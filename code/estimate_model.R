#!/usr/bin/env Rscript

# Estimate the annual direct- and neighbor-flood event study.
#
# The monthly analysis panel is collapsed to a balanced Florida county-year
# panel. Floods are represented as event years, and the event-time regressors
# count pre- and post-Risk-Rating-2.0 flood events separately. Counting events
# rather than retaining only the first event preserves overlapping flood
# responses in the short event window.
#
# The primary outcome is log1p(new_policy_records). In the policy derivation,
# new_policy_records counts policy records for which originalNBDate equals
# policyEffectiveDate. The annual outcome is therefore log(1 + the annual
# count of these new policy records), not a count of unique households.

args <- commandArgs(trailingOnly = FALSE)
script_argument <- args[grepl("^--file=", args)]
if (length(script_argument) == 0L) stop("Could not determine script location")
script <- sub("^--file=", "", script_argument[1L])
root <- normalizePath(file.path(dirname(script), ".."))

required_packages <- c("data.table", "fixest")
missing_packages <- required_packages[!vapply(required_packages,
    requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_packages) > 0L) {
    stop("Install required R packages in the project renv environment: ",
        paste(missing_packages, collapse = ", "))
}

derived <- file.path(root, "data", "derived")
input_file <- file.path(derived, "analysis_panel.csv")
output_dir <- file.path(derived, "model")
if (!file.exists(input_file)) stop("Missing analysis panel: ", input_file)
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

start_year <- 2015L
end_year <- 2024L
transition_year <- 2021L
event_min <- -3L
event_max <- 3L
event_times <- setdiff(event_min:event_max, -1L)
event_label <- function(event_time) {
    if (event_time < 0L) paste0("m", abs(event_time)) else paste0("p", event_time)
}

first_nonmissing <- function(values) {
    values <- values[!is.na(values)]
    if (length(values) == 0L) return(NA_character_)
    as.character(values[1L])
}

first_nonmissing_numeric <- function(values) {
    values <- values[!is.na(values)]
    if (length(values) == 0L) return(NA_real_)
    as.numeric(values[1L])
}

annual_any <- function(values) {
    values <- values[!is.na(values)]
    if (length(values) == 0L) return(0L)
    as.integer(any(values > 0))
}

write_csv_with_message <- function(data, path) {
    data.table::fwrite(data, path)
    message("Wrote ", path)
}

panel_columns <- c("county_fips", "year", "state", "policy_count",
    "new_policy_records", "policy_records", "flood_declaration",
    "neighbor_flood", "population", "housing_units", "median_income")
panel <- data.table::fread(input_file, select = panel_columns,
    showProgress = FALSE)
panel[, county_fips := trimws(as.character(county_fips))]
panel[, year := as.integer(year)]
panel <- panel[grepl("^12[0-9]{3}$", county_fips) &
    year >= start_year & year <= end_year]
if (nrow(panel) == 0L) stop("No Florida observations in the requested years")

annual <- panel[, .(
    state = first_nonmissing(state),
    policy_count = sum(policy_count, na.rm = TRUE),
    new_policy_records = sum(new_policy_records, na.rm = TRUE),
    policy_records = sum(policy_records, na.rm = TRUE),
    direct_flood = annual_any(flood_declaration),
    neighbor_flood = annual_any(neighbor_flood),
    population = first_nonmissing_numeric(population),
    housing_units = first_nonmissing_numeric(housing_units),
    median_income = first_nonmissing_numeric(median_income)
), by = .(county_fips, year)]

# Complete the county-year panel. Missing policy observations represent zero
# recorded policies after the county and year have entered the analysis panel.
counties <- unique(annual[, .(county_fips, state)])
years <- data.table::data.table(year = start_year:end_year)
panel_year <- data.table::CJ(county_fips = counties$county_fips,
    year = years$year, unique = TRUE)
panel_year <- merge(panel_year, counties, by = "county_fips", all.x = TRUE)
panel_year <- merge(panel_year, annual, by = c("county_fips", "year"), all.x = TRUE)
for (column in c("policy_count", "new_policy_records", "policy_records",
    "direct_flood", "neighbor_flood")) {
    panel_year[is.na(get(column)), (column) := 0]
}

# Add event-time counts. A county with two qualifying flood event years has a
# value of two in the relevant event-time regressor, preserving overlapping
# events rather than silently choosing one event.
add_event_regressors <- function(data, event_data, prefix, cohort_name) {
    if (nrow(event_data) == 0L) {
        for (event_time in event_times) {
            data[, paste0(prefix, "_", cohort_name, "_", event_label(event_time)) := 0]
        }
        return(data)
    }
    for (event_time in event_times) {
        column <- paste0(prefix, "_", cohort_name, "_", event_label(event_time))
        values <- event_data[, .(county_fips, year = event_year + event_time,
            value = 1L)][, .(value = sum(value)), by = .(county_fips, year)]
        data <- merge(data, values, by = c("county_fips", "year"), all.x = TRUE)
        data[is.na(value), value := 0L]
        data.table::setnames(data, "value", column)
    }
    data
}

direct_events <- panel_year[direct_flood == 1L,
    .(county_fips, event_year = year)]
neighbor_events <- panel_year[neighbor_flood == 1L,
    .(county_fips, event_year = year)]
direct_pre <- direct_events[event_year <= transition_year]
direct_post <- direct_events[event_year > transition_year]
neighbor_pre <- neighbor_events[event_year <= transition_year]
neighbor_post <- neighbor_events[event_year > transition_year]

panel_year <- add_event_regressors(panel_year, direct_pre, "direct", "pre")
panel_year <- add_event_regressors(panel_year, direct_post, "direct", "post")
panel_year <- add_event_regressors(panel_year, neighbor_pre, "neighbor", "pre")
panel_year <- add_event_regressors(panel_year, neighbor_post, "neighbor", "post")

panel_year[, post_rr20 := as.integer(year >= 2022L)]
panel_year[, log1p_policy_count := log1p(policy_count)]
panel_year[, log1p_new_policy_records := log1p(new_policy_records)]
panel_year[, log1p_policy_records := log1p(policy_records)]

# Save the exact annual regression data for reproducibility and diagnostics.
data.table::setorder(panel_year, county_fips, year)
write_csv_with_message(panel_year,
    file.path(output_dir, "annual_event_study_panel.csv"))

regressor_names <- unlist(lapply(c("direct", "neighbor"), function(prefix) {
    unlist(lapply(c("pre", "post"), function(cohort) {
        paste0(prefix, "_", cohort, "_", vapply(event_times, event_label, character(1)))
    }))
}))
regressor_formula <- paste(regressor_names, collapse = " + ")
# Estimate the primary new-policy outcome first, followed by robustness
# outcomes based on policy counts and all policy records.
outcomes <- c("log1p_new_policy_records", "log1p_policy_count",
    "log1p_policy_records")

coefficient_parts <- list()
fit_parts <- list()
model_summaries <- list()
for (outcome in outcomes) {
    formula <- stats::as.formula(paste0(outcome, " ~ ", regressor_formula,
        " | county_fips + year"))
    model <- fixest::feols(formula, data = panel_year,
        cluster = ~county_fips, warn = FALSE)
    table <- as.data.frame(fixest::coeftable(model))
    table$term <- rownames(table)
    rownames(table) <- NULL
    names(table)[seq_len(min(4L, ncol(table)))] <- c("estimate", "std_error",
        "statistic", "p_value")[seq_len(min(4L, ncol(table)))]
    table$outcome <- outcome
    coefficient_parts[[outcome]] <- data.table::as.data.table(table)
    fit_parts[[outcome]] <- data.table::data.table(
        outcome = outcome,
        observations = stats::nobs(model),
        within_r2 = as.numeric(fixest::fitstat(model, "wr2")),
        overall_r2 = as.numeric(fixest::fitstat(model, "r2"))
    )
    model_summaries[[outcome]] <- list(model = model, coefficients = table)
}

coefficients <- data.table::rbindlist(coefficient_parts, fill = TRUE)
data.table::setcolorder(coefficients,
    c("outcome", "term", setdiff(names(coefficients), c("outcome", "term"))))
write_csv_with_message(coefficients,
    file.path(output_dir, "event_study_coefficients.csv"))
write_csv_with_message(data.table::rbindlist(fit_parts),
    file.path(output_dir, "event_study_fit_statistics.csv"))

# Print a compact result summary for interactive runs and reproducibility logs.
message("\nAnnual flood event-study summary")
message("Sample: ", nrow(panel_year), " county-year observations across ",
    data.table::uniqueN(panel_year$county_fips), " Florida counties")
message("Flood event years: direct pre-RR2.0 = ", nrow(direct_pre),
    "; direct post-RR2.0 = ", nrow(direct_post),
    "; neighbor pre-RR2.0 = ", nrow(neighbor_pre),
    "; neighbor post-RR2.0 = ", nrow(neighbor_post))
for (outcome in outcomes) {
    fit <- fit_parts[[outcome]]
    message("\nOutcome: ", outcome,
        " | N = ", fit$observations,
        " | within R2 = ", formatC(fit$within_r2, digits = 4, format = "f"),
        " | overall R2 = ", formatC(fit$overall_r2, digits = 4, format = "f"))
    visible <- model_summaries[[outcome]]$coefficients[
        grepl("^(direct|neighbor)_", model_summaries[[outcome]]$coefficients$term),
        c("term", "estimate", "std_error", "p_value"), drop = FALSE]
    print(visible, row.names = FALSE)
}
message("Completed annual flood event-study models")
