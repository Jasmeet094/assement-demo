
resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
  }
}

resource "helm_release" "metrics_server" {
  name             = "metrics-server"
  chart            = "metrics-server"
  repository       = "https://kubernetes-sigs.github.io/metrics-server/"
  version          = "3.12.2"
  namespace        = "monitoring"
  max_history      = 5
  create_namespace = false

  set {
    name  = "clusterName"
    value = "${local.identifier}"
  }

  values = [
    <<YAML
    resources:
        requests:
            cpu: 100m
            memory: 200Mi
        limits:
            cpu: 500m
            memory: 512Mi
    tolerations:
        - key: "CriticalAddonsOnly"
          operator: "Equal"
          value: "true"
          effect: "NoSchedule"
    YAML
  ]

  depends_on = [kubernetes_namespace.monitoring]
}