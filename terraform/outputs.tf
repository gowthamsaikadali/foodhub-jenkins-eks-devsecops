output "account_id" {
  value = local.account_id
}

output "region" {
  value = var.region
}

output "ecr_repository_urls" {
  value = module.ecr.repository_urls
}

output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "kubeconfig_command" {
  description = "Run this to point kubectl at the cluster"
  value       = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks.cluster_name}"
}

output "rds_endpoint" {
  description = "Database host name (private, only resolvable inside the VPC)"
  value       = module.rds.address
}

output "rds_master_secret_arn" {
  value = module.rds.master_secret_arn
}

output "jwt_secret_name" {
  value = module.secrets.jwt_secret_name
}

output "db_connection_secret_name" {
  value = module.secrets.db_connection_secret_name
}

output "db_master_secret_name" {
  description = "Generated name of the RDS-managed credentials secret (used by the ExternalSecret)"
  value       = module.secrets.db_master_secret_name
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "alb_controller_role_arn" {
  value = module.eks.lbc_role_arn
}

output "external_secrets_role_arn" {
  value = module.secrets.external_secrets_role_arn
}

output "jenkins_role_arn" {
  value = module.iam.jenkins_role_arn
}

output "terraform_deployer_role_arn" {
  value = module.iam.terraform_role_arn
}

output "nat_public_ips" {
  value = module.vpc.nat_public_ips
}

output "jenkins_url" {
  value = var.create_ci_servers ? "http://${module.ci_servers[0].jenkins_public_ip}:8080" : null
}

output "sonarqube_url" {
  value = var.create_ci_servers ? "http://${module.ci_servers[0].sonarqube_public_ip}:9000" : null
}

output "jenkins_instance_id" {
  description = "Use with: aws ssm start-session --target <id>"
  value       = var.create_ci_servers ? module.ci_servers[0].jenkins_instance_id : null
}

output "sonarqube_instance_id" {
  value = var.create_ci_servers ? module.ci_servers[0].sonarqube_instance_id : null
}
