resource "helm_release" "secret_csi" {
  namespace           = "kube-system"
  name                = "csi-secrets-store"
  repository          = "https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts"
  chart               = "secrets-store-csi-driver"
  version             = "1.4.8"
  wait                = false
  create_namespace    = false

  values = [
    <<-EOT
    syncSecret:
      enabled: true
    EOT
  ]
  
}

resource "helm_release" "secret_ascp" {
  namespace           = "kube-system"
  name                = "secrets-store-csi-driver-provider-aws"
  repository          = "https://aws.github.io/secrets-store-csi-driver-provider-aws"
  chart               = "secrets-store-csi-driver-provider-aws"
  version             = "1.0.0"
  wait                = false
  create_namespace    = false
  
  depends_on = [ helm_release.secret_csi ]
}



# IAM Policy for Secrets Manager Access
resource "aws_iam_policy" "secretsmanager" {
  name        = "jobber-secret-access-${local.identifier}"
  description = "Allows read access to secrets in AWS Secrets Manager for jobber app"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ],
        Resource = "arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:jobber-app-secrets*"
      }
    ]
  })
}

# IAM Role + Kubernetes Service Account for IRSA
module "iam_eks_role_secret_sa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.44.0"

  role_name = "jobber-secret-${local.identifier}"

  role_policy_arns = {
    secretsmanager = aws_iam_policy.secretsmanager.arn
  }

  oidc_providers = {
    eks = {
      provider_arn               = data.terraform_remote_state.eks.outputs.eks.oidc_provider_arn
      namespace_service_accounts = ["production:jobber-secret-reader"]
    }
  }
}

# Kubernetes Service Account that will be used in your deployment
resource "kubernetes_service_account" "jobber_secret_reader" {
  metadata {
    name      = "jobber-secret-reader"
    namespace = "production"
    annotations = {
      "eks.amazonaws.com/role-arn" = module.iam_eks_role_secret_sa.iam_role_arn
    }
  }
} 