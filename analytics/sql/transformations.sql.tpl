-- Curate raw events into partitioned Parquet and compute daily metrics

-- 1) Curated events as Parquet with partitions
CREATE TABLE IF NOT EXISTS ${GLUE_DB}.curated_glucose_events
WITH (
  format = 'PARQUET',
  parquet_compression = 'SNAPPY',
  external_location = 's3://${CURATED_BUCKET}/events/',
  partitioned_by = ARRAY['metric_date', 'patient_id']
) AS
SELECT
  event_id,
  patient_id,
  session_id,
  from_iso8601_timestamp(event_time) AS event_ts,
  CAST(mg_dL AS DOUBLE) AS mg_dL,
  source,
  CAST(date(from_iso8601_timestamp(event_time)) AS DATE) AS metric_date
FROM ${GLUE_DB}.raw_glucose_events
WHERE event_time IS NOT NULL;

MSCK REPAIR TABLE ${GLUE_DB}.curated_glucose_events;

-- 2) Daily metrics per patient
CREATE TABLE IF NOT EXISTS ${GLUE_DB}.metrics_daily
WITH (
  format = 'PARQUET',
  parquet_compression = 'SNAPPY',
  external_location = 's3://${CURATED_BUCKET}/metrics_daily/',
  partitioned_by = ARRAY['metric_date', 'patient_id']
) AS
WITH base AS (
  SELECT patient_id, metric_date, mg_dL
  FROM ${GLUE_DB}.curated_glucose_events
)
SELECT
  patient_id,
  metric_date,
  AVG(mg_dL) AS mean_glucose,
  -- Time in Range (70-180)
  AVG(CASE WHEN mg_dL BETWEEN 70 AND 180 THEN 1 ELSE 0 END) AS tir_70_180,
  -- Coefficient of Variation
  CASE WHEN STDDEV_SAMP(mg_dL) IS NULL OR AVG(mg_dL) = 0 THEN NULL
       ELSE STDDEV_SAMP(mg_dL) / NULLIF(AVG(mg_dL),0) END AS cv,
  -- GMI (%): 3.31 + 0.02392 * mean_glucose
  3.31 + 0.02392 * AVG(mg_dL) AS gmi
FROM base
GROUP BY patient_id, metric_date;

MSCK REPAIR TABLE ${GLUE_DB}.metrics_daily;


