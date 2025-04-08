# Vienna Mobility Project

This project analyzes Vienna’s mobility data—annual public transport tickets, ridership, car ownership, and mode shares. The goal is to demonstrate data cleaning, transformation, and advanced SQL querying for real-world insights into urban mobility.

---

## Data Files & Column Details

The original datasets came from multiple yearly CSV files on [data.gv.at](https://www.data.gv.at/). After merging each dataset by year, we ended up with **five** consolidated files representing:

1. **Jahreskarten der Wiener Linien Wien**  
   - **Original Columns**  
     - `NUTS1` (AT1 für Ostösterreich)  
     - `NUTS2` (AT13 für Bundesland Wien)  
     - `NUTS3` (AT130 für Stadt Wien)  
     - `DISTRICT_CODE` (90001 für Wien)  
     - `SUB_DISTRICT_CODE` (0 da nicht verwendet)  
     - `YEAR` (Jahr, für das die Werte gelten)  
     - `REF_YEAR` (Datenjahr)  
     - `ANNUAL_TICKETS` (Anzahl von Jahreskarten)  
   - **Included in Final Table**  
     - `YEAR` was renamed or stored as `data_year`  
     - `ANNUAL_TICKETS` was renamed to `ticket_count`  
   - **Dropped / Not Imported**  
     - `NUTS1`, `NUTS2`, `NUTS3`, `DISTRICT_CODE`, `SUB_DISTRICT_CODE` were excluded when using the Table Data Import Wizard (redundant for our analysis).  
     - `REF_YEAR` was later removed to keep only one year column.

2. **Fahrgastzahlen der Wiener Linien Wien**  
   - **Original Columns**  
     - `NUTS1` (AT1 für Ostösterreich)  
     - `NUTS2` (AT13 für Bundesland Wien)  
     - `NUTS3` (AT130 für Stadt Wien)  
     - `DISTRICT_CODE` (90001 für Wien)  
     - `SUB_DISTRICT_CODE` (0 da nicht verwendet)  
     - `YEAR` (Jahr)  
     - `REF_YEAR` (Datenjahr)  
     - `BUS` (Autobus)  
     - `TRAM` (Straßenbahn)  
     - `UNDERGROUND` (U-Bahn)  
   - **Included in Final Table**  
     - `YEAR` → stored as `data_year`  
     - `BUS`, `TRAM`, `UNDERGROUND` columns kept  
   - **Dropped / Not Imported**  
     - `NUTS1`, `NUTS2`, `NUTS3`, `DISTRICT_CODE`, `SUB_DISTRICT_CODE` removed  
     - `REF_YEAR` removed in a later step

3. **Jahreskarten und PKW seit 2002 – Wien**  
   - **Original Columns**  
     - `NUTS` | NUTS2-Region  
     - `DISTRICT_CODE` (Gemeindebezirkskennzahl)  
     - `SUB_DISTRICT_CODE` (Zählbezirkskennzahl)  
     - `REF_YEAR`  
     - `REF_DATE`  
     - `TIC_VALUE` (Ausgestellte Wiener Linien Jahreskarten)  
     - `PKW_VALUE` (Zugelassene PKW)  
     - `TIC_DENSITY` (Ausgestellte Wiener Linien Jahreskarten pro 1.000 EinwohnerInnen)  
     - `PKW_DENSITY` (Zugelassene PKW pro 1.000 EinwohnerInnen)  
   - **Included in Final Table** (renamed `annual_tickets_cars`)  
     - `REF_YEAR` → became `data_year`  
     - `TIC_VALUE` 
     - Other columns (`PKW_VALUE`, densities) were partially excluded or not used for final tasks. (We only needed `data_year`, `tic_value`. We did not rely on PKW columns in this script’s final queries, though they remained in the table.)
   - **Dropped / Not Imported**  
     - `NUTS`, `DISTRICT_CODE`, `SUB_DISTRICT_CODE`, `REF_DATE` not used in final analysis  
     - Some rows not imported at first due to data mismatch—subsequently corrected by manually editing the file in Excel (removing commas/periods) and running CREATE/INSERT commands.

4. **PKW-Bestand und EinwohnerInnen Wien**  
   - **Original Columns**  
     - `NUTS1` (AT1 für Ostösterreich)  
     - `NUTS2` (AT13 für Bundesland Wien)  
     - `NUTS3` (AT130 für Stadt Wien)  
     - `DISTRICT_CODE` (90001 für Wien)  
     - `SUB_DISTRICT_CODE` (0 da nicht verwendet)  
     - `YEAR` (Jahr)  
     - `REF_YEAR` (Datenjahr)  
     - `DISTRICT` (Name des Bezirks)  
     - `PASSENGER_CARS` (Anzahl der PKW)  
     - `POPULATION` (Bevölkerungszahl)  
   - **Included in Final Table** (`pkw_population`)  
     - `YEAR` → `data_year`  
     - `DISTRICT`  
     - `PASSENGER_CARS`  
     - `POPULATION`  
   - **Dropped / Not Imported**  
     - `NUTS1`, `NUTS2`, `NUTS3`, `DISTRICT_CODE`, `SUB_DISTRICT_CODE` removed  
     - `REF_YEAR` removed later

5. **Verkehrsmittelwahl Wien**  
   - **Original Columns**  
     - `NUTS1` (AT1 für Ostösterreich)  
     - `NUTS2` (AT13 für Bundesland Wien)  
     - `NUTS3` (AT130 für Stadt Wien)  
     - `DISTRICT_CODE` (9 für Wien)  
     - `SUB_DISTRICT_CODE` (0 da nicht verwendet)  
     - `YEAR` (Jahr)  
     - `BICYCLE` (Anteil Fahrräder)  
     - `BY_FOOT` (Anteil zu Fuß)  
     - `CAR` (Anteil PKW)  
     - `MOTORCYCLE` (Anteil Motorräder)  
     - `PUBLIC_TRANSPORT` (Anteil öffentlicher Verkehr)  
   - **Included in Final Table** (renamed `mode_share`)  
     - `YEAR` → `data_year`  
     - `bicycle`, `by_foot`, `car`, `motorbike`(or `motorcycle`), `public_transport`  
   - **Dropped / Not Imported**  
     - `NUTS1`, `NUTS2`, `NUTS3`, `DISTRICT_CODE`, `SUB_DISTRICT_CODE` removed  
     - Extra columns like `bikesharing` or `carsharing` might be partially used or dropped, depending on final merges.  
     - Some rows not imported (only partial data used).

---

## Course of Events

1. **Data Acquisition & Merging**  
   - Found necessary yearly CSV files on [data.gv.at](https://www.data.gv.at/).  
   - Merged each dataset’s CSVs (2015–2021 or 2002–2021) into a single file with a file merging service, resulting in five combined CSVs (one for each of the data types above).

2. **Initial Database & Table Creation**  
   - Opened **MySQL Workbench**, created the `vienna_mobility` database:
     ```sql
     CREATE DATABASE IF NOT EXISTS vienna_mobility;
     USE vienna_mobility;
     ```
   - Used **Table Data Import Wizard** for four of these CSVs, **selecting only** the columns/rows needed. (Not all columns were imported; columns like `NUTSx`, `DISTRICT_CODE`, etc., were excluded.)

3. **Handling the Last File**  
   - The last CSV had 100+ rows, but only ~80 were added automatically.  
   - Instead, removed unneeded columns & rows in Excel, replaced commas/periods, then **converted** CSV to an `.sql` script (with `CREATE TABLE` and `INSERT` statements).  
   - Executed that script to finalize the last table with correct data.

4. **Schema Revisions & Data Cleaning**  
   - **Renamed** columns (e.g., `ref_year` → `data_year`) to unify naming.  
   - **Removed** any redundant primary keys and extra columns (`REF_YEAR`, `NUTS1`, `NUTS2`, etc.).  
   - **Cleaned duplicates** by creating temp tables and grouping/aggregating:
     - Example: 
       ```sql
       CREATE TABLE annual_tickets_clean AS
       SELECT data_year, MAX(ticket_count) ticket_count
       FROM annual_tickets
       GROUP BY data_year;
       DROP TABLE annual_tickets;
       RENAME TABLE annual_tickets_clean TO annual_tickets;
       ```
   - After these steps, the final tables were consistent and free of duplicates.

5. **Advanced Queries & Final Tasks**  
   - Wrote joins to compare annual tickets vs. ridership (`rides per ticket`).  
   - Calculated **year-over-year** growth for both tickets and ridership.  
   - Summarized passenger car usage (`cars_per_1000_people` by district).  
   - Analyzed mode share (bicycle, car, public transport, etc.) and identified each year’s **top mode**.

With all duplicates removed and columns streamlined, I performed the final queries without issues.

---

## How to Use This Project

1. **Clone or Download** this repository (`My_Portfolio_Projects`), then open `Vienna_mobility_project`.

2. **Check `cleaned_data/`**  
   - It contains the five merged, cleaned CSVs obtained originally from data.gv.at.(Check original data for original uncleaned, unmerged data)

3. **Run `create_clean_tables.sql`**  
   - This script sets up the final schema, cleans duplicates, and renames columns.

4. **Run `analysis_queries.sql`**  
   - Produces the advanced queries comparing ticket counts, ridership, car ownership, and mode shares.

5. **Review Output**  
   - Observe the results in MySQL Workbench (e.g. “rides_per_ticket” column or “top 5 districts by car ownership”).

By following these steps, you can replicate the entire process, from partial CSVs to final analysis. This demonstrates my experience in data wrangling, SQL transformations, and generating meaningful insights from real-world mobility data for Vienna.
