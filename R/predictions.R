#' Prediction data
#'
#' A table listing all February 2nd predictions by year and prognosticator
#'
#' @format ## `predictions`
#' A data frame with 1488 rows and 5 columns:
#' \describe{
#'   \item{prognosticator}{Prognosticator name}
#'   \item{year}{Prediction year}
#'   \item{prediction_orig}{Original prediction label}
#'   \item{prediction}{Recoded prediction: Early Spring, Long Winter, NA}
#'   \item{predict_early_spring}{Binary indicator where 1 equals Early Spring, 0 equals variants of Long Winter, NA}
#'   ...
#' }
#' @source <https://countdowntogroundhogday.com/predictions/>
"Countdown to Groundhog Day"
