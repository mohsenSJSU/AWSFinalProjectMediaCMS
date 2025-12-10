# Variables ********************************************************************

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "db_username" {
  description = "Database master username"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "Database master password"
  type        = string
  sensitive   = true
}

variable "db_host" {
  description = "Database endpoint"
  type        = string
}

variable "db_name" {
  description = "Database name"
  type        = string
}

# Resources ********************************************************************

resource "aws_secretsmanager_secret" "db_credentials" {
  name        = "mohsen-${var.project_name}-db-credentials"
  description = "Database credentials for MediaCMS"

  tags = {
    Name = "mohsen-${var.project_name}-db-secret"
  }
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = var.db_username
    password = var.db_password
    host     = var.db_host
    dbname   = var.db_name
  })
}

# Outputs **********************************************************************

output "secret_arn" {
  description = "ARN of the database credentials secret"
  value       = aws_secretsmanager_secret.db_credentials.arn
}

output "secret_name" {
  description = "Name of the database credentials secret"
  value       = aws_secretsmanager_secret.db_credentials.name
}
