data "aws_caller_identity" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  name         = "${var.project}-${var.environment}"
  cluster_name = "${local.name}-eks"
  account_id   = data.aws_caller_identity.current.account_id
  azs          = slice(data.aws_availability_zones.available.names, 0, var.az_count)
  ecr_repos    = ["${var.project}-frontend", "${var.project}-backend"]
}

# 1. Network
module "vpc" {
  source = "./modules/vpc"

  name               = local.name
  cluster_name       = local.cluster_name
  region             = var.region
  vpc_cidr           = var.vpc_cidr
  azs                = local.azs
  single_nat_gateway = var.single_nat_gateway
}

# 2. IAM identities (cluster, nodes, Jenkins, Terraform deployer)
module "iam" {
  source = "./modules/iam"

  name                          = local.name
  region                        = var.region
  account_id                    = local.account_id
  cluster_name                  = local.cluster_name
  ecr_repository_names          = local.ecr_repos
  state_bucket_name             = var.state_bucket_name
  extra_trusted_principal_arns  = var.terraform_extra_trusted_arns
}

# 3. Container registry
module "ecr" {
  source = "./modules/ecr"

  repository_names    = local.ecr_repos
  force_delete        = var.ecr_force_delete
  pull_principal_arns = [module.iam.eks_node_role_arn]
  push_principal_arns = [module.iam.jenkins_role_arn]
}

# 4. Kubernetes cluster
module "eks" {
  source = "./modules/eks"

  name                 = local.name
  cluster_name         = local.cluster_name
  region               = var.region
  kubernetes_version   = var.kubernetes_version
  cluster_role_arn     = module.iam.eks_cluster_role_arn
  node_role_arn        = module.iam.eks_node_role_arn
  private_subnet_ids   = module.vpc.private_app_subnet_ids
  public_access_cidrs  = var.admin_cidrs
  cluster_log_types    = var.eks_log_types
  node_instance_types  = var.node_instance_types
  node_desired_size    = var.node_desired_size
  node_min_size        = var.node_min_size
  node_max_size        = var.node_max_size
  admin_principal_arns = var.admin_principal_arns
  jenkins_role_arn     = module.iam.jenkins_role_arn
}

# 5. Security groups (needs the EKS cluster SG, so it comes after EKS)
module "security" {
  source = "./modules/security"

  name                          = local.name
  vpc_id                        = module.vpc.vpc_id
  admin_cidrs                   = var.admin_cidrs
  github_webhook_cidrs          = var.github_webhook_cidrs
  eks_cluster_security_group_id = module.eks.cluster_security_group_id
}

# 6. Database
module "rds" {
  source = "./modules/rds"

  name                  = local.name
  private_db_subnet_ids = module.vpc.private_db_subnet_ids
  rds_security_group_id = module.security.rds_sg_id
  instance_class        = var.db_instance_class
  allocated_storage_gb  = var.db_allocated_storage_gb
  multi_az              = var.db_multi_az
  backup_retention_days = var.db_backup_retention_days
  deletion_protection   = var.db_deletion_protection
  skip_final_snapshot   = var.db_skip_final_snapshot
}

# 7. Secrets Manager + External Secrets Operator role
module "secrets" {
  source = "./modules/secrets"

  name                 = local.name
  cluster_name         = module.eks.cluster_name
  db_master_secret_arn = module.rds.master_secret_arn
  db_host              = module.rds.address
  db_port              = module.rds.port
  db_name              = module.rds.db_name
  recovery_window_days = var.secret_recovery_window_days
}

# 8. Jenkins and SonarQube servers (optional, so you can build them only when needed)
module "ci_servers" {
  count  = var.create_ci_servers ? 1 : 0
  source = "./modules/ci_servers"

  name                          = local.name
  public_subnet_id              = module.vpc.public_subnet_ids[0]
  jenkins_sg_id                 = module.security.jenkins_sg_id
  sonarqube_sg_id               = module.security.sonarqube_sg_id
  jenkins_instance_profile_name = module.iam.jenkins_instance_profile_name
  jenkins_instance_type         = var.jenkins_instance_type
  sonarqube_instance_type       = var.sonarqube_instance_type
}
