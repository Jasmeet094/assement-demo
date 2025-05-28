# resource "kubernetes_namespace" "argo-cd" {
#   metadata {
#     name = "argo-cd"
#   }
# }

# resource "helm_release" "argo-cd" {
#   namespace           = "argo-cd"
#   name                = "argo-cd"
#   repository          = "oci://ghcr.io/argoproj/argo-helm"
#   chart               = "argo-cd"
#   version             = "7.7.11"
#   wait                = false

#   values = [
#     <<YAML
#     global:
#       domain: argocd.poc.testing-ottera.tv
#       nodeSelector: 
#         karpenter.sh/nodepool: argo
#       tolerations:
#         - key: "argocd"
#           operator: "Equal"
#           value: "true"
#           effect: "NoSchedule"
#     configs:
#       params:
#         server.insecure: true
#     server:
#       ingress:
#         enabled: true
#         controller: aws
#         ingressClassName: alb
#         annotations:
#           alb.ingress.kubernetes.io/scheme: internet-facing        
#           alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:us-west-2:487376241693:certificate/8489cf8d-c5bf-4114-b251-2d951bdaf85d
#           alb.ingress.kubernetes.io/listen-ports: '[{"HTTP":80,"HTTPS":443}]'
#           alb.ingress.kubernetes.io/ssl-redirect: '443'
#           alb.ingress.kubernetes.io/group.name: ottera
#           alb.ingress.kubernetes.io/healthcheck-interval-seconds: "15"
#           alb.ingress.kubernetes.io/healthcheck-timeout-seconds: "5"
#           alb.ingress.kubernetes.io/healthy-threshold-count: "3"
#           alb.ingress.kubernetes.io/unhealthy-threshold-count: "2"
#           alb.ingress.kubernetes.io/target-type: ip
#         aws:
#           serviceType: ClusterIP # <- Used with target-type: ip
#           backendProtocolVersion: GRPC
    
#     YAML
#   ]
  
#   depends_on = [ kubernetes_namespace.argo-cd ]
# }
