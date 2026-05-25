resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_virtual_network" "main" {
  name                = var.vnet_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = var.vnet_address_space
}

resource "azurerm_subnet" "aks" {
  name                 = "aks-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = var.aks_subnet_prefix
}

resource "azurerm_subnet" "alb" {
  name                 = "alb-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = var.alb_subnet_prefix

  delegation {
    name = "albdelegation"

    service_delegation {
      name = "Microsoft.ServiceNetworking/trafficControllers"
      # Azure auto-assigns this action when the delegation is created.
      # Declaring it explicitly prevents Terraform detecting drift and
      # removing it on every plan, which would break ALB subnet access.
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_kubernetes_cluster" "aks" {
  name                = var.aks_cluster_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix          = var.dns_prefix

  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  default_node_pool {
    name           = "system"
    node_count     = 1
    vm_size        = "Standard_DS2_v2"
    vnet_subnet_id = azurerm_subnet.aks.id

    # Azure sets these upgrade defaults automatically.
    # Declaring them here prevents drift warnings and the associated
    # 2-minute AKS update on every Phase 2 apply.
    upgrade_settings {
      max_surge                     = "10%"
      drain_timeout_in_minutes      = 0
      node_soak_duration_in_minutes = 0
    }
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin = "azure"
    service_cidr   = "172.16.0.0/16"
    dns_service_ip = "172.16.0.10"
  }
}

############################################
# DEDICATED USER ASSIGNED MANAGED IDENTITY
# FOR ALB CONTROLLER (workload identity)
############################################

resource "azurerm_user_assigned_identity" "alb" {
  name                = var.alb_identity_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
}

############################################
# FEDERATED IDENTITY CREDENTIAL
# Links AKS OIDC issuer → alb-controller SA
############################################

resource "azurerm_federated_identity_credential" "alb" {
  name                = "alb-controller-federated"
  resource_group_name = azurerm_resource_group.main.name
  parent_id           = azurerm_user_assigned_identity.alb.id

  audience = ["api://AzureADTokenExchange"]
  issuer   = azurerm_kubernetes_cluster.aks.oidc_issuer_url
  subject  = "system:serviceaccount:azure-alb-system:alb-controller-sa"
}
