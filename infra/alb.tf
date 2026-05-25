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

############################################
# ALB SUBNET ASSOCIATION
# Links the delegated alb-subnet to the traffic controller.
# Without this the ALB controller cannot provision the Azure-side
# frontend and the Gateway condition never flips to Programmed=True.
#
# setup.sh creates this resource via az CLI before Phase 1 runs,
# then imports it into state so Terraform manages it from that point on.
# On subsequent runs Terraform refreshes and no-ops this resource.
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
}

# Role assignments for the ALB controller managed identity are provisioned
# by setup.sh. The deploying SP has an ABAC condition that blocks
# Microsoft.Authorization/roleAssignments/write at these scopes.
