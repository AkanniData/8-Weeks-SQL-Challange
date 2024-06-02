-- A. Pizza Metrics (SOLUTION)
----------------------------------------------------
-- How many pizzas were ordered?
use pizza_runner;

SELECT COUNT(*) as num_pizzas_ordered
FROM customer_orders;
---------------------------------------------------
-- How many unique customer orders were made?
SELECT COUNT(DISTINCT customer_id) as num_unique_orders
FROM customer_orders;
---------------------------------------------------
-- How many successful orders were delivered by each runner?
SELECT 
	runner_id, 
    COUNT(*) as num_successful_orders
FROM runner_orders
WHERE cancellation IS NULL
GROUP BY runner_id;
-------------------------------------------------
-- How many of each type of pizza was delivered?
SELECT 
	pizza_names.pizza_name,
    COUNT(*) as num_delivered
FROM customer_orders
JOIN pizza_names 
	ON customer_orders.pizza_id = pizza_names.pizza_id
JOIN runner_orders 
	ON customer_orders.order_id = runner_orders.order_id
WHERE runner_orders.cancellation IS NULL
GROUP BY pizza_names.pizza_name;
--------------------------------------------------
-- How many Vegetarian and Meatlovers were ordered by each customer?
SELECT customer_id, 
       SUM(CASE WHEN pizza_names.pizza_name = 'Meatlovers' THEN 1 ELSE 0 END) AS num_meatlovers,
       SUM(CASE WHEN pizza_names.pizza_name = 'Vegetarian' THEN 1 ELSE 0 END) AS num_vegetarian
FROM customer_orders
JOIN pizza_names 
	ON customer_orders.pizza_id = pizza_names.pizza_id
GROUP BY customer_id;
------------------------------------------------
-- What was the maximum number of pizzas delivered in a single order?
SELECT MAX(num_pizzas) AS max_pizzas_per_order
FROM (
  SELECT 
	co.order_id, 
    COUNT(*) AS num_pizzas
  FROM customer_orders co
  JOIN runner_orders ro
	ON co.order_id = ro.order_id
  WHERE ro.cancellation IS NULL 
GROUP BY order_id
) AS pizza_counts;
------------------------------------------------
-- For each customer, how many delivered pizzas had at least 1 change and how many had no changes?
SELECT customer_id, 
       SUM(CASE WHEN exclusions <> '' OR extras <> '' THEN 1 ELSE 0 END) AS num_pizzas_with_changes,
       SUM(CASE WHEN exclusions = '' AND extras = '' THEN 1 ELSE 0 END) AS num_pizzas_with_no_changes
FROM customer_orders
JOIN runner_orders ON customer_orders.order_id = runner_orders.order_id
WHERE runner_orders.cancellation IS NULL
GROUP BY customer_id;
-------------------------------------------------
-- How many pizzas were delivered that had both exclusions and extras?
SELECT COUNT(
     CASE WHEN exclusions != '' AND extras != '' THEN 1 END
   ) AS pizza_with_exclu_and_extr
FROM customer_orders
JOIN runner_orders
USING(order_id)
WHERE cancellation NOT IN ('Restaurant Cancellation', 'Customer Cancellation')
---------------------------------------------------
-- What was the total volume of pizzas ordered for each hour of the day?
SELECT 
	HOUR(order_time) AS hour_of_day,
    COUNT(*) AS num_pizzas_ordered
FROM customer_orders
GROUP BY hour_of_day;
---------------------------------------------------
-- What was the volume of orders for each day of the week?
SELECT 
	DAYNAME(order_time) AS day_of_week, 
    COUNT(*) AS num_orders
FROM customer_orders
GROUP BY day_of_week;


-- B. Runner and Customer Experience (SOLUTION)
--------------------------------------------------
-- Q1. How many runners signed up for each 1 week period? 

SELECT 
    YEARWEEK(registration_date, 1) AS week, 
    COUNT(*) AS num_runners
FROM 
    runners
Where registration_date >= 2021-01-01
GROUP BY 
    YEARWEEK(registration_date, 1);
------------------------------------------------
-- Q2.What was the average time in minutes it took for each runner to arrive at the Pizza Runner HQ to pickup the order?

SELECT 
    runner_id, 
    AVG(TIME_TO_SEC(TIMEDIFF(pickup_time, order_time))/60) AS avg_pickup_time_in_minutes
FROM 
    runner_orders
JOIN 
    customer_orders ON runner_orders.order_id = customer_orders.order_id
GROUP BY 
    runner_id;
------------------------------------------------
-- Q3. Is there any relationship between the number of pizzas and how long the order takes to prepare?

SELECT 
    COUNT(*) AS num_pizzas,
    AVG(TIME_TO_SEC(TIMEDIFF(pickup_time, order_time))/60) AS avg_prep_time_in_minutes
FROM 
    customer_orders
JOIN 
    runner_orders ON customer_orders.order_id = runner_orders.order_id
ORDER BY 
    num_pizzas;
-------------------------------------------
-- Q4. What was the average distance travelled for each customer?
    
with cte as (
select c.customer_id, round(avg(r.distance),1) as AvgDistance
from customer_orders as c
inner join runner_orders as r
on c.order_id = r.order_id
where r.distance != 0
group by c.customer_id)
select * from cte;
---------------------------------------------
-- Q5. What was the difference between the longest and shortest delivery times for all orders?

with cte as(
select c.order_id, order_time, pickup_time, timestampdiff(minute, order_time,pickup_time) as TimeDiff1
from customer_orders as c
inner join runner_orders as r
on c.order_id = r.order_id
where distance != 0
group by c.order_id, order_time, pickup_time)
select max(TimeDiff1) - min(TimeDiff1) as DifferenceTime from cte;
-------------------------------------------
-- Q6. What was the average speed for each runner for each delivery and do you notice any trend for these values?

SELECT 
    runner_id,
    order_id,
    distance,
    duration,
    ROUND(distance *60/duration,1) AS speedKMH
FROM 
    runner_orders
ORDER BY 
    runner_id, order_id;
-------------------------------------------
-- Q7. What is the successful delivery percentage for each runner?

SELECT
  runner_id,
  COUNT(pickup_time) as delivered,
  COUNT(order_id) AS total,
  ROUND(COUNT(pickup_time)/COUNT(order_id)*100) AS delivery_percent
FROM runner_orders
GROUP BY runner_id
ORDER BY runner_id;

with cte as(
select runner_id, sum(case
when distance != 0 then 1
else 0
end) as percsucc, count(order_id) as TotalOrders
from runner_orders1
group by runner_id)
select runner_id,round((percsucc/TotalOrders)*100) as Successfulpercentage 
from cte
order by runner_id;
-------------------------------------------
-- C. Ingredient Optimisation
-------------------------------------------
-- What are the standard ingredients for each pizza?

with cte as (
select pizza_names.pizza_name,pizza_recipes.pizza_id, pizza_toppings.topping_name
from pizza_recipes
inner join pizza_toppings
on pizza_recipes.toppings = pizza_toppings.topping_id
inner join pizza_names
on pizza_names.pizza_id = pizza_recipes.pizza_id
order by pizza_name, pizza_recipes.pizza_id)
select pizza_name, group_concat(topping_name) as StandardToppings
from cte
group by pizza_name;
--------------------------------------------
-- 2. What was the most commonly added extra?

SELECT extras, COUNT(extras) AS extra_count
FROM customer_orders
WHERE extras != ''
GROUP BY extras
ORDER BY extra_count DESC
LIMIT 1;
-----------------------------------------
-- 3. What was the most common exclusion?

SELECT 
	exclusions,
    COUNT(*) AS exclusion_count
FROM customer_orders
WHERE exclusions != ''
GROUP BY exclusions
ORDER BY exclusion_count DESC
LIMIT 1;
-------------------------------------
-- 4. Generate an order item for each record in the customers_orders table in the format of one of the following:
-- Meat Lovers
-- Meat Lovers - Exclude Beef
-- Meat Lovers - Extra Bacon
-- Meat Lovers - Exclude Cheese, Bacon - Extra Mushroom, Peppers

select customer_orders.order_id, customer_orders.pizza_id, pizza_names.pizza_name, customer_orders.exclusions, customer_orders.extras, 
case
when customer_orders.pizza_id = 1 and (exclusions is null or exclusions=0) and (extras is null or extras=0) then 'Meat Lovers'
when customer_orders.pizza_id = 2 and (exclusions is null or exclusions=0) and (extras is null or extras=0) then 'Veg Lovers'
when customer_orders.pizza_id = 2 and (exclusions =4 ) and (extras is null or extras=0) then 'Veg Lovers - Exclude Cheese'
when customer_orders.pizza_id = 1 and (exclusions =4 ) and (extras is null or extras=0) then 'Meat Lovers - Exclude Cheese'
when customer_orders.pizza_id=1 and (exclusions like '%3%' or exclusions =3) and (extras is null or extras=0) then 'Meat Lovers - Exclude Beef'
when customer_orders.pizza_id =1 and (exclusions is null or exclusions=0) and (extras like '%1%' or extras =1) then 'Meat Lovers - Extra Bacon'
when customer_orders.pizza_id=1 and (exclusions like '1, 4' ) and (extras like '6, 9') then 'Meat Lovers - Exclude Cheese, Bacon - Extra Mushroom, Peppers'
when customer_orders.pizza_id=1 and (exclusions like '2, 6' ) and (extras like '1, 4') then 'Meat Lovers - Exclude BBQ Sauce,Mushroom - Extra Bacon, Cheese'
when customer_orders.pizza_id=1 and (exclusions =4) and (extras like '1, 5') then 'Meat Lovers - Exclude Cheese - Extra Bacon, Chicken'
end as OrderItem
from customer_orders
inner join pizza_names
on pizza_names.pizza_id = customer_orders.pizza_id;
-------------------------------------
-- 5. Generate an alphabetically ordered comma separated ingredient list for each pizza order from the customer_orders table and add a 2x in front of any relevant ingredients
-- For example: "Meat Lovers: 2xBacon, Beef, ... , Salami"

WITH cte_toppings AS (
	SELECT
		pt.topping_name,
		tpr.pizza_id,
        pn.pizza_name
	FROM pizza_recipes tpr
    JOIN pizza_toppings pt ON pt.topping_id = tpr.toppings
    JOIN pizza_names pn ON pn.pizza_id = tpr.pizza_id
    ORDER BY pn.pizza_name),
topping_group AS (
SELECT
	pizza_id,
	GROUP_CONCAT(topping_name) AS toppings
FROM cte_toppings
GROUP BY pizza_id)
SELECT
	tco.order_id,
    tco.customer_id,
    tco.pizza_id,
	tco.exclusions, 
    tco.extras,
    tco.order_time,
    CASE
		WHEN ct.pizza_id = 1 THEN CONCAT(ct.pizza_name, ":", " ", "2x", " ", tg.toppings)
        WHEN ct.pizza_id = 2 THEN CONCAT(ct.pizza_name, ":", " ", "2x", " ", tg.toppings)
	END AS ingredient_list
FROM cte_toppings ct
LEFT JOIN topping_group tg ON tg.pizza_id = ct.pizza_id
LEFT JOIN customer_orders tco ON tg.pizza_id = tco.pizza_id
GROUP BY tco.order_id, tco.exclusions;
----------------------------------------
-- 6. What is the total quantity of each ingredient used in all delivered pizzas sorted by most frequent first?

SELECT
  pt.topping_name,
  SUM(
    IF(FIND_IN_SET(pt.topping_id, pr.toppings) AND FIND_IN_SET(co.order_id, ro.order_id), 1, 0)
  ) AS total_quantity
FROM
  customer_orders co
  JOIN pizza_recipes pr ON co.pizza_id = pr.pizza_id
  JOIN pizza_toppings pt ON FIND_IN_SET(pt.topping_id, pr.toppings)
  LEFT JOIN runner_orders ro ON co.order_id = ro.order_id AND ro.cancellation IS NULL
 GROUP BY
  pt.topping_name
ORDER BY
  total_quantity DESC;
  ---------------------------------------
  #D. Pricing and Ratings
  ----------------------------------------
  -- 1. If a Meat Lovers pizza costs $12 and Vegetarian costs $10 and there were no charges for changes 
  -- how much money has Pizza Runner made so far if there are no delivery fees?
  
  SELECT SUM(
  CASE
    WHEN pizza_name = 'Meatlovers' THEN 12
    WHEN pizza_name = 'Vegetarian' THEN 10
    ELSE 0
  END
) AS total_revenue
FROM customer_orders
JOIN pizza_names ON customer_orders.pizza_id = pizza_names.pizza_id;
---------------------------------------------
-- 2. What if there was an additional $1 charge for any pizza extras?
-- Add cheese is $1 extra

set @basecost = 160;
select (LENGTH(group_concat(extras)) - LENGTH(REPLACE(group_concat(extras), ',', '')) + 1) + @basecost as Total
from customer_orders
inner join runner_orders
on customer_orders.order_id = runner_orders.order_id
where extras is not null and extras !=0 and distance is not null;
---------------------------------------------
-- 3. The Pizza Runner team now wants to add an additional ratings system that allows customers to rate their runner, how would you design an additional table for this new dataset 
-- generate a schema for this new table and insert your own data for ratings for each successful customer order between 1 to 5.

SELECT * FROM ratings;
-------------------------------------------
-- 4. Using your newly generated table - can you join all of the information together to form a table which has the following information for successful deliveries?
-- customer_id
-- order_id
-- runner_id
-- rating
-- order_time
-- pickup_time
-- Time between order and pickup
-- Delivery duration
-- Average speed
-- Total number of pizzas

SELECT
	tco.customer_id,
    tco.order_id,
    tro.runner_id,
    rt.rating,
    tco.order_time,
    tro.pickup_time,
    MINUTE(TIMEDIFF(tco.order_time, tro.pickup_time)) AS time_order_pickup,
    tro.duration,
    ROUND(avg(60 * tro.distance / tro.duration), 1) AS avg_speed,
    COUNT(tco.pizza_id) AS num_pizza
FROM customer_orders tco
JOIN runner_orders tro ON tco.order_id = tro.order_id
JOIN ratings rt ON tco.order_id = rt.order_id
GROUP BY tco.customer_id, tco.order_id, tro.runner_id, rt.rating, tco.order_time, tro.pickup_time, time_order_pickup, tro.duration
ORDER BY rt.rating desc;
------------------------------------------
-- 5. If a Meat Lovers pizza was $12 and Vegetarian $10 fixed prices with no cost for extras and each runner is paid $0.30 per kilometre traveled 
-- how much money does Pizza Runner have left over after these deliveries?

set @pizzaamountearned = 160;
select @pizzaamountearned - (sum(distance))*0.3 as Finalamount
from runner_orders;


  