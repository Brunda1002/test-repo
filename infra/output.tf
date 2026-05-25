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
  description = "Client ID of the ALB controller managed identity"
  value       = azurerm_user_assigned_identity.alb.client_id
}

output "alb_identity_principal_id" {
  description = "Principal ID — use this in the manual role assignment CLI commands"
  value       = azurerm_user_assigned_identity.alb.principal_id
}

output "alb_resource_id" {
  description = "Full resource ID of the ALB traffic controller — use as --scope in the Reader assignment"
  value       = azapi_resource.alb.id
}

output "resource_group_id" {
  description = "Full resource ID of the resource group — use as --scope in the Network Contributor assignment"
  value       = azurerm_resource_group.main.id
}
