variable "name" { type = string }
variable "cluster_name" { type = string }

variable "db_master_secret_arn" {
  description = "Secret created by RDS for the database credentials"
  type        = string
}

variable "db_host" {
  type = string
}

variable "db_port" {
  type = number
}

variable "db_name" {
  type = string
}

variable "recovery_window_days" {
  description = "Days a deleted secret stays recoverable. 0 = delete immediately (dev, so destroy/apply cycles do not clash on names)."
  type        = number
  default     = 0
}

variable "external_secrets_namespace" {
  type    = string
  default = "external-secrets"
}

variable "tags" {
  type    = map(string)
  default = {}
}
