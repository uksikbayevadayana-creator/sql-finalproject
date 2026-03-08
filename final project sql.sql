CREATE DATABASE Customer_transactions;

SET SQL_SAFE_UPDATES = 0;
UPDATE customers SET Gender = NULL WHERE Gender ='';
UPDATE customers SET Age = NULL WHERE Age ='';
ALTER TABLE customers MODIFY AGE INT NULL;

SELECT * FROM customers;

CREATE TABLE transactions
(date_new DATE,
Id_check INT,
ID_client INT,
Count_products DECIMAL(10,3),
Sum_payment DECIMAL(10,2));

LOAD DATA INFILE 'C:\\ProgramData\\MySQL\\MySQL Server 8.0\\Uploads\\TRANSACTIONS.csv'
INTO TABLE transactions
FIELDS TERMINATED BY ','
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(date_new, Id_check, ID_client, Count_products, @Sum_payment)
SET Sum_payment = TRIM(REPLACE(REPLACE(@Sum_payment, ';', ''), '\r', ''));

SELECT * FROM Transactions;


#Задание 1 
#1. Клиенты с непрерывной историей за год
SELECT
  t.ID_client
FROM transactions t
WHERE t.date_new >= '2015-06-01'
  AND t.date_new <  '2016-06-01'
GROUP BY t.ID_client
HAVING COUNT(DISTINCT DATE_FORMAT(t.date_new, '%Y-%m')) = 12;

#2.Средний чек за период (01.06.2015–01.06.2016)
SELECT
  ROUND(SUM(Sum_payment) / COUNT(DISTINCT Id_check), 2) AS avg_check
FROM transactions
WHERE date_new >= '2015-06-01'
  AND date_new <  '2016-06-01';

#3.Средняя сумма покупок за месяц
SELECT
  ROUND(AVG(month_sum), 2) AS avg_month_revenue
FROM (
  SELECT
    DATE_FORMAT(date_new, '%Y-%m') AS ym,
    SUM(Sum_payment) AS month_sum
  FROM transactions
  WHERE date_new >= '2015-06-01'
    AND date_new <  '2016-06-01'
  GROUP BY ym
) m;

#4.Количество всех операций по клиенту за период
SELECT
  ID_client,
  COUNT(*) AS operations_cnt,
  COUNT(DISTINCT Id_check) AS checks_cnt,
  ROUND(SUM(Sum_payment), 2) AS total_spent
FROM transactions
WHERE date_new >= '2015-06-01'
  AND date_new <  '2016-06-01'
GROUP BY ID_client
ORDER BY operations_cnt DESC;

#Задание 2
#1. Cредняя сумма чека, кол-во операций, активные клиенты, выручка (в разрезе месяца)
SELECT
  DATE_FORMAT(date_new, '%Y-%m') AS ym,
  ROUND(SUM(Sum_payment) / COUNT(DISTINCT Id_check), 2) AS avg_check_month,
  COUNT(*) AS operations_cnt_month,
  COUNT(DISTINCT ID_client) AS active_clients_month,
  ROUND(SUM(Sum_payment), 2) AS revenue_month
FROM transactions
WHERE date_new >= '2015-06-01'
  AND date_new <  '2016-06-01'
GROUP BY ym
ORDER BY ym;

#2. Доля операций от общего количества за год и доля суммы месяца от общей суммы за год
WITH totals AS (
  SELECT
    COUNT(*) AS ops_year_total,
    SUM(Sum_payment) AS sum_year_total
  FROM transactions
  WHERE date_new >= '2015-06-01'
    AND date_new <  '2016-06-01'
),
monthly AS (
  SELECT
    DATE_FORMAT(date_new, '%Y-%m') AS ym,
    COUNT(*) AS ops_month,
    SUM(Sum_payment) AS sum_month
  FROM transactions
  WHERE date_new >= '2015-06-01'
    AND date_new <  '2016-06-01'
  GROUP BY ym
)
SELECT
  m.ym,
  m.ops_month,
  ROUND(m.ops_month / t.ops_year_total * 100, 2) AS ops_share_of_year_pct,
  ROUND(m.sum_month, 2) AS sum_month,
  ROUND(m.sum_month / t.sum_year_total * 100, 2) AS sum_share_of_year_pct
FROM monthly m
CROSS JOIN totals t
ORDER BY m.ym

#3. % соотношение M/F/NA в каждом месяце + их доля затрат
WITH base AS (
  SELECT
    DATE_FORMAT(t.date_new, '%Y-%m') AS ym,
    COALESCE(NULLIF(c.Gender, ''), 'NA') AS gender,
    t.ID_client,
    t.Sum_payment
  FROM transactions t
  LEFT JOIN customers c ON c.ID_client = t.ID_client
  WHERE t.date_new >= '2015-06-01'
    AND t.date_new <  '2016-06-01'
),
month_totals AS (
  SELECT
    ym,
    COUNT(DISTINCT ID_client) AS clients_month,
    SUM(Sum_payment) AS sum_month
  FROM base
  GROUP BY ym
),
gender_totals AS (
  SELECT
    ym,
    gender,
    COUNT(DISTINCT ID_client) AS clients_gender,
    SUM(Sum_payment) AS sum_gender
  FROM base
  GROUP BY ym, gender
)
SELECT
  g.ym,
  g.gender,
  g.clients_gender,
  ROUND(g.clients_gender / NULLIF(m.clients_month, 0) * 100, 2) AS clients_share_pct,
  ROUND(g.sum_gender, 2) AS spend_gender,
  ROUND(g.sum_gender / NULLIF(m.sum_month, 0) * 100, 2) AS spend_share_pct
FROM gender_totals g
JOIN month_totals m ON m.ym = g.ym
ORDER BY g.ym,
         CASE g.gender WHEN 'F' THEN 1 WHEN 'M' THEN 2 ELSE 3 END;
         
	#Задание 3
#1. 
SELECT
  CASE
    WHEN c.Age IS NULL THEN 'Unknown'
    ELSE CONCAT(FLOOR(c.Age/10)*10, '-', FLOOR(c.Age/10)*10 + 9)
  END AS age_group,
  COUNT(*) AS operations_cnt,
  COUNT(DISTINCT t.ID_client) AS clients_cnt,
  ROUND(SUM(t.Sum_payment), 2) AS total_spent
FROM transactions t
LEFT JOIN customers c ON c.ID_client = t.ID_client
WHERE t.date_new >= '2015-06-01'
  AND t.date_new <  '2016-06-01'
GROUP BY age_group
ORDER BY
  CASE
    WHEN age_group = 'Unknown' THEN 999
    ELSE CAST(SUBSTRING_INDEX(age_group, '-', 1) AS UNSIGNED)
  END;
  
  #2.
  WITH base_data AS (
  SELECT
    CONCAT(YEAR(t.date_new), '-Q', QUARTER(t.date_new)) AS quarter,
    t.ID_client,
    t.Sum_payment,
    CASE
      WHEN c.Age IS NULL THEN 'Unknown'
      ELSE CONCAT(FLOOR(c.Age/10)*10, '-', FLOOR(c.Age/10)*10 + 9)
    END AS age_group
  FROM transactions t
  LEFT JOIN customers c ON c.ID_client = t.ID_client
  WHERE t.date_new >= '2015-06-01'
    AND t.date_new <  '2016-06-01'
),

quarter_sum AS (
  SELECT
    quarter,
    COUNT(*) AS total_operations,
    SUM(Sum_payment) AS total_revenue
  FROM base_data
  GROUP BY quarter
),

age_q_stats AS (
  SELECT
    quarter,
    age_group,
    COUNT(*) AS operations_count,
    COUNT(DISTINCT ID_client) AS clients_count,
    SUM(Sum_payment) AS revenue,
    AVG(Sum_payment) AS avg_payment,
    COUNT(*) / NULLIF(COUNT(DISTINCT ID_client), 0) AS avg_ops_per_client
  FROM base_data
  GROUP BY quarter, age_group
)

SELECT
  a.quarter,
  a.age_group,
  a.operations_count,
  a.clients_count,
  ROUND(a.revenue, 2) AS revenue,
  ROUND(a.avg_payment, 2) AS avg_payment,
  ROUND(a.avg_ops_per_client, 2) AS avg_ops_per_client,
  ROUND(a.operations_count / NULLIF(q.total_operations, 0) * 100, 2) AS operations_share_pct,
  ROUND(a.revenue / NULLIF(q.total_revenue, 0) * 100, 2) AS revenue_share_pct
FROM age_q_stats a
JOIN quarter_sum q ON q.quarter = a.quarter
ORDER BY
  a.quarter,
  CASE
    WHEN a.age_group = 'Unknown' THEN 999
    ELSE CAST(SUBSTRING_INDEX(a.age_group, '-', 1) AS UNSIGNED)
  END;