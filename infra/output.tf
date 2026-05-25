output "alb_id" {
  value = azapi_resource.alb.id
}

output "aks_name" {
  value = azurerm_kubernetes_cluster.aks.name
}

output "oidc_url" {
  value = azurerm_kubernetes_cluster.aks.oidc_issuer_url
}

output "alb_identity_client_id" {
  value = azurerm_user_assigned_identity.alb.client_id
}

output "alb_identity_principal_id" {
  value = azurerm_user_assigned_identity.alb.principal_id
}

output "alb_resource_id" {
  value = azapi_resource.alb.id
}

output "resource_group_id" {
  value = azurerm_resource_group.main.id
}
