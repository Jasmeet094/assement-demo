resource "aws_iam_policy" "dns" {

  name = "external-dns-${local.identifier}"
  path = "/"

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "route53:ChangeResourceRecordSets"
        ],
        "Resource" : [
          "arn:aws:route53:::hostedzone/*"
        ]
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "route53:ListHostedZones",
          "route53:ListResourceRecordSets",
          "route53:ListTagsForResource"
        ],
        "Resource" : [
          "*"
        ]
      }
    ]
  })

}

module "iam_eks_role_dns" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.52.2"

  role_name = "external-dns-${local.identifier}"

  role_policy_arns = {
    policy = aws_iam_policy.dns.arn
  }

  oidc_providers = {
    alb = {
      provider_arn               = data.terraform_remote_state.eks.outputs.eks.oidc_provider_arn
      namespace_service_accounts = ["external-dns:external-dns"]
    }
  }
}

resource "kubernetes_namespace" "dns" {
  metadata {
    name = "external-dns"
  }
}

resource "kubernetes_service_account" "dns" {
  metadata {
    namespace = "external-dns"
    name      = "external-dns"

    annotations = {
      "eks.amazonaws.com/role-arn" = module.iam_eks_role_dns.iam_role_arn
    }
  }

  depends_on = [kubernetes_namespace.dns]
}

resource "helm_release" "dns" {
  name             = "external-dns"
  chart            = "external-dns"
  repository       = "https://kubernetes-sigs.github.io/external-dns/"
  version          = "1.15.0"
  namespace        = "external-dns"
  max_history      = 5
  create_namespace = false

  set {
    name  = "clusterName"
    value = "${local.identifier}"
  }

  values = [
    <<YAML
    policy: sync
    serviceAccount:
        create: false
        name: external-dns
    tolerations:
        - key: "CriticalAddonsOnly"
          operator: "Equal"
          value: "true"
          effect: "NoSchedule"
    YAML
  ]

  depends_on = [kubernetes_service_account.dns]
}