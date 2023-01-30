-- Request 1: Provide the list of markets in which customer "Atliq Exclusive" 
--            operates its business in the APAC region.

SELECT DISTINCT(market) FROM dim_customer
WHERE customer = "Atliq Exclusive" and region = "APAC";

-- Request 2: What is the percentage of unique product increase in 2021 vs. 2020? 
--            The final output contains these fields: unique_products_2020, unique_products_2021, 
--            percentage_chg

WITH CTE_2020 AS
(SELECT COUNT(DISTINCT product_code) AS unique_products_2020 
FROM fact_sales_monthly
WHERE fiscal_year = 2020),
CTE_2021 AS
(SELECT COUNT(DISTINCT product_code) AS unique_products_2021 
FROM fact_sales_monthly
WHERE fiscal_year = 2021)
SELECT unique_products_2020, unique_products_2021, 
ROUND((unique_products_2021 - unique_products_2020) * 100/unique_products_2020,2) AS percentage_chg
FROM CTE_2020
CROSS JOIN CTE_2021;

-- Request 3: Provide a report with all the unique product counts for each segment 
--            and sort them in descending order of product counts. 
--            The final output contains 2 fields: segment, product_count

SELECT segment, COUNT(DISTINCT product_code) AS product_count
FROM dim_product
GROUP BY segment
ORDER BY product_count DESC;

-- Request 4: Follow-up of Request 3 
--            Which segment had the most increase in unique products in 2021 vs 2020? 
--            The final output contains these fields: 
--            segment, product_count_2020, product_count_2021, difference

WITH CTE_2020 AS
(SELECT p.segment, COUNT(DISTINCT s.product_code) AS product_count_2020
FROM dim_product AS p
JOIN fact_sales_monthly AS s
ON p.product_code = s.product_code
WHERE s.fiscal_year = 2020
GROUP BY p.segment),
CTE_2021 AS
(SELECT p.segment, COUNT(DISTINCT s.product_code) AS product_count_2021
FROM dim_product AS p
JOIN fact_sales_monthly AS s
ON p.product_code = s.product_code
WHERE s.fiscal_year = 2021
GROUP BY p.segment)
SELECT CTE_2020.segment, product_count_2020, product_count_2021, 
(product_count_2021 - product_count_2020) AS difference
FROM CTE_2020
JOIN CTE_2021
ON CTE_2020.segment = CTE_2021.segment
ORDER BY difference DESC;

-- Request 5: Get the products that have the highest and lowest manufacturing costs. 
--            The final output should contain these fields: product_code, product, manufacturing_cost

(SELECT m.product_code, CONCAT(p.product," ",p.variant) AS product_name, 
m.manufacturing_cost AS highest_manufacturing_cost
FROM fact_manufacturing_cost m
JOIN dim_product p
ON m.product_code = p.product_code
WHERE m.manufacturing_cost = 
(SELECT MAX(manufacturing_cost) FROM fact_manufacturing_cost))
UNION
(SELECT m.product_code, CONCAT(p.product," ",p.variant) AS product_name, 
m.manufacturing_cost AS lowest_manufacturing_cost
FROM fact_manufacturing_cost m
JOIN dim_product p
ON m.product_code = p.product_code
WHERE m.manufacturing_cost = 
(SELECT MIN(manufacturing_cost) FROM fact_manufacturing_cost));

-- Request 6 :Generate a report which contains the top 5 customers who received an average 
--            high pre_invoice_discount_pct for the fiscal year 2021 and in the Indian market. 
--            The final output contains these fields: customer_code, customer, average_discount_percentage

SELECT pre.customer_code, c.customer, 
ROUND(AVG(pre.pre_invoice_discount_pct)*100,2) AS Avg_pre_invoice_discount_pct
FROM fact_pre_invoice_deductions pre
JOIN dim_customer c
ON pre.customer_code = c.customer_code
WHERE pre.fiscal_year = 2021 AND c.market = "India" 
GROUP BY pre.customer_code
ORDER BY Avg_pre_invoice_discount_pct DESC
LIMIT 5;

-- Request 7: Get the complete report of the Gross sales amount for the customer “Atliq Exclusive” 
--            for each month. This analysis helps to get an idea of low and high-performing months 
--            and take strategic decisions. The final report contains these columns: 
--            Month, Year, Gross sales Amount

SELECT date, MONTH(date) AS Month, YEAR(date) as Year,
ROUND(SUM(gross_price*sold_quantity),2) AS Gross_sales_amount
FROM fact_sales_monthly s
JOIN dim_customer c
ON s.customer_code = c.customer_code
JOIN fact_gross_price g
ON s.product_code = g.product_code 
WHERE customer = "Atliq Exclusive"
GROUP BY date
ORDER BY date;

-- Request 8: In which quarter of 2020, got the maximum total_sold_quantity?
--            The final output contains these fields sorted by the total_sold_quantity:
--            Quarter, total_sold_quantity

SELECT 
   CASE 
      WHEN MONTH(date) IN (9,10,11) THEN 'Q1'
      WHEN MONTH(date) IN (12,1,2) THEN 'Q2'
      WHEN MONTH(date) IN (3,4,5) THEN 'Q3'
      ELSE 'Q4' 
   END AS Quarter,
SUM(sold_quantity) AS total_sold_quantity
FROM fact_sales_monthly
WHERE fiscal_year = 2020 
GROUP BY Quarter
ORDER BY total_sold_quantity DESC;

-- Request 9: Which channel helped to bring more gross sales in the fiscal year 2021 and 
--            the percentage of contribution? 
--            The final output contains these fields: channel, gross_sales_mln, percentage

WITH CTE1 AS 
(SELECT channel, ROUND(SUM(gross_price * sold_quantity)/1000000,2) AS gross_sales_mln
FROM fact_sales_monthly s
JOIN dim_customer c
ON s.customer_code = c.customer_code
JOIN fact_gross_price g
ON s.product_code = g.product_code AND
s.fiscal_year = g.fiscal_year
WHERE s.fiscal_year = 2021
GROUP BY channel
ORDER BY  gross_sales_mln DESC)
SELECT channel, gross_sales_mln, 
gross_sales_mln*100/SUM(gross_sales_mln) OVER() AS percentage
FROM CTE1;

-- Request 10: Get the Top 3 products in each division that have a 
--             high total_sold_quantity in the fiscal_year 2021? 
--             The final output contains these fields: 
--             division, product_code, product, total_sold_quantity, rank_order

WITH CTE1 AS 
(SELECT p.division, s.product_code, CONCAT(p.product," ",p.variant) AS product_name, 
SUM(s.sold_quantity) AS total_sold_quantity,
DENSE_RANK() OVER (PARTITION BY division ORDER BY SUM(s.sold_quantity) DESC) AS rank_order
FROM fact_sales_monthly s
JOIN dim_product p
ON s.product_code = p.product_code
WHERE s.fiscal_year = 2021
GROUP BY s.product_code)
SELECT * FROM CTE1
WHERE rank_order <= 3;