#' Weather classifications, definition 1
#'
#' A table listing early spring/long winter classifications for each prognosticator's city by year. The definition of "early spring" follows previous analyses by NOAA and 538 in classifying a year as "early spring" if the average temperature in February OR March is above the 15-year running average for the location.
#'
#' @format ## `class_def1`
#' A data frame with 16456 rows and 3 columns:
#' \describe{
#'   \item{prognosticator_city}{Where the prognosticator is located}
#'   \item{year}{Classification year}
#'   \item{class}{Classification: early spring or long winter}
#'   ...
#' }
#' @source <https://www.ncdc.noaa.gov/cdo-web/webservices/v2>
"Constructed from NOAA data"
