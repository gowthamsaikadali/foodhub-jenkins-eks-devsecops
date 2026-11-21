variable "name" { type = string }
variable "public_subnet_id" { type = string }
variable "jenkins_sg_id" { type = string }
variable "sonarqube_sg_id" { type = string }
variable "jenkins_instance_profile_name" { type = string }

variable "jenkins_instance_type" {
  type    = string
  default = "t3.medium"
}

variable "sonarqube_instance_type" {
  description = "SonarQube needs at least 4 GB RAM to run comfortably"
  type        = string
  default     = "t3.medium"
}

variable "jenkins_volume_gb" {
  type    = number
  default = 30
}

variable "sonarqube_volume_gb" {
  type    = number
  default = 30
}

variable "tags" {
  type    = map(string)
  default = {}
}
