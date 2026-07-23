output "game_url" {
  description = "Open this in a browser to play the game"
  value       = "http://${module.alb.alb_dns_name}"
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "alerts_topic_arn" {
  description = "SNS topic this stack's CloudWatch alarms publish to"
  value       = module.monitoring.alerts_topic_arn
}
