#!/usr/bin/env Rscript

# Aggregate the large NFIP policy transaction file in chunks. This avoids
# loading the 30 GB CSV into memory and does not require a database package.

if (!requireNamespace("data.table", quietly = TRUE)) stop("Install required R package: data.table")
args <- commandArgs(trailingOnly = FALSE)
script <- sub("^--file=", "", args[grepl("^--file=", args)][1])
root <- normalizePath(file.path(dirname(script), ".."))
raw <- file.path(root, "data", "raw")
derived <- file.path(root, "data", "derived")
dir.create(derived, recursive = TRUE, showWarnings = FALSE)
policies <- file.path(raw, "FimaNfipPoliciesV2.csv")
if (!file.exists(policies)) stop("Missing raw policy file: ", policies)

read_in_chunks <- function(path, columns, process, chunk_size = 1000000L) {
    header <- data.table::fread(path, nrows = 0L, showProgress = FALSE)
    indices <- match(columns, names(header))
    if (anyNA(indices)) stop("Missing policy columns: ", paste(columns[is.na(indices)], collapse = ", "))
    skip <- 0
    repeat {
        # fread() errors rather than returning an empty table when skip lands
        # exactly at EOF, which happens when the file has an exact number of
        # chunks. Treat only that condition as normal termination.
        chunk <- tryCatch(
            data.table::fread(path, skip = skip, nrows = chunk_size,
                header = skip == 0, select = if (skip == 0) columns else indices,
                showProgress = FALSE),
            error = function(error) {
                if (grepl("input only has", conditionMessage(error), fixed = TRUE)) {
                    return(NULL)
                }
                stop(error)
            }
        )
        if (is.null(chunk) || nrow(chunk) == 0L) break
        if (skip != 0) data.table::setnames(chunk, names(chunk), columns)
        process(chunk)
        skip <- skip + nrow(chunk) + if (skip == 0) 1 else 0
    }
}

columns <- c("propertyState", "countyCode", "policyEffectiveDate", "originalNBDate",
    "cancellationDateOfFloodPolicy", "policyCount", "totalInsurancePremiumOfThePolicy",
    "totalBuildingInsuranceCoverage", "totalContentsInsuranceCoverage")
parts <- list()
part_index <- 0L
process <- function(chunk) {
    data.table::setDT(chunk)
    # fread() may infer ISO timestamps as POSIXct. Normalize all date fields
    # to character dates before comparing them or checking for empty values.
    chunk[, effective_date := substr(as.character(policyEffectiveDate), 1L, 10L)]
    chunk[, original_nb_date := substr(as.character(originalNBDate), 1L, 10L)]
    chunk[, cancellation_date := as.character(cancellationDateOfFloodPolicy)]
    chunk[, month := data.table::as.IDate(effective_date)]
    chunk[, county_fips := sprintf("%05d", as.integer(countyCode))]
    chunk[, policy_count_numeric := suppressWarnings(as.numeric(policyCount))]
    chunk[, premium_numeric := suppressWarnings(as.numeric(totalInsurancePremiumOfThePolicy))]
    chunk <- chunk[!is.na(month)]
    if (nrow(chunk) == 0L) return(invisible(NULL))
    part_index <<- part_index + 1L
    parts[[part_index]] <<- chunk[, .(
        policy_records = .N,
        policy_count = sum(policy_count_numeric, na.rm = TRUE),
        new_policy_records = sum(original_nb_date == effective_date, na.rm = TRUE),
        cancellation_records = sum(!is.na(cancellation_date) & cancellation_date != "", na.rm = TRUE),
        premium_sum = sum(premium_numeric, na.rm = TRUE), premium_n = sum(!is.na(premium_numeric)),
        building_coverage_sum = sum(as.numeric(totalBuildingInsuranceCoverage), na.rm = TRUE),
        contents_coverage_sum = sum(as.numeric(totalContentsInsuranceCoverage), na.rm = TRUE),
        coverage_n = sum(!is.na(as.numeric(totalBuildingInsuranceCoverage)))
    ), by = .(state = propertyState, county_fips, month)]
}
read_in_chunks(policies, columns, process)
result <- data.table::rbindlist(parts)[, .(
    policy_records = sum(policy_records), policy_count = sum(policy_count),
    new_policy_records = sum(new_policy_records), cancellation_records = sum(cancellation_records),
    mean_premium = sum(premium_sum) / sum(premium_n),
    mean_building_coverage = sum(building_coverage_sum) / sum(coverage_n),
    mean_contents_coverage = sum(contents_coverage_sum) / sum(coverage_n)
), by = .(state, county_fips, month)]
data.table::setorder(result, state, county_fips, month)
data.table::fwrite(result, file.path(derived, "policy_county_month.csv"))
message("Wrote policy_county_month.csv")
