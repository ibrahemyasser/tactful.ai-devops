# AWS Secrets Manager module for storing application secrets
# These secrets are used by External Secrets Operator in Kubernetes

# Random password generation for PostgreSQL
resource "random_password" "postgresql_password" {
  length  = 32
  special = true
  # Avoid characters that might cause issues in connection strings
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# PostgreSQL credentials secret
# Using path-based naming to match Helm chart references: voting/{env}/postgresql
resource "aws_secretsmanager_secret" "postgresql" {
  name                    = "voting/${var.environment}/postgresql"
  description             = "PostgreSQL database credentials for ${var.environment} environment"
  recovery_window_in_days = var.recovery_window_in_days

  tags = merge(
    var.tags,
    {
      Name        = "voting-${var.environment}-postgresql"
      Environment = var.environment
      ManagedBy   = "Terraform"
      Component   = "Database"
    }
  )

  lifecycle {
    prevent_destroy = true
  }
}

# PostgreSQL secret version with password only
# Other connection parameters (host, port, database, username) are managed in Helm values
resource "aws_secretsmanager_secret_version" "postgresql" {
  secret_id = aws_secretsmanager_secret.postgresql.id

  secret_string = jsonencode({
    password = random_password.postgresql_password.result
  })

  lifecycle {
    ignore_changes = [
      secret_string,  # Don't update if manually rotated
    ]
  }
}

# IAM policy for External Secrets Operator to read secrets
resource "aws_iam_policy" "external_secrets_policy" {
  name_prefix = "${var.name_prefix}-external-secrets-"
  description = "Policy for External Secrets Operator to access Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [
          aws_secretsmanager_secret.postgresql.arn
        ]
      }
    ]
  })

  tags = var.tags
}

# IAM role for External Secrets Operator using EKS Pod Identity
resource "aws_iam_role" "external_secrets" {
  name_prefix = "${var.name_prefix}-external-secrets-"
  description = "IAM role for External Secrets Operator service account via Pod Identity"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "pods.eks.amazonaws.com"
        }
        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
      }
    ]
  })

  tags = var.tags
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "external_secrets" {
  role       = aws_iam_role.external_secrets.name
  policy_arn = aws_iam_policy.external_secrets_policy.arn
}

# Note: The EKS Pod Identity Association is created in the eks-cluster module
# The EKS module references external_secrets_role_arn from this module's outputs
