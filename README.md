GlucoseStream AWS — Serverless Data Lake & ETL/ELT for Glucose Analytics

[![Build Status](https://img.shields.io/github/actions/workflow/status/chaffybird56/GlucoseStream/ci.yml?label=CI&logo=github)](https://github.com/chaffybird56/GlucoseStream/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
![Go](https://img.shields.io/badge/Go-1.22-00ADD8?logo=go)
![Terraform](https://img.shields.io/badge/Terraform-1.5+-623CE4?logo=terraform)
![AWS](https://img.shields.io/badge/AWS-Serverless-orange?logo=amazon-aws)

Overview
GlucoseStream is a production‑minded, serverless analytics stack for continuous glucose monitoring (CGM)–like data. It ingests timestamped glucose events, lands them in Amazon S3, catalogs with AWS Glue, transforms and queries with Amazon Athena (ELT-first), orchestrates with AWS Step Functions and Lambda, and visualizes insights with either Amazon QuickSight or a lightweight Flask dashboard.

Why this matters
- Patients and clinicians need actionable, privacy‑aware insights like time‑in‑range (TIR), hypoglycemia/hyperglycemia risk, glucose variability, and daily patterns.
- The platform demonstrates industry‑grade patterns: IaC with Terraform, streaming ingestion, ELT via Athena, data quality gates, cost controls, CI/CD, and extensible analytics (SQL + Lambda + optional Scala Spark).

Key Capabilities
- Ingestion: REST-style Lambda (Go) to land JSON events to S3 raw zone; optional sample data generator (Go) for local simulation.
- Cataloging: AWS Glue database and crawlers for raw and curated zones.
- Transform/Query: Athena SQL to create external tables, curated views, and patient metrics (TIR, GMI, variability, streaks, circadian plots).
- Orchestration: Step Functions triggers Glue crawler → Athena transforms → data-quality Lambda → publish curated/metrics to S3.
- Visualization: QuickSight dataset or a local Flask dashboard with Plotly charts and a differential privacy (DP) toggle.
- Data Quality: SQL checks plus a Lambda (Go) that fails the workflow and optionally publishes alerts via SNS.
- Privacy: Differential Privacy noise injection for shared/aggregate metrics in the dashboard.

Tech Stack
- Languages: Go (Lambdas, generator), SQL (Athena). Optional Scala Spark job scaffold included.
- AWS: S3, Glue, Athena, Step Functions, Lambda, IAM, SNS (optional), API Gateway (optional).
- IaC: Terraform.
- CI/CD: GitHub Actions (Terraform fmt/validate, Go build, Python lint/test).

Table of Contents
- [Overview](#overview)
- [Quickstart](#quickstart)
- [Screenshots & Interpretation](#screenshots--interpretation)
- [Tests](#tests)
- [Data Model & ERD](#data-model--erd)
- [Security & Compliance](#security--compliance)
- [Cost Notes](#cost-notes)
- [Local Development](#local-development)
- [License](#license)

Screenshots & Interpretation
![Dashboard Patient View](docs/screenshots/dashboard_patient_view.svg)

How to read the charts:
- Mean Glucose: stable around 110–120 mg/dL is a healthy trend for many patients.
- TIR (70–180): higher values indicate better control; aim > 70% in many guidelines.
- CV: lower values indicate reduced glycemic variability; aim < 36%.
- GMI: an estimate of A1c from mean glucose; falling GMI can reflect improving control.

![Pipeline Orchestration](docs/screenshots/pipeline_state_machine.svg)
- The state machine runs Glue crawler → Athena table creation → transformations → DQ checks. Failures stop the pipeline, prompting a fix before data is published.

Repository Layout
```
GlucoseStream/
  terraform/
  lambdas/
    ingest-go/
    dq-check-go/
  data-generator/
  analytics/sql/
  flask-dashboard/
  docs/
  .github/workflows/
```

Quickstart
1) Bootstrap AWS resources (Terraform)
- Prereqs: AWS account/credentials, Terraform >= 1.5, Go 1.22+
```
make build-lambdas
cd terraform
terraform init
terraform apply -auto-approve
```
This creates S3 buckets (raw/curated/temp), Glue database + crawler, Athena workgroup, Step Functions state machine, and Lambda functions.

2) Generate sample events (optional, local)
```
cd data-generator
go run ./...
```
This produces sample CGM events. You can upload them to the raw S3 bucket via AWS CLI or invoke the ingest Lambda via API Gateway (if enabled) or Lambda test event.

3) Run the pipeline
- Start the Step Functions state machine from the AWS Console (or CLI) to crawl, transform, and compute metrics.

4) Explore data
- QuickSight: point to the Athena curated/metrics tables created by SQL in analytics/sql.
- Flask dashboard (local):
```
cd flask-dashboard
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
FLASK_APP=app.py flask run
```
Configure environment variables in .env (see flask-dashboard/README snippet inside app.py) for AWS region and S3/Athena settings.

Tests
Run the cross‑stack smoke tests (Go + Flask):
```
make test
```
What this verifies:
- Data generator circadian baseline stays within reasonable physiological ranges and changes smoothly hour‑to‑hour.
- Flask routes render correctly (index and patient view), with Athena calls safely monkeypatched.

Sample output:
```
=== RUN   TestCircadianBaseReasonableRange
--- PASS: TestCircadianBaseReasonableRange (0.00s)
=== RUN   TestCircadianBaseSmoothness
--- PASS: TestCircadianBaseSmoothness (0.00s)
PASS
ok  	glucosestream/data-generator	0.15s

..                                                                       [100%]
2 passed in 0.34s
```

Data Model & ERD
- See docs/ERD.md (Mermaid diagram) for entities: patients, devices, glucose_events, sessions, metrics, alerts.

Security & Compliance
- Buckets use server-side encryption; IAM roles scoped by least privilege.
- PII is excluded from raw events by default; use hashed patient IDs.
- Differential privacy is available in the dashboard for aggregate sharing.

Cost Notes
- Athena queries are compressed/partition-aware; prefer Parquet for curated data.
- Crawler schedules and Step Functions are event-driven, reducing idle costs.
- See docs/COSTS.md for tips.

Local Development
- Go 1.21+, Python 3.10+ recommended.
- Makefile includes common tasks (build, test, fmt) when present.

License
MIT


