variable "name" {
  description = "Short name used to prefix/tag every resource this module creates"
  type        = string
}

variable "vpc_id" {
  type = string
}

variable "public_subnet_ids" {
  description = "Subnets the Auto Scaling Group's instances are placed in"
  type        = list(string)
}

variable "alb_security_group_id" {
  description = "Security group of the ALB (from modules/alb) — instances only accept HTTP from it"
  type        = string
}

variable "target_group_arn" {
  description = "ALB target group (from modules/alb) the Auto Scaling Group attaches to"
  type        = string
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "min_size" {
  type    = number
  default = 1
}

variable "max_size" {
  type    = number
  default = 3
}

variable "desired_capacity" {
  type    = number
  default = 2
}

variable "game_index_html" {
  description = "Raw contents of the index.html served by every instance"
  type        = string
}

variable "region_label" {
  description = "Human-readable label written to /region.json so the page can show which region served it"
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
