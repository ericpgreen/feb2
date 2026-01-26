# weather_openmeteo_chunked.R
# Collects weather data using Open-Meteo Historical API in smaller chunks
# to avoid rate limiting

library(tidyverse)
library(httr)
library(jsonlite)

# =============================================================================
# Configuration
# =============================================================================

START_YEAR <- 1940
END_YEAR <- 2025
CHUNK_SIZE <- 10  # years per request
REQUEST_DELAY <- 2.0  # seconds between requests
MAX_RETRIES <- 3

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
# Open-Meteo API Function (smaller chunks)
# =============================================================================

fetch_openmeteo_chunk <- function(lat, lon, start_year, end_year, retry_count = 0) {
  start_date <- sprintf("%d-01-01", start_year)
  end_date <- sprintf("%d-12-31", end_year)

  url <- sprintf(
    "https://archive-api.open-meteo.com/v1/archive?latitude=%f&longitude=%f&start_date=%s&end_date=%s&daily=temperature_2m_max&temperature_unit=fahrenheit&timezone=auto",
    lat, lon, start_date, end_date
  )

  response <- tryCatch({
    GET(url, timeout(60))
  }, error = function(e) {
    return(NULL)
  })

  if (is.null(response)) return(NULL)

  if (status_code(response) == 429) {
    if (retry_count < MAX_RETRIES) {
      wait_time <- 2^retry_count * 10
      message(sprintf("    Rate limited, waiting %ds...", wait_time))
      Sys.sleep(wait_time)
      return(fetch_openmeteo_chunk(lat, lon, start_year, end_year, retry_count + 1))
    }
    return(NULL)
  }

  if (status_code(response) != 200) return(NULL)

  data <- content(response, as = "parsed", type = "application/json")
  if (is.null(data$daily)) return(NULL)

  tibble(
    date = as.Date(unlist(data$daily$time)),
    tmax_f = unlist(data$daily$temperature_2m_max)
  )
}

# =============================================================================
# Collect Data
# =============================================================================

message("\n=== Starting chunked data collection ===\n")

# Resume from progress
if (file.exists("openmeteo_chunked_progress.rds")) {
  message("Resuming from progress...")
  all_data <- readRDS("openmeteo_chunked_progress.rds")
  completed_cities <- unique(all_data$prognosticator_city)
  message(sprintf("Already have data for %d cities", length(completed_cities)))
} else {
  all_data <- NULL
  completed_cities <- character(0)
}

# Year chunks
year_chunks <- seq(START_YEAR, END_YEAR, by = CHUNK_SIZE)

for (i in seq_len(nrow(city_coords))) {
  city <- city_coords[i, ]

  if (city$prognosticator_city %in% completed_cities) {
    message(sprintf("[%d/%d] %s - SKIPPED", i, nrow(city_coords), city$prognosticator_city))
    next
  }

  message(sprintf("[%d/%d] %s", i, nrow(city_coords), city$prognosticator_city))

  city_data <- NULL
  success <- TRUE

  for (chunk_start in year_chunks) {
    chunk_end <- min(chunk_start + CHUNK_SIZE - 1, END_YEAR)

    chunk_data <- fetch_openmeteo_chunk(
      city$prognosticator_lat,
      city$prognosticator_long,
      chunk_start,
      chunk_end
    )

    if (is.null(chunk_data)) {
      message(sprintf("  Failed on %d-%d", chunk_start, chunk_end))
      success <- FALSE
      break
    }

    city_data <- bind_rows(city_data, chunk_data)
    Sys.sleep(REQUEST_DELAY)
  }

  if (success && !is.null(city_data)) {
    city_data$prognosticator_city <- city$prognosticator_city
    all_data <- bind_rows(all_data, city_data)
    message(sprintf("  Got %d days", nrow(city_data)))
    saveRDS(all_data, "openmeteo_chunked_progress.rds")
  }
}

message(sprintf("\nCollected data for %d cities", length(unique(all_data$prognosticator_city))))
saveRDS(all_data, "openmeteo_chunked_final.rds")
