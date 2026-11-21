variable "name" {
  description = "Prefix for resource names, e.g. foodhub-dev"
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name. Used for subnet tags so the AWS Load Balancer Controller can find subnets."
  type        = string
}

variable "vpc_cidr" {
  description = "IP range of the whole VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "azs" {
  description = "Availability zones to spread subnets over (two is the minimum for EKS and RDS)"
  type        = list(string)
}

variable "single_nat_gateway" {
  description = "true = one NAT gateway for all AZs (cheap, dev). false = one per AZ (highly available, prod)."
  type        = bool
  default     = true
}

variable "region" {
  description = "AWS region, needed for the S3 gateway endpoint service name"
  type        = string
}

variable "tags" {
  description = "Extra tags applied to every resource"
  type        = map(string)
  default     = {}
}
