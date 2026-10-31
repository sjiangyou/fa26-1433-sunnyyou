#!/usr/bin/env Rscript

# Create or update the project-local R environment. `renv` records the
# resolved package versions in renv.lock after the first successful setup.

required_packages <- c("here", "ggplot2", "data.table", "jsonlite")

if (!requireNamespace("renv", quietly = TRUE)) {
    install.packages("renv", repos = "https://cloud.r-project.org")
}

if (file.exists("renv.lock")) {
    renv::restore(prompt = FALSE)
}

if (!file.exists("renv.lock")) {
    renv::init(bare = TRUE, restart = FALSE)
}
renv::install(required_packages)
renv::snapshot(prompt = FALSE)

message("R environment is ready with: ", paste(required_packages, collapse = ", "))
