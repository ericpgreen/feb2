# feb2 0.2.0

## Major changes

* Weather data now sourced from Open-Meteo ERA5 reanalysis API instead of NOAA ISD stations
* Coverage expanded to 158 unique prognosticator cities (up from ~50)
* Historical coverage extended: 1887-2025 (Punxsutawney uses GHCND data pre-1940)

## Data updates

* `class_def1`: ~14,000 city-year classifications
* `class_def1_data`: Monthly temperature data with 15-year rolling averages
* `predictions`: Column renamed from `Year` to `year` for consistency

## New features

* Added testthat test suite (141 tests) for data validation
* Added JSON exports in `inst/json/` for web applications

## Documentation

* Updated README with reproduction instructions for weather data
* Added data documentation in `R/data.R`

# feb2 0.1.0

* Initial release with prediction data from Countdown to Groundhog Day
* Weather classifications using NOAA ISD station data
* Basic prognosticator and prediction datasets
