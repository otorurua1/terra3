terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "s3" {
    bucket       = "grendaizer-win-s3-lock-1"
    key          = "dev/eu/terraform.tfstate"
    region       = "eu-central-1" # region the state BUCKET lives in, not eu-west-1
    use_lockfile = true           # native S3 state locking (Terraform >= 1.10), no DynamoDB needed
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
