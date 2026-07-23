output "alb_dns_name" {
  description = "Public URL (http://<this>) to play the game"
  value       = aws_lb.game.dns_name
}

output "alb_zone_id" {
  description = "Route53 hosted zone ID of the ALB, useful for an alias record"
  value       = aws_lb.game.zone_id
}

output "alb_arn_suffix" {
  description = "Used by modules/monitoring to build CloudWatch alarm dimensions"
  value       = aws_lb.game.arn_suffix
}

output "target_group_arn" {
  description = "Consumed by modules/ec2 to attach the Auto Scaling Group"
  value       = aws_lb_target_group.game.arn
}

output "target_group_arn_suffix" {
  description = "Used by modules/monitoring to build CloudWatch alarm dimensions"
  value       = aws_lb_target_group.game.arn_suffix
}

output "alb_security_group_id" {
  description = "Consumed by modules/ec2 so instances only accept traffic from the ALB"
  value       = aws_security_group.alb.id
}
