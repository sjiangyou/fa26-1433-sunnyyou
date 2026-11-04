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

The primary focus is South Florida, with Miami-Dade, Broward, and Palm Beach as
the core counties. The preferred comparison sample includes all Florida
counties, allowing South Florida effects to be compared with broader Florida
responses.

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
Y_{cy} = \sum_k \beta_k Flood_{c,y+k}
+ \sum_k \gamma_k NeighborFlood_{c,y+k}
+ \sum_k \beta_k^{Post}(Flood_{c,y+k} \times Post_y)
+ \sum_k \gamma_k^{Post}(NeighborFlood_{c,y+k} \times Post_y)
+ \alpha_c + \lambda_y + \varepsilon_{cy}.
\]

Here:

- `Flood` identifies a flood-related FEMA declaration in the county.
- `NeighborFlood` identifies flooding in nearby counties.
- `Post` identifies the post-Risk-Rating-2.0 period beginning in 2022.
- `alpha_c` denotes county fixed effects.
- `lambda_y` denotes calendar-year fixed effects.

The implemented model uses county fixed effects (`county_fips`) and
calendar-year fixed effects (`year`), specified in `code/estimate_model.R` as
`county_fips + year`. A county-month model with calendar month-year fixed
effects remains a planned higher-frequency specification, not the model
currently estimated by `make all`.

The primary outcome is annual new NFIP policy records:

\[
NewPolicyRecords_{cy}
= \sum_{i\in(c,y)}
1\{originalNBDate_i = policyEffectiveDate_i\},
\qquad
Y_{cy}=\log\left(1+NewPolicyRecords_{cy}\right).
\]

Thus, a record is classified as new when its original new-business date equals
its effective date. This measures new NFIP policy records rather than unique
households. The models also estimate log policy counts and log policy records as
robustness outcomes.

The pre-period is 2015–2021 and the post-period begins in 2022. Because Risk
Rating 2.0 was phased in beginning in late 2021, 2021 is treated as a
transition year and will be excluded or handled separately in robustness
checks.

The main coefficients of interest are the interactions between event-time flood
indicators and `Post`. They measure whether the dynamic responses to direct and
nearby floods changed after Risk Rating 2.0.

## Derived data

The categorized derivation workflow creates:

- `policy_county_month.csv`: policy records, policy counts, new-policy records,
  cancellations, coverage, and mean observed premiums by county and month.
- `flood_county_month.csv`: FEMA declaration counts, flood indicators, NFIP
  claims, reported damage, payments, and water depth by county and month.
- `county_neighbors.csv`: counties sharing a positive-length boundary segment
  with each Florida county.
- `analysis_panel.csv`: merged county-month panel with flood, neighbor,
  post-2022, South Florida, premium, and ACS variables where available.

The policy and claims derivations use chunked `data.table` reads. This avoids
loading the approximately 30 GB policy file or the large claims file into
memory and does not require a database server.

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
- The current neighbor measure uses counties sharing a positive-length boundary
  segment. Counties that only meet at a point are excluded.
- The pre/post design estimates a change in the overall flood-response
  relationship. Without a clean individual premium-change measure, it does not
  separately identify the causal effect of premium changes.
