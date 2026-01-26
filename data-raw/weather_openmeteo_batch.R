# weather_openmeteo_batch.R
# Collects weather data using Open-Meteo Historical API with batched coordinates
# Multiple cities per request to reduce total API calls

library(tidyverse)
library(httr)
library(jsonlite)

# =============================================================================
# Configuration
# =============================================================================

START_YEAR <- 1940
END_YEAR <- 2025
BATCH_SIZE <- 5  # cities per request
REQUEST_DELAY <- 5.0  # seconds between requests
MAX_RETRIES <- 5  # max retries per batch
RATE_LIMIT_WAIT <- 60  # seconds to wait when rate limited

# =============================================================================
# Load Data
# =============================================================================

message("Loading prognosticators and predictions...")
load("../data/prognosticators.rda")
load("../data/predictions.rda")

pred_with_city <- predictions %>%
  left_join(
    prognosticators %>% select(prognosticator_slug, prognosticator_city,
                                prognosticator_lat, prognosticator_long),
    by = "prognosticator_slug"
  ) %>%
  filter(!is.na(prognosticator_city))

city_coords <- pred_with_city %>%
  distinct(prognosticator_city, prognosticator_lat, prognosticator_long)

# Exclude invalid coordinates
excluded_cities <- c("Mira, NS", "MD", "IL")
city_coords <- city_coords %>%
  filter(!prognosticator_city %in% excluded_cities) %>%
  filter(!is.na(prognosticator_lat) & !is.na(prognosticator_long))

message(sprintf("Will collect data for %d cities", nrow(city_coords)))

# =============================================================================
# Resume from progress
# =============================================================================

if (file.exists("openmeteo_batch_progress.rds")) {
  message("Resuming from progress...")
  all_data <- readRDS("openmeteo_batch_progress.rds")
  completed_cities <- unique(all_data$prognosticator_city)
  message(sprintf("Already have data for %d cities", length(completed_cities)))

  # Filter to remaining cities
  city_coords <- city_coords %>%
    filter(!prognosticator_city %in% completed_cities)
  message(sprintf("Remaining cities to collect: %d", nrow(city_coords)))
} else {
  all_data <- NULL
  completed_cities <- character(0)
}

if (nrow(city_coords) == 0) {
  message("All cities already collected!")
  quit(save = "no")
}

# =============================================================================
# Batch API Function
# =============================================================================

fetch_openmeteo_batch <- function(cities_df, retry_count = 0) {
  lats <- paste(round(cities_df$prognosticator_lat, 4), collapse = ",")
  lons <- paste(round(cities_df$prognosticator_long, 4), collapse = ",")

  url <- sprintf(
    "https://archive-api.open-meteo.com/v1/archive?latitude=%s&longitude=%s&start_date=%d-01-01&end_date=%d-03-31&daily=temperature_2m_max&temperature_unit=fahrenheit&timezone=auto",
    lats, lons, START_YEAR, END_YEAR
  )

  response <- tryCatch({
    GET(url, timeout(180))
  }, error = function(e) {
    message("  Request error: ", e$message)
    return(NULL)
  })

  if (is.null(response)) return(NULL)

  if (status_code(response) == 429) {
    if (retry_count < MAX_RETRIES) {
      wait_time <- RATE_LIMIT_WAIT * (2^retry_count)
      message(sprintf("  Rate limited! Waiting %d seconds (retry %d/%d)...",
                      wait_time, retry_count + 1, MAX_RETRIES))
      Sys.sleep(wait_time)
      return(fetch_openmeteo_batch(cities_df, retry_count + 1))
    }
    message("  Max retries exceeded")
    return(NULL)
  }

  if (status_code(response) != 200) {
    message("  API error: ", status_code(response))
    return(NULL)
  }

  data <- content(response, as = "text", encoding = "UTF-8")
  parsed <- fromJSON(data, simplifyVector = FALSE)

  # Handle single vs multiple locations
  if (nrow(cities_df) == 1) {
    # Single location - response is a single object
    result <- tibble(
      date = as.Date(unlist(parsed$daily$time)),
      tmax_f = unlist(parsed$daily$temperature_2m_max),
      prognosticator_city = cities_df$prognosticator_city[1]
    )
  } else {
    # Multiple locations - response is array of objects
    result <- NULL
    for (i in seq_len(nrow(cities_df))) {
      city_data <- tibble(
        date = as.Date(unlist(parsed[[i]]$daily$time)),
        tmax_f = unlist(parsed[[i]]$daily$temperature_2m_max),
        prognosticator_city = cities_df$prognosticator_city[i]
      )
      result <- bind_rows(result, city_data)
    }
  }

  result
}

# =============================================================================
# Collect Data in Batches
# =============================================================================

message(sprintf("\n=== Collecting data in batches of %d ===\n", BATCH_SIZE))

n_batches <- ceiling(nrow(city_coords) / BATCH_SIZE)

for (batch_num in seq_len(n_batches)) {
  start_idx <- (batch_num - 1) * BATCH_SIZE + 1
  end_idx <- min(batch_num * BATCH_SIZE, nrow(city_coords))

  batch_cities <- city_coords[start_idx:end_idx, ]

  message(sprintf("[Batch %d/%d] %d cities: %s",
                  batch_num, n_batches, nrow(batch_cities),
                  paste(batch_cities$prognosticator_city, collapse = ", ")))

  batch_data <- fetch_openmeteo_batch(batch_cities)

  if (!is.null(batch_data) && nrow(batch_data) > 0) {
    all_data <- bind_rows(all_data, batch_data)
    message(sprintf("  Got %d records for %d cities",
                    nrow(batch_data), length(unique(batch_data$prognosticator_city))))

    # Save progress
    saveRDS(all_data, "openmeteo_batch_progress.rds")
  } else {
    message("  FAILED - stopping to avoid rate limit issues")
    break
  }

  Sys.sleep(REQUEST_DELAY)
}

# =============================================================================
# Final Summary
# =============================================================================

message(sprintf("\n=== COLLECTION COMPLETE ==="))
message(sprintf("Cities collected: %d", length(unique(all_data$prognosticator_city))))
message(sprintf("Total records: %d", nrow(all_data)))

saveRDS(all_data, "openmeteo_batch_final.rds")
message("Saved to openmeteo_batch_final.rds")
