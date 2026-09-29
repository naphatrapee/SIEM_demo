# ingest/
Syslog listener (UDP+TCP) and per-source normalizers (`normalizers.py`).
`normalizers.py` is also imported by the backend for HTTP ingest, so all sources share one schema.
Runs as its own container (`ingest`) from the shared Python image.
