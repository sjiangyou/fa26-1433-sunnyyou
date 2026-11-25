# Important Findings and Current Working Method

## Context and research question

Gallagher (2014) studies how households learn about infrequent flood risk by
examining NFIP insurance take-up before and after floods. The paper finds an
immediate increase in take-up after a flood, followed by gradual decay. It also
examines responses in nearby nonflooded communities.

Our project replicates Gallagher’s direct-flood and geographic-neighbor design
using current NFIP data and extends it to the NFIP Risk Rating 2.0 transition.
The research question is:

> Did households’ NFIP insurance responses to direct floods and nearby floods
> change after the introduction of Risk Rating 2.0?

The original primary focus was South Florida, with Miami-Dade, Broward, and Palm
Beach as the core counties. The implemented model now uses all counties and
state-like geographic units available in the data, while retaining South
Florida indicators for descriptive comparisons.

## Data

The main raw inputs are:

- Redacted NFIP policy transactions: effective dates, terminations,
  cancellations, policy counts, premiums, coverage, flood zones, and geography.
- Redacted NFIP claims: loss dates, claim counts, damage, payments, water depth,
  and redacted geography.
- FEMA disaster declarations: incident dates, declaration types, and designated
  counties.
- ACS county controls: population, housing units, and median income.
- Census TIGER/Line county polygons for constructing a geographic-neighbor
  crosswalk.

The study does not use media influences. GDELT and television-market data are
therefore not part of the main data, estimating equation, or `make all` workflow.

## Estimating method

The empirical strategy follows Gallagher’s event-study structure. The derived
analysis panel is at the county-month level, but the currently implemented
estimator collapses it to a balanced county-year panel rather than estimating
the county-month specification directly.

\[
Y_{cy} = \sum_k \beta_k^F F_{k,cy}
+ \sum_k \beta_k^N N_{k,cy}
+ \sum_k \delta_k^F(F_{k,cy} \times PostFloodCohort)
+ \sum_k \delta_k^N(N_{k,cy} \times PostFloodCohort)
+ \alpha_c + \lambda_{s(c),y} + \varepsilon_{cy}.
\]

Here:

- `F` identifies a flood-related FEMA declaration in the county.
- `N` identifies a border-adjacent flood only when the focal county is not
  directly flooded in that calendar year. This matches Gallagher's
  adjacent-nonflooded-county specification and makes `F` and `N` mutually
  exclusive within a county-year.
- `PostFloodCohort` identifies floods occurring after 2021. This is an event-
  cohort classification, not an indicator for the observation year.
- `alpha_c` denotes county fixed effects.
- `lambda_{s(c),y}` denotes state-by-year fixed effects.

For each event time, the baseline coefficients \(\beta_k^F\) and
\(\beta_k^N\) measure the pre-transition responses. The post-transition
responses are \(\beta_k^F+\delta_k^F\) and
\(\beta_k^N+\delta_k^N\). The interaction coefficients \(\delta_k^F\) and
\(\delta_k^N\) are the primary coefficients of interest: they measure the
post-minus-pre differences. On the percentage scale, these relative
differences are \(100[\exp(\delta_k)-1]\).

The implemented model uses county fixed effects (`county_fips`) and state-by-
year fixed effects (`state_group^year`), specified in `code/estimate_model.R` as
`county_fips + state_group^year`. The state group is based on the first two
county-FIPS digits; D.C. and U.S. territories therefore receive their own
state-like groups. `state_group` is attached from the county lookup exactly
once when the balanced county-year panel is assembled. The lookup contains one
row per FIPS code, and the estimator validates that every county-year is unique,
so intermittently missing state labels cannot duplicate observations. A
county-month model with calendar month-year fixed effects
remains a planned higher-frequency specification, not the model currently
estimated by `make all`.

The primary outcome is the log of annual new NFIP policy records:

\[
NewPolicyRecords_{cy}
= \sum_{i\in(c,y)}
1\{originalNBDate_i = policyEffectiveDate_i\},
\qquad
Y_{cy}=\log\left(NewPolicyRecords_{cy}\right).
\]

Thus, a record is classified as new when its original new-business date equals
its effective date. This measures new NFIP policy records rather than unique
households. The models also estimate log policy counts and log policy records as
robustness outcomes. Zero-valued outcomes are undefined on this scale and are
omitted from the corresponding model; the annual panel retains the previous
`log1p_*` versions for alternative specifications.

Pre-transition flood cohorts occur in 2015–2021 and post-transition flood
cohorts begin in 2022. Because Risk Rating 2.0 was phased in beginning in late
2021, treating 2021 separately remains an important robustness check.

The saved effects table reports the pre response, post response, and
post-minus-pre difference for every direct- and neighbor-flood event time,
together with cluster-robust uncertainty estimates. Post-cohort event time
(+3) is not estimable because post cohorts begin in 2022 and the current data
end in 2024; these rows are retained and explicitly marked non-estimable.

## Derived data

The categorized derivation workflow creates:

- `policy_county_month.csv`: policy records, policy counts, new-policy records,
  cancellations, coverage, and mean observed premiums by county and month.
- `flood_county_month.csv`: FEMA declaration counts, flood indicators, NFIP
  claims, reported damage, payments, and water depth by county and month.
- `county_neighbors.csv`: counties sharing a positive-length boundary segment
  with each available county.
- `analysis_panel.csv`: merged county-month panel with direct floods, adjacent-
  flood counts, Gallagher-style nonflooded-neighbor indicators, post-2022,
  South Florida, premium, and ACS variables where available.

The policy and claims derivations use chunked `data.table` reads. This avoids
loading the approximately 30 GB policy file or the large claims file into
memory and does not require a database server.

## Results

The model was regenerated on November 18, 2026 after implementing Gallagher's
mutually exclusive direct- and neighbor-flood classification and validating the
balanced panel. The panel contains exactly 35,470 observations: ten years for
each of 3,547 counties, with no duplicated county-years. It contains 9,322
county-years with an adjacent flood. Of these, 6,912 are also directly flooded
and are therefore excluded from neighbor treatment, leaving 2,410 nonflooded-
neighbor event years. The direct and neighbor indicators have zero overlap.

For the primary log-new-policy-record outcome:

- Before the Risk Rating 2.0 transition, direct floods are associated with
  increases of 19.8 percent in the flood year, 15.7 percent after one year, and
  5.0 percent after two years. All three estimates are statistically
  significant.
- After the transition, the corresponding direct-flood responses are -0.5
  percent, -1.5 percent, and -1.4 percent. None is statistically significant.
  The post-minus-pre differences are -16.9 percent in the flood year and -14.9
  percent after one year, both statistically significant; the year-two
  difference is not significant.
- Before the transition, nonflooded geographic neighbors have positive
  responses of 9.1 percent in the flood year, 8.7 percent after one year, and
  4.9 percent after two years. All three estimates are statistically
  significant.
- After the transition, neighbor responses are -9.2 percent, -10.5 percent,
  and -16.1 percent at event times 0, 1, and 2. All three estimates and all
  three post-minus-pre differences are negative and statistically significant.

The direct-flood leads at event times -3 and -2 are not statistically
significant after correcting the neighbor classification. The neighbor leads
remain positive and statistically significant, and the neighbor post-minus-pre
difference at event time -2 is also significant. This evidence of differential
pre-event behavior means the neighbor estimates should not yet be interpreted
as causal effects.

The three reproducible event-study figures visualize these estimates on the
implied-percentage-change scale. The direct and neighbor figures compare flood
cohorts through 2021 with cohorts after 2021; the difference figure shows the
post-minus-pre interactions that are the coefficients of interest. The plotted
year -1 zeros are regression normalizations, not additional estimates.

## Assumptions and validation

The most important assumptions are:

1. Flood timing is conditionally exogenous after controlling for county,
   calendar time, seasonality, and prior flood history.
2. Counties have no differential pre-flood trends in NFIP take-up.
3. Geographic-neighbor indicators capture relevant indirect exposure.
4. NFIP policy outcomes are measured consistently before and after 2022.
5. The post-2022 change is not entirely caused by unrelated changes in COVID-19,
   migration, housing, disaster assistance, or flood severity.

We will evaluate these assumptions with event-study lead tests, placebo flood
dates, lagged-outcome tests, alternative neighbor definitions, transition-year
exclusions, county population and housing controls, and alternative samples.

## Limitations

- The outcome measures NFIP take-up, not total flood-insurance take-up, because
  private flood-insurance policies are not observed.
- NFIP records are redacted and do not provide reliable household-level
  longitudinal histories.
- FEMA declarations do not capture every physical flood; claims, rainfall,
  gauges, or inundation data may be used in robustness checks.
- The current neighbor measure implements Gallagher's adjacent-nonflooded-
  county variant. Adjacent counties share a positive-length boundary segment;
  counties that only meet at a point are excluded, and a directly flooded
  county-year cannot also be classified as a neighbor event. Gallagher's
  closest-five-county and television-market definitions are not implemented.
- The pre/post design estimates a change in the overall flood-response
  relationship. Without a clean individual premium-change measure, it does not
  separately identify the causal effect of premium changes.

## Conclusions

Matching Gallagher's nonflooded-neighbor definition removes substantial
treatment overlap and materially changes the direct-flood estimates. The
current results indicate positive direct and neighbor responses before the
Risk Rating 2.0 transition but no positive direct response and a negative
neighbor response after the transition. The post-transition contrast is an
association under the event-study assumptions, not an isolated causal effect
of Risk Rating 2.0. In particular, the remaining neighbor pre-trends require
additional robustness analysis before drawing a causal conclusion.
