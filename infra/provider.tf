terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.2.0"
    }

    azuread = {
      source  = "hashicorp/azuread"
      version = "3.0.2"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.32.0"
    }

    helm = {
      source  = "hashicorp/helm"
      version = "2.16.1"
    }

    azapi = {
      source  = "Azure/azapi"
      version = "2.0.1"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

provider "azuread" {}

# The kubernetes and helm providers use the kubeconfig written by
# `az aks get-credentials` in the GitHub Actions app job.
# This avoids provider-init-time failures that occur when
# referencing a resource or data source (both are evaluated
# after providers are already initialized).
provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = var.aks_cluster_name
}

provider "helm" {
  kubernetes {
    config_path    = "~/.kube/config"
    config_context = var.aks_cluster_name
  }
}

provider "azapi" {}
