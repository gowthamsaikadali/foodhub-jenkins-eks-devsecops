provider "aws" {
  region = var.region

  # Every resource that supports tags gets these automatically (useful for cost reports and cleanup)
  default_tags {
    tags = {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}
