-- create_clean_tables.sql

-- 1) Creates/uses the 'vienna_mobility' database.
-- 2) Renames columns where necessary (e.g., ref_year => data_year).
-- 3) Removes primary keys that weren't unique.
-- 4) Drops columns that are no longer relevant (e.g., ref_year).
-- 5) Cleans duplicates by creating temporary tables, then replacing the originals.

--------------------------------------------------------------------------------
-- STEP 1: CREATE OR USE DATABASE
--------------------------------------------------------------------------------
-- 1A) vienna_mobility
CREATE DATABASE IF NOT EXISTS vienna_mobility;
USE vienna_mobility;

-- 1B) Use the Table Data Import Wizard in MySQL Workbench 

-- to import the relevant CSV files for:
--   1) annual_tickets
--   2) annual_tickets_cars
--   3) mode_share
--   4) pkw_population
--   5) ridership
-- Make sure to map only the columns you need (dropping redundant columns such as NUTS1, NUTS2, DISTRICT_CODE, etc.) if using original_data. 
-- If using cleaned_data, map all the columns there are.
-- Once the data is loaded, proceed with the schema adjustments below.


--------------------------------------------------------------------------------
-- STEP 2: RENAME 'ref_year' TO 'data_year' IN annual_tickets_cars
--------------------------------------------------------------------------------
ALTER TABLE annual_tickets_cars
  CHANGE COLUMN ref_year data_year INT NOT NULL
  COMMENT 'Renamed from ref_year; this column is the actual data year';

--------------------------------------------------------------------------------
-- STEP 3: REMOVE PRIMARY KEYS IN TABLES (THEY WERE NOT UNIQUE)
--------------------------------------------------------------------------------
ALTER TABLE annual_tickets DROP PRIMARY KEY;
ALTER TABLE ridership DROP PRIMARY KEY;
ALTER TABLE pkw_population DROP PRIMARY KEY;
ALTER TABLE mode_share DROP PRIMARY KEY;

--------------------------------------------------------------------------------
-- STEP 4: DROP THE 'ref_year' COLUMN (NO LONGER NEEDED)
--------------------------------------------------------------------------------
ALTER TABLE annual_tickets DROP COLUMN ref_year;
ALTER TABLE ridership DROP COLUMN ref_year;
ALTER TABLE pkw_population DROP COLUMN ref_year;
ALTER TABLE mode_share DROP COLUMN ref_year;

--------------------------------------------------------------------------------
-- STEP 5: CLEAN AND DEDUPLICATE TABLES
--------------------------------------------------------------------------------

-- 5A) annual_tickets
CREATE TABLE annual_tickets_clean AS
SELECT
  data_year,
  MAX(ticket_count) AS ticket_count
FROM annual_tickets
GROUP BY data_year;
DROP TABLE annual_tickets;
RENAME TABLE annual_tickets_clean TO annual_tickets;

-- 5B) mode_share
CREATE TABLE mode_share_clean AS
SELECT 
  data_year,
  bicycle,
  bikesharing,
  by_foot,
  car,
  carsharing,
  motorbike,
  public_transport
FROM
(
  SELECT
    *,
    ROW_NUMBER() OVER (PARTITION BY data_year ORDER BY data_year) AS row_num
  FROM mode_share
) dt
WHERE row_num = 1;
DROP TABLE mode_share;
RENAME TABLE mode_share_clean TO mode_share;

-- 5C) pkw_population
CREATE TABLE pkw_population_clean AS
SELECT
  data_year,
  district,
  passenger_cars,
  population
FROM
(
  SELECT
    *,
    ROW_NUMBER() OVER (
      PARTITION BY data_year, district
      ORDER BY data_year, district
    ) AS row_num
  FROM pkw_population
) dt
WHERE row_num = 1;
DROP TABLE pkw_population;
RENAME TABLE pkw_population_clean TO pkw_population;

-- 5D) ridership
CREATE TABLE ridership_clean AS
SELECT DISTINCT *
FROM ridership;
DROP TABLE ridership;
RENAME TABLE ridership_clean TO ridership;

--------------------------------------------------------------------------------
-- (OPTIONAL) STEP 6: CHECK ROW COUNTS
--------------------------------------------------------------------------------
SELECT "annual_tickets" table__name, COUNT(*) row_counts FROM annual_tickets # Initially were 77 rows, after data cleaning 14
UNION
SELECT "annual_tickets_cars" table__name, COUNT(*) row_counts FROM annual_tickets_cars # 20
UNION
SELECT "mode_share" table__name, COUNT(*) row_counts FROM mode_share # Initially were 95 rows, after data cleaning 20
UNION
SELECT "pkw_population" table__name, COUNT(*) row_counts FROM pkw_population # Initially were 328 rows, after data cleaning 188
UNION
SELECT "ridership" table__name, COUNT(*) row_counts FROM ridership; # Initially were 168 rows, after data cleaning 27

--------------------------------------------------------------------------------
-- END OF create_clean_tables.sql
--------------------------------------------------------------------------------
