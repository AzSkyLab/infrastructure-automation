# terraform/modules/naming/outputs.tf

output "name" {
  description = "Generated resource name"
  value       = local.resource_name
}

output "resource_group_name" {
  description = "Generated resource group name"
  value       = local.resource_group_name
}

output "prefix" {
  description = "Prefix used for this resource type"
  value       = lookup(local.prefixes, var.resource_type, var.resource_type)
}

output "tags" {
  description = "Standard tags for the resource"
  value = {
    Project         = var.project
    Environment     = var.environment
    BusinessUnit    = var.business_unit
    ApplicationId   = var.application_id
    ApplicationName = var.application_name
    Tier            = tostring(var.tier)
    CostCenter      = var.cost_center
    ManagedBy       = "Terraform-Patterns"
  }
}
