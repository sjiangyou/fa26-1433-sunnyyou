# Code

Store scripts for acquiring, cleaning, analyzing, and visualizing data here. Use
descriptive filenames and document the execution order in the repository's main
README.

The current setup scripts are:

- `download_fema_nfip_data.py`: downloads FEMA disaster declarations and
  redacted NFIP policies and claims.
- `download_census_controls.py`: downloads annual ACS county controls.
- It reads the Census API key from the `CENSUS_API_KEY` environment variable.
- `download_census_county_geography.py`: downloads Census county centroids
  used for the transparent nearest-neighbor proxy.
- `derive_policy_panel.R`: creates county-month NFIP policy flows and premium
  summaries using chunked `data.table` reads.
- `derive_flood_panel.R`: creates county-month FEMA declaration and claims
  measures using chunked `data.table` reads.
- `derive_neighbor_panel.R`: creates the South Florida county nearest-neighbor
  crosswalk.
- `derive_analysis_panel.R`: merges all derived inputs into `analysis_panel.csv`.
- `setup_r_environment.R`: creates or restores the project-local `renv`
  environment with `here` and `ggplot2`.

Use the repository `Makefile` instead of invoking these scripts manually when
reproducing the project.
