module "iam_eks_role_ebs_csi"{
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.52.2"

  role_name = "aws-ebs-csi-controller-${local.identifier}"

  role_policy_arns = {
    policy = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  }

  oidc_providers = {
    ebs = {
      provider_arn               = data.terraform_remote_state.eks.outputs.eks.oidc_provider_arn
      namespace_service_accounts = ["ebs-csi:aws-ebs-csi"]
    }
  }
}

resource "kubernetes_namespace" "ebs" {
  metadata {
    name = "ebs-csi"
  }
}

resource "kubernetes_service_account" "ebs" {
  metadata {
    namespace = "ebs-csi"
    name      = "aws-ebs-csi"

    annotations = {
      "eks.amazonaws.com/role-arn" = module.iam_eks_role_ebs_csi.iam_role_arn
    }
  }

  depends_on = [kubernetes_namespace.ebs]
}

resource "helm_release" "ebs" {
  name             = "aws-ebs-csi"
  chart            = "aws-ebs-csi-driver"
  repository       = "https://charts.deliveryhero.io"
  version          = "2.17.1"
  namespace        = "ebs-csi"
  max_history      = 5
  create_namespace = false

  set {
    name  = "clusterName"
    value = "${local.identifier}-cluster"
  }

  values = [
    <<YAML
    controller:
      serviceAccount:
        create: false
        name:  aws-ebs-csi
      tolerations:
        - key: "CriticalAddonsOnly"
          operator: "Equal"
          value: "true"
          effect: "NoSchedule"
        - effect: NoExecute
          operator: Exists
          tolerationSeconds: 300
    node:
      tolerations:
        - key: "CriticalAddonsOnly"
          operator: "Equal"
          value: "true"
          effect: "NoSchedule"
        - operator: Exists
          effect: NoExecute
          tolerationSeconds: 300
      serviceAccount:
        create: false
        name: aws-ebs-csi
    YAML
  ]

  depends_on = [kubernetes_service_account.ebs]
}

resource "kubernetes_storage_class" "example" {
  metadata {
    name = "ebs-sc"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true" # Set this as the default storage class
    }
  }
  storage_provisioner = "ebs.csi.aws.com"
  reclaim_policy      = "Delete"
  parameters = {
    type              = "gp2"
    encrypted         = "true"
    kmsKeyId          = "alias/aws/ebs"
  }
  volume_binding_mode = "WaitForFirstConsumer"

  depends_on = [ helm_release.ebs ]
}