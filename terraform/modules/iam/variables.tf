variable "name" {
  description = "Prefix for role names, e.g. foodhub-dev"
  type        = string
}

variable "region" {
  type = string
}

variable "account_id" {
  type = string
}

variable "cluster_name" {
  description = "EKS cluster name (used to build the cluster ARN for Jenkins permissions)"
  type        = string
}

variable "ecr_repository_names" {
  description = "ECR repositories Jenkins may push to"
  type        = list(string)
}

variable "state_bucket_name" {
  description = "S3 bucket that holds Terraform state (the Terraform deployer role needs access)"
  type        = string
}

variable "extra_trusted_principal_arns" {
  description = "Extra principals (for example your admin IAM user) allowed to assume the Terraform deployer role. The Jenkins role is always trusted."
  type        = list(string)
  default     = []
}

variable "tags" {
  type    = map(string)
  default = {}
}
