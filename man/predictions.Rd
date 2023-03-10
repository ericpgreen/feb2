% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/data.R
\docType{data}
\name{predictions}
\alias{predictions}
\title{Prediction data}
\format{
A data frame with 1488 rows and 5 columns:
\describe{
  \item{prognosticator_name}{Prognosticator name}
  \item{year}{Prediction year}
  \item{prediction_orig}{Original prediction label}
  \item{prediction}{Recoded prediction: Early Spring, Long Winter, NA}
  \item{predict_early_spring}{Binary indicator where 1 equals Early Spring, 0 equals variants of Long Winter, NA}
}
}
\source{
<https://countdowntogroundhogday.com/predictions/>
}
\usage{
predictions
}
\description{
A table listing all February 2nd predictions by year and prognosticator
}
\keyword{datasets}
