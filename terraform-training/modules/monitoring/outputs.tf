output "alerts_topic_arn" {
  description = "SNS topic CloudWatch alarms publish to. Subscribe additional endpoints (Slack webhook via Lambda, PagerDuty, etc.) here."
  value       = aws_sns_topic.alerts.arn
}
