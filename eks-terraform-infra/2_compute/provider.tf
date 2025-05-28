terraform {
  required_version = "1.11.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.91.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.36.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "2.17.0"
    }
    kubectl = {
      source  = "alekc/kubectl"
      version = "2.1.3"
    }
    http = {
      source = "hashicorp/http"
      version = "3.4.5"
    }
  }
}

provider "aws" {
  region  = local.config.region
  profile = local.config.aws_profile
  default_tags {
    tags = local.tags
  }
}

provider "aws" {
  region = "us-east-1"
  alias = "us-east-1"
}

provider "kubernetes" {
  cluster_ca_certificate = try(base64decode(module.eks.cluster_certificate_authority_data), "")
  token                  = try(data.aws_eks_cluster_auth.this.token, "")
  host                   = try(module.eks.cluster_endpoint, "")
}

provider "helm" {
  kubernetes {
    cluster_ca_certificate = try(base64decode(module.eks.cluster_certificate_authority_data), "")
    token                  = try(data.aws_eks_cluster_auth.this.token, "")
    host                   = try(module.eks.cluster_endpoint, "")
  }
}

provider "kubectl" {
  apply_retry_count      = 5
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  load_config_file       = false

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}