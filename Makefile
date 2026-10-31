# Reproducible entry points for the fa26-1433-sunnyyou research project.
#
# The current repository contains raw-data acquisition code. The derive,
# analyze, plots, and paper stages will be added when their scripts exist.

PYTHON ?= .venv/bin/python
Rscript ?= Rscript

.PHONY: all help setup-python setup-r download-fema download-acs download-geography download-raw derive-policy derive-flood derive-neighbors derive-analysis derive

all: setup-python setup-r download-raw derive

help:
	@printf '%s\n' \
		'make all          Set up environments, download raw data, and derive panels' \
		'make setup-python Prepare the Python environment' \
		'make setup-r      Create/restore the R renv environment' \
		'make download-fema Download FEMA declarations, claims, and policies' \
		'make download-acs Download ACS county controls' \
		'make download-geography Download Census county geography' \
		'make download-raw Download all configured raw data' \
		'make derive       Create all derived analysis panels'

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
	@$(Rscript) code/derive_neighbor_panel.R

derive-analysis: derive-policy derive-flood derive-neighbors download-acs
	@$(Rscript) code/derive_analysis_panel.R

derive: derive-analysis
