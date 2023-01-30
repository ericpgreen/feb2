library(rvest)
library(polite)
library(tidyverse)
library(tidygeocoder)
library(googlesheets4)
gs4_deauth()

# check permissions
# ---------------------
  url <- "https://countdowntogroundhogday.com/past-predictions/1887"
  session <- bow(url, user_agent = "Class Project")
  session

# get prognosticators
# ---------------------

  url <- "https://countdowntogroundhogday.com/groundhogs-from-around-the-world"

  session <- bow(url, user_agent = "Class Project")

  prognosticators_node <- scrape(session) %>%
    html_nodes("#forecaster-table")
read_sheet()
  prognosticators <- prognosticators_node %>%
    html_table() %>%
    flatten_df()

# get classifications
# ---------------------
  prognosticators_type <- read_sheet("https://docs.google.com/spreadsheets/d/1egRcFIW06Fcmr-6xV4B9Fc14OPvrwRB0t6bG68uWG5c/edit?usp=sharing",
                                     sheet = "prognosticator classification")
# wrangle
# ---------------------
  prognosticators <- prognosticators %>%
    rename(prognosticator_name = Name,
           prognosticator_type_orig = `Forecaster Type`,
           prognosticator_city = Location) %>%
  # get city coords
    geocode(prognosticator_city) %>%
    rename(prognosticator_lat = lat,
           prognosticator_long = long) %>%
  # classify prognosticators
    left_join(select(prognosticators_type, -prognosticator_type),
              by = "prognosticator_name")

usethis::use_data(prognosticators, overwrite = TRUE)
