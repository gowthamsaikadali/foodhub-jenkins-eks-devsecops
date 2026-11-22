variable "name" { type = string }
variable "private_db_subnet_ids" { type = list(string) }
variable "rds_security_group_id" { type = string }

variable "db_name" {
  type    = string
  default = "foodhub"
}

variable "master_username" {
  type    = string
  default = "foodhub_admin"
}

variable "engine_version" {
  description = "MySQL 8.0 minor version. Leave at 8.0 to let AWS choose the current default 8.0.x."
  type        = string
  default     = "8.0"
}

variable "instance_class" {
  type    = string
  default = "db.t3.micro"
}

variable "allocated_storage_gb" {
  type    = number
  default = 20
}

variable "max_allocated_storage_gb" {
  description = "Storage autoscaling ceiling"
  type        = number
  default     = 50
}

variable "multi_az" {
  type    = bool
  default = false
}

variable "backup_retention_days" {
  type    = number
  default = 0
}

variable "deletion_protection" {
  type    = bool
  default = false
}

variable "skip_final_snapshot" {
  description = "true = destroy without a last backup (dev). false = take a final snapshot first (prod)."
  type        = bool
  default     = true
}

variable "tags" {
  type    = map(string)
  default = {}
}
