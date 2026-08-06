-- 02_profile.sql - understand the data before trusting it.

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

--- loan-amount distribution on RAW data (still has multifamily/commercial).
SELECT MIN(loan_amount) AS min_loan, MEDIAN(loan_amount) AS median_loan,
    QUANTILE_CONT(loan_amount, 0.99) AS p99, MAX(loan_amount) AS max_loan
FROM hmda_raw
WHERE action_taken = 1;

--- Investigate the giants BEFORE cutting: why is a loan $500M+?
-- Almost always multifamily or business - i.e., not a house. The fix is
-- STRUCTURAL (scopr the population), not an arbitrary cap.
SELECT derived_dwelling_category, total_units, business_or_commercial_purpose, 
    COUNT(*) AS n, MAX(loan_amount) AS max_loan
FROM hmda_raw
WHERE loan_amount > 30000000
GROUP BY 1, 2, 3
ORDER BY n DESC;

