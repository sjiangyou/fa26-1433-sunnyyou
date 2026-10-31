#!/usr/bin/env python3
"""Download annual ACS county controls used to normalize NFIP take-up."""

import json
import os
from pathlib import Path
from urllib.parse import urlencode
from urllib.request import Request, urlopen


ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "data" / "raw" / "census"
YEARS = range(2015, 2025)
VARIABLES = "NAME,B01001_001E,B25001_001E,B19013_001E"


def build_url(year: int) -> str:
    """Build the ACS request URL using the key supplied by the environment."""
    api_key = os.environ.get("CENSUS_API_KEY")
    if not api_key:
        raise RuntimeError(
            "CENSUS_API_KEY is not set. Add it to .env or export it before "
            "running the Census download."
        )

    query = urlencode(
        {
            "get": VARIABLES,
            "for": "county:*",
            "key": api_key,
        }
    )
    return f"https://api.census.gov/data/{year}/acs/acs5?{query}"


def download_year(year: int) -> None:
    target = RAW / f"acs5_county_controls_{year}.json"
    if target.exists() and target.stat().st_size > 0:
        print(f"exists: {target}; skipping")
        return

    url = build_url(year)
    request = Request(url, headers={"User-Agent": "fa26-1433-sunnyyou research"})
    RAW.mkdir(parents=True, exist_ok=True)
    with urlopen(request, timeout=60) as response:
        payload = response.read()
    json.loads(payload)
    target.write_bytes(payload)
    print(f"saved: {target} ({target.stat().st_size:,} bytes)")


if __name__ == "__main__":
    for year in YEARS:
        download_year(year)
