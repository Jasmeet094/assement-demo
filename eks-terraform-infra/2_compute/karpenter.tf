module "karpenter" {
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "20.24.0"

  cluster_name = module.eks.cluster_name

  enable_v1_permissions = true

  enable_pod_identity             = true
  create_pod_identity_association = true

  node_iam_role_additional_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }
}

resource "helm_release" "karpenter" {
  namespace           = "kube-system"
  name                = "karpenter"
  repository          = "oci://public.ecr.aws/karpenter"
  repository_username = data.aws_ecrpublic_authorization_token.token.user_name
  repository_password = data.aws_ecrpublic_authorization_token.token.password
  chart               = "karpenter"
  version             = "1.3.1"
  wait                = false

  values = [
    <<-EOT
    serviceAccount:
      name: ${module.karpenter.service_account}
    settings:
      clusterName: ${module.eks.cluster_name}
      clusterEndpoint: ${module.eks.cluster_endpoint}
      interruptionQueue: ${module.karpenter.queue_name}
    tolerations:
    - key: "CriticalAddonsOnly"
      operator: "Equal"
      value: "true"
      effect: "NoSchedule"      
    EOT
  ]
  
  depends_on = [ module.eks ]

  lifecycle {
    ignore_changes = [ repository_password ]
  }
}

# MAIN
resource "kubectl_manifest" "karpenter_node_class" {
  yaml_body = <<-YAML
    apiVersion: karpenter.k8s.aws/v1
    kind: EC2NodeClass
    metadata:
      name: main
    spec:
      metadataOptions:
        httpEndpoint: enabled
        httpProtocolIPv6: disabled
        httpPutResponseHopLimit: 1
        httpTokens: required
      amiFamily: AL2023
      amiSelectorTerms:
        - alias: al2023@latest
      role: ${module.karpenter.node_iam_role_name}
      subnetSelectorTerms:
        - tags:
            karpenter.sh/discovery:  ${module.eks.cluster_name}
            layer: private
      securityGroupSelectorTerms:
        - tags:
            karpenter.sh/discovery: ${module.eks.cluster_name}
      tags:
        karpenter.sh/discovery: ${module.eks.cluster_name}
        Name: "${module.eks.cluster_name}-karpenter-main-node-class"
        map-migrated: migRJEII6HF3V
  YAML

  depends_on = [
    helm_release.karpenter
  ]
}

resource "kubectl_manifest" "karpenter_node_pool" {
  yaml_body = <<-YAML
    apiVersion: karpenter.sh/v1
    kind: NodePool
    metadata:
      name: main
    spec:
      template:
        spec:
          nodeClassRef:
            group: karpenter.k8s.aws
            kind: EC2NodeClass
            name: main
          requirements:
            - key: "karpenter.k8s.aws/instance-category"
              operator: In
              values: ["c"]
            - key: "karpenter.k8s.aws/instance-cpu"
              operator: In
              values: ["4", "8", "16"]
            - key: "karpenter.k8s.aws/instance-hypervisor"
              operator: In
              values: ["nitro"]
            - key: "karpenter.k8s.aws/instance-generation"
              operator: Gt
              values: ["4"]
            - key: "kubernetes.io/arch"
              operator: In
              values: ["arm64"]
            - key: "karpenter.sh/capacity-type"
              operator: In
              values: ["on-demand"]
      limits:
        cpu: 1000
      disruption:
        consolidationPolicy: WhenEmptyOrUnderutilized 
        consolidateAfter: 3m
  YAML

  depends_on = [
    kubectl_manifest.karpenter_node_class
  ]
}

# MONITORING
resource "kubectl_manifest" "monitoring_node_class" {
  yaml_body = <<-YAML
    apiVersion: karpenter.k8s.aws/v1
    kind: EC2NodeClass
    metadata:
      name: monitoring
    spec:
      metadataOptions:
        httpEndpoint: enabled
        httpProtocolIPv6: disabled
        httpPutResponseHopLimit: 1
        httpTokens: required
      amiFamily: AL2023
      amiSelectorTerms:
        - alias: al2023@latest
      role: ${module.karpenter.node_iam_role_name}
      subnetSelectorTerms:
        - tags:
            karpenter.sh/discovery:  ${module.eks.cluster_name}
            layer: private
      securityGroupSelectorTerms:
        - tags:
            karpenter.sh/discovery: ${module.eks.cluster_name}
      tags:
        karpenter.sh/discovery: ${module.eks.cluster_name}
        Name: "${module.eks.cluster_name}-karpenter-monitoring-node-class"
        map-migrated: migRJEII6HF3V
  YAML

  depends_on = [
    helm_release.karpenter
  ]
}
resource "kubectl_manifest" "monitoring_node_pool" {
  yaml_body = <<-YAML
    apiVersion: karpenter.sh/v1
    kind: NodePool
    metadata:
      name: monitoring
    spec:
      template:
        spec:
          taints:
          - key: monitoring
            value: "true"
            effect: NoSchedule
          nodeClassRef:
            group: karpenter.k8s.aws
            kind: EC2NodeClass
            name: monitoring
          requirements:
            - key: "karpenter.k8s.aws/instance-category"
              operator: In
              values: ["c"]
            - key: "karpenter.k8s.aws/instance-cpu"
              operator: In
              values: ["4", "8", "16"]
            - key: "karpenter.k8s.aws/instance-hypervisor"
              operator: In
              values: ["nitro"]
            - key: "karpenter.k8s.aws/instance-generation"
              operator: Gt
              values: ["4"]
            - key: "kubernetes.io/arch"
              operator: In
              values: ["arm64"]
            - key: "karpenter.sh/capacity-type"
              operator: In
              values: ["on-demand"]
      limits:
        cpu: 1000
      disruption:
        consolidationPolicy: WhenEmptyOrUnderutilized 
        consolidateAfter: 3m
  YAML

  depends_on = [
    kubectl_manifest.karpenter_node_class
  ]
}


# # # ARGO
# # resource "kubectl_manifest" "argo_node_class" {
# #   yaml_body = <<-YAML
# #     apiVersion: karpenter.k8s.aws/v1
# #     kind: EC2NodeClass
# #     metadata:
# #       name: argo
# #     spec:
# #       metadataOptions:
# #         httpEndpoint: enabled
# #         httpProtocolIPv6: disabled
# #         httpPutResponseHopLimit: 1
# #         httpTokens: required
# #       amiFamily: AL2023
# #       amiSelectorTerms:
# #         - alias: al2023@latest
# #       role: ${module.karpenter.node_iam_role_name}
# #       subnetSelectorTerms:
# #         - tags:
# #             karpenter.sh/discovery: ${module.eks.cluster_name}
# #             layer: private
# #       securityGroupSelectorTerms:
# #         - tags:
# #             karpenter.sh/discovery: ${module.eks.cluster_name}
# #       tags:
# #         karpenter.sh/discovery: ${module.eks.cluster_name}
# #         Name: "${module.eks.cluster_name}-karpenter-argo-node-class"
# #         map-migrated: migRJEII6HF3V
# #   YAML

# #   depends_on = [
# #     helm_release.karpenter
# #   ]
# # }
# # resource "kubectl_manifest" "argo_node_pool" {
# #   yaml_body = <<-YAML
# #     apiVersion: karpenter.sh/v1
# #     kind: NodePool
# #     metadata:
# #       name: argo
# #     spec:
# #       template:
# #         spec:
# #           taints:
# #           - key: argocd
# #             value: "true"
# #             effect: NoSchedule
# #           nodeClassRef:
# #             group: karpenter.k8s.aws
# #             kind: EC2NodeClass
# #             name: argo
# #           requirements:
# #             - key: "karpenter.k8s.aws/instance-category"
# #               operator: In
# #               values: ["m"]
# #             - key: "karpenter.k8s.aws/instance-cpu"
# #               operator: In
# #               values: ["4", "8", "16"]
# #             - key: "karpenter.k8s.aws/instance-hypervisor"
# #               operator: In
# #               values: ["nitro"]
# #             - key: "karpenter.k8s.aws/instance-generation"
# #               operator: Gt
# #               values: ["4"]
# #             - key: "kubernetes.io/arch"
# #               operator: In
# #               values: ["arm64"]
# #             - key: "karpenter.sh/capacity-type"
# #               operator: In
# #               values: ["on-demand"]
# #       limits:
# #         cpu: 1000
# #       disruption:
# #         consolidationPolicy: WhenEmptyOrUnderutilized 
# #         consolidateAfter: 3m
# #   YAML

# #   depends_on = [
# #     kubectl_manifest.karpenter_node_class
# #   ]
# # }