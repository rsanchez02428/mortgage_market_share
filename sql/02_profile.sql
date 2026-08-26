-- 02_profile.sql - understand the data before trusting it.

-- CONCEPT: 

--- Summarize the entire dataset to get an overview of its structure and contents.
SUMMARIZE hmda_raw;

--- Count the number of records for each action_taken value to understand the distribution of actions.
SELECT action_taken, COUNT(*) AS n
FROM hmda_raw
GROUP BY action_taken
ORDER BY n DESC;


--- Count the number of records for each loan_purpose value to understand the distribution of loan purposes.
SELECT loan_purpose, COUNT(*) AS n
FROM hmda_raw
GROUP BY loan_purpose
ORDER BY n DESC;


--- Count the number of records for each state_code value to understand the distribution of records by state.
SELECT state_code, COUNT(*) AS n
FROM hmda_raw
GROUP BY state_code
ORDER BY n DESC;


--- How many records per state as a share of that year's total records?
SELECT
    activity_year,
    SUM(COUNT(*)) OVER (PARTITION BY activity_year) AS year_total_records,
    state_code,
    COUNT(*) AS state_records,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY activity_year), 2) AS pct_of_year
FROM hmda_raw
GROUP BY activity_year, state_code
ORDER BY activity_year, pct_of_year DESC;


-- How many NA does each column have?
SELECT 'county_code' as column_name, county_code AS raw_value, COUNT(*) AS n
FROM hmda_raw
WHERE county_code = 'NA'
GROUP BY county_code

UNION ALL

SELECT 'census_tract' as column_name, census_tract AS raw_value, COUNT(*) AS n
FROM hmda_raw
WHERE census_tract = 'NA'
GROUP BY census_tract

UNION ALL

SELECT 'property_value' as column_name, property_value AS raw_value, COUNT(*) AS n
FROM hmda_raw
WHERE property_value = 'NA'
GROUP BY property_value

UNION ALL 

SELECT 'income' as column_name, income AS raw_value, COUNT(*) AS n
FROM hmda_raw
WHERE income = 'NA'
GROUP BY income

UNION ALL

SELECT 'interest_rate' as column_name, interest_rate AS raw_value, COUNT(*) AS n
FROM hmda_raw
WHERE interest_rate = 'NA'
GROUP BY interest_rate

UNION ALL

SELECT 'loan_term' as column_name, loan_term AS raw_value, COUNT(*) AS n
FROM hmda_raw
WHERE loan_term = 'NA'
GROUP BY loan_term

ORDER BY column_name, n DESC;

--- How many NA values across each state for each year?
SELECT activity_year, state_code, 'county_code' AS column_name, COUNT(*) AS n
FROM hmda_raw
WHERE county_code = 'NA'
GROUP BY activity_year, state_code

UNION ALL

SELECT activity_year, state_code, 'census_tract' AS column_name, COUNT(*) AS n
FROM hmda_raw
WHERE census_tract = 'NA'
GROUP BY activity_year, state_code

UNION ALL

SELECT activity_year, state_code, 'property_value' AS column_name, COUNT(*) AS n
FROM hmda_raw
WHERE property_value = 'NA'
GROUP BY activity_year, state_code

UNION ALL

SELECT activity_year, state_code, 'income' AS column_name, COUNT(*) AS n
FROM hmda_raw
WHERE income = 'NA'
GROUP BY activity_year, state_code

UNION ALL

SELECT activity_year, state_code, 'interest_rate' AS column_name, COUNT(*) AS n
FROM hmda_raw
WHERE interest_rate = 'NA'
GROUP BY activity_year, state_code

UNION ALL

SELECT activity_year, state_code, 'loan_term' AS column_name, COUNT(*) AS n
FROM hmda_raw
WHERE loan_term = 'NA'
GROUP BY activity_year, state_code

ORDER BY column_name, activity_year, state_code;


--- How many regions untraceable?
SELECT activity_year, state_code, county_code,'county_code' as column_name, COUNT(*) AS n
FROM hmda_raw
WHERE county_code = 'NA'
GROUP BY activity_year, state_code, county_code

UNION ALL

SELECT activity_year, state_code, census_tract, 'census_tract' as column_name, COUNT(*) AS n
FROM hmda_raw
WHERE census_tract = 'NA'
GROUP BY activity_year, state_code, census_tract

UNION ALL

SELECT activity_year, state_code, derived_msa_md, 'market' AS column_name, COUNT(*) AS n
FROM hmda_raw
WHERE derived_msa_md = 99999
GROUP BY activity_year, state_code, derived_msa_md

ORDER BY column_name, state_code, activity_year, n DESC;


--- How many records have NA for income/interest_rate/property_value, alone and stacked
--- (i.e. does NA cluster in the same records, or spread across different ones?)
SELECT
    COUNT(*) FILTER (WHERE income = 'NA') AS income_na,
    COUNT(*) FILTER (WHERE income = 'NA' AND interest_rate = 'NA') AS income_rate_na,
    COUNT(*) FILTER (WHERE income = 'NA' AND interest_rate = 'NA' AND property_value = 'NA') AS income_rate_value_na,

    COUNT(*) FILTER (WHERE interest_rate = 'NA') AS rate_na,
    COUNT(*) FILTER (WHERE interest_rate = 'NA' AND property_value = 'NA') AS rate_value_na,

    COUNT(*) FILTER (WHERE property_value = 'NA') AS value_na,
    COUNT(*) FILTER (WHERE property_value = 'NA' AND income = 'NA') AS value_income_na
FROM hmda_raw;




--- Specific column checks that are not explained in statistics.
--- conforming loan limit
--- NOTE: look at during base EDA for NA
SELECT activity_year, conforming_loan_limit, COUNT(*) AS n
FROM hmda_raw
GROUP BY activity_year, conforming_loan_limit
ORDER BY activity_year, conforming_loan_limit;


--- derived dwelling count
SELECT derived_dwelling_category, COUNT(*) AS n
FROM hmda_raw
GROUP BY derived_dwelling_category
ORDER BY n DESC;


--- derived dwelling + busniss or commercial use count
SELECT derived_dwelling_category, business_or_commercial_purpose, COUNT(*) as n 
FROM hmda_raw
GROUP BY derived_dwelling_category, business_or_commercial_purpose
ORDER BY n DESC;

--- total units count
SELECT activity_year, total_units, COUNT(*) as n 
FROM hmda_raw
GROUP BY activity_year, total_units
ORDER BY n DESC;


--- loan-amount distribution on RAW data (still has multifamily/commercial).
SELECT derived_dwelling_category, MIN(loan_amount) AS min_loan, MEDIAN(loan_amount) AS median_loan,
    QUANTILE_CONT(loan_amount, 0.99) AS p99, MAX(loan_amount) AS max_loan
FROM hmda_raw
WHERE action_taken = 1
GROUP BY derived_dwelling_category
ORDER BY derived_dwelling_category;


--- Investigate the giants BEFORE cutting: why is a loan $500M+?
-- Almost always multifamily or business - i.e., not a house. The fix is
-- STRUCTURAL (scopr the population), not an arbitrary cap.
SELECT derived_dwelling_category, total_units, business_or_commercial_purpose, 
    COUNT(*) AS n, MAX(loan_amount) AS max_loan
FROM hmda_raw
WHERE loan_amount > 30000000
    AND action_taken = 1
GROUP BY 1, 2, 3
ORDER BY n DESC;

-- property value
-- property value
SELECT derived_dwelling_category, MIN(TRY_CAST(property_value AS INT)) AS min_value,
       MEDIAN(TRY_CAST(property_value AS INT)) AS median_value,
       QUANTILE_CONT(TRY_CAST(property_value AS INT), 0.99) AS p99,
       MAX(TRY_CAST(property_value AS INT)) AS max_value
FROM hmda_raw
WHERE action_taken = 1
GROUP BY derived_dwelling_category;

--- income
SELECT derived_dwelling_category, MIN(TRY_CAST(income AS INT)) AS min_value,
       MEDIAN(TRY_CAST(income AS INT)) AS median_value,
       QUANTILE_CONT(TRY_CAST(income AS INT), 0.99) AS p99,
       MAX(TRY_CAST(income AS INT)) AS max_value
FROM hmda_raw
WHERE action_taken = 1
GROUP BY derived_dwelling_category;


--- less than or = to 0
SELECT derived_dwelling_category, COUNT(*) AS n
FROM hmda_raw
WHERE action_taken = 1
    AND (TRY_CAST(income as INT) < 0 OR TRY_CAST(income as INT) = 0)
GROUP BY derived_dwelling_category
ORDER BY n DESC;

----- STopped here on 08/24/2026
--- interest rate

SELECT 
    activity_year, 
    MIN(TRY_CAST(interest_rate AS DOUBLE)) AS min_rate,
    MEDIAN(TRY_CAST(interest_rate AS DOUBLE)) AS median_rate,
    AVG(TRY_CAST(interest_rate AS DOUBLE)) AS avg_rate, 
    QUANTILE_CONT(TRY_CAST(interest_rate AS DOUBLE), [0.01, 0.25, 0.75, 0.99]) AS q, 
    MAX(TRY_CAST(interest_rate AS DOUBLE)) AS max_rate
FROM hmda_raw
WHERE action_taken = 1
GROUP BY activity_year
ORDER BY activity_year;

SELECT activity_year, loan_type, COUNT(*) AS n
FROM hmda_raw
WHERE TRY_CAST(interest_rate AS DOUBLE) < 3
    AND action_taken = 1
GROUP BY activity_year, loan_type
ORDER BY n DESC;


--- loan term
SELECT 
    activity_year, loan_purpose,
    MIN(TRY_CAST(loan_term AS INTEGER)) AS min_term,
    MEDIAN(TRY_CAST(loan_term AS INTEGER)) AS median_term,
    AVG(TRY_CAST(loan_term AS INTEGER)) AS avg_term, 
    QUANTILE_CONT(TRY_CAST(loan_term AS INTEGER), [0.01, 0.25, 0.75, 0.99]) AS q, 
    MAX(TRY_CAST(loan_term AS INTEGER)) AS max_term
FROM hmda_raw
WHERE action_taken = 1
GROUP BY activity_year, loan_purpose
ORDER BY activity_year;


SELECT activity_year, COUNT(*) AS n
FROM hmda_raw
WHERE loan_term = 'NA'
    AND action_taken = 1
GROUP BY activity_year
ORDER BY n DESC;


--- submission_of_application
SELECT activity_year, submission_of_application, COUNT(*) AS n
FROM hmda_raw
WHERE action_taken = 1
GROUP BY activity_year, submission_of_application
ORDER BY n DESC;


--- initally payable to institution
SELECT initially_payable_to_institution, COUNT(*) AS n
FROM hmda_raw
WHERE action_taken = 1
GROUP BY initially_payable_to_institution
ORDER BY n DESC;


--- Check duplicate lei codes for differing lender_name

-- Same LEI mapped to more than one lender name WITHIN the same year.
-- (Ideally zero -- LEI should be a 1:1 key to a lender in a given year.)
SELECT activity_year, lei,
    COUNT(DISTINCT respondent_name) AS n_names,
    STRING_AGG(DISTINCT respondent_name, ' | ') AS names
FROM lenders
GROUP BY activity_year, lei
HAVING COUNT(DISTINCT respondent_name) > 1
ORDER BY n_names DESC, activity_year;


-- Same LEI mapped to different lender names ACROSS years
-- (e.g. rebrand, acquisition, or a data-entry inconsistency).
SELECT lei,
    COUNT(DISTINCT respondent_name) AS n_names,
    STRING_AGG(DISTINCT activity_year || ': ' || respondent_name, ' | ' ORDER BY activity_year || ': ' || respondent_name) AS names_by_year
FROM lenders
GROUP BY lei
HAVING COUNT(DISTINCT respondent_name) > 1
ORDER BY n_names DESC;


-- Opposite direction: same lender name using more than one
-- LEI (also a data-quality flag, and matters for market-share rollups).
SELECT respondent_name,
    COUNT(DISTINCT lei) AS n_leis,
    STRING_AGG(DISTINCT lei, ' | ') AS leis
FROM lenders
GROUP BY respondent_name
HAVING COUNT(DISTINCT lei) > 1
ORDER BY n_leis DESC;

