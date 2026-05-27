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

# Uses ~/.kube/config written by:
#   - Locally / Cloud Shell: az aks get-credentials --admin
#   - GitHub Actions:        "Get AKS Credentials" step in alb-stage1.yml
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
