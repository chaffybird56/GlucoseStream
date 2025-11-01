# ERD — GlucoseStream

```mermaid
erDiagram
  PATIENTS ||--o{ SESSIONS : has
  PATIENTS ||--o{ METRICS : has
  SESSIONS ||--o{ GLUCOSE_EVENTS : contains
  DEVICES ||--o{ SESSIONS : used_by
  GLUCOSE_EVENTS ||--o{ ALERTS : triggers

  PATIENTS {
    string patient_id PK
    string cohort_id
    date   birth_date
  }
  DEVICES {
    string device_id PK
    string manufacturer
    string model
  }
  SESSIONS {
    string session_id PK
    string patient_id FK
    string device_id FK
    timestamp start_time
    timestamp end_time
  }
  GLUCOSE_EVENTS {
    string  event_id PK
    string  session_id FK
    string  patient_id FK
    timestamp event_time
    double  mg_dL
    string  source  // sensor, fingerstick, derived
  }
  METRICS {
    string  metric_id PK
    string  patient_id FK
    date    metric_date
    double  tir_70_180
    double  gmi
    double  cv
  }
  ALERTS {
    string  alert_id PK
    string  patient_id FK
    timestamp alert_time
    string  kind // hypo_risk, hyper_streak, variability
    string  severity // info, warn, critical
  }
```

Notes
- Use hashed `patient_id` to avoid PII.
- Raw events are immutable in `raw/` S3. Curated tables in `curated/` are Parquet partitioned by `metric_date` and `patient_id`.
- Metrics are computed by Athena and optionally materialized to `curated/metrics/`.


