data "aws_iam_policy_document" "assume_role_sfn" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["states.${var.aws_region}.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "sfn_role" {
  name               = "${var.project_name}-sfn-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role_sfn.json
  tags               = var.tags
}

resource "aws_iam_role_policy" "sfn_policy" {
  name = "${var.project_name}-sfn-policy"
  role = aws_iam_role.sfn_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "lambda:InvokeFunction",
          "glue:StartCrawler",
          "glue:GetCrawler",
          "athena:StartQueryExecution",
          "athena:GetQueryExecution"
        ],
        Resource = "*"
      }
    ]
  })
}

locals {
  state_machine_definition = jsonencode({
    Comment = "GlucoseStream Orchestration",
    StartAt = "StartRawCrawler",
    States = {
      StartRawCrawler = {
        Type = "Task",
        Resource = "arn:aws:states:::aws-sdk:glue:startCrawler",
        Parameters = { Name = aws_glue_crawler.raw.name },
        Next = "WaitForCrawl"
      },
      WaitForCrawl = {
        Type = "Wait",
        Seconds = 30,
        Next = "CreateTables"
      },
      CreateTables = {
        Type = "Task",
        Resource = "arn:aws:states:::athena:startQueryExecution.sync",
        Parameters = {
          QueryString = templatefile("${path.module}/../analytics/sql/create_tables.sql.tpl", {
            GLUE_DB              = aws_glue_catalog_database.db.name,
            RAW_BUCKET           = aws_s3_bucket.raw.bucket,
            CURATED_BUCKET       = aws_s3_bucket.curated.bucket,
            ATHENA_RESULTS_BUCKET = aws_s3_bucket.athena_results.bucket
          }),
          WorkGroup   = aws_athena_workgroup.wg.name,
          ResultConfiguration = {
            OutputLocation = "s3://${aws_s3_bucket.athena_results.bucket}/results/"
          }
        },
        Next = "RunTransformations"
      },
      RunTransformations = {
        Type = "Task",
        Resource = "arn:aws:states:::athena:startQueryExecution.sync",
        Parameters = {
          QueryString = templatefile("${path.module}/../analytics/sql/transformations.sql.tpl", {
            GLUE_DB        = aws_glue_catalog_database.db.name,
            RAW_BUCKET     = aws_s3_bucket.raw.bucket,
            CURATED_BUCKET = aws_s3_bucket.curated.bucket
          }),
          WorkGroup   = aws_athena_workgroup.wg.name,
          ResultConfiguration = {
            OutputLocation = "s3://${aws_s3_bucket.athena_results.bucket}/results/"
          }
        },
        Next = "RunDQChecks"
      },
      RunDQChecks = {
        Type = "Task",
        Resource = aws_lambda_function.dq_check.arn,
        End = true
      }
    }
  })
}

resource "aws_sfn_state_machine" "pipeline" {
  name     = "${var.project_name}-pipeline"
  role_arn = aws_iam_role.sfn_role.arn
  definition = local.state_machine_definition
  tags       = var.tags
}

