-- 01_load.sql - load HMDA CA/OR/WA into DuckDB, keeping only needed columns, fix hyphenated names. 

-- CONCEPT: read all state files at once. union_by_name lines columns
-- up by header; sample_size -1 scans all rows for correct types. I SELECT
-- only the columns I will need, so the file's other columns are never stored.
-- NOTE: property_value / interest_rate / loan_term / total_units may load as
-- VARCHAR because they contain ranges or "Exempt".

CREATE OR REPLACE TABLE hmda_raw AS
SELECT
    activity_year,
    lei, 
    state_code,
    county_code,
    census_tract,
    "derived_msa-md" AS derived_msa_md,
    action_taken, 
    loan_purpose, 
    loan_type,
    derived_loan_product_type,
    conforming_loan_limit,
    lien_status,
    "open-end_line_of_credit" AS open_end_line_of_credit,
    reverse_mortgage,
    business_or_commercial_purpose,
    occupancy_type,
    construction_method,
    derived_dwelling_category,
    total_units,
    loan_amount,
    property_value,
    income, 
    interest_rate,
    loan_term,
    purchaser_type,
    submission_of_application,
    initially_payable_to_institution,
    tract_one_to_four_family_homes,
    tract_owner_occupied_units,
    ffiec_msa_md_median_family_income 
FROM read_csv_auto(
    [
    'data/raw/hmda_ca_2023.csv', 'data/raw/hmda_or_2023.csv', 'data/raw/hmda_wa_2023.csv',
    'data/raw/hmda_ca_2024.csv', 'data/raw/hmda_or_2024.csv', 'data/raw/hmda_wa_2024.csv',
    'data/raw/hmda_ca_2025.csv', 'data/raw/hmda_or_2025.csv', 'data/raw/hmda_wa_2025.csv',
    ], 
    sample_size=-1,
    union_by_name=true
);

-- Always check what you loaded:
-- How many rows and how many states?
SELECT COUNT(*) AS total_rows, COUNT(DISTINCT state_code) AS states
FROM hmda_raw;

-- Do column types match expectations.
DESCRIBE hmda_raw;

-- Does the data look correct?
SELECT *
FROM hmda_raw
LIMIT 10;



--  Create the table mapping LEI to respondent name for lender lookup.
CREATE OR REPLACE TABLE lenders AS
SELECT
    activity_year,
    lei,
    respondent_name
FROM read_csv_auto(
    ['data/raw/2023_panel.csv',
    'data/raw/2024_panel.csv',
    'data/raw/2025_panel.csv'], sample_size=-1);

-- Does the data looks correct.
SELECT *
FROM lenders
LIMIT 10;

-- Always check what you loaded: 
-- How many rows?
SELECT COUNT(*) AS total_rows
FROM lenders;

-- What are the column types?
DESCRIBE lenders;


-- Save a compressed Parquet copy of the raw table for fast future reloads.ABORT
COPY hmda_raw TO 'data/processed/hmda_raw.parquet' (FORMAT PARQUET);