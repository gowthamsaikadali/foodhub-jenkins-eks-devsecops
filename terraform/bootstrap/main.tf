
# Run ONCE per AWS account, with local state, to create the S3 bucket
# that stores all other Terraform state.

terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# Variables

variable "region" {
  type    = string
  default = "ap-south-1"
}

variable "budget_email" {
  description = "Email address that receives AWS cost alerts"
  type        = string
}

variable "monthly_budget_usd" {
  description = "Monthly cost limit in USD"
  type        = number
  default     = 60
}

# AWS Provider

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project   = "foodhub"
      ManagedBy = "terraform-bootstrap"
    }
  }
}

# AWS Account Identity

data "aws_caller_identity" "current" {}

# S3 Bucket Name

locals {
  bucket_name = "foodhub-tfstate-${data.aws_caller_identity.current.account_id}-${var.region}"
}

# S3 Terraform State Bucket

resource "aws_s3_bucket" "state" {
  bucket = local.bucket_name

  lifecycle {
    prevent_destroy = true
  }
}

# Enable S3 Versioning

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Enable Server-Side Encryption

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block Public Access

resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Deny Insecure HTTP Access

data "aws_iam_policy_document" "tls_only" {
  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.state.arn,
      "${aws_s3_bucket.state.arn}/*"
    ]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "tls_only" {
  bucket = aws_s3_bucket.state.id
  policy = data.aws_iam_policy_document.tls_only.json
}

# Lifecycle Configuration
# Expire old noncurrent state versions after 90 days.

resource "aws_s3_bucket_lifecycle_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    id     = "expire-old-state-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}

# AWS Monthly Cost Budget

resource "aws_budgets_budget" "monthly" {
  name         = "foodhub-monthly-cost"
  budget_type  = "COST"
  limit_amount = tostring(var.monthly_budget_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  # Alert when actual cost exceeds 50%

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 50
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.budget_email]
  }

  # Alert when actual cost exceeds 80%

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.budget_email]
  }

  # Alert when forecasted cost exceeds 100%

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [var.budget_email]
  }
}

# Output S3 State Bucket Name

output "state_bucket_name" {
  description = "Name of the Terraform state S3 bucket"
  value       = aws_s3_bucket.state.id
}
