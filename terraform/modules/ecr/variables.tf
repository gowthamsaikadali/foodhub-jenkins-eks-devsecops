variable "repository_names" {
  description = "ECR repositories to create"
  type        = list(string)
  default     = ["foodhub-frontend", "foodhub-backend"]
}

variable "force_delete" {
  description = "Allow terraform destroy to delete repositories that still contain images (dev only)"
  type        = bool
  default     = false
}

variable "keep_last_tagged_images" {
  description = "How many tagged images to keep per repository"
  type        = number
  default     = 20
}

variable "untagged_expire_days" {
  description = "Delete untagged images after this many days"
  type        = number
  default     = 7
}

variable "pull_principal_arns" {
  description = "IAM role ARNs allowed to pull images through the repository policy (EKS node role)"
  type        = list(string)
  default     = []
}

variable "push_principal_arns" {
  description = "IAM role ARNs allowed to push images through the repository policy (Jenkins role)"
  type        = list(string)
  default     = []
}

variable "tags" {
  type    = map(string)
  default = {}
}
