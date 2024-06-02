-- A. Customer Journey
-- Based off the 8 sample customers provided in the sample from the subscriptions table, write a brief description about each customer’s onboarding journey.
-- Try to keep it as short as possible - you may also want to run some sort of join to make your explanations a bit easier!

SELECT
	s.customer_id,
    p.plan_name,
    s.start_date
FROM subscriptions s
JOIN plans p ON s.plan_id = p.plan_id
LIMIT 12;
----------------------------------------------
-- B. Data Analysis Questions:
----------------------------------------------
-- 1. How many customers has Foodie-Fi ever had?

select count(distinct customer_id) as NumOfCustomers
from foodie_fi.subscriptions;
----------------------------------------------
-- 2. What is the monthly distribution of trial plan start_date values for our dataset - use the start of the month as the group by value?

SELECT
	MONTH(start_date) AS months,
    monthname(start_date) AS MonthName, 
	COUNT(customer_id) AS num_customers
FROM subscriptions
GROUP BY month(start_date),monthname(start_date)
ORDER BY month(start_date);
---------------------------------------------
-- 3. What plan start_date values occur after the year 2020 for our dataset? Show the breakdown by count of events for each plan_name

SELECT
	p.plan_name,
    p.plan_id,
    count(s.plan_id) AS CountofEvents
FROM subscriptions s 
JOIN plans p ON p.plan_id = s.plan_id
WHERE s.start_date >= '2021-01-01'
GROUP BY p.plan_id,p.plan_name
ORDER BY p.plan_id;
------------------------------------------
-- 4. What is the customer count and percentage of customers who have churned rounded to 1 decimal place?

SELECT 
	COUNT(customer_id) AS CustomersChurned, 
   ROUND(COUNT(customer_id)*100/(SELECT COUNT(DISTINCT customer_id) FROM foodie_fi.subscriptions),1) AS PercentCustomersChurned
FROM foodie_fi.subscriptions 
WHERE plan_id = 4;
-----------------------------------------
-- 5. How many the customers have churned straight after their initial free trial — what the percentage is this rounded to the nearest whole number?

WITH cte_churn AS (
	SELECT
		*,
        LAG(plan_id, 1) OVER(PARTITION BY customer_id ORDER BY plan_id) AS prev_plan
	FROM subscriptions)
SELECT
	COUNT(prev_plan) AS TotalCustomers,
    ROUND(COUNT(*) * 100/(SELECT COUNT(DISTINCT customer_id) FROM subscriptions),0) AS percent
FROM cte_churn
WHERE plan_id = 4 and prev_plan = 0;

with cte_nextplan as(
select customer_id, plan_id, lead(plan_id) over (partition by customer_id) as next_plan
from foodie_fi.subscriptions )
select 
	count(distinct customer_id) as TotalCustomers, 
    round(count(customer_id)*100/(select count(distinct customer_id) from foodie_fi.subscriptions),1) as Percent
from cte_nextplan 
where plan_id = 0 and next_plan = 4;
---------------------------------------
-- 6. What is the number and percentage of customer plans after their initial free trial?

with cte_rank as(
select s.customer_id, s.plan_id,row_number() over (partition by s.customer_id) as ranking
from foodie_fi.subscriptions as s)
select 
	p.plan_name, 
    c.plan_id, count(c.customer_id) as Customers, 
    round(count(c.customer_id)*100/(select count(distinct customer_id) from foodie_fi.subscriptions),1) as Percent
from cte_rank as c
inner join foodie_fi.plans as p
on p.plan_id = c.plan_id
where ranking=2
group by p.plan_name,c.plan_id;
---------------------------------------
-- 7. What is the customer count and percentage breakdown of all 5 plan_name values at 2020-12-31?

with cte_rank as(
	select 
		s.customer_id, s.plan_id,
        start_date,row_number() over (partition by s.customer_id order by start_date desc) as ranking
from foodie_fi.subscriptions as s
where start_date <= '2020-12-31')
select 
	p.plan_name, 
    c.plan_id, count(c.customer_id) as Customers, round(count(c.customer_id)*100/(select count(distinct customer_id) from foodie_fi.subscriptions),1) as Percent
from cte_rank as c
inner join foodie_fi.plans as p
on p.plan_id = c.plan_id
where ranking=1
group by p.plan_name,c.plan_id; 
-------------------------------------
-- 8. How many customers have upgraded to an annual plan in 2020?

select 
	count(distinct customer_id) as TotalAnnualProCustomers
from subscriptions 
where plan_id =3 and year(start_date)=2020;
------------------------------------
-- 9. How many days on average does it take for a customer to an annual plan from the day they join Foodie-Fi?

WITH annual_plan AS (
	SELECT
		customer_id,
        start_date AS annual_date
	FROM subscriptions
    	WHERE plan_id = 3),
trial_plan AS (
	SELECT
		customer_id,
        start_date AS trial_date
	FROM subscriptions
    WHERE plan_id = 0
)
SELECT
	ROUND(AVG(DATEDIFF(annual_date, trial_date)),0) AS avg_Days
FROM annual_plan ap
JOIN trial_plan tp ON ap.customer_id = tp.customer_id;
--------------------------------------
-- 10. Can you further breakdown this average value into 30 day periods (i.e. 0-30 days, 31-60 days etc)

WITH annual_plan AS (
	SELECT
		customer_id,
        start_date AS annual_date
	FROM subscriptions
    WHERE plan_id = 3),
trial_plan AS (
	SELECT
		customer_id,
        start_date AS trial_date
	FROM subscriptions
    WHERE plan_id = 0
),
day_period AS (
SELECT
	DATEDIFF(annual_date, trial_date) AS diff
FROM trial_plan tp
LEFT JOIN annual_plan ap ON tp.customer_id = ap.customer_id
WHERE annual_date is not null
),
bins AS (
SELECT
	*, FLOOR(diff/30) AS bins
FROM day_period)
SELECT
	CONCAT((bins * 30) + 1, ' - ', (bins + 1) * 30, ' days ') AS days,
	COUNT(diff) AS total
FROM bins
GROUP BY bins;
----------------------------------------------
-- 11. How many customers downgraded from a pro monthly to a basic monthly plan in 2020?

WITH next_plan AS (
	SELECT 
		*,
		LEAD(plan_id, 1) OVER(PARTITION BY customer_id ORDER BY start_date, plan_id) AS plan
	FROM subscriptions)
SELECT
	COUNT(DISTINCT customer_id) AS num_downgrade
FROM next_plan np
LEFT JOIN plans p ON p.plan_id = np.plan_id
WHERE p.plan_name = 'pro monthly' AND np.plan = 1 AND start_date <= '2020-12-31';