output "aks_cluster_name" {
  value = azurerm_kubernetes_cluster.grouper.name
}

output "aks_oidc_url" {
  value = azurerm_kubernetes_cluster.grouper.oidc_issuer_url
}

output "acr_login_server" {
  value = azurerm_container_registry.grouper.login_server
}

output "psql_fqdn" {
  value     = azurerm_postgresql_flexible_server.grouper.fqdn
  sensitive = true
}

output "resource_group_name" {
  value = azurerm_resource_group.grouper.name
}
