#!/usr/bin/env Rscript

# Aggregate FEMA declarations and NFIP claims to county-month observations
# using chunked data.table reads rather than a database engine.

if (!requireNamespace("data.table", quietly = TRUE)) stop("Install required R package: data.table")
args <- commandArgs(trailingOnly = FALSE)
script <- sub("^--file=", "", args[grepl("^--file=", args)][1])
root <- normalizePath(file.path(dirname(script), ".."))
raw <- file.path(root, "data", "raw")
derived <- file.path(root, "data", "derived")
dir.create(derived, recursive = TRUE, showWarnings = FALSE)
declarations <- file.path(raw, "DisasterDeclarationsSummariesV2.csv")
claims <- file.path(raw, "NfipClaimsV3.csv")
if (!file.exists(declarations)) stop("Missing declarations file: ", declarations)
if (!file.exists(claims)) stop("Missing claims file: ", claims)

declarations_data <- data.table::fread(declarations, showProgress = TRUE)
declarations_data[, county_fips := sprintf("%02d%03d", as.integer(fipsStateCode), as.integer(fipsCountyCode))]
declarations_data[, month := data.table::as.IDate(paste0(substr(incidentBeginDate, 1L, 7L), "-01"))]
declarations_data[, flood_declaration := as.integer(tolower(incidentType) %in%
    c("flood", "hurricane", "coastal storm", "severe storm"))]
declaration_panel <- declarations_data[!is.na(month), .(
    declaration_count = data.table::uniqueN(femaDeclarationString),
    flood_declaration = max(flood_declaration, na.rm = TRUE),
    river_or_flash_flood_declaration = as.integer(any(tolower(incidentType) == "flood"))
), by = .(county_fips, month)]

columns <- c("dateOfLoss", "censusGeoid", "buildingDamageAmount", "contentsDamageAmount",
    "netBuildingPaymentAmount", "netContentsPaymentAmount", "waterDepth")
header <- data.table::fread(claims, nrows = 0L, showProgress = FALSE)
indices <- match(columns, names(header))
if (anyNA(indices)) stop("Missing claims columns: ", paste(columns[is.na(indices)], collapse = ", "))
parts <- list()
part_index <- 0L
skip <- 0
repeat {
    # fread() errors rather than returning an empty table when skip lands
    # exactly at EOF. Treat only that condition as normal termination.
    chunk <- tryCatch(
        data.table::fread(claims, skip = skip, nrows = 1000000L,
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
    rows_read <- nrow(chunk)
    if (skip != 0) data.table::setnames(chunk, names(chunk), columns)
    chunk[, month := data.table::as.IDate(paste0(substr(dateOfLoss, 1L, 7L), "-01"))]
    chunk[, county_fips := substr(as.character(censusGeoid), 1L, 5L)]
    chunk <- chunk[!is.na(month) & nchar(county_fips) == 5L]
    if (nrow(chunk) > 0L) {
        part_index <- part_index + 1L
        parts[[part_index]] <- chunk[, .(
            claim_count = .N,
            reported_damage = sum(as.numeric(buildingDamageAmount), na.rm = TRUE) + sum(as.numeric(contentsDamageAmount), na.rm = TRUE),
            net_claim_payment = sum(as.numeric(netBuildingPaymentAmount), na.rm = TRUE) + sum(as.numeric(netContentsPaymentAmount), na.rm = TRUE),
            water_depth_sum = sum(as.numeric(waterDepth), na.rm = TRUE),
            water_depth_n = sum(!is.na(as.numeric(waterDepth)))
        ), by = .(county_fips, month)]
    }
    skip <- skip + rows_read + if (skip == 0) 1 else 0
}
claim_panel <- data.table::rbindlist(parts)[, .(
    claim_count = sum(claim_count), reported_damage = sum(reported_damage),
    net_claim_payment = sum(net_claim_payment), mean_water_depth = sum(water_depth_sum) / sum(water_depth_n)
), by = .(county_fips, month)]
result <- merge(declaration_panel, claim_panel, by = c("county_fips", "month"), all = TRUE)
for (name in c("declaration_count", "flood_declaration", "river_or_flash_flood_declaration", "claim_count", "reported_damage", "net_claim_payment")) {
    result[is.na(get(name)), (name) := 0]
}
data.table::setorder(result, county_fips, month)
data.table::fwrite(result, file.path(derived, "flood_county_month.csv"))
message("Wrote flood_county_month.csv")
