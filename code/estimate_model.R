#!/usr/bin/env Rscript

# Estimate the annual direct- and neighbor-flood event study.
#
# The monthly analysis panel is collapsed to a balanced county-year panel for
# all geographies represented in the input data. Floods are represented as
# event years. Direct floods and Gallagher-style geographic-neighbor floods are
# mutually exclusive within a county-year: a neighbor event requires at least
# one adjacent flooded county and no direct flood in the focal county. Each
# direct- and neighbor-flood event-time indicator enters once
# as the pre-Risk-Rating-2.0 response and once interacted with an indicator for
# a post-Risk-Rating-2.0 flood cohort. The interaction coefficient is therefore
# the post-minus-pre response difference. Counting events rather than retaining
# only the first event preserves overlapping responses in the event window.
#
# The primary outcome is log(new_policy_records). In the policy derivation,
# new_policy_records counts policy records for which originalNBDate equals
# policyEffectiveDate. The annual outcome is therefore the log of the annual
# count of these new policy records, not a count of unique households. Because
# log(0) is undefined, zero-valued outcomes are represented as NA in the log
# columns and are omitted from the corresponding model by fixest.

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

# Thin wrapper scripts can set these options to run a robustness specification
# without duplicating the model implementation. Event regressors are always
# constructed before observation years are excluded, so floods in an excluded
# observation year can still contribute leads and lags in retained years.
output_suffix <- getOption("event_study.output_suffix", "")
excluded_observation_years <- as.integer(getOption(
    "event_study.excluded_observation_years", integer()))
if (length(output_suffix) != 1L || is.na(output_suffix) ||
        !grepl("^(_[A-Za-z0-9]+)*$", output_suffix)) {
    stop("The event-study output suffix must be empty or use '_label' blocks")
}
artifact_path <- function(stem) {
    file.path(output_dir, paste0(stem, output_suffix, ".csv"))
}

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
    values <- trimws(as.character(values))
    values <- values[!is.na(values) & nzchar(values)]
    if (length(values) == 0L) return(NA_character_)
    values[1L]
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
    "adjacent_flood_count", "population", "housing_units", "median_income")
panel <- data.table::fread(input_file, select = panel_columns,
    showProgress = FALSE)
panel[, county_fips := trimws(as.character(county_fips))]
panel[, year := as.integer(year)]
panel <- panel[grepl("^[0-9]{5}$", county_fips) &
    year >= start_year & year <= end_year]
if (nrow(panel) == 0L) stop("No county observations in the requested years")
# Construct one county lookup row per FIPS code before annual aggregation.
# State labels are intermittently missing in the raw panel, so taking unique
# county-state pairs would create two lookup rows for some counties and would
# duplicate every year when merged into the balanced panel. The state-group
# identifier comes directly from FIPS and is therefore not affected by missing
# state labels. Washington, D.C., and U.S. territories retain their own codes.
counties <- panel[, .(state = first_nonmissing(state)), by = county_fips]
counties[, state_group := substr(county_fips, 1L, 2L)]
if (counties[, anyDuplicated(county_fips)] > 0L) {
    stop("County lookup must contain exactly one row per county FIPS")
}

annual <- panel[, .(
    policy_count = sum(policy_count, na.rm = TRUE),
    new_policy_records = sum(new_policy_records, na.rm = TRUE),
    policy_records = sum(policy_records, na.rm = TRUE),
    direct_flood = annual_any(flood_declaration),
    adjacent_flood = annual_any(adjacent_flood_count),
    population = first_nonmissing_numeric(population),
    housing_units = first_nonmissing_numeric(housing_units),
    median_income = first_nonmissing_numeric(median_income)
), by = .(county_fips, year)]

# Complete the county-year panel from the one-row-per-county lookup. Missing
# policy observations represent zero recorded policies after panel entry.
years <- data.table::data.table(year = start_year:end_year)
panel_year <- data.table::CJ(county_fips = counties$county_fips,
    year = years$year, unique = TRUE)
panel_year <- merge(panel_year, counties, by = "county_fips", all.x = TRUE)
panel_year <- merge(panel_year, annual, by = c("county_fips", "year"), all.x = TRUE)
expected_rows <- nrow(counties) * nrow(years)
duplicate_county_years <- panel_year[, .N, by = .(county_fips, year)][N > 1L, .N]
if (nrow(panel_year) != expected_rows || duplicate_county_years > 0L) {
    stop("Balanced panel must contain exactly one row per county-year; expected ",
        expected_rows, " rows but found ", nrow(panel_year), " rows and ",
        duplicate_county_years, " duplicated county-years")
}
for (column in c("policy_count", "new_policy_records", "policy_records",
    "direct_flood", "adjacent_flood")) {
    panel_year[is.na(get(column)), (column) := 0]
}

# Match Gallagher's geographic-neighbor definition: a county-year is a
# neighbor event only when an adjacent county floods and the focal county does
# not. Keep adjacent_flood in the saved panel to make the exclusion auditable.
panel_year[, neighbor_flood := as.integer(
    adjacent_flood == 1L & direct_flood == 0L)]
if (panel_year[direct_flood == 1L & neighbor_flood == 1L, .N] > 0L) {
    stop("Direct- and neighbor-flood treatments must be mutually exclusive")
}

# Add event-time counts. A county with two qualifying flood event years has a
# value of two in the relevant event-time regressor, preserving overlapping
# events rather than silently choosing one event.
add_event_regressors <- function(data, event_data, prefix) {
    if (nrow(event_data) == 0L) {
        for (event_time in event_times) {
            data[, paste0(prefix, "_", event_label(event_time)) := 0]
        }
        return(data)
    }
    for (event_time in event_times) {
        column <- paste0(prefix, "_", event_label(event_time))
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
direct_post <- direct_events[event_year > transition_year]
neighbor_post <- neighbor_events[event_year > transition_year]

# The all-event columns identify the pre-cohort response. The post-difference
# columns are interactions: they equal the corresponding event-time count only
# for floods whose event year is after the Risk Rating 2.0 transition.
panel_year <- add_event_regressors(panel_year, direct_events, "direct")
panel_year <- add_event_regressors(panel_year, direct_post,
    "direct_post_difference")
panel_year <- add_event_regressors(panel_year, neighbor_events, "neighbor")
panel_year <- add_event_regressors(panel_year, neighbor_post,
    "neighbor_post_difference")

panel_year[, post_rr20 := as.integer(year >= 2022L)]
panel_year[, log1p_policy_count := log1p(policy_count)]
panel_year[, log1p_new_policy_records := log1p(new_policy_records)]
panel_year[, log1p_policy_records := log1p(policy_records)]
panel_year[, log_policy_count := data.table::fifelse(policy_count > 0,
    log(policy_count), NA_real_)]
panel_year[, log_new_policy_records := data.table::fifelse(new_policy_records > 0,
    log(new_policy_records), NA_real_)]
panel_year[, log_policy_records := data.table::fifelse(policy_records > 0,
    log(policy_records), NA_real_)]

# Drop requested observation years only after constructing events from the
# complete annual panel. This distinction is important for the no-2021
# robustness check: a 2021 flood can still affect retained lead/lag years.
estimation_panel <- panel_year[
    !year %in% excluded_observation_years]
if (nrow(estimation_panel) == 0L) {
    stop("Excluding observation years left no observations for estimation")
}
if (length(excluded_observation_years) > 0L &&
        estimation_panel[year %in% excluded_observation_years, .N] > 0L) {
    stop("Excluded observation years remain in the estimation panel")
}

# Save the exact annual regression data for reproducibility and diagnostics.
data.table::setorder(estimation_panel, county_fips, year)
write_csv_with_message(estimation_panel,
    artifact_path("annual_event_study_panel"))

regressor_names <- unlist(lapply(c("direct", "neighbor"), function(prefix) {
    c(paste0(prefix, "_", vapply(event_times, event_label, character(1))),
        paste0(prefix, "_post_difference_",
            vapply(event_times, event_label, character(1))))
}))
regressor_formula <- paste(regressor_names, collapse = " + ")
# Estimate the primary new-policy outcome first, followed by robustness
# outcomes based on policy counts and all policy records. The log1p outcomes
# remain in the saved panel but are not estimated by this specification.
outcomes <- c("log_new_policy_records", "log_policy_count",
    "log_policy_records")

coefficient_parts <- list()
fit_parts <- list()
effect_parts <- list()
model_summaries <- list()

make_effect_row <- function(outcome, exposure, event_time, effect_type,
        term, estimate, variance) {
    std_error <- if (is.na(variance) || variance < 0) NA_real_ else sqrt(variance)
    statistic <- estimate / std_error
    data.table::data.table(
        outcome = outcome,
        exposure = exposure,
        event_time = event_time,
        effect_type = effect_type,
        coefficient_of_interest = effect_type == "post_minus_pre_difference",
        estimable = !is.na(estimate) && !is.na(std_error),
        term = term,
        estimate = estimate,
        std_error = std_error,
        statistic = statistic,
        p_value = 2 * stats::pnorm(-abs(statistic)),
        ci_lower = estimate - stats::qnorm(0.975) * std_error,
        ci_upper = estimate + stats::qnorm(0.975) * std_error
    )
}

build_effect_table <- function(model, outcome) {
    estimates <- stats::coef(model)
    covariance <- stats::vcov(model)
    rows <- list()
    row_index <- 1L
    for (exposure in c("direct", "neighbor")) {
        for (event_time in event_times) {
            label <- event_label(event_time)
            baseline_term <- paste0(exposure, "_", label)
            difference_term <- paste0(exposure, "_post_difference_", label)
            baseline_available <- baseline_term %in% names(estimates)
            difference_available <- difference_term %in% names(estimates)

            baseline_estimate <- if (baseline_available) {
                estimates[[baseline_term]]
            } else NA_real_
            difference_estimate <- if (difference_available) {
                estimates[[difference_term]]
            } else NA_real_
            baseline_variance <- if (baseline_available) {
                covariance[baseline_term, baseline_term]
            } else NA_real_
            difference_variance <- if (difference_available) {
                covariance[difference_term, difference_term]
            } else NA_real_
            post_variance <- if (baseline_available && difference_available) {
                baseline_variance + difference_variance +
                    2 * covariance[baseline_term, difference_term]
            } else NA_real_

            rows[[row_index]] <- make_effect_row(outcome, exposure, event_time,
                "pre_response", baseline_term, baseline_estimate,
                baseline_variance)
            rows[[row_index + 1L]] <- make_effect_row(outcome, exposure,
                event_time, "post_response",
                paste0(baseline_term, " + ", difference_term),
                if (baseline_available && difference_available) {
                    baseline_estimate + difference_estimate
                } else NA_real_, post_variance)
            rows[[row_index + 2L]] <- make_effect_row(outcome, exposure,
                event_time, "post_minus_pre_difference", difference_term,
                difference_estimate, difference_variance)
            row_index <- row_index + 3L
        }
    }
    data.table::rbindlist(rows, fill = TRUE)
}

for (outcome in outcomes) {
    formula <- stats::as.formula(paste0(outcome, " ~ ", regressor_formula,
        " | county_fips + state_group^year"))
    model <- fixest::feols(formula, data = estimation_panel,
        cluster = ~county_fips, warn = FALSE)
    table <- as.data.frame(fixest::coeftable(model))
    table$term <- rownames(table)
    rownames(table) <- NULL
    names(table)[seq_len(min(4L, ncol(table)))] <- c("estimate", "std_error",
        "statistic", "p_value")[seq_len(min(4L, ncol(table)))]
    table$outcome <- outcome
    table$effect_type <- ifelse(grepl("_post_difference_", table$term),
        "post_minus_pre_difference", "pre_response")
    table$coefficient_of_interest <- table$effect_type ==
        "post_minus_pre_difference"
    table$ci_lower <- table$estimate - stats::qnorm(0.975) * table$std_error
    table$ci_upper <- table$estimate + stats::qnorm(0.975) * table$std_error
    coefficient_parts[[outcome]] <- data.table::as.data.table(table)
    effect_parts[[outcome]] <- build_effect_table(model, outcome)
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
    artifact_path("event_study_coefficients"))
effects <- data.table::rbindlist(effect_parts, fill = TRUE)
write_csv_with_message(effects,
    artifact_path("event_study_effects"))
write_csv_with_message(data.table::rbindlist(fit_parts),
    artifact_path("event_study_fit_statistics"))

# Print a compact result summary for interactive runs and reproducibility logs.
message("\nAnnual flood event-study summary")
message("Sample: ", nrow(estimation_panel),
    " county-year observations across ",
    data.table::uniqueN(estimation_panel$county_fips), " counties and ",
    data.table::uniqueN(estimation_panel$state_group), " state-like groups")
if (length(excluded_observation_years) > 0L) {
    message("Excluded observation years: ",
        paste(excluded_observation_years, collapse = ", "),
        "; flood events in those years remain in lead/lag construction")
}
message("Flood event years: direct pre-RR2.0 = ",
    nrow(direct_events) - nrow(direct_post),
    "; direct post-RR2.0 = ", nrow(direct_post),
    "; neighbor pre-RR2.0 = ", nrow(neighbor_events) - nrow(neighbor_post),
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
