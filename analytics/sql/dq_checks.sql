-- Data Quality Ad-hoc Queries (executed by Lambda)

-- 1) Check null/invalid timestamps
SELECT COUNT(*) AS invalid_ts
FROM ${GLUE_DB}.raw_glucose_events
WHERE event_time IS NULL;

-- 2) Check physiologic range (40-400 mg/dL)
SELECT COUNT(*) AS out_of_range
FROM ${GLUE_DB}.raw_glucose_events
WHERE mg_dL < 40 OR mg_dL > 400;

-- 3) Duplicate event ids
SELECT COUNT(*) AS dup_count FROM (
  SELECT event_id FROM ${GLUE_DB}.raw_glucose_events GROUP BY event_id HAVING COUNT(*) > 1
);


