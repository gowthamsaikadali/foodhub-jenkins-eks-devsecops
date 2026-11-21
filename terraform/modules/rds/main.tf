resource "aws_db_subnet_group" "this" {
  name       = "${var.name}-db-subnets"
  subnet_ids = var.private_db_subnet_ids # only the private DB subnets: no route to the internet
  tags       = merge(var.tags, { Name = "${var.name}-db-subnets" })
}

resource "aws_db_parameter_group" "this" {
  name   = "${var.name}-mysql8"
  family = "mysql8.0"

  parameter {
    name  = "character_set_server"
    value = "utf8mb4"
  }
  parameter {
    name  = "collation_server"
    value = "utf8mb4_unicode_ci"
  }
  parameter {
    name  = "time_zone"
    value = "UTC"
  }

  tags = var.tags
}

# Role that lets RDS publish Enhanced Monitoring metrics (OS level CPU/memory) to CloudWatch
data "aws_iam_policy_document" "monitoring_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["monitoring.rds.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "monitoring" {
  name               = "${var.name}-rds-monitoring"
  assume_role_policy = data.aws_iam_policy_document.monitoring_assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "monitoring" {
  role       = aws_iam_role.monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

resource "aws_db_instance" "this" {
  identifier     = "${var.name}-mysql"
  engine         = "mysql"
  engine_version = var.engine_version
  instance_class = var.instance_class

  db_name  = var.db_name
  username = var.master_username

  # AWS generates the password, stores it in AWS Secrets Manager and can rotate it.
  # The password never appears in Terraform code, variables or state.
  manage_master_user_password = true

  allocated_storage     = var.allocated_storage_gb
  max_allocated_storage = var.max_allocated_storage_gb
  storage_type          = "gp3"
  storage_encrypted     = true

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [var.rds_security_group_id]
  publicly_accessible    = false
  multi_az               = var.multi_az
  parameter_group_name   = aws_db_parameter_group.this.name

  backup_retention_period    = var.backup_retention_days
  backup_window              = "21:00-22:00" # UTC, early morning in India
  maintenance_window         = "sun:22:30-sun:23:30"
  auto_minor_version_upgrade = true
  copy_tags_to_snapshot      = true

  monitoring_interval             = 60
  monitoring_role_arn             = aws_iam_role.monitoring.arn
  enabled_cloudwatch_logs_exports = ["error", "slowquery"]

  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.name}-final-${formatdate("YYYYMMDDhhmm", timestamp())}"
  apply_immediately         = true

  tags = merge(var.tags, { Name = "${var.name}-mysql" })

  lifecycle {
    ignore_changes = [final_snapshot_identifier, engine_version]
  }
}
