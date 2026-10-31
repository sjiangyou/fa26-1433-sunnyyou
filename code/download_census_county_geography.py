#!/usr/bin/env python3
"""Download Census county geography used to construct neighbor measures."""

from pathlib import Path
from urllib.request import Request, urlopen


ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "data" / "raw" / "census"
URL = (
    "https://www2.census.gov/geo/docs/maps-data/data/gazetteer/"
    "2024_Gazetteer/2024_Gaz_counties_national.zip"
)
TARGET = RAW / "2024_Gaz_counties_national.zip"


def download() -> None:
    if TARGET.exists() and TARGET.stat().st_size > 0:
        print(f"exists: {TARGET}; skipping")
        return
    RAW.mkdir(parents=True, exist_ok=True)
    request = Request(URL, headers={"User-Agent": "fa26-1433-sunnyyou research"})
    with urlopen(request, timeout=60) as response:
        TARGET.write_bytes(response.read())
    print(f"saved: {TARGET} ({TARGET.stat().st_size:,} bytes)")


if __name__ == "__main__":
    download()
