# weather_20cr.R
# Fetches historical weather data from NOAA 20th Century Reanalysis V3
#
# Two purposes:
# 1. Fill GHCND gaps for Punxsutawney (1887-1892, 1906-1910) and Quarryville (1887-1893)
# 2. Provide 1926-1939 data for ALL cities to enable rolling average calculation for 1940+

library(tidyverse)
library(ncdf4)

# =============================================================================
# Configuration
# =============================================================================

# OPeNDAP URL for daily max temperature at 2m
opendap_url <- "http://apdrc.soest.hawaii.edu/dods/public_data/Reanalysis_Data/NOAA_20th_Century/V3/daily/monolevel/tmax_2m"

# Load prognosticator cities
load("../data/prognosticators.rda")

# Get all cities with coordinates
all_cities <- prognosticators %>%
  filter(!is.na(prognosticator_lat), !is.na(prognosticator_long)) %>%
  distinct(prognosticator_city, prognosticator_lat, prognosticator_long) %>%
  rename(city = prognosticator_city, lat = prognosticator_lat, lon = prognosticator_long)

message(sprintf("Total cities to process: %d", nrow(all_cities)))

# Years to fetch:
# - 1926-1939 for ALL cities (enables 1940+ rolling average)
# - 1887-1892, 1906-1910 for Punxsutawney (fills GHCND gaps)
# - 1887-1893 for Quarryville (fills GHCND gaps)
years_all_cities <- 1926:1939
years_punxsutawney_extra <- c(1887:1892, 1906:1910)
years_quarryville_extra <- 1887:1893

# =============================================================================
# Helper Functions
# =============================================================================

kelvin_to_fahrenheit <- function(k) {
  (k - 273.15) * 9/5 + 32
}

find_nearest_index <- function(coord_array, target) {
  which.min(abs(coord_array - target))
}

#' Fetch tmax data for a specific location and years
fetch_20cr_tmax <- function(nc, lat_target, lon_target, years, lat_vals, lon_vals, dates) {

  # Convert negative longitude to 0-360 format
  lon_target_360 <- ifelse(lon_target < 0, lon_target + 360, lon_target)

  # Find nearest grid point
  lat_idx <- find_nearest_index(lat_vals, lat_target)
  lon_idx <- find_nearest_index(lon_vals, lon_target_360)

  results <- list()

  for (year in years) {
    # Find time indices for Feb and March of this year
    year_mask <- lubridate::year(dates) == year & lubridate::month(dates) %in% c(2, 3)
    year_dates <- dates[year_mask]

    if (length(year_dates) == 0) next

    time_indices <- which(year_mask)

    # Read data - OPeNDAP subset: [lon, lat, time]
    start <- c(lon_idx, lat_idx, min(time_indices))
    count <- c(1, 1, length(time_indices))

    tmax_k <- ncvar_get(nc, "tmax", start = start, count = count)
    tmax_f <- kelvin_to_fahrenheit(tmax_k)

    results[[as.character(year)]] <- tibble(
      date = year_dates,
      tmax_f = as.numeric(tmax_f)
    )
  }

  bind_rows(results)
}

# =============================================================================
# Main Processing
# =============================================================================

message("\n=== Fetching data from NOAA 20th Century Reanalysis V3 ===\n")
message(sprintf("OPeNDAP URL: %s", opendap_url))

# Open connection
message("Opening connection to OPeNDAP server...")
nc <- nc_open(opendap_url)

# Get coordinate arrays
lat_vals <- ncvar_get(nc, "lat")
lon_vals <- ncvar_get(nc, "lon")
time_vals <- ncvar_get(nc, "time")

# Convert time (days since year 1) to dates
reference_day <- 670221  # corresponds to 1836-01-01
reference_date <- as.Date("1836-01-01")
dates <- reference_date + (time_vals - reference_day)

message(sprintf("Data range: %s to %s", min(dates), max(dates)))
message(sprintf("Grid: %d lat x %d lon", length(lat_vals), length(lon_vals)))

# Process all cities
all_data <- list()
n_cities <- nrow(all_cities)

for (i in seq_len(n_cities)) {
  city_info <- all_cities[i, ]
  city <- city_info$city

  # Determine which years to fetch for this city
  if (grepl("Punxsutawney", city)) {
    years_to_fetch <- sort(unique(c(years_all_cities, years_punxsutawney_extra)))
  } else if (grepl("Quarryville", city)) {
    years_to_fetch <- sort(unique(c(years_all_cities, years_quarryville_extra)))
  } else {
    years_to_fetch <- years_all_cities
  }

  message(sprintf("[%d/%d] %s (%.2f, %.2f) - years %d-%d",
                  i, n_cities, city, city_info$lat, city_info$lon,
                  min(years_to_fetch), max(years_to_fetch)))

  tryCatch({
    data <- fetch_20cr_tmax(
      nc = nc,
      lat_target = city_info$lat,
      lon_target = city_info$lon,
      years = years_to_fetch,
      lat_vals = lat_vals,
      lon_vals = lon_vals,
      dates = dates
    )

    if (nrow(data) > 0) {
      data$prognosticator_city <- city
      all_data[[city]] <- data
    }
  }, error = function(e) {
    message(sprintf("  ERROR: %s", e$message))
  })
}

nc_close(nc)

# Combine all data
cr20_daily <- bind_rows(all_data) %>%
  select(prognosticator_city, date, tmax_f)

message(sprintf("\nTotal daily records: %d", nrow(cr20_daily)))
message(sprintf("Cities with data: %d", length(unique(cr20_daily$prognosticator_city))))

# =============================================================================
# Calculate Monthly Means
# =============================================================================

message("\n=== Calculating monthly means ===\n")

cr20_monthly <- cr20_daily %>%
  mutate(
    year = lubridate::year(date),
    month = lubridate::month(date)
  ) %>%
  filter(month %in% c(2, 3)) %>%
  group_by(prognosticator_city, year, month) %>%
  summarize(
    tmax_monthly_mean_f = mean(tmax_f, na.rm = TRUE),
    n_days = n(),
    .groups = "drop"
  ) %>%
  mutate(yearmo = paste(year, str_pad(month, 2, pad = "0"), sep = "-"))

message(sprintf("Monthly records: %d", nrow(cr20_monthly)))
message(sprintf("Year range: %d to %d", min(cr20_monthly$year), max(cr20_monthly$year)))

# Summary by year
message("\nRecords per year:")
cr20_monthly %>%
  count(year) %>%
  print(n = 100)

# =============================================================================
# Save Results
# =============================================================================

message("\n=== Saving results ===\n")

saveRDS(cr20_daily, "20cr_daily.rds")
saveRDS(cr20_monthly, "20cr_monthly.rds")

message("Saved: 20cr_daily.rds, 20cr_monthly.rds")
message("\nNext: Run process_openmeteo_batch.R to integrate this data")
