library(rvest)
library(polite)
library(tidyverse)

# check permissions
# ---------------------
  url <- "https://countdowntogroundhogday.com/past-predictions/1887"
  session <- bow(url, user_agent = "Class Project")
  session

# Helper function to extract predictions with slugs from a page
# ---------------------
extract_predictions <- function(page) {
  rows <- page %>% html_nodes("table tr")

  map_dfr(rows[-1], function(row) {
    cells <- row %>% html_nodes("td")
    if (length(cells) < 3) return(NULL)

    # Get the link href to extract slug
    name_link <- cells[2] %>% html_node("a") %>% html_attr("href")
    slug <- if (!is.na(name_link)) trimws(basename(name_link)) else ""

    tibble(
      Prediction = cells[1] %>% html_text(trim = TRUE),
      Name = cells[2] %>% html_text(trim = TRUE),
      slug = slug,
      Type = cells[3] %>% html_text(trim = TRUE)
    )
  })
}

# get predictions
# ---------------------

# create empty data frame
  predictions <- NULL

# loop through 1887-2018 predictions
  for (y in 1887:2018) {
    url <- paste0("https://countdowntogroundhogday.com/past-predictions/", y)

    session <- bow(url, user_agent = "Class Project")
    page <- scrape(session)

    p <- extract_predictions(page) %>%
      mutate(Year = y)

    predictions <- predictions %>%
      bind_rows(p)

    message(sprintf("Fetched %d predictions for %d", nrow(p), y))
  }

# loop through 2019-current predictions
# REMEMBER: update end year

  for (y in 2019:2025) {
    url <- paste0("https://countdowntogroundhogday.com/predictions/", y, "_predictions")

    session <- bow(url, user_agent = "Class Project")
    page <- scrape(session)

    p <- extract_predictions(page) %>%
      mutate(Year = y)

    predictions <- predictions %>%
      bind_rows(p)

    message(sprintf("Fetched %d predictions for %d", nrow(p), y))
  }

# wrangle
# REMEMBER: check for predictions that can be re-classified as LW or ES
  predictions <- predictions %>%
    select(Name, slug, Year, Prediction) %>%
    rename(prognosticator_name = Name,
           prognosticator_slug = slug,
           prediction_orig = Prediction) %>%
    mutate(prediction = case_when(
      prediction_orig == "Long Winter" ~ "Long Winter",
      prediction_orig == "Long Sloppy Winter" ~ "Long Winter",
      prediction_orig == "Late Spring" ~ "Long Winter",
      prediction_orig == "Early Spring" ~ "Early Spring",
      prediction_orig == "'Flip- flop' end of winter" ~ "Long Winter",
      prediction_orig == "Long Spring" ~ "Early Spring",
      TRUE ~ NA_character_
    )) %>%
    mutate(predict_early_spring = case_when(
      is.na(prediction) ~ NA_integer_,
      prediction == "Early Spring" ~ 1L,
      TRUE ~ 0L
    ))

message(sprintf("Total predictions: %d", nrow(predictions)))
message(sprintf("Unique slugs: %d", length(unique(predictions$prognosticator_slug))))

usethis::use_data(predictions, overwrite = TRUE)
