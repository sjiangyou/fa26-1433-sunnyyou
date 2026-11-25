# Output

Store generated figures, tables, and other results here. Do not edit generated output by hand.

`make plot-figures` creates three ggplot2 figures:

- Figure 1, `event_study_direct_flood.png`: direct-flood responses for flood
  cohorts through 2021 and after 2021.
- Figure 2, `event_study_neighbor_flood.png`: responses in nonflooded
  border-adjacent counties for the two flood cohorts.
- Figure 3, `event_study_post_minus_pre.png`: post-minus-pre response
  differences for direct and neighbor floods.

The figures show implied percentage changes and 95 percent confidence
intervals. Event year -1 is displayed as a normalized zero rather than an
estimated coefficient. The legends identify the pre-transition response as
`beta[k]`, the post-transition response as `beta[Post,k]`, and the direct and
neighbor post-minus-pre interactions as `delta[k]^F` and `delta[k]^N`,
respectively. The plotting script uses mathematical expressions so subscripts
and superscripts are rendered typographically in the PNG files.
