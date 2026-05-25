############################################
# ALB CONTROLLER (Helm)
############################################

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

############################################
# APPLICATION LOAD BALANCER (Azure)
############################################

resource "azapi_resource" "alb" {
  type      = "Microsoft.ServiceNetworking/trafficControllers@2024-05-01-preview"
  name      = "alb-poc"
  parent_id = azurerm_resource_group.main.id
  location  = azurerm_resource_group.main.location

  body = {
    properties = {}
  }
}

# Role assignments for the ALB controller managed identity are provisioned
# manually via Azure CLI. See role-assignments.sh for the commands.
# This avoids the ABAC 403 that occurs when the deploying SP lacks
# Owner / User Access Administrator rights at the required scopes.
