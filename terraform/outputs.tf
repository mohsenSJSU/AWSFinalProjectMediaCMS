# Outputs

output "application_url" {
  description = "MediaCMS application URL"
  value       = "http://${module.alb.alb_dns_name}"
}

output "media_bucket" {
  description = "S3 bucket for media storage"
  value       = module.s3.media_bucket_name
}

output "ecs_cluster" {
  description = "ECS cluster name"
  value       = module.ecs.cluster_name
}
