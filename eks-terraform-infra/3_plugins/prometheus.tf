module "loki-s3-bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "4.5.0"

  bucket = "${local.identifier}-loki-storage-test"
  force_destroy = true
}

resource "kubernetes_namespace" "production" {
  metadata {
    name = "production"
  }
}

resource "helm_release" "prometheus" {
  name             = "prometheus"
  chart            = "prometheus"
  repository       = "https://prometheus-community.github.io/helm-charts"
  version          = "27.1.0"
  namespace        = "production"
  max_history      = 5
  create_namespace = false

  values = [
    <<YAML
    server:
        nodeSelector:
            karpenter.sh/nodepool: monitoring
        resources:
            requests:
                cpu: 100m
                memory: 200Mi
            limits:
                cpu: 500m
                memory: 512Mi
        tolerations:
            - key: "monitoring"
              operator: "Equal"
              value: "true"
              effect: "NoSchedule"
    YAML
  ]

  depends_on = [kubernetes_namespace.production]
}

resource "helm_release" "grafana" {
  name             = "grafana"
  chart            = "grafana"
  repository       = "https://grafana.github.io/helm-charts"
  version          = "8.8.5"
  namespace        = "production"
  max_history      = 5
  create_namespace = false

  values = [
    <<YAML

    nodeSelector:
        karpenter.sh/nodepool: monitoring
    resources:
        requests:
            cpu: 100m
            memory: 200Mi
        limits:
            cpu: 500m
            memory: 512Mi
    tolerations:
        - key: "monitoring"
          operator: "Equal"
          value: "true"
          effect: "NoSchedule"
    
    YAML
  ]

  depends_on = [kubernetes_namespace.production]
}

# LOKI

resource "aws_iam_policy" "loki" {

  name = "loki-${local.identifier}"
  path = "/"

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "s3:*"
        ],
        "Resource" : [
          "${module.loki-s3-bucket.s3_bucket_arn}",
          "${module.loki-s3-bucket.s3_bucket_arn}/*"
        ]
      }
    ]
  })

}

module "iam_eks_role_loki" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.44.0"

  role_name = "loki-${local.identifier}"

  role_policy_arns = {
    policy = aws_iam_policy.loki.arn
  }

  oidc_providers = {
    alb = {
      provider_arn               = data.terraform_remote_state.eks.outputs.eks.oidc_provider_arn
      namespace_service_accounts = ["production:loki-sa"]
    }
  }
}

resource "kubernetes_service_account" "loki" {
  metadata {
    namespace = "production"
    name      = "loki-sa"

    annotations = {
      "eks.amazonaws.com/role-arn" = module.iam_eks_role_loki.iam_role_arn
    }
  }

  depends_on = [kubernetes_namespace.production]
}

resource "helm_release" "loki" {
  name             = "loki"
  chart            = "loki"
  repository       = "https://grafana.github.io/helm-charts"
  version          = "6.25.0"
  namespace        = "production"
  max_history      = 5
  create_namespace = false

  values = [
    <<YAML
    
    serviceAccount:
      create: false
      name: loki-sa
    loki:
      auth_enabled: false
      storage:
        type: s3
        s3:
          region: ${local.config.region}
        bucketNames:
          chunks: ${local.identifier}-loki-storage-test
          ruler: ${local.identifier}-loki-storage-test
          admin: ${local.identifier}-loki-storage-test
      schemaConfig:
        configs:
          - from: "2024-04-01"
            store: tsdb
            object_store: s3
            schema: v13
            index:
              prefix: loki_index_
              period: 24h
      ingester:
        chunk_encoding: snappy
      querier:
        # Default is 4, if you have enough memory and CPU you can increase, reduce if OOMing
        max_concurrent: 4
      pattern_ingester:
        enabled: true
      limits_config:
        allow_structured_metadata: true
        volume_enabled: true
    
    deploymentMode: SimpleScalable
    
    backend:
      replicas: 2
      nodeSelector:
        karpenter.sh/nodepool: monitoring
      tolerations:
        - key: "monitoring"
          operator: "Equal"
          value: "true"
          effect: "NoSchedule"
    read:
      replicas: 2
      nodeSelector:
        karpenter.sh/nodepool: monitoring
      tolerations:
        - key: "monitoring"
          operator: "Equal"
          value: "true"
          effect: "NoSchedule"
    write:
      replicas: 3
      nodeSelector:
        karpenter.sh/nodepool: monitoring
      tolerations:
        - key: "monitoring"
          operator: "Equal"
          value: "true"
          effect: "NoSchedule"
    gateway:
      nodeSelector:
        karpenter.sh/nodepool: monitoring
      tolerations:
        - key: "monitoring"
          operator: "Equal"
          value: "true"
          effect: "NoSchedule"
    minio:
      enabled: false
    YAML
  ]

  depends_on = [kubernetes_namespace.production, module.loki-s3-bucket, kubernetes_service_account.loki] 
}

resource "helm_release" "alloy" {
  name             = "alloy"
  chart            = "alloy"
  repository       = "https://grafana.github.io/helm-charts"
  version          = "0.11.0"
  namespace        = "production"
  max_history      = 5
  create_namespace = false

  values = [
  <<YAML
  controller:
    tolerations:
      - key: "monitoring"
        operator: "Equal"
        value: "true"
        effect: "NoSchedule"
      
  alloy:
    mounts:
      varlog: true
    configMap:
      content: |
        logging {
          level  = "info"
          format = "logfmt"
        }

        discovery.kubernetes "pod" {
          role = "pod"
        }

        discovery.relabel "pod_logs" {
            targets = discovery.kubernetes.pod.targets

            // Label creation - "namespace" field from "__meta_kubernetes_namespace"
            rule {
                source_labels = ["__meta_kubernetes_namespace"]
                action = "replace"
                target_label = "namespace"
            }

            // Label creation - "pod" field from "__meta_kubernetes_pod_name"
            rule {
                source_labels = ["__meta_kubernetes_pod_name"]
                action = "replace"
                target_label = "pod"
            }

            // Label creation - "container" field from "__meta_kubernetes_pod_container_name"
            rule {
                source_labels = ["__meta_kubernetes_pod_container_name"]
                action = "replace"
                target_label = "container"
            }

            // Label creation -  "app" field from "__meta_kubernetes_pod_label_app_kubernetes_io_name"
            rule {
                source_labels = ["__meta_kubernetes_pod_label_app_kubernetes_io_name"]
                action = "replace"
                target_label = "app"
            }

            // Label creation -  "job" field from "__meta_kubernetes_namespace" and "__meta_kubernetes_pod_container_name"
            // Concatenate values __meta_kubernetes_namespace/__meta_kubernetes_pod_container_name
            rule {
                source_labels = ["__meta_kubernetes_namespace", "__meta_kubernetes_pod_container_name"]
                action = "replace"
                target_label = "job"
                separator = "/"
                replacement = "$1"
            }

            // Label creation - "container" field from "__meta_kubernetes_pod_uid" and "__meta_kubernetes_pod_container_name"
            // Concatenate values __meta_kubernetes_pod_uid/__meta_kubernetes_pod_container_name.log
            rule {
                source_labels = ["__meta_kubernetes_pod_uid", "__meta_kubernetes_pod_container_name"]
                action = "replace"
                target_label = "__path__"
                separator = "/"
                replacement = "/var/log/pods/$1/$2/*.log"
            }

            // Label creation -  "container_runtime" field from "__meta_kubernetes_pod_container_id"
            rule {
                source_labels = ["__meta_kubernetes_pod_container_id"]
                action = "replace"
                target_label = "container_runtime"
                regex = "^(\\S+):\\/\\/.+$"
                replacement = "$1"
            }
        }

        loki.source.kubernetes "pod_logs" {
          targets    = discovery.relabel.pod_logs.output
          forward_to = [loki.write.endpoint.receiver]
        }

        loki.write "endpoint" {
          endpoint {
            url = "http://loki-gateway.production.svc.cluster.local:80/loki/api/v1/push"
            tenant_id = "local"
          }
        }
  YAML
  ]

  depends_on = [kubernetes_namespace.production, helm_release.loki]
}

