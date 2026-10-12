-- 03_base.sql - Scope the population & build the analysis base.

CREATE OR REPLACE VIEW base AS
WITH originations AS (
    SELECT
        TRY_CAST(activity_year AS SMALLINT) AS activity_year,   -- small integer data type helps with storage on database
        state_code, 
        county_code, 
        census_tract,
        derived_msa_md AS market, 
        lei,
        loan_amount, 
        TRY_CAST(loan_type AS TINYINT) AS loan_type_num, -- tiny integer helps with storage and but the numbers cant exceed 237 
        derived_loan_product_type,
        conforming_loan_limit, 
        loan_term,
        TRY_CAST(loan_term AS SMALLINT) AS loan_term_num,
        income,
        TRY_CAST(income AS INTEGER) AS income_num,
        property_value,
        TRY_CAST(property_value AS BIGINT) AS property_value_num,
        interest_rate,
        TRY_CAST(interest_rate AS DOUBLE) AS interest_rate_num,
        TRY_CAST(construction_method AS TINYINT) AS construction_method, -- DONE (NOTE: Look at the various values these columns can take and select the correct data type given the values (those below and above) document everything you have been working on)
        TRY_CAST(submission_of_application AS TINYINT) AS submission_of_application,
        TRY_CAST(initially_payable_to_institution AS TINYINT) AS initially_payable_to_institution,
        TRY_CAST(purchaser_type AS TINYINT) AS purchaser_type,
        TRY_CAST(tract_one_to_four_family_homes AS SMALLINT) AS tract_one_to_four_family_homes,
        TRY_CAST(tract_owner_occupied_units AS SMALLINT) AS tract_owner_occupied_units,
        TRY_CAST(ffiec_msa_md_median_family_income AS INTEGER) AS ffiec_msa_md_median_family_income

    FROM hmda_raw
    WHERE action_taken = 1
        AND lien_status = 1
        AND occupancy_type = 1
        AND business_or_commercial_purpose = 2
        AND loan_purpose = 1
        AND open_end_line_of_credit = 2
        AND reverse_mortgage = 2
        AND total_units IN ('1', '2', '3', '4')
        AND derived_msa_md IS NOT NULL
)
SELECT
    o.*,
    COALESCE(ovr.lender_name, ldr.lender_name, o.lei) AS lender_name
FROM originations o
LEFT JOIN lender_overrides ovr ON o.lei = ovr.lei
LEFT JOIN lenders_clean ldr ON o.lei = ldr.lei;



-- Count of total records in the base view. Does the count make sense given the amount of records in the raw data and the filters applied? If not, check the filters and the joins to ensure they are correct.
SELECT COUNT(*) AS total_records
FROM base;


-- Does the data look correct?
SELECT *
FROM base
LIMIT 10;


-- Summarize the base for quick checks and validation
SUMMARIZE base;


--- How many records per state as a share of that year's total records?
SELECT
    activity_year,
    SUM(COUNT(*)) OVER (PARTITION BY activity_year) AS year_total_records,
    state_code,
    COUNT(*) AS state_records,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY activity_year), 2) AS pct_of_year
FROM base
GROUP BY activity_year, state_code
ORDER BY activity_year, pct_of_year DESC;


--- How many records per market as a share of that year's total records?
SELECT
    activity_year,
    SUM(COUNT(*)) OVER (PARTITION BY activity_year) AS year_total_records,
    market,
    COUNT(*) AS market_records,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY activity_year), 2) AS pct_of_year
FROM base
GROUP BY activity_year, market
ORDER BY activity_year, pct_of_year DESC;


--- Top 5 markets per year by share of that year's total records
SELECT
    activity_year,
    market,
    COUNT(*) AS market_records,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY activity_year), 2) AS pct_of_year
FROM base
GROUP BY activity_year, market
QUALIFY ROW_NUMBER() OVER (PARTITION BY activity_year ORDER BY COUNT(*) DESC) <= 5
ORDER BY activity_year, pct_of_year DESC;


--- Top 5 counties (state_code + county_code) per year by share of that year's total records
SELECT
    activity_year,
    state_code,
    county_code,
    COUNT(*) AS county_records,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY activity_year), 2) AS pct_of_year
FROM base
WHERE county_code <> 'NA'
GROUP BY activity_year, state_code, county_code
QUALIFY ROW_NUMBER() OVER (PARTITION BY activity_year ORDER BY COUNT(*) DESC) <= 5
ORDER BY activity_year, pct_of_year DESC;


--- Top 5 census tracts (state_code + county_code + census_tract) per year by share of that year's total records
SELECT
    activity_year,
    state_code,
    county_code,
    census_tract,
    COUNT(*) AS tract_records,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY activity_year), 2) AS pct_of_year
FROM base
WHERE census_tract <> 'NA'
GROUP BY activity_year, state_code, county_code, census_tract
QUALIFY ROW_NUMBER() OVER (PARTITION BY activity_year ORDER BY COUNT(*) DESC) <= 5
ORDER BY activity_year, pct_of_year DESC;


--- Total origination volume (loan count and dollar amount) per year
SELECT
    activity_year,
    COUNT(*) AS loan_count,
    SUM(loan_amount) AS total_volume,
    ROUND(SUM(loan_amount) / 1e9, 2) AS total_volume_bn,
    ROUND(AVG(loan_amount), 0) AS avg_loan_amount
FROM base
WHERE market != '99999'
GROUP BY activity_year
ORDER BY activity_year;


-- Distribution of loan amounts given the state and construction method.
SELECT state_code, 
    construction_method, 
    COUNT(*) AS records,  
    MIN(loan_amount) AS min_loan_amount, 
    MEDIAN(loan_amount) AS median_loan_amount,
    AVG(loan_amount) AS avg_loan_amount,
    QUANTILE_CONT(loan_amount, 0.99) AS p99,
    MAX(loan_amount) AS max_loan
FROM base
GROUP BY state_code, construction_method
ORDER BY state_code, construction_method;


-- Income distribution by state
SELECT state_code, 
    COUNT(*) AS records,  
    MIN(income_num) AS min_income, 
    MEDIAN(income_num) AS median_income,
    AVG(income_num) AS avg_income,
    QUANTILE_CONT(income_num, 0.99) AS p99,
    MAX(income_num) AS max_income
FROM base
GROUP BY state_code
ORDER BY median_income DESC;


-- property value distirbution given the state and construction method.
SELECT state_code,
    construction_method, 
    COUNT(*) AS records,  
    MIN(property_value_num) AS min_property_value, 
    MEDIAN(property_value_num) AS median_property_value,
    AVG(property_value_num) AS avg_property_value,
    QUANTILE_CONT(property_value_num, 0.99) AS p99,
    MAX(property_value_num) AS max_property_value
FROM base
GROUP BY state_code, construction_method
ORDER BY state_code, construction_method;


--- interest rate distribution by year
SELECT activity_year, 
    COUNT(*) AS records,  
    MIN(interest_rate_num) AS min_interest_rate, 
    MEDIAN(interest_rate_num) AS median_interest_rate,
    AVG(interest_rate_num) AS avg_interest_rate,
    QUANTILE_CONT(interest_rate_num, 0.99) AS p99,
    MAX(interest_rate_num) AS max_interest_rate
FROM base
GROUP BY activity_year
ORDER BY activity_year;


-- Purchaser type counts by year
SELECT activity_year, 
    purchaser_type, 
    COUNT(*) AS records
FROM base
GROUP BY activity_year, purchaser_type
ORDER BY activity_year, purchaser_type;


--- EDA based off of profile findings.

--- Count of records with income less than or equal to 0
SELECT activity_year, state_code, COUNT(*) AS n
FROM base
WHERE  income_num < 0 OR income_num = 0
GROUP BY activity_year, state_code
ORDER BY activity_year, state_code;

--- Count of records with an interest rate lower than 3 percent.
SELECT loan_type_num, COUNT(*) AS n
FROM base
WHERE interest_rate_num < 3
GROUP BY loan_type_num
ORDER BY n DESC;


--- Records with a null value in any key numeric column.
SELECT COUNT(*) AS null_records
FROM base
WHERE property_value_num IS NULL
   OR income_num IS NULL
   OR interest_rate_num IS NULL
   OR loan_term_num IS NULL;


--- Records with NA or Exempt values in any key numeric column.
SELECT COUNT(*) AS na_exempt_records
FROM base
WHERE property_value IN ('NA', 'Exempt')
   OR income IN ('NA', 'Exempt')
   OR interest_rate IN ('NA', 'Exempt')
   OR loan_term IN ('NA', 'Exempt');


--- Count of NA and Exempt values per key numeric column against null values. This will help us understand the distribution of missing values in the data.
SELECT
    SUM(CASE WHEN property_value_num IS NULL THEN 1 ELSE 0 END) AS property_value_null,
    SUM(CASE WHEN property_value = 'NA' THEN 1 ELSE 0 END) AS property_value_na,
    SUM(CASE WHEN property_value = 'Exempt' THEN 1 ELSE 0 END) AS property_value_exempt,
    SUM(CASE WHEN income_num IS NULL THEN 1 ELSE 0 END) AS income_null,
    SUM(CASE WHEN income = 'NA' THEN 1 ELSE 0 END) AS income_na,
    SUM(CASE WHEN income = 'Exempt' THEN 1 ELSE 0 END) AS income_exempt,
    SUM(CASE WHEN interest_rate_num IS NULL THEN 1 ELSE 0 END) AS interest_rate_null,
    SUM(CASE WHEN interest_rate = 'NA' THEN 1 ELSE 0 END) AS interest_rate_na,
    SUM(CASE WHEN interest_rate = 'Exempt' THEN 1 ELSE 0 END) AS interest_rate_exempt,
    SUM(CASE WHEN loan_term_num IS NULL THEN 1 ELSE 0 END) AS loan_term_null,
    SUM(CASE WHEN loan_term = 'NA' THEN 1 ELSE 0 END) AS loan_term_na,
    SUM(CASE WHEN loan_term = 'Exempt' THEN 1 ELSE 0 END) AS loan_term_exempt
FROM base;


--- Top 5 counties per state by share of that county's records with a NULL value in any key numeric column.
SELECT
    state_code,
    county_code,
    COUNT(*) AS county_records,
    COUNT(*) FILTER (
        WHERE property_value_num IS NULL
           OR income_num IS NULL
           OR interest_rate_num IS NULL
           OR loan_term_num IS NULL
    ) AS null_records,
    ROUND(100.0 * COUNT(*) FILTER (
        WHERE property_value_num IS NULL
           OR income_num IS NULL
           OR interest_rate_num IS NULL
           OR loan_term_num IS NULL
    ) / COUNT(*), 2) AS pct_null
FROM base
WHERE county_code != 'NA'
GROUP BY state_code, county_code
QUALIFY ROW_NUMBER() OVER (PARTITION BY state_code ORDER BY null_records DESC) <= 5
ORDER BY state_code, pct_null DESC;


--- Top 5 markets per state by share of that county's records with a NULL value in any key numeric column.
SELECT
    state_code,
    market,
    COUNT(*) AS market_records,
    COUNT(*) FILTER (
        WHERE property_value_num IS NULL
           OR income_num IS NULL
           OR interest_rate_num IS NULL
           OR loan_term_num IS NULL
    ) AS null_records,
    ROUND(100.0 * COUNT(*) FILTER (
        WHERE property_value_num IS NULL
           OR income_num IS NULL
           OR interest_rate_num IS NULL
           OR loan_term_num IS NULL
    ) / COUNT(*), 2) AS pct_null
FROM base
WHERE market != 99999
GROUP BY state_code, market
QUALIFY ROW_NUMBER() OVER (PARTITION BY state_code ORDER BY null_records DESC) <= 5
ORDER BY state_code, pct_null DESC;

SELECT
    state_code,
    census_tract,
    COUNT(*) AS tract_records,
    COUNT(*) FILTER (
        WHERE property_value_num IS NULL
           OR income_num IS NULL
           OR interest_rate_num IS NULL
           OR loan_term_num IS NULL
    ) AS null_records,
    ROUND(100.0 * COUNT(*) FILTER (
        WHERE property_value_num IS NULL
           OR income_num IS NULL
           OR interest_rate_num IS NULL
           OR loan_term_num IS NULL
    ) / COUNT(*), 2) AS pct_null
FROM base
WHERE census_tract != 'NA'
GROUP BY state_code, census_tract
QUALIFY ROW_NUMBER() OVER (PARTITION BY state_code ORDER BY null_records DESC) <= 5
ORDER BY state_code, pct_null DESC;


--- Untraceable records to geography (state, county, census tract, or market) by year.
SELECT
    activity_year,
    COUNT(*) AS untraceable_records
FROM base
WHERE county_code = 'NA'
    OR census_tract = 'NA'
    OR market = 99999
GROUP BY activity_year
ORDER BY activity_year;



--- How many records not traceable to county as a share of that year's total records?
WITH year_totals AS (
    SELECT activity_year, COUNT(*) AS total_records
    FROM base
    GROUP BY activity_year
)
SELECT b.activity_year,
    b.state_code,
    b.county_code,
    COUNT(*) AS untraceable_records,
    ROUND(100.0 * COUNT(*) / yt.total_records, 2) AS pct_of_year
FROM base b
JOIN year_totals yt ON yt.activity_year = b.activity_year
WHERE b.county_code = 'NA'
    OR b.county_code = 'Exempt'
GROUP BY b.activity_year, b.state_code, b.county_code, yt.total_records
ORDER BY untraceable_records DESC;



--- How many lenders have a record untracebale to a county?
--- Began to wonder during construction of County market metrics 09/15/2026
SELECT activity_year, COUNT(DISTINCT lei) AS lenders_with_untraceable_county
FROM base
WHERE county_code = 'NA'
    OR county_code = 'Exempt'
GROUP BY activity_year;


--- How many records not traceable to market as a share of that year's total records?
WITH year_totals AS (
    SELECT activity_year, COUNT(*) AS total_records
    FROM base
    GROUP BY activity_year
)
SELECT b.activity_year,
    b.state_code,
    b.market,
    COUNT(*) AS untraceable_records,
    ROUND(100.0 * COUNT(*) / yt.total_records, 2) AS pct_of_year
FROM base b
JOIN year_totals yt ON yt.activity_year = b.activity_year
WHERE b.market = 99999
GROUP BY b.activity_year, b.state_code, b.market, yt.total_records
ORDER BY untraceable_records DESC;


--- How many records not traceable to census tract as a share of that year's total records?
WITH year_totals AS (
    SELECT activity_year, COUNT(*) AS total_records
    FROM base
    GROUP BY activity_year
)
SELECT b.activity_year,
    b.state_code,
    b.census_tract,
    COUNT(*) AS untraceable_records,
    ROUND(100.0 * COUNT(*) / yt.total_records, 2) AS pct_of_year
FROM base b
JOIN year_totals yt ON yt.activity_year = b.activity_year
WHERE b.census_tract = 'NA'
    OR b.census_tract = 'Exempt'
GROUP BY b.activity_year, b.state_code, b.census_tract, yt.total_records
ORDER BY untraceable_records DESC;



--- Top 5 LEIs by county-untraceable records each year, with each LEI's most recent
--- lender name and what share of that LEI's own records that year were untraceable.
WITH most_recent_name AS (
    SELECT lei, respondent_name AS lender_name
    FROM (
        SELECT lei, respondent_name,
            ROW_NUMBER() OVER (PARTITION BY lei ORDER BY activity_year DESC) AS rn
        FROM lenders
    ) ranked_names
    WHERE rn = 1
),
lei_totals AS (
    SELECT activity_year, lei, COUNT(*) AS lei_records
    FROM base
    GROUP BY activity_year, lei
),
lei_untraceable AS (
    SELECT activity_year, lei, COUNT(*) AS untraceable_records
    FROM base
    WHERE county_code = 'NA'
        OR county_code = 'Exempt'
    GROUP BY activity_year, lei
),
ranked AS (
    SELECT u.activity_year,
        u.lei,
        u.untraceable_records,
        t.lei_records,
        ROUND(100.0 * u.untraceable_records / t.lei_records, 2) AS pct_of_lei_records,
        ROW_NUMBER() OVER (PARTITION BY u.activity_year ORDER BY u.untraceable_records DESC) AS rnk
    FROM lei_untraceable u
    JOIN lei_totals t ON t.activity_year = u.activity_year AND t.lei = u.lei
)
SELECT r.activity_year,
    r.lei,
    mrn.lender_name,
    r.untraceable_records,
    r.lei_records,
    r.pct_of_lei_records
FROM ranked r
LEFT JOIN most_recent_name mrn ON mrn.lei = r.lei
WHERE r.rnk <= 5
ORDER BY r.activity_year, r.rnk;



--- Top 5 LEIs by market-untraceable records each year, with each LEI's most recent
--- lender name and what share of that LEI's own records that year were untraceable.
WITH most_recent_name AS (
    SELECT lei, respondent_name AS lender_name
    FROM (
        SELECT lei, respondent_name,
            ROW_NUMBER() OVER (PARTITION BY lei ORDER BY activity_year DESC) AS rn
        FROM lenders
    ) ranked_names
    WHERE rn = 1
),
lei_totals AS (
    SELECT activity_year, lei, COUNT(*) AS lei_records
    FROM base
    GROUP BY activity_year, lei
),
lei_untraceable AS (
    SELECT activity_year, lei, COUNT(*) AS untraceable_records
    FROM base
    WHERE market = 99999
    GROUP BY activity_year, lei
),
ranked AS (
    SELECT u.activity_year,
        u.lei,
        u.untraceable_records,
        t.lei_records,
        ROUND(100.0 * u.untraceable_records / t.lei_records, 2) AS pct_of_lei_records,
        ROW_NUMBER() OVER (PARTITION BY u.activity_year ORDER BY u.untraceable_records DESC) AS rnk
    FROM lei_untraceable u
    JOIN lei_totals t ON t.activity_year = u.activity_year AND t.lei = u.lei
)
SELECT r.activity_year,
    r.lei,
    mrn.lender_name,
    r.untraceable_records,
    r.lei_records,
    r.pct_of_lei_records
FROM ranked r
LEFT JOIN most_recent_name mrn ON mrn.lei = r.lei
WHERE r.rnk <= 5
ORDER BY r.activity_year, r.rnk;



--- Top 5 LEIs by census-tract-untraceable records each year, with each LEI's most recent
--- lender name and what share of that LEI's own records that year were untraceable.
WITH most_recent_name AS (
    SELECT lei, respondent_name AS lender_name
    FROM (
        SELECT lei, respondent_name,
            ROW_NUMBER() OVER (PARTITION BY lei ORDER BY activity_year DESC) AS rn
        FROM lenders
    ) ranked_names
    WHERE rn = 1
),
lei_totals AS (
    SELECT activity_year, lei, COUNT(*) AS lei_records
    FROM base
    GROUP BY activity_year, lei
),
lei_untraceable AS (
    SELECT activity_year, lei, COUNT(*) AS untraceable_records
    FROM base
    WHERE census_tract = 'NA'
        OR census_tract = 'Exempt'
    GROUP BY activity_year, lei
),
ranked AS (
    SELECT u.activity_year,
        u.lei,
        u.untraceable_records,
        t.lei_records,
        ROUND(100.0 * u.untraceable_records / t.lei_records, 2) AS pct_of_lei_records,
        ROW_NUMBER() OVER (PARTITION BY u.activity_year ORDER BY u.untraceable_records DESC) AS rnk
    FROM lei_untraceable u
    JOIN lei_totals t ON t.activity_year = u.activity_year AND t.lei = u.lei
)
SELECT r.activity_year,
    r.lei,
    mrn.lender_name,
    r.untraceable_records,
    r.lei_records,
    r.pct_of_lei_records
FROM ranked r
LEFT JOIN most_recent_name mrn ON mrn.lei = r.lei
WHERE r.rnk <= 5
ORDER BY r.activity_year, r.rnk;



--- How many records have a null value and have 0 or negative incomes?
SELECT activity_year,
    state_code,
    COUNT(*) AS null_and_zero_or_negative_income_records
FROM base
WHERE income_num <= 0
    AND (property_value_num IS NULL
        OR interest_rate_num IS NULL
        OR loan_term_num IS NULL)
GROUP BY activity_year, state_code
ORDER BY null_and_zero_or_negative_income_records DESC;



-- Same LEI mapped to different lender names ACROSS years
-- (e.g. rebrand, acquisition, or a data-entry inconsistency).
SELECT lei,
    COUNT(DISTINCT lender_name) AS n_names,
    STRING_AGG(DISTINCT activity_year || ': ' || lender_name, ' | ' ORDER BY activity_year || ': ' || lender_name) AS names_by_year
FROM base
GROUP BY lei
HAVING COUNT(DISTINCT lender_name) > 1
ORDER BY n_names DESC;


-- Opposite direction: same lender name using more than one
-- LEI (also a data-quality flag, and matters for market-share rollups).
SELECT lender_name,
    COUNT(DISTINCT lei) AS n_leis,
    STRING_AGG(DISTINCT lei, ' | ') AS leis
FROM base
GROUP BY lender_name
HAVING COUNT(DISTINCT lei) > 1
ORDER BY n_leis DESC;


-- How much volume does Summit Mortgage have in the base? How many LEIs are associated with that lender name?
SELECT lender_name,
    COUNT(*) AS loan_count,
    ROUND(SUM(loan_amount / 1e6), 1) AS volume_millions,
    COUNT(DISTINCT lei) AS n_leis
FROM base
WHERE lender_name = 'Summit Mortgage Corporation'
GROUP BY lender_name;


-- PCT_UNMATCHED — share of loans that fell back to a bare LEI (no panel name).
-- Relies on the fact that your base sets lender_name = lei when the join missed.
SELECT
    COUNT(*)                                                   AS total_loans,
    COUNT(*) FILTER (WHERE lender_name = lei)                  AS unmatched_loans,
    ROUND(100.0 * COUNT(*) FILTER (WHERE lender_name = lei)
          / COUNT(*), 3)                                       AS pct_unmatched,
    COUNT(DISTINCT lei) FILTER (WHERE lender_name = lei)       AS unmatched_leis
FROM base;

-- What's actually unmatched, ranked by volume (only if pct_unmatched isn't tiny).
SELECT
    lei,
    COUNT(*)                          AS loan_count,
    ROUND(SUM(loan_amount / 1e6), 1)  AS volume_millions
FROM base 
WHERE lei = lender_name
GROUP BY lei
ORDER BY SUM(loan_amount) DESC
LIMIT 20;