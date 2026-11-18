# Code

Store scripts for acquiring, cleaning, analyzing, and visualizing data here. Use
descriptive filenames and document the execution order in the repository's main
README.

The current setup scripts are:

- `download_fema_nfip_data.py`: downloads FEMA disaster declarations and
  redacted NFIP policies and claims.
- `download_census_controls.py`: downloads annual ACS county controls.
- It reads the Census API key from the `CENSUS_API_KEY` environment variable.
- `download_census_county_geography.py`: downloads Census county Gazetteer and
  TIGER/Line polygon files used for the geographic-neighbor crosswalk.
- `derive_policy_panel.R`: creates county-month NFIP policy flows and premium
  summaries using chunked `data.table` reads.
- `derive_flood_panel.R`: creates county-month FEMA declaration and claims
  measures using chunked `data.table` reads.
- `derive_neighbor_panel.py`: creates the county-neighbor crosswalk for all
  counties represented in the Census geography file by retaining county pairs
  that share a positive-length boundary segment. It uses only the Python
  standard library to parse the Census shapefile.
- `derive_analysis_panel.R`: merges all derived inputs into `analysis_panel.csv`,
  retaining the number of adjacent flooded counties and marking a county-month
  as a Gallagher-style neighbor only when the focal county is not flooded.
- `estimate_model.R`: aggregates the analysis panel to annual county
  observations for all available geographies and estimates the annual direct-
  and neighbor-flood event study with baseline event-time terms and post-flood-
  cohort interactions, county fixed effects, and state-by-year fixed effects.
  At the annual level, neighbor exposure requires an adjacent flood and no
  direct flood anywhere in the focal county-year. The script builds a one-row-
  per-FIPS county lookup and stops if the balanced panel contains duplicate or
  missing county-years.
- `translate_coefficients.R`: translates log event-study coefficients into
  implied percentage changes using `100 * (exp(estimate) - 1)`, including the
  confidence intervals in the coefficient and effects tables.
- `setup_r_environment.R`: creates or restores the project-local `renv`
  environment with the packages required by the data and model scripts.

Use `make estimate-model` to run the model stage after the derived panels
exist. The model writes its annual regression panel and coefficient tables to
`data/derived/model/`. This stage is also included in `make all`, which runs
the complete currently implemented workflow. Use the repository `Makefile`
instead of invoking these scripts manually when reproducing the project.

After estimation, `make translate-coefficients` writes translated versions of
`event_study_coefficients.csv` and `event_study_effects.csv`. These files
preserve the log-scale results and add implied percentage changes for the point
estimates and confidence intervals.
