# terraform {
#   required_providers {
#     azurerm = {
#       source  = "hashicorp/azurerm"
#       version = "~> 4.2"
#     }

#     azapi = {
#       source  = "azure/azapi"
#       version = "~> 2.0"
#     }

#     helm = {
#       source  = "hashicorp/helm"
#       version = "~> 2.16"
#     }

#     kubernetes = {
#       source  = "hashicorp/kubernetes"
#       version = "~> 2.32"
#     }
#   }
# }

# provider "azurerm" {
#   features {}
#   subscription_id = var.subscription_id
# }

# provider "azapi" {
#   subscription_id = var.subscription_id
# }

# provider "helm" {
#   kubernetes {
#     host                   = data.azurerm_kubernetes_cluster.grouper.kube_config[0].host
#     client_certificate     = base64decode(data.azurerm_kubernetes_cluster.grouper.kube_config[0].client_certificate)
#     client_key             = base64decode(data.azurerm_kubernetes_cluster.grouper.kube_config[0].client_key)
#     cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.grouper.kube_config[0].cluster_ca_certificate)
#   }
# }

# provider "kubernetes" {
#   host                   = data.azurerm_kubernetes_cluster.grouper.kube_config[0].host
#   client_certificate     = base64decode(data.azurerm_kubernetes_cluster.grouper.kube_config[0].client_certificate)
#   client_key             = base64decode(data.azurerm_kubernetes_cluster.grouper.kube_config[0].client_key)
#   cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.grouper.kube_config[0].cluster_ca_certificate)
# }

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.2"
    }

    azapi = {
      source  = "azure/azapi"
      version = "~> 2.0"
    }

    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.16"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.32"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

provider "azapi" {
  subscription_id = var.subscription_id
}

# ── Local / Cloud Shell: uses ~/.kube/config (after az aks get-credentials --admin)
# ── GitHub Actions:      uses ~/.kube/config written by the "Get AKS Credentials" step
# Removed inline kube_config[0] — that bypasses local kubeconfig and hits the
# AKS API endpoint directly, which fails when the runner/machine IP is not
# yet reflected or the connection goes through a different route.
provider "helm" {
  kubernetes {
    config_path    = "~/.kube/config"
    config_context = "aks-grouper-dev-cluster-admin"
  }
}

provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "aks-grouper-dev-cluster-admin"
}
