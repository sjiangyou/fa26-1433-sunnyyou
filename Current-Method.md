# Important Findings and Current Working Method

## Context and previous work

Gallagher (2014), “Learning about an Infrequent Event,” studies how households
update flood-risk beliefs after floods. Gallagher finds that NFIP take-up rises
immediately after a flood and then decays.

Our project extends this design to the period surrounding NFIP Risk Rating 2.0,
which introduced more individualized risk-based pricing. The central question
is whether floods and nearby floods produce different NFIP take-up responses
before and after the new pricing regime.

The primary geographic focus is South Florida, with Miami-Dade, Broward, and
Palm Beach as the core counties. The preferred comparison sample includes all
Florida counties, allowing South Florida effects to be estimated relative to
broader Florida trends. Additional South Florida counties are retained in a
broader robustness definition.

## Data

### Raw data

The current raw-data inventory includes:

- FEMA/NFIP policy transactions, including effective and termination dates,
  policy counts, premiums, coverage, flood-zone variables, and geography.
- FEMA/NFIP claims, including loss dates, damage, payments, water depth, and
  redacted county/tract geography.
- FEMA disaster declarations, including incident dates, declaration types, and
  designated counties.
- ACS five-year county controls: population, housing units, and median income.
- Census county Gazetteer geography used to construct a transparent geographic
  neighbor proxy.

Raw files are documented in `data/raw/SOURCES.md` and are downloaded through
the categorized scripts described below.

## Method

### Estimating design

The intended event-study specification includes direct floods, nearby floods,
and the post-Risk-Rating-2.0 regime:

\[
Y_{ct} = \sum_k \beta_k Flood_{c,t+k}
+ \sum_k \gamma_k NeighborFlood_{c,t+k}
+ \sum_k \beta_k^{Post}(Flood_{c,t+k} \times Post_t)
+ \sum_k \gamma_k^{Post}(NeighborFlood_{c,t+k} \times Post_t)
+ \alpha_c + \lambda_t + \varepsilon_{ct}.
\]

The pre-period is 2015–2021 and the post-period begins in 2022. Because Risk
Rating 2.0 was phased in beginning in late 2021, 2021 is treated as a transition
year in robustness checks. County fixed effects absorb time-invariant county
characteristics, while calendar-time fixed effects absorb common shocks.

The primary outcome is NFIP take-up measured from policy transactions. Since the
public NFIP policy file does not contain a persistent household policy identifier
or a complete housing denominator, the initial outcomes are county-month policy
flows and policy counts, without an interaction term with premiums. 
ACS housing units can later be used to normalize these measures.

### Derived variables

The derivation workflow creates:

- `policy_county_month.csv`: policy records, policy counts, new-policy records,
  cancellations, coverage, and mean observed premiums by county and month.
- `flood_county_month.csv`: FEMA declaration counts, flood-declaration
  indicators, NFIP claim counts, reported damage, payments, and water depth.
- `county_nearest_neighbors.csv`: five nearest counties for Florida counties.
- `analysis_panel.csv`: merged county-month panel with South Florida,
  post-2022, flood-by-post, neighbor-by-post, premium-change, and ACS variables
  where available.

The current `premium_change` variable is the change in the county-month mean
observed NFIP premium. It is descriptive rather than a clean causal measure of
the Risk Rating 2.0 price change because policy composition may change over
time. The main identification strategy therefore emphasizes the pre/post-2022
comparison rather than interpreting the aggregate premium change as an
individual household treatment.

### Categorized workflow

`make all` runs the complete workflow:

1. Set up the Python and R environments.
2. Download FEMA/NFIP data with `download_fema_nfip_data.py`.
3. Download ACS controls with `download_census_controls.py`.
4. Download Census county geography with `download_census_county_geography.py`.
5. Derive policy, flood, neighbor, and merged analysis panels with the
   corresponding R scripts.

The two largest raw files are processed with chunked `data.table` reads, so the
full NFIP policy and claims files are not loaded into memory and no database
server is required.

## Current limitations and conclusions

- The outcome measures NFIP take-up, not total flood-insurance take-up, because
  private flood-insurance policies are not in the FEMA files.
- NFIP policy transactions are redacted and do not support reliable household
  longitudinal histories.
- The current neighbor measure uses five nearest county centroids, not
  contiguous county borders. It is a documented proxy that should be replaced
  with a border-adjacency crosswalk for the preferred specification.
- FEMA disaster declarations do not capture every physical flood. Claims,
  precipitation, gauges, or inundation data should be used in robustness checks.
- A pre/post-2022 comparison identifies a change in the overall flood-response
  relationship. It does not, by itself, isolate the causal effect of premium
  changes from other changes in NFIP rules, insurance markets, migration,
  disaster assistance, or flood severity.
