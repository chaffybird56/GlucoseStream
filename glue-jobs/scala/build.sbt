ThisBuild / version := "0.1.0"
ThisBuild / scalaVersion := "2.12.18"
ThisBuild / organization := "com.glucosestream"

libraryDependencies ++= Seq(
  "com.amazonaws" % "AWSGlueETL" % "3.0.0" % "provided",
  "org.apache.spark" %% "spark-sql" % "3.3.0" % "provided"
)

Compile / packageBin / packageOptions += Package.ManifestAttributes(
  "Main-Class" -> "com.glucosestream.Transform"
)

