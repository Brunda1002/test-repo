# Remote state stored in Azure Blob Storage
# The storage account + container must exist BEFORE running terraform init
# Run bootstrap/setup_backend.sh once to create them

terraform {
  backend "azurerm" {
    resource_group_name  = "rg-grouper-tf-state"
    storage_account_name = "stgroupertfstate"   # must be globally unique — change this
    container_name       = "tfstate"
    key                  = "grouper-infra.tfstate"
  }
}
