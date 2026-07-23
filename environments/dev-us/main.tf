locals {
  name = "${var.project}-${var.environment}-${var.region_short}"
  tags = {
    Project     = var.project
    Environment = var.environment
    Region      = var.region_short
  }
}

module "vpc" {
  source = "../../modules/vpc"

  name                = local.name
  vpc_cidr            = var.vpc_cidr
  public_subnet_cidrs = var.public_subnet_cidrs
  az_count            = 2

  tags = local.tags
}

module "alb" {
  source = "../../modules/alb"

  name              = local.name
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids

  tags = local.tags
}

module "ec2" {
  source = "../../modules/ec2"

  name              = local.name
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids

  alb_security_group_id = module.alb.alb_security_group_id
  target_group_arn      = module.alb.target_group_arn

  instance_type    = var.instance_type
  min_size         = var.min_size
  max_size         = var.max_size
  desired_capacity = var.desired_capacity

  game_index_html = file("${path.module}/../../game/index.html")
  region_label    = "${var.aws_region} (${var.environment})"

  tags = local.tags
}

module "monitoring" {
  source = "../../modules/monitoring"

  name = local.name

  alb_arn_suffix          = module.alb.alb_arn_suffix
  target_group_arn_suffix = module.alb.target_group_arn_suffix
  autoscaling_group_name  = module.ec2.autoscaling_group_name

  alarm_email = var.alarm_email

  tags = local.tags
}
