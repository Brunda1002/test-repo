variable "subscription_id" {
  type = string
}

variable "location" {
  default = "eastus"
}

variable "tfstate_resource_group" {
  default = "rg-tfstate"
}

variable "tfstate_storage_account" {
  default = "sttfstateaksalb001"
}

variable "tfstate_container" {
  default = "tfstate"
}