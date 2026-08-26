# Devlog - Mortgage Market Share

`Newest entry on top. Each entry captures what I did, why, what I learened, and where aI stopped. The reasoning that a README can't hold and that I lose fastest after time away.**Re-onboarding? Read the top 2-3 entries and you're all caught up.** Write the entry *when I stop working*, not when I come back.`

---

## Template for entries

```markdown
## YYYY-MM-DD - one-line summary of where I'm leaving off

**What I did:**
**Why:**
**What I learned / what surprised me:**
**Where I'm stopping and why:**
**Next when I return:**
```

---

## 2026-08-25 - EDA on raw data

**What I did:** Created 02_profile.sql file. Within this file, I conducted exploratory data analysis on the raw data. The EDA answers questions such as:
    - What does the data look like?
    - How many records per action taken?
    - How many records per each loan purpose?
    - How many records per state?
    - How many records per state as a share of a given years total records?
    - How many NA values does each column have given the findings from the datas summary?
    - How many NA values acorss each state for each year?
    - How many regions are untraceable?
    - How many records have NA for income/interest_rate/property_value, alone and stacked?
    - How many records per each conforming_loaan_limit value?
    - How many records per each derived dwelling category?
    - How many records per each derived dwelling category given if its a business or commercial purpose?
    - Across the years, how many records per each amount of units?
    - What does the distribution of loan_amount look like?
    - Given the derived_dwelling_category, the total_units for each derived_dwelling_category, and whether its for business or commerical use, how many records fall under each that surpasses a loan amount of 30,000,000 and what is the max loan amount in that category?
    - What does the distribution of property_value look like under each type of dwelling_category?
    - What does the distribution of income look like for each derived_dwelling_category that is for business and commerical use and had the loan originated by the instiution?
    - How many records that have been originated have an income value of 0 or less?
    - What does the distribution of the interest rate look like for every given year for every look that had been originated?
    - How many loans, given that the loan has been originated and the loans type, has an interest rate below 3%?
    - What is the disribution of loan term, given that the loan was originated and the purpose of the loan?
    - What does the distribution fo submission_of_application look like across years given that the loan has been originated by the institution?
    - How many loans that have been originated are initially payable to the institution?
    - How many LEIs are mapped to more than one lenders name within the same year?
    - How many LEIs are mapped to more than one lender name across years?
    - Hoe many lender names map to multiple LEIs?
**What I learned / what surprised me:** 
**Where I'm stopping and why:**
**Next when I return:**

---

## 2026-08-02 - Created necessary the necessary tables in duckdb

**What I did:**  Created the 01_load.sql file. Created tables 'hmda_raw' and 'lenders'. For each table, I only extracted the necessary columns needed for this analysis and corrected variable(column) names. Queried the tables respectively to ensure the data uploaded correctly and were the correct data type. Finally saved hmda_raw as a compressed parquet file.
**Why:** 
**What I learned / what surprised me:**
**Where I'm stopping and why:**
**Next when I return:**

---

## 2026-07-31 - Project structure constructed and data extracted

**What I did:** Created the projects file and stucture. Respectively extracted 3 years (2023, 2024, 2025) of mortgage data for California, Washington, and Oregon from [HMDA Data Browser](https://ffiec.cfpb.gov/data-browser/) and extracted institution lei/name data for the same 3 years from the [Snapshot National Loan Level Dataset](https://ffiec.cfpb.gov/data-publication/snapshot-national-loan-level-dataset). Stored all extracted data inside `data/raw/`.
**Why:**  
**What I learned / what surprised me:** 
**Where I'm stopping and why:**
**Next when I return:**
