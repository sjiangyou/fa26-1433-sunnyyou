# Important Findings and Current Working Method

## Context and previous work

Gallagher (2014), “Learning about an Infrequent Event,” studies how households
update flood-risk beliefs after floods. Gallagher finds that NFIP take-up rises
immediately after a flood and then decays.

Our project extends this design to the period surrounding NFIP Risk Rating 2.0,
which introduced more individualized risk-based pricing. The central question
is whether floods and nearby floods produce different NFIP take-up responses
before and after the new pricing regime.

The original geographic focus was South Florida, with Miami-Dade, Broward, and
Palm Beach as the core counties. The implemented analysis now uses all counties
and state-like geographic units available in the data. South Florida indicators
are retained for descriptive and subgroup analyses.

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
- Census TIGER/Line county polygons used to construct the geographic-neighbor
  crosswalk.

Raw files are documented in `data/raw/SOURCES.md` and are downloaded through
the categorized scripts described below.

## Method

### Estimating design

The event-study specification uses annual leads and lags and separates floods
occurring before and after the Risk Rating 2.0 transition. It includes one set
of direct- and neighbor-flood indicators and a second set interacting each
indicator with the flood event's policy regime:

\[
Y_{cy} = \sum_k \beta_k^F F_{k,cy}
+ \sum_k \beta_k^N N_{k,cy}
+ \sum_k \delta_k^F(F_{k,cy} \times PostFloodCohort)
+ \sum_k \delta_k^N(N_{k,cy} \times PostFloodCohort)
+ \alpha_c + \lambda_{s(c),y} + \varepsilon_{cy}.
\]

Here, \(F_{k,cy}\) and \(N_{k,cy}\) are direct- and neighbor-flood event-time
counts, and \(k=-1\) is omitted. Following Gallagher's geographic-neighbor
specification, a county-year enters the neighbor treatment only if at least one
border-adjacent county floods and the focal county does not flood in that year.
Direct- and neighbor-flood treatments are therefore mutually exclusive within
a county-year. `PostFloodCohort` equals one for a flood event occurring after
2021; it classifies the flood, not the observation year. In code, each
interaction is the event-time count constructed only from post-2021 floods,
which also handles overlapping events from different cohorts. The implemented
window is three years before through three years after each event.

The estimator collapses the county-month analysis panel to a balanced
county-year panel for all available geographies. Its fixed effects
are county fixed effects (`county_fips`) and state-by-year fixed effects
(`state_group^year`), implemented in `code/estimate_model.R` as
`county_fips + state_group^year`. The state group is the first two digits of
county FIPS, so Washington, D.C., and U.S. territories are treated as their own
state-like groups. The annual aggregation carries the group identifier through
the one-row-per-FIPS county lookup, which is merged once into the balanced
county-year panel. Missing and populated state labels therefore cannot create
duplicate lookup rows. The estimator stops unless it finds exactly one row per
county-year and preserves the `state_group` column used by the fixed-effects
formula.
County fixed effects absorb time-invariant county
characteristics, while state-by-year fixed effects absorb shocks shared by
counties within a state or territory in a given year. A county-month version
with calendar month-year fixed effects remains a planned higher-frequency
specification rather than the estimator currently run by `make all`.

For each event time \(k\), \(\beta_k^F\) and \(\beta_k^N\) are the pre-Risk-
Rating-2.0 responses. The corresponding post responses are
\(\beta_k^F+\delta_k^F\) and \(\beta_k^N+\delta_k^N\). The interaction
coefficients \(\delta_k^F\) and \(\delta_k^N\) are the primary coefficients of
interest because they directly measure the post-minus-pre response difference.
For a logged outcome, `translate_coefficients.R` expresses that relative
difference as \(100[\exp(\delta_k)-1]\).

### Notation and variable definitions

The following notation applies to the implemented annual estimator unless
otherwise noted:

- \(c\) indexes counties. It does not index individual households, because the
  public NFIP records are geographically aggregated and do not provide a
  reliable persistent household identifier.
- \(y\) indexes calendar years. The implemented outcome is \(Y_{cy}\), a
  county-year NFIP outcome. The planned higher-frequency specification uses
  \(t\) for calendar months and \(Y_{ct}\) for county-month outcomes.
- \(k\) indexes event time in years relative to a flood year. For example,
  \(k=0\) is the flood year, \(k=1\) is the following year, and \(k=-1\) is
  the year immediately before the flood.
- \(Y_{cy}\) is the annual county-level NFIP outcome. The primary outcome is
  `log_new_policy_records`; `log_policy_count` and `log_policy_records` are
  robustness outcomes. The corresponding `log1p_*` columns are retained in
  the saved annual panel for alternative specifications.
- `EventTime` or `Flood` identifies a direct flood event for county \(c\) at
  the relevant event time. `AdjacentFlood` identifies any flood in a county
  sharing a positive-length border with county \(c\). `NeighborFlood` equals
  one only when `AdjacentFlood` equals one and the focal county has no direct
  flood in that calendar year.
- `PostFloodCohort` identifies the flood event's Risk Rating 2.0 cohort: pre-
  transition floods occurred in 2021 or earlier, while post-transition floods
  occurred after 2021. It is an event-level classification, not a permanent
  characteristic of a county.
- \(\alpha_c\) denotes county fixed effects, implemented as `county_fips`.
  These absorb time-invariant county characteristics.
- \(\lambda_{s(c),y}\) denotes state-by-year fixed effects, implemented as
  `state_group^year`. These absorb shocks common to counties within a state or
  territory in a given year.
- \(\varepsilon_{cy}\) denotes the county-year error term.
- Event time \(k=-1\) is omitted as the reference period. Coefficients for
  other event times are interpreted relative to the year immediately before
  the flood.

In `code/estimate_model.R`, baseline terms are named `direct_*` and
`neighbor_*`. Interaction terms are named `direct_post_difference_*` and
`neighbor_post_difference_*`. The saved `event_study_effects.csv` reports each
pre response, the corresponding post response, and the post-minus-pre
difference with its standard error and 95 percent confidence interval. Because
the data end in 2024, event time (+3) is not estimable for post-2021 flood
cohorts; the effects table retains these rows and marks them non-estimable.

### Event-study figures

The visualization stage uses R and ggplot2 to plot the primary
`log_new_policy_records` results from
`event_study_effects_translated.csv`. Separate figures compare pre- and
post-transition responses for direct floods and nonflooded geographic
neighbors. A third figure plots the post-minus-pre interaction estimates for
both exposures. The y-axes report implied percentage changes,
`100[exp(beta) - 1]`, and confidence bars are transformed endpoints of the
county-clustered 95 percent intervals. Event time -1 is omitted from the model
and inserted as a normalized zero; it is not an estimated point. Run
`make plot-figures` to reproduce the PNG files, or `make all` for the complete
workflow.

### Primary outcome definition

The primary outcome is the log of the annual number of new NFIP policy
records in county \(c\) and year \(y\):

\[
NewPolicyRecords_{cy}
= \sum_{i\in(c,y)}
1\{originalNBDate_i = policyEffectiveDate_i\},
\]

\[
Y_{cy}=\log\left(NewPolicyRecords_{cy}\right).
\]

The equality identifies a policy record as new when its `originalNBDate` equals
its `policyEffectiveDate`. The annual count is obtained by summing the monthly
counts. This is a record-based proxy for new NFIP take-up, not a count of unique
households: the public NFIP policy file does not contain a persistent household
identifier or a complete housing denominator. The other estimated outcomes are
defined analogously as `log(policy_count)` and `log(policy_records)` and are
used as robustness checks. Since the ordinary log is undefined at zero, zero
outcomes are stored as `NA` in the `log_*` columns and omitted from the
corresponding model. The `log1p_*` columns remain available in the saved panel.

### Derived variables

The derivation workflow creates:

- `policy_county_month.csv`: policy records, policy counts, new-policy records,
  cancellations, coverage, and mean observed premiums by county and month.
- `flood_county_month.csv`: FEMA declaration counts, flood-declaration
  indicators, NFIP claim counts, reported damage, payments, and water depth.
- `county_neighbors.csv`: counties sharing a positive-length boundary segment
  with each available county.
- `analysis_panel.csv`: merged county-month panel with South Florida,
  post-2022, direct-flood, adjacent-flood-count, Gallagher-style nonflooded-
  neighbor, premium-change, and ACS variables where available.

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

### Transition-year robustness specification

The transition-year robustness model uses the same outcomes, event window,
event-cohort classification, fixed effects, and county-clustered uncertainty
estimates as the baseline model. It first constructs event-time regressors from
the complete 2015--2024 panel and then removes observations whose calendar year
is 2021 from the estimation sample. This order preserves the influence of a
2021 flood on retained lead and lag observations. Such a flood remains a
pre-transition cohort because `PostFloodCohort` is defined by the flood year,
not the outcome-observation year.

Run `make estimate-model-no-2021` to create the log-scale estimates and
`make translate-coefficients-no-2021` to create their implied-percentage-change
versions. All robustness artifacts use `_no_2021.csv` suffixes and are also
regenerated by `make all`.

## Current results

The results regenerated on November 18, 2026 use the corrected Gallagher-style
neighbor definition and a validated balanced panel of 35,470 observations: ten
years for each of 3,547 counties. Among 9,322 county-years with at least one
adjacent flood, 6,912 also have a direct flood and are excluded from neighbor
treatment. This leaves 2,410 mutually exclusive neighbor event years: 1,687
through 2021 and 723 after 2021. Direct and neighbor indicators have zero
overlap in the saved annual estimation panel.

For the primary log-new-policy-record outcome, pre-transition direct floods are
associated with increases of 19.8 percent in the flood year, 15.7 percent one
year later, and 5.0 percent two years later. The corresponding post-transition
responses are -0.5 percent, -1.5 percent, and -1.4 percent and are not
statistically distinguishable from zero. The post-minus-pre differences are
-16.9 percent in the flood year and -14.9 percent one year later, both
statistically significant; the year-two difference is not significant. Direct-
flood leads at event times -3 and -2 are not statistically significant.

Pre-transition nonflooded neighbors have positive responses of 9.1 percent in
the flood year, 8.7 percent one year later, and 4.9 percent two years later.
Post-transition neighbor responses are -9.2 percent, -10.5 percent, and -16.1
percent, respectively, and all three are statistically significant. Their
post-minus-pre differences are also negative and statistically significant.
However, the neighbor leads at event times -3 and -2 are positive, and the
post-minus-pre difference at -2 is statistically significant. These pre-event
patterns weaken a causal interpretation of the neighbor estimates.

## Categorized workflow

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
- The current neighbor measure implements Gallagher's adjacent-nonflooded-
  county variant using a border-adjacency crosswalk based on Census TIGER/Line
  county polygons. A county-year with a direct flood is excluded from neighbor
  treatment, and counties that only meet at a point are excluded. Gallagher's
  closest-five-county and television-market definitions are not implemented.
- FEMA disaster declarations do not capture every physical flood. Claims,
  precipitation, gauges, or inundation data should be used in robustness checks.
- A pre/post-2022 comparison identifies a change in the overall flood-response
  relationship. It does not, by itself, isolate the causal effect of premium
  changes from other changes in NFIP rules, insurance markets, migration,
  disaster assistance, or flood severity.
