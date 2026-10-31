#!/usr/bin/env Rscript

# Create a transparent geographic-neighbor crosswalk. The Census Gazetteer
# contains centroids rather than borders, so this first version uses the five
# nearest county centroids and can later be replaced with a border crosswalk.

args <- commandArgs(trailingOnly = FALSE)
script <- sub("^--file=", "", args[grepl("^--file=", args)][1])
root <- normalizePath(file.path(dirname(script), ".."))
raw <- file.path(root, "data", "raw", "census")
derived <- file.path(root, "data", "derived")
zip_file <- file.path(raw, "2024_Gaz_counties_national.zip")
if (!file.exists(zip_file)) stop("Missing Census county Gazetteer: ", zip_file)
dir.create(derived, recursive = TRUE, showWarnings = FALSE)

files <- unzip(zip_file, list = TRUE)$Name
txt <- files[grepl("\\.txt$", files, ignore.case = TRUE)][1]
if (is.na(txt)) stop("No county Gazetteer text file found in ", zip_file)
unzip(zip_file, files = txt, exdir = dirname(zip_file))
extracted <- file.path(dirname(zip_file), txt)
gaz <- read.table(extracted, header = TRUE, sep = "\t", quote = "", comment.char = "", stringsAsFactors = FALSE)
names(gaz) <- gsub("[^A-Za-z0-9]", "", names(gaz))
id_col <- names(gaz)[grepl("GEOID", names(gaz), ignore.case = TRUE)][1]
lat_col <- names(gaz)[grepl("INTPTLAT", names(gaz), ignore.case = TRUE)][1]
lon_col <- names(gaz)[grepl("INTPTLONG", names(gaz), ignore.case = TRUE)][1]
if (any(is.na(c(id_col, lat_col, lon_col)))) stop("Unexpected Census Gazetteer columns")
gaz$county_fips <- as.character(gaz[[id_col]])
gaz$lat <- as.numeric(gaz[[lat_col]])
gaz$lon <- as.numeric(gaz[[lon_col]])
gaz <- gaz[!is.na(gaz$lat) & !is.na(gaz$lon), c("county_fips", "lat", "lon")]
targets <- gaz[substr(gaz$county_fips, 1, 2) == "12", ]

distance <- function(lat1, lon1, lat2, lon2) {
    radians <- pi / 180
    3959 * 2 * asin(sqrt(sin((lat2 - lat1) * radians / 2)^2 +
        cos(lat1 * radians) * cos(lat2 * radians) * sin((lon2 - lon1) * radians / 2)^2))
}
rows <- vector("list", nrow(targets) * 5)
index <- 0L
for (i in seq_len(nrow(targets))) {
    d <- distance(targets$lat[i], targets$lon[i], gaz$lat, gaz$lon)
    d[gaz$county_fips == targets$county_fips[i]] <- Inf
    nearest <- order(d)[seq_len(min(5L, sum(is.finite(d))))]
    for (j in nearest) {
        index <- index + 1L
        rows[[index]] <- data.frame(county_fips = targets$county_fips[i],
            neighbor_fips = gaz$county_fips[j], distance_miles = d[j])
    }
}
neighbors <- do.call(rbind, rows[seq_len(index)])
write.csv(neighbors, file.path(derived, "county_nearest_neighbors.csv"), row.names = FALSE)
message("Wrote county_nearest_neighbors.csv")
