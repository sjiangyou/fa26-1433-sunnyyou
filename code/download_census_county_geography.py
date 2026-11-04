#!/usr/bin/env python3
"""Download Census county geography used to construct neighbor measures."""

from pathlib import Path
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "data" / "raw" / "census"
GAZETTEER_URL = (
    "https://www2.census.gov/geo/docs/maps-data/data/gazetteer/"
    "2024_Gazetteer/2024_Gaz_counties_national.zip"
)
GAZETTEER_TARGET = RAW / "2024_Gaz_counties_national.zip"
TIGER_URL = "https://www2.census.gov/geo/tiger/TIGER2024/COUNTY/tl_2024_us_county.zip"
TIGER_TARGET = RAW / "tl_2024_us_county.zip"


def download_file(url: str, target: Path) -> None:
    if target.exists() and target.stat().st_size > 0:
        print(f"exists: {target}; skipping")
        return
    RAW.mkdir(parents=True, exist_ok=True)
    request = Request(url, headers={"User-Agent": "fa26-1433-sunnyyou research"})
    with urlopen(request, timeout=60) as response:
        target.write_bytes(response.read())
    print(f"saved: {target} ({target.stat().st_size:,} bytes)")


def download() -> None:
    download_file(GAZETTEER_URL, GAZETTEER_TARGET)
    download_file(TIGER_URL, TIGER_TARGET)


if __name__ == "__main__":
    download()
