terraform {
  required_version = ">= 1.17.1"

  required_providers {
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.8"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.71"
    }
  }

  # Bucket, key and region come from `terraform init -backend-config=...`; see the README.
  backend "s3" {
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.tags
  }
}
