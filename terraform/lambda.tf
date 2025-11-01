data "archive_file" "ingest_zip" {
  type        = "zip"
  source_file = "${path.module}/../lambdas/ingest-go/bootstrap"
  output_path = "${path.module}/.build/ingest.zip"
}

resource "aws_lambda_function" "ingest" {
  function_name = "${var.project_name}-ingest"
  role          = aws_iam_role.lambda_role.arn
  architectures = ["arm64"]
  runtime       = "provided.al2023"
  handler       = "bootstrap"
  filename      = data.archive_file.ingest_zip.output_path
  source_code_hash = data.archive_file.ingest_zip.output_base64sha256
  timeout       = 15
  environment {
    variables = {
      RAW_BUCKET = aws_s3_bucket.raw.bucket
    }
  }
  tags = var.tags
}

data "archive_file" "dq_zip" {
  type        = "zip"
  source_file = "${path.module}/../lambdas/dq-check-go/bootstrap"
  output_path = "${path.module}/.build/dq.zip"
}

resource "aws_lambda_function" "dq_check" {
  function_name = "${var.project_name}-dq-check"
  role          = aws_iam_role.lambda_role.arn
  architectures = ["arm64"]
  runtime       = "provided.al2023"
  handler       = "bootstrap"
  filename      = data.archive_file.dq_zip.output_path
  source_code_hash = data.archive_file.dq_zip.output_base64sha256
  timeout       = 60
  environment {
    variables = {
      ATHENA_WORKGROUP = aws_athena_workgroup.wg.name
      ATHENA_OUTPUT    = "s3://${aws_s3_bucket.athena_results.bucket}/results/"
      GLUE_DB          = aws_glue_catalog_database.db.name
    }
  }
  tags = var.tags
}

