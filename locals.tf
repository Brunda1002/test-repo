locals {
  tags = {
    ManagedBy   = "Terraform"
    Environment = var.environment
    Workload    = "grouper"
    Prefix      = var.name_prefix
  }
}
