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

# Resources *******************************************************************

resource "aws_lb" "main" {
  name               = "mohsen-${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = var.security_group_ids
  subnets            = var.subnet_ids

  enable_deletion_protection       = false
  enable_http2                     = true
  enable_cross_zone_load_balancing = true

  tags = {
    Name = "mohsen-${var.project_name}-alb"
  }
}

resource "aws_lb_target_group" "main" {
  name        = "mohsen-${var.project_name}-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 10
    interval            = 30
    path                = "/"
    matcher             = "200,301,302"
  }

  deregistration_delay = 30

  tags = {
    Name = "mohsen-${var.project_name}-target-group"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}

# Outputs *********************************************************************

output "alb_arn" {
  description = "ALB ARN"
  value       = aws_lb.main.arn
}

output "alb_arn_suffix" {
  description = "ALB ARN suffix for CloudWatch"
  value       = aws_lb.main.arn_suffix
}

output "alb_dns_name" {
  description = "ALB DNS name"
  value       = aws_lb.main.dns_name
}

output "target_group_arn" {
  description = "Target group ARN"
  value       = aws_lb_target_group.main.arn
}

output "target_group_arn_suffix" {
  description = "Target group ARN suffix for CloudWatch"
  value       = aws_lb_target_group.main.arn_suffix
}