# Variables *******************************************************************

variable "project_name" {
  description = "Project name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
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

variable "task_cpu" {
  description = "CPU units for ECS task"
  type        = string
}

variable "task_memory" {
  description = "Memory for ECS task"
  type        = string
}

variable "desired_count" {
  description = "Desired number of tasks"
  type        = number
}

variable "min_capacity" {
  description = "Minimum number of tasks"
  type        = number
}

variable "max_capacity" {
  description = "Maximum number of tasks"
  type        = number
}

variable "cpu_target_value" {
  description = "Target CPU utilization percentage"
  type        = number
}

variable "redis_host" {
  description = "Redis host"
  type        = string
}

variable "media_bucket_name" {
  description = "S3 bucket name for media"
  type        = string
}

variable "target_group_arn" {
  description = "Target group ARN"
  type        = string
}

variable "db_secret_arn" {
  description = "ARN of Secrets Manager secret containing database credentials"
  type        = string
}

# Resources *******************************************************************

data "aws_region" "current" {}

resource "aws_ecs_cluster" "main" {
  name = "mohsen-${var.project_name}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name = "mohsen-${var.project_name}-ecs-cluster"
  }
}

resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/mohsen-${var.project_name}"
  retention_in_days = 7

  tags = {
    Name = "mohsen-${var.project_name}-logs"
  }
}

# IAM ROLES - PRINCIPLE OF LEAST PRIVILEGE
# MediaCMS uses TWO separate IAM roles following AWS best practices:
#
# 1. EXECUTION ROLE (ecs_execution_role):
#    - Used by ECS service to set up the task
#    - Pulls Docker images, writes CloudWatch logs
#    - Administrative/infrastructure permissions
#
# 2. TASK ROLE (ecs_task_role):
#    - Used by the MediaCMS application itself
#    - Access to S3 for media storage
#    - Application-level permissions only
#
# This separation ensures ECS infrastructure operations are isolated
# from application operations, limiting blast radius of any compromise.
# 
resource "aws_iam_role" "ecs_execution_role" {
  name = "mohsen-${var.project_name}-ecs-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })
}

# ECS Execution Role - AWS Managed Policy
#
# Uses AWS managed policy: AmazonECSTaskExecutionRolePolicy
# This grants permissions for ECS infrastructure operations:
# - Pull container images from ECR
# - Write logs to CloudWatch
# - Retrieve secrets from Secrets Manager (when configured)
#
# SECURITY JUSTIFICATION:
# - This is a well-maintained AWS managed policy
# - Permissions are scoped to ECS service operations only
# - Does NOT grant application-level permissions (those use ecs_task_role)

resource "aws_iam_role_policy_attachment" "ecs_execution_role_policy" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Secrets Manager Access for Execution Role
# 
# The EXECUTION role needs permission to retrieve secrets at task startup
# This allows ECS to inject secret values into the container environment
# 
# SECURITY NOTE:
# - Only grants GetSecretValue (not PutSecretValue or DeleteSecret)
# - Scoped to specific secret ARN only (not all secrets)
# - Uses temporary IAM role credentials (not long-term keys)
resource "aws_iam_role_policy" "ecs_execution_secrets_policy" {
  name = "mohsen-${var.project_name}-ecs-execution-secrets"
  role = aws_iam_role.ecs_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "AllowRetrieveDatabaseSecret"
      Effect = "Allow"
      Action = [
        "secretsmanager:GetSecretValue"
      ]
      Resource = [
        var.db_secret_arn
      ]
    }]
  })
}

resource "aws_iam_role" "ecs_task_role" {
  name = "mohsen-${var.project_name}-ecs-task"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })
}

# IAM Policy - Least Privilege Principle
# 
# This policy grants the ECS tasks minimal S3 permissions required for MediaCMS:
# 1. ListBucket: Required to check if media files exist
# 2. PutObject: Required to upload videos/images
# 3. GetObject: Required to stream/download media to users
# 
# REMOVED PERMISSIONS (not required for operation):
# - s3:DeleteObject: Media deletion handled through application logic, not direct S3
# 
# SECURITY ENHANCEMENTS:
# - Condition enforces server-side encryption (AES256)
# - Separate statements for bucket vs object operations
# - Explicit resource ARNs (no wildcards at bucket level)

resource "aws_iam_role_policy" "ecs_task_s3_policy" {
  name = "mohsen-${var.project_name}-ecs-s3"
  role = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowListBucket"
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.media_bucket_name}"
        ]
      },
      {
        Sid    = "AllowReadWriteObjects"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject"
        ]
        Resource = [
          "arn:aws:s3:::${var.media_bucket_name}/*"
        ]
        Condition = {
          StringEquals = {
            "s3:x-amz-server-side-encryption" = "AES256"
          }
        }
      }
    ]
  })
}

resource "aws_ecs_task_definition" "main" {
  family                   = "mohsen-${var.project_name}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([{
    name  = "mediacms"
    image = "mediacms/mediacms:latest"

    portMappings = [{
      containerPort = 80
      protocol      = "tcp"
    }]

    # Non-sensitive environment variables
    environment = [
      { name = "REDIS_HOST", value = var.redis_host },
      { name = "REDIS_PORT", value = "6379" },
      { name = "MEDIA_BUCKET", value = var.media_bucket_name },
      { name = "AWS_REGION", value = data.aws_region.current.name }
    ]

    # Sensitive secrets retrieved from Secrets Manager at runtime
    # ECS automatically injects these as environment variables
    # No hardcoded credentials in task definition!
    secrets = [
      { name = "POSTGRES_HOST", valueFrom = "${var.db_secret_arn}:host::" },
      { name = "POSTGRES_DB", valueFrom = "${var.db_secret_arn}:dbname::" },
      { name = "POSTGRES_USER", valueFrom = "${var.db_secret_arn}:username::" },
      { name = "POSTGRES_PASSWORD", valueFrom = "${var.db_secret_arn}:password::" }
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
        "awslogs-region"        = data.aws_region.current.name
        "awslogs-stream-prefix" = "ecs"
      }
    }

    essential = true
  }])

  tags = {
    Name = "mohsen-${var.project_name}-task"
  }
}

resource "aws_ecs_service" "main" {
  name            = "mohsen-${var.project_name}-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.main.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = var.security_group_ids
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.target_group_arn
    container_name   = "mediacms"
    container_port   = 80
  }

  depends_on = [var.target_group_arn]

  tags = {
    Name = "mohsen-${var.project_name}-service"
  }
}

resource "aws_appautoscaling_target" "ecs" {
  max_capacity       = var.max_capacity
  min_capacity       = var.min_capacity
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.main.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "ecs_cpu" {
  name               = "mohsen-${var.project_name}-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = var.cpu_target_value
    scale_in_cooldown  = 300
    scale_out_cooldown = 60

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}

# Outputs *********************************************************************

output "cluster_id" {
  description = "ECS cluster ID"
  value       = aws_ecs_cluster.main.id
}

output "cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.main.name
}

output "service_name" {
  description = "ECS service name"
  value       = aws_ecs_service.main.name
}

output "task_definition_arn" {
  description = "ECS task definition ARN"
  value       = aws_ecs_task_definition.main.arn
}