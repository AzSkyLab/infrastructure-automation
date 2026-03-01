"""Provision and destroy tools (prototype mode - triggers GitHub Actions)."""

import base64
import json
from typing import Any

from ..github.client import GitHubClient
from ..patterns.loader import load_patterns
from ..patterns.resolver import PatternResolver

WORKFLOW_FILE = "prototype-provision.yaml"


def _get_resolver() -> PatternResolver:
    return PatternResolver(load_patterns())


async def provision(
    pattern_name: str,
    environment: str,
    config: dict[str, Any],
    project: str,
    business_unit: str = "",
    owners: list[str] | None = None,
    location: str = "eastus",
    size: str | None = None,
) -> dict[str, Any]:
    """Provision infrastructure by triggering a GitHub Actions workflow.

    This is the prototype flow: MCP server triggers workflow_dispatch on
    infrastructure-automation repo, which runs terraform apply.

    Args:
        pattern_name: Pattern to provision (e.g., "key_vault")
        environment: Target environment (dev/staging/prod)
        config: Pattern-specific config (must include "name")
        project: Project name
        business_unit: Business unit for tagging
        owners: List of owner email addresses
        location: Azure region
        size: T-shirt size override

    Returns:
        Dict with trigger status and workflow info
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
    tfvars_json = json.dumps(tfvars)
    tfvars_b64 = base64.b64encode(tfvars_json.encode()).decode()

    state_key = resolver.compute_state_key(
        pattern_name, environment, config, metadata
    )

    # Trigger workflow
    gh = GitHubClient()
    result = await gh.trigger_workflow(
        WORKFLOW_FILE,
        inputs={
            "pattern": pattern_name,
            "environment": environment,
            "tfvars_json": tfvars_b64,
            "action": "create",
            "state_key": state_key,
        },
    )

    return {
        "status": "triggered",
        "action": "create",
        "pattern": pattern_name,
        "environment": environment,
        "state_key": state_key,
        "workflow": result,
    }


async def destroy(
    pattern_name: str,
    environment: str,
    config: dict[str, Any],
    project: str,
    business_unit: str = "",
    owners: list[str] | None = None,
    location: str = "eastus",
) -> dict[str, Any]:
    """Destroy infrastructure by triggering a GitHub Actions workflow.

    Args:
        pattern_name: Pattern to destroy
        environment: Target environment
        config: Pattern config (must include "name")
        project: Project name
        business_unit: Business unit
        owners: Owner emails
        location: Azure region

    Returns:
        Dict with trigger status
    """
    resolver = _get_resolver()

    metadata = {
        "project": project,
        "environment": environment,
        "business_unit": business_unit,
        "owners": owners or [],
        "location": location,
    }

    # Validate
    validation = resolver.validate_config(pattern_name, environment, config, metadata)
    if not validation["valid"]:
        return {"error": "Validation failed", "details": validation["errors"]}

    tfvars = resolver.resolve(pattern_name, environment, config, metadata)
    tfvars_json = json.dumps(tfvars)
    tfvars_b64 = base64.b64encode(tfvars_json.encode()).decode()

    state_key = resolver.compute_state_key(
        pattern_name, environment, config, metadata
    )

    # Trigger destroy workflow
    gh = GitHubClient()
    result = await gh.trigger_workflow(
        WORKFLOW_FILE,
        inputs={
            "pattern": pattern_name,
            "environment": environment,
            "tfvars_json": tfvars_b64,
            "action": "destroy",
            "state_key": state_key,
        },
    )

    return {
        "status": "triggered",
        "action": "destroy",
        "pattern": pattern_name,
        "environment": environment,
        "state_key": state_key,
        "workflow": result,
    }
