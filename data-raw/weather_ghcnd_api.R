# weather_ghcnd_api.R
# Collects weather data using direct NOAA CDO API calls (replaces rnoaa which stopped working)
# Run this after rnoaa data ends (~2022) to continue the time series

library(tidyverse)
library(httr)
library(jsonlite)

# =============================================================================
# Configuration
# =============================================================================

# Get NOAA token from environment variable
# Request a token at: https://www.ncdc.noaa.gov/cdo-web/token
NOAA_TOKEN <- Sys.getenv("NOAA_TOKEN")
if (NOAA_TOKEN == "") {

  stop("NOAA_TOKEN environment variable not set. Get a token at https://www.ncdc.noaa.gov/cdo-web/token")
}

# Years to collect (update as needed)
START_YEAR <- 2023
END_YEAR <- 2025

# API settings
API_BASE <- "https://www.ncei.noaa.gov/cdo-web/api/v2"
REQUEST_DELAY <- 0.5  # seconds between requests to avoid rate limiting

# =============================================================================
# Helper Functions
# =============================================================================

#' Fetch data from NOAA CDO API
#' @param endpoint API endpoint (e.g., "data", "stations")
#' @param params List of query parameters
#' @return Parsed JSON response or NULL on error
fetch_noaa <- function(endpoint, params = list()) {
  url <- paste0(API_BASE, "/", endpoint)

  response <- tryCatch({
    GET(
      url,
      add_headers(token = NOAA_TOKEN),
      query = params,
      timeout(60)
    )
  }, error = function(e) {
    message("Request error: ", e$message)
    return(NULL)
  })

  if (is.null(response)) return(NULL)

  if (status_code(response) == 429) {
    message("Rate limited, waiting 5 seconds...")
    Sys.sleep(5)
    return(fetch_noaa(endpoint, params))
  }

  if (status_code(response) != 200) {
    message("API error: ", status_code(response))
    return(NULL)
  }

  content(response, as = "parsed", type = "application/json")
}

#' Get TMAX data for a station and date range
#' @param station_id GHCND station ID
#' @param start_date Start date (YYYY-MM-DD)
#' @param end_date End date (YYYY-MM-DD)
#' @return Data frame with date and tmax columns
get_station_tmax <- function(station_id, start_date, end_date) {
  result <- fetch_noaa("data", list(
    datasetid = "GHCND",
    stationid = station_id,
    startdate = start_date,
    enddate = end_date,
    datatypeid = "TMAX",
    limit = 1000
  ))

  Sys.sleep(REQUEST_DELAY)

  if (is.null(result) || is.null(result$results)) {
    return(NULL)
  }

  data.frame(
    station_id = station_id,
    date = as.Date(sapply(result$results, function(x) substr(x$date, 1, 10))),
    tmax = sapply(result$results, function(x) x$value) / 10  # Convert to Celsius
  )
}

# =============================================================================
# Main Data Collection
# =============================================================================

message("Loading existing weather station data...")
load("../data/weather_stations_ghcnd.rda")

# Get the 10 closest stations per city (same as original approach)
closest_n <- 10
stations_to_query <- weather_stations_ghcnd %>%
  arrange(prognosticator_city, distance) %>%
  group_by(prognosticator_city) %>%
  slice_min(distance, n = closest_n) %>%
  ungroup()

message(sprintf("Will query %d stations across %d cities",
                nrow(stations_to_query),
                length(unique(stations_to_query$prognosticator_city))))

# Collect data for each year
all_tmax_data <- NULL

for (year in START_YEAR:END_YEAR) {
  message(sprintf("\n=== Collecting %d data ===", year))

  # February and March only (for classification)
  date_ranges <- list(
    list(start = sprintf("%d-02-01", year), end = sprintf("%d-02-28", year)),
    list(start = sprintf("%d-03-01", year), end = sprintf("%d-03-31", year))
  )

  cities <- unique(stations_to_query$prognosticator_city)

  for (i in seq_along(cities)) {
    city <- cities[i]
    message(sprintf("[%d/%d] %s", i, length(cities), city))

    city_stations <- stations_to_query %>%
      filter(prognosticator_city == city)

    for (j in seq_len(nrow(city_stations))) {
      station <- city_stations[j, ]

      for (range in date_ranges) {
        tmax_data <- get_station_tmax(station$id, range$start, range$end)

        if (!is.null(tmax_data) && nrow(tmax_data) > 0) {
          tmax_data$prognosticator_city <- city
          all_tmax_data <- bind_rows(all_tmax_data, tmax_data)
        }
      }
    }
  }

  # Save progress after each year
  saveRDS(all_tmax_data, sprintf("tmax_raw_%d_%d_progress.rds", START_YEAR, year))
  message(sprintf("Progress saved: %d total records", nrow(all_tmax_data)))
}

message("\n=== Processing collected data ===")

# Convert to Fahrenheit and calculate daily means across stations
ghcnd_tmax_new <- all_tmax_data %>%
  mutate(tmax_f = tmax * 1.8 + 32) %>%
  group_by(prognosticator_city, date) %>%
  summarize(tmax_daily_mean_f = mean(tmax_f, na.rm = TRUE), .groups = "drop")

# Calculate monthly means
ghcnd_tmax_monthly_new <- ghcnd_tmax_new %>%
  mutate(
    year = lubridate::year(date),
    month = lubridate::month(date)
  ) %>%
  filter(month %in% c(2, 3)) %>%
  group_by(prognosticator_city, year, month) %>%
  summarize(tmax_monthly_mean_f = mean(tmax_daily_mean_f, na.rm = TRUE), .groups = "drop") %>%
  mutate(yearmo = paste(year, str_pad(month, 2, pad = "0"), sep = "-"))

# =============================================================================
# Merge with Historical Data and Recalculate Classifications
# =============================================================================

message("Loading historical data...")
load("../data/class_def1_data.rda")

# Keep only the columns we need from historical data
historical_data <- class_def1_data %>%
  select(prognosticator_city, year, yearmo, month, tmax_monthly_mean_f)

# Combine historical and new data
combined_data <- bind_rows(
  historical_data,
  ghcnd_tmax_monthly_new %>%
    select(prognosticator_city, year, yearmo, month, tmax_monthly_mean_f)
) %>%
  distinct(prognosticator_city, year, month, .keep_all = TRUE) %>%
  arrange(prognosticator_city, year, month)

# Recalculate 15-year rolling averages
calc_rolling_avg <- function(data, mon) {
  data %>%
    filter(month == mon) %>%
    arrange(prognosticator_city, year) %>%
    group_by(prognosticator_city) %>%
    mutate(tmax_monthly_mean_f_15y = zoo::rollmean(
      tmax_monthly_mean_f,
      k = 15, fill = NA, align = "right"
    )) %>%
    ungroup()
}

feb_data <- calc_rolling_avg(combined_data, 2)
mar_data <- calc_rolling_avg(combined_data, 3)

# Combine and classify
class_def1_data_updated <- bind_rows(feb_data, mar_data) %>%
  arrange(prognosticator_city, year, month) %>%
  group_by(prognosticator_city, year) %>%
  mutate(class = case_when(
    any(tmax_monthly_mean_f > tmax_monthly_mean_f_15y, na.rm = TRUE) ~ "Early Spring",
    any(is.na(tmax_monthly_mean_f)) ~ NA_character_,
    any(is.na(tmax_monthly_mean_f_15y)) ~ NA_character_,
    TRUE ~ "Long Winter"
  )) %>%
  ungroup()

# =============================================================================
# Save Updated Data
# =============================================================================

message("\n=== Saving updated data ===")

# Backup original
file.copy("../data/class_def1_data.rda",
          sprintf("../data/class_def1_data_backup_%s.rda", Sys.Date()))

# Save new data
class_def1_data <- class_def1_data_updated
usethis::use_data(class_def1_data, overwrite = TRUE)

# Also save the detailed data
class_def1_data_detailed <- class_def1_data_updated
usethis::use_data(class_def1_data_detailed, overwrite = TRUE)

# Summary
message("\n=== Summary ===")
message(sprintf("Years covered: %d to %d",
                min(class_def1_data$year),
                max(class_def1_data$year)))
message(sprintf("Total records: %d", nrow(class_def1_data)))
message(sprintf("Cities: %d", length(unique(class_def1_data$prognosticator_city))))

# Show recent classifications
message("\nRecent classifications sample:")
class_def1_data %>%
  filter(year >= END_YEAR - 1) %>%
  distinct(prognosticator_city, year, class) %>%
  group_by(year, class) %>%
  count() %>%
  print()

message("\nDone! Run usethis::use_data() if needed.")
