
terraform {
  backend "s3" {
    bucket               = "terraform-state-backend-demo-test"
    region               = "us-east-1"
    key                  = "backend.tfstate"
    workspace_key_prefix = "Terraform-demo-plugins-eks"
    encrypt              = true
    use_lockfile         = true
  }
}