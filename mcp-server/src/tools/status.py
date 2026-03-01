"""Status and deployment listing tools."""

from typing import Any

from ..github.client import GitHubClient


async def check_status(run_id: int) -> dict[str, Any]:
    """Check the status of a GitHub Actions workflow run.

    Args:
        run_id: The workflow run ID returned from provision/destroy

    Returns:
        Dict with run status, conclusion, and URL
    """
    gh = GitHubClient()
    return await gh.get_workflow_run(run_id)


async def list_deployments(
    status: str | None = None,
    limit: int = 10,
) -> list[dict[str, Any]]:
    """List recent infrastructure deployments (workflow runs).

    Args:
        status: Filter by status (queued, in_progress, completed)
        limit: Max results to return

    Returns:
        List of deployment summaries
    """
    gh = GitHubClient()
    return await gh.get_workflow_runs(
        workflow_file="prototype-provision.yaml",
        status=status,
        per_page=limit,
    )
