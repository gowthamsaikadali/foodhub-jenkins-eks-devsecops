variable "name" { type = string }
variable "cluster_name" { type = string }
variable "region" { type = string }

variable "kubernetes_version" {
  description = "EKS Kubernetes version (must be in standard support, see root variables.tf)"
  type        = string
}

variable "cluster_role_arn" { type = string }
variable "node_role_arn" { type = string }
variable "private_subnet_ids" { type = list(string) }

variable "endpoint_public_access" {
  description = "Expose the Kubernetes API publicly (restricted by public_access_cidrs). Jenkins uses the private endpoint either way."
  type        = bool
  default     = true
}

variable "public_access_cidrs" {
  description = "Who may reach the public Kubernetes API. Use your own IP/32, never 0.0.0.0/0."
  type        = list(string)
}

variable "cluster_log_types" {
  description = "Control-plane logs sent to CloudWatch (each type costs log storage)"
  type        = list(string)
  default     = ["api", "audit"]
}

variable "node_instance_types" {
  description = "EC2 instance types for EKS worker nodes"
  type        = list(string)
  default     = ["t3.small"]
}

variable "node_desired_size" {
  type    = number
  default = 1
}

variable "node_min_size" {
  type    = number
  default = 1
}

variable "node_max_size" {
  type    = number
  default = 3
}

variable "node_disk_size_gb" {
  type    = number
  default = 20
}

variable "admin_principal_arns" {
  description = "IAM users/roles that get cluster-admin through EKS access entries (your own admin user)"
  type        = list(string)
  default     = []
}

variable "jenkins_role_arn" {
  description = "Jenkins instance role. Gets edit rights ONLY inside the app namespace."
  type        = string
}

variable "app_namespace" {
  type    = string
  default = "foodhub"
}

variable "tags" {
  type    = map(string)
  default = {}
}
