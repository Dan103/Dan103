# Vienna Mobility Project

This project analyzes Vienna’s mobility data from multiple open-data files originally obtained from [data.gv.at](https://www.data.gv.at/). The source datasets included columns like `NUTS1`, `NUTS2`, `NUTS3`, `DISTRICT_CODE`, `SUB_DISTRICT_CODE`, `YEAR`, `REF_YEAR`, and specific measures such as passenger counts, vehicle counts, mode shares, or annual ticket numbers. Below are the **original fields** (in German and English) and which ones **remain** in our final tables.

---

## **Original Datasets & Columns**

### 1. Jahreskarten der Wiener Linien Wien
- **NUTS1**: AT1 for Ostösterreich  
- **NUTS2**: AT13 for Bundesland Wien  
- **NUTS3**: AT130 for Stadt Wien  
- **DISTRICT_CODE**: 90001 for Wien  
- **SUB_DISTRICT_CODE**: 0 (not used)  
- **YEAR**: The year for which the values apply  
- **REF_YEAR**: The data year  
- **ANNUAL_TICKETS** (Anzahl von Jahreskarten)

In the **final** table `annual_tickets`, I **removed** columns such as `NUTS1, NUTS2, NUTS3, DISTRICT_CODE, SUB_DISTRICT_CODE, REF_YEAR`. I **kept** `YEAR` (renamed to `data_year` in some steps) and `ANNUAL_TICKETS` (renamed to `ticket_count`).

### 2. Fahrgastzahlen der Wiener Linien Wien
- **NUTS1**: AT1 for Ostösterreich  
- **NUTS2**: AT13 for Bundesland Wien  
- **NUTS3**: AT130 for Stadt Wien  
- **DISTRICT_CODE**: 90001 for Wien  
- **SUB_DISTRICT_CODE**: 0 (not used)  
- **YEAR**: The year for which the values apply  
- **REF_YEAR**: The data year  
- **BUS** (Autobus)  
- **TRAM** (Straßenbahn)  
- **UNDERGROUND** (U-Bahn)

In the **final** table `ridership`, I **removed** `NUTS1, NUTS2, NUTS3, DISTRICT_CODE, SUB_DISTRICT_CODE, REF_YEAR` and **kept** `YEAR` (as `data_year`), plus `BUS`, `TRAM`, `UNDERGROUND`.

### 3. Jahreskarten und PKW seit 2002 – Wien
- **NUTS**: NUTS2-Region (Bundesland)  
- **DISTRICT_CODE**: Gemeindebezirkskennzahl (Schema: 9BBZZ, where BB=Bezirk, ZZ=00)  
- **SUB_DISTRICT_CODE**: Zählbezirkskennzahl gemäß Stadt Wien (9BBZZ, with 99 if unknown)  
- **REF_YEAR**: Reference year  
- **REF_DATE**: Reference date  
- **TIC_VALUE**: Ausgestellte Wiener Linien Jahreskarten  
- **PKW_VALUE**: Zugelassene Kraftfahrzeuge - Personenkraftwagen (inkl. Autotaxi)  
- **TIC_DENSITY**: Ausgestellte Wiener Linien Jahreskarten pro 1.000 EinwohnerInnen  
- **PKW_DENSITY**: PKW pro 1.000 EinwohnerInnen

In the **final** table `annual_tickets_cars`, I **renamed** `REF_YEAR` to `data_year`, dropped other unneeded columns, and kept `tic_value`. We did **not** retain PKW columns here in the final CSV; only `data_year` and `tic_value` remain (some rows might vary depending on your merges).

### 4. PKW-Bestand und EinwohnerInnen Wien
- **NUTS1**: AT1 for Ostösterreich  
- **NUTS2**: AT13 for Bundesland Wien  
- **NUTS3**: AT130 for Stadt Wien  
- **DISTRICT_CODE**: 90001 for Wien  
- **SUB_DISTRICT_CODE**: 0 (not used)  
- **YEAR**: The year for which the values apply  
- **REF_YEAR**: The data year  
- **DISTRICT**: Name des Bezirks  
- **PASSENGER_CARS**: Anzahl der PKW  
- **POPULATION**: Bevölkerungszahl

In the **final** table `pkw_population`, columns like `NUTS1`, `NUTS2`, `NUTS3`, `DISTRICT_CODE`, `SUB_DISTRICT_CODE`, and `REF_YEAR` were removed. We **kept** `YEAR` (called `data_year`), `DISTRICT`, `PASSENGER_CARS`, and `POPULATION`.

### 5. Verkehrsmittelwahl Wien
- **NUTS1**: AT1 for Ostösterreich  
- **NUTS2**: AT13 for Bundesland Wien  
- **NUTS3**: AT130 for Stadt Wien  
- **DISTRICT_CODE**: 9 for Wien  
- **SUB_DISTRICT_CODE**: 0 (not used)  
- **YEAR**: The year for which the share applies  
- **BICYCLE**: Anteil Fahrräder  
- **BY_FOOT**: Anteil zu Fuß  
- **CAR**: Anteil PKW  
- **MOTORCYCLE**: Anteil Motorräder  
- **PUBLIC_TRANSPORT**: Anteil öffentlicher Verkehr

In the **final** table `mode_share`, we removed `NUTS1, NUTS2, NUTS3, DISTRICT_CODE, SUB_DISTRICT_CODE`. We **kept** `YEAR` (renamed to `data_year`) and the percentage columns like `bicycle, by_foot, car, public_transport`, etc.

---

## **Project Steps**

1. **Data Merging**  
   I merged all yearly CSVs for each dataset using a file merging service and ended up with five consolidated CSVs. Then I selectively imported columns and rows into MySQL Workbench.

2. **Last File Conversion**  
   One dataset was converted from CSV to SQL manually, where I dropped unnecessary columns in Excel, then used `CREATE TABLE` and `INSERT` statements to finalize the import.

3. **Schema Adjustments**  
   - Renamed columns such as `ref_year` to `data_year` for consistency.  
   - Dropped extra columns like `NUTS1, NUTS2, DISTRICT_CODE` once I confirmed they were identical in all rows and unnecessary for the final queries.  
   - Removed primary keys where the data wasn’t actually unique on that column combination.  
   - Cleaned duplicates by creating “clean” tables using window functions or grouping, then replaced the originals.

4. **Analysis**  
   - I compared annual ticket counts with ridership totals to see if an increase in passes correlated with more usage.  
   - I computed year-over-year growth in passes, ridership, and rides-per-ticket.  
   - I ranked districts by the ratio of passenger cars to population.  
   - I analyzed average mode shares (bicycle, by foot, car, public transport) and identified the top usage mode each year.

## **Project Files**

- **data/**  
  Contains the merged CSVs for each dataset, reflecting the columns above. Some columns (like `NUTS1`, `DISTRICT_CODE`, `REF_YEAR`) were later dropped in MySQL.

- **sql_scripts/**  
  - **create_clean_tables.sql**  
    Contains all commands to create (or use) `vienna_mobility`, rename columns, remove unwanted fields, and remove duplicates.  
  - **analysis_queries.sql**  
    Contains final advanced SQL queries that perform joins, aggregations, window function calculations, and mode share analyses.

- **screenshots/** (Optional)  
  Could hold images of MySQL Workbench or sample outputs.

---

## **How to Run**

1. **Clone or Download** this repository.  
2. **Open MySQL Workbench** or another client, and connect to your MySQL server.  
3. **Run `create_clean_tables.sql`**:
   ```sql
   SOURCE /path/to/sql_scripts/create_clean_tables.sql;
