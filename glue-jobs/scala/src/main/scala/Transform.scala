package com.glucosestream

import com.amazonaws.services.glue.GlueContext
import org.apache.spark.SparkContext
import com.amazonaws.services.glue.util.Job
import com.amazonaws.services.glue.util.GlueArgParser
import org.apache.spark.sql.functions._

object Transform {
  def main(sysArgs: Array[String]): Unit = {
    val args = GlueArgParser.getResolvedOptions(sysArgs, Seq("JOB_NAME", "RAW_PATH", "CURATED_PATH").toArray)
    val sparkContext: SparkContext = new SparkContext()
    val glueContext: GlueContext = new GlueContext(sparkContext)
    val spark = glueContext.getSparkSession
    Job.init(args("JOB_NAME"), glueContext, args)

    val rawPath = args("RAW_PATH")
    val curatedPath = args("CURATED_PATH")

    val df = spark.read.json(rawPath)
      .withColumn("event_ts", to_timestamp(col("event_time")))
      .withColumn("metric_date", to_date(col("event_ts")))

    df.repartition(col("metric_date"), col("patient_id"))
      .write
      .mode("overwrite")
      .partitionBy("metric_date", "patient_id")
      .parquet(curatedPath + "/events/")

    Job.commit()
  }
}

