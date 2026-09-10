# E-Ticaret Satış Analizi

Data Engineering stajı case çalışması. Online Retail II veri setini (UK merkezli bir e-ticaret şirketinin 2009-2011 işlem verisi) temizleyip Postgres'e ilişkisel bir model olarak yükledim, SQL ile 8 soruyu cevapladım, Looker Studio'da 4 grafik hazırladım.

## Veride ne buldum, neyi nasıl temizledim

Ham veri 1.067.371 satırdı. Sırayla şunları tespit ettim ve şu kararları verdim:

**Sildiklerim:**
- ~34 bin satır tamamen tekrar ediyordu → `drop_duplicates()`
- `Customer ID` satırların ~%23'ünde boştu (misafir/kayıtsız alışverişler). Bunları attım çünkü kimlik olmadan RFM veya müşteri bazlı hiçbir analiz yapamıyorum. Bunun bedeli: cironun bir kısmı hesaplara girmiyor.
- `Invoice` kodu `C` ile başlayan satırlar iptal edilmiş işlemler → çıkardım

**Silmediklerim ama analiz dışında bıraktıklarım:**
- `POST`, `DOT`, `BANK CHARGES`, `D`, `M`, `AMAZONFEE` gibi kodlar kargo/komisyon/indirim/banka masrafı — gerçek ürün değil ama gerçek para hareketi. Satırları silmedim, sadece "en çok satan ürün" sorgusunda `WHERE ... NOT IN (...)` ile dışarıda bıraktım.

**Doldurduklarım:**
- Eksik `Description`'ları aynı `StockCode`'un en sık geçen açıklamasıyla doldurdum

**Sonradan kontrol ettiklerim:**
Ham veride `StockCode = 'B'` ("Adjust bad debt", fiyatları -11.000 / -53.000 gibi absürt büyük muhasebe düzeltmeleri, 6 satır) ve `TEST001`/`TEST002` (açıklaması "This is a test product.", 17 satır) gibi gerçek satış olmayan kayıtlar vardı. Bunlar için ayrı bir filtre yazmadım ama temizlik sonrası kontrol ettiğimde ikisinin de temiz veride kalmadığını gördüm — yukarıdaki adımlar sırasında elenmişler.

Temizlik sonrası ~780 bin satır kaldı.

## Veritabanı yapısı

4 tablo: `customers`, `products`, `invoices`, `invoice_items`. Şema ve neden öyle kurduğum `er_diagram.md`'de. Kısaca iki karar:

- Ülke bilgisini `customers`'a değil `invoices`'a bağladım — bir müşteri farklı ülkelerden sipariş vermiş olabilir
- `invoice_items`'ta `(invoice_id, stock_code)` tekil çıkmadı (aynı üründen bir faturada birden fazla satır olabiliyor), o yüzden otomatik artan bir `id` (SERIAL) kullandım

Yükledikten sonra 4 tablonun satır sayısını CSV'lerdekiyle karşılaştırdım, hepsi tutuyordu.

## Varsayımlar

Bunlar önemli, çünkü rakamların ne anlama geldiğini değiştiriyorlar:

- **"Net ciro" adı biraz yanıltıcı olabilir.** İptalleri ve misafir siparişleri baştan çıkardığım için elimdeki rakam aslında "kayıtlı müşterilerin, iptal edilmemiş siparişlerinin toplamı" — iadeleri netleyen bir rakam değil.
- **"Aylık iptal oranı" sorusunu SQL modelinden cevaplayamadım**, çünkü modelde iptal verisi yok. Onu ham veri üzerinden pandas ile ayrıca hesapladım (notebook'ta var), Looker Studio'ya ayrı bir tablo olarak yükledim.
- Ürün analizinde kargo/komisyon kodlarını manuel bir listeyle filtreledim, `is_product` gibi bir bayrak kolonu kullanmadım. Bayrak daha temiz olurdu ama sorgu içinde filtrelemek de aynı sonucu veriyor.
