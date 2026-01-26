# test-data-integrity.R
# Tests for data loading and basic structure

test_that("prognosticators dataset loads and has required columns", {
  expect_true(exists("prognosticators"))
  expect_s3_class(prognosticators, "data.frame")

  required_cols <- c("prognosticator_slug", "prognosticator_name",
                     "prognosticator_city", "prognosticator_lat",
                     "prognosticator_long")
  expect_true(all(required_cols %in% names(prognosticators)))
})

test_that("prognosticators has unique slugs", {
  expect_equal(
    nrow(prognosticators),
    length(unique(prognosticators$prognosticator_slug))
  )
})

test_that("predictions dataset loads and has required columns", {
  expect_true(exists("predictions"))
  expect_s3_class(predictions, "data.frame")

  required_cols <- c("prognosticator_slug", "year", "prediction",
                     "predict_early_spring")
  expect_true(all(required_cols %in% names(predictions)))
})

test_that("class_def1 dataset loads and has required columns", {
  expect_true(exists("class_def1"))
  expect_s3_class(class_def1, "data.frame")

  required_cols <- c("prognosticator_city", "year", "class")
  expect_true(all(required_cols %in% names(class_def1)))
})

test_that("class_def1_data dataset loads and has required columns", {
  expect_true(exists("class_def1_data"))
  expect_s3_class(class_def1_data, "data.frame")

  required_cols <- c("prognosticator_city", "year", "month",
                     "tmax_monthly_mean_f", "tmax_monthly_mean_f_15y", "class")
  expect_true(all(required_cols %in% names(class_def1_data)))
})

test_that("datasets have reasonable row counts", {
  expect_gt(nrow(prognosticators), 100)  # Should have 300+ prognosticators
  expect_gt(nrow(predictions), 1000)     # Should have 2000+ predictions
  expect_gt(nrow(class_def1), 5000)      # Should have many city-year combos
  expect_gt(nrow(class_def1_data), 10000) # Should have monthly data
})
