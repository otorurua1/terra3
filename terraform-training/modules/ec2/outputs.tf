output "autoscaling_group_name" {
  description = "Used by modules/monitoring to build the high-CPU alarm dimension"
  value       = aws_autoscaling_group.game.name
}

output "instance_security_group_id" {
  value = aws_security_group.instance.id
}
