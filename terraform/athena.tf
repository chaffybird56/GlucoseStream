resource "aws_athena_workgroup" "wg" {
  name = "${var.project_name}-wg"
  configuration {
    result_configuration {
      output_location = "s3://${aws_s3_bucket.athena_results.bucket}/results/"
    }
    enforce_workgroup_configuration = false
    publish_cloudwatch_metrics_enabled = true
  }
  tags = var.tags
}

output "athena_workgroup" {
  value = aws_athena_workgroup.wg.name
}

