#!/usr/bin/env Rscript

# Translate log event-study coefficients into implied percentage changes.
#
# For a coefficient beta from a log outcome, the corresponding percentage
# change on the transformed outcome scale is 100 * (exp(beta) - 1). The script
# preserves each input table and appends translated point estimates and, when
# available, translated confidence-interval endpoints.

args <- commandArgs(trailingOnly = FALSE)
script_argument <- args[grepl("^--file=", args)]
if (length(script_argument) == 0L) stop("Could not determine script location")
script <- sub("^--file=", "", script_argument[1L])
root <- normalizePath(file.path(dirname(script), ".."))

model_dir <- file.path(root, "data", "derived", "model")
translate_file <- function(input_file, output_file) {
    if (!file.exists(input_file)) stop("Missing model output: ", input_file)

    results <- utils::read.csv(input_file, stringsAsFactors = FALSE,
        check.names = FALSE)
    if (!"estimate" %in% names(results)) {
        stop("The model output must contain an 'estimate' column: ", input_file)
    }

    results$implied_percent_change <- 100 * (exp(results$estimate) - 1)
    if (all(c("ci_lower", "ci_upper") %in% names(results))) {
        results$implied_percent_change_ci_lower <-
            100 * (exp(results$ci_lower) - 1)
        results$implied_percent_change_ci_upper <-
            100 * (exp(results$ci_upper) - 1)
    }
    utils::write.csv(results, output_file, row.names = FALSE)
    message("Wrote ", output_file)
}

translate_file(
    file.path(model_dir, "event_study_coefficients.csv"),
    file.path(model_dir, "event_study_coefficients_translated.csv")
)
translate_file(
    file.path(model_dir, "event_study_effects.csv"),
    file.path(model_dir, "event_study_effects_translated.csv")
)
