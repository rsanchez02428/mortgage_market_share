--- METROPOLITAN STATISTICAL AREA
-- HHI measurement per metro across years
CREATE OR REPLACE VIEW market_concentration AS
SELECT activity_year,
    market,
    MAX(market_vol) AS total_vol, -- constant within MSA-year
    COUNT(*) AS active_lenders,
    SUM(POWER(100.0 * lender_vol / market_vol, 2)) AS hhi,
    SUM(CASE WHEN lender_rank <= 5 
            THEN 100.0 * lender_vol / market_vol END) AS top5_share_pct
FROM(
    SELECT 
        activity_year, 
        market,
        lender_vol, 
        market_vol, 
        ROW_NUMBER() OVER (PARTITION BY activity_year, market ORDER BY lender_vol DESC) AS lender_rank
    FROM lender_share
) ranked
GROUP BY activity_year, market;


-- Market context: housing stock + MSA income, LATEST YEAR ONLY.
-- Restricting to one year is what guarantees one row per tract: within a single
-- year a tract has one homes value, so SELECT DISTINCT collapses to one row and
-- SUM does not double-count. (Spanning years re-introduced the double-count bug.)
CREATE OR REPLACE VIEW market_context AS
WITH latest AS (
    SELECT MAX(activity_year) AS y FROM market_size
),
tract_stock AS (
    SELECT DISTINCT
        market,
        census_tract,
        tract_one_to_four_family_homes     AS homes_1to4,
        ffiec_msa_md_median_family_income  AS msa_income
    FROM base
    WHERE market IS NOT NULL
      AND market != '99999'
      AND census_tract IS NOT NULL
      AND census_tract NOT IN ('NA', 'Exempt')
      AND tract_one_to_four_family_homes IS NOT NULL
      AND activity_year = (SELECT y FROM latest)
)
SELECT
    market,
    SUM(homes_1to4) AS homes_1to4,                 -- sum across DISTINCT tracts
    MAX(msa_income) AS msa_median_family_income    -- constant within MSA-year
FROM tract_stock
GROUP BY market;


-- Oppportunity. Combining CAGR, 
CREATE OR REPLACE VIEW opportunity AS
WITH latest AS (
    SELECT MAX(activity_year) AS y FROM market_size
),
-- Per-year YoY, kept for DISPLAY (shows the most recent year's change; also the
-- raw material for any boom-vs-plateau regime comparison).
yoy AS (
    SELECT
        market,
        activity_year,
        100.0 * (total_vol - LAG(total_vol) OVER (PARTITION BY market ORDER BY activity_year))
            / NULLIF(LAG(total_vol) OVER (PARTITION BY market ORDER BY activity_year), 0)
            AS vol_yoy_pct,
        100.0 * (loan_count - LAG(loan_count) OVER (PARTITION BY market ORDER BY activity_year))
            / NULLIF(LAG(loan_count) OVER (PARTITION BY market ORDER BY activity_year), 0)
            AS count_yoy_pct
    FROM market_size
),
-- CAGR across the FULL window (first year -> last year), annualized. Drives the
-- growth tier: robust to one noisy middle year since it depends only on endpoints.
-- arg_min/arg_max return the value at the earliest/latest year per market.
cagr AS (
    SELECT
        market,
        MIN(activity_year) AS first_year,
        MAX(activity_year) AS last_year,
        CASE WHEN arg_min(total_vol, activity_year) > 0
                  AND MAX(activity_year) > MIN(activity_year)
             THEN 100.0 * (POWER(
                    arg_max(total_vol, activity_year) * 1.0
                    / arg_min(total_vol, activity_year),
                    1.0 / (MAX(activity_year) - MIN(activity_year))) - 1)
        END AS vol_cagr_pct,
        CASE WHEN arg_min(loan_count, activity_year) > 0
                  AND MAX(activity_year) > MIN(activity_year)
             THEN 100.0 * (POWER(
                    arg_max(loan_count, activity_year) * 1.0
                    / arg_min(loan_count, activity_year),
                    1.0 / (MAX(activity_year) - MIN(activity_year))) - 1)
        END AS count_cagr_pct
    FROM market_size
    GROUP BY market
),
joined AS (
    SELECT
        s.market,
        s.total_vol,
        s.loan_count,
        s.active_lenders,
        c.hhi,
        c.top5_share_pct,
        r.vol_cagr_pct,
        r.count_cagr_pct,
        y.vol_yoy_pct   AS latest_vol_yoy_pct,
        y.count_yoy_pct AS latest_count_yoy_pct,
        x.homes_1to4,
        x.msa_median_family_income,
        CASE WHEN x.homes_1to4 > 0
            THEN 1000.0 * s.loan_count / x.homes_1to4 END AS orig_per_1000_homes
    FROM market_size s
    JOIN market_concentration c
        ON s.market = c.market AND s.activity_year = c.activity_year
    JOIN cagr r
        ON s.market = r.market
    LEFT JOIN yoy y
        ON s.market = y.market AND s.activity_year = y.activity_year
    LEFT JOIN market_context x
        ON s.market = x.market
    WHERE s.activity_year = (SELECT y FROM latest)
      AND s.active_lenders >= 15
      AND s.market IN (
        SELECT market
        FROM market_size
        GROUP BY market
        HAVING COUNT(DISTINCT activity_year) = (SELECT COUNT(DISTINCT activity_year) FROM market_size)
      )
),
tiered AS (
    SELECT
        *,
        -- growth tier driven by VOLUME CAGR (sustained trajectory, not one noisy year)
        NTILE(10) OVER (ORDER BY vol_cagr_pct)              AS growth_tier,
        -- add-on tier = COUNT CAGR (demand expansion, price-independent)
        NTILE(10) OVER (ORDER BY count_cagr_pct)            AS count_growth_tier,
        -- READING B: low HHI -> high tier (contestable markets = opportunity)
        NTILE(10) OVER (ORDER BY hhi DESC)                  AS concentration_tier,
        -- low penetration -> high tier (more headroom)
        NTILE(10) OVER (ORDER BY orig_per_1000_homes DESC)  AS headroom_tier
    FROM joined
)
SELECT
    market,
    total_vol,
    loan_count,
    active_lenders,
    ROUND(hhi) AS hhi,
    ROUND(vol_cagr_pct, 1)         AS vol_cagr_pct,          -- score driver
    ROUND(count_cagr_pct, 1)       AS count_cagr_pct,        -- add-on
    ROUND(latest_vol_yoy_pct, 1)   AS latest_vol_yoy_pct,    -- display: most recent year
    ROUND(latest_count_yoy_pct, 1) AS latest_count_yoy_pct,  -- display: most recent year
    ROUND(orig_per_1000_homes, 1)  AS orig_per_1000_homes,
    msa_median_family_income,
    growth_tier,
    count_growth_tier,
    concentration_tier,
    headroom_tier,
    ROUND(0.4 * (growth_tier + count_growth_tier) / 2.0 + 0.3*concentration_tier + 0.3*headroom_tier, 2) AS opportunity_score
FROM tiered;



SELECT *
FROM opportunity
ORDER BY opportunity_score DESC 
LIMIT 10;



CREATE OR REPLACE VIEW market_channel AS
SELECT 
    market,
    activity_year,
    ROUND(100.0 * COUNT(*) FILTER (WHERE submission_of_application = 2)
        / NULLIF(COUNT(*) FILTER (WHERE submission_of_application IN (1,2)),0), 1) AS broker_share_pct
FROM base
GROUP BY market, activity_year;


--- COUNTY 
-- HHI measurement per county across years
CREATE OR REPLACE VIEW county_market_concentration AS
SELECT activity_year,
    county_code,
    MAX(county_vol) AS total_vol, 
    COUNT(*) AS active_lenders,
    SUM(POWER(100.0 * lender_vol / county_vol, 2)) AS hhi,
    SUM(CASE WHEN lender_rank <= 5 THEN 100.0 * lender_vol / 
        county_vol END) AS top5_share_pct
FROM(
    SELECT 
        activity_year, 
        county_code,
        lender_vol, 
        county_vol, 
        ROW_NUMBER() OVER (PARTITION BY activity_year, county_code ORDER BY lender_vol DESC) AS lender_rank
    FROM county_lender_share
) ranked
GROUP BY activity_year, county_code;



CREATE OR REPLACE VIEW county_market_context AS
WITH latest AS (
    SELECT MAX(activity_year) AS y
    FROM county_market_size
),
tract_stock AS (
    SELECT DISTINCT
        county_code,
        census_tract,
        tract_one_to_four_family_homes AS homes_1to4
    FROM base
    WHERE county_code  NOT IN ('NA', 'Exempt')
      AND census_tract NOT IN ('NA', 'Exempt')
      AND tract_one_to_four_family_homes IS NOT NULL
      AND activity_year = (SELECT y FROM latest)
),
county_stock AS (
    SELECT county_code,
        SUM(homes_1to4) AS homes_1to4   -- sum across DISTINCT tracts
    FROM tract_stock
    GROUP BY county_code
),
applicant_income AS (
    -- county-native figure: applicant-reported income, not an area statistic
    SELECT county_code,
        MEDIAN(income_num) AS median_applicant_income
    FROM base
    WHERE county_code NOT IN ('NA', 'Exempt')
      AND income_num > 0
      AND income_num < 10000
      AND activity_year = (SELECT y FROM latest)
    GROUP BY county_code
)
SELECT s.county_code,
    s.homes_1to4,
    a.median_applicant_income
FROM county_stock s
LEFT JOIN applicant_income a ON a.county_code = s.county_code;



-- Opportunity score: combining growth, HHI, amd penetration NTILE tiers. 
CREATE OR REPLACE VIEW county_opportunity AS
WITH latest AS (
    SELECT MAX(activity_year) AS y FROM county_market_size
),
yoy AS (
    SELECT
        county_code,
        activity_year,
        100.0 * (total_vol - LAG(total_vol) OVER (PARTITION BY county_code ORDER BY activity_year))
            / NULLIF(LAG(total_vol) OVER (PARTITION BY county_code ORDER BY activity_year), 0)
            AS vol_yoy_pct,
        100.0 * (loan_count - LAG(loan_count) OVER (PARTITION BY county_code ORDER BY activity_year))
            / NULLIF(LAG(loan_count) OVER (PARTITION BY county_code ORDER BY activity_year), 0)
            AS count_yoy_pct
    FROM county_market_size
),
cagr AS (
    SELECT
        county_code,
        MIN(activity_year) AS first_year,
        MAX(activity_year) AS last_year,
        CASE WHEN arg_min(total_vol, activity_year) > 0
                  AND MAX(activity_year) > MIN(activity_year)
             THEN 100.0 * (POWER(
                    arg_max(total_vol, activity_year) * 1.0
                    / arg_min(total_vol, activity_year),
                    1.0 / (MAX(activity_year) - MIN(activity_year))) - 1)
        END AS vol_cagr_pct,
        CASE WHEN arg_min(loan_count, activity_year) > 0
                  AND MAX(activity_year) > MIN(activity_year)
             THEN 100.0 * (POWER(
                    arg_max(loan_count, activity_year) * 1.0
                    / arg_min(loan_count, activity_year),
                    1.0 / (MAX(activity_year) - MIN(activity_year))) - 1)
        END AS count_cagr_pct
    FROM county_market_size
    GROUP BY county_code
),
joined AS (
    SELECT
        s.county_code,
        s.total_vol,
        s.loan_count,
        s.active_lenders,
        c.hhi,
        c.top5_share_pct,
        r.vol_cagr_pct,
        r.count_cagr_pct,
        y.vol_yoy_pct   AS latest_vol_yoy_pct,
        y.count_yoy_pct AS latest_count_yoy_pct,
        x.homes_1to4,
        x.median_applicant_income,
        CASE WHEN x.homes_1to4 > 0
            THEN 1000.0 * s.loan_count / x.homes_1to4 END AS orig_per_1000_homes
    FROM county_market_size s
    JOIN county_market_concentration c
        ON s.county_code = c.county_code AND s.activity_year = c.activity_year
    JOIN cagr r
        ON s.county_code = r.county_code
    LEFT JOIN yoy y
        ON s.county_code = y.county_code AND s.activity_year = y.activity_year
    LEFT JOIN county_market_context x
        ON s.county_code = x.county_code
    WHERE s.activity_year = (SELECT y FROM latest)
      AND s.active_lenders >= 15    -- consider a higher floor for counties
      AND s.loan_count >= 200 -- loan count floor
),
tiered AS (
    SELECT
        *,
        NTILE(10) OVER (ORDER BY vol_cagr_pct)              AS growth_tier,
        NTILE(10) OVER (ORDER BY count_cagr_pct)            AS count_growth_tier,
        NTILE(10) OVER (ORDER BY hhi DESC)                  AS concentration_tier,  -- Reading B
        NTILE(10) OVER (ORDER BY orig_per_1000_homes DESC)  AS headroom_tier
    FROM joined
)
SELECT
    county_code,
    total_vol,
    loan_count,
    active_lenders,
    ROUND(hhi) AS hhi,
    ROUND(vol_cagr_pct, 1)         AS vol_cagr_pct,
    ROUND(count_cagr_pct, 1)       AS count_cagr_pct,
    ROUND(latest_vol_yoy_pct, 1)   AS latest_vol_yoy_pct,
    ROUND(latest_count_yoy_pct, 1) AS latest_count_yoy_pct,
    ROUND(orig_per_1000_homes, 1)  AS orig_per_1000_homes,
    median_applicant_income,
    growth_tier,
    count_growth_tier,
    concentration_tier,
    headroom_tier,
    ROUND(0.4 * (growth_tier + count_growth_tier) / 2.0 + 0.3*concentration_tier + 0.3*headroom_tier, 2) AS opportunity_score
FROM tiered;


SELECT * 
FROM county_opportunity 
ORDER BY opportunity_score DESC 
LIMIT 10;


--- County broker/correspondent channel mix
CREATE OR REPLACE VIEW county_market_channel AS
SELECT
    county_code,
    activity_year,
    ROUND(100.0 * COUNT(*) FILTER (WHERE submission_of_application = 2)
        / NULLIF(COUNT(*) FILTER (WHERE submission_of_application IN (1,2)),0), 1) AS broker_share_pct
FROM base
WHERE county_code NOT IN ('NA', 'Exempt')
GROUP BY county_code, activity_year;



