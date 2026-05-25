# ============================================================
# Template 1 — Grouper AKS Infrastructure (new account)
# Mirrors the calstate pattern: VNet + AKS + ACR + PostgreSQL + Key Vault
# Single environment version (no dev/prod split) — easy to duplicate
# ============================================================

# ----- Resource Group -----
resource "azurerm_resource_group" "grouper" {
  name     = "rg-${var.name_prefix}"
  location = var.location
  tags     = local.tags
}

# ----- Networking -----
resource "azurerm_virtual_network" "grouper" {
  name                = "vnet-${var.name_prefix}"
  location            = azurerm_resource_group.grouper.location
  resource_group_name = azurerm_resource_group.grouper.name
  address_space       = [var.vnet_cidr]
  tags                = local.tags
}

resource "azurerm_subnet" "aks" {
  name                 = "snet-${var.name_prefix}-aks"
  resource_group_name  = azurerm_resource_group.grouper.name
  virtual_network_name = azurerm_virtual_network.grouper.name
  address_prefixes     = [var.aks_subnet_cidr]

  service_endpoints = ["Microsoft.KeyVault"]
}

resource "azurerm_subnet" "psql" {
  name                 = "snet-${var.name_prefix}-psql"
  resource_group_name  = azurerm_resource_group.grouper.name
  virtual_network_name = azurerm_virtual_network.grouper.name
  address_prefixes     = [var.psql_subnet_cidr]

  delegation {
    name = "psql-flex-delegation"
    service_delegation {
      name    = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }

  service_endpoints = ["Microsoft.Storage"]
}

# ----- ACR -----
resource "azurerm_container_registry" "grouper" {
  name                = var.acr_name
  resource_group_name = azurerm_resource_group.grouper.name
  location            = azurerm_resource_group.grouper.location
  sku                 = "Basic"
  admin_enabled       = false
  tags                = local.tags
}

# ----- AKS -----
resource "azurerm_kubernetes_cluster" "grouper" {
  name                = "aks-${var.name_prefix}"
  location            = azurerm_resource_group.grouper.location
  resource_group_name = azurerm_resource_group.grouper.name
  dns_prefix          = "${var.name_prefix}-aks"

  oidc_issuer_enabled = true

  default_node_pool {
    name           = "system"
    node_count     = var.node_count
    vm_size        = var.node_vm_size
    vnet_subnet_id = azurerm_subnet.aks.id

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
    network_plugin     = "azure"
    network_data_plane = "cilium"
    network_policy     = "cilium"
    service_cidr       = var.service_cidr
    dns_service_ip     = var.dns_service_ip
  }

  key_vault_secrets_provider {
    secret_rotation_enabled = true
  }

  tags = local.tags
}

# Give AKS permission to pull from ACR
resource "azurerm_role_assignment" "aks_acr_pull" {
  scope                = azurerm_container_registry.grouper.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.grouper.kubelet_identity[0].object_id
}

# ----- PostgreSQL -----
resource "azurerm_private_dns_zone" "psql" {
  name                = "${var.name_prefix}.postgres.database.azure.com"
  resource_group_name = azurerm_resource_group.grouper.name
  tags                = local.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "psql" {
  name                  = "${var.name_prefix}-psql-dns-link"
  resource_group_name   = azurerm_resource_group.grouper.name
  private_dns_zone_name = azurerm_private_dns_zone.psql.name
  virtual_network_id    = azurerm_virtual_network.grouper.id
  registration_enabled  = false
  tags                  = local.tags
}

resource "random_password" "psql_admin" {
  length           = 20
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "azurerm_postgresql_flexible_server" "grouper" {
  name                = "psql-${var.name_prefix}-grouper"
  resource_group_name = azurerm_resource_group.grouper.name
  location            = azurerm_resource_group.grouper.location

  version                      = "16"
  administrator_login          = var.psql_admin_login
  administrator_password       = random_password.psql_admin.result
  sku_name                     = var.psql_sku
  storage_mb                   = 32768
  backup_retention_days        = 7
  geo_redundant_backup_enabled = false
  delegated_subnet_id          = azurerm_subnet.psql.id
  private_dns_zone_id          = azurerm_private_dns_zone.psql.id
  public_network_access_enabled = false
  zone                         = "1"

  tags = local.tags


  depends_on = [azurerm_private_dns_zone_virtual_network_link.psql]
}

resource "azurerm_postgresql_flexible_server_database" "grouper" {
  name      = "grouper"
  server_id = azurerm_postgresql_flexible_server.grouper.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}


# ----- Key Vault (write secrets into existing KV) -----
# Skipped when key_vault_name is left empty in terraform.tfvars
data "azurerm_key_vault" "grouper" {
  count               = var.key_vault_name != "" ? 1 : 0
  name                = var.key_vault_name
  resource_group_name = azurerm_resource_group.grouper.name
}

resource "azurerm_key_vault_secret" "psql_login" {
  count        = var.key_vault_name != "" ? 1 : 0
  name         = "grouper-postgresql-admin-login"
  value        = var.psql_admin_login
  key_vault_id = data.azurerm_key_vault.grouper[0].id
  content_type = "text/plain"
}

resource "azurerm_key_vault_secret" "psql_password" {
  count        = var.key_vault_name != "" ? 1 : 0
  name         = "grouper-postgresql-admin-password"
  value        = random_password.psql_admin.result
  key_vault_id = data.azurerm_key_vault.grouper[0].id
  content_type = "text/plain"
}

resource "azurerm_key_vault_secret" "psql_host" {
  count        = var.key_vault_name != "" ? 1 : 0
  name         = "grouper-postgresql-host"
  value        = azurerm_postgresql_flexible_server.grouper.fqdn
  key_vault_id = data.azurerm_key_vault.grouper[0].id
  content_type = "text/plain"
}

resource "azurerm_key_vault_secret" "psql_db" {
  count        = var.key_vault_name != "" ? 1 : 0
  name         = "grouper-postgresql-database"
  value        = azurerm_postgresql_flexible_server_database.grouper.name
  key_vault_id = data.azurerm_key_vault.grouper[0].id
  content_type = "text/plain"
}
