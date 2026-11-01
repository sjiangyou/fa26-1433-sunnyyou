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

The planned county-month event-study specification uses annual leads and lags
and separates floods occurring before and after the Risk Rating 2.0 transition.
It includes direct floods, nearby floods, and their interactions with the
flood's policy regime:

\[
Y_{ct} = \sum_k \beta_k EventTime_{ckt}
+ \sum_k \gamma_k NeighborEventTime_{ckt}
+ \sum_k \theta_k(EventTime_{ckt} \times PostFloodCohort_c)
+ \sum_k \delta_k(NeighborEventTime_{ckt} \times PostFloodCohort_c)
+ \alpha_c + \lambda_t + \varepsilon_{ct}.
\]

Here, \(k\) indexes years relative to the flood, with event time \(-1\)
omitted. `PostFloodCohort` indicates that the flood occurred after the Risk
Rating 2.0 transition. The primary event window is expected to be relatively
short (for example, three years before through three years after the flood) to
limit contamination from the pricing transition and overlapping flood effects.
The pre-period is 2015–2021 and the post-period begins in 2022. Because Risk
Rating 2.0 was phased in beginning in late 2021, 2021 is treated as a transition
year in robustness checks.

The currently implemented estimator collapses the county-month analysis panel
to a balanced county-year panel. Its fixed effects are county fixed effects
(`county_fips`) and calendar-year fixed effects (`year`), implemented in
`code/estimate_model.R` as `county_fips + year`. County fixed effects absorb
time-invariant county characteristics, while calendar-year fixed effects absorb
common annual shocks. The county-month/calendar-month-year version above
remains the planned higher-frequency specification rather than the estimator
currently run by `make all`.

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

### Causal-identification assumptions

The event-study estimates extend Gallagher's design, so their causal
interpretation depends on the following assumptions. These assumptions are not
all fully testable; the listed diagnostics are intended to assess their
plausibility.

1. **Parallel pre-trends.** In the absence of a flood, counties exposed to
   floods at different times would have followed comparable NFIP take-up trends
   after accounting for county and calendar-time fixed effects. This can be
   assessed using the pre-flood event-time coefficients.
2. **Conditionally exogenous flood timing.** Conditional on the fixed effects
   and included controls, flood timing is not driven by an unobserved,
   county-specific shock that independently changes NFIP take-up.
3. **No differential concurrent shocks.** Other events, including hurricanes,
   disaster assistance, migration, housing-market changes, NFIP rule changes,
   and private-insurance-market changes, do not differentially coincide with
   flood exposure unless they are controlled for or are part of the intended
   flood response.
4. **Accurate flood measurement and timing.** FEMA declarations and claims
   identify the relevant flood events and their timing with sufficient accuracy.
   Robustness checks should compare declaration-based and claim-based measures.
5. **Limited anticipation.** Households do not substantially change insurance
   decisions before the specific flood being studied. Large pre-flood
   coefficients would challenge this assumption.
6. **No problematic composition changes.** Floods do not alter county
   population, housing, or policy composition in a way that mechanically drives
   measured take-up, unless that composition change is itself the intended
   outcome. ACS population and housing controls can help assess this concern.
7. **Stable outcome measurement.** Changes in NFIP reporting, policy-file
   coverage, missingness, or county coding do not coincide with floods or Risk
   Rating 2.0 in a way that mechanically changes the outcome.
8. **Appropriate treatment of repeated floods.** The model accounts for the
   possibility that a county experiences multiple floods before an earlier
   response has dissipated. Short event windows, recent-flood measures, and
   multiple-event sensitivity analyses should be considered.
9. **Explicit spillover interpretation.** Because nearby floods are included,
   the direct-flood coefficient is interpreted conditional on modeled neighbor
   exposure, while the neighbor coefficient represents a spillover effect.
   Alternative neighbor definitions should be used as robustness checks.
10. **Risk Rating 2.0 comparison validity.** Changes in the flood-response
    relationship after 2022 are not caused by other contemporaneous changes
    that differentially affected flood-exposed counties. This is stronger than
    Gallagher's original assumption and cannot be established by fixed effects
    alone.
11. **Sufficient treatment support.** There are enough flood events before and
    after the transition to estimate the relevant event-time effects. Long
    post-2022 lags will be weakly identified because the post-period is short.

The pre-2022 event study is the closest replication of Gallagher's design. The
post-2022 interaction should be interpreted more cautiously: it estimates a
change in the flood-response relationship under the identifying assumptions,
not necessarily the isolated causal effect of Risk Rating 2.0 pricing.

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
