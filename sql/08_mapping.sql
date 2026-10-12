
-- MSA name mapping tables for lookup.
CREATE OR REPLACE TABLE market_names AS
SELECT 
    CAST("MSA State" AS VARCHAR) AS state_code,
    CAST("MSA code" AS VARCHAR) AS market, 
    CAST("MSA Title" AS VARCHAR) AS market_name,
FROM read_csv_auto('data/raw/msa_codes_2025onward.csv', header=true);

-- MSA name overrides for specific markets that are not in the official list.
CREATE OR REPLACE TABLE market_overrides (state_code VARCHAR, market VARCHAR, market_name VARCHAR);
INSERT INTO market_overrides VALUES
  ('WA', '42644', 'Seattle-Bellevue-Kent'),
  ('CA', '36084', 'Oakland-Fremont-Berkeley'),
  ('CA', '11244', 'Anaheim-Santa Ana-Irvine'),
  ('CA', '42034', 'San Rafael'),
  ('WA', '45104','Tacoma-Lakewood'),
  ('CA', '31084', 'Los Angeles-Long Beach-Glendale'),
  ('CA', '41884', 'San Francisco-San Mateo-Redwood City'),
  ('CA', '44700', 'Stockton-Lodi'),
  ('WA', '21794', 'Everett'),
  ('CA', '31460', 'Madera');



-- County name mapping table for lookup.
CREATE OR REPLACE TABLE county_names AS
SELECT 
    CAST(State AS VARCHAR) AS state,
    CAST("State FIPS" AS VARCHAR) AS state_code,
    CAST("Full FIPS" AS VARCHAR) AS county_code,
    CAST("County Name" AS VARCHAR) AS county_name
FROM read_csv_auto('data/raw/county_fips.csv', header=true);



-- Produces the exact set of MSA codes you must name, with a loan-count so you
-- can prioritize.
SELECT
    market AS msa_code,
    COUNT(*) AS loans,
    STRING_AGG(DISTINCT state_code, ', ' ORDER BY state_code) AS states
FROM base
WHERE market <> '99999'
GROUP BY market
ORDER BY loans DESC;

-- Same for counties:
SELECT
    county_code AS county_fips,
    SUBSTR(county_code, 1, 2) AS state_fips,
    COUNT(*) AS loans
FROM base
WHERE county_code NOT IN ('NA','Exempt')
GROUP BY county_code
ORDER BY loans DESC;



-- Metro mapping
    SELECT m.market,
           COALESCE(ovr.market_name, n.market_name, CAST(m.market as VARCHAR)) AS market_name,   -- name, fallback to code
           MAX(x.msa_median_family_income) AS msa_median_family_income,
           STRING_AGG(DISTINCT b.state_code, ', ' ORDER BY b.state_code) AS states
    FROM market_size m
    LEFT JOIN market_overrides ovr ON m.market = ovr.market
    LEFT JOIN market_names n     ON m.market = n.market
    LEFT JOIN market_context x ON m.market = x.market
    LEFT JOIN base b           ON m.market = b.market
    WHERE m.market <> 99999
    GROUP BY m.market, ovr.market_name, n.market_name;



-- county mapping
  SELECT DISTINCT c.county_code,
           COALESCE(n.county_name, c.county_code) AS county_name
    FROM county_market_size c
    LEFT JOIN county_names n ON c.county_code = n.county_code
    WHERE c.county_code NOT IN ('NA','Exempt');


-- Distinct counties and metros per year
SELECT
    activity_year,
    COUNT(DISTINCT CASE WHEN county_code NOT IN ('NA', 'Exempt') THEN county_code END) AS counties,
    COUNT(DISTINCT CASE WHEN market <> '99999' THEN market END)                        AS metros
FROM base
GROUP BY activity_year
ORDER BY activity_year;

-- Count of counties in the county_opportunity table
SELECT
    COUNT(county_code) AS counties
FROM county_opportunity;


-- Count of metros in the opportunity table
SELECT
    COUNT(market) AS metros
FROM opportunity;