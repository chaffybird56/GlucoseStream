data "aws_iam_policy_document" "assume_role_lambda" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_role" {
  name               = "${var.project_name}-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role_lambda.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_access" {
  name = "${var.project_name}-lambda-access"
  role = aws_iam_role.lambda_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
        ],
        Resource = [
          aws_s3_bucket.raw.arn,
          "${aws_s3_bucket.raw.arn}/*",
          aws_s3_bucket.curated.arn,
          "${aws_s3_bucket.curated.arn}/*",
          aws_s3_bucket.athena_results.arn,
          "${aws_s3_bucket.athena_results.arn}/*"
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "athena:StartQueryExecution",
          "athena:GetQueryExecution",
          "athena:GetQueryResults"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "glue:GetDatabase",
          "glue:GetTables",
          "glue:GetTable",
          "glue:StartCrawler",
          "glue:GetCrawler",
          "glue:GetCrawlerMetrics"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = ["sns:Publish"],
        Resource = "*"
      }
    ]
  })
}

data "aws_iam_policy_document" "assume_role_glue" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["glue.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "glue_role" {
  name               = "${var.project_name}-glue-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role_glue.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "glue_service" {
  role       = aws_iam_role.glue_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

resource "aws_iam_role_policy" "glue_access" {
  name = "${var.project_name}-glue-access"
  role = aws_iam_role.glue_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = ["s3:ListBucket", "s3:GetObject"],
        Resource = [
          aws_s3_bucket.raw.arn,
          "${aws_s3_bucket.raw.arn}/*",
          aws_s3_bucket.curated.arn,
          "${aws_s3_bucket.curated.arn}/*"
        ]
      }
    ]
  })
}

