# Architecture — GlucoseStream

Flow
- Ingest → S3 raw → Glue catalog → Athena transforms → curated Parquet → metrics → dashboard
- Step Functions orchestrates end-to-end with quality gates and optional alerts.

Components
- S3: `raw/`, `curated/`, `athena-results/`
- Glue: Database `glucosestream_db`, Crawlers for raw and curated
- Athena: External tables over raw JSON and curated Parquet; views for metrics
- Lambda (Go):
  - `ingest` — accepts glucose events and writes to `raw/` (optionally via API GW)
  - `dq_check` — runs DQ SQL via Athena; fails state machine on threshold breaches; can publish SNS
- Step Functions: State machine JSON triggers crawler → runs Athena DDL/DML queries → executes DQ Lambda → success/fail
- Flask dashboard: reads metrics (from S3 or live Athena), renders Plotly charts; optional DP noise for aggregates

Security
- SSE-S3 encryption on buckets; least-privilege IAM for Lambda/Athena/Glue; VPC endpoints optional.
- No PII in events; hashed `patient_id` only. Audit logs via CloudTrail.

Extensibility
- Add Scala Spark job for advanced feature engineering.
- Add Kinesis/DataFirehose for true streaming if needed.
- Add Lake Formation for access controls at table/column level.

