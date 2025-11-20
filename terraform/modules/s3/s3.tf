# Variables *******************************************************************

variable "project_name" {
  description = "Project name"
  type        = string
}

# Resources *******************************************************************

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "media" {
  bucket = "mohsen-${var.project_name}-media-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name    = "mohsen-${var.project_name}-media-files"
    Purpose = "Media storage"
  }
}

resource "aws_s3_bucket_versioning" "media" {
  bucket = aws_s3_bucket.media.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "media" {
  bucket = aws_s3_bucket.media.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "media" {
  bucket = aws_s3_bucket.media.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_cors_configuration" "media" {
  bucket = aws_s3_bucket.media.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "PUT", "POST", "DELETE", "HEAD"]
    allowed_origins = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

# Outputs *********************************************************************

output "media_bucket_name" {
  description = "Media bucket name"
  value       = aws_s3_bucket.media.id
}

output "media_bucket_arn" {
  description = "Media bucket ARN"
  value       = aws_s3_bucket.media.arn
}