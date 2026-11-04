#!/usr/bin/env Rscript

# Translate log1p event-study coefficients into implied percentage changes.
#
# For a coefficient beta from a log1p outcome, the corresponding percentage
# change on the transformed outcome scale is 100 * (exp(beta) - 1). The script
# preserves the original coefficient table and appends this translated value.

args <- commandArgs(trailingOnly = FALSE)
script_argument <- args[grepl("^--file=", args)]
if (length(script_argument) == 0L) stop("Could not determine script location")
script <- sub("^--file=", "", script_argument[1L])
root <- normalizePath(file.path(dirname(script), ".."))

model_dir <- file.path(root, "data", "derived", "model")
input_file <- file.path(model_dir, "event_study_coefficients.csv")
output_file <- file.path(model_dir,
    "event_study_coefficients_translated.csv")

if (!file.exists(input_file)) stop("Missing coefficient file: ", input_file)

coefficients <- utils::read.csv(input_file, stringsAsFactors = FALSE,
    check.names = FALSE)
if (!"estimate" %in% names(coefficients)) {
    stop("The coefficient file must contain an 'estimate' column")
}

coefficients$implied_percent_change <- 100 * (exp(coefficients$estimate) - 1)
utils::write.csv(coefficients, output_file, row.names = FALSE)
message("Wrote ", output_file)
