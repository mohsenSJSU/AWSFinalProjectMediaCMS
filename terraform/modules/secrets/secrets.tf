# Variables *******************************************************************

variable "project_name" {
  description = "Project name"
  type        = string
}

variable "db_username" {
  description = "Database username"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}

variable "db_host" {
  description = "Database host endpoint"
  type        = string
}

variable "db_name" {
  description = "Database name"
  type        = string
}

# Resources *******************************************************************

# AWS Secrets Manager Secret
# Stores database credentials securely instead of environment variables
# ECS tasks will retrieve this at runtime using IAM role
resource "aws_secretsmanager_secret" "db_credentials" {
  name        = "mohsen-${var.project_name}-db-credentials"
  description = "Database credentials for MediaCMS (migrated from environment variables)"

  # Automatic rotation not enabled for this demo
  # In production, enable rotation with Lambda function
  recovery_window_in_days = 7

  tags = {
    Name        = "mohsen-${var.project_name}-db-credentials"
    Purpose     = "Database authentication"
    ManagedBy   = "Terraform"
    Environment = "Production"
  }
}

# Secret Version - Contains actual credential values
resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id

  # Store credentials as JSON
  # ECS will parse this automatically
  secret_string = jsonencode({
    username = var.db_username
    password = var.db_password
    host     = var.db_host
    dbname   = var.db_name
    port     = 5432
    engine   = "postgres"
  })
}

# Outputs *********************************************************************

output "secret_arn" {
  description = "ARN of the database credentials secret"
  value       = aws_secretsmanager_secret.db_credentials.arn
}

output "secret_name" {
  description = "Name of the database credentials secret"
  value       = aws_secretsmanager_secret.db_credentials.name
}
