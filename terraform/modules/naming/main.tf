# terraform/modules/naming/main.tf
# Generates consistent resource names across all patterns

terraform {
  required_version = ">= 1.5.0"
}

locals {
  # Azure resource naming prefixes
  prefixes = {
    keyvault           = "kv"
    postgresql         = "psql"
    mongodb            = "cosmos"
    storage_account    = "st"
    function_app       = "func"
    resource_group     = "rg"
    security_group     = "sg"
    azure_sql          = "sql"
    eventhub           = "evh"
    static_web_app     = "swa"
    aks_namespace      = "ns"
    container_app      = "ca"
    container_env      = "cae"
    container_registry = "cr"
    linux_vm           = "vm"
    private_endpoint   = "pe"
    log_analytics      = "log"
    app_insights       = "appi"
    service_plan       = "asp"
  }

  # Environment abbreviations for constrained resources
  env_abbrev = {
    prototype = "x"
    dev       = "d"
    tst       = "t"
    stg       = "s"
    prd       = "p"
  }

  # Standard name pattern: {prefix}-{project}-{name}-{env}
  standard_name = "${lookup(local.prefixes, var.resource_type, var.resource_type)}-${var.project}-${var.name}-${var.environment}"

  # Storage accounts: no hyphens, max 24 chars, lowercase only
  # Format: st{project}{name}{env_abbrev} - use abbreviation to save chars
  # Clean project and name by removing hyphens
  storage_project = lower(replace(var.project, "-", ""))
  storage_suffix  = lower(replace(var.name, "-", ""))
  storage_env     = lookup(local.env_abbrev, var.environment, substr(var.environment, 0, 1))
  # Prefix (2) + env (1) = 3 reserved chars, leaving 21 for project+name
  # Split roughly: 14 for project, 7 for name (adjustable)
  storage_project_max = min(length(local.storage_project), 14)
  storage_suffix_max  = min(length(local.storage_suffix), 21 - local.storage_project_max)
  storage_name = lower(join("", [
    "st",
    substr(local.storage_project, 0, local.storage_project_max),
    substr(local.storage_suffix, 0, local.storage_suffix_max),
    local.storage_env
  ]))

  # Key Vault: max 24 chars, alphanumeric and hyphens only, must end with letter/digit
  # Format: kv-{project}-{name}-{env_abbrev}
  keyvault_env       = lookup(local.env_abbrev, var.environment, substr(var.environment, 0, 1))
  keyvault_base      = "kv-${var.project}-${var.name}-${local.keyvault_env}"
  keyvault_truncated = substr(local.keyvault_base, 0, 24)
  # Remove trailing hyphens after truncation to ensure valid Key Vault name
  keyvault_name = trimsuffix(local.keyvault_truncated, "-")

  # Container Registry: alphanumeric only, 5-50 chars
  # Format: cr{project}{name}{env_abbrev}
  cr_project = lower(replace(var.project, "-", ""))
  cr_suffix  = lower(replace(var.name, "-", ""))
  cr_env     = lookup(local.env_abbrev, var.environment, substr(var.environment, 0, 1))
  cr_name = lower(join("", [
    "cr",
    substr(local.cr_project, 0, min(length(local.cr_project), 20)),
    substr(local.cr_suffix, 0, min(length(local.cr_suffix), 20)),
    local.cr_env
  ]))

  # Select appropriate name based on resource type
  resource_name = var.resource_type == "storage_account" ? local.storage_name : (
    var.resource_type == "keyvault" ? local.keyvault_name : (
      var.resource_type == "container_registry" ? local.cr_name : local.standard_name
    )
  )

  # Resource group includes pattern name for uniqueness across patterns
  # If pattern_name is empty, fall back to project-environment only
  resource_group_name = var.pattern_name != "" ? "rg-${var.project}-${var.pattern_name}-${var.environment}" : "rg-${var.project}-${var.environment}"
}
