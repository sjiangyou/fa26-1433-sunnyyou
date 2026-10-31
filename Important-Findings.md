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
- Census county Gazetteer coordinates for constructing a geographic-neighbor
  proxy.

The study does not use media influences. GDELT and television-market data are
therefore not part of the main data, estimating equation, or `make all` workflow.

## Estimating method

The empirical strategy follows Gallagher’s event-study structure. The primary
unit is a county-month observation rather than Gallagher’s community-year
observation.

\[
Y_{ct} = \sum_k \beta_k Flood_{c,t+k}
+ \sum_k \gamma_k NeighborFlood_{c,t+k}
+ \sum_k \beta_k^{Post}(Flood_{c,t+k} \times Post_t)
+ \sum_k \gamma_k^{Post}(NeighborFlood_{c,t+k} \times Post_t)
+ \alpha_c + \lambda_t + \varepsilon_{ct}.
\]

Here:

- `Flood` identifies a flood-related FEMA declaration in the county.
- `NeighborFlood` identifies flooding in nearby counties.
- `Post` identifies the post-Risk-Rating-2.0 period beginning in 2022.
- `alpha_c` denotes county fixed effects.
- `lambda_t` denotes calendar month-year fixed effects.

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
- `county_nearest_neighbors.csv`: five nearest counties for Florida counties,
  used as the initial geographic-neighbor proxy.
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
- The current neighbor measure uses five nearest county centroids rather than
  contiguous county borders. A border-adjacency crosswalk is preferred for the
  final specification.
- The pre/post design estimates a change in the overall flood-response
  relationship. Without a clean individual premium-change measure, it does not
  separately identify the causal effect of premium changes.
