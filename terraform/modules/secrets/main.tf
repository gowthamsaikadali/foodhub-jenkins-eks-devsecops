# ---------- JWT signing secret for the backend ----------
resource "random_password" "jwt" {
  length  = 64
  special = false
}

resource "aws_secretsmanager_secret" "jwt" {
  name                    = "${var.name}/backend/jwt"
  description             = "HS256 signing key for FoodHub JWTs"
  recovery_window_in_days = var.recovery_window_days
  tags                    = var.tags
}

resource "aws_secretsmanager_secret_version" "jwt" {
  secret_id     = aws_secretsmanager_secret.jwt.id
  secret_string = jsonencode({ secret = random_password.jwt.result })
}

# ---------- Database connection details (host, port, schema). The username and password stay in the RDS-managed secret. ----------
resource "aws_secretsmanager_secret" "db_connection" {
  name                    = "${var.name}/backend/db-connection"
  description             = "Where the database lives (no credentials)"
  recovery_window_in_days = var.recovery_window_days
  tags                    = var.tags
}

resource "aws_secretsmanager_secret_version" "db_connection" {
  secret_id     = aws_secretsmanager_secret.db_connection.id
  secret_string = jsonencode({ host = var.db_host, port = tostring(var.db_port), dbname = var.db_name })
}

# The RDS-managed secret has a generated name (rds!db-...); External Secrets needs that exact name
data "aws_secretsmanager_secret" "db_master" {
  arn = var.db_master_secret_arn
}

# ---------- IAM role for External Secrets Operator (through EKS Pod Identity) ----------
data "aws_iam_policy_document" "pod_identity_assume" {
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]
    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "read_secrets" {
  statement {
    sid       = "ReadOnlyTheThreeFoodHubSecrets"
    actions   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
    resources = [var.db_master_secret_arn, aws_secretsmanager_secret.jwt.arn, aws_secretsmanager_secret.db_connection.arn]
  }
}

resource "aws_iam_role" "external_secrets" {
  name               = "${var.name}-external-secrets"
  assume_role_policy = data.aws_iam_policy_document.pod_identity_assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy" "external_secrets" {
  name   = "${var.name}-read-foodhub-secrets"
  role   = aws_iam_role.external_secrets.id
  policy = data.aws_iam_policy_document.read_secrets.json
}

resource "aws_eks_pod_identity_association" "external_secrets" {
  cluster_name    = var.cluster_name
  namespace       = var.external_secrets_namespace
  service_account = "external-secrets"
  role_arn        = aws_iam_role.external_secrets.arn
}
