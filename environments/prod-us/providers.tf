terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "s3" {
    bucket       = "tornike-state-s3-lock-12"
    key          = "prod/us/terraform.tfstate"
    region       = "us-east-1" # region the state BUCKET lives in
    use_lockfile = true        # native S3 state locking (Terraform >= 1.10), no DynamoDB needed
    encrypt      = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project
      Environment = var.environment
      Region      = var.region_short
      ManagedBy   = "terraform"
    }
  }
}
