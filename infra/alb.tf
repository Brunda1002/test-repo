resource "helm_release" "alb_controller" {
  name             = "alb-controller"
  namespace        = "azure-alb-system"
  create_namespace = true

  repository = "oci://mcr.microsoft.com/application-lb/charts"
  chart      = "alb-controller"

  set {
    name  = "albController.podIdentity.clientID"
    value = azurerm_user_assigned_identity.alb.client_id
  }

  depends_on = [
    azurerm_kubernetes_cluster.aks,
    azurerm_federated_identity_credential.alb
  ]
}

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
