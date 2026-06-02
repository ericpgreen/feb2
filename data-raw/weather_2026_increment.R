# weather_2026_increment.R
# Incremental update: fetch ONLY 2026 (Jan-Mar) daily temps and merge with the
# existing historical monthly means already stored in data/class_def1_data.rda
# (which carry all 1887-2025 data across the GHCND/20CR/Open-Meteo boundaries).
#
# This avoids re-downloading 86 years of data per city just to add one year.
# Output is identical to process_openmeteo_batch.R for 1887-2025, plus 2026.
#
# Run from data-raw/:  Rscript -e 'setwd("data-raw"); source("weather_2026_increment.R")'

library(tidyverse)
library(httr)
library(jsonlite)

NEW_YEAR    <- 2026
BATCH_SIZE  <- 5
REQUEST_DELAY    <- 3.0
MAX_RETRIES      <- 5
RATE_LIMIT_WAIT  <- 60

# =============================================================================
# City list (same logic/exclusions as weather_openmeteo_batch.R)
# =============================================================================
load("../data/prognosticators.rda")
load("../data/predictions.rda")

pred_with_city <- predictions %>%
  left_join(
    prognosticators %>% select(prognosticator_slug, prognosticator_city,
                               prognosticator_lat, prognosticator_long),
    by = "prognosticator_slug"
  ) %>%
  filter(!is.na(prognosticator_city))

excluded_cities <- c("Mira, NS", "MD", "IL", "WI")
city_coords <- pred_with_city %>%
  distinct(prognosticator_city, prognosticator_lat, prognosticator_long) %>%
  filter(!prognosticator_city %in% excluded_cities) %>%
  filter(!is.na(prognosticator_lat) & !is.na(prognosticator_long))

message(sprintf("Fetching %d for %d cities", NEW_YEAR, nrow(city_coords)))

# =============================================================================
# Batch fetch (2026 only - small payloads)
# =============================================================================
fetch_batch <- function(cities_df, retry_count = 0) {
  lats <- paste(round(cities_df$prognosticator_lat, 4), collapse = ",")
  lons <- paste(round(cities_df$prognosticator_long, 4), collapse = ",")
  url <- sprintf(
    "https://archive-api.open-meteo.com/v1/archive?latitude=%s&longitude=%s&start_date=%d-01-01&end_date=%d-03-31&daily=temperature_2m_max&temperature_unit=fahrenheit&timezone=auto",
    lats, lons, NEW_YEAR, NEW_YEAR
  )
  response <- tryCatch(GET(url, timeout(120)), error = function(e) {
    message("  Request error: ", e$message); NULL
  })
  if (is.null(response)) {
    if (retry_count < MAX_RETRIES) { Sys.sleep(10); return(fetch_batch(cities_df, retry_count + 1)) }
    return(NULL)
  }
  if (status_code(response) == 429) {
    if (retry_count < MAX_RETRIES) {
      wait_time <- RATE_LIMIT_WAIT * (2^retry_count)
      message(sprintf("  Rate limited! Waiting %d s (retry %d/%d)...", wait_time, retry_count + 1, MAX_RETRIES))
      Sys.sleep(wait_time)
      return(fetch_batch(cities_df, retry_count + 1))
    }
    return(NULL)
  }
  if (status_code(response) != 200) { message("  API error: ", status_code(response)); return(NULL) }

  parsed <- fromJSON(content(response, as = "text", encoding = "UTF-8"), simplifyVector = FALSE)
  if (nrow(cities_df) == 1) {
    tibble(date = as.Date(unlist(parsed$daily$time)),
           tmax_f = unlist(parsed$daily$temperature_2m_max),
           prognosticator_city = cities_df$prognosticator_city[1])
  } else {
    map_dfr(seq_len(nrow(cities_df)), function(i) {
      tibble(date = as.Date(unlist(parsed[[i]]$daily$time)),
             tmax_f = unlist(parsed[[i]]$daily$temperature_2m_max),
             prognosticator_city = cities_df$prognosticator_city[i])
    })
  }
}

all_2026 <- NULL
n_batches <- ceiling(nrow(city_coords) / BATCH_SIZE)
for (b in seq_len(n_batches)) {
  idx <- ((b - 1) * BATCH_SIZE + 1):min(b * BATCH_SIZE, nrow(city_coords))
  bc <- city_coords[idx, ]
  message(sprintf("[Batch %d/%d] %s", b, n_batches, paste(bc$prognosticator_city, collapse = ", ")))
  bd <- fetch_batch(bc)
  if (is.null(bd)) { stop(sprintf("Batch %d failed after retries; rerun to resume not supported - rerun whole script.", b)) }
  all_2026 <- bind_rows(all_2026, bd)
  Sys.sleep(REQUEST_DELAY)
}
message(sprintf("Fetched %d daily records for %d cities",
                nrow(all_2026), length(unique(all_2026$prognosticator_city))))

# =============================================================================
# 2026 monthly means (Feb/March)
# =============================================================================
monthly_2026 <- all_2026 %>%
  mutate(year = lubridate::year(date), month = lubridate::month(date)) %>%
  filter(month %in% c(2, 3)) %>%
  group_by(prognosticator_city, year, month) %>%
  summarize(tmax_monthly_mean_f = mean(tmax_f, na.rm = TRUE), .groups = "drop") %>%
  mutate(yearmo = paste(year, str_pad(month, 2, pad = "0"), sep = "-")) %>%
  filter(!is.nan(tmax_monthly_mean_f))

# =============================================================================
# Historical monthly means from existing class_def1_data (<= 2025)
# =============================================================================
load("../data/class_def1_data.rda")
historical_monthly <- class_def1_data %>%
  filter(year < NEW_YEAR) %>%
  select(prognosticator_city, year, month, yearmo, tmax_monthly_mean_f)

combined_monthly <- bind_rows(historical_monthly, monthly_2026) %>%
  arrange(prognosticator_city, year, month)

message(sprintf("Combined monthly records: %d (historical %d + 2026 %d)",
                nrow(combined_monthly), nrow(historical_monthly), nrow(monthly_2026)))

# =============================================================================
# 15-year rolling average + classification (identical to process_openmeteo_batch.R)
# =============================================================================
calc_rolling_avg <- function(data, mon) {
  data %>%
    filter(month == mon) %>%
    arrange(prognosticator_city, year) %>%
    group_by(prognosticator_city) %>%
    mutate(tmax_monthly_mean_f_15y = zoo::rollmean(
      tmax_monthly_mean_f, k = 15, fill = NA, align = "right")) %>%
    ungroup()
}

class_def1_data_new <- bind_rows(
  calc_rolling_avg(combined_monthly, 2),
  calc_rolling_avg(combined_monthly, 3)
) %>%
  arrange(prognosticator_city, year, month) %>%
  group_by(prognosticator_city, year) %>%
  mutate(class = case_when(
    any(tmax_monthly_mean_f > tmax_monthly_mean_f_15y, na.rm = TRUE) ~ "Early Spring",
    any(is.na(tmax_monthly_mean_f)) ~ NA_character_,
    any(is.na(tmax_monthly_mean_f_15y)) ~ NA_character_,
    TRUE ~ "Long Winter"
  )) %>%
  ungroup()

class_def1_data <- class_def1_data_new
usethis::use_data(class_def1_data, overwrite = TRUE)

class_def1 <- class_def1_data %>% distinct(prognosticator_city, year, class)
usethis::use_data(class_def1, overwrite = TRUE)

# =============================================================================
# Summary + sanity check that 1887-2025 is unchanged
# =============================================================================
message(sprintf("\nYear range: %d-%d, cities: %d, rows: %d",
                min(class_def1_data$year), max(class_def1_data$year),
                length(unique(class_def1_data$prognosticator_city)), nrow(class_def1_data)))
message("\n2026 classification counts:")
class_def1_data %>% filter(year == 2026) %>%
  distinct(prognosticator_city, class) %>% count(class) %>% print()
message("Done.")
