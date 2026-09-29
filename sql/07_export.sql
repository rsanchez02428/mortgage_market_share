-- ============================================================
-- SNAPSHOT TABLES (latest year only) — feed the static Opportunity pages.
-- ============================================================
 
-- Metro opportunity: the headline ranked table + map source.
COPY (SELECT * FROM opportunity)
  TO 'data/exports/opportunity.parquet' (FORMAT PARQUET);
 
-- County opportunity: drill-through / county page source.
COPY (SELECT * FROM county_opportunity)
  TO 'data/exports/county_opportunity.parquet' (FORMAT PARQUET);
 
-- Metro context (housing stock, MSA income) — supporting detail on metro pages.
COPY (SELECT * FROM market_context)
  TO 'data/exports/market_context.parquet' (FORMAT PARQUET);
 
-- County context (housing stock, applicant income).
COPY (SELECT * FROM county_market_context)
  TO 'data/exports/county_market_context.parquet' (FORMAT PARQUET);


-- ============================================================
-- YEARLY FACT TABLES (all years) — feed the year-sliced size/share/concentration.
-- ============================================================
 
-- Metro size by year (volume, loan_count, active_lenders).
COPY (SELECT * FROM market_size)
  TO 'data/exports/market_size.parquet' (FORMAT PARQUET);
 
-- Metro concentration by year (HHI, top5_share).
COPY (SELECT * FROM market_concentration)
  TO 'data/exports/market_concentration.parquet' (FORMAT PARQUET);
 
-- Metro lender share by year (per-lender volume & share) — competition page.
COPY (SELECT * FROM lender_share)
  TO 'data/exports/lender_share.parquet' (FORMAT PARQUET);
 
-- Metro broker/channel mix by year.
COPY (SELECT * FROM market_channel)
  TO 'data/exports/market_channel.parquet' (FORMAT PARQUET);

-- County parallels.
COPY (SELECT * FROM county_market_size)
  TO 'data/exports/county_market_size.parquet' (FORMAT PARQUET);
COPY (SELECT * FROM county_market_concentration)
  TO 'data/exports/county_market_concentration.parquet' (FORMAT PARQUET);
COPY (SELECT * FROM county_lender_share)
  TO 'data/exports/county_lender_share.parquet' (FORMAT PARQUET);
COPY (SELECT * FROM county_market_channel)
  TO 'data/exports/county_market_channel.parquet' (FORMAT PARQUET);


-- ============================================================
-- DIMENSION TABLES — small lookups that make the Power BI model clean.
-- ============================================================
 
-- Year dimension: drives the Year slicer on the yearly pages.
COPY (
    SELECT DISTINCT activity_year
    FROM market_size
    ORDER BY activity_year
) TO 'data/exports/dim_year.parquet' (FORMAT PARQUET);
 
-- Metro dimension: one row per market, for the slicer / map / relationships.
-- Includes a friendly label and the state(s) it touches, for display.
COPY (
    SELECT
        m.market,
        MAX(x.msa_median_family_income) AS msa_median_family_income,
        STRING_AGG(DISTINCT b.state_code, ', ' ORDER BY b.state_code) AS states
    FROM market_size m
    LEFT JOIN market_context x ON m.market = x.market
    LEFT JOIN base b           ON m.market = b.market
    GROUP BY m.market
) TO 'data/exports/dim_market.parquet' (FORMAT PARQUET);
 
-- County dimension: one row per county, with state, for map + relationships.
COPY (
    SELECT DISTINCT
        county_code,
        SUBSTR(county_code, 1, 2) AS state_fips   -- first 2 digits of FIPS = state
    FROM county_market_size
    WHERE county_code NOT IN ('NA','Exempt')
) TO 'data/exports/dim_county.parquet' (FORMAT PARQUET);
 
-- Lender dimension: one canonical name per LEI, for the competition page.
COPY (SELECT lei, lender_name FROM lenders_clean)
  TO 'data/exports/dim_lender.parquet' (FORMAT PARQUET);