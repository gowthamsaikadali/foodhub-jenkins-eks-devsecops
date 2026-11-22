variable "name" { type = string }
variable "public_subnet_id" { type = string }
variable "jenkins_sg_id" { type = string }
variable "sonarqube_sg_id" { type = string }
variable "jenkins_instance_profile_name" { type = string }


variable "jenkins_instance_type" {
  type    = string
  default = "c7i-flex.large"
}

variable "sonarqube_instance_type" {
  description = "SonarQube EC2 instance type"
  type        = string
  default     = "c7i-flex.large"
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
