# Remote state of management VPC
data "terraform_remote_state" "vpc" {
  workspace = terraform.workspace
  backend   = "s3"
  config = {
    bucket               = "terraform-state-backend-demo-test"
    region               = "us-east-1"
    key                  = "backend.tfstate"
    workspace_key_prefix = "Terraform-demo-vpc"
  }
}

