# update_all.R
# Master script to update all feb2 data
# Run this after March each year to update predictions and classifications

# Prerequisites:
# 1. Set NOAA_TOKEN environment variable (get token at https://www.ncdc.noaa.gov/cdo-web/token)
# 2. Install required packages: tidyverse, httr, jsonlite, rvest, polite, zoo, lubridate, usethis

library(tidyverse)

message("========================================")
message("feb2 Data Update")
message("========================================")
message(sprintf("Date: %s", Sys.Date()))
message("")

# Check for NOAA token
if (Sys.getenv("NOAA_TOKEN") == "") {
  stop("NOAA_TOKEN not set. Get a token at https://www.ncdc.noaa.gov/cdo-web/token
       Then run: Sys.setenv(NOAA_TOKEN = 'your-token-here')")
}

# Set working directory to package root
if (!file.exists("DESCRIPTION")) {
  stop("Please run this script from the feb2 package root directory")
}

setwd("data-raw")

# =============================================================================
# Step 1: Update Prognosticators
# =============================================================================
message("\n--- Step 1: Updating prognosticators ---")
tryCatch({
  source("prognosticators.R")
  message("✓ Prognosticators updated")
}, error = function(e) {
  message("✗ Error updating prognosticators: ", e$message)
})

# =============================================================================
# Step 2: Update Predictions
# =============================================================================
message("\n--- Step 2: Updating predictions ---")
tryCatch({
  source("predictions.R")
  message("✓ Predictions updated")
}, error = function(e) {
  message("✗ Error updating predictions: ", e$message)
})

# =============================================================================
# Step 3: Update Weather Data and Classifications
# =============================================================================
message("\n--- Step 3: Updating weather data (this may take a while) ---")
tryCatch({
  source("weather_ghcnd_api.R")
  message("✓ Weather data and classifications updated")
}, error = function(e) {
  message("✗ Error updating weather data: ", e$message)
})

setwd("..")

# =============================================================================
# Summary
# =============================================================================
message("\n========================================")
message("Update Complete!")
message("========================================")

# Load and summarize updated data
load("data/predictions.rda")
load("data/class_def1_data.rda")

message(sprintf("\nPredictions: %d records, years %d-%d",
                nrow(predictions),
                min(predictions$Year),
                max(predictions$Year)))

message(sprintf("Classifications: %d records, years %d-%d",
                nrow(class_def1_data),
                min(class_def1_data$year),
                max(class_def1_data$year)))

message("\nRemember to:")
message("1. Review changes with git diff")
message("2. Update version in DESCRIPTION")
message("3. Commit and push to GitHub")
