-- 06_validate.sql — assertions that PASS silently (0 rows) and FAIL loudly (return rows).
-- Run top-to-bottom. Any result set with rows is a problem; the check_name says which.
-- Thresholds (floors, tolerances) are set to match the pipeline — tune if you changed them.


-- ============================================================
-- SECTION 1 — POPULATION & RECONCILIATION
-- ============================================================

-- 1.1 base reconciles to an independently re-scoped count off hmda_raw.
SELECT '1.1 base_reconciliation' AS check_name, base_n, raw_n, base_n - raw_n AS diff
FROM (
    SELECT (SELECT COUNT(*) FROM base) AS base_n,
           (SELECT COUNT(*) FROM hmda_raw
             WHERE action_taken = 1 AND lien_status = 1 AND occupancy_type = 1
               AND business_or_commercial_purpose = 2 AND loan_purpose = 1
               AND open_end_line_of_credit = 2 AND reverse_mortgage = 2
               AND total_units IN ('1','2','3','4') AND derived_msa_md IS NOT NULL) AS raw_n
)
WHERE base_n <> raw_n;

-- 1.2 No NULLs in the columns every core metric depends on.
SELECT '1.2 core_field_nulls' AS check_name, *
FROM (
    SELECT
        COUNT(*) FILTER (WHERE activity_year IS NULL) AS null_year,
        COUNT(*) FILTER (WHERE market       IS NULL) AS null_market,
        COUNT(*) FILTER (WHERE lei          IS NULL) AS null_lei,
        COUNT(*) FILTER (WHERE loan_amount  IS NULL) AS null_loan_amount,
        COUNT(*) FILTER (WHERE lender_name  IS NULL) AS null_lender_name
    FROM base
)
WHERE null_year + null_market + null_lei + null_loan_amount + null_lender_name > 0;

-- 1.3 Every year is comparably sized (protects growth). Flags a year < 50% of the largest.
SELECT '1.3 year_comparability' AS check_name, activity_year, n,
       ROUND(100.0 * n / MAX(n) OVER (), 1) AS pct_of_largest
FROM (SELECT activity_year, COUNT(*) AS n FROM base GROUP BY activity_year)
QUALIFY ROUND(100.0 * n / MAX(n) OVER (), 1) < 50;

-- 1.4 The same markets appear in every year (a market missing a year breaks CAGR/YoY).
-- NOTE: Excluded boundary-broken codes from the metro growth ranking only. The Seattle metro codes (42644, 21794, and King's codes) 
-- get flagged out of metro CAGR because no honest metro-level multi-year series exists for them. But King and Snohomish still appear — correctly,
--  with real growth — in the county ranking. Lose them from the metro opportunity list, not from the analysis
SELECT '1.4 market_year_coverage' AS check_name, market, n_years, total_years
FROM (
    SELECT market,
           COUNT(DISTINCT activity_year) AS n_years,
           (SELECT COUNT(DISTINCT activity_year) FROM base) AS total_years
    FROM base
    WHERE market <> '99999'
    GROUP BY market
)
WHERE n_years < total_years;

-- 1.4b The same county appears in every year.
SELECT county_code, COUNT(DISTINCT activity_year) AS n_years
FROM base WHERE county_code NOT IN ('NA','Exempt')
GROUP BY county_code
HAVING COUNT(DISTINCT activity_year) < (SELECT COUNT(DISTINCT activity_year) FROM base);


-- ============================================================
-- SECTION 2 — LENDER IDENTITY / JOIN INTEGRITY
-- ============================================================

-- 2.1 lenders_clean is one row per LEI (guarantees the join cannot fan out).
SELECT '2.1 lenders_clean_uniqueness' AS check_name, lei, COUNT(*) AS n
FROM lenders_clean
GROUP BY lei
HAVING COUNT(*) > 1;

-- 2.2 No LEI carries more than one lender_name inside base (join stayed 1:1 on name).
SELECT '2.2 lei_one_name_in_base' AS check_name, lei, COUNT(DISTINCT lender_name) AS n_names
FROM base
GROUP BY lei
HAVING COUNT(DISTINCT lender_name) > 1;

-- 2.3 Unmatched-name rate within tolerance (loans whose name fell through to the LEI).
SELECT '2.3 unmatched_name_rate' AS check_name,
       total, unmatched, ROUND(100.0*unmatched/total, 3) AS pct
FROM (
    SELECT COUNT(*) AS total,
           COUNT(*) FILTER (WHERE lender_name = lei) AS unmatched
    FROM base
)
WHERE ROUND(100.0*unmatched/total, 3) > 0.5;   -- tune to your accepted rate


-- ============================================================
-- SECTION 3 — SHARE & CONCENTRATION (metro)
-- ============================================================

-- 3.1 Lender shares sum to ~100% within every market-year.
SELECT '3.1 shares_sum_to_100' AS check_name, activity_year, market, total_share
FROM (
    SELECT activity_year, market,
           ROUND(SUM(100.0 * lender_vol / market_vol), 2) AS total_share
    FROM lender_share
    GROUP BY activity_year, market
)
WHERE ABS(total_share - 100.0) > 0.1;

-- 3.2 HHI within mathematical bounds (0, 10000].
SELECT '3.2 hhi_bounds' AS check_name, activity_year, market, hhi
FROM market_concentration
WHERE hhi <= 0 OR hhi > 10000.0001;

-- 3.3 top5_share_pct in [0, 100].
SELECT '3.3 top5_share_bounds' AS check_name, activity_year, market, top5_share_pct
FROM market_concentration
WHERE top5_share_pct < 0 OR top5_share_pct > 100.0001;

-- 3.4 active_lenders positive.
SELECT '3.4 active_lenders_positive' AS check_name, activity_year, market, active_lenders
FROM market_concentration
WHERE active_lenders <= 0;


-- ============================================================
-- SECTION 4 — CONTEXT / PENETRATION (metro)
-- ============================================================

-- 4.1 market_context is one row per market (DISTINCT-tract dedup worked).
SELECT '4.1 context_one_row_per_market' AS check_name, market, COUNT(*) AS n
FROM market_context
GROUP BY market
HAVING COUNT(*) > 1;

-- 4.2 Housing stock positive where present.
SELECT '4.2 homes_positive' AS check_name, market, homes_1to4
FROM market_context
WHERE homes_1to4 IS NOT NULL AND homes_1to4 <= 0;

-- 4.3 Penetration not absurd (> 1000 origs per 1000 homes = denominator problem).
SELECT '4.3 penetration_sane' AS check_name, market, orig_per_1000_homes
FROM opportunity
WHERE orig_per_1000_homes > 1000;


-- ============================================================
-- SECTION 5 — OPPORTUNITY OUTPUT (metro)
-- ============================================================

-- 5.1 All tiers within 1..10.
SELECT '5.1 tier_bounds' AS check_name, market,
       growth_tier, count_growth_tier, concentration_tier, headroom_tier
FROM opportunity
WHERE growth_tier         NOT BETWEEN 1 AND 10
   OR count_growth_tier   NOT BETWEEN 1 AND 10
   OR concentration_tier  NOT BETWEEN 1 AND 10
   OR headroom_tier       NOT BETWEEN 1 AND 10;

-- 5.2 opportunity_score within its weighted range [1.0, 10.0].
SELECT '5.2 score_bounds' AS check_name, market, opportunity_score
FROM opportunity
WHERE opportunity_score < 1.0 OR opportunity_score > 10.0;

-- 5.3 Every ranked metro clears BOTH floors (lender >=15 and loan count >= 250).
SELECT '5.3 floors_enforced' AS check_name, market, active_lenders, loan_count
FROM opportunity
WHERE active_lenders < 15 OR loan_count < 250;

-- 5.4 Reading-B direction sanity: the lowest-HHI markets should hold the HIGHEST
-- concentration_tier. Fails if a bottom-quartile-HHI market lands in a low tier.
SELECT '5.4 hhi_direction_readingB' AS check_name, market, hhi, concentration_tier
FROM opportunity
QUALIFY hhi <= QUANTILE_CONT(hhi, 0.25) OVER () AND concentration_tier < 6;

-- 5.5 CAGR present for every ranked market (NULL CAGR would mis-tier).
SELECT '5.5 cagr_not_null' AS check_name, market, vol_cagr_pct, count_cagr_pct
FROM opportunity
WHERE vol_cagr_pct IS NULL OR count_cagr_pct IS NULL;


-- ============================================================
-- SECTION 6 — COUNTY PARALLELS
-- ============================================================

-- 6.1 County shares sum to ~100% within county-year.
SELECT '6.1 county_shares_sum_100' AS check_name, activity_year, county_code, total_share
FROM (
    SELECT activity_year, county_code,
           ROUND(SUM(100.0 * lender_vol / county_vol), 2) AS total_share
    FROM county_lender_share
    GROUP BY activity_year, county_code
)
WHERE ABS(total_share - 100.0) > 0.1;

-- 6.2 County HHI bounds.
SELECT '6.2 county_hhi_bounds' AS check_name, activity_year, county_code, hhi
FROM county_market_concentration
WHERE hhi <= 0 OR hhi > 10000.0001;

-- 6.3 County context one row per county.
SELECT '6.3 county_context_unique' AS check_name, county_code, COUNT(*) AS n
FROM county_market_context
GROUP BY county_code
HAVING COUNT(*) > 1;

-- 6.4 County opportunity clears BOTH floors(active lenders >= 15 and loan count >= 200 (less than metro due to the difference in size))
SELECT '6.4 county_floors_enforced' AS check_name, county_code, active_lenders, loan_count
FROM county_opportunity
WHERE active_lenders < 15 OR loan_count < 200;

-- 6.5 County tiers within 1..10.
SELECT '6.5 county_tier_bounds' AS check_name, county_code,
       growth_tier, count_growth_tier, concentration_tier, headroom_tier
FROM county_opportunity
WHERE growth_tier         NOT BETWEEN 1 AND 10
   OR count_growth_tier   NOT BETWEEN 1 AND 10
   OR concentration_tier  NOT BETWEEN 1 AND 10
   OR headroom_tier       NOT BETWEEN 1 AND 10;

-- 6.6 County penetration sane.
SELECT '6.6 county_penetration_sane' AS check_name, county_code, orig_per_1000_homes
FROM county_opportunity
WHERE orig_per_1000_homes > 1000;


-- ============================================================
-- END — every section returning 0 rows == pipeline validated.
-- ============================================================