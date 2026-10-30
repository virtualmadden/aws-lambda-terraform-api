terraform {
  required_version = ">= 1.17.1"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.71"
    }
  }

  # Local state: this root creates the bucket the API's state lives in, and runs once
  # from a laptop. Keep terraform.tfstate somewhere safe, or see the README to move it.
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Repository = var.github_repository
      ManagedBy  = "terraform"
    }
  }
}
