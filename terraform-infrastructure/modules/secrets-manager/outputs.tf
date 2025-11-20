output "postgresql_secret_arn" {
  description = "ARN of the PostgreSQL credentials secret"
  value       = aws_secretsmanager_secret.postgresql.arn
}

output "postgresql_secret_name" {
  description = "Name of the PostgreSQL credentials secret"
  value       = aws_secretsmanager_secret.postgresql.name
}

output "external_secrets_role_arn" {
  description = "ARN of the IAM role for External Secrets Operator"
  value       = aws_iam_role.external_secrets.arn
}

output "external_secrets_policy_arn" {
  description = "ARN of the IAM policy for External Secrets Operator"
  value       = aws_iam_policy.external_secrets_policy.arn
}

# Output the initial password (sensitive)
output "postgresql_initial_password" {
  description = "Initial PostgreSQL password (store securely!)"
  value       = random_password.postgresql_password.result
  sensitive   = true
}
