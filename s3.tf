data "aws_s3_bucket" "terraform_state" {
  bucket = var.terraform_state_bucket
}
resource "aws_s3_bucket" "terraform_state" {
  # Only create if the data source doesn't return a bucket
  count  = length(data.aws_s3_bucket.terraform_state) == 0 ? 1 : 0
  bucket = var.terraform_state_bucket

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "enabled" {
  count  = length(data.aws_s3_bucket.terraform_state) == 0 ? 1 : 0
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "default" {
  count  = length(data.aws_s3_bucket.terraform_state) == 0 ? 1 : 0
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "public_access" {
  count                   = length(data.aws_s3_bucket.terraform_state) == 0 ? 1 : 0
  bucket                  = aws_s3_bucket.terraform_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
