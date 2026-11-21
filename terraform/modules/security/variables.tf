variable "name" { type = string }
variable "vpc_id" { type = string }

variable "admin_cidrs" {
  description = "Your public IP in CIDR form (for example 203.0.113.7/32). Only these addresses can open Jenkins and SonarQube in a browser."
  type        = list(string)
}

variable "github_webhook_cidrs" {
  description = "GitHub webhook source ranges allowed to reach Jenkins on 8080. Leave empty to use polling instead."
  type        = list(string)
  default     = []
}

variable "eks_cluster_security_group_id" {
  description = "EKS cluster security group; worker nodes and (by default) pods use it"
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
