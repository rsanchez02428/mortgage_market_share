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


-- MSA & MD mapping: one row per market, with name and states
COPY  (SELECT CAST(m.market as VARCHAR) AS market,
          COALESCE(ovr.market_name, n.market_name, CAST(m.market as VARCHAR)) AS market_name,   -- name, fallback to code
          MAX(x.msa_median_family_income) AS msa_median_family_income,
          STRING_AGG(DISTINCT b.state_code, ', ' ORDER BY b.state_code) AS states
      FROM market_size m
      LEFT JOIN market_overrides ovr ON m.market = ovr.market
      LEFT JOIN market_names n     ON m.market = n.market
      LEFT JOIN market_context x ON m.market = x.market
      LEFT JOIN base b           ON m.market = b.market
      WHERE m.market <> 99999
      GROUP BY m.market, ovr.market_name, n.market_name
    ) TO 'data/exports/dim_market.parquet' (FORMAT PARQUET);

-- County mapping: one row per county, with name and state
COPY(SELECT DISTINCT c.county_code,
           COALESCE(n.county_name, c.county_code) AS county_name,
           SUBSTR(c.county_code, 1, 2) AS state_fips
    FROM county_market_size c
    LEFT JOIN county_names n ON c.county_code = n.county_code
    WHERE c.county_code NOT IN ('NA','Exempt')
) TO 'data/exports/dim_county.parquet' (FORMAT PARQUET);
 

-- Lender dimension: one canonical name per LEI, for the competition page.
COPY (SELECT lei, lender_name FROM lenders_clean)
  TO 'data/exports/dim_lender.parquet' (FORMAT PARQUET);

--