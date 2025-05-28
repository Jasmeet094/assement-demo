terraform {
  required_version = "1.11.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.91.0"
    }
  }
}

provider "aws" {
  region  = local.config.region
  profile = local.config.aws_profile
  default_tags {
    tags = merge({
      Workspace = terraform.workspace
      Env       = terraform.workspace
      Source    = "devops-kubernetes/network"
      Terraform = "true"
    }, local.config.tags)
  }
}
