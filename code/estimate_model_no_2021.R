#!/usr/bin/env Rscript

# Estimate the annual event study after removing calendar-year 2021
# observations from the regression sample.
#
# The shared estimator constructs event-time regressors from the complete
# 2015--2024 annual panel before applying this exclusion. Consequently, floods
# occurring in 2021 remain eligible events and can affect outcomes in retained
# lead and lag years. The wrapper changes only the observation sample and the
# output filename suffix.

args <- commandArgs(trailingOnly = FALSE)
script_argument <- args[grepl("^--file=", args)]
if (length(script_argument) == 0L) stop("Could not determine script location")
script <- normalizePath(sub("^--file=", "", script_argument[1L]))

options(
    event_study.output_suffix = "_no_2021",
    event_study.excluded_observation_years = 2021L
)
source(file.path(dirname(script), "estimate_model.R"), chdir = FALSE)
