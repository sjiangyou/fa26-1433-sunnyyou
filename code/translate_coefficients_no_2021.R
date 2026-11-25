#!/usr/bin/env Rscript

# Translate the no-2021 robustness estimates to implied percentage changes
# using the same implementation as the baseline model.

args <- commandArgs(trailingOnly = FALSE)
script_argument <- args[grepl("^--file=", args)]
if (length(script_argument) == 0L) stop("Could not determine script location")
script <- normalizePath(sub("^--file=", "", script_argument[1L]))

options(event_study.output_suffix = "_no_2021")
source(file.path(dirname(script), "translate_coefficients.R"), chdir = FALSE)
