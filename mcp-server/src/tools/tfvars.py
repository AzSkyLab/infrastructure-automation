"""Production mode: push tfvars to app-infrastructure repo."""

import json
from typing import Any

from ..github.client import GitHubClient
from ..patterns.loader import load_patterns
from ..patterns.resolver import PatternResolver


def _get_resolver() -> PatternResolver:
    return PatternResolver(load_patterns())


async def push_tfvars(
    pattern_name: str,
    environment: str,
    config: dict[str, Any],
    project: str,
    business_unit: str = "",
    owners: list[str] | None = None,
    location: str = "eastus",
    size: str | None = None,
) -> dict[str, Any]:
    """Push Terraform tfvars to app-infrastructure repo for GitOps deployment.

    Creates/updates a branch {project}/{environment} with the pattern's
    terraform.tfvars.json and backend.hcl. Push triggers the terraform-apply
    workflow in app-infrastructure.

    Args:
        pattern_name: Pattern to deploy (e.g., "key_vault")
        environment: Target environment (dev/staging/prod)
        config: Pattern-specific config (must include "name")
        project: Project name
        business_unit: Business unit
        owners: Owner emails
        location: Azure region
        size: T-shirt size override

    Returns:
        Dict with commit info and branch details
    """
    resolver = _get_resolver()

    metadata = {
        "project": project,
        "environment": environment,
        "business_unit": business_unit,
        "owners": owners or [],
        "location": location,
    }

    if size:
        config["size"] = size

    # Validate and resolve
    validation = resolver.validate_config(pattern_name, environment, config, metadata)
    if not validation["valid"]:
        return {"error": "Validation failed", "details": validation["errors"]}

    tfvars = resolver.resolve(pattern_name, environment, config, metadata)
    state_key = resolver.compute_state_key(
        pattern_name, environment, config, metadata
    )

    tfvars_json = json.dumps(tfvars, indent=2)

    # Generate backend.hcl
    backend_hcl = f"""# Auto-generated backend configuration
resource_group_name  = "${{TF_STATE_RESOURCE_GROUP}}"
storage_account_name = "${{TF_STATE_STORAGE_ACCOUNT}}"
container_name       = "${{TF_STATE_CONTAINER}}"
key                  = "{state_key}"
"""

    branch = f"{project}/{environment}"
    commit_message = f"deploy: {pattern_name} for {project}/{environment}"

    gh = GitHubClient()
    result = await gh.push_tfvars(
        branch=branch,
        pattern_name=pattern_name,
        tfvars_json=tfvars_json,
        backend_hcl=backend_hcl,
        commit_message=commit_message,
    )

    return {
        "status": "pushed",
        "branch": branch,
        "pattern": pattern_name,
        "environment": environment,
        "state_key": state_key,
        "commit": result,
    }
