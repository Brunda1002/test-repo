subscription_id  = "91ea5a42-5e9b-4c0c-a766-ea2a2aaa3ace"
name_prefix      = "grouper-poc"
location         = "eastus"
environment      = "poc"

# Must be globally unique, alphanumeric only, 5-50 chars
acr_name         = "acrgrouperpoc001"

# key_vault_name must already exist in Azure before running apply
# If you don't have one yet, comment out key_vault references in main.tf
key_vault_name   = "kv-grouper-poc"
