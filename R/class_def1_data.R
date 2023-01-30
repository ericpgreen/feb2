#' Weather classifications, data, definition 1
#'
#' A table listing the average monthly high temperature by location and year, the 15-year running average monthly high temperature for each location, and the early spring/long winter classifications by month, year, and location.
#'
#' @format ## `class_def1_data`
#' A data frame with 32912 rows and 7 columns:
#' \describe{
#'   \item{prognosticator_city}{Where the prognosticator is located}
#'   \item{year}{Classification year}
#'   \item{yearmo}{Classification year-month}
#'   \item{month}{Classification month}
#'   \item{tmax_monthly_mean_f}{Average monthly high temperature per location by month and year. Daily high temperatures averaged across up to 10 weather stations near each location. Monthly data then averaged over the daily summaries. Degrees Fahrenheit.}
#'   \item{tmax_monthly_mean_f_15y}{15-year running average monthly high temperature for each location. Degrees Fahrenheit.}
#'   \item{class}{Classification: early spring or long winter}
#'   ...
#' }
#' @source <https://www.ncdc.noaa.gov/cdo-web/webservices/v2>
"Constructed from NOAA data"
