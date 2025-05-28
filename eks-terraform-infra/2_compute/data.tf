
data "aws_eks_cluster_auth" "this" {
  name = module.eks.cluster_name
}

data "aws_ecrpublic_authorization_token" "token" {
  provider = aws.us-east-1
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_vpc" "vpc" {
  filter {
    name   = "tag:Env"
    values = [terraform.workspace]
  }
}

data "aws_subnets" "private_subnets" {
  filter {
    name   = "tag:Env"
    values = [terraform.workspace]
  }

  filter {
    name   = "tag:layer"
    values = ["private"]
  }

  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.vpc.id]
  }
}

data "aws_subnets" "public_subnets" {
  filter {
    name   = "tag:Env"
    values = [terraform.workspace]
  }

  filter {
    name   = "tag:layer"
    values = ["public"]
  }

  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.vpc.id]
  }
}