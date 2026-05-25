data "azurerm_resource_group" "tfstate" {
  name = var.tfstate_resource_group
}

data "azurerm_storage_account" "tfstate" {
  name                = var.tfstate_storage_account
  resource_group_name = data.azurerm_resource_group.tfstate.name
}

resource "azapi_resource" "tfstate_container" {
  type      = "Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01"
  name      = var.tfstate_container
  parent_id = "${data.azurerm_storage_account.tfstate.id}/blobServices/default"

  body = {
    properties = {
      publicAccess = "None"
    }
  }
}
 