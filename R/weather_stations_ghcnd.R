#' NOAA GHCND Weather Stations Near Prognosticators
#'
#' A table listing all NOAA GHCND weather stations within 100km of each prognosticator's city coordinates
#'
#' @format ## `weather_stations_ghcnd`
#' A data frame with 15045 rows and 6 columns:
#' \describe{
#'   \item{prognosticator_city}{Where the prognosticator is located}
#'   \item{id}{The weather station's ID number. The first two letters denote the country (using FIPS country codes)}
#'   \item{name}{The station's name}
#'   \item{latitude}{The station's latitude, in decimal degrees. Southern latitudes will be negative}
#'   \item{longitude}{The station's longitude, in decimal degrees. Western longitudes will be negative}
#'   \item{distance}{distance (km) from coordinates searched}
#'   ...
#' }
#' @source <https://www.ncdc.noaa.gov/cdo-web/webservices/v2>
"NOAA"
