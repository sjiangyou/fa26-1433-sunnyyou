#!/usr/bin/env Rscript

# Merge policy, flood, neighbor, and ACS controls into the county-month panel.

if (!requireNamespace("jsonlite", quietly = TRUE)) stop("Install required R package: jsonlite")
args <- commandArgs(trailingOnly = FALSE)
script <- sub("^--file=", "", args[grepl("^--file=", args)][1])
root <- normalizePath(file.path(dirname(script), ".."))
derived <- file.path(root, "data", "derived")
raw_census <- file.path(root, "data", "raw", "census")
required <- c("policy_county_month.csv", "flood_county_month.csv", "county_nearest_neighbors.csv")
missing <- required[!file.exists(file.path(derived, required))]
if (length(missing) > 0) stop("Missing derived inputs: ", paste(missing, collapse = ", "))

policy <- read.csv(file.path(derived, "policy_county_month.csv"), stringsAsFactors = FALSE)
flood <- read.csv(file.path(derived, "flood_county_month.csv"), stringsAsFactors = FALSE)
neighbors <- read.csv(file.path(derived, "county_nearest_neighbors.csv"), stringsAsFactors = FALSE)
policy$month <- as.character(as.Date(policy$month))
flood$month <- as.character(as.Date(flood$month))

panel <- merge(policy, flood, by = c("county_fips", "month"), all = TRUE)
panel <- panel[order(panel$county_fips, panel$month), ]

south_florida <- c("12025", "12011", "12099", "12087", "12086", "12043", "12051", "12061", "12071", "12085", "12093")
panel$south_florida <- as.integer(panel$county_fips %in% south_florida)
panel$post_rr20 <- as.integer(as.Date(panel$month) >= as.Date("2022-01-01"))
panel$premium_change <- ave(panel$mean_premium, panel$county_fips, FUN = function(x) c(NA, diff(x)))
panel$flood_x_post_rr20 <- panel$flood_declaration * panel$post_rr20
neighbor_values <- merge(neighbors,
    flood[, c("county_fips", "month", "flood_declaration", "claim_count")],
    by.x = "neighbor_fips", by.y = "county_fips", all = FALSE)
neighbor_values$neighbor_flood <- neighbor_values$flood_declaration
neighbor_panel <- aggregate(cbind(neighbor_flood, claim_count) ~ county_fips + month,
    data = neighbor_values, FUN = sum, na.rm = TRUE)
names(neighbor_panel)[names(neighbor_panel) == "claim_count"] <- "neighbor_claim_count"
panel <- merge(panel, neighbor_panel, by = c("county_fips", "month"), all.x = TRUE)
panel$neighbor_flood[is.na(panel$neighbor_flood)] <- 0
panel$neighbor_claim_count[is.na(panel$neighbor_claim_count)] <- 0
panel$neighbor_flood_x_post_rr20 <- panel$neighbor_flood * panel$post_rr20

acs_rows <- list()
for (year in 2015:2024) {
    file <- file.path(raw_census, paste0("acs5_county_controls_", year, ".json"))
    if (!file.exists(file)) next
    values <- jsonlite::fromJSON(file)
    if (is.null(dim(values)) || ncol(values) != 6L) {
        stop("Unexpected ACS response structure in ", file,
            "; expected six columns")
    }
    values <- as.data.frame(values, stringsAsFactors = FALSE)
    if (nrow(values) > 1) {
        names(values) <- c("NAME", "population", "housing_units", "median_income", "state", "county")
        values$county_fips <- paste0(values$state, values$county)
        values$year <- year
        acs_rows[[length(acs_rows) + 1L]] <- values[, c("county_fips", "year", "population", "housing_units", "median_income")]
    }
}
if (length(acs_rows) > 0) {
    acs <- do.call(rbind, acs_rows)
    panel$year <- as.integer(substr(panel$month, 1, 4))
    panel <- merge(panel, acs, by = c("county_fips", "year"), all.x = TRUE)
}

write.csv(panel, file.path(derived, "analysis_panel.csv"), row.names = FALSE)
message("Wrote analysis_panel.csv")
