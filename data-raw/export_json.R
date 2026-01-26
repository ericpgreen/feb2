# export_json.R
# Export feb2 data as JSON for use by byteburrower and other JS applications

library(jsonlite)

message("Loading feb2 data...")
load("../data/prognosticators.rda")
load("../data/predictions.rda")

# Create export directory
export_dir <- "../inst/json"
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
  "Year",
  "prediction",
  "predict_early_spring"
)]
names(predictions_export)[3] <- "year"  # lowercase for JS convention

message(sprintf("Exporting %d predictions...", nrow(predictions_export)))
write_json(predictions_export,
           file.path(export_dir, "predictions.json"),
           pretty = TRUE,
           auto_unbox = TRUE,
           na = "null")

# Calculate and export accuracy stats per prognosticator
# This requires class_def1 data - check if it exists
if (file.exists("../data/class_def1.rda")) {
  load("../data/class_def1.rda")

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

message(sprintf("\nJSON files exported to %s", export_dir))
message("Files created:")
message("  - prognosticators.json")
message("  - predictions.json")
if (file.exists("../data/class_def1.rda")) {
  message("  - accuracy.json")
}
