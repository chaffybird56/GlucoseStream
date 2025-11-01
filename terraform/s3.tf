locals {
  bucket_suffix = random_id.bucket_suffix.hex
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "raw" {
  bucket        = "${var.project_name}-raw-${local.bucket_suffix}"
  force_destroy = true
  tags          = var.tags
}

resource "aws_s3_bucket" "curated" {
  bucket        = "${var.project_name}-curated-${local.bucket_suffix}"
  force_destroy = true
  tags          = var.tags
}

resource "aws_s3_bucket" "athena_results" {
  bucket        = "${var.project_name}-athena-${local.bucket_suffix}"
  force_destroy = true
  tags          = var.tags
}

resource "aws_s3_bucket_public_access_block" "all" {
  for_each = {
    raw            = aws_s3_bucket.raw.id
    curated        = aws_s3_bucket.curated.id
    athena_results = aws_s3_bucket.athena_results.id
  }

  bucket = each.value

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "all" {
  for_each = {
    raw            = aws_s3_bucket.raw.id
    curated        = aws_s3_bucket.curated.id
    athena_results = aws_s3_bucket.athena_results.id
  }

  bucket = each.value

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

output "raw_bucket" {
  value = aws_s3_bucket.raw.bucket
}

output "curated_bucket" {
  value = aws_s3_bucket.curated.bucket
}

output "athena_results_bucket" {
  value = aws_s3_bucket.athena_results.bucket
}

