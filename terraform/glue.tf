resource "aws_glue_catalog_database" "db" {
  name = replace(var.project_name, "-", "_")
}

resource "aws_glue_crawler" "raw" {
  name          = "${var.project_name}-raw-crawler"
  role          = aws_iam_role.glue_role.arn
  database_name = aws_glue_catalog_database.db.name

  s3_target {
    path = "s3://${aws_s3_bucket.raw.bucket}/"
  }

  configuration = jsonencode({
    Version = 1.0,
    CrawlerOutput = { Partitions = { AddOrUpdateBehavior = "InheritFromTable" } }
  })
  tags = var.tags
}

resource "aws_glue_crawler" "curated" {
  name          = "${var.project_name}-curated-crawler"
  role          = aws_iam_role.glue_role.arn
  database_name = aws_glue_catalog_database.db.name

  s3_target {
    path = "s3://${aws_s3_bucket.curated.bucket}/"
  }
  configuration = jsonencode({ Version = 1.0 })
  tags          = var.tags
}

