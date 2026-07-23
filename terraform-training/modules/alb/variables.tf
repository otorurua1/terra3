variable "name" {
  description = "Short name used to prefix/tag every resource this module creates"
  type        = string
}

variable "vpc_id" {
  type = string
}

variable "public_subnet_ids" {
  description = "Subnets the ALB itself is placed in"
  type        = list(string)
}

variable "tags" {
  type    = map(string)
  default = {}
}
