# MediaCMS Infrastructure
# Modular Terraform configuration for AWS deployment

# VPC Module *******************************************************************

module "vpc" {
  source = "./modules/vpc"

  project_name = var.project_name
}

# Security Groups **************************************************************

resource "aws_security_group" "alb" {
  name        = "mohsen-${var.project_name}-alb-sg"
  description = "ALB security group"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP from internet"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS from internet"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = {
    Name = "mohsen-${var.project_name}-alb-sg"
  }
}

resource "aws_security_group" "ecs" {
  name        = "mohsen-${var.project_name}-ecs-sg"
  description = "ECS containers security group"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
    description     = "Traffic from ALB"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = {
    Name = "mohsen-${var.project_name}-ecs-sg"
  }
}

resource "aws_security_group" "rds" {
  name        = "mohsen-${var.project_name}-rds-sg"
  description = "RDS PostgreSQL security group"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
    description     = "PostgreSQL from ECS"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = {
    Name = "mohsen-${var.project_name}-rds-sg"
  }
}

resource "aws_security_group" "redis" {
  name        = "mohsen-${var.project_name}-redis-sg"
  description = "ElastiCache Redis security group"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
    description     = "Redis from ECS"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = {
    Name = "mohsen-${var.project_name}-redis-sg"
  }
}

# S3 Module *******************************************************************

module "s3" {
  source = "./modules/s3"

  project_name = var.project_name
}

# RDS Module ******************************************************************

module "rds" {
  source = "./modules/rds"

  project_name       = var.project_name
  db_name            = var.db_name
  db_username        = var.db_username
  db_password        = var.db_password
  db_instance_class  = var.db_instance_class
  subnet_ids         = module.vpc.private_subnet_ids
  security_group_ids = [aws_security_group.rds.id]
}

# ElastiCache Module **********************************************************

module "elasticache" {
  source = "./modules/elasticache"

  project_name       = var.project_name
  node_type          = var.redis_node_type
  subnet_ids         = module.vpc.private_subnet_ids
  security_group_ids = [aws_security_group.redis.id]
}

# Secrets Manager Module ******************************************************

module "secrets" {
  source = "./modules/secrets"

  project_name = var.project_name
  db_username  = var.db_username
  db_password  = var.db_password
  db_host      = module.rds.db_endpoint
  db_name      = var.db_name
}

# ALB Module ******************************************************************

module "alb" {
  source = "./modules/alb"

  project_name       = var.project_name
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.public_subnet_ids
  security_group_ids = [aws_security_group.alb.id]
}

# ECS Module ******************************************************************

module "ecs" {
  source = "./modules/ecs"

  project_name       = var.project_name
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.private_subnet_ids
  security_group_ids = [aws_security_group.ecs.id]

  task_cpu          = var.ecs_task_cpu
  task_memory       = var.ecs_task_memory
  desired_count     = var.ecs_desired_count
  min_capacity      = var.ecs_min_capacity
  max_capacity      = var.ecs_max_capacity
  cpu_target_value  = var.cpu_target_value
  db_host           = module.rds.db_endpoint
  db_name           = var.db_name
  db_username       = var.db_username
  db_password       = var.db_password
  db_secret_arn     = module.secrets.secret_arn
  redis_host        = module.elasticache.redis_endpoint
  media_bucket_name = module.s3.media_bucket_name
  target_group_arn  = module.alb.target_group_arn
}

# Monitoring Module ***********************************************************

module "monitoring" {
  source = "./modules/monitoring"

  project_name            = var.project_name
  alarm_email             = var.alarm_email
  alb_arn                 = module.alb.alb_arn
  alb_arn_suffix          = module.alb.alb_arn_suffix
  target_group_arn        = module.alb.target_group_arn
  target_group_arn_suffix = module.alb.target_group_arn_suffix
  ecs_cluster_name        = module.ecs.cluster_name
  ecs_service_name        = module.ecs.service_name
  rds_instance_id         = module.rds.db_instance_id
  redis_cluster_id        = module.elasticache.redis_cluster_id
}
