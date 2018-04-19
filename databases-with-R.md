introduction to databases (but with R)
================

background
----------

This document generally mirrors the SOS 598 RDM [introduction to databases](https://github.com/SOS598-RDM/rdm-databases) resource but adapts the workflow to R. Please see the aforementioned document for background and details.

load required libraries
-----------------------

``` r
library(dplyr)
library(dbplyr)
library(lubridate)
library(readr)
library(RSQLite)
```

create a database and connect to it
-----------------------------------

we can create a new database from within R:

``` r
src_sqlite("~/Desktop/stream-metabolism-R.sqlite",
           create = TRUE)
```

    ## src:  sqlite 3.22.0 [/home/srearl/Desktop/stream-metabolism-R.sqlite]
    ## tbls:

connect to our database:

``` r
con <- DBI::dbConnect(RSQLite::SQLite(),
                      "~/Desktop/stream-metabolism-R.sqlite")

# instruct our SQLite database to enforce foreign keys:
dbExecute(con, 'PRAGMA foreign_keys = ON;')
```

add database structure and data
-------------------------------

#### sonde events

With DB Browser, we were able to use an import wizard to create the *sonde\_events* table and import the data in a single action, with a subsequent step of adding the NOT NULL, PRIMARY KEY, and AUTOINCREMENT characteristics to the 'id' field of our table with DB Browser's modify table tool. However, functionality for modifying tables after they are created is limited with SQLite, particularly outside of a GUI environment like DB Browser. A better approach, and one that we need to use with R, is to set these features when the table is created. So, instead of a creating the table by importing them, we will pass an SQL statement to create the table with the appropriate characteristics, then insert the data with a separate SQL statement. We can use the dbWriteTable function to crudely but quickly load the sonde event data into a temporary table, then insert them from the temporary table to the *sonde\_events table* with the appropriate formatting and structure.

create our sonde events table

``` r
dbExecute(con,'
CREATE TABLE `sonde_events` (
    `id`    INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    `site_id`   TEXT,
    `date`  TEXT,
    `instrument_id` TEXT,
    `K2_20` REAL);')
```

add sonde events data

``` r
# load data; SQLite does not have a type DATE so convert to character
sondeEvents <- read_csv('~/localRepos/databases/data/sonde_events.csv') %>% 
  mutate(date = as.character(date))
```

    ## Parsed with column specification:
    ## cols(
    ##   id = col_integer(),
    ##   site_id = col_character(),
    ##   date = col_date(format = ""),
    ##   instrument_id = col_character(),
    ##   K2_20 = col_double()
    ## )

``` r
# write the events to a temporary table
DBI::dbWriteTable(conn = con, 
                  name = "tempTable",
                  value = sondeEvents,
                  row.names = FALSE,
                  temporary = FALSE,
                  overwrite = TRUE,
                  append = FALSE) 


# insert data from the temporary table to sonde_events
dbExecute(con, '
INSERT INTO sonde_events(
  site_id,
  date,
  instrument_id,
  K2_20)
SELECT
  site_id,
  date,
  instrument_id,
  K2_20
FROM tempTable;')

# delete the temporary table
dbExecute(con, '
DROP TABLE tempTable;')
```

#### sonde data

create our sonde data table:

``` r
dbExecute(con,'
CREATE TABLE "sonde_data" (
  "id" INTEGER PRIMARY KEY  AUTOINCREMENT NOT NULL,
  "sonde_event_id" INTEGER NOT NULL,
  "Date" TEXT,
  "Time" TEXT,
  "Temp" DOUBLE,
  "SpCond" DOUBLE,
  "DO" DOUBLE,
FOREIGN KEY ("sonde_event_id") REFERENCES sonde_events("id"));')
```

We need to add the sonde data to our database. However, because we are now in a scripting environment, we can develop tools and approaches to automate some of these processes. For example, we can start with a function that will add data to our sonde data table. This function adds data specifically to the *sonde\_data* table but we could add a parameter that would allow us to select any table.

``` r
tempTableData <- function(dataFile, overWrite) {
  
  # set append argument to dbWriteTable based on user input ~ overwrite
  if(overWrite == FALSE) { 
    setAppend = TRUE } else {
      setAppend = FALSE
    }
  
  # read that data file
  dataFile <- read_csv(dataFile) %>% 
    mutate(
      Date = as.character(Date),
      Time = as.character(Time)
    )
  
  # write specified data to tempTable
  DBI::dbWriteTable(conn = con, 
                    name = "tempTable",
                    value = dataFile,
                    row.names = FALSE,
                    temporary = FALSE,
                    overwrite = overWrite,
                    append = setAppend) 
}
```

use the script to load sonde event data 1 through 4:

``` r
# list data resources to load
dataFiles <- list('~/localRepos/databases/data/sonde_data_1_3.csv',
                  '~/localRepos/databases/data/sonde_data_4.csv')

# use the tempTableData function to load the data
lapply(dataFiles, tempTableData, overWrite = FALSE)
```

    ## Parsed with column specification:
    ## cols(
    ##   id = col_character(),
    ##   sonde_event_id = col_integer(),
    ##   Date = col_date(format = ""),
    ##   Time = col_time(format = ""),
    ##   Temp = col_double(),
    ##   SpCond = col_double(),
    ##   DO = col_double()
    ## )

    ## Parsed with column specification:
    ## cols(
    ##   id = col_character(),
    ##   sonde_event_id = col_integer(),
    ##   Date = col_date(format = ""),
    ##   Time = col_time(format = ""),
    ##   Temp = col_double(),
    ##   SpCond = col_integer(),
    ##   DO = col_double()
    ## )

    ## [[1]]
    ## [1] TRUE
    ## 
    ## [[2]]
    ## [1] TRUE

insert the data into the sonde\_data table by selecting the data inserted into the temporary table:

``` r
dbExecute(con, '
          INSERT INTO sonde_data(
            sonde_event_id,
            Date,
            Time,
            Temp,
            SpCond,
            DO) 
          SELECT
            sonde_event_id, 
            Date, 
            Time, 
            Temp, 
            SpCond,
            DO 
          FROM tempTable;')
```

    ## [1] 6151

Since there is not a sonde event 5 in our *sonde\_events* table, we need to add it before we can load event 5 data into the sonde\_data table.

``` r
dbExecute(con,'
INSERT INTO sonde_events(
  site_id,  
  date,
  instrument_id,
  K2_20)
VALUES(
  "HN",
  "2013-08-13",
  "yellow",
  55.42
);')
```

    ## [1] 1

Now that there is an event 5 in our *sonde\_events* table, we can add data from sonde event 5 to our *sonde\_data* table. This chunk will load the event 5 sonde data into our temporary table.

``` r
dataFiles <- list('~/localRepos/databases/data/sonde_data_5.csv')

lapply(dataFiles, tempTableData, overWrite = TRUE)
```

    ## Parsed with column specification:
    ## cols(
    ##   id = col_character(),
    ##   sonde_event_id = col_integer(),
    ##   Date = col_date(format = ""),
    ##   Time = col_time(format = ""),
    ##   Temp = col_double(),
    ##   SpCond = col_integer(),
    ##   DO = col_double()
    ## )

    ## [[1]]
    ## [1] TRUE

I can then insert the data into the sonde\_data table from the temporary table simply by referencing the chunk that we employed earlier for this purpose.

> {r dbi::insert\_sonde\_data\_5, ref.label='dbi::insert\_sonde\_data'}

``` r
dbExecute(con, '
          INSERT INTO sonde_data(
            sonde_event_id,
            Date,
            Time,
            Temp,
            SpCond,
            DO) 
          SELECT
            sonde_event_id, 
            Date, 
            Time, 
            Temp, 
            SpCond,
            DO 
          FROM tempTable;')
```

    ## [1] 1463

extract data from the database
------------------------------

There are several approaches that we can employ to access data in our database. One is to use SQL statements as we have done to create and populate our database. Another is to use dplyr/dbplyr functionality so that we can access the data using dplyr syntax, which it will convert to SQL for us.

get the first ten rows from the *sonde\_data* table with SQL:

``` r
dbGetQuery(con, '
SELECT *
FROM sonde_data
LIMIT 10;')
```

    ##    id sonde_event_id       Date     Time  Temp SpCond   DO
    ## 1   1              1 2003-08-13 11:15:00 18.42  139.3 9.06
    ## 2   2              1 2003-08-13 11:20:00 18.41  139.3 9.01
    ## 3   3              1 2003-08-13 11:25:00 18.43  139.4 8.98
    ## 4   4              1 2003-08-13 11:30:00 18.49  139.4 9.02
    ## 5   5              1 2003-08-13 11:35:00 18.55  139.5 8.91
    ## 6   6              1 2003-08-13 11:40:00 18.57  139.5 8.82
    ## 7   7              1 2003-08-13 11:45:00 18.56  139.4 8.83
    ## 8   8              1 2003-08-13 11:50:00 18.58  139.4 8.82
    ## 9   9              1 2003-08-13 11:55:00 18.60  139.3 8.89
    ## 10 10              1 2003-08-13 12:00:00 18.61  139.3 8.87

We can assign the results of that query as an object in our R environment.

``` r
sonde_data_top <- dbGetQuery(con, '
SELECT *
FROM sonde_data
LIMIT 10;')
```

with dplyr:

create a pointer to the *sonde\_events* table in our database

``` r
event_db <- tbl(con, "sonde_events")
```

we can then access the information in the *sonde\_events* table by referencing the pointer

use the show\_query() function to transate the dplyr statement to SQL

``` r
event_db %>% 
  select(everything()) %>% 
  show_query()
```

    ## <SQL>
    ## SELECT `id`, `site_id`, `date`, `instrument_id`, `K2_20`
    ## FROM `sonde_events`

example: select all data from the *sonde\_events* table

``` r
event_db %>%
  select(everything())
```

    ## # Source:   lazy query [?? x 5]
    ## # Database: sqlite 3.22.0
    ## #   [/home/srearl/Desktop/stream-metabolism-R.sqlite]
    ##      id site_id date       instrument_id K2_20
    ##   <int> <chr>   <chr>      <chr>         <dbl>
    ## 1     1 GB      2013-08-13 black          57.4
    ## 2     2 GB      2013-08-13 red            57.4
    ## 3     3 SC      2013-09-03 green          63.3
    ## 4     4 SC      2013-09-10 black          59.1
    ## 5     5 HN      2013-08-13 yellow         55.4

example: assign results of select all data from the *sonde\_events* table to an object in our R environment

``` r
sondeevent <- event_db %>%
  select(everything()) %>%
  collect()
```

Usually we want to use certain search criteria. Note the difference between the SQL and dplyr syntax to harvest the Date and DO fields from the *sonde\_data* table that were collected on the 15th of August.

*SQL*

``` r
dbGetQuery(con,"
SELECT
  Date,
  DO
FROM sonde_data 
WHERE strftime('%m', Date) = '08' AND strftime('%d', Date) = '15'
LIMIT 10;")
```

    ##          Date   DO
    ## 1  2003-08-15 7.98
    ## 2  2003-08-15 7.95
    ## 3  2003-08-15 7.95
    ## 4  2003-08-15 7.91
    ## 5  2003-08-15 7.93
    ## 6  2003-08-15 7.99
    ## 7  2003-08-15 7.98
    ## 8  2003-08-15 7.93
    ## 9  2003-08-15 7.98
    ## 10 2003-08-15 8.06

*dplyr*

``` r
sondedata_db <- tbl(con, "sonde_data")
```

``` r
sondedata_db %>%
  select(Date, DO) %>%
  collect() %>%
  mutate(Date = as.Date(Date, format = "%Y-%m-%d")) %>% 
  filter(month(Date) == 8 & day(Date) == 15) %>% 
  head(n = 10)
```

    ## # A tibble: 10 x 2
    ##    Date          DO
    ##    <date>     <dbl>
    ##  1 2003-08-15  7.98
    ##  2 2003-08-15  7.95
    ##  3 2003-08-15  7.95
    ##  4 2003-08-15  7.91
    ##  5 2003-08-15  7.93
    ##  6 2003-08-15  7.99
    ##  7 2003-08-15  7.98
    ##  8 2003-08-15  7.93
    ##  9 2003-08-15  7.98
    ## 10 2003-08-15  8.06

We can group results based on data features that can be binned, this is particularly useful for aggregate functions. The query below extracts the minimum and maximum dissolved oxygen (DO) values for each sonde event.

``` r
sondedata_db %>%
  select(everything()) %>%
  group_by(sonde_event_id) %>% 
  summarise(
    min_DO = min(DO, na.rm = TRUE),
    max_DO = max(DO, na.rm = TRUE)
  ) 
```

    ## # Source:   lazy query [?? x 3]
    ## # Database: sqlite 3.22.0
    ## #   [/home/srearl/Desktop/stream-metabolism-R.sqlite]
    ##   sonde_event_id min_DO max_DO
    ##            <int>  <dbl>  <dbl>
    ## 1              1   7.12   9.06
    ## 2              2   6.32   9.02
    ## 3              3   6.65   8.29
    ## 4              4   8.14   9.52
    ## 5              5   8.14   9.52

The ability to link information in our tables is a core features of databases. We do this with **JOINs**.

For example, incorporate site\_id from the *sonde\_events* table into a query of temperature and dissolved oxygen from *sonde\_data*:

``` r
sondedata_db %>% 
  select(sonde_event_id, Temp, DO) %>% 
  inner_join(event_db %>% select(id, site_id), by = c("sonde_event_id" = "id")) %>% 
  select(site_id, Temp, DO) %>% 
  head(n = 10)
```

    ## # Source:   lazy query [?? x 3]
    ## # Database: sqlite 3.22.0
    ## #   [/home/srearl/Desktop/stream-metabolism-R.sqlite]
    ##    site_id  Temp    DO
    ##    <chr>   <dbl> <dbl>
    ##  1 GB       18.4  9.06
    ##  2 GB       18.4  9.01
    ##  3 GB       18.4  8.98
    ##  4 GB       18.5  9.02
    ##  5 GB       18.6  8.91
    ##  6 GB       18.6  8.82
    ##  7 GB       18.6  8.83
    ##  8 GB       18.6  8.82
    ##  9 GB       18.6  8.89
    ## 10 GB       18.6  8.87
    ## # ... with more rows

For example, find the minimum and maximum dissolved oxgyen values for each sonde\_event as per above but this time include the site and the K2\_20 from the sonde\_events table:

``` r
sondedata_db %>%
  select(everything()) %>%
  group_by(sonde_event_id) %>% 
  summarise(
    min_DO = min(DO, na.rm = TRUE),
    max_DO = max(DO, na.rm = TRUE)
  ) %>% 
  inner_join(event_db %>% select(id, site_id), by = c("sonde_event_id" = "id"))
```

    ## # Source:   lazy query [?? x 4]
    ## # Database: sqlite 3.22.0
    ## #   [/home/srearl/Desktop/stream-metabolism-R.sqlite]
    ##   sonde_event_id min_DO max_DO site_id
    ##            <int>  <dbl>  <dbl> <chr>  
    ## 1              1   7.12   9.06 GB     
    ## 2              2   6.32   9.02 GB     
    ## 3              3   6.65   8.29 SC     
    ## 4              4   8.14   9.52 SC     
    ## 5              5   8.14   9.52 HN

databases? eh, whatevs
----------------------

join the sonde data and sonde events data using the sonde\_event\_id:

``` r
read_csv('~/localRepos/databases/data/sonde_data_1_3.csv') %>% 
  select(-id) %>% 
  inner_join(read_csv('~/localRepos/databases/data/sonde_events.csv') %>% select(-date), by = c("sonde_event_id" = "id")) %>% 
  View("joinWithKey")
```

further, we do not really need a key, but we need to store more information in our tables without it:

``` r
read_csv('~/localRepos/databases/data/sonde_data_1_3.csv') %>% 
  mutate(
    site_id = case_when(sonde_event_id == 1 ~ 'GB',
                        sonde_event_id == 2 ~ 'GB',
                        sonde_event_id == 3 ~ 'SC'),
    instrument_id = case_when(sonde_event_id == 1 ~ 'black',
                              sonde_event_id == 2 ~ 'red',
                              sonde_event_id == 3 ~ 'green')
  ) %>% 
  select(-id) %>% 
  inner_join(read_csv('~/localRepos/databases/data/sonde_events.csv') %>% select(-date), by = c("site_id", "instrument_id")) %>% 
  View('joinSansKey')
```
