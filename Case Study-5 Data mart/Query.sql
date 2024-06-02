-- 1. Data Cleansing Steps
-- In a single query, perform the following operations and generate a new table in the data_mart schema named clean_weekly_sales:
-- Convert the week_date to a DATE format
-- Add a week_number as the second column for each week_date value, for example any value from the 1st of January to 7th of January will be 1, 8th to 14th will be 2 etc
-- Add a month_number with the calendar month for each week_date value as the 3rd column
-- Add a calendar_year column as the 4th column containing either 2018, 2019 or 2020 values
-- Add a new column called age_band after the original segment column using the following mapping on the number inside the segment value

-- I temporarily disable safe update mode for the current session by executing the following SQL statement before i UPDATE
SET SQL_SAFE_UPDATES = 0;

------------------------- 
-- to change the week_date datatype
ALTER TABLE weekly_sales MODIFY COLUMN week_date DATE;
UPDATE weekly_sales SET week_date = STR_TO_DATE(week_date, '%Y-%m-%d');

-- creating the clean_weekly_sales table
CREATE TABLE clean_weekly_sales AS
SELECT 
    week_date,
    WEEK(week_date) AS week_number,
    MONTH(week_date) AS month_number,
    YEAR(week_date) AS calendar_year,
    region,
    platform,
    segment,
    CASE
        WHEN RIGHT(segment, 1) = '1' THEN 'Young Adults'
        WHEN RIGHT(segment, 1) = '2' THEN 'Middle Aged'
        WHEN RIGHT(segment, 1) IN ('3', '4') THEN 'Retirees'
        ELSE 'Unknown'
    END AS age_band, 
    CASE
        WHEN LEFT(segment, 1) = 'C' THEN 'Couples'
        WHEN LEFT(segment, 1) = 'F' THEN 'Families'
        ELSE 'Unknown'
    END AS demographic,
    customer_type, 
    transactions, 
    sales,
    ROUND((CAST(sales AS DECIMAL) / transactions), 2) AS avg_transactions
FROM 
    weekly_sales;
    
-- After executing My UPDATE statement, I set it back to 1 for safety:
SET SQL_SAFE_UPDATES = 1;
-- I choose the option that best suits my needs and workflow. I wa not sure about the implications of disabling safe update mode.

-- to view the table
SELECT * FROM clean_weekly_sales;

-- Data Exploration
-- There are 9 questions in this section. Here, I got an overview of the state of affairs at Data Mart.

-- 1. What day of the week is used for each week_date value?
SELECT DISTINCT DAYNAME(week_date) AS day_of_week
FROM clean_weekly_sales;

-- 2. What range of week numbers are missing from the dataset?
SELECT t.num AS missing_week
FROM (
  SELECT num FROM 
  (SELECT 1 AS num UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9 UNION ALL SELECT 10 UNION ALL
   SELECT 11 AS num UNION ALL SELECT 12 UNION ALL SELECT 13 UNION ALL SELECT 14 UNION ALL SELECT 15 UNION ALL SELECT 16 UNION ALL SELECT 17 UNION ALL SELECT 18 UNION ALL SELECT 19 UNION ALL SELECT 20 UNION ALL
   SELECT 21 AS num UNION ALL SELECT 22 UNION ALL SELECT 23 UNION ALL SELECT 24 UNION ALL SELECT 25 UNION ALL SELECT 26 UNION ALL SELECT 27 UNION ALL SELECT 28 UNION ALL SELECT 29 UNION ALL SELECT 30 UNION ALL
   SELECT 31 AS num UNION ALL SELECT 32 UNION ALL SELECT 33 UNION ALL SELECT 34 UNION ALL SELECT 35 UNION ALL SELECT 36 UNION ALL SELECT 37 UNION ALL SELECT 38 UNION ALL SELECT 39 UNION ALL SELECT 40 UNION ALL
   SELECT 41 AS num UNION ALL SELECT 42 UNION ALL SELECT 43 UNION ALL SELECT 44 UNION ALL SELECT 45 UNION ALL SELECT 46 UNION ALL SELECT 47 UNION ALL SELECT 48 UNION ALL SELECT 49 UNION ALL SELECT 50 UNION ALL
   SELECT 51 AS num UNION ALL SELECT 52) AS numbers
) AS t
LEFT JOIN clean_weekly_sales AS wsc ON t.num = wsc.week_number
WHERE wsc.week_number IS NULL;

-- 3. How many total transactions were there for each year in the dataset?
SELECT
  calendar_year,
  COUNT(transactions) AS num_transactions,
  SUM(transactions) AS total_transactions
FROM
  clean_weekly_sales
GROUP BY  
  calendar_year;

-- 4. What is the total sales for each region for each month?
SELECT
  region,
  month_number,
  COUNT(sales) AS count_sales,
  SUM(sales) AS total_sales
FROM 
  clean_weekly_sales
GROUP BY
  region, month_number
ORDER BY 
  month_number, total_sales;

-- 5. What is the total count of transactions for each platform
SELECT
  platform,
  COUNT(*) AS count_platform,
  SUM(transactions) AS total_transactions
FROM
  clean_weekly_sales
GROUP BY
  platform;
  
-- 6. What is the percentage of sales for Retail vs Shopify for each month? 
    WITH monthly_sales AS
(SELECT 
  calendar_year, month_number, platform, SUM(sales) AS monthly_sales 
FROM clean_weekly_sales 
GROUP BY calendar_year, month_number, platform 
ORDER BY calendar_year, month_number, platform)

SELECT 
calendar_year, month_number,
ROUND(100*MAX(CASE
	           WHEN platform="Retail" THEN monthly_sales ELSE NULL END)/SUM(monthly_sales), 2) AS retail_sales_percentage,
ROUND(100*MAX(CASE
	           WHEN platform="Shopify" THEN monthly_sales ELSE NULL END)/SUM(monthly_sales), 2) AS shopify_sales_percentage
FROM monthly_sales
GROUP BY calendar_year, month_number;

    
-- 7. What is the percentage of sales by demographic for each year in the dataset?
WITH yearly_sales AS
(SELECT 
  calendar_year, demographic, SUM(sales) AS yearly_sales 
FROM clean_weekly_sales 
GROUP BY calendar_year, demographic 
ORDER BY calendar_year)

SELECT 
  calendar_year,
  ROUND(100*MAX(CASE WHEN demographic="Couples" THEN yearly_sales ELSE NULL END)/SUM(yearly_sales), 2) AS couples_percentage,
  ROUND(100*MAX(CASE WHEN demographic="Families" THEN yearly_sales ELSE NULL END)/SUM(yearly_sales), 2) AS Families_percentage,
  ROUND(100*MAX(CASE WHEN demographic="unknown" THEN yearly_sales ELSE NULL END)/SUM(yearly_sales), 2) AS unknown_percentage
FROM yearly_sales
GROUP BY calendar_year;

-- 8. Which age_band and demographic values contribute the most to Retail sales?
WITH retail_sales AS 
(SELECT 
  age_band, demographic, SUM(sales) AS total_retail_sales 
FROM clean_weekly_sales 
WHERE platform = "Retail" 
GROUP BY age_band, demographic 
ORDER BY total_retail_sales DESC)

SELECT 
  age_band, demographic, total_retail_sales, 
  ROUND(100*(total_retail_sales/SUM(total_retail_sales) OVER()), 2) AS retail_sales_contribution_pct 
FROM retail_sales 
ORDER BY retail_sales_contribution_pct DESC;

-- 9. Can we use the avg_transaction column to find the average transaction size for each year for Retail vs Shopify? If not - how would you calculate it instead?
SELECT 
  calendar_year, platform, ROUND(SUM(sales)/SUM(transactions), 0) AS transaction_size 
FROM clean_weekly_sales 
GROUP BY calendar_year, platform 
ORDER BY calendar_year;


-- 3. Before & After Analysis
-- This technique is usually used when we inspect an important event and want to inspect the impact before and after a certain point in time.
-- Taking the week_date value of 2020-06-15 as the baseline week where the Data Mart sustainable packaging changes came into effect.
-- We would include all week_date values for 2020-06-15 as the start of the period after the change and the previous week_date values would be before

-- Using this analysis approach - answer the following questions:
-- What is the total sales for the 4 weeks before and after 2020-06-15? What is the growth or reduction rate in actual values and percentage of sales?
WITH sales_per_week_before_after AS
(
    SELECT 
        SUM(CASE 
                WHEN (week_number BETWEEN 20 AND 23) AND (calendar_year = 2020) THEN sales 
                ELSE 0
            END) AS sales_per_week_before,
        SUM(CASE
                WHEN (week_number BETWEEN 24 AND 27) AND (calendar_year = 2020) THEN sales 
                ELSE 0
            END) AS sales_per_week_after
    FROM clean_weekly_sales
    WHERE calendar_year = 2020
),
total_sales_before_after AS
(
    SELECT
        SUM(sales_per_week_before) AS before_change_sales,
        SUM(sales_per_week_after) AS after_change_sales 
    FROM sales_per_week_before_after
)

SELECT 
    before_change_sales,
    after_change_sales,
    (after_change_sales - before_change_sales) AS difference, 
    (100 * (after_change_sales - before_change_sales) / before_change_sales) AS pct_variance 
FROM total_sales_before_after;

-- 2. What about the entire 12 weeks before and after?
WITH sales_per_week_before_after AS
(SELECT 
    SUM(CASE 
            WHEN (week_number BETWEEN 12 AND 23) AND (calendar_year="2020") THEN sales 
	END) AS sales_per_week_before,
    SUM(CASE
            WHEN (week_number BETWEEN 24 AND 35) AND (calendar_year="2020") THEN sales 
	END) AS sales_per_week_after
FROM clean_weekly_sales
GROUP BY calendar_year, week_number, week_date 
ORDER BY week_number),

total_sales_before_after AS
(SELECT 
  SUM(sales_per_week_before) AS before_change_sales, SUM(sales_per_week_after) AS after_change_sales 
FROM sales_per_week_before_after)

SELECT 
  before_change_sales, after_change_sales, (after_change_sales - before_change_sales) as difference, 
  (100*(after_change_sales - before_change_sales)/before_change_sales) AS pct_variance 
FROM total_sales_before_after;

-- 3. How do the sale metrics for these 2 periods before and after compare with the previous years in 2018 and 2019?
WITH sales_per_week_before_after AS
(SELECT calendar_year,
	SUM(CASE 
		WHEN (week_number BETWEEN 20 AND 23) THEN sales 
	END) AS sales_per_week_before,
	SUM(CASE
		WHEN (week_number BETWEEN 24 AND 27) THEN sales 
	END) AS sales_per_week_after
FROM clean_weekly_sales
GROUP BY calendar_year, week_number 
ORDER BY week_number),

total_sales_before_after AS
(SELECT 
  calendar_year, SUM(sales_per_week_before) AS before_change_sales, SUM(sales_per_week_after) AS after_change_sales  
FROM sales_per_week_before_after 
GROUP BY calendar_year 
ORDER BY calendar_year)

SELECT 
  calendar_year, before_change_sales, after_change_sales, (after_change_sales - before_change_sales) AS difference, 
  (100*(after_change_sales - before_change_sales)/before_change_sales) AS pct_variance 
FROM total_sales_before_after;


WITH sales_per_week_before_after AS
(SELECT calendar_year,
	SUM(CASE 
	        WHEN (week_number BETWEEN 12 AND 23) THEN sales 
	END) AS sales_per_week_before,
	SUM(CASE
                WHEN (week_number BETWEEN 24 AND 35) THEN sales 
	END) AS sales_per_week_after
FROM clean_weekly_sales
GROUP BY calendar_year, week_number 
ORDER BY week_number),

total_sales_before_after AS
(SELECT 
  calendar_year, SUM(sales_per_week_before) AS before_change_sales, SUM(sales_per_week_after) AS after_change_sales 
FROM sales_per_week_before_after 
GROUP BY calendar_year 
ORDER BY calendar_year)

SELECT 
  calendar_year, before_change_sales, after_change_sales, (after_change_sales - before_change_sales) AS difference, 
  (100*(after_change_sales - before_change_sales)/before_change_sales) AS pct_variance 
FROM total_sales_before_after;


-- 4. Bonus Question
-- Which areas of the business have the highest negative impact in sales metrics performance in 2020 for the 12 week before and after period?

-- REGION
WITH sales_before_after AS
(SELECT 
  region,
  SUM(CASE 
          WHEN (week_number BETWEEN 12 AND 23) AND (calendar_year="2020") THEN sales 
	END) AS before_change_sales,
  SUM(CASE
          WHEN (week_number BETWEEN 24 AND 35) AND (calendar_year="2020") THEN sales 
	END) AS after_change_sales
FROM clean_weekly_sales
GROUP BY region 
ORDER BY region)
SELECT 
  *, (after_change_sales - before_change_sales) AS difference, 
  100*((after_change_sales - before_change_sales)/before_change_sales) AS pct_variance 
FROM sales_before_after;
-- The new sustainable packaging change had a negative impact on all regions except Europe and Africa. Europe region experience an increase in sales, with a significant rise of approximately 11.12% and Africa region 2.58%
-- The highest negative impact was in Asia with -3.61% decrease in sales

-- PLATFORM
WITH sales_before_after AS
(SELECT 
  platform,
  SUM(CASE 
          WHEN (week_number BETWEEN 12 AND 23) AND (calendar_year="2020") THEN sales 
	END) AS before_change_sales,
  SUM(CASE
          WHEN (week_number BETWEEN 24 AND 35) AND (calendar_year="2020") THEN sales 
	END) AS after_change_sales
FROM clean_weekly_sales
GROUP BY platform 
ORDER BY platform)


SELECT 
  *, (after_change_sales - before_change_sales) AS difference, 
  100*((after_change_sales - before_change_sales)/before_change_sales) AS pct_variance 
FROM sales_before_after;
-- There is a decrease in sales by -0.72 in the retail sales after packaging change 
-- Sales made through Shopify increased by approximately 0.54% following the introduction of sustainable packaging. 
-- This suggests that online customers are more receptive and respond positively to changes compared to retail customers, highlighting Shopify as an effective platform for implementing such changes in the future.

-- AGE_BAND

WITH sales_before_after AS
(SELECT 
  age_band,
  SUM(CASE 
          WHEN (week_number BETWEEN 12 AND 23) AND (calendar_year="2020") THEN sales 
	END) AS before_change_sales,
  SUM(CASE
          WHEN (week_number BETWEEN 24 AND 35) AND (calendar_year="2020") THEN sales 
	END) AS after_change_sales
FROM clean_weekly_sales
GROUP BY age_band 
ORDER BY age_band)


SELECT 
  *, (after_change_sales - before_change_sales) AS difference, 
  100*((after_change_sales - before_change_sales)/before_change_sales) AS pct_variance 
FROM sales_before_after;
-- There is a negative impact on the sales all age band except the unknown which showed a positive of 0.64%
-- The highest negative impact is from the age-band 'Middle Aged' (-2.64%) while the least negative impact is from Retirees(-1.01%)

-- DEMOGRAPHIC

WITH sales_before_after AS
(SELECT 
  demographic,
  SUM(CASE 
          WHEN (week_number BETWEEN 12 AND 23) AND (calendar_year="2020") THEN sales 
	END) AS before_change_sales,
  SUM(CASE
          WHEN (week_number BETWEEN 24 AND 35) AND (calendar_year="2020") THEN sales 
	END) AS after_change_sales
FROM clean_weekly_sales
GROUP BY demographic 
ORDER BY demographic)


SELECT 
  *, (after_change_sales - before_change_sales) AS difference, 
  100*((after_change_sales - before_change_sales)/before_change_sales) AS pct_variance 
FROM sales_before_after;
-- Sustainable packaging had negative impact on sales of couples and families of the demographic
-- Unknown had a positive impact of 0.64% on sales.

-- CUSTOMER_TYPE

WITH sales_before_after AS
(SELECT 
  customer_type,
  SUM(CASE 
          WHEN (week_number BETWEEN 12 AND 23) AND (calendar_year="2020") THEN sales 
	END) AS before_change_sales,
  SUM(CASE
          WHEN (week_number BETWEEN 24 AND 35) AND (calendar_year="2020") THEN sales 
	END) AS after_change_sales
FROM clean_weekly_sales
GROUP BY customer_type 
ORDER BY customer_type)


SELECT 
  *, (after_change_sales - before_change_sales) AS difference, 
  100*((after_change_sales - before_change_sales)/before_change_sales) AS pct_variance 
FROM sales_before_after;
-- Only Exiting customers showed a negative impact to the new packaging change with -3.19% decrease in sales.
-- Both Guest and New customers responded positively to the new packaging change with 1.36% and 3.69% increase in sales respectively compared to previous 12 weeks 