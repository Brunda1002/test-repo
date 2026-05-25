variable "subscription_id" {
  type        = string
  description = "Azure subscription ID"
}

variable "location" {
  type        = string
  default     = "eastus"
  description = "Azure region"
}

variable "name_prefix" {
  type        = string
  description = "Short prefix used for all resource names, e.g. 'grouper-poc'"
}

variable "environment" {
  type        = string
  default     = "poc"
  description = "Environment tag value"
}

# --- Networking ---
variable "vnet_cidr" {
  type    = string
  default = "10.10.0.0/22"
}

variable "aks_subnet_cidr" {
  type    = string
  default = "10.10.0.0/23"
}

variable "psql_subnet_cidr" {
  type    = string
  default = "10.10.2.0/27"
}

variable "service_cidr" {
  type    = string
  default = "172.16.0.0/16"
}

variable "dns_service_ip" {
  type    = string
  default = "172.16.0.10"
}

# --- ACR ---
variable "acr_name" {
  type        = string
  description = "Must be globally unique, only alphanumeric"
}

# --- AKS ---
variable "node_count" {
  type    = number
  default = 2
}

variable "node_vm_size" {
  type    = string
  default = "Standard_DS2_v2"
}

# --- PostgreSQL ---
variable "psql_admin_login" {
  type    = string
  default = "grouperadmin"
}

variable "psql_sku" {
  type    = string
  default = "B_Standard_B2ms"
}

# --- Key Vault ---
variable "key_vault_name" {
  type        = string
  description = "Name of a pre-existing Key Vault in the same resource group"
}
