############################################
# NAMESPACE
############################################

resource "kubernetes_namespace" "app" {
  metadata {
    name = "demo"
  }
}

############################################
# NGINX DEPLOYMENT
############################################

resource "kubernetes_deployment" "nginx" {
  metadata {
    name      = "nginx"
    namespace = kubernetes_namespace.app.metadata[0].name

    labels = {
      app = "nginx"
    }
  }

  spec {
    replicas = 2

    selector {
      match_labels = {
        app = "nginx"
      }
    }

    template {
      metadata {
        labels = {
          app = "nginx"
        }
      }

      spec {
        container {
          name  = "nginx"
          image = "nginx:latest"

          port {
            container_port = 80
          }
        }
      }
    }
  }
}

############################################
# SERVICE
############################################

resource "kubernetes_service" "nginx" {
  metadata {
    name      = "nginx-service"
    namespace = kubernetes_namespace.app.metadata[0].name
  }

  spec {
    selector = {
      app = "nginx"
    }

    port {
      port        = 80
      target_port = 80
    }

    type = "ClusterIP"
  }
}

############################################
# GATEWAY
############################################

resource "kubernetes_manifest" "gateway" {
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "Gateway"

    metadata = {
      name      = "demo-gateway"
      namespace = kubernetes_namespace.app.metadata[0].name

      annotations = {
        "alb.networking.azure.io/alb-id" = azapi_resource.alb.id
      }
    }

    spec = {
      gatewayClassName = "azure-alb-external"

      listeners = [
        {
          name     = "http"
          port     = 80
          protocol = "HTTP"
        }
      ]
    }
  }

  lifecycle {
    replace_triggered_by = [
      azapi_resource.alb
    ]
  }

  depends_on = [
    helm_release.alb_controller,
    azapi_resource.alb
  ]
}
############################################
# HTTP ROUTE
############################################

resource "kubernetes_manifest" "httproute" {
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"

    metadata = {
      name      = "demo-route"
      namespace = kubernetes_namespace.app.metadata[0].name
    }

    spec = {
      parentRefs = [
        {
          name = "demo-gateway"
        }
      ]

      rules = [
        {
          backendRefs = [
            {
              name = "nginx-service"
              port = 80
            }
          ]
        }
      ]
    }
  }

  depends_on = [
    kubernetes_manifest.gateway
  ]
}