-- BOLUM 1: DDL (TABLO TANIMLARI)

DROP TABLE IF EXISTS invoice_items;
DROP TABLE IF EXISTS invoices;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS customers;

CREATE TABLE customers (
    customer_id     INTEGER PRIMARY KEY
);

CREATE TABLE products (
    stock_code      TEXT PRIMARY KEY,
    description     TEXT
);

CREATE TABLE invoices (
    invoice_id      INTEGER PRIMARY KEY,
    customer_id     INTEGER REFERENCES customers(customer_id),
    invoice_date    TIMESTAMP NOT NULL,
    country         TEXT NOT NULL
);

CREATE TABLE invoice_items (
    id              SERIAL PRIMARY KEY,
    invoice_id      INTEGER NOT NULL REFERENCES invoices(invoice_id),
    stock_code      TEXT NOT NULL REFERENCES products(stock_code),
    quantity        INTEGER NOT NULL,
    unit_price      NUMERIC NOT NULL,
    total_amount    NUMERIC NOT NULL
);

CREATE INDEX idx_items_invoice ON invoice_items(invoice_id);
CREATE INDEX idx_items_stock ON invoice_items(stock_code);
CREATE INDEX idx_invoices_customer ON invoices(customer_id);


-- BOLUM 2: ANALIZ SORGULARI

-- Q1) Aylik net ciro ne kadardir?
SELECT
    TO_CHAR(i.invoice_date, 'YYYY-MM') AS ay,
    ROUND(SUM(ii.total_amount)::numeric, 2) AS net_ciro,
    COUNT(DISTINCT i.invoice_id) AS fatura_sayisi
FROM invoice_items ii
JOIN invoices i ON i.invoice_id = ii.invoice_id
GROUP BY ay
ORDER BY ay;


-- Q2) En fazla gelir saglayan 10 urun hangileridir?
SELECT
    p.stock_code,
    p.description,
    SUM(ii.quantity) AS toplam_adet,
    ROUND(SUM(ii.total_amount)::numeric, 2) AS toplam_gelir
FROM invoice_items ii
JOIN products p ON p.stock_code = ii.stock_code
WHERE p.stock_code NOT IN (
    'POST', 'DOT', 'C2', 'D', 'M', 'S', 'BANK CHARGES',
    'AMAZONFEE', 'CRUK', 'PADS', 'TEST001', 'TEST002'
)
GROUP BY p.stock_code, p.description
ORDER BY toplam_gelir DESC
LIMIT 10;


-- Q3) En degerli 10 musteri kimdir?
SELECT
    i.customer_id,
    COUNT(DISTINCT i.invoice_id) AS fatura_sayisi,
    ROUND(SUM(ii.total_amount)::numeric, 2) AS toplam_harcama
FROM invoice_items ii
JOIN invoices i ON i.invoice_id = ii.invoice_id
WHERE i.customer_id IS NOT NULL
GROUP BY i.customer_id
ORDER BY toplam_harcama DESC
LIMIT 10;


-- Q4) Ulkelere gore siparis ve ciro dagilimi nedir?
SELECT
    i.country,
    COUNT(DISTINCT i.invoice_id) AS siparis_sayisi,
    ROUND(SUM(ii.total_amount)::numeric, 2) AS toplam_ciro,
    ROUND(100.0 * SUM(ii.total_amount) / SUM(SUM(ii.total_amount)) OVER ()::numeric, 2) AS ciro_yuzdesi
FROM invoice_items ii
JOIN invoices i ON i.invoice_id = ii.invoice_id
GROUP BY i.country
ORDER BY toplam_ciro DESC;


-- Q5) Aylik iptal orani nedir?


-- Q6) Musterilerin ortalama sepet tutari nedir?
WITH fatura_toplamlari AS (
    SELECT ii.invoice_id, i.customer_id, SUM(ii.total_amount) AS fatura_toplami
    FROM invoice_items ii
    JOIN invoices i ON i.invoice_id = ii.invoice_id
    WHERE i.customer_id IS NOT NULL
    GROUP BY ii.invoice_id, i.customer_id
)
SELECT
    customer_id,
    COUNT(*) AS siparis_sayisi,
    ROUND(AVG(fatura_toplami)::numeric, 2) AS ort_sepet_tutari,
    ROUND(AVG(AVG(fatura_toplami)) OVER ()::numeric, 2) AS genel_ortalama
FROM fatura_toplamlari
GROUP BY customer_id
ORDER BY ort_sepet_tutari DESC;


-- Q7) Bir onceki aya gore ciro buyume orani nedir?
WITH aylik AS (
    SELECT TO_CHAR(i.invoice_date, 'YYYY-MM') AS ay,
           ROUND(SUM(ii.total_amount)::numeric, 2) AS net_ciro
    FROM invoice_items ii
    JOIN invoices i ON i.invoice_id = ii.invoice_id
    GROUP BY ay
)
SELECT
    ay, net_ciro,
    LAG(net_ciro) OVER (ORDER BY ay) AS onceki_ay,
    ROUND(100.0 * (net_ciro - LAG(net_ciro) OVER (ORDER BY ay))
          / LAG(net_ciro) OVER (ORDER BY ay), 2) AS buyume_yuzde
FROM aylik
ORDER BY ay;


-- Q8) Musteri RFM (Recency, Frequency, Monetary) tablosu
WITH musteri_ozet AS (
    SELECT i.customer_id,
           MAX(i.invoice_date) AS son_alisveris,
           COUNT(DISTINCT i.invoice_id) AS frequency,
           SUM(ii.total_amount) AS monetary
    FROM invoice_items ii
    JOIN invoices i ON i.invoice_id = ii.invoice_id
    WHERE i.customer_id IS NOT NULL
    GROUP BY i.customer_id
),
snapshot AS (SELECT MAX(invoice_date) AS snapshot_tarihi FROM invoices)
SELECT
    m.customer_id,
    (s.snapshot_tarihi::date - m.son_alisveris::date) AS recency_gun,
    m.frequency,
    ROUND(m.monetary::numeric, 2) AS monetary,
    NTILE(5) OVER (ORDER BY (s.snapshot_tarihi::date - m.son_alisveris::date) DESC) AS recency_skor,
    NTILE(5) OVER (ORDER BY m.frequency) AS frequency_skor,
    NTILE(5) OVER (ORDER BY m.monetary) AS monetary_skor
FROM musteri_ozet m, snapshot s
ORDER BY monetary DESC;
