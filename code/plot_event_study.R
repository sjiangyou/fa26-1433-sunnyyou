#!/usr/bin/env Rscript

# Create Gallagher-style event-study figures for the primary NFIP outcome.
# Event time -1 is omitted from the regressions. It is inserted at zero in each
# figure as a normalization, not as an estimated coefficient.

args <- commandArgs(trailingOnly = FALSE)
script_argument <- args[grepl("^--file=", args)]
if (length(script_argument) == 0L) stop("Could not determine script location")
script <- sub("^--file=", "", script_argument[1L])
root <- normalizePath(file.path(dirname(script), ".."))

if (!requireNamespace("ggplot2", quietly = TRUE)) {
    stop("Install ggplot2 with `make setup-r` before plotting")
}

input_file <- file.path(root, "data", "derived", "model",
    "event_study_effects_translated.csv")
output_dir <- file.path(root, "output")
if (!file.exists(input_file)) stop("Missing translated effects: ", input_file)
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

effects <- utils::read.csv(input_file, stringsAsFactors = FALSE,
    check.names = FALSE)
required_columns <- c("outcome", "exposure", "event_time", "effect_type",
    "estimable", "implied_percent_change",
    "implied_percent_change_ci_lower", "implied_percent_change_ci_upper")
missing_columns <- setdiff(required_columns, names(effects))
if (length(missing_columns) > 0L) {
    stop("Translated effects table is missing: ",
        paste(missing_columns, collapse = ", "))
}

primary_outcome <- "log_new_policy_records"
effects <- effects[effects$outcome == primary_outcome, , drop = FALSE]
if (nrow(effects) == 0L) {
    stop("No effects found for the primary outcome: ", primary_outcome)
}

response_labels <- c(
    pre_response = "Floods through 2021",
    post_response = "Floods after 2021"
)
exposure_labels <- c(
    direct = "Direct flood",
    neighbor = "Nonflooded neighbor"
)
response_legend_labels <- expression(
    "Floods through 2021 (" * beta[k] * ")",
    "Floods after 2021 (" * beta[Post * "," * k] * ")"
)
exposure_legend_labels <- expression(
    "Direct flood (" * delta[k]^F * ")",
    "Nonflooded neighbor (" * delta[k]^N * ")"
)

add_reference_rows <- function(data, grouping_column, grouping_values) {
    references <- data.frame(
        event_time = rep(-1L, length(grouping_values)),
        implied_percent_change = rep(0, length(grouping_values)),
        implied_percent_change_ci_lower = rep(NA_real_, length(grouping_values)),
        implied_percent_change_ci_upper = rep(NA_real_, length(grouping_values)),
        stringsAsFactors = FALSE
    )
    references[[grouping_column]] <- grouping_values
    common_columns <- intersect(names(data), names(references))
    rbind(data[common_columns], references[common_columns])
}

gallagher_theme <- function() {
    ggplot2::theme_classic(base_size = 12) +
        ggplot2::theme(
            axis.title = ggplot2::element_text(color = "black"),
            axis.text = ggplot2::element_text(color = "black"),
            legend.position = "bottom",
            legend.title = ggplot2::element_blank(),
            legend.box.margin = ggplot2::margin(t = -4),
            plot.title = ggplot2::element_text(face = "bold", size = 13),
            plot.subtitle = ggplot2::element_text(size = 11),
            plot.caption = ggplot2::element_text(hjust = 0, size = 9),
            plot.margin = ggplot2::margin(10, 14, 10, 10)
        )
}

save_png <- function(plot, filename) {
    path <- file.path(output_dir, filename)
    ggplot2::ggsave(path, plot = plot, device = "png", width = 8,
        height = 5.5, units = "in", dpi = 300, bg = "white")
    message("Wrote ", path)
}

plot_response <- function(exposure, title, filename) {
    data <- effects[
        effects$exposure == exposure &
            effects$effect_type %in% names(response_labels) &
            effects$estimable,
        , drop = FALSE
    ]
    if (nrow(data) == 0L) stop("No estimable responses for ", exposure)
    data <- add_reference_rows(data, "effect_type", names(response_labels))
    data$series <- factor(response_labels[data$effect_type],
        levels = unname(response_labels))
    data <- data[order(data$series, data$event_time), , drop = FALSE]
    dodge <- ggplot2::position_dodge(width = 0.16)

    plot <- ggplot2::ggplot(data, ggplot2::aes(
        x = event_time,
        y = implied_percent_change,
        group = series,
        shape = series,
        linetype = series
    )) +
        ggplot2::geom_hline(yintercept = 0, color = "grey55", linewidth = 0.4) +
        ggplot2::geom_vline(xintercept = 0, color = "grey75", linewidth = 0.4) +
        ggplot2::geom_errorbar(ggplot2::aes(
            ymin = implied_percent_change_ci_lower,
            ymax = implied_percent_change_ci_upper
        ), width = 0.10, position = dodge, linewidth = 0.45,
        na.rm = TRUE) +
        ggplot2::geom_line(position = dodge, linewidth = 0.55) +
        ggplot2::geom_point(position = dodge, size = 2.4, fill = "white") +
        ggplot2::scale_shape_manual(values = c(21, 22),
            labels = response_legend_labels) +
        ggplot2::scale_linetype_manual(values = c("solid", "dashed"),
            labels = response_legend_labels) +
        ggplot2::scale_x_continuous(breaks = -3:3) +
        ggplot2::labs(
            title = title,
            subtitle = "Annual new NFIP policy records",
            x = "Event time (years)",
            y = "Implied change relative to year -1 (percent)",
            caption = paste0(
                "Notes: Points show annual county event-study estimates; bars ",
                "show 95% confidence intervals.\n",
                "The post-2021 response is the sum of the baseline and interaction ",
                "coefficients. Year -1 is omitted and normalized to zero.\n",
                "Standard errors are clustered by county."
            )
        ) +
        gallagher_theme()

    save_png(plot, filename)
}

plot_difference <- function() {
    data <- effects[
        effects$effect_type == "post_minus_pre_difference" &
            effects$exposure %in% names(exposure_labels) &
            effects$estimable,
        , drop = FALSE
    ]
    if (nrow(data) == 0L) stop("No estimable post-minus-pre differences")
    data <- add_reference_rows(data, "exposure", names(exposure_labels))
    data$series <- factor(exposure_labels[data$exposure],
        levels = unname(exposure_labels))
    data <- data[order(data$series, data$event_time), , drop = FALSE]
    dodge <- ggplot2::position_dodge(width = 0.16)

    plot <- ggplot2::ggplot(data, ggplot2::aes(
        x = event_time,
        y = implied_percent_change,
        group = series,
        shape = series,
        linetype = series
    )) +
        ggplot2::geom_hline(yintercept = 0, color = "grey55", linewidth = 0.4) +
        ggplot2::geom_vline(xintercept = 0, color = "grey75", linewidth = 0.4) +
        ggplot2::geom_errorbar(ggplot2::aes(
            ymin = implied_percent_change_ci_lower,
            ymax = implied_percent_change_ci_upper
        ), width = 0.10, position = dodge, linewidth = 0.45,
        na.rm = TRUE) +
        ggplot2::geom_line(position = dodge, linewidth = 0.55) +
        ggplot2::geom_point(position = dodge, size = 2.4, fill = "white") +
        ggplot2::scale_shape_manual(values = c(21, 24),
            labels = exposure_legend_labels) +
        ggplot2::scale_linetype_manual(values = c("solid", "dashed"),
            labels = exposure_legend_labels) +
        ggplot2::scale_x_continuous(breaks = -3:3) +
        ggplot2::labs(
            title = "Figure 3. Change in flood response after Risk Rating 2.0",
            subtitle = "Post-2021 response minus response to floods through 2021",
            x = "Event time (years)",
            y = "Implied post-minus-pre difference (percent)",
            caption = paste0(
                "Notes: Points show annual county event-study interactions; bars ",
                "show 95% confidence intervals.\n",
                "The plotted interaction coefficients are post-minus-pre differences. ",
                "Year -1 is omitted and normalized to zero.\n",
                "Standard errors are clustered by county."
            )
        ) +
        gallagher_theme()

    save_png(plot, "event_study_post_minus_pre.png")
}

plot_response(
    exposure = "direct",
    title = "Figure 1. Flood insurance take-up after a direct flood",
    filename = "event_study_direct_flood.png"
)
plot_response(
    exposure = "neighbor",
    title = "Figure 2. Flood insurance take-up near a flood",
    filename = "event_study_neighbor_flood.png"
)
plot_difference()
message("Completed Gallagher-style event-study figures")
