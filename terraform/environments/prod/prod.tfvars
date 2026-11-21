# Production-recommended settings (documented for comparison; this project does not require you to deploy prod).
environment        = "prod"
single_nat_gateway = false
az_count           = 3

node_instance_types = ["m5.large"]
node_desired_size   = 3
node_min_size       = 3
node_max_size       = 6

db_instance_class        = "db.m5.large"
db_allocated_storage_gb  = 100
db_multi_az              = true
db_backup_retention_days = 14
db_deletion_protection   = true
db_skip_final_snapshot   = false

eks_log_types               = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
ecr_force_delete            = false
secret_recovery_window_days = 30
create_ci_servers           = false # prod would use a shared, separately managed CI/CD platform
