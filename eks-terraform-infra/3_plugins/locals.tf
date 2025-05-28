locals {
  config     = yamldecode(file("${path.module}/config/${terraform.workspace}.yaml"))
  identifier = "${local.config.identifier}-${terraform.workspace}"
   tags = merge({
      Workspace = terraform.workspace
      Env       = terraform.workspace
      Source    = "demo-kubernetes/plugins"
      Terraform = "true"
    }, local.config.tags)
}
