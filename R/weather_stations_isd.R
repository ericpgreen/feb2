#' NOAA ISD Weather Stations Near Prognosticators
#'
#' A table listing all NOAA ISD weather stations within 100km of each prognosticator's city coordinates
#'
#' @format ## `weather_stations_isd`
#' A data frame with 5262 rows and 13 columns:
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
#'   ...
#' }
#' @source <https://www.ncdc.noaa.gov/cdo-web/webservices/v2>
"NOAA"
