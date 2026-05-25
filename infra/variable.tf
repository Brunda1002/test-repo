variable "subscription_id" {
  type = string
}

variable "location" {
  default = "eastus"
}

variable "resource_group_name" {
  default = "rg-aks-alb-poc"
}

variable "vnet_name" {
  default = "vnet-aks-alb-poc"
}

variable "aks_cluster_name" {
  default = "aks-alb-poc"
}

variable "dns_prefix" {
  default = "aksalb"
}

variable "vnet_address_space" {
  default = ["10.0.0.0/16"]
}

variable "aks_subnet_prefix" {
  default = ["10.0.1.0/24"]
}

variable "alb_subnet_prefix" {
  default = ["10.0.2.0/24"]
}