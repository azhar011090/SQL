CREATE DATABASE Customers_transactions;
SET SQL_SAFE_UPDATES = 0;
UPDATE customers SET Gender = NULL WHERE Gender = '';
UPDATE customers SET Age = NULL WHERE Age = '';
ALTER TABLE customers MODIFY AGE INT NULL;

SELECT * FROM customers;
SELECT * FROM transactions;

CREATE TABLE transactions
(
	date_new DATE,
    Id_check INT,
    ID_client INT,
    Count_products DECIMAL(10,3),
    Sum_payment DECIMAL(10,2)
);

LOAD DATA INFILE "C:\\ProgramData\\MySQL\\MySQL Server 8.0\\Uploads\\TRANSACTIONS_final2.csv"
INTO TABLE transactions
FIELDS TERMINATED BY ','
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;


SHOW VARIABLES LIKE 'secure_file_priv';

/* ----------------------- ЗАДАНИЕ 1 ------------------------------------------*/
WITH monthly_activity AS (
    SELECT 
        t.ID_client,
        YEAR(t.date_new) AS year,
        MONTH(t.date_new) AS month,
        COUNT(DISTINCT t.ID_check) AS transactions_count,  -- количество операций по клиенту за месяц
        SUM(t.Sum_payment) AS total_spent_month  -- общая сумма покупок за месяц
    FROM transactions t
    WHERE t.date_new BETWEEN '2015-06-01' AND '2016-06-01'
    GROUP BY t.ID_client, YEAR(t.date_new), MONTH(t.date_new)
),
client_history AS (
    SELECT
        ID_client,
        COUNT(DISTINCT month) AS active_months  -- подсчёт активных месяцев для клиента
    FROM monthly_activity
    GROUP BY ID_client
),
continuous_clients AS (
    SELECT 
        mh.ID_client
    FROM monthly_activity mh
    JOIN client_history ch ON mh.ID_client = ch.ID_client
    WHERE ch.active_months = 12  -- Клиенты, которые были активны все 12 месяцев
),
summary_stats AS (
    SELECT 
        t.ID_client,
        AVG(t.Sum_payment) AS avg_payment_per_transaction,  -- средний чек за весь период
        COUNT(t.ID_check) AS total_transactions,  -- количество всех операций
        SUM(t.Sum_payment) AS total_spent  -- общая сумма за весь период
    FROM transactions t
    WHERE t.date_new BETWEEN '2015-06-01' AND '2016-06-01'
    GROUP BY t.ID_client
)
SELECT 
    distinct c.ID_client,
    c.avg_payment_per_transaction,
    c.total_transactions,
    c.total_spent
FROM summary_stats c
JOIN continuous_clients cc ON c.ID_client = cc.ID_client;


/* ----------------------- ЗАДАНИЕ 2 ------------------------------------------*/

WITH monthly_activity AS (
    SELECT 
        t.ID_client,
        YEAR(t.date_new) AS year,
        MONTH(t.date_new) AS month,
        COUNT(DISTINCT t.ID_check) AS transactions_count,  -- количество операций по клиенту за месяц
        SUM(t.Sum_payment) AS total_spent_month  -- общая сумма покупок за месяц
    FROM transactions t
    WHERE t.date_new BETWEEN '2015-06-01' AND '2016-06-01'
    GROUP BY t.ID_client, YEAR(t.date_new), MONTH(t.date_new)
),
/*select * from monthly_activity;*/
monthly_summary AS (
    SELECT 
        ma.month,
        AVG(ma.total_spent_month) AS avg_check,  -- средняя сумма чека за месяц
        AVG(ma.transactions_count) AS avg_transactions,  -- среднее количество операций за месяц
        COUNT(DISTINCT ma.ID_client) AS avg_clients_per_month,  -- среднее количество клиентов
        SUM(ma.transactions_count) AS total_transactions_month,  -- общее количество операций в месяце
        SUM(ma.total_spent_month) AS total_spent_month,  -- общая сумма покупок за месяц
        SUM(CASE WHEN c.Gender = 'M' THEN ma.total_spent_month ELSE 0 END) AS male_spent,
        SUM(CASE WHEN c.Gender = 'F' THEN ma.total_spent_month ELSE 0 END) AS female_spent,
        SUM(CASE WHEN c.Gender IS NULL THEN ma.total_spent_month ELSE 0 END) AS na_spent
    FROM monthly_activity ma
    JOIN customers c ON ma.ID_client = c.Id_client
    GROUP BY ma.month
),
/*select * from monthly_summary;*/
annual_summary AS (
    SELECT 
        SUM(transactions_count) AS total_transactions_year,
        SUM(total_spent_month) AS total_spent_year
    FROM monthly_activity
)
/*select * from annual_summary;*/
SELECT 
    ms.month,
    ms.avg_check,
    ms.avg_transactions,
    ms.avg_clients_per_month,
    (ms.total_transactions_month / asy.total_transactions_year) * 100 AS month_transaction_share,  -- доля операций месяца от общего количества за год
    (ms.total_spent_month / asy.total_spent_year) * 100 AS month_spending_share,  -- доля затрат месяца от общей суммы за год
    (ms.male_spent / ms.total_spent_month) * 100 AS male_percentage_of_spending,  -- процент затрат мужчин
    (ms.female_spent / ms.total_spent_month) * 100 AS female_percentage_of_spending,  -- процент затрат женщин
    (ms.na_spent / ms.total_spent_month) * 100 AS na_percentage_of_spending  -- процент затрат неопределённых
FROM monthly_summary ms, annual_summary asy
ORDER BY ms.month;

/* ----------------------- ЗАДАНИЕ 3 ------------------------------------------*/

WITH age_groups AS (
    -- Группировка по возрастным категориям с шагом 10 лет
    SELECT 
        c.ID_client,
        CASE 
            WHEN c.Age IS NULL THEN 'Unknown'
            WHEN c.Age BETWEEN 0 AND 9 THEN '0-9'
            WHEN c.Age BETWEEN 10 AND 19 THEN '10-19'
            WHEN c.Age BETWEEN 20 AND 29 THEN '20-29'
            WHEN c.Age BETWEEN 30 AND 39 THEN '30-39'
            WHEN c.Age BETWEEN 40 AND 49 THEN '40-49'
            WHEN c.Age BETWEEN 50 AND 59 THEN '50-59'
            WHEN c.Age BETWEEN 60 AND 69 THEN '60-69'
            WHEN c.Age BETWEEN 70 AND 79 THEN '70-79'
            ELSE '80+'
        END AS age_group
    FROM customers c
),
transaction_summary AS (
    -- Сумма и количество операций за весь период для каждого клиента
    SELECT 
        t.ID_client,
        SUM(t.Sum_payment) AS total_spent,
        COUNT(DISTINCT t.ID_check) AS total_transactions
    FROM transactions t
    GROUP BY t.ID_client
),
quarterly_summary AS (
    -- Поквартальные данные по операциям и расходам
    SELECT 
        t.ID_client,
        QUARTER(t.date_new) AS quarter,
        SUM(t.Sum_payment) AS total_spent_quarter,
        COUNT(DISTINCT t.ID_check) AS total_transactions_quarter
    FROM transactions t
    WHERE t.date_new BETWEEN '2015-06-01' AND '2016-06-01'  -- Период с 01.06.2015 по 01.06.2016
    GROUP BY t.ID_client, QUARTER(t.date_new)
),
total_summary AS (
    -- Общая сумма и количество операций за год
    SELECT 
        SUM(t.Sum_payment) AS total_year_spent,
        COUNT(DISTINCT t.ID_check) AS total_year_transactions
    FROM transactions t
    WHERE t.date_new BETWEEN '2015-06-01' AND '2016-06-01'
)
SELECT 
    ag.age_group,
    ts.total_spent,
    ts.total_transactions,
    -- Средняя сумма чека и операций поквартально
    AVG(qs.total_spent_quarter) AS avg_quarterly_spent,
    AVG(qs.total_transactions_quarter) AS avg_quarterly_transactions,
    -- Процентное соотношение по каждому кварталу от общего
    (SUM(qs.total_spent_quarter) / ts.total_spent) * 100 AS quarter_spending_percentage,
    (SUM(qs.total_transactions_quarter) / ts.total_transactions) * 100 AS quarter_transaction_percentage
FROM age_groups ag
LEFT JOIN transaction_summary ts ON ag.ID_client = ts.ID_client
LEFT JOIN quarterly_summary qs ON ag.ID_client = qs.ID_client
LEFT JOIN total_summary total ON 1=1  -- Суммарные данные по всем клиентам
GROUP BY ag.age_group, ts.total_spent, ts.total_transactions
ORDER BY FIELD(ag.age_group, 'Unknown', '0-9', '10-19', '20-29', '30-39', '40-49', '50-59', '60-69', '70-79', '80+');

