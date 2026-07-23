variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "project" {
  type    = string
  default = "mario-game"
}

variable "environment" {
  type    = string
  default = "prod"
}

variable "region_short" {
  type    = string
  default = "us"
}

variable "vpc_cidr" {
  type    = string
  default = "10.22.0.0/16"
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.22.1.0/24", "10.22.2.0/24"]
}

variable "instance_type" {
  type    = string
  default = "t3.small"
}

variable "min_size" {
  type    = number
  default = 2
}

variable "max_size" {
  type    = number
  default = 4
}

variable "desired_capacity" {
  type    = number
  default = 2
}

variable "alarm_email" {
  description = "Email address subscribed to this stack's CloudWatch alarm SNS topic. Leave blank to skip the subscription."
  type        = string
  default     = ""
}
