# feb2 0.2.2

## Data updates

* Added 2026 Groundhog Day predictions and weather classifications. Prognosticators grew from 315 to 331, predictions from 2,482 to 2,630 (117 new for 2026), and weather classification now extends through 2026 (160 Early Spring, 2 Long Winter for the classifiable cities).

* 2026 weather was fetched incrementally (Jan–Mar 2026 only) via `data-raw/weather_2026_increment.R` and merged with existing historical monthly means; the 15-year rolling averages and `def1` classifications for all years ≤2025 are byte-identical to the prior release.

## Bug fixes

* Fixed a casing bug in `data-raw/export_json.R` that made `accuracy.json` measure the wrong thing. The accuracy computation compared classifications against `"early spring"` (lowercase) when the data uses `"Early Spring"`, so every prognosticator's reported accuracy was inverted. Punxsutawney Phil now correctly shows 33.9% (matching his real ~34% record).

## Known limitations

* 16 forecasters new in 2026 lack taxonomy in `prognosticator_classification.csv`, and 11 cities new this cycle have no 2026 `def1` classification (insufficient 15-year history). Both are resolved by a future full weather backfill.

# feb2 0.2.1

## New features

* Added NOAA 20th Century Reanalysis V3 data (1926-1939) for all 165 prognosticator cities. This enables classification for 1940 onward, eliminating 2,212 NA values that previously existed due to the 15-year rolling average requirement.

* Extended Punxsutawney Phil's verifiable prediction history back to 1901 (was 1925) by filling GHCND gaps with 20CR data.

## Bug fixes

* Fixed 15-year rolling average calculation for cities with pre-1940 data. Previously, the rolling average reset at 1940 when switching from GHCND to Open-Meteo data. Now the rolling average is calculated on the combined data.

## Documentation

* Added documentation explaining NA values in `class_def1` and `class_def1_data`
* Updated README with "Missing Values (NA)" section and data sources

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
