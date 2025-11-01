-- Create external table over raw JSON events (ingest writes to s3://${RAW_BUCKET}/events/)
CREATE DATABASE IF NOT EXISTS ${GLUE_DB};

CREATE EXTERNAL TABLE IF NOT EXISTS ${GLUE_DB}.raw_glucose_events (
  event_id    string,
  patient_id  string,
  session_id  string,
  event_time  string,
  mg_dL       double,
  source      string
)
ROW FORMAT SERDE 'org.openx.data.jsonserde.JsonSerDe'
WITH SERDEPROPERTIES (
  'ignore.malformed.json' = 'true'
)
LOCATION 's3://${RAW_BUCKET}/events/'
TBLPROPERTIES ('classification'='json');

-- Optional curated table placeholders to be created by CTAS in transformations
-- Views can be created later once CTAS completes

