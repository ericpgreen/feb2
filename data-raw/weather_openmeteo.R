# weather_openmeteo.R
# Collects weather data using Open-Meteo Historical API
# Replaces GHCND station-based approach with simpler coordinate-based queries
#
# Run after: prognosticators.R, predictions.R

library(tidyverse)
library(httr)
library(jsonlite)

# =============================================================================
# Configuration
# =============================================================================

START_YEAR <- 1940
END_YEAR <- 2025
REQUEST_DELAY <- 1.0  # seconds between requests (be nice to free API)
MAX_RETRIES <- 5      # max retries on rate limit

# =============================================================================
# Load Data
# =============================================================================

message("Loading prognosticators and predictions...")
load("../data/prognosticators.rda")
load("../data/predictions.rda")

# Join predictions with city coordinates
pred_with_city <- predictions %>%
  left_join(
    prognosticators %>% select(prognosticator_slug, prognosticator_city,
                                prognosticator_lat, prognosticator_long),
    by = "prognosticator_slug"
  ) %>%
  filter(!is.na(prognosticator_city))

# Get unique city coordinates
city_coords <- pred_with_city %>%
  distinct(prognosticator_city, prognosticator_lat, prognosticator_long)

# Exclude invalid/suspicious coordinates
excluded_cities <- c("Mira, NS", "MD", "IL")
city_coords <- city_coords %>%
  filter(!prognosticator_city %in% excluded_cities) %>%
  filter(!is.na(prognosticator_lat) & !is.na(prognosticator_long))

message(sprintf("Will collect data for %d cities", nrow(city_coords)))

# =============================================================================
# Open-Meteo API Function
# =============================================================================

#' Fetch daily max temperature from Open-Meteo Historical API
#' @param lat Latitude
#' @param lon Longitude
#' @param start_date Start date (YYYY-MM-DD)
#' @param end_date End date (YYYY-MM-DD)
#' @param retry_count Current retry attempt
#' @return Data frame with date and tmax_f columns, or NULL on error
fetch_openmeteo <- function(lat, lon, start_date, end_date, retry_count = 0) {
  url <- sprintf(
    "https://archive-api.open-meteo.com/v1/archive?latitude=%f&longitude=%f&start_date=%s&end_date=%s&daily=temperature_2m_max&temperature_unit=fahrenheit&timezone=auto",
    lat, lon, start_date, end_date
  )

  response <- tryCatch({
    GET(url, timeout(120))
  }, error = function(e) {
    message("  Request error: ", e$message)
    return(NULL)
  })

  if (is.null(response)) return(NULL)

  # Handle rate limiting with exponential backoff
  if (status_code(response) == 429) {
    if (retry_count < MAX_RETRIES) {
      wait_time <- 2^retry_count * 5  # 5, 10, 20, 40, 80 seconds
      message(sprintf("  Rate limited, waiting %d seconds (retry %d/%d)...",
                      wait_time, retry_count + 1, MAX_RETRIES))
      Sys.sleep(wait_time)
      return(fetch_openmeteo(lat, lon, start_date, end_date, retry_count + 1))
    } else {
      message("  Max retries exceeded")
      return(NULL)
    }
  }

  if (status_code(response) != 200) {
    message("  API error: ", status_code(response))
    return(NULL)
  }

  data <- content(response, as = "parsed", type = "application/json")

  if (is.null(data$daily)) {
    message("  No daily data returned")
    return(NULL)
  }

  tibble(
    date = as.Date(unlist(data$daily$time)),
    tmax_f = unlist(data$daily$temperature_2m_max)
  )
}

# =============================================================================
# Collect Data for All Cities
# =============================================================================

message("\n=== Starting data collection ===\n")

# Resume from progress file if it exists
if (file.exists("openmeteo_progress.rds")) {
  message("Resuming from previous progress...")
  all_data <- readRDS("openmeteo_progress.rds")
  completed_cities <- unique(all_data$prognosticator_city)
  message(sprintf("Already have data for %d cities", length(completed_cities)))
} else {
  all_data <- NULL
  completed_cities <- character(0)
}

start_date <- sprintf("%d-01-01", START_YEAR)
end_date <- sprintf("%d-03-31", END_YEAR)

for (i in seq_len(nrow(city_coords))) {
  city <- city_coords[i, ]

  # Skip if already have data for this city
  if (city$prognosticator_city %in% completed_cities) {
    message(sprintf("[%d/%d] %s - SKIPPED (already have data)",
                    i, nrow(city_coords), city$prognosticator_city))
    next
  }

  message(sprintf("[%d/%d] %s (%.4f, %.4f)",
                  i, nrow(city_coords),
                  city$prognosticator_city,
                  city$prognosticator_lat,
                  city$prognosticator_long))

  daily_data <- fetch_openmeteo(
    city$prognosticator_lat,
    city$prognosticator_long,
    start_date,
    end_date
  )

  if (!is.null(daily_data) && nrow(daily_data) > 0) {
    daily_data$prognosticator_city <- city$prognosticator_city
    all_data <- bind_rows(all_data, daily_data)
    message(sprintf("  Got %d days", nrow(daily_data)))

    # Save progress after each successful city
    saveRDS(all_data, "openmeteo_progress.rds")
  } else {
    message("  FAILED - no data returned")
  }

  Sys.sleep(REQUEST_DELAY)
}

# Final save of raw data
saveRDS(all_data, "openmeteo_raw.rds")
message(sprintf("\nRaw data saved: %d total records", nrow(all_data)))

# =============================================================================
# Process Data: Filter to Feb-March, Calculate Classifications
# =============================================================================

message("\n=== Processing data ===\n")

# Filter to February and March only
feb_mar_data <- all_data %>%
  mutate(
    year = lubridate::year(date),
    month = lubridate::month(date)
  ) %>%
  filter(month %in% c(2, 3))

message(sprintf("Feb-March records: %d", nrow(feb_mar_data)))

# Calculate monthly means
monthly_means <- feb_mar_data %>%
  group_by(prognosticator_city, year, month) %>%
  summarize(
    tmax_monthly_mean_f = mean(tmax_f, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(yearmo = paste(year, str_pad(month, 2, pad = "0"), sep = "-"))

# Calculate 15-year rolling average by month
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

feb_rolling <- calc_rolling_avg(monthly_means, 2)
mar_rolling <- calc_rolling_avg(monthly_means, 3)

# Combine and classify
class_def1_openmeteo <- bind_rows(feb_rolling, mar_rolling) %>%
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
# Merge with GHCND for Pre-1940 Data
# =============================================================================

message("\n=== Merging with GHCND pre-1940 data ===\n")

load("../data/class_def1_data.rda")

# Keep GHCND data for pre-1940 (Punxsutawney and Quarryville)
ghcnd_pre1940 <- class_def1_data %>%
  filter(year < 1940) %>%
  filter(prognosticator_city %in% c("Punxsutawney, PA", "Quarryville, PA"))

message(sprintf("GHCND pre-1940 records: %d", nrow(ghcnd_pre1940)))

# Combine: GHCND pre-1940 + Open-Meteo 1940+
class_def1_data_new <- bind_rows(
  ghcnd_pre1940,
  class_def1_openmeteo
) %>%
  arrange(prognosticator_city, year, month)

# =============================================================================
# Save Updated Data
# =============================================================================

message("\n=== Saving data ===\n")

# Backup original
backup_file <- sprintf("../data/class_def1_data_backup_%s.rda", Sys.Date())
if (file.exists("../data/class_def1_data.rda")) {
  file.copy("../data/class_def1_data.rda", backup_file)
  message(sprintf("Backed up original to %s", backup_file))
}

# Save new data
class_def1_data <- class_def1_data_new
usethis::use_data(class_def1_data, overwrite = TRUE)

# Also create summary classification (one row per city-year)
class_def1 <- class_def1_data %>%
  distinct(prognosticator_city, year, class)

usethis::use_data(class_def1, overwrite = TRUE)

# =============================================================================
# Summary
# =============================================================================

message("\n=== SUMMARY ===\n")
message(sprintf("Total city-year-month records: %d", nrow(class_def1_data)))
message(sprintf("Unique cities: %d", length(unique(class_def1_data$prognosticator_city))))
message(sprintf("Year range: %d to %d", min(class_def1_data$year), max(class_def1_data$year)))

message("\nClassification counts:")
class_def1_data %>%
  filter(!is.na(class)) %>%
  distinct(prognosticator_city, year, class) %>%
  count(class) %>%
  print()

message("\nRecent years sample:")
class_def1_data %>%
  filter(year >= 2023) %>%
  distinct(prognosticator_city, year, class) %>%
  group_by(year, class) %>%
  count() %>%
  print()

message("\nDone!")
