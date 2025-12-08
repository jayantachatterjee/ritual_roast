provider "aws" {
  region = "ap-southeast-1"
}


# --- 1. S3 Bucket for State Storage ---
resource "aws_s3_bucket" "terraform_state" {
  # This name must be GLOBALLY unique
  bucket        = "my-unique-app-terraform-state-12345" 
  force_destroy = true # Allow deletion even if not empty (Be careful in Prod!)
}

# Enable Versioning (Critical for State Recovery)
resource "aws_s3_bucket_versioning" "enabled" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Enable Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "default" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block Public Access (Security Best Practice)
resource "aws_s3_bucket_public_access_block" "public_access" {
  bucket                  = aws_s3_bucket.terraform_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# --- 2. DynamoDB Table for State Locking ---
resource "aws_dynamodb_table" "terraform_locks" {
  name         = "my-app-terraform-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}