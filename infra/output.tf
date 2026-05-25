output "alb_id" {
  value = azapi_resource.alb.id
}

output "aks_name" {
  value = azurerm_kubernetes_cluster.aks.name
}

output "oidc_url" {
  value = azurerm_kubernetes_cluster.aks.oidc_issuer_url
}