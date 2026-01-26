library(rvest)
library(polite)
library(tidyverse)
library(tidygeocoder)

# check permissions
# ---------------------
  url <- "https://countdowntogroundhogday.com/past-predictions/1887"
  session <- bow(url, user_agent = "Class Project")
  session

# get prognosticators
# ---------------------

  url <- "https://countdowntogroundhogday.com/forecasters/showall"

  session <- bow(url, user_agent = "Class Project")

  page <- scrape(session)

  # Extract table rows
  rows <- page %>% html_nodes("table tr")

  # Parse each row to get slug from link
  prognosticators <- map_dfr(rows[-1], function(row) {
    cells <- row %>% html_nodes("td")
    if (length(cells) < 4) return(NULL)

    # Get the link href to extract slug
    name_link <- cells[1] %>% html_node("a") %>% html_attr("href")
    slug <- if (!is.na(name_link)) trimws(basename(name_link)) else ""

    tibble(
      Name = cells[1] %>% html_text(trim = TRUE),
      slug = slug,
      `Forecaster Type` = cells[2] %>% html_text(trim = TRUE),
      Location = cells[3] %>% html_text(trim = TRUE),
      `Last Prediction` = cells[4] %>% html_text(trim = TRUE)
    )
  })

  # Separate name and status
  prognosticators <- prognosticators %>%
    separate(Name, into = c("Name", "Status"),
             sep = "\\s*\\(\\s*", extra = "merge", fill = "right") %>%
    mutate(Status = sub("\\)", "", Status)) %>%
    mutate(Status = case_when(
      is.na(Status) ~ "Active",
      TRUE ~ Status))

  # Clean up whitespace in locations (some have newlines, extra spaces)
  prognosticators <- prognosticators %>%
    mutate(Location = str_replace_all(Location, "[\r\n]+", " ")) %>%
    mutate(Location = str_replace_all(Location, "\\s+,", ",")) %>%
    mutate(Location = str_squish(Location))

  # Deduplicate by slug (unique identifier)
  prognosticators <- prognosticators %>%
    filter(slug != "") %>%
    distinct(slug, .keep_all = TRUE)

  message(sprintf("Scraped %d unique prognosticators", nrow(prognosticators)))

# get classifications from local CSV (with slug-based IDs)
# ---------------------
  prognosticators_type <- read_csv("prognosticator_classification.csv",
                                    show_col_types = FALSE)

  message(sprintf("Classification file: %d entries", nrow(prognosticators_type)))

# wrangle
# ---------------------
  prognosticators <- prognosticators %>%
    rename(prognosticator_name = Name,
           prognosticator_slug = slug,
           prognosticator_type_orig = `Forecaster Type`,
           prognosticator_city = Location) %>%
  # get city coords
    geocode(prognosticator_city) %>%
    rename(prognosticator_lat = lat,
           prognosticator_long = long) %>%
  # classify prognosticators - join on SLUG (unique identifier)
    left_join(
      prognosticators_type %>%
        select(-prognosticator_name, -location),
      by = c("prognosticator_slug")
    )

  # Check for missing classifications
  missing <- prognosticators %>% filter(is.na(prognosticator_type))
  if (nrow(missing) > 0) {
    message(sprintf("WARNING: %d prognosticators missing classification:", nrow(missing)))
    message(paste("  -", missing$prognosticator_slug, collapse = "\n"))
  }

  message(sprintf("Final prognosticators dataset: %d rows", nrow(prognosticators)))

usethis::use_data(prognosticators, overwrite = TRUE)
