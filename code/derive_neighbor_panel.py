#!/usr/bin/env python3
"""Create a positive-length county-border neighbor crosswalk.

The Census TIGER/Line county shapefile stores county boundaries as polygon
segments. Shared segments are identified by matching their endpoints, so
counties that only meet at a point are excluded.
"""

import csv
import math
import struct
import zipfile
from collections import defaultdict
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "data" / "raw" / "census"
DERIVED = ROOT / "data" / "derived"
TIGER_ZIP = RAW / "tl_2024_us_county.zip"


def read_polygon_segments(shapefile: Path):
    """Yield (county_fips, endpoint_a, endpoint_b) for each polygon edge."""
    with shapefile.open("rb") as source:
        source.seek(100)
        while True:
            record_header = source.read(8)
            if not record_header:
                break
            if len(record_header) != 8:
                raise ValueError("Incomplete shapefile record header")
            _, content_length_words = struct.unpack(">ii", record_header)
            content = source.read(content_length_words * 2)
            shape_type = struct.unpack("<i", content[:4])[0]
            if shape_type == 0:
                continue
            if shape_type != 5:
                raise ValueError(f"Expected polygon records, found type {shape_type}")
            _, _, _, _, num_parts, num_points = struct.unpack(
                "<4d2i", content[4:44]
            )
            parts = struct.unpack(
                f"<{num_parts}i", content[44 : 44 + 4 * num_parts]
            )
            points_start = 44 + 4 * num_parts
            points = [
                struct.unpack("<2d", content[offset : offset + 16])
                for offset in range(points_start, points_start + 16 * num_points, 16)
            ]
            yield parts, points


def read_dbf_fips(dbf_file: Path):
    """Read GEOID values from the DBF records in shapefile order."""
    with dbf_file.open("rb") as source:
        header = source.read(32)
        if len(header) != 32:
            raise ValueError("Incomplete DBF header")
        _, _, _, _, record_count, header_length, record_length = struct.unpack(
            "<BBBBLHH20x", header
        )
        fields = []
        for _ in range((header_length - 33) // 32):
            field = source.read(32)
            name = field[:11].split(b"\0", 1)[0].decode("ascii")
            length = field[16]
            fields.append((name, length))
        source.read(1)
        geoid_index = next(
            (index for index, (name, _) in enumerate(fields) if name == "GEOID"),
            None,
        )
        if geoid_index is None:
            raise ValueError("GEOID field not found in county DBF")
        fips = []
        for _ in range(record_count):
            record = source.read(record_length)
            values = []
            offset = 1
            for _, length in fields:
                values.append(record[offset : offset + length].decode("latin-1").strip())
                offset += length
            fips.append(values[geoid_index])
        return fips


def canonical_point(point):
    """Round coordinates to stabilize matching across shapefile records."""
    return tuple(round(value, 10) for value in point)


def segment_length_miles(first, second):
    """Calculate great-circle segment length from longitude/latitude points."""
    lon1, lat1 = map(math.radians, first)
    lon2, lat2 = map(math.radians, second)
    half_angle = math.sin((lat2 - lat1) / 2) ** 2
    half_angle += math.cos(lat1) * math.cos(lat2) * math.sin((lon2 - lon1) / 2) ** 2
    return 3958.7613 * 2 * math.asin(math.sqrt(min(1.0, half_angle)))


def find_shapefile(extract_dir: Path):
    shapefiles = list(extract_dir.rglob("*.shp"))
    if len(shapefiles) != 1:
        raise ValueError("Expected exactly one county shapefile in the TIGER archive")
    return shapefiles[0], shapefiles[0].with_suffix(".dbf")


def build_crosswalk():
    if not TIGER_ZIP.exists():
        raise FileNotFoundError(f"Missing Census TIGER county file: {TIGER_ZIP}")
    extract_dir = RAW / "tl_2024_us_county"
    extract_dir.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(TIGER_ZIP) as archive:
        archive.extractall(extract_dir)
    shapefile, dbf = find_shapefile(extract_dir)
    fips = read_dbf_fips(dbf)
    segment_counties = defaultdict(set)
    with shapefile.open("rb") as source:
        source.seek(100)
        record_index = 0
        while True:
            header = source.read(8)
            if not header:
                break
            _, content_length_words = struct.unpack(">ii", header)
            content = source.read(content_length_words * 2)
            shape_type = struct.unpack("<i", content[:4])[0]
            if shape_type == 0:
                record_index += 1
                continue
            if shape_type != 5:
                raise ValueError(f"Expected polygon records, found type {shape_type}")
            _, _, _, _, num_parts, num_points = struct.unpack("<4d2i", content[4:44])
            parts = struct.unpack(
                f"<{num_parts}i", content[44 : 44 + 4 * num_parts]
            )
            points_start = 44 + 4 * num_parts
            points = [
                struct.unpack("<2d", content[offset : offset + 16])
                for offset in range(points_start, points_start + 16 * num_points, 16)
            ]
            county = fips[record_index]
            for part_index, start in enumerate(parts):
                end = parts[part_index + 1] if part_index + 1 < len(parts) else num_points
                ring = points[start:end]
                for first, second in zip(ring, ring[1:]):
                    first_key = canonical_point(first)
                    second_key = canonical_point(second)
                    if first_key == second_key:
                        continue
                    segment_key = tuple(sorted((first_key, second_key)))
                    segment_counties[segment_key].add(county)
            record_index += 1

    rows = []
    for segment, counties in segment_counties.items():
        all_counties = sorted(counties)
        if len(all_counties) < 2:
            continue
        distance = segment_length_miles(segment[0], segment[1])
        if distance <= 0:
            continue
        for county in all_counties:
            for neighbor in sorted(counties):
                if neighbor != county:
                    rows.append((county, neighbor, distance))

    pair_lengths = defaultdict(float)
    for county, neighbor, distance in rows:
        pair_lengths[(county, neighbor)] += distance
    DERIVED.mkdir(parents=True, exist_ok=True)
    output = DERIVED / "county_neighbors.csv"
    with output.open("w", newline="") as target:
        writer = csv.writer(target)
        writer.writerow(["county_fips", "neighbor_fips", "shared_boundary_miles"])
        for (county, neighbor), distance in sorted(pair_lengths.items()):
            writer.writerow([county, neighbor, distance])
    print(f"Wrote {output} with {len(pair_lengths)} positive-length county-border pairs")


if __name__ == "__main__":
    build_crosswalk()
