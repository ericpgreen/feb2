# export_json.R
# Export feb2 data as JSON for use by byteburrower and other JS applications
#
# Usage: Run from feb2 root directory:
#   source("data-raw/export_json.R")

library(jsonlite)

# Determine base path (works whether run from root or data-raw)
if (basename(getwd()) == "data-raw") {
  base_path <- ".."
} else {
  base_path <- "."
}

message("Loading feb2 data...")
load(file.path(base_path, "data/prognosticators.rda"))
load(file.path(base_path, "data/predictions.rda"))

# Create export directory
export_dir <- file.path(base_path, "inst/json")
if (!dir.exists(export_dir)) {
  dir.create(export_dir, recursive = TRUE)
}

# Export prognosticators with key fields for web use
prognosticators_export <- prognosticators[, c(
  "prognosticator_name",
  "prognosticator_slug",
  "prognosticator_city",
  "prognosticator_lat",
  "prognosticator_long",
  "prognosticator_type",
  "prognosticator_status",
  "prognosticator_creature",
  "Status"
)]

message(sprintf("Exporting %d prognosticators...", nrow(prognosticators_export)))
write_json(prognosticators_export,
           file.path(export_dir, "prognosticators.json"),
           pretty = TRUE,
           auto_unbox = TRUE,
           na = "null")

# Export predictions
predictions_export <- predictions[, c(
  "prognosticator_name",
  "prognosticator_slug",
  "year",
  "prediction",
  "predict_early_spring"
)]

message(sprintf("Exporting %d predictions...", nrow(predictions_export)))
write_json(predictions_export,
           file.path(export_dir, "predictions.json"),
           pretty = TRUE,
           auto_unbox = TRUE,
           na = "null")

# Calculate and export accuracy stats per prognosticator
# This requires class_def1 data - check if it exists
class_def1_path <- file.path(base_path, "data/class_def1.rda")
if (file.exists(class_def1_path)) {
  load(class_def1_path)

  # Join predictions with classifications
  library(dplyr)

  # Get prognosticator locations
  prog_locations <- prognosticators[, c("prognosticator_slug", "prognosticator_city")]

  # Join predictions with locations, then with classifications
  accuracy_data <- predictions_export %>%
    left_join(prog_locations, by = "prognosticator_slug") %>%
    left_join(class_def1, by = c("prognosticator_city", "year")) %>%
    filter(!is.na(prediction) & !is.na(class)) %>%
    mutate(
      predicted_early = prediction == "Early Spring",
      actual_early = class == "early spring",
      correct = predicted_early == actual_early
    ) %>%
    group_by(prognosticator_slug, prognosticator_name) %>%
    summarise(
      total_predictions = n(),
      correct_predictions = sum(correct),
      accuracy = round(correct_predictions / total_predictions * 100, 1),
      .groups = "drop"
    ) %>%
    filter(total_predictions >= 5)  # Only include those with 5+ predictions

  message(sprintf("Exporting accuracy stats for %d prognosticators...", nrow(accuracy_data)))
  write_json(accuracy_data,
             file.path(export_dir, "accuracy.json"),
             pretty = TRUE,
             auto_unbox = TRUE)
} else {
  message("class_def1.rda not found - skipping accuracy export")
}

# Export class_def1 (actual outcomes by city/year)
if (file.exists(class_def1_path)) {
  message(sprintf("Exporting %d city-year classifications...", nrow(class_def1)))
  write_json(class_def1,
             file.path(export_dir, "class_def1.json"),
             pretty = TRUE,
             auto_unbox = TRUE,
             na = "null")
}

message(sprintf("\nJSON files exported to %s", export_dir))
message("Files created:")
message("  - prognosticators.json")
message("  - predictions.json")
if (file.exists(class_def1_path)) {
  message("  - accuracy.json")
  message("  - class_def1.json")
}
