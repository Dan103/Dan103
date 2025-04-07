CREATE DATABASE IF NOT EXISTS vienna_mobility;
USE vienna_mobility;

-- annual_tickets_cars: RENAME ref_year => data_year
ALTER TABLE annual_tickets_cars
  CHANGE COLUMN ref_year data_year INT NOT NULL 
  COMMENT 'Renamed from ref_year; this column is the actual data year';

-- Remove the existing PK in each table
ALTER TABLE annual_tickets
  DROP PRIMARY KEY;

ALTER TABLE ridership
  DROP PRIMARY KEY;

ALTER TABLE pkw_population
  DROP PRIMARY KEY;

ALTER TABLE mode_share
  DROP PRIMARY KEY;

-- Drop the ref_year column
ALTER TABLE annual_tickets
  DROP COLUMN ref_year;

ALTER TABLE ridership
  DROP COLUMN ref_year;

ALTER TABLE pkw_population
  DROP COLUMN ref_year;

ALTER TABLE mode_share
  DROP COLUMN ref_year;


-- Final removal of duplicates
# 1
CREATE TABLE annual_tickets_clean AS
SELECT data_year, MAX(ticket_count) ticket_count FROM annual_tickets GROUP BY data_year;
DROP TABLE annual_tickets;
RENAME TABLE annual_tickets_clean TO annual_tickets;
# 2 
CREATE TABLE mode_share_clean AS
SELECT data_year, bicycle, bikesharing, by_foot, car, carsharing, motorbike, public_transport FROM (SELECT *, ROW_NUMBER() OVER (PARTITION BY data_year ORDER BY data_year) AS row_num FROM mode_share) dt WHERE row_num = 1;
DROP TABLE mode_share;
RENAME TABLE mode_share_clean TO mode_share;
# 3
CREATE TABLE pkw_population_clean AS
SELECT data_year, district, passenger_cars, population FROM (SELECT *, ROW_NUMBER() OVER(PARTITION BY data_year, district ORDER BY data_year, district) row_num FROM pkw_population) dt WHERE row_num = 1;
DROP TABLE pkw_population;
RENAME TABLE pkw_population_clean TO pkw_population;
# 4
CREATE TABLE ridership_clean AS
SELECT DISTINCT * FROM ridership;
DROP TABLE ridership;
RENAME TABLE ridership_clean TO ridership;

-- Check Row Counts in each table
SELECT "annual_tickets" table__name, COUNT(*) row_counts FROM annual_tickets # Initially were 77 rows, after data cleaning 14
UNION
SELECT "annual_tickets_cars" table__name, COUNT(*) row_counts FROM annual_tickets_cars # 20
UNION
SELECT "mode_share" table__name, COUNT(*) row_counts FROM mode_share # Initially were 95 rows, after data cleaning 20
UNION
SELECT "pkw_population" table__name, COUNT(*) row_counts FROM pkw_population # Initially were 328 rows, after data cleaning 188
UNION
SELECT "ridership" table__name, COUNT(*) row_counts FROM ridership; # Initially were 168 rows, after data cleaning 27

-- Preview Sample Rows to ensure values loaded correctly and columns are numeric where expected
# Everything seems to be okay:
SELECT * FROM annual_tickets;
SELECT * FROM annual_tickets_cars;
SELECT * FROM mode_share;
SELECT * FROM pkw_population;
SELECT * FROM ridership;






-- Perform Simple Joins
-- Join annual_tickets & ridership on (data_year, ref_year) to see if ticket_count aligns with bus/tram/underground usage
# 1 simple option
SELECT
	ant.data_year,
    FORMAT(ant.ticket_count, 0) annual_passes,
    FORMAT((r.bus + r.tram + r.underground), 0) total_rides,
    FORMAT((r.bus + r.tram + r.underground) / ant.ticket_count , 2) rides_per_ticket
FROM
    annual_tickets ant
        JOIN
    ridership r ON ant.data_year = r.data_year
ORDER BY data_year;
        
# 2 complicated one
SELECT
	ant.data_year,
    FORMAT(ant.ticket_count, 0) annual_passes,
    CASE
		WHEN LAG(ticket_count) OVER(ORDER BY data_year) IS NULL OR LAG(ticket_count) OVER(ORDER BY data_year) = 0 THEN "No previous value" 
        ELSE CONCAT(FORMAT((ticket_count - LAG(ticket_count) OVER(ORDER BY data_year)) * 100.0 / LAG(ticket_count) OVER(ORDER BY data_year), 2), '%')
    END annual_passes_growth,
    
    
    FORMAT((r.bus + r.tram + r.underground), 0) total_rides,
    CASE
		WHEN LAG((r.bus + r.tram + r.underground)) OVER(ORDER BY data_year) IS NULL OR LAG((r.bus + r.tram + r.underground)) OVER(ORDER BY data_year) = 0 THEN "No previous value" 
        ELSE CONCAT(FORMAT(((r.bus + r.tram + r.underground) - LAG((r.bus + r.tram + r.underground)) OVER(ORDER BY data_year)) * 100.0 / LAG((r.bus + r.tram + r.underground)) OVER(ORDER BY data_year), 2), '%')
    END total_rides_growth,
    
    FORMAT((r.bus + r.tram + r.underground) / ant.ticket_count , 2) rides_per_ticket,
    CASE
		WHEN LAG((r.bus + r.tram + r.underground) / ant.ticket_count) OVER(ORDER BY data_year) IS NULL OR LAG((r.bus + r.tram + r.underground) / ant.ticket_count) OVER(ORDER BY data_year) = 0 THEN "No previous value" 
        ELSE CONCAT(FORMAT(((r.bus + r.tram + r.underground) / ant.ticket_count  - LAG((r.bus + r.tram + r.underground) / ant.ticket_count) OVER(ORDER BY data_year)) * 100.0 / LAG((r.bus + r.tram + r.underground) / ant.ticket_count) OVER(ORDER BY data_year), 2), '%')
    END rides_per_ticket_growth
FROM
    annual_tickets ant
        JOIN
    ridership r ON ant.data_year = r.data_year
ORDER BY data_year;

-- Join annual_tickets_cars with annual_tickets if you want to compare ticket_count vs. tic_value from the same ref_year
SELECT
	ant.data_year,
    ant.ticket_count,
    atc.tic_value,
    CASE
		WHEN (tic_value - ticket_count) = 0 THEN "Same value"
        ELSE (tic_value - ticket_count)
    END diff_tickets,
    CASE
		WHEN (tic_value - ticket_count) = 0 THEN "Same value"
        ELSE CONCAT((tic_value - ticket_count) * 100 / ticket_count, " %")
    END pct_diff
FROM
    annual_tickets ant
        JOIN
    annual_tickets_cars atc ON ant.data_year = atc.data_year;


-- Apply Aggregations & Grouping
-- Group ridership by data_year to see total ridership across bus/tram/underground
SELECT
	data_year,
    FORMAT(SUM(bus),0) bus_total,
    FORMAT(SUM(tram),0) tram_total,
    FORMAT(SUM(underground),0) underground_total,
    FORMAT((SUM(bus) + SUM(tram) + SUM(underground)),0) total
FROM
    ridership
GROUP BY data_year
ORDER BY data_year;


-- Aggregate pkw_population to find total cars vs. total population each year
SELECT 
	data_year,
    district,
    SUM(passenger_cars) total_passenger_cars,
    SUM(population) total_population,
    ROUND(SUM(passenger_cars) / SUM(population) * 1000, 2) cars_per_1000_people
FROM
    pkw_population
GROUP BY data_year, district
ORDER BY data_year, cars_per_1000_people DESC;

-- Use Window Functions & CTEs
-- Year-over-Year Growth in ticket_count from annual_tickets
WITH previous_year_CTE AS
(
SELECT
	data_year,
    ticket_count,
    LAG(ticket_count) OVER(ORDER BY data_year) prev_ticket_count
FROM
	annual_tickets
GROUP BY data_year, ticket_count
)
SELECT
	data_year,
    FORMAT(ticket_count,0),
    CASE
		WHEN prev_ticket_count IS NULL OR prev_ticket_count = 0 THEN "No previous value" ELSE FORMAT(prev_ticket_count, 0)
	END previous_ticket_count,
    CASE
		WHEN prev_ticket_count IS NULL OR prev_ticket_count = 0 THEN "No previous value" 
        ELSE CONCAT(FORMAT((ticket_count - prev_ticket_count) * 100.0 / prev_ticket_count, 2), '%')
    END percentage_growth
FROM previous_year_CTE
ORDER BY data_year;
	


-- Ranking Districts by passenger_cars in pkw_population:
# Top 5 Districts per Year
WITH car_CTE AS
(
SELECT
    data_year,
    DENSE_RANK() OVER(PARTITION BY data_year ORDER BY data_year, (passenger_cars / population) * 100 DESC) ranking,
    district,
    passenger_cars,
    population,
    CONCAT((passenger_cars / population) * 100, "%") car_percentage
FROM
    pkw_population
GROUP BY data_year , district , passenger_cars , population
)
SELECT
	*
FROM car_CTE
WHERE ranking <= 5;

#Bonus task from me: Grouped by year, in order to find the district leaders in car ownership over the years.
SELECT 
    data_year,
    DENSE_RANK() OVER(PARTITION BY data_year ORDER BY (passenger_cars / population) * 100 DESC) ranking,
    district,
    passenger_cars,
    population,
    CONCAT((passenger_cars / population) * 100, "%") car_ownership_in_district
FROM
    pkw_population
GROUP BY data_year , district , passenger_cars , population
ORDER BY ranking;


-- Investigate Mode Share Shifts
-- Check average mode share across all data_year
SELECT
    CONCAT(ROUND(AVG(bicycle), 2), "%") avg_bicycle,
    CONCAT(ROUND(AVG(bikesharing), 2), "%") avg_bikesharing,
    CONCAT(ROUND(AVG(by_foot), 2), "%") avg_by_foot,
    CONCAT(ROUND(AVG(car), 2), "%") avg_car,
    CONCAT(ROUND(AVG(carsharing), 2), "%") avg_carsharing,
    CONCAT(ROUND(AVG(motorbike), 2), "%") avg_motorbike,
    CONCAT(ROUND(AVG(public_transport), 2), "%") avg_public_transport
FROM
    mode_share;

-- Find highest usage in a single mode each year
SELECT 
	data_year,
    CASE
		WHEN bicycle >= car AND bicycle >= public_transport AND bicycle >= by_foot THEN 'bicycle'
        WHEN car >= bicycle AND car >= public_transport AND car >= by_foot THEN 'car'
        WHEN public_transport >= bicycle AND public_transport >= car AND public_transport >= by_foot THEN 'public_transport'
        ELSE "by_foot"
    END top_mode
FROM mode_share
ORDER BY data_year;












