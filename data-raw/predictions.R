library(rvest)
library(polite)
library(tidyverse)

# check permissions
# ---------------------
  url <- "https://countdowntogroundhogday.com/past-predictions/1887"
  session <- bow(url, user_agent = "Class Project")
  session

# get predictions
# ---------------------

# create empty data frame
  predictions <- NULL

# loop through 1887-2018 predictions
  for (y in 1887:2018) {
    url <- paste0("https://countdowntogroundhogday.com/past-predictions/", y)

    session <- bow(url, user_agent = "Class Project")

    predictions_node <- scrape(session) %>%
      html_nodes("#forecaster-table")

    p <- predictions_node %>%
      html_table() %>%
      flatten_df() %>%
      mutate(Year = y)

    predictions <- predictions %>%
      bind_rows(p)
  }

# loop through 2019-current predictions

  for (y in 2019:2022) {
    url <- paste0("https://countdowntogroundhogday.com/predictions/", y, "_predictions")

    session <- bow(url, user_agent = "Class Project")

    predictions_node <- scrape(session) %>%
      html_nodes("#forecaster-table")

    p <- predictions_node %>%
      html_table() %>%
      flatten_df() %>%
      mutate(Year = y)

    predictions <- predictions %>%
      bind_rows(p)
  }

# wrangle
  predictions <- predictions %>%
    select(Name, year, Prediction) %>%
    rename(prognosticator = Name,
           prediction_orig = Prediction) %>%
    mutate(prediction = case_when(
      prediction_orig == "Long Winter" ~ "Long Winter",
      prediction_orig == "Long Sloppy Winter" ~ "Long Winter",
      prediction_orig == "Late Spring" ~ "Long Winter",
      prediction_orig == "Early Spring" ~ "Early Spring",
      TRUE ~ NA_character_
    )) %>%
    mutate(predict_early_spring = case_when(
      is.na(prediction) ~ NA_integer_,
      prediction == "Early Spring" ~ 1L,
      TRUE ~ 0L
    ))

usethis::use_data(predictions, overwrite = TRUE)
