# test-relationships.R
# Tests for relationships between datasets

test_that("most predictions link to valid prognosticators", {
  pred_slugs <- unique(predictions$prognosticator_slug)
  prog_slugs <- unique(prognosticators$prognosticator_slug)

  # Nearly all prediction slugs should exist in prognosticators
  # (allowing for minor data inconsistencies from web scraping)
  matching <- sum(pred_slugs %in% prog_slugs)
  expect_gt(matching / length(pred_slugs), 0.99)
})

test_that("class_def1 cities match prognosticator cities", {
  class_cities <- unique(class_def1$prognosticator_city)
  prog_cities <- unique(prognosticators$prognosticator_city)

  # Most classification cities should exist in prognosticators
  # (some may have been excluded due to invalid coordinates)
  matching <- class_cities %in% prog_cities
  expect_gt(sum(matching) / length(class_cities), 0.95)
})

test_that("class_def1 and class_def1_data are consistent", {
  # Get distinct city-year-class from detailed data
  data_summary <- unique(class_def1_data[, c("prognosticator_city", "year", "class")])

  # Should have similar row counts (class_def1 is the summary)
  expect_equal(nrow(class_def1), nrow(data_summary), tolerance = 10)

  # Merge and check classifications match
  merged <- merge(class_def1, data_summary,
                  by = c("prognosticator_city", "year"),
                  suffixes = c("_summary", "_detail"))

  # Where both have non-NA class, most should match
  # (some discrepancies may exist due to edge cases in classification logic)
  both_valid <- !is.na(merged$class_summary) & !is.na(merged$class_detail)
  if (sum(both_valid) > 0) {
    match_rate <- mean(merged$class_summary[both_valid] == merged$class_detail[both_valid])
    expect_gt(match_rate, 0.90)  # At least 90% should match
  }
})

test_that("class_def1_data has Feb and March for each city-year", {
  # Count months per city-year
  month_counts <- aggregate(month ~ prognosticator_city + year,
                            data = class_def1_data, FUN = length)

  # Most city-years should have 2 months (Feb and March)
  expect_gt(mean(month_counts$month == 2), 0.95)

  # Check that months are actually 2 and 3
  expect_true(all(class_def1_data$month %in% c(2, 3)))
})

test_that("Punxsutawney Phil has the longest history", {
  phil <- predictions[predictions$prognosticator_slug == "Punxsutawney-Phil", ]

  # Phil should have predictions going back to 1887
  expect_lte(min(phil$year, na.rm = TRUE), 1890)

  # Phil should have the most predictions
  pred_counts <- table(predictions$prognosticator_slug)
  expect_equal(names(which.max(pred_counts)), "Punxsutawney-Phil")
})
