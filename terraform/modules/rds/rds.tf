# Variables *******************************************************************

variable "project_name" {
  description = "Project name"
  type        = string
}


variable "db_name" {
  description = "Database name"
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

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs"
  type        = list(string)
}

variable "security_group_ids" {
  description = "List of security group IDs"
  type        = list(string)
}

# Resources *******************************************************************

resource "aws_db_subnet_group" "main" {
  name       = "mohsen-${var.project_name}-db-subnet"
  subnet_ids = var.subnet_ids

  tags = {
    Name = "mohsen-${var.project_name}-db-subnet-group"
  }
}

resource "aws_db_instance" "main" {
  identifier     = "mohsen-${var.project_name}-db"
  engine         = "postgres"
  engine_version = "15"

  instance_class = var.db_instance_class

  allocated_storage     = 100
  max_allocated_storage = 500
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  multi_az               = true
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = var.security_group_ids

  backup_retention_period = 7
  backup_window           = "03:00-04:00"

  maintenance_window         = "mon:04:00-mon:05:00"
  auto_minor_version_upgrade = true

  deletion_protection       = false
  skip_final_snapshot       = true
  final_snapshot_identifier = "mohsen-${var.project_name}-final-snapshot"

  tags = {
    Name = "mohsen-${var.project_name}-database"
  }
}

# Outputs *********************************************************************

output "db_instance_id" {
  description = "RDS instance ID"
  value       = aws_db_instance.main.id
}

output "db_endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.main.endpoint
}

output "db_address" {
  description = "RDS instance address"
  value       = aws_db_instance.main.address
}