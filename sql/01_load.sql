-- 01_load.sql - load HMDA CA/OR/WA into DuckDB, keeping only needed columns. 

-- CONCEPT: read all state files at once. union_by_name lines up
-- columns by header (not position); sample_size = -1 scans all rows for 
-- accurate type inference. I SELECT only the 12 columns I need, so the
-- other columns in the file are never materialized.

CREATE OR REPLACE TABLE hmda_raw AS
SELECT
    activity_year,
    lei, 
    state_code,
    "derived_msa-md",
    action_taken, 
    loan_purpose, 
    loan_type, 
    loan_amount,
    income, 
    occupancy_type, 
    lien_status, 
    business_or_commercial_purpose
FROM read_csv_auto(
    [
    'data/raw/hmda_ca_2023.csv', 'data/raw/hmda_or_2023.csv', 'data/raw/hmda_wa_2023.csv',
    'data/raw/hmda_ca_2024.csv', 'data/raw/hmda_or_2024.csv', 'data/raw/hmda_wa_2024.csv',
    'data/raw/hmda_ca_2025.csv', 'data/raw/hmda_or_2025.csv', 'data/raw/hmda_wa_2025.csv',
    ], 
    sample_size=-1,
    union_by_name=true
);

-- Always check what you loaded: how many rows, how many states, what types?
SELECT COUNT(*) AS total_rows, COUNT(DISTINCT state_code) AS states
FROM hmda_raw;
DESCRIBE hmda_raw;

-- View the first few rows to ensure the data looks correct.
SELECT *
FROM hmda_raw
LIMIT 10;

--  Create a table mapping LEI to respondent name for lender lookup.
CREATE OR REPLACE TABLE lenders AS
SELECT
    lei,
    respondent_name
FROM read_csv_auto('data/raw/panel.csv', sample_size=-1);

-- View the first few rows to ensure the data looks correct.
SELECT *
FROM lenders
LIMIT 10;

-- Always check what you loaded: how many rows, what types?
SELECT COUNT(*) AS total_rows
FROM lenders;
DESCRIBE lenders;


-- Save a compressed Parquet copy of the raw table for fast future reloads.ABORT
COPY hmda_raw TO 'data/processed/hmda_raw.parquet' (FORMAT PARQUET);