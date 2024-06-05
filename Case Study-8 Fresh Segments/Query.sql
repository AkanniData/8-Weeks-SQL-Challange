-- Data Exploration and Cleansing
-- 1. Update the fresh_segments.interest_metrics table by modifying the month_year column to be a date data type with the start of the month
-- Drop the existing month_year column

ALTER TABLE fresh_segments.interest_metrics
MODIFY COLUMN month_year DATE;

-- 2. What is count of records in the fresh_segments.interest_metrics for each month_year value sorted in chronological order (earliest to latest) with the null values appearing first?
SELECT 
  month_year, COUNT(*)
FROM fresh_segments.interest_metrics
GROUP BY month_year
ORDER BY month_year IS NULL, month_year;
-- ORDER BY month_year IS NULL orders the results such that rows where month_year is NULL appear first.
-- month_year orders the non-NULL values in ascending order.

-- 3. What do you think we should do with these null values in the fresh_segments.interest_metrics
-- Before dropping the values, it would be useful to find out the percentage of null values.
SELECT 
  ROUND(100 * (SUM(CASE WHEN interest_id IS NULL THEN 1 END) * 1.0 /
    COUNT(*)),2) AS null_perc
FROM fresh_segments.interest_metrics;
-- RESULT; The percentage of null values is 8.36% which is less than 10%, hence I would suggest to drop all the null values.

-- Now delete where interest_id is NULL 
DELETE FROM fresh_segments.interest_metrics
WHERE interest_id IS NULL;

-- Run again to confirm that there are no null values.
SELECT 
  ROUND(100 * (SUM(CASE WHEN interest_id IS NULL THEN 1 END) * 1.0 /
    COUNT(*)),2) AS null_perc
FROM fresh_segments.interest_metrics;

-- 4. How many interest_id values exist in the fresh_segments.interest_metrics table but not in the fresh_segments.interest_map table? What about the other way around?
SELECT count(DISTINCT interest_id) Ids_not_in_maps  
FROM interest_metrics 
WHERE interest_id  NOT IN(select interest_id  FROM interest_map);

SELECT count(id) as Ids_not_in_metrics from interest_map
where id  not in (select interest_id  from interest_metrics );

-- 5. Summarise the id values in the fresh_segments.interest_map by its total record count in this table
-- I found the solution for this question to be strange - hence I came up with another summary of the id values too.
-- original solution;
SELECT COUNT(*)
FROM fresh_segments.interest_map;

SELECT 
	id, 
    interest_name, 
    count
FROM (
  SELECT 
    map.id, 
    map.interest_name, 
    COUNT(*) AS count
  FROM fresh_segments.interest_map map
  JOIN fresh_segments.interest_metrics metrics
    ON map.id = metrics.interest_id
  GROUP BY map.id, map.interest_name
) AS subquery
ORDER BY count DESC, id;
-- Using a Subquery: The COUNT(*) alias is defined in an inner subquery, and the outer query orders by this alias.

-- 6. What sort of table join should we perform for our analysis and why? Check your logic by checking the rows where 'interest_id = 21246' in your joined output and include all columns from fresh_segments.
-- interest_metrics and all columns from fresh_segments.interest_map except from the id column.

SELECT *
FROM fresh_segments.interest_map map
INNER JOIN fresh_segments.interest_metrics metrics
  ON map.id = metrics.interest_id
WHERE metrics.interest_id = 21246   
  AND metrics._month IS NOT NULL; 

-- 7. Are there any records in your joined table where the month_year value is before the created_at value from the fresh_segments.interest_map table? Do you think these values are valid and why?
SELECT 
  COUNT(*)
FROM fresh_segments.interest_map map
INNER JOIN fresh_segments.interest_metrics metrics
  ON map.id = metrics.interest_id
WHERE metrics.month_year < DATE(map.created_at);
-- There are 189 records where the month_year date is before the created_at date.

SELECT 
  COUNT(*)
FROM fresh_segments.interest_map map
INNER JOIN fresh_segments.interest_metrics metrics
  ON map.id = metrics.interest_id
WHERE metrics.month_year < DATE_FORMAT(map.created_at, '%Y-%m-01');
-- 

-- 						Interest Analysis
-- 1. Which interests have been present in all month_year dates in our dataset?
SELECT 
  COUNT(DISTINCT month_year) AS unique_month_year_count, 
  COUNT(DISTINCT interest_id) AS unique_interest_id_count
FROM fresh_segments.interest_metrics;
-- There are 15 distinct month_year dates and 1202 distinct interest_id

WITH interest_cte AS (
  SELECT 
    interest_id, 
    COUNT(DISTINCT month_year) AS total_months
  FROM fresh_segments.interest_metrics
  WHERE month_year IS NOT NULL
  GROUP BY interest_id
)

SELECT 
  c.total_months,
  COUNT(DISTINCT c.interest_id) AS interest_count
FROM interest_cte c
WHERE c.total_months = 14
GROUP BY c.total_months
ORDER BY interest_count DESC;

-- 2. Using this same total_months measure — calculate the cumulative percentage of all records starting at 14 months — which total_months value passes the 90% cumulative percentage value?
with months_count as(
select distinct interest_id, count(month_year) as month_count
from interest_metrics 
group by interest_id
-- order by 2 desc
)
, interests_count as
(
select month_count, count(interest_id) as interest_count
from months_count
group by month_count
)
, cumulative_percentage as
(
select *, round(sum(interest_count)over(order by month_count desc) *100.0/(select sum(interest_count) from interests_count),2) as cumulative_percent
from interests_count
group by month_count, interest_count
)
select *
from cumulative_percentage
where cumulative_percent >90

-- 3. If we were to remove all interest_id values which are lower than the total_months value we found in the previous question — how many total data points would we be removing?
-- Getting interest IDs which have month count less than 6
WITH month_counts AS (
    SELECT interest_id, COUNT(DISTINCT month_year) AS month_count
    FROM interest_metrics
    GROUP BY interest_id
    HAVING COUNT(DISTINCT month_year) < 6
)

-- Getting the number of times the above interest IDs are present in the interest_metrics table
-- Getting the number of times the interest IDs which have month count less than 6 are present in the interest_metrics table
SELECT COUNT(interest_id) AS interest_record_to_remove
FROM interest_metrics
WHERE interest_id IN (
    SELECT interest_id
    FROM (
        SELECT interest_id
        FROM interest_metrics
        GROUP BY interest_id
        HAVING COUNT(DISTINCT month_year) < 6
    ) AS subquery
);



-- Getting the number of times the above interest IDs are present in the interest_metrics table
SELECT COUNT(interest_id) AS interest_record_to_remove
FROM interest_metrics
WHERE interest_id IN (SELECT interest_id FROM month_counts);



