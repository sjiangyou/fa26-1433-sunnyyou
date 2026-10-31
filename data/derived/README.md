# Derived data

Store analysis-ready data created by the project's code here. These files are ignored by Git by default and should be reproducible from the raw data.

Run `make derive` to create the categorized panels. The outputs are:

- `policy_county_month.csv`: NFIP policy flows, stocks/transactions, coverage, and observed premiums.
- `flood_county_month.csv`: FEMA declarations and NFIP claims aggregated by county and month.
- `county_nearest_neighbors.csv`: five-nearest-county proxy for geographic neighbors.
- `analysis_panel.csv`: merged county-month analysis file with pre/post-Risk-Rating-2.0 and South Florida variables.

The nearest-neighbor file is a transparent first proxy based on county centroids,
not a contiguous-border definition. The policy file does not contain a
persistent household identifier, so `premium_change` is an aggregate change in
the county-month mean observed premium.
