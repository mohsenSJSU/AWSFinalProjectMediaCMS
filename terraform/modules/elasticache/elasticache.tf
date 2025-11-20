# Variables *******************************************************************

variable "project_name" {
  description = "Project name"
  type        = string
}

variable "node_type" {
  description = "ElastiCache node type"
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

resource "aws_elasticache_subnet_group" "main" {
  name       = "mohsen-${var.project_name}-redis-subnet"
  subnet_ids = var.subnet_ids

  tags = {
    Name = "mohsen-${var.project_name}-redis-subnet-group"
  }
}

resource "aws_elasticache_replication_group" "main" {
  replication_group_id = "mohsen-${var.project_name}-redis"
  description          = "Redis cluster for mohsen ${var.project_name}"

  engine             = "redis"
  engine_version     = "7.0"
  node_type          = var.node_type
  num_cache_clusters = 3

  port               = 6379
  subnet_group_name  = aws_elasticache_subnet_group.main.name
  security_group_ids = var.security_group_ids

  automatic_failover_enabled = true
  multi_az_enabled           = true

  maintenance_window       = "sun:05:00-sun:06:00"
  snapshot_window          = "04:00-05:00"
  snapshot_retention_limit = 5

  at_rest_encryption_enabled = true
  transit_encryption_enabled = false

  auto_minor_version_upgrade = true

  tags = {
    Name = "mohsen-${var.project_name}-redis"
  }
}

# Outputs *********************************************************************

output "redis_cluster_id" {
  description = "Redis cluster ID"
  value       = aws_elasticache_replication_group.main.id
}

output "redis_endpoint" {
  description = "Redis primary endpoint"
  value       = aws_elasticache_replication_group.main.primary_endpoint_address
}

output "redis_port" {
  description = "Redis port"
  value       = aws_elasticache_replication_group.main.port
}