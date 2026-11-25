# Reproducible entry points for the fa26-1433-sunnyyou research project.
#
# The complete implemented workflow includes raw-data acquisition, derived
# panels, and annual event-study estimation.

PYTHON ?= .venv/bin/python
Rscript ?= Rscript

.PHONY: all help setup-python setup-r download-fema download-acs download-geography download-raw derive-policy derive-flood derive-neighbors derive-analysis derive estimate-model estimate-model-no-2021 translate-coefficients translate-coefficients-no-2021 plot-figures

all: setup-python setup-r download-raw derive estimate-model estimate-model-no-2021 translate-coefficients translate-coefficients-no-2021 plot-figures

help:
	@printf '%s\n' \
		'make all          Run the complete workflow through figure creation' \
		'make setup-python Prepare the Python environment' \
		'make setup-r      Create/restore the R renv environment' \
		'make download-fema Download FEMA declarations, claims, and policies' \
		'make download-acs Download ACS county controls' \
		'make download-geography Download Census county geography' \
		'make download-raw Download all configured raw data' \
		'make derive       Create all derived analysis panels' \
		'make estimate-model Estimate the annual flood event-study models' \
		'make estimate-model-no-2021 Estimate models without 2021 observations' \
		'make translate-coefficients Translate model coefficients into percentage changes' \
		'make translate-coefficients-no-2021 Translate the no-2021 estimates' \
		'make plot-figures Create Gallagher-style event-study PNG figures'

setup-python:
	@if [ ! -x "$(PYTHON)" ]; then \
		command -v python3 >/dev/null || \
			(echo 'Python 3 is required but was not found.' >&2; exit 1); \
		python3 -m venv .venv; \
	fi
	@$(PYTHON) --version

setup-r:
	@command -v $(Rscript) >/dev/null || \
		(echo 'Rscript is required but was not found.' >&2; exit 1)
	@$(Rscript) code/setup_r_environment.R

download-fema:
	@$(PYTHON) code/download_fema_nfip_data.py

download-acs:
	@if [ ! -f .env ]; then \
		echo 'Missing .env; add CENSUS_API_KEY before downloading ACS data.' >&2; \
		exit 1; \
	fi
	@set -a; . ./.env; set +a; $(PYTHON) code/download_census_controls.py

download-geography:
	@$(PYTHON) code/download_census_county_geography.py

download-raw: download-fema download-acs download-geography

derive-policy: download-fema
	@$(Rscript) code/derive_policy_panel.R

derive-flood: download-fema
	@$(Rscript) code/derive_flood_panel.R

derive-neighbors: download-geography
	@$(PYTHON) code/derive_neighbor_panel.py

derive-analysis: derive-policy derive-flood derive-neighbors download-acs
	@$(Rscript) code/derive_analysis_panel.R

derive: derive-analysis

estimate-model: derive-analysis
	@$(Rscript) code/estimate_model.R

estimate-model-no-2021: derive-analysis
	@$(Rscript) code/estimate_model_no_2021.R

translate-coefficients: estimate-model
	@$(Rscript) code/translate_coefficients.R

translate-coefficients-no-2021: estimate-model-no-2021
	@$(Rscript) code/translate_coefficients_no_2021.R

plot-figures: translate-coefficients
	@$(Rscript) code/plot_event_study.R
