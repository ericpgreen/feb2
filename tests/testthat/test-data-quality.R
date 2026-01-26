# test-data-quality.R
# Tests for data quality and valid values

test_that("prognosticator coordinates are valid", {
  valid_coords <- prognosticators[!is.na(prognosticators$prognosticator_lat) &
                                   !is.na(prognosticators$prognosticator_long), ]

  # Latitude should be between -90 and 90

  expect_true(all(valid_coords$prognosticator_lat >= -90 &
                    valid_coords$prognosticator_lat <= 90))


  # Longitude should be between -180 and 180
  expect_true(all(valid_coords$prognosticator_long >= -180 &
                    valid_coords$prognosticator_long <= 180))

  # Most prognosticators should be in North America (lat 20-70, lon -170 to -50)
  na_progs <- valid_coords[valid_coords$prognosticator_lat >= 20 &
                            valid_coords$prognosticator_lat <= 70 &
                            valid_coords$prognosticator_long >= -170 &
                            valid_coords$prognosticator_long <= -50, ]
  expect_gt(nrow(na_progs) / nrow(valid_coords), 0.8)  # >80% in North America
})

test_that("prediction years are reasonable", {
  expect_true(all(predictions$year >= 1880 & predictions$year <= 2030,
                  na.rm = TRUE))

  # Punxsutawney Phil started in 1887
  expect_true(min(predictions$year, na.rm = TRUE) <= 1890)
})

test_that("predictions have valid values", {
  valid_predictions <- c("Early Spring", "Long Winter", NA)
  expect_true(all(predictions$prediction %in% valid_predictions))

  # predict_early_spring should be 0, 1, or NA
  expect_true(all(predictions$predict_early_spring %in% c(0, 1, NA)))

  # predict_early_spring should match prediction text
  es_match <- predictions$prediction == "Early Spring" &
    predictions$predict_early_spring == 1
  lw_match <- predictions$prediction == "Long Winter" &
    predictions$predict_early_spring == 0
  na_match <- is.na(predictions$prediction) &
    is.na(predictions$predict_early_spring)

  expect_true(all(es_match | lw_match | na_match, na.rm = TRUE))
})

test_that("class_def1 has valid classification values", {
  valid_classes <- c("Early Spring", "Long Winter", NA)
  expect_true(all(class_def1$class %in% valid_classes))
})

test_that("temperature values are in reasonable range", {
  temps <- class_def1_data$tmax_monthly_mean_f[!is.na(class_def1_data$tmax_monthly_mean_f)]

  # February/March daily highs should be between -50°F and 120°F
  expect_true(all(temps >= -50 & temps <= 120))

  # Most should be between 20°F and 80°F
  reasonable_temps <- temps[temps >= 20 & temps <= 80]
  expect_gt(length(reasonable_temps) / length(temps), 0.7)
})

test_that("rolling averages are calculated correctly", {
  # 15-year rolling average should only exist for years with enough history
  has_rolling <- class_def1_data[!is.na(class_def1_data$tmax_monthly_mean_f_15y), ]

  # Punxsutawney has GHCND data from 1887, others start later with Open-Meteo
  expect_true(min(has_rolling$year) <= 1940)  # Should have early data

  # Rolling average should be close to the actual temp (within reason)
  temp_diff <- abs(has_rolling$tmax_monthly_mean_f - has_rolling$tmax_monthly_mean_f_15y)
  expect_true(median(temp_diff, na.rm = TRUE) < 15)  # Median diff < 15°F
})
