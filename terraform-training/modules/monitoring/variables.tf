variable "name" {
  description = "Short name used to prefix/tag every resource this module creates"
  type        = string
}

variable "alb_arn_suffix" {
  description = "From modules/alb — used in the unhealthy-hosts and 5xx alarm dimensions"
  type        = string
}

variable "target_group_arn_suffix" {
  description = "From modules/alb — used in the unhealthy-hosts alarm dimension"
  type        = string
}

variable "autoscaling_group_name" {
  description = "From modules/ec2 — used in the high-CPU alarm dimension"
  type        = string
}

variable "alarm_email" {
  description = "Email address subscribed to the CloudWatch alarm SNS topic. Leave blank to create the topic/alarms without a subscription (subscribe manually or add one later)."
  type        = string
  default     = ""
}

variable "tags" {
  type    = map(string)
  default = {}
}
