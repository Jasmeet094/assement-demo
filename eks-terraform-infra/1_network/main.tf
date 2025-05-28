locals {
  config     = yamldecode(file("${path.module}/config/${terraform.workspace}.yaml"))
  identifier = "${local.config.identifier}-${terraform.workspace}"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.16.0"

  name = local.identifier
  cidr = local.config.cidr

  azs              = slice(data.aws_availability_zones.available.names, 0, 4)
  private_subnets  = local.config.private_subnet_cidrs
  public_subnets   = local.config.public_subnet_cidrs
  database_subnets = local.config.data_subnet_cidrs

  one_nat_gateway_per_az = false
  single_nat_gateway     = true

  enable_nat_gateway = true
  enable_vpn_gateway = false
  enable_dns_hostnames = true
  enable_dns_support  = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
    "layer"                  = "public"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
    "karpenter.sh/discovery"          = "${local.identifier}-cluster"
    "layer"                           = "private"
  }
}