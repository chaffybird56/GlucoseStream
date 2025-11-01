# Cost Notes — GlucoseStream

Guidelines to keep costs minimal:

- Storage
  - Raw zone: JSON/CSV; Curated: Parquet + compression (Snappy, ZSTD) for Athena efficiency.
  - Partition curated data by `metric_date` and optionally `patient_id` to prune scans.
- Compute
  - Prefer ELT with Athena over always-on Spark clusters.
  - Use `ctas` (CREATE TABLE AS SELECT) for one-time heavy transforms.
  - Use Athena Workgroups with enforced query limits and per-query bytes scanned.
- Glue
  - Schedule crawlers to run on-demand (triggered by Step Functions) instead of cron.
- Lambda
  - Keep Lambdas small; reuse connections; set timeouts sensible; use ARM64 where possible.
- QuickSight
  - Use SPICE where it makes sense; otherwise connect live to Athena for small teams.
- Monitoring
  - Export Athena/Glue metrics to CloudWatch; alert on unusual query bytes scanned.
- Environments
  - Separate dev/stage/prod buckets and workgroups. Enable bucket lifecycle rules for old data.

Rough Estimation (low-usage dev)
- S3: <$5/month for GBs of data with lifecycle to STANDARD_IA/GLACIER.
- Athena: <$10/month assuming light exploration (tens of GB scanned).
- Glue Crawler: cents to a few dollars depending on runs.
- Lambda + Step Functions: cents to a few dollars for dev.

These are ballpark; production depends on data volume, usage, and retention.

