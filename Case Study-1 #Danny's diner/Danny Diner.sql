-- 1. What is the total amount each customer spent at the restaurant?
use dannys_diner;

SELECT 
	customer_id , 
    SUM(price) total_amount_spent
FROM sales s
LEFT JOIN menu m
  ON s.product_id = m.product_id
GROUP BY customer_id;

-- 2. How many days has each customer visited the restaurant?
SELECT 
	customer_id, 
    COUNT(DISTINCT(order_date)) no_of_days_visited
FROM sales
GROUP BY customer_id;

-- 3. What was the first item from the menu purchased by each customer?
SELECT 
	customer_id,
    product_name, 
    order_date
FROM sales s
LEFT JOIN menu m
  ON s.product_id = m.product_id
WHERE order_date = '2021-01-01' 
ORDER BY customer_id;

-- 4. What is the most purchased item on the menu and how many times was it purchased by all customers?
SELECT 
	product_name, 
    COUNT(product_name) AS times_purchased
FROM sales s
LEFT JOIN menu m
  USING (product_id)
GROUP BY product_name
ORDER BY times_purchased desc
LIMIT 1;

-- 5. Which item was the most popular for each customer?
SELECT 
	customer_id, 
    product_name, 
    COUNT(product_name) AS times_purchased 
FROM sales s 
LEFT JOIN menu m 
  USING (product_id)
GROUP BY customer_id, product_name
ORDER BY times_purchased DESC

-- 6. Which item was purchased first by the customer after they became a member?
-- Customer A
SELECT 
	customer_id,
    order_date,
    product_name 
FROM sales 
LEFT JOIN menu 
  USING (product_id)
WHERE customer_id = 'A' AND order_date > '2021-01-07' -- date after membership
ORDER BY order_date
LIMIT 1
-- Customer B
SELECT 
	customer_id,
    order_date,
    product_name 
FROM sales 
LEFT JOIN menu 
  USING (product_id)
WHERE customer_id = 'B' AND order_date > '2021-01-09' -- date after membership
ORDER BY order_date
LIMIT 1

-- 7. Which item was purchased just before the customer became a member?
-- Customer A
SELECT 
	customer_id, 
    order_date,
    product_name 
FROM sales 
LEFT JOIN menu 
  USING (product_id)
WHERE customer_id = 'A' AND order_date < '2021-01-07' -- dates before membership
ORDER BY order_date DESC
-- Customer B
SELECT 
	customer_id,
    order_date, 
    product_name 
FROM sales
LEFT JOIN menu 
  USING (product_id)
WHERE customer_id = 'B' AND order_date < '2021-01-09' -- get dates before membership
ORDER BY order_date DESC -- to capture closest date before membership
LIMIT 1;

-- 8. What is the total items and amount spent for each member before they became a member?
SELECT 
	customer_id,
    COUNT(DISTINCT(product_id)) as total_items, 
    SUM(price) as amount_spent 
FROM sales s
JOIN members m
USING (customer_id)
JOIN menu
USING (product_id)
WHERE s.order_date < m.join_date
GROUP BY customer_id;

-- 9. If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?
SELECT 
	customer_id,
SUM(CASE
    WHEN product_name = 'sushi' THEN 20 * price
    ELSE 10 * price
END) total_points
FROM sales
LEFT JOIN menu 
  USING (product_id)
GROUP BY customer_id;

-- 10. In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi 
-- how many points do customer A and B have at the end of January?
WITH cte_OfferValidity AS 
    (SELECT s.customer_id, m.join_date, s.order_date,
        date_add(m.join_date, interval(6) DAY) firstweek_ends, menu.product_name, menu.price
    FROM sales s
    LEFT JOIN members m
      ON s.customer_id = m.customer_id
    LEFT JOIN menu
        ON s.product_id = menu.product_id)
SELECT customer_id,
    SUM(CASE
            WHEN order_date BETWEEN join_date AND firstweek_ends THEN 20 * price 
            WHEN (order_date NOT BETWEEN join_date AND firstweek_ends) AND product_name = 'sushi' THEN 20 * price
            ELSE 10 * price
        END) points
FROM cte_OfferValidity
WHERE order_date < '2021-02-01' -- filter jan points only
GROUP BY customer_id;

-- Bonus Questions
-- Join All The Things
-- The following questions are related creating basic data tables that Danny and his team can use to quickly derive insights without needing to join the underlying tables using SQL.
CREATE VIEW order_member_status AS
SELECT 
	s.customer_id, 
    s.order_date, 
    product_name, price,
  (
    CASE
     WHEN s.order_date >= '2021-01-07' AND m.join_date IS NOT NULL THEN 'Y' 
     WHEN s.order_date >= '2021-01-09' AND m.join_date IS NOT NULL THEN 'Y'
    ELSE 'N'
    END
  ) AS MEMBER
FROM sales s
LEFT JOIN members m
USING (customer_id)
JOIN menu mu
USING (product_id);

SELECT * FROM order_member_status;

----------------------------------------------------
WITH cte AS
  (SELECT 
	s.customer_id,
    order_date, 
    menu.product_name,
    menu.price, 
    CASE
      WHEN s.order_date >= '2021-01-07' AND m.join_date IS NOT NULL THEN 'Y' 
      WHEN s.order_date >= '2021-01-09' AND m.join_date IS NOT NULL THEN 'Y'
      ELSE 'N'
    END AS member
  FROM sales s
  LEFT JOIN menu 
    ON s.product_id = menu.product_id
  LEFT JOIN members m
    ON s.customer_id = m.customer_id)
SELECT *, 
  CASE
    WHEN member = 'N' THEN NULL 
    ELSE RANK() OVER w
  END AS ranking
FROM cte
WINDOW w AS (PARTITION BY s.customer_id, member ORDER BY s.order_date)


