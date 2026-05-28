variable "resource_group_name" {
  type = string
}

variable "vnet_name" {
  type = string
}

variable "aks_cluster_name" {
  type = string
}

variable "name_prefix" {
  type = string
}

variable "subscription_id" {
  type = string
}

variable "acr_name" {
  description = "ACR name (e.g. grouperdevacrpoc)"
  type        = string
}

variable "grouper_image_tag" {
  description = "Grouper container image tag"
  type        = string
  default     = "latest"
}
