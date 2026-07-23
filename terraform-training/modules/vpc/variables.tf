variable "name" {
  description = "Short name used to prefix/tag every resource this module creates, e.g. \"mario-eu\""
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for the public subnets, one per AZ used"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "az_count" {
  description = "Number of availability zones to spread public subnets across (must be <= length(public_subnet_cidrs))"
  type        = number
  default     = 2
}

variable "tags" {
  description = "Extra tags applied to every resource"
  type        = map(string)
  default     = {}
}
