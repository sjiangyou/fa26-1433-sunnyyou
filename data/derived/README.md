# Derived data

Store analysis-ready data created by the project's code here. These files are ignored by Git by default and should be reproducible from the raw data.

Run `make derive` to create the categorized panels. The outputs are:

- `policy_county_month.csv`: NFIP policy flows, stocks/transactions, coverage, and observed premiums.
- `flood_county_month.csv`: FEMA declarations and NFIP claims aggregated by county and month.
- `county_neighbors.csv`: county pairs sharing a positive-length boundary segment.
- `analysis_panel.csv`: merged county-month analysis file with direct floods,
  adjacent-flood counts, Gallagher-style nonflooded-neighbor indicators,
  pre/post-Risk-Rating-2.0 variables, and South Florida indicators.

The model stage, run by `make estimate-model` or as the final stage of
`make all`, writes these additional reproducible artifacts under `model/`:

- `model/annual_event_study_panel.csv`: annual county observations for all available states and territories used for estimation.
- `model/event_study_coefficients.csv`: baseline direct- and neighbor-flood
  coefficients and post-minus-pre interaction coefficients.
- `model/event_study_effects.csv`: pre responses, post responses, and their
  differences with uncertainty estimates.
- `model/event_study_coefficients_translated.csv` and
  `model/event_study_effects_translated.csv`: log-scale estimates translated to
  implied percentage changes.
- `model/event_study_fit_statistics.csv`: observation counts and fit statistics for each outcome.

The county-neighbor file uses Census TIGER/Line county polygons for all
available counties. Counties that only meet at a point are excluded. The policy
file does not contain a persistent household identifier, so `premium_change` is
an aggregate change in the county-month mean observed premium. The annual model
panel retains `adjacent_flood` as the raw exposure and defines `neighbor_flood`
as one only when `adjacent_flood == 1` and `direct_flood == 0`. The estimator
also validates that the balanced panel contains exactly one observation for
each county-year.
