# test-classification.R
# Tests for the def1 classification logic

test_that("classification logic follows def1 rules", {
  # def1: Early Spring if Feb OR March temp > 15-year rolling average

  # Get data with valid rolling averages
  valid_data <- class_def1_data[!is.na(class_def1_data$tmax_monthly_mean_f) &
                                  !is.na(class_def1_data$tmax_monthly_mean_f_15y), ]

  # For each city-year, check if classification is correct
  city_years <- unique(valid_data[, c("prognosticator_city", "year")])

  # Sample 100 random city-years to test
  set.seed(42)
  sample_idx <- sample(nrow(city_years), min(100, nrow(city_years)))

  for (i in sample_idx) {
    cy <- city_years[i, ]
    cy_data <- valid_data[valid_data$prognosticator_city == cy$prognosticator_city &
                            valid_data$year == cy$year, ]

    if (nrow(cy_data) == 0) next

    # Check if any month is above rolling average
    above_avg <- any(cy_data$tmax_monthly_mean_f > cy_data$tmax_monthly_mean_f_15y,
                     na.rm = TRUE)

    expected_class <- if (above_avg) "Early Spring" else "Long Winter"
    actual_class <- unique(cy_data$class)

    if (length(actual_class) == 1 && !is.na(actual_class)) {
      expect_equal(actual_class, expected_class,
                   info = paste("City:", cy$prognosticator_city, "Year:", cy$year))
    }
  }
})

test_that("early spring vs long winter ratio is reasonable", {
  # Climate-wise, we'd expect roughly 50-50 split over long periods
  # But with climate change, might skew toward more early springs recently

  class_counts <- table(class_def1$class)

  # Neither class should be less than 20% of total
  total <- sum(class_counts)
  expect_gt(class_counts["Early Spring"] / total, 0.2)
  expect_gt(class_counts["Long Winter"] / total, 0.2)
})

test_that("recent years show climate warming trend",
{
  # In recent decades, we'd expect more early springs due to climate change
  recent <- class_def1[class_def1$year >= 2010 & !is.na(class_def1$class), ]
  early <- class_def1[class_def1$year >= 1960 & class_def1$year < 1990 &
                        !is.na(class_def1$class), ]

  recent_es_pct <- mean(recent$class == "Early Spring")
  early_es_pct <- mean(early$class == "Early Spring")

  # Recent period should have higher early spring percentage
 expect_gt(recent_es_pct, early_es_pct)
})

test_that("Punxsutawney has pre-1940 data from GHCND", {
  punx_data <- class_def1_data[class_def1_data$prognosticator_city == "Punxsutawney, PA", ]

  # Should have data before 1940 (from GHCND)
  pre_1940 <- punx_data[punx_data$year < 1940, ]
  expect_gt(nrow(pre_1940), 0)

  # Earliest should be around 1890s
  expect_lte(min(punx_data$year), 1900)
})
