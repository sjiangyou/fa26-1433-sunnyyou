#!/usr/bin/env python3
"""Download the raw FEMA/NFIP inputs for the flood-insurance project.

The files are deliberately downloaded without transformations into data/raw.
Run from the repository root:

    python code/download_fema_nfip_data.py

The NFIP policy extract is large (~30 GB) and is not downloaded again when the
existing file is present. FEMA may revise these endpoints, so the URLs and
retrieval date are recorded in data/raw/SOURCES.md.
"""

from pathlib import Path
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "data" / "raw"
RAW.mkdir(parents=True, exist_ok=True)

FILES = {
    # One row per designated county/tribal area and declaration.
    "DisasterDeclarationsSummariesV2.csv": "https://www.fema.gov/api/open/v2/DisasterDeclarationsSummaries.csv",
    # One row per redacted NFIP claim transaction. FEMA's current claims
    # dataset is NfipClaims v3; the former FimaNfipClaims v2 endpoint returns
    # 404 and should not be used for new downloads.
    "NfipClaimsV3.csv": "https://www.fema.gov/api/open/v3/NfipClaims.csv",
    # Existing project input; retained under this filename for compatibility.
    "FimaNfipPoliciesV2.csv": "https://www.fema.gov/api/open/v2/FimaNfipPolicies.csv",
}

def download(name: str, url: str) -> None:
    target = RAW / name
    if target.exists() and target.stat().st_size > 0:
        with target.open("rb") as existing:
            prefix = existing.read(2000)
        if b"Invalid mode" not in prefix:
            print(f"exists: {target} ({target.stat().st_size:,} bytes); skipping")
            return
        print(f"removing invalid API response: {target}")
        target.unlink()

    partial = target.with_suffix(target.suffix + ".part")
    print(f"downloading: {url}")
    request = Request(url, headers={"User-Agent": "fa26-1433-sunnyyou research"})
    with urlopen(request, timeout=60) as response, partial.open("wb") as out:
        first_chunk = response.read(1024 * 1024)
        out.write(first_chunk)
        while chunk := response.read(1024 * 1024):
            out.write(chunk)
    partial.replace(target)
    print(f"saved: {target} ({target.stat().st_size:,} bytes)")


if __name__ == "__main__":
    for filename, url in FILES.items():
        download(filename, url)
