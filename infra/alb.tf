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

  lifecycle {
    # Azure may auto-assign tags from policy; ignore them to prevent
    # spurious updates that trigger long ARM operations.
    ignore_changes = [tags]
  }
}

############################################
# ALB SUBNET ASSOCIATION
# Links the delegated alb-subnet to the traffic controller.
# Without this the ALB controller cannot provision the Azure-side
# frontend and the Gateway condition never flips to Programmed=True.
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
    # `output` is read-only metadata populated by Azure after creation
    # (provisioningState, ARM type, etc.). The azapi provider detects it
    # as drift on every plan and sends a PUT to Azure, which blocks for
    # 10-12 minutes on a live association. Ignoring it prevents that.
    #
    # `tags` suppresses Azure Policy auto-tagging drift (e.g. Environment=Prod)
    # that would otherwise trigger the same unnecessary PUT.
    ignore_changes = [output, tags]
  }
}

# Role assignments for the ALB controller managed identity are provisioned
# by the pipeline's rbac job. The deploying SP has an ABAC condition that
# blocks Microsoft.Authorization/roleAssignments/write at these scopes.
