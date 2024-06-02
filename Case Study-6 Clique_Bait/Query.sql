-- 2. Digital Analysis
-- Using the available datasets - answer the following questions using a single query for each one:

-- 1. How many users are there?
SELECT 
  COUNT(DISTINCT user_id) AS user_count
FROM clique_bait.users;

-- 2. How many cookies does each user have on average?
-- The question is asking for the average number of cookies each user has. To achieve this, we need to use either a DISTINCT clause or a GROUP BY clause to ensure we uniquely count the cookies associated with each user.
-- Next, round the average cookie count to 0 decimal points, as having a fraction of a cookie does not make sense.
WITH cookie AS (
  SELECT 
    user_id, 
    COUNT(cookie_id) AS cookie_id_count
  FROM clique_bait.users
  GROUP BY user_id)

SELECT 
  ROUND(AVG(cookie_id_count),0) AS avg_cookie_id
FROM cookie;

-- 3. What is the unique number of visits by all users per month?
-- First, extract the numerical month from event_time to enable grouping the data by month. Use the keyword DISTINCT to ensure uniqueness.
SELECT 
  EXTRACT(MONTH FROM event_time) as month, 
  COUNT(DISTINCT visit_id) AS unique_visit_count
FROM clique_bait.events
GROUP BY EXTRACT(MONTH FROM event_time);

-- 4. What is the number of events for each event type?
SELECT 
  event_type, 
  COUNT(*) AS event_count
FROM clique_bait.events
GROUP BY event_type
ORDER BY event_type;

-- 5. What is the percentage of visits which have a purchase event?
-- Join the events and events_identifier tables and filter for Purchase events only. 
-- Once filtered, count the distinct visit IDs to determine the number of Purchase events. 
-- Then, divide this count by the total number of distinct visits from the events table using a subquery.
SELECT 
  100 * COUNT(DISTINCT e.visit_id)/
    (SELECT COUNT(DISTINCT visit_id) FROM clique_bait.events) AS percentage_purchase
FROM clique_bait.events AS e
JOIN clique_bait.event_identifier AS ei
  ON e.event_type = ei.event_type
WHERE ei.event_name = 'Purchase';

-- 6. What is the percentage of visits which view the checkout page but do not have a purchase event?
-- Create a CTE and using CASE statements, find the MAX() of;
-- Assign "1" to events where event_type = 1 (Page View) and page_id = 12 (Checkout). These events indicate when a user viewed the checkout page.
-- Assign "1" to events where event_type = 3 (Purchase). This events signifies users who made a purchase.
-- Using the table we have created, find the percentage of visits checkout page.
WITH checkout_purchase AS (
    SELECT 
        visit_id,
        MAX(CASE WHEN event_type = 1 AND page_id = 12 THEN 1 ELSE 0 END) AS checkout,
        MAX(CASE WHEN event_type = 3 THEN 1 ELSE 0 END) AS purchase
    FROM clique_bait.events
    GROUP BY visit_id
)

SELECT 
    ROUND(100 * (1 - (SUM(purchase) / SUM(checkout))), 2) AS percentage_checkout_view_with_no_purchase
FROM checkout_purchase;

-- 7. What are the top 3 pages by number of views?

-- Select from the event table and join the page hierarchy, where page view appear
-- Order by descending to retrieve highest to lowest number of views
-- Limit results to 3 to find the top 3
SELECT 
  ph.page_name, 
  COUNT(*) AS page_views
FROM clique_bait.events AS e
JOIN clique_bait.page_hierarchy AS ph
  ON e.page_id = ph.page_id
WHERE e.event_type = 1 -- "Page View"
GROUP BY ph.page_name
ORDER BY page_views DESC 
LIMIT 3; 

-- 8. What is the number of views and cart adds for each product category?
SELECT 
  ph.product_category, 
  SUM(CASE WHEN e.event_type = 1 THEN 1 ELSE 0 END) AS page_views,
  SUM(CASE WHEN e.event_type = 2 THEN 1 ELSE 0 END) AS cart_adds
FROM clique_bait.events AS e
JOIN clique_bait.page_hierarchy AS ph
  ON e.page_id = ph.page_id
WHERE ph.product_category IS NOT NULL
GROUP BY ph.product_category
ORDER BY page_views DESC;  

-- 9. What are the top 3 products by purchases?
WITH purchase_cte AS (
    SELECT DISTINCT visit_id AS purchase_id
    FROM events 
    WHERE event_type = 3
),
page_view_cte AS (
    SELECT 
        p.page_name,
        p.page_id,
        e.visit_id 
    FROM events e
    LEFT JOIN page_hierarchy p ON p.page_id = e.page_id
    WHERE p.product_id IS NOT NULL 
      AND e.event_type = 2
)
SELECT 
    page_view_cte.page_name AS Product,
    COUNT(*) AS Quantity_purchased
FROM purchase_cte 
LEFT JOIN page_view_cte ON purchase_cte.purchase_id = page_view_cte.visit_id 
GROUP BY page_view_cte.page_name
ORDER BY COUNT(*) DESC 
LIMIT 3;

-- 3. Product Funnel Analysis
-- Using a single SQL query - create a new output table which has the following details:

How many times was each product viewed?
How many times was each product added to cart?
How many times was each product added to a cart but not purchased (abandoned)?
How many times was each product purchased?

create table Product_Analysis as 
with cte as (
select
  e.visit_id,
        e.cookie_id,
  e.event_type,
  p.page_name,
  p.page_id,
  p.product_category,
        p.product_id
 from events e
 join page_hierarchy p on e.page_id = p.page_id),

cte2 as (
 select page_name,
    product_id,
    product_category,
 case when event_type = 1 then visit_id end as page_view,
 case when event_type = 2 then visit_id end as cart
 from cte 
 where product_id is not null
),

cte3 as (
select visit_id as purchased
from events
where event_type = 3
),
cte4 as(
select page_name, 
product_id,
product_category,
count(page_view) as product_viewed,
count(cart) as product_addedtocart,
count(purchased) as product_purchased,
count(cart) - count(purchased) as product_abadoned
from cte2
left join cte3 on purchased = cart
group by page_name, product_id, product_category)

select * from cte4;

SELECT * FROM Product_Analysis;

-- Additionally, create another table which further aggregates the data for the above points but this time for each product category instead of individual products.
create table Product_category as 
with cte5 as (
select
  e.visit_id,
        e.cookie_id,
  e.event_type,
  p.page_name,
  p.page_id,
  p.product_category,
        p.product_id
 from events e
 join page_hierarchy p on e.page_id = p.page_id),

cte6 as (
select page_name,
    product_category,
 case when event_type = 1 then visit_id end as page_view,
 case when event_type = 2 then visit_id end as cart
 from cte5
 where product_id is not null
),

cte7 as (
select visit_id as purchased
from events
where event_type = 3
),
cte8 as(
select
product_category,
count(page_view) as product_viewed,
count(cart) as product_addedtocart,
count(purchased) as product_purchased,
count(cart) - count(purchased) as product_abadoned
from cte6
left join cte7 on purchased = cart
group by product_category)

select *
from cte8;

SELECT * FROM product_category;

-- Use your 2 new output tables - answer the following questions:
-- Which product had the most views, cart adds and purchases?

SELECT
    page_name,
    product_viewed
FROM product_analysis
WHERE product_viewed = (
    SELECT MAX(product_viewed)
    FROM product_analysis
);


SELECT
    page_name,
    product_addedtocart
FROM product_analysis
WHERE product_addedtocart = (
    SELECT MAX(product_addedtocart)
    FROM product_analysis
);


SELECT
    page_name,
    product_purchased
FROM product_analysis
WHERE product_purchased = (
    SELECT MAX(product_purchased)
    FROM product_analysis
);

-- Which product was most likely to be abandoned?
SELECT
    page_name,
    product_abadoned
FROM product_analysis
WHERE product_abadoned = (
    SELECT max(product_abadoned)
    FROM product_analysis
);

-- Which product had the highest view to purchase percentage?
select page_name, round(100*(product_purchased/product_viewed), 2) as view_to_purchase
from product_analysis
order by 2 desc
limit 1;

-- What is the average conversion rate from view to cart add?
SELECT 
  ROUND(100*AVG(product_addedtocart/product_viewed),2) AS avg_view_to_cart_add_conversion
FROM product_analysis

-- What is the average conversion rate from cart add to purchase?
SELECT 
	ROUND(100*AVG(product_purchased/product_addedtocart),2) AS avg_cart_add_to_purchases_conversion_rate
FROM product_analysis;

-- 3. Campaigns Analysis
-- Generate a table that has 1 single row for every unique visit_id record and has the following columns:
-- user_id
-- visit_id
-- visit_start_time: the earliest event_time for each visit
-- page_views: count of page views for each visit
-- cart_adds: count of product cart add events for each visit
-- purchase: 1/0 flag if a purchase event exists for each visit
-- campaign_name: map the visit to a campaign if the visit_start_time falls between the start_date and end_date
-- impression: count of ad impressions for each visit
-- click: count of ad clicks for each visit
-- (Optional column) cart_products: a comma separated text value with products added to the cart sorted by the order they were added to the cart (hint: use the sequence_number)

SELECT 
  u.user_id, 
  e.visit_id, 
  MIN(e.event_time) AS visit_start_time,
  SUM(CASE WHEN e.event_type = 1 THEN 1 ELSE 0 END) AS page_views,
  SUM(CASE WHEN e.event_type = 2 THEN 1 ELSE 0 END) AS cart_adds,
  SUM(CASE WHEN e.event_type = 3 THEN 1 ELSE 0 END) AS purchase,
  c.campaign_name,
  SUM(CASE WHEN e.event_type = 4 THEN 1 ELSE 0 END) AS impression, 
  SUM(CASE WHEN e.event_type = 5 THEN 1 ELSE 0 END) AS click, 
  GROUP_CONCAT(CASE 
                WHEN p.product_id IS NOT NULL AND e.event_type = 2 
                THEN p.page_name 
                ELSE NULL 
               END ORDER BY e.sequence_number SEPARATOR ', ') AS cart_products
FROM clique_bait.users AS u
INNER JOIN clique_bait.events AS e
  ON u.cookie_id = e.cookie_id
LEFT JOIN clique_bait.campaign_identifier AS c
  ON e.event_time BETWEEN c.start_date AND c.end_date
LEFT JOIN clique_bait.page_hierarchy AS p
  ON e.page_id = p.page_id
GROUP BY u.user_id, e.visit_id, c.campaign_name;

-- This query aggregates user visit data, counting specific event types (page views, cart additions, purchases, impressions, and clicks) and concatenating product names for cart additions. 
-- It groups the results by user and visit, joining relevant campaign and page information, and orders the results by user ID.
-- This allows for a comprehensive analysis of user interactions and campaign effectiveness within the specified time frames.

