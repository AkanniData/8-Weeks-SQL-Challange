-- A. Customer Nodes Exploration
----------------------------------------
-- 1. How many unique nodes are there in the Data Bank system?

SELECT  COUNT(DISTINCT node_id) AS Unique_nodes
FROM customer_nodes;
----------------------------------------
-- 2. What is the number of nodes per region?

SELECT
	region_name,
    COUNT(node_id) AS num_of_nodes
FROM customer_nodes cn
INNER JOIN regions r
USING(region_id)
GROUP BY region_name
ORDER BY num_of_nodes DESC;
---------------------------------------
-- 3. How many customers are allocated to each region?

SELECT
	cn.region_id,
    region_name,
    COUNT(DISTINCT customer_id) AS num_of_customers
FROM customer_nodes cn
JOIN regions r
USING(region_id)
GROUP BY cn.region_id, region_name
ORDER BY num_of_customers DESC;
---------------------------------------
-- 4. How many days on average are customers reallocated to a different node?

WITH sum_diff_day AS (
SELECT 
	customer_id, node_id, start_date, end_date,
    SUM(DATEDIFF(end_date, start_date)) AS sum_diff
FROM customer_nodes
WHERE end_date != '9999-12-31'
GROUP BY customer_id, node_id, start_date, end_date
ORDER BY customer_id, node_id)
SELECT 
	ROUND(AVG(sum_diff),0) AS avg_days_in_nodes
FROM sum_diff_day;
----------------------------------------
-- 5. What is the median, 80th and 95th percentile for this same reallocation days metric for each region?
-- *NOT DONE*
WITH sum_diff_day AS (
SELECT 
	region_name,
	customer_id,
    node_id,
    SUM(DATEDIFF(end_date, start_date)) AS sum_diff
FROM customer_nodes AS c
INNER JOIN regions AS r
	ON r.region_id = c.region_id
WHERE end_date != '9999-12-31'
GROUP BY region_name, customer_id, node_id
)
SELECT 
	ROUND(AVG(sum_diff),0) AS avg_days_in_nodes
FROM sum_diff_day;
-------------------------------------------
-- B. Customer Transactions
-------------------------------------------
-- 1. What is the unique count and total amount for each transaction type?

SELECT
	txn_type,
	COUNT(*) AS unique_count,
  SUM(txn_amount) AS total_amount
FROM customer_transactions
GROUP BY txn_type; 
------------------------------------------
-- 2. What is the average total historical deposit counts and amounts for all customers?

WITH CTE AS (
select
customer_id,
AVG(txn_amount) as avg_desposit,
count(*) as transaction_count
from customer_transactions
where txn_type = 'deposit'
group by customer_id
)
select
round(avg(avg_desposit),2) as avg_desposit_amount,
round(avg(transaction_count),0) as avg_transactions
from CTE;
---------------------------------------------
-- 3. For each month - how many Data Bank customers make more than 1 deposits and either 1 purchase or 1 withdrawal in a single month?

 WITH monthly_txn AS (
SELECT
	customer_id,
	MONTH(txn_date) AS months,
    SUM(CASE WHEN txn_type = 'deposit' THEN 0 ELSE 1 END) AS deposits,
    SUM(CASE WHEN txn_type = 'purchase' THEN 0 ELSE 1 END) AS purchases,
    SUM(CASE WHEN txn_type = 'withdrawal' THEN 1 ELSE 0 END) AS withdrawal
FROM customer_transactions
GROUP BY customer_id, months)
SELECT
	months,
    COUNT(DISTINCT customer_id) AS customer_cnt
FROM monthly_txn
WHERE deposits >= 2 AND (purchases > 1 OR withdrawal > 1)
GROUP BY months
ORDER BY months;  
--------------------------------------------
-- 4. What is the closing balance for each customer at the end of the month?

WITH AmountCte AS(
   SELECT 
   	customer_id,
   	EXTRACT(MONTH FROM txn_date) AS month,
   	SUM(CASE 
   	WHEN txn_type = 'deposit' THEN txn_amount ELSE -txn_amount END) AS amount
   FROM customer_transactions
   GROUP BY customer_id, month
   ORDER BY customer_id
)
SELECT 
   customer_id, 
   month,
   SUM(amount)OVER(PARTITION BY customer_id ORDER BY MONTH ROWS BETWEEN
   			   UNBOUNDED PRECEDING AND CURRENT ROW) AS closing_balance
FROM AmountCte
GROUP BY customer_id, month, amount
ORDER BY customer_id;
--------------------------------------------
-- 5. What is the percentage of customers who increase their closing balance by more than 5%?

WITH monthly_transactions AS
(
	SELECT customer_id,
	       MONTH(txn_date) AS end_date,
	       SUM(CASE WHEN txn_type IN ('withdrawal', 'purchase') THEN -txn_amount
			ELSE txn_amount END) AS transactions
	FROM customer_transactions
	GROUP BY customer_id, end_date
),
closing_balances AS 
(
	SELECT customer_id,
	       end_date,
	       COALESCE(SUM(transactions) OVER(PARTITION BY customer_id ORDER BY end_date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW), 0) AS closing_balance
	FROM monthly_transactions
),
pct_increase AS 
(
  SELECT customer_id,
         end_date,
         closing_balance,
         LAG(closing_balance) OVER (PARTITION BY customer_id ORDER BY end_date) AS prev_closing_balance,
         100 * (closing_balance - LAG(closing_balance) OVER (PARTITION BY customer_id ORDER BY end_date)) / NULLIF(LAG(closing_balance) OVER (PARTITION BY customer_id ORDER BY end_date), 0) AS pct_increase
 FROM closing_balances
)
SELECT CAST(100.0 * COUNT(DISTINCT customer_id) / (SELECT COUNT(DISTINCT customer_id) FROM customer_transactions) AS FLOAT) AS pct_customers
FROM pct_increase
WHERE pct_increase > 5;
------------------------------------------
-- To test out a few different hypotheses - the Data Bank team wants to run an experiment where different groups of customers would be allocated data using 3 different options:

-- Option 1: data is allocated based off the amount of money at the end of the previous month

WITH Amount_Cte AS (
	SELECT
		customer_id,
        EXTRACT(MONTH from txn_date) AS month,
        CASE
			WHEN txn_type = 'deposit' THEN txn_amount
            WHEN txn_type = 'withdrawal' THEN -txn_amount
            WHEN txn_type = 'purchase' THEN -txn_amount END as amount
	FROM customer_transactions
	ORDER BY customer_id, month),
RunningBalance AS (
	SELECT
		*,
        SUM(amount) OVER (PARTITION BY customer_id, month ORDER BY customer_id, month
					ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_balance
	FROM Amount_Cte),
MonthlyAllocation AS(
	SELECT
		*,
        LAG(running_balance, 1) OVER(PARTITION BY customer_id ORDER BY customer_id, month) AS MonthlyAllocation
	FROM RunningBalance)
SELECT 
	month,
    SUM(
   	CASE WHEN MonthlyAllocation < 0 THEN 0 ELSE MonthlyAllocation END) AS total_allocation
FROM MonthlyAllocation
GROUP BY month
ORDER BY month;
-----------------------------------
-- Option 2: data is allocated on the average amount of money kept in the account in the previous 30 days
WITH AmountCte AS (
   SELECT 
   	customer_id,
   	EXTRACT(MONTH from txn_date) AS month,
   	SUM(CASE
   		WHEN txn_type = 'deposit' THEN txn_amount
   		WHEN txn_type = 'purchase' THEN -txn_amount
   		WHEN txn_type = 'withdrawal' THEN -txn_amount END) as net_amount
   FROM customer_transactions
   GROUP BY customer_id, month
),
RunningBalance AS (
   SELECT 
   	*,
   	SUM(net_amount) OVER (PARTITION BY customer_id ORDER BY month
   		   ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_balance
   FROM AmountCte
   ORDER BY customer_id, month
),
Avg_running_balance AS(
   SELECT customer_id, 
   month,
   AVG(running_balance) OVER(PARTITION BY customer_id) AS avg_balance
   FROM RunningBalance
   GROUP BY customer_id, month, running_balance
   ORDER BY customer_id
)
SELECT 
   month,
   ROUND(SUM(CASE
   		WHEN avg_balance < 0 THEN 0 ELSE avg_balance END), 2) AS data_needed_per_month
FROM Avg_running_balance
GROUP BY month
ORDER BY month;	
-------------------------
-- Option 3: data is updated real-time

WITH AmountCte AS (
   SELECT
   	customer_id,
   	EXTRACT(MONTH FROM txn_date) AS month,
   	SUM(CASE 
   		WHEN txn_type = 'deposit' THEN txn_amount 
   		ELSE -txn_amount END) AS balance
   FROM customer_transactions
   GROUP BY customer_id, month
),
Running_balance AS (
   SELECT
   		customer_id,
   		month,
   		SUM(balance) OVER(PARTITION BY customer_id ORDER BY month 
   						  ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_total
   FROM AmountCte
   GROUP BY customer_id, month, balance
)
SELECT 
   month, 
   SUM(CASE WHEN running_total < 0 THEN 0 ELSE running_total END) Data_required
FROM Running_balance
GROUP BY month
ORDER BY month;
---------------------------
-- Using all of the data available - how much data would have been required for each option on a monthly basis?

-- running customer balance column that includes the impact each transaction

SELECT customer_id,
       txn_date,
       txn_type,
       txn_amount,
       SUM(CASE WHEN txn_type = 'deposit' THEN txn_amount
		WHEN txn_type = 'withdrawal' THEN -txn_amount
		WHEN txn_type = 'purchase' THEN -txn_amount
		ELSE 0
	   END) OVER(PARTITION BY customer_id ORDER BY txn_date) AS running_balance
FROM customer_transactions;
-------------------------------------
-- customer balance at the end of each month

WITH AmountCte AS(
   SELECT 
   	customer_id,
   	EXTRACT(MONTH from txn_date) AS month,
   	SUM(CASE
   		WHEN txn_type = 'deposit' THEN txn_amount
   		ELSE -txn_amount END) as amount
   FROM customer_transactions
   GROUP BY customer_id, month
   ORDER BY customer_id, month
)
SELECT 
   customer_id,
   month,
   SUM(amount) OVER(PARTITION  BY customer_id, month ORDER BY month 
					ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_balance
FROM AmountCte
GROUP BY customer_id, month, amount;
----------------------------------
-- minimum, average and maximum values of the running balance for each customer

WITH running_balance AS
(
	SELECT customer_id,
	       txn_date,
	       txn_type,
	       txn_amount,
	       SUM(CASE WHEN txn_type = 'deposit' THEN txn_amount
			WHEN txn_type = 'withdrawal' THEN -txn_amount
			WHEN txn_type = 'purchase' THEN -txn_amount
			ELSE 0
		    END) OVER(PARTITION BY customer_id ORDER BY txn_date) AS running_balance
	FROM customer_transactions
)

SELECT customer_id,
       AVG(running_balance) AS avg_running_balance,
       MIN(running_balance) AS min_running_balance,
       MAX(running_balance) AS max_running_balance
FROM running_balance
GROUP BY customer_id;
---------------------------------

