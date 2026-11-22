variable "project" {
  description = "Project name used as a prefix for every resource"
  type        = string
  default     = "foodhub"
}

variable "environment" {
  description = "dev or prod"
  type        = string
  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be dev or prod."
  }
}

variable "region" {
  type    = string
  default = "ap-south-1"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "az_count" {
  description = "Number of availability zones (2 minimum)"
  type        = number
  default     = 2
}

variable "single_nat_gateway" {
  description = "true for dev (cheaper), false for prod (one NAT per AZ)"
  type        = bool
  default     = true
}

# ---------- access control ----------
variable "admin_cidrs" {
  description = "Your public IP as CIDR, e.g. [\"124.123.138.4/32\"]. Find it with: curl https://checkip.amazonaws.com"
  type        = list(string)
  validation {
    condition     = length(var.admin_cidrs) > 0 && !contains(var.admin_cidrs, "0.0.0.0/0")
    error_message = "admin_cidrs must contain at least one address and must NOT contain 0.0.0.0/0."
  }
}

variable "github_webhook_cidrs" {
  description = "Optional GitHub webhook ranges for Jenkins (from https://api.github.com/meta, key 'hooks'). Empty = use SCM polling."
  type        = list(string)
  default     = []
}

variable "admin_principal_arns" {
  description = "Your IAM user/role ARNs that should get cluster-admin on EKS, e.g. arn:aws:iam::123456789012:user/gowtham-admin"
  type        = list(string)
  default     = []
}

variable "terraform_extra_trusted_arns" {
  description = "Extra principals that may assume the Terraform deployer role (normally your admin user)"
  type        = list(string)
  default     = []
}

# ---------- state ----------
variable "state_bucket_name" {
  description = "Name of the S3 bucket created by terraform/bootstrap"
  type        = string
}

# ---------- EKS ----------
variable "kubernetes_version" {
  description = "EKS Kubernetes version. MUST be in standard support: older versions cost 6x more per hour for the control plane. 1.36 is in standard support until Aug 2027 (checked Nov 2026). Re-check https://endoflife.date/eks before applying."
  type        = string
  default     = "1.36"
}

variable "node_instance_types" {
  type    = list(string)
  default = ["c7i-flex.large"]
}

variable "node_desired_size" {
  type    = number
  default = 2
}

variable "node_min_size" {
  type    = number
  default = 2
}

variable "node_max_size" {
  type    = number
  default = 3
}

variable "eks_log_types" {
  type    = list(string)
  default = ["api", "audit"]
}

# ---------- RDS ----------
variable "db_instance_class" {
  type    = string
  default = "db.t3.micro"
}

variable "db_allocated_storage_gb" {
  type    = number
  default = 20
}

variable "db_multi_az" {
  type    = bool
  default = false
}

variable "db_backup_retention_days" {
  type    = number
  default = 3
}

variable "db_deletion_protection" {
  type    = bool
  default = false
}

variable "db_skip_final_snapshot" {
  type    = bool
  default = true
}

# ---------- ECR ----------
variable "ecr_force_delete" {
  description = "Let destroy remove repositories that still contain images (dev only)"
  type        = bool
  default     = false
}

# ---------- Jenkins / SonarQube servers ----------
variable "create_ci_servers" {
  description = "Create the Jenkins and SonarQube EC2 instances"
  type        = bool
  default     = true
}

variable "jenkins_instance_type" {
  type    = string
  default = "c7i-flex.large"
}

variable "sonarqube_instance_type" {
  type    = string
  default = "c7i-flex.large"
}

variable "secret_recovery_window_days" {
  description = "0 for dev so destroy+apply cycles work; 7-30 for prod"
  type        = number
  default     = 0
}
