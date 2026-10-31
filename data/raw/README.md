# Raw data

Store original, unmodified source data here. These files are ignored by Git by default. Document each source, access date, and any instructions needed to obtain the data.

See [SOURCES.md](SOURCES.md) for the FEMA/NFIP and Census inventory and the
repository `Makefile` for reproducible acquisition.

The ACS county-controls download requires a Census API key in a local `.env`
file as `CENSUS_API_KEY=...`. The key is used at runtime and must not be
committed.
