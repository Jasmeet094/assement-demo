locals {
  config     = yamldecode(file("${path.module}/config/${terraform.workspace}.yaml"))
  identifier = "${local.config.identifier}-${terraform.workspace}"
   tags = merge({
      Workspace = terraform.workspace
      Env       = terraform.workspace
      Source    = "test-kubernetes/compute"
      Terraform = "true"
    }, local.config.tags)
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.33.0"

  cluster_name                            = "${local.identifier}-cluster"
  cluster_version                         = local.config.cluster_version
  subnet_ids                              = concat(
    data.terraform_remote_state.vpc.outputs.private_subnet_ids,
    data.terraform_remote_state.vpc.outputs.public_subnet_ids
  )
  vpc_id                                  = data.terraform_remote_state.vpc.outputs.vpc_id
  iam_role_name                           = "${local.identifier}-eks"
  cluster_security_group_name             = "${local.identifier}-eks"
  cluster_security_group_tags = {
    "karpenter.sh/discovery" : "${local.identifier}-cluster"
  }
  node_security_group_tags = {
    "karpenter.sh/discovery" : "${local.identifier}-cluster"
  }

  access_entries = local.config.access_entries
  enable_cluster_creator_admin_permissions = true
  cluster_addons = local.config.cluster_addons

  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true

  eks_managed_node_groups = {
    default1 = {
      name            = "${local.identifier}-default1"
      use_name_prefix = false

      ami_type     = local.config.node_group.default.ami_type
      min_size     = local.config.node_group.default.min_size
      max_size     = local.config.node_group.default.max_size
      desired_size = local.config.node_group.default.desired_size

      instance_types               = local.config.node_group.default.instance_types
      create_iam_role              = true
      iam_role_name                = "${local.identifier}-ng-default"
      iam_role_additional_policies = { "${local.identifier}-ng-default" : "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore" }
      iam_role_use_name_prefix     = false
      subnet_ids                   = data.terraform_remote_state.vpc.outputs.private_subnet_ids
      cluster_enabled_log_types    = [] # default values are ["audit", "api", "authenticator"]

      taints = {
        # This Taint aims to keep just EKS Addons and Karpenter running on this MNG
        # The pods that do not tolerate this taint should run on nodes created by Karpenter
        addons = {
          key    = "CriticalAddonsOnly"
          value  = "true"
          effect = "NO_SCHEDULE"
        },
      }

      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = 50
            volume_type           = "gp2"
            encrypted             = true
            delete_on_termination = true
          }
        }
      }

      tags = local.config.tags

    }
  }
}