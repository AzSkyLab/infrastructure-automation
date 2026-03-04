"""Provision and destroy tools (prototype mode).

Provision pushes tfvars to app-infrastructure repo (same as production GitOps).
Destroy still triggers workflow_dispatch since it needs terraform destroy.
"""

import base64
import json
import logging
from typing import Any

from ..github.client import GitHubClient
from ..patterns.loader import load_patterns
from ..patterns.resolver import PatternResolver
from ._push import push_pattern

logger = logging.getLogger(__name__)

WORKFLOW_FILE = "prototype-provision.yaml"

# Module-level client for connection reuse (destroy only)
_github_client: GitHubClient | None = None


def _get_github_client() -> GitHubClient:
    global _github_client
    if _github_client is None:
        _github_client = GitHubClient()
    return _github_client


def _get_resolver() -> PatternResolver:
    return PatternResolver(load_patterns())


async def provision(
    pattern_name: str,
    config: dict[str, Any],
    project: str,
    application_id: str,
    application_name: str,
    business_unit: str = "",
    owners: list[str] | None = None,
    location: str = "eastus",
    size: str | None = None,
    tier: int = 4,
) -> dict[str, Any]:
    """Provision infrastructure to the prototype environment.

    Pushes tfvars to app-infrastructure repo, which triggers terraform apply
    via the terraform-apply workflow.
    """
    environment = "prototype"

    metadata = {
        "project": project,
        "environment": environment,
        "business_unit": business_unit,
        "owners": owners or [],
        "location": location,
        "application_id": application_id,
        "application_name": application_name,
        "tier": tier,
    }

    resolved_config = dict(config)
    if size:
        resolved_config["size"] = size

    return await push_pattern(
        pattern_name=pattern_name,
        environment=environment,
        config=resolved_config,
        metadata=metadata,
        commit_prefix="prototype",
    )


async def destroy(
    pattern_name: str,
    config: dict[str, Any],
    project: str,
    application_id: str,
    application_name: str,
    business_unit: str = "",
    owners: list[str] | None = None,
    location: str = "eastus",
    tier: int = 4,
) -> dict[str, Any]:
    """Destroy prototype infrastructure by triggering a GitHub Actions workflow.

    Destroy requires running terraform destroy, so it still uses
    workflow_dispatch with base64-encoded tfvars.
    """
    environment = "prototype"
    resolver = _get_resolver()

    metadata = {
        "project": project,
        "environment": environment,
        "business_unit": business_unit,
        "owners": owners or [],
        "location": location,
        "application_id": application_id,
        "application_name": application_name,
        "tier": tier,
    }

    resolved_config = dict(config)

    # Validate
    validation = resolver.validate_config(
        pattern_name, environment, resolved_config, metadata
    )
    if not validation["valid"]:
        return {"error": "Validation failed", "details": validation["errors"]}

    tfvars = resolver.resolve(pattern_name, environment, resolved_config, metadata)
    tfvars_json = json.dumps(tfvars)
    tfvars_b64 = base64.b64encode(tfvars_json.encode()).decode()

    state_key = resolver.compute_state_key(
        pattern_name, environment, resolved_config, metadata
    )

    # Trigger destroy workflow
    gh = _get_github_client()
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

    logger.info(
        "Triggered destroy: %s/prototype for %s", pattern_name, project
    )
    return {
        "status": "triggered",
        "action": "destroy",
        "pattern": pattern_name,
        "environment": environment,
        "state_key": state_key,
        "workflow": result,
    }
