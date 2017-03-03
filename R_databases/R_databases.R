# library
library(DBI)

# set the database connection
streamChem <- dbConnect(RSQLite::SQLite(), "~/Desktop/stream_chemistry.sqlite")

# query data
dbGetQuery(streamChem, 'SELECT Date FROM sonde_data')

# another query
dbGetQuery(streamChem,
  'SELECT
    Date,
    DO
  FROM sonde_data 
  WHERE strftime("%m", Date) = "08" AND strftime("%d", Date) = "15";')

# query with aggregation
dbGetQuery(streamChem,
  'SELECT
    sonde_event_id,
    MIN(DO) AS min_DO,
    MAX(DO) AS max_DO
  FROM sonde_data 
  GROUP BY sonde_event_id;')

# assign results of query to R dataframe
min_max_DO <- dbGetQuery(streamChem,
  'SELECT
    sonde_event_id,
    MIN(DO) AS min_DO,
    MAX(DO) AS max_DO
  FROM sonde_data 
  GROUP BY sonde_event_id;')