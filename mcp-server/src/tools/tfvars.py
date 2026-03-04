"""Production mode: push tfvars to app-infrastructure repo."""

import logging
from typing import Any

from ._push import push_pattern

logger = logging.getLogger(__name__)


async def push_tfvars(
    pattern_name: str,
    environment: str,
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
    """Push Terraform tfvars to app-infrastructure repo for GitOps deployment.

    Creates/updates folder {application_id}/{application_name}/{environment}/{pattern_name}/
    on main with terraform.tfvars.json and backend.hcl. Push triggers the
    terraform-apply workflow in app-infrastructure.

    Not available for the prototype environment — use provision() instead.
    """
    if environment == "prototype":
        return {
            "error": "Cannot use push_tfvars for the prototype environment. "
            "Use the provision tool instead."
        }

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
        commit_prefix="deploy",
    )
