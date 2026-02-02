# weather_20cr.R
# Fetches missing historical weather data from NOAA 20th Century Reanalysis V3
# Fills gaps in GHCND data for Punxsutawney (1887-1892, 1906-1910) and
# Quarryville (1887-1893)

library(tidyverse)
library(ncdf4)

# =============================================================================
# Configuration
# =============================================================================

# OPeNDAP URL for daily max temperature at 2m
opendap_url <- "http://apdrc.soest.hawaii.edu/dods/public_data/Reanalysis_Data/NOAA_20th_Century/V3/daily/monolevel/tmax_2m"

# Locations and missing years
locations <- list(
  list(
    city = "Punxsutawney, PA",
    lat = 40.95,
    lon = -79.0,
    missing_years = c(1887:1892, 1906:1910)
  ),
  list(
    city = "Quarryville, PA",
    lat = 39.9,
    lon = -76.15,
    missing_years = c(1887:1893)
  )
)

# =============================================================================
# Helper Functions
# =============================================================================

#' Convert Kelvin to Fahrenheit
kelvin_to_fahrenheit <- function(k) {

(k - 273.15) * 9/5 + 32
}

#' Find nearest grid index for a given coordinate
find_nearest_index <- function(coord_array, target) {
  which.min(abs(coord_array - target))
}

#' Fetch tmax data for a specific location and year range from 20CR
fetch_20cr_tmax <- function(nc, lat_target, lon_target, years, lat_vals, lon_vals, dates) {

  # Convert negative longitude to 0-360 format if needed
  lon_target_360 <- ifelse(lon_target < 0, lon_target + 360, lon_target)

  # Find nearest grid point
  lat_idx <- find_nearest_index(lat_vals, lat_target)
  lon_idx <- find_nearest_index(lon_vals, lon_target_360)

  actual_lat <- lat_vals[lat_idx]
  actual_lon <- lon_vals[lon_idx]
  if (actual_lon > 180) actual_lon <- actual_lon - 360

  message(sprintf("  Grid point: %.2f°N, %.2f°E (requested: %.2f°N, %.2f°E)",
                  actual_lat, actual_lon, lat_target, lon_target))

  results <- list()

  for (year in years) {
    # Find time indices for Feb and March of this year
    year_mask <- lubridate::year(dates) == year & lubridate::month(dates) %in% c(2, 3)
    year_dates <- dates[year_mask]

    if (length(year_dates) == 0) {
      message(sprintf("  Warning: No data for year %d", year))
      next
    }

    time_indices <- which(year_mask)

    # Read data for this location and time range
    # OPeNDAP subset: [lon, lat, time]
    start <- c(lon_idx, lat_idx, min(time_indices))
    count <- c(1, 1, length(time_indices))

    tmax_k <- ncvar_get(nc, "tmax", start = start, count = count)
    tmax_f <- kelvin_to_fahrenheit(tmax_k)

    # Create data frame
    df <- tibble(
      date = year_dates,
      tmax_f = as.numeric(tmax_f)
    )

    results[[as.character(year)]] <- df
    message(sprintf("  Year %d: %d days", year, nrow(df)))
  }

  bind_rows(results)
}

# =============================================================================
# Main Processing
# =============================================================================

message("=== Fetching data from NOAA 20th Century Reanalysis V3 ===\n")
message(sprintf("OPeNDAP URL: %s\n", opendap_url))

# Open connection to OPeNDAP server
message("Opening connection to OPeNDAP server...")
nc <- nc_open(opendap_url)

# Get coordinate arrays
lat_vals <- ncvar_get(nc, "lat")
lon_vals <- ncvar_get(nc, "lon")
time_vals <- ncvar_get(nc, "time")

# Time is in days since 1-1-1 (year 1 AD)
# R's Date system starts at 1970-01-01, so we need to convert carefully
# Days from year 1 to 1970-01-01 is approximately 719528 days
time_origin <- as.Date("0001-01-01")
# Use a workaround since R doesn't handle year 1 well
# Convert by calculating offset from a known date
# 1836-01-01 corresponds to approximately day 670221 in this system
# Let's use: date = time_vals - 670221 + as.Date("1836-01-01")
reference_day <- 670221  # corresponds to 1836-01-01
reference_date <- as.Date("1836-01-01")

# Convert time values to dates
dates <- reference_date + (time_vals - reference_day)

message(sprintf("Lat range: %.1f to %.1f", min(lat_vals), max(lat_vals)))
message(sprintf("Lon range: %.1f to %.1f", min(lon_vals), max(lon_vals)))
message(sprintf("Time range: %s to %s\n", min(dates), max(dates)))

# Fetch data for each location
all_data <- list()

for (loc in locations) {
  message(sprintf("Fetching data for %s...", loc$city))
  message(sprintf("  Missing years: %s", paste(loc$missing_years, collapse = ", ")))

  data <- fetch_20cr_tmax(
    nc = nc,
    lat_target = loc$lat,
    lon_target = loc$lon,
    years = loc$missing_years,
    lat_vals = lat_vals,
    lon_vals = lon_vals,
    dates = dates
  )

  data$prognosticator_city <- loc$city
  all_data[[loc$city]] <- data

  message(sprintf("  Retrieved %d daily records\n", nrow(data)))
}

# Close connection
nc_close(nc)

# Combine all data
cr20_daily <- bind_rows(all_data)

if (nrow(cr20_daily) == 0) {
  stop("No data retrieved! Check the OPeNDAP connection and date ranges.")
}

cr20_daily <- cr20_daily %>%
  select(prognosticator_city, date, tmax_f)

message(sprintf("Total daily records: %d", nrow(cr20_daily)))

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

message("Monthly means calculated:")
print(cr20_monthly)

# =============================================================================
# Save Results
# =============================================================================

message("\n=== Saving results ===\n")

saveRDS(cr20_daily, "20cr_daily.rds")
saveRDS(cr20_monthly, "20cr_monthly.rds")

message("Saved: 20cr_daily.rds, 20cr_monthly.rds")
message("\nNext: Run process_openmeteo_batch.R to integrate this data")
