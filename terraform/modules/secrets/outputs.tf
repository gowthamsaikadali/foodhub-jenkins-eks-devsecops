output "jwt_secret_name" { value = aws_secretsmanager_secret.jwt.name }
output "jwt_secret_arn" { value = aws_secretsmanager_secret.jwt.arn }
output "external_secrets_role_arn" { value = aws_iam_role.external_secrets.arn }
output "db_connection_secret_name" { value = aws_secretsmanager_secret.db_connection.name }
output "db_master_secret_name" { value = data.aws_secretsmanager_secret.db_master.name }
