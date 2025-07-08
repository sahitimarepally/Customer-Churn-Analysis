-- Data Exploration & Quality
-- Total customers are in the dataset:
SELECT COUNT(*) FROM customer_table;
-- Distribution across churned vs. retained customers
SELECT
  SUM(CASE WHEN Churn = 'Yes' THEN 1 ELSE 0 END) AS churned,
  SUM(CASE WHEN Churn = 'No' THEN 1 ELSE 0 END) AS retained
FROM customer_table;

-- Customer tenure range
SELECT MIN(tenure) AS min_tenure, MAX(tenure) AS max_tenure FROM customer_table;

-- Find Missing values
SELECT * FROM customer_table WHERE TotalCharges IS NULL OR MonthlyCharges IS NULL;


-- Data Cleaning

-- No. of missing values in TotalCharges
SELECT COUNT(*) AS missing_totalcharges
FROM customer_table
WHERE TotalCharges IS NULL OR TRIM(TotalCharges) = '';

-- Check Duplicate entries
SELECT COUNT(*) FROM customer_table GROUP BY customerid HAVING COUNT(*) > 1;

--Check any invalid entries
SELECT * FROM customer_table WHERE customerid IS NULL;
SELECT * FROM customer_table WHERE MonthlyCharges IS NULL;
SELECT * FROM customer_table WHERE TotalCharges < MonthlyCharges;
SELECT * FROM customer_table WHERE tenure = 0 AND Churn = 'No';
/* The customers with tenure=0 means they’ve just joined and have not completed one billing cycle.  We can also observe that these are the same rows with missing Total charges and haven’t been billed yet.*/

--Fill missing values
SELECT
  CASE
    WHEN TRIM(TotalCharges) = '' OR TotalCharges IS NULL THEN 0
    ELSE CAST(TotalCharges AS FLOAT)
  END AS TotalCharges_Cleaned
FROM customer_table;

--Data Transformation / Aggregation
-- Creating a summary table to capture per customer:
CREATE TABLE customer_summary AS
SELECT customerID, tenure, MonthlyCharges, TotalCharges FROM customer_table;

-- Count of services subscribed :
SELECT
  SUM(CASE WHEN PhoneService = 'Yes' THEN 1 ELSE 0 END) AS phonesubs,
  SUM(CASE WHEN InternetService <> 'No' THEN 1 ELSE 0 END) AS internetsubs,
  SUM(CASE WHEN OnlineSecurity = 'Yes' THEN 1 ELSE 0 END) AS olsecuritysubs,
  SUM(CASE WHEN OnlineBackup = 'Yes' THEN 1 ELSE 0 END) AS olbackupsubs,
  SUM(CASE WHEN StreamingTV = 'Yes' THEN 1 ELSE 0 END) AS TVsubs,
  SUM(CASE WHEN StreamingMovies = 'Yes' THEN 1 ELSE 0 END) AS Moviesubs
FROM customer_table;

-- Count of customers based onContract type, payment method
SELECT contract, COUNT(*) AS customers FROM customer_table GROUP BY contract;
SELECT PaymentMethod, COUNT(*) AS customers FROM customer_table GROUP BY PaymentMethod;


 -- Descriptive Churn Analytics
-- Overall churn rate:
SELECT (SUM(CASE WHEN churn = 'Yes' THEN 1 ELSE 0 END) * 100) / COUNT(churn) AS churn_rate;

-- Average monthly charge and total charges for churned vs. non-churned groups.
SELECT
  Churn,
  AVG(MonthlyCharges) AS avg_monthlycharges,
  AVG(CAST(TotalCharges AS FLOAT)) AS avg_totalcharges
FROM customer_table
GROUP BY Churn;

--Churn rate by contract type 

SELECT contract, (SUM(CASE WHEN churn = 'Yes' THEN 1 ELSE 0 END) * 100) / COUNT(churn) AS churn_rate
FROM customer_table
GROUP BY contract;

--Churn rate across internet service types and payment methods.
SELECT
  InternetService, PaymentMethod,
  (SUM(CASE WHEN churn = 'Yes' THEN 1 ELSE 0 END) * 100) / COUNT(churn) AS churn_rate
FROM customer_table
GROUP BY InternetService, PaymentMethod;

 -- Customer Segmentation
-- Segmenting customers into low/medium/high value by MonthlyCharges 
WITH q1 AS (
  SELECT MonthlyCharges AS first_quart
  FROM customer_table
  ORDER BY MonthlyCharges
  LIMIT 1 OFFSET (SELECT CAST(COUNT(*) * 0.25 AS INTEGER) FROM customer_table)
), q3 AS (
  SELECT MonthlyCharges AS third_quart
  FROM customer_table
  ORDER BY MonthlyCharges
  LIMIT 1 OFFSET (SELECT CAST(COUNT(*) * 0.75 AS INTEGER) FROM customer_table)
)SELECT
  CASE
    WHEN MonthlyCharges < q1.first_quart THEN 'Low'
    WHEN MonthlyCharges >= q1.first_quart AND MonthlyCharges < q3.third_quart THEN 'Medium'
    ELSE 'High'
  END AS value_segment,
  COUNT(*) AS total_customers,
  SUM(CASE WHEN churn = 'Yes' THEN 1 ELSE 0 END) AS churned_customers,
  ROUND(100.0 * SUM(CASE WHEN churn = 'Yes' THEN 1 ELSE 0 END) / COUNT(*), 2) AS churn_rate_percent
FROM customer_table
CROSS JOIN q1
CROSS JOIN q3
GROUP BY value_segment;

-- Having Tech support can effect churn?
SELECT
  TechSupport,
  (SUM(CASE WHEN churn = 'Yes' THEN 1 ELSE 0 END) * 100) / COUNT(churn) AS churn_rate
FROM customer_table
GROUP BY TechSupport;

-- Cohort & Temporal Analysis
--Monthly churn rate over tenure
SELECT
  Tenure,
  (SUM(CASE WHEN churn = 'Yes' THEN 1 ELSE 0 END) * 100) / COUNT(churn) AS churn_rate
FROM customer_table
GROUP BY Tenure
ORDER BY Tenure;

-- Comparing churn rate with tenure segments
SELECT
  CASE
    WHEN tenure <= 6 THEN 'Less tenure'
    WHEN tenure > 24 THEN 'High Tenure'
  END AS tenure_seg,
  (SUM(CASE WHEN churn = 'Yes' THEN 1 ELSE 0 END) * 100) / COUNT(churn) AS churn_rate
FROM customer_table
GROUP BY tenure_seg;

 -- Combine Behavioral Insights
-- Correlation of services with churn:
SELECT
  StreamingMovies,
  StreamingTV,
  COUNT(CASE WHEN churn = 'Yes' THEN 1 END) AS churned,
  (SUM(CASE WHEN churn = 'Yes' THEN 1 ELSE 0 END) * 100) / COUNT(churn) AS churn_rate
FROM customer_table
GROUP BY StreamingMovies, StreamingTV
ORDER BY churn_rate;

--Churn rate by demographics
SELECT
  SeniorCitizen, Partner, Dependents,
  COUNT(*) AS total_customers,
  COUNT(CASE WHEN churn = 'Yes' THEN 1 END) AS churned,
  (SUM(CASE WHEN churn = 'Yes' THEN 1 ELSE 0 END) * 100) / COUNT(*) AS churn_rate
FROM customer_table
GROUP BY SeniorCitizen, Partner, Dependents
ORDER BY churn_rate DESC;
SELECT
  gender,
  SUM(CASE WHEN churn = 'Yes' THEN 1 ELSE 0 END) AS churned
FROM customer_table
GROUP BY gender;

--Risk-based churn categories

/*“At Risk” = month-to-month + no tech support + fiber internet
Medium Risk= month-to-month + notech suppot/fiber optics+ <6months tenure
Low risk= One/two year contract + tech support+DSL */

SELECT
  contract,
  Internetservice,
  techsupport,
  tenure,
  CASE
    WHEN contract = 'Month-to-month' AND internetservice = 'Fiber optic' AND techsupport = 'No' THEN 'At Risk'
    WHEN contract = 'Month-to-month' AND (internetservice = 'Fiber optic' OR techsupport = 'No') AND tenure < 6 THEN 'Medium risk'
    WHEN contract = 'One year' AND internetservice = 'DSL' AND techsupport = 'Yes' AND tenure > 12 THEN 'Low risk'
    ELSE 'No risk'
  END AS risk_categories
FROM customer_table;


--Top 3 risk factor combinations
SELECT
  internetservice,
  techsupport,
  tenure,
  paymentmethod,
  contract,
  COUNT(*) AS total_customers,
  (SUM(CASE WHEN churn = 'Yes' THEN 1 ELSE 0 END) * 100) / COUNT(churn) AS churn_rate
FROM customer_table
GROUP BY internetservice, techsupport, tenure, paymentmethod, contract
HAVING COUNT(*) > 10
ORDER BY churn_rate DESC;

--Creating a churn report view
CREATE VIEW churn_reports AS
SELECT
  customerid,
  CASE WHEN churn = 'Yes' THEN 1 ELSE 0 END AS churn_flag,
  tenure,
  monthlycharges,
  paymentmethod,
  contract,
  (
    (CASE WHEN PhoneService = 'Yes' THEN 1 ELSE 0 END) +
    (CASE WHEN InternetService <> 'No' THEN 1 ELSE 0 END) +
    (CASE WHEN OnlineSecurity = 'Yes' THEN 1 ELSE 0 END) +
    (CASE WHEN OnlineBackup = 'Yes' THEN 1 ELSE 0 END) +
    (CASE WHEN StreamingTV = 'Yes' THEN 1 ELSE 0 END) +
    (CASE WHEN StreamingMovies = 'Yes' THEN 1 ELSE 0 END)
  ) AS number_of_services
FROM customer_table
GROUP BY customerid;




