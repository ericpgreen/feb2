#' Weather classifications, data, definition 1
#'
#' A table listing the average monthly high temperature by location and year, the 15-year running average monthly high temperature for each location, and the early spring/long winter classifications by month, year, and location.
#'
#' @format A data frame with 7 columns:
#' \describe{
#'   \item{prognosticator_city}{Where the prognosticator is located}
#'   \item{year}{Classification year}
#'   \item{yearmo}{Classification year-month}
#'   \item{month}{Classification month}
#'   \item{tmax_monthly_mean_f}{Average monthly high temperature per location by month and year. Daily high temperatures from Open-Meteo ERA5 reanalysis data for each prognosticator's coordinates. Degrees Fahrenheit.}
#'   \item{tmax_monthly_mean_f_15y}{15-year running average monthly high temperature for each location. Degrees Fahrenheit.}
#'   \item{class}{Classification: early spring or long winter}
#' }
#' @source <https://open-meteo.com/en/docs/historical-weather-api>
"class_def1_data"

#' Weather classifications, definition 1
#'
#' A table listing early spring/long winter classifications for each prognosticator's city by year. The definition of "early spring" follows previous analyses by NOAA and 538 in classifying a year as "early spring" if the average temperature in February OR March is above the 15-year running average for the location.
#'
#' @format A data frame with 3 columns:
#' \describe{
#'   \item{prognosticator_city}{Where the prognosticator is located}
#'   \item{year}{Classification year}
#'   \item{class}{Classification: early spring or long winter}
#' }
#' @source <https://open-meteo.com/en/docs/historical-weather-api>
"class_def1"

#' Prediction data
#'
#' A table listing all February 2nd predictions by year and prognosticator
#'
#' @format A data frame with over 2400 rows and 6 columns:
#' \describe{
#'   \item{prognosticator_name}{Prognosticator name}
#'   \item{prognosticator_slug}{Unique identifier derived from the prognosticator's URL on Countdown to Groundhog Day}
#'   \item{Year}{Prediction year}
#'   \item{prediction_orig}{Original prediction label}
#'   \item{prediction}{Recoded prediction: Early Spring, Long Winter, NA}
#'   \item{predict_early_spring}{Binary indicator where 1 equals Early Spring, 0 equals variants of Long Winter, NA}
#' }
#' @source <https://countdowntogroundhogday.com/predictions/>
"predictions"

#' Prognosticators data
#'
#' A table listing all known February 2nd prognosticators
#'
#' @format A data frame with over 300 rows and 14 columns:
#' \describe{
#'   \item{prognosticator_name}{Prognosticator name}
#'   \item{Status}{Active/Inactive status}
#'   \item{prognosticator_slug}{Unique identifier derived from the prognosticator's URL on Countdown to Groundhog Day. Use this for joining with predictions.}
#'   \item{prognosticator_type_orig}{Prognosticator type, original labels from source}
#'   \item{prognosticator_city}{Where the prognosticator is located}
#'   \item{Last Prediction}{Year of last recorded prediction}
#'   \item{prognosticator_lat}{City latitude}
#'   \item{prognosticator_long}{City longitude}
#'   \item{prognosticator_type}{Prognosticator type, cleaned}
#'   \item{prognosticator_status}{Prognosticator status: creature, human mascot, inanimate}
#'   \item{prognosticator_creature}{Prognosticator creature type}
#'   \item{prognosticator_phylum}{Prognosticator creature phylum}
#'   \item{prognosticator_class}{Prognosticator creature class}
#'   \item{prognosticator_order}{Prognosticator creature order}
#' }
#' @source <https://countdowntogroundhogday.com/groundhogs-from-around-the-world>
"prognosticators"

#' NOAA GHCND Weather Stations Near Prognosticators
#'
#' A table listing all NOAA GHCND weather stations within 100km of each prognosticator's city coordinates.
#' Note: As of 2025, weather data primarily comes from Open-Meteo ERA5 reanalysis. GHCND stations are only used for Punxsutawney Phil's pre-1940 predictions (1887-1939).
#'
#' @format A data frame with 15045 rows and 6 columns:
#' \describe{
#'   \item{prognosticator_city}{Where the prognosticator is located}
#'   \item{id}{The weather station's ID number. The first two letters denote the country (using FIPS country codes)}
#'   \item{name}{The station's name}
#'   \item{latitude}{The station's latitude, in decimal degrees. Southern latitudes will be negative}
#'   \item{longitude}{The station's longitude, in decimal degrees. Western longitudes will be negative}
#'   \item{distance}{distance (km) from coordinates searched}
#' }
#' @source <https://www.ncdc.noaa.gov/cdo-web/webservices/v2>
"weather_stations_ghcnd"

#' NOAA ISD Weather Stations Near Prognosticators
#'
#' A table listing all NOAA ISD weather stations within 100km of each prognosticator's city coordinates.
#' Note: As of 2025, weather data primarily comes from Open-Meteo ERA5 reanalysis. ISD stations may be used for supplementary historical analysis.
#'
#' @format A data frame with 5262 rows and 13 columns:
#' \describe{
#'   \item{prognosticator_city}{Where the prognosticator is located}
#'   \item{usaf}{USAF number, character}
#'   \item{wban}{WBAN number, character}
#'   \item{station_name}{station name, character}
#'   \item{ctry}{Country, if given, character}
#'   \item{state}{State, if given, character}
#'   \item{icao}{ICAO number, if given, character}
#'   \item{lat}{Latitude, if given, numeric}
#'   \item{lon}{Longitude, if given, numeric}
#'   \item{elev_m}{Elevation, if given, numeric}
#'   \item{begin}{Begin date of data coverage, of form YYYYMMDD, numeric}
#'   \item{end}{End date of data coverage, of form YYYYMMDD, numeric}
#'   \item{distance}{distance (km) from coordinates searched}
#' }
#' @source <https://www.ncdc.noaa.gov/cdo-web/webservices/v2>
"weather_stations_isd"
