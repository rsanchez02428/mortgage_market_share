
-- one clean name per LEI, built once
CREATE OR REPLACE TABLE lenders_clean AS
SELECT lei, respondent_name AS lender_name
FROM (
    SELECT lei, respondent_name, activity_year,
           ROW_NUMBER() OVER (PARTITION BY lei ORDER BY activity_year DESC) AS rn
    FROM lenders
    WHERE respondent_name <> lei          -- skip junk-field years where name = LEI
)
WHERE rn = 1;


CREATE OR REPLACE TABLE lender_overrides (lei VARCHAR, lender_name VARCHAR);

INSERT INTO lender_overrides VALUES
  ('5493006L4FQIQFVFNS72', 'Mega Capital Funding, Inc.');


