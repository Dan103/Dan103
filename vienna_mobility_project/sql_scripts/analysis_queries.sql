-- analysis_queries.sql

-- These queries demonstrate:
--  1) Basic comparison of annual tickets vs. ridership (rides per ticket).
--  2) Multi-column YOY growth for tickets & ridership.
--  3) Discrepancies between 'ticket_count' and 'tic_value' in annual_tickets_cars.
--  4) Aggregated ridership by year.
--  5) Car ownership by district (cars per 1,000 inhabitants).
--  6) YOY growth for 'ticket_count' alone (using a CTE).
--  7) Ranking top 5 districts by car ownership each year.
--  8) Bonus rank approach for district leaders by year.
--  9) Mode share averages city-wide.
-- 10) Highest usage mode each year.

USE vienna_mobility;

--------------------------------------------------------------------------------
-- 1) COMPARE ANNUAL TICKETS VS. RIDERSHIP (BASIC RATIO)
--------------------------------------------------------------------------------
SELECT
    ant.data_year,
    FORMAT(ant.ticket_count, 0) AS annual_passes,
    FORMAT((r.bus + r.tram + r.underground), 0) AS total_rides,
    FORMAT((r.bus + r.tram + r.underground) / ant.ticket_count, 2) AS rides_per_ticket
FROM annual_tickets AS ant
JOIN ridership AS r
  ON ant.data_year = r.data_year
ORDER BY ant.data_year;


--------------------------------------------------------------------------------
-- 2) COMPARE ANNUAL TICKETS VS. RIDERSHIP WITH YOY GROWTH (ADVANCED)
--------------------------------------------------------------------------------
SELECT
    ant.data_year,

    FORMAT(ant.ticket_count, 0) AS annual_passes,
    CASE
        WHEN LAG(ant.ticket_count) OVER (ORDER BY ant.data_year) IS NULL
             OR LAG(ant.ticket_count) OVER (ORDER BY ant.data_year) = 0
        THEN 'No previous value'
        ELSE CONCAT(
            FORMAT(
              (ant.ticket_count - LAG(ant.ticket_count) OVER (ORDER BY ant.data_year))
              * 100.0 / LAG(ant.ticket_count) OVER (ORDER BY ant.data_year),
            2), '%'
        )
    END AS annual_passes_growth,

    FORMAT((r.bus + r.tram + r.underground), 0) AS total_rides,
    CASE
        WHEN LAG((r.bus + r.tram + r.underground)) OVER (ORDER BY ant.data_year) IS NULL
             OR LAG((r.bus + r.tram + r.underground)) OVER (ORDER BY ant.data_year) = 0
        THEN 'No previous value'
        ELSE CONCAT(
            FORMAT(
              ((r.bus + r.tram + r.underground)
               - LAG((r.bus + r.tram + r.underground)) OVER (ORDER BY ant.data_year))
              * 100.0
              / LAG((r.bus + r.tram + r.underground)) OVER (ORDER BY ant.data_year),
            2), '%'
        )
    END AS total_rides_growth,

    FORMAT((r.bus + r.tram + r.underground)/ant.ticket_count, 2) AS rides_per_ticket,
    CASE
        WHEN LAG((r.bus + r.tram + r.underground)/ant.ticket_count)
             OVER (ORDER BY ant.data_year) IS NULL
             OR LAG((r.bus + r.tram + r.underground)/ant.ticket_count)
             OVER (ORDER BY ant.data_year) = 0
        THEN 'No previous value'
        ELSE CONCAT(
            FORMAT(
              ((r.bus + r.tram + r.underground)/ant.ticket_count
               - LAG((r.bus + r.tram + r.underground)/ant.ticket_count)
                 OVER (ORDER BY ant.data_year))
              * 100.0
              / LAG((r.bus + r.tram + r.underground)/ant.ticket_count)
                 OVER (ORDER BY ant.data_year),
            2), '%'
        )
    END AS rides_per_ticket_growth

FROM annual_tickets AS ant
JOIN ridership AS r
  ON ant.data_year = r.data_year
ORDER BY ant.data_year;


--------------------------------------------------------------------------------
-- 3) COMPARE ANNUAL TICKETS WITH annual_tickets_cars (TICKET DISCREPANCIES)
--------------------------------------------------------------------------------
SELECT
    ant.data_year,
    ant.ticket_count,
    atc.tic_value,
    CASE
       WHEN (atc.tic_value - ant.ticket_count) = 0 THEN 'Same value'
       ELSE FORMAT((atc.tic_value - ant.ticket_count), 0)
    END AS diff_tickets,
    CASE
       WHEN (atc.tic_value - ant.ticket_count) = 0 THEN 'Same value'
       ELSE CONCAT(
         FORMAT(((atc.tic_value - ant.ticket_count)*100.0 / ant.ticket_count), 2),
         '%'
       )
    END AS pct_diff
FROM annual_tickets ant
JOIN annual_tickets_cars atc
  ON ant.data_year = atc.data_year;


--------------------------------------------------------------------------------
-- 4) AGGREGATED RIDERSHIP BY YEAR
--------------------------------------------------------------------------------
SELECT
    data_year,
    FORMAT(SUM(bus), 0) AS bus_total,
    FORMAT(SUM(tram), 0) AS tram_total,
    FORMAT(SUM(underground), 0) AS underground_total,
    FORMAT((SUM(bus) + SUM(tram) + SUM(underground)), 0) AS grand_total
FROM ridership
GROUP BY data_year
ORDER BY data_year;


--------------------------------------------------------------------------------
-- 5) CARS VS. POPULATION BY DISTRICT
--------------------------------------------------------------------------------
SELECT 
    data_year,
    district,
    FORMAT(SUM(passenger_cars), 0) AS total_passenger_cars,
    FORMAT(SUM(population), 0) AS total_population,
    ROUND(SUM(passenger_cars) / SUM(population) * 1000, 2) AS cars_per_1000_people
FROM pkw_population
GROUP BY data_year, district
ORDER BY data_year, cars_per_1000_people DESC;


--------------------------------------------------------------------------------
-- 6) YEAR-OVER-YEAR GROWTH IN ticket_count (CTE)
--------------------------------------------------------------------------------
WITH previous_year_CTE AS (
    SELECT
        data_year,
        ticket_count,
        LAG(ticket_count) OVER (ORDER BY data_year) AS prev_ticket_count
    FROM annual_tickets
)
SELECT
    data_year,
    FORMAT(ticket_count, 0) AS current_ticket_count,
    CASE
        WHEN prev_ticket_count IS NULL OR prev_ticket_count = 0
        THEN 'No previous value'
        ELSE FORMAT(prev_ticket_count, 0)
    END AS prev_ticket_count,
    CASE
        WHEN prev_ticket_count IS NULL OR prev_ticket_count = 0
        THEN 'No previous value'
        ELSE CONCAT(
          FORMAT((ticket_count - prev_ticket_count)*100.0 / prev_ticket_count, 2),
          '%'
        )
    END AS pct_growth
FROM previous_year_CTE
ORDER BY data_year;


--------------------------------------------------------------------------------
-- 7) IDENTIFY TOP 5 DISTRICTS BY CAR OWNERSHIP (WINDOW FUNCTION)
--------------------------------------------------------------------------------
WITH car_CTE AS (
  SELECT
      data_year,
      district,
      passenger_cars,
      population,
      DENSE_RANK() OVER (
        PARTITION BY data_year
        ORDER BY (passenger_cars / population) DESC
      ) AS ranking,
      CONCAT(
        ROUND((passenger_cars / population)*100, 2),
        '%'
      ) AS car_percentage
  FROM pkw_population
)
SELECT
  data_year,
  district,
  car_percentage,
  ranking
FROM car_CTE
WHERE ranking <= 5
ORDER BY data_year, ranking;


--------------------------------------------------------------------------------
-- 8) BONUS: DISTRICT LEADERS IN CAR OWNERSHIP (YEAR-BY-YEAR)
--------------------------------------------------------------------------------
SELECT 
    data_year,
    DENSE_RANK() OVER (
      PARTITION BY data_year
      ORDER BY (passenger_cars / population) DESC
    ) AS ranking,
    district,
    FORMAT(passenger_cars, 0) AS passenger_cars,
    FORMAT(population, 0) AS population,
    CONCAT(
      ROUND((passenger_cars / population)*100, 2),
      '%'
    ) AS car_percentage
FROM pkw_population
ORDER BY data_year, ranking;


--------------------------------------------------------------------------------
-- 9) INVESTIGATE MODE SHARE SHIFTS (AVERAGE VALUES)
--------------------------------------------------------------------------------
SELECT
    CONCAT(ROUND(AVG(bicycle), 2), '%') AS avg_bicycle,
    CONCAT(ROUND(AVG(bikesharing), 2), '%') AS avg_bikesharing,
    CONCAT(ROUND(AVG(by_foot), 2), '%') AS avg_by_foot,
    CONCAT(ROUND(AVG(car), 2), '%') AS avg_car,
    CONCAT(ROUND(AVG(carsharing), 2), '%') AS avg_carsharing,
    CONCAT(ROUND(AVG(motorbike), 2), '%') AS avg_motorbike,
    CONCAT(ROUND(AVG(public_transport), 2), '%') AS avg_public_transport
FROM mode_share;


--------------------------------------------------------------------------------
-- 10) HIGHEST USAGE MODE EACH YEAR
--------------------------------------------------------------------------------
SELECT 
    data_year,
    CASE
        WHEN bicycle >= car
          AND bicycle >= public_transport
          AND bicycle >= by_foot
        THEN 'bicycle'
        
        WHEN car >= bicycle
          AND car >= public_transport
          AND car >= by_foot
        THEN 'car'
        
        WHEN public_transport >= bicycle
          AND public_transport >= car
          AND public_transport >= by_foot
        THEN 'public_transport'
        
        ELSE 'by_foot'
    END AS top_mode
FROM mode_share
ORDER BY data_year;

--------------------------------------------------------------------------------
-- END OF analysis_queries.sql
--------------------------------------------------------------------------------
