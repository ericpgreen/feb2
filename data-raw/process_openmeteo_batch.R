# process_openmeteo_batch.R
# Processes collected Open-Meteo data into class_def1 datasets
# Run after: weather_openmeteo_batch.R

library(tidyverse)

# =============================================================================
# Load Raw Data
# =============================================================================

message("Loading collected weather data...")

if (!file.exists("openmeteo_batch_final.rds")) {
  stop("openmeteo_batch_final.rds not found. Run weather_openmeteo_batch.R first.")
}

all_data <- readRDS("openmeteo_batch_final.rds")
message(sprintf("Loaded %d records for %d cities",
                nrow(all_data), length(unique(all_data$prognosticator_city))))

# =============================================================================
# Process Open-Meteo Data: Filter to Feb-March, Calculate Monthly Means
# =============================================================================

message("\n=== Processing Open-Meteo data ===\n")

# Filter to February and March only
feb_mar_data <- all_data %>%
  mutate(
    year = lubridate::year(date),
    month = lubridate::month(date)
  ) %>%
  filter(month %in% c(2, 3))

message(sprintf("Feb-March records: %d", nrow(feb_mar_data)))

# Calculate monthly means for Open-Meteo data
openmeteo_monthly <- feb_mar_data %>%
  group_by(prognosticator_city, year, month) %>%
  summarize(
    tmax_monthly_mean_f = mean(tmax_f, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(yearmo = paste(year, str_pad(month, 2, pad = "0"), sep = "-"))

# =============================================================================
# Load GHCND Pre-1940 Data and Combine BEFORE Calculating Rolling Average
# =============================================================================

message("\n=== Loading GHCND pre-1940 data ===\n")

# Check if backup exists with full GHCND data
backup_files <- list.files("../data", pattern = "class_def1_data_backup.*\\.rda$", full.names = TRUE)
if (length(backup_files) > 0) {
  # Use most recent backup
  backup_file <- sort(backup_files, decreasing = TRUE)[1]
  message(sprintf("Loading pre-1940 data from: %s", backup_file))
  load(backup_file)  # loads class_def1_data

  # Extract just the monthly means for pre-1940 (drop old rolling avg and class)
  ghcnd_monthly <- class_def1_data %>%
    filter(year < 1940) %>%
    filter(prognosticator_city %in% c("Punxsutawney, PA", "Quarryville, PA")) %>%
    select(prognosticator_city, year, month, yearmo, tmax_monthly_mean_f)

  message(sprintf("GHCND pre-1940 records: %d", nrow(ghcnd_monthly)))
} else {
  message("No backup file found - skipping pre-1940 data")
  ghcnd_monthly <- NULL
}

# =============================================================================
# Load 20CR Data to Fill GHCND Gaps
# =============================================================================

message("\n=== Loading 20CR data for GHCND gaps ===\n")

if (file.exists("20cr_monthly.rds")) {
  cr20_monthly <- readRDS("20cr_monthly.rds") %>%
    select(prognosticator_city, year, month, yearmo, tmax_monthly_mean_f)

  message(sprintf("20CR records: %d", nrow(cr20_monthly)))

  # Fill NA values in GHCND with 20CR data
  if (!is.null(ghcnd_monthly)) {
    # Identify rows with NA temperature in GHCND
    ghcnd_na_keys <- ghcnd_monthly %>%
      filter(is.na(tmax_monthly_mean_f)) %>%
      mutate(key = paste(prognosticator_city, year, month, sep = "-")) %>%
      pull(key)

    message(sprintf("GHCND rows with NA temperature: %d", length(ghcnd_na_keys)))

    # Get 20CR data for those gaps
    cr20_to_use <- cr20_monthly %>%
      mutate(key = paste(prognosticator_city, year, month, sep = "-")) %>%
      filter(key %in% ghcnd_na_keys) %>%
      select(-key)

    message(sprintf("20CR records filling GHCND NA gaps: %d", nrow(cr20_to_use)))

    # Remove NA rows from GHCND and replace with 20CR data
    ghcnd_monthly <- ghcnd_monthly %>%
      filter(!is.na(tmax_monthly_mean_f)) %>%
      bind_rows(cr20_to_use) %>%
      arrange(prognosticator_city, year, month)

    message(sprintf("Combined pre-1940 records (GHCND + 20CR): %d", nrow(ghcnd_monthly)))
  } else {
    ghcnd_monthly <- cr20_monthly
    message("Using 20CR data as primary pre-1940 source")
  }
} else {
  message("No 20CR data found (20cr_monthly.rds) - run weather_20cr.R first if you want to fill GHCND gaps")
}

# Combine monthly means FIRST (before rolling average calculation)
# This ensures the 15-year rolling average carries across the GHCND/Open-Meteo boundary
combined_monthly <- bind_rows(
  ghcnd_monthly,
  openmeteo_monthly
) %>%
  arrange(prognosticator_city, year, month)

message(sprintf("Combined monthly records: %d", nrow(combined_monthly)))

# =============================================================================
# Calculate 15-Year Rolling Average on Combined Data
# =============================================================================

message("\n=== Calculating 15-year rolling averages ===\n")

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

feb_rolling <- calc_rolling_avg(combined_monthly, 2)
mar_rolling <- calc_rolling_avg(combined_monthly, 3)

# Combine and classify
class_def1_data_new <- bind_rows(feb_rolling, mar_rolling) %>%
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

message("\n=== Saving data ===\n")

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

message("\nDone! Now run export_json.R to update JSON exports.")
