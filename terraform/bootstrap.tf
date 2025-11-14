# ==================================================================
# TERRAFORM STATE BACKEND BOOTSTRAP
# This file should be deployed FIRST before the main infrastructure
# Run: terraform init && terraform apply -target=aws_s3_bucket.terraform_state -target=aws_dynamodb_table.terraform_lock
# ==================================================================

# S3 Bucket for Terraform State
resource "aws_s3_bucket" "terraform_state" {
  bucket = "comet-terraform-state"

  tags = {
    Name        = "Terraform State Bucket"
    Environment = "production"
    ManagedBy   = "terraform"
  }
}

# Enable versioning for state file history
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Enable encryption at rest
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block public access
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# DynamoDB Table for State Locking
resource "aws_dynamodb_table" "terraform_lock" {
  name         = "terraform-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name        = "Terraform State Lock Table"
    Environment = "production"
    ManagedBy   = "terraform"
  }
}
