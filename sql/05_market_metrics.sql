--- METROPOLITIAN STATISTICAL AREA
--- View of lender share of market volume by year and market
CREATE OR REPLACE VIEW lender_share AS
SELECT 
    activity_year, 
    market, 
    lei, 
    lender_name, 
    SUM(loan_amount) AS lender_vol, 
    SUM(SUM(loan_amount)) OVER (PARTITION BY activity_year, market) AS market_vol
FROM base
WHERE market != '99999'
GROUP BY activity_year, market, lei, lender_name;



--- View of market size by year and market
CREATE OR REPLACE VIEW market_size AS
SELECT
    activity_year, 
    market,
    SUM(loan_amount) AS total_vol,
    COUNT(*) AS loan_count,         -- outlier-proof volume
    COUNT(DISTINCT lei) AS active_lenders
FROM base
WHERE market != '99999'
GROUP BY activity_year, market;



-- #1 lender per market-year (QUALIFY = WHERE for window functions)
SELECT
    activity_year,
    market,
    lender_name, 
    ROUND(100.0 * lender_vol / market_vol, 2) AS share_pct
FROM lender_share
QUALIFY RANK() OVER (PARTITION BY activity_year, market ORDER BY lender_vol DESC) = 1
ORDER BY market_vol DESC;



-- YoY growth
SELECT 
    activity_year,
    market, 
    total_vol, 
    loan_count,
    active_lenders,
    ROUND(100.0 * (total_vol - LAG(total_vol) OVER (PARTITION BY market ORDER BY activity_year))
        / NULLIF(LAG(total_vol) OVER (PARTITION BY market ORDER BY activity_year), 0)
        , 1) AS yoy_growth_pct
FROM market_size
ORDER BY market, activity_year;



--- COUNTY
--- View of lender share of county volume by year and county 
CREATE OR REPLACE VIEW county_lender_share AS
SELECT 
    activity_year, 
    county_code, 
    lei, 
    lender_name, 
    SUM(loan_amount) AS lender_vol, 
    SUM(SUM(loan_amount)) OVER (PARTITION BY activity_year, county_code) AS county_vol
FROM base
WHERE county_code != 'NA'
GROUP BY activity_year, county_code, lei, lender_name;



--- View of market size by year and county
CREATE OR REPLACE VIEW county_market_size AS
SELECT
    activity_year, 
    county_code,
    SUM(loan_amount) AS total_vol,
    COUNT(*) AS loan_count,         -- outlier-proof volume
    COUNT(DISTINCT lei) AS active_lenders
FROM base
WHERE county_code != 'NA'
GROUP BY activity_year, county_code;


-- #1 lender per county-year (QUALIFY = WHERE for window functions)
SELECT
    activity_year,
    county_code,
    lender_name, 
    ROUND(100.0 * lender_vol / county_vol, 2) AS share_pct
FROM county_lender_share
QUALIFY RANK() OVER (PARTITION BY activity_year, county_code ORDER BY lender_vol DESC) = 1
ORDER BY county_vol DESC;


-- YoY growth
SELECT 
    activity_year,
    county_code, 
    total_vol, 
    loan_count,
    active_lenders,
    ROUND(100.0 * (total_vol - LAG(total_vol) OVER (PARTITION BY county_code ORDER BY activity_year))
        / NULLIF(LAG(total_vol) OVER (PARTITION BY county_code ORDER BY activity_year), 0)
        , 1) AS yoy_growth_pct
FROM county_market_size
ORDER BY county_code, activity_year;



