############################################
# ALB CONTROLLER
############################################

resource "helm_release" "alb_controller" {
  name             = "alb-controller"
  namespace        = "azure-alb-system"
  create_namespace = true

  repository = "oci://mcr.microsoft.com/application-lb/charts"
  chart      = "alb-controller"

  depends_on = [
    azurerm_kubernetes_cluster.aks
  ]
}

############################################
# APPLICATION LOAD BALANCER
############################################

resource "azapi_resource" "alb" {
  type      = "Microsoft.ServiceNetworking/trafficControllers@2024-05-01-preview"
  name      = "alb-poc"
  parent_id = azurerm_resource_group.main.id
  location  = azurerm_resource_group.main.location

  body = {
    properties = {}
  }

  lifecycle {
    ignore_changes = [tags]
  }
}

############################################
# ALB SUBNET ASSOCIATION
# Required: without this the Gateway never reaches Programmed=True.
# Created by setup.sh first, imported into state, then managed here.
# ignore_changes [tags] prevents Azure Policy tag drift triggering a
# spurious 15-min PUT on every apply.
############################################

resource "azapi_resource" "alb_association" {
  type      = "Microsoft.ServiceNetworking/trafficControllers/associations@2024-05-01-preview"
  name      = "alb-association"
  parent_id = azapi_resource.alb.id
  location  = azurerm_resource_group.main.location

  body = {
    properties = {
      associationType = "subnets"
      subnet = {
        id = azurerm_subnet.alb.id
      }
    }
  }

  depends_on = [azapi_resource.alb]

  lifecycle {
    ignore_changes = [tags]
  }
}

# Role assignments (Reader on ALB, Network Contributor on RG) are
# handled by setup.sh — the deploying SP is blocked from writing
# role assignments by an ABAC condition on the subscription.
