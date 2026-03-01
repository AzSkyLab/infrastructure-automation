"""GitHub API client for triggering workflows and pushing files."""

import base64
import os
import time
from typing import Any

import httpx
import jwt


class GitHubClient:
    """GitHub API client using GitHub App authentication."""

    def __init__(
        self,
        app_id: str | None = None,
        private_key: str | None = None,
        infra_repo: str | None = None,
        app_infra_repo: str | None = None,
    ):
        self.app_id = app_id or os.environ.get("INFRA_APP_ID", "")
        self.private_key = private_key or os.environ.get("INFRA_APP_PRIVATE_KEY", "")
        self.infra_repo = infra_repo or os.environ.get(
            "INFRA_REPO", "infrastructure-automation"
        )
        self.app_infra_repo = app_infra_repo or os.environ.get(
            "APP_INFRA_REPO", "app-infrastructure"
        )
        self.base_url = "https://api.github.com"
        self._installation_token: str | None = None
        self._token_expires: float = 0

    def _generate_jwt(self) -> str:
        """Generate a JWT for GitHub App authentication."""
        now = int(time.time())
        payload = {
            "iat": now - 60,
            "exp": now + (10 * 60),
            "iss": self.app_id,
        }
        return jwt.encode(payload, self.private_key, algorithm="RS256")

    async def _get_installation_token(self) -> str:
        """Get or refresh an installation access token."""
        if self._installation_token and time.time() < self._token_expires:
            return self._installation_token

        jwt_token = self._generate_jwt()
        async with httpx.AsyncClient() as client:
            # Get installations
            resp = await client.get(
                f"{self.base_url}/app/installations",
                headers={
                    "Authorization": f"Bearer {jwt_token}",
                    "Accept": "application/vnd.github+json",
                },
            )
            resp.raise_for_status()
            installations = resp.json()

            if not installations:
                raise RuntimeError("No GitHub App installations found")

            installation_id = installations[0]["id"]

            # Create installation token
            resp = await client.post(
                f"{self.base_url}/app/installations/{installation_id}/access_tokens",
                headers={
                    "Authorization": f"Bearer {jwt_token}",
                    "Accept": "application/vnd.github+json",
                },
            )
            resp.raise_for_status()
            token_data = resp.json()

            self._installation_token = token_data["token"]
            self._token_expires = time.time() + 3500  # ~58 min

        return self._installation_token  # type: ignore[return-value]

    async def _headers(self) -> dict[str, str]:
        """Get authenticated headers."""
        token = await self._get_installation_token()
        return {
            "Authorization": f"token {token}",
            "Accept": "application/vnd.github+json",
        }

    async def trigger_workflow(
        self,
        workflow_file: str,
        ref: str = "main",
        inputs: dict[str, str] | None = None,
    ) -> dict[str, Any]:
        """Trigger a workflow_dispatch event on the infrastructure-automation repo.

        Args:
            workflow_file: Workflow filename (e.g., "prototype-provision.yaml")
            ref: Git ref to run on
            inputs: Workflow inputs

        Returns:
            Dict with status and run info
        """
        headers = await self._headers()
        url = f"{self.base_url}/repos/{self.infra_repo}/actions/workflows/{workflow_file}/dispatches"

        payload: dict[str, Any] = {"ref": ref}
        if inputs:
            payload["inputs"] = inputs

        async with httpx.AsyncClient() as client:
            resp = await client.post(url, headers=headers, json=payload)
            resp.raise_for_status()

        return {"status": "triggered", "workflow": workflow_file, "inputs": inputs}

    async def push_tfvars(
        self,
        branch: str,
        pattern_name: str,
        tfvars_json: str,
        backend_hcl: str,
        commit_message: str,
    ) -> dict[str, Any]:
        """Push tfvars and backend config to a branch in app-infrastructure repo.

        Args:
            branch: Branch name (e.g., "myapp/dev")
            pattern_name: Pattern name for file path
            tfvars_json: JSON content for terraform.tfvars.json
            backend_hcl: HCL content for backend.hcl
            commit_message: Commit message

        Returns:
            Dict with commit info
        """
        headers = await self._headers()

        async with httpx.AsyncClient() as client:
            # Ensure branch exists (create from main if not)
            await self._ensure_branch(client, headers, branch)

            # Get current tree SHA for the branch
            ref_resp = await client.get(
                f"{self.base_url}/repos/{self.app_infra_repo}/git/ref/heads/{branch}",
                headers=headers,
            )
            ref_resp.raise_for_status()
            current_sha = ref_resp.json()["object"]["sha"]

            # Create blobs for both files
            tfvars_blob = await self._create_blob(
                client, headers, tfvars_json
            )
            backend_blob = await self._create_blob(
                client, headers, backend_hcl
            )

            # Create tree with both files
            tree_resp = await client.post(
                f"{self.base_url}/repos/{self.app_infra_repo}/git/trees",
                headers=headers,
                json={
                    "base_tree": current_sha,
                    "tree": [
                        {
                            "path": f"{pattern_name}/terraform.tfvars.json",
                            "mode": "100644",
                            "type": "blob",
                            "sha": tfvars_blob,
                        },
                        {
                            "path": f"{pattern_name}/backend.hcl",
                            "mode": "100644",
                            "type": "blob",
                            "sha": backend_blob,
                        },
                    ],
                },
            )
            tree_resp.raise_for_status()
            tree_sha = tree_resp.json()["sha"]

            # Create commit
            commit_resp = await client.post(
                f"{self.base_url}/repos/{self.app_infra_repo}/git/commits",
                headers=headers,
                json={
                    "message": commit_message,
                    "tree": tree_sha,
                    "parents": [current_sha],
                },
            )
            commit_resp.raise_for_status()
            commit_sha = commit_resp.json()["sha"]

            # Update branch ref
            await client.patch(
                f"{self.base_url}/repos/{self.app_infra_repo}/git/refs/heads/{branch}",
                headers=headers,
                json={"sha": commit_sha},
            )

        return {
            "branch": branch,
            "commit_sha": commit_sha,
            "files": [
                f"{pattern_name}/terraform.tfvars.json",
                f"{pattern_name}/backend.hcl",
            ],
        }

    async def get_workflow_runs(
        self,
        workflow_file: str | None = None,
        status: str | None = None,
        per_page: int = 10,
    ) -> list[dict[str, Any]]:
        """List recent workflow runs.

        Args:
            workflow_file: Filter by workflow file name
            status: Filter by status (queued, in_progress, completed)
            per_page: Number of results

        Returns:
            List of workflow run summaries
        """
        headers = await self._headers()
        params: dict[str, Any] = {"per_page": per_page}
        if status:
            params["status"] = status

        if workflow_file:
            url = f"{self.base_url}/repos/{self.infra_repo}/actions/workflows/{workflow_file}/runs"
        else:
            url = f"{self.base_url}/repos/{self.infra_repo}/actions/runs"

        async with httpx.AsyncClient() as client:
            resp = await client.get(url, headers=headers, params=params)
            resp.raise_for_status()
            data = resp.json()

        return [
            {
                "id": run["id"],
                "name": run.get("name", ""),
                "status": run["status"],
                "conclusion": run.get("conclusion"),
                "created_at": run["created_at"],
                "html_url": run["html_url"],
            }
            for run in data.get("workflow_runs", [])
        ]

    async def get_workflow_run(self, run_id: int) -> dict[str, Any]:
        """Get details for a specific workflow run."""
        headers = await self._headers()

        async with httpx.AsyncClient() as client:
            resp = await client.get(
                f"{self.base_url}/repos/{self.infra_repo}/actions/runs/{run_id}",
                headers=headers,
            )
            resp.raise_for_status()
            run = resp.json()

        return {
            "id": run["id"],
            "name": run.get("name", ""),
            "status": run["status"],
            "conclusion": run.get("conclusion"),
            "created_at": run["created_at"],
            "updated_at": run["updated_at"],
            "html_url": run["html_url"],
        }

    async def _ensure_branch(
        self, client: httpx.AsyncClient, headers: dict, branch: str
    ) -> None:
        """Ensure a branch exists in app-infrastructure, creating from main if needed."""
        resp = await client.get(
            f"{self.base_url}/repos/{self.app_infra_repo}/git/ref/heads/{branch}",
            headers=headers,
        )
        if resp.status_code == 200:
            return

        # Get main branch SHA
        main_resp = await client.get(
            f"{self.base_url}/repos/{self.app_infra_repo}/git/ref/heads/main",
            headers=headers,
        )
        main_resp.raise_for_status()
        main_sha = main_resp.json()["object"]["sha"]

        # Create branch
        await client.post(
            f"{self.base_url}/repos/{self.app_infra_repo}/git/refs",
            headers=headers,
            json={"ref": f"refs/heads/{branch}", "sha": main_sha},
        )

    async def _create_blob(
        self, client: httpx.AsyncClient, headers: dict, content: str
    ) -> str:
        """Create a blob in the app-infrastructure repo."""
        resp = await client.post(
            f"{self.base_url}/repos/{self.app_infra_repo}/git/blobs",
            headers=headers,
            json={"content": content, "encoding": "utf-8"},
        )
        resp.raise_for_status()
        return resp.json()["sha"]
