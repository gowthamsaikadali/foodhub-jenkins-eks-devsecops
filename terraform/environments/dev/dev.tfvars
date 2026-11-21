# Cost-conscious development settings. Contains no secrets and no personal values.
environment        = "dev"
single_nat_gateway = true

node_instance_types = ["t3.medium"]
node_desired_size   = 2
node_min_size       = 2
node_max_size       = 3

db_instance_class        = "db.t3.micro"
db_allocated_storage_gb  = 20
db_multi_az              = false
db_backup_retention_days = 3
db_deletion_protection   = false
db_skip_final_snapshot   = true

ecr_force_delete            = true
secret_recovery_window_days = 0
create_ci_servers           = true
