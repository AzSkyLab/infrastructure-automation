# CLAUDE.md

This file provides guidance to Claude Code when working with this repository.

## Platform Overview

Enterprise cloud platform on Azure serving multiple business units. Follows a hub-spoke architecture with centralized IT governance. Developers interact with an MCP server via Claude Code to provision Azure resources using approved infrastructure patterns in a prototyping subscription.

- **Hub-spoke architecture** with centralized IT governance
- **Multiple Azure subscriptions** (hub, shared services, workload spokes)
- **T-shirt sizing** (S, M, L, XL) for right-sizing infrastructure
- **Application tiers 1-4** drive HA/DR, backup, monitoring, and failover decisions
- **Promotion model:** Developers prototype via MCP server; DevOps promotes to production

## Architecture

```
Developer (Claude Code)
  -> MCP Server (Python, Azure Container App)
     -> provision tool (prototype only):
        -> Pushes tfvars to app-infrastructure repo at {app_id}/{app_name}/prototype/{pattern}/
        -> Push to main triggers terraform-apply.yaml (folder-based GitOps)
     -> destroy tool (prototype only):
        -> Triggers workflow_dispatch on prototype-provision.yaml (needs terraform destroy)
     -> push_tfvars tool (DevOps, non-prototype envs):
        -> Pushes tfvars to app-infrastructure repo
        -> Push to main triggers terraform-apply.yaml

Promotion (DevOps, GitHub Actions UI):
  -> promote.yaml workflow_dispatch
     -> Copies tfvars from source env, adjusts sizing for target env
     -> Creates PR against app-infrastructure main
     -> PR merge triggers terraform-apply.yaml

All tfvars are stored in app-infrastructure: {app_id}/{app_name}/{environment}/{pattern}/
ArgoCD manages all Kubernetes changes.
```

### Provisioning Modes

- **Prototype mode** (`provision`): MCP server pushes tfvars to `app-infrastructure` repo at `{app_id}/{app_name}/prototype/{pattern}/`. Push to main triggers `terraform-apply.yaml`. Always targets the `prototype` environment.
- **Destroy** (`destroy`): Triggers `prototype-provision.yaml` via workflow_dispatch with base64-encoded tfvars and `action=destroy`. Always targets prototype.
- **Production mode** (`push_tfvars`): DevOps pushes tfvars to `app-infrastructure` at `{app_id}/{app_name}/{environment}/{pattern}/` for non-prototype environments.
- **Promotion** (`promote.yaml`): PR-based promotion between environments. Copies source tfvars, adjusts sizing, creates PR. Merge triggers deployment.

### Promotion Path

```
prototype -> dev -> tst -> stg -> prd
```

Not all apps move beyond prototype — it's a stable state. DevOps manages promotion via the `promote.yaml` workflow.

## Application Tiers

| Tier | Priority | RTO | HA/DR | Description |
|------|----------|-----|-------|-------------|
| 1 | Highest | 4 hours | Cross-region HA/DR | Mission-critical, always available |
| 2 | High | 8 hours | Single-region HA | Business-critical with redundancy |
| 3 | Medium | 24 hours | Backup/restore | Standard workloads |
| 4 | Low | 72 hours | Best-effort | Non-critical, dev/test |

Tier assignment drives: redundancy, backup frequency, monitoring sensitivity, failover configuration, SLA targets.

## T-Shirt Sizing

| Size | Use Case |
|------|----------|
| S | Dev/test, minimal resources |
| M | Standard workloads, moderate traffic |
| L | High-traffic, production workloads |
| XL | Enterprise-scale, high-performance |

Each pattern defines size-specific configurations per environment.

## Design Principles

- **Azure Well-Architected Framework** alignment across all infrastructure
- **Zero Trust networking** — no implicit trust, verify everything
- **No portal click-ops** — all changes flow through code, PRs, and automation
- **HA/DR as foundational** — not an afterthought, tier-driven from day one
- **Cost accountability** via consistent tagging strategy
- **Multi-business-unit isolation** in all designs
- **Reusability and consistency** across business units

## Compliance and Security

- **Azure Policy** enforces guardrails across all subscriptions
- **Wiz** provides CSPM and vulnerability scanning
- **AI-assisted tests** in every Terraform module
- **Audit evidence** generated automatically in deployment pipelines
- **Policy-as-code** checks within every module

## Repository Strategy

Each Terraform module and pattern lives in its own dedicated repository for independent versioning and reusability. This repo (`infrastructure-automation`) serves as the orchestration hub containing:

- MCP server
- CI/CD workflow templates
- Pattern definitions (YAML)
- Module/pattern templates and reference implementations

Individual module/pattern repos follow the naming convention:
- Modules: `terraform-azurerm-<resource>` (e.g., `terraform-azurerm-key-vault`)
- Patterns: `terraform-pattern-<name>` (e.g., `terraform-pattern-web-backend`)

**Important:** Pattern names use underscores (`web_backend`) but repo names use hyphens (`terraform-pattern-web-backend`). The workflows convert underscores to hyphens via `tr '_' '-'`.

### Current Pattern Repo Versions

| Repo | Tag | Notes |
|------|-----|-------|
| `terraform-pattern-web-backend` | v1.1.3 | 5-env validation |
| `terraform-azurerm-postgresql` | v1.1.1 | 5-env validation |
| `terraform-azurerm-key-vault` | v1.0.1 | 5-env validation |
| `terraform-azurerm-container-app` | v1.0.1 | 5-env validation |
| `terraform-azurerm-container-registry` | v1.0.1 | 5-env validation |
| `terraform-azurerm-naming` | v1.0.1 | 5-env abbreviations |
| `terraform-azurerm-resource-group` | v1.0.0 | |
| `terraform-azurerm-security-groups` | v1.0.0 | |
| `terraform-azurerm-rbac-assignments` | v1.0.0 | |

## Common Commands

### Terraform
```bash
# Validate a module
cd terraform/modules/key_vault && terraform init -backend=false && terraform validate

# Validate a pattern
cd terraform/patterns/key_vault && terraform init -backend=false && terraform validate
```

### MCP Server
```bash
# Install dependencies
cd mcp-server && pip install -e .

# Run locally (stdio mode for Claude Code)
cd mcp-server && MCP_TRANSPORT=stdio python -m src.server

# Run locally (HTTP mode)
cd mcp-server && python -m src.server
```

### Pattern Resolution (reference script)
```bash
python3 scripts/resolve-pattern.py --list-patterns
```

## Directory Structure

```
.github/workflows/
  terraform-test.yaml          # Validate modules/patterns on PR
  prototype-provision.yaml     # workflow_dispatch triggered by MCP server
  deploy-mcp-server.yaml       # Build and deploy MCP server container
  validate-module-sync.yaml    # Ensure config/ and terraform/ are in sync

terraform/
  modules/                     # Reference module implementations (split into separate repos)
    resource_group/
    key_vault/
    postgresql/
    container_app/
    naming/                     # Cross-cutting: naming conventions
    security_groups/            # Cross-cutting: Entra ID groups
    rbac_assignments/           # Cross-cutting: Azure RBAC
  patterns/                     # Reference pattern implementations (split into separate repos)
    key_vault/
    postgresql/
    container_app/
    web_backend/

config/patterns/                # Pattern definitions (YAML, source of truth)
  key_vault.yaml
  postgresql.yaml
  container_app.yaml
  container_registry.yaml
  web_backend.yaml

mcp-server/                     # Python MCP server (FastMCP)
  src/
    server.py                   # FastMCP entry point with all tools
    auth/
      __init__.py
      provider.py               # EntraOAuthProvider (Entra ID OAuth proxy)
    tools/                      # Tool implementations
      patterns.py               # list_patterns, get_pattern_details
      provision.py              # provision, destroy (prototype only)
      tfvars.py                 # push_tfvars (non-prototype envs)
      status.py                 # check_status, list_deployments
      _push.py                  # Shared helper: validate, resolve, push tfvars
    patterns/
      loader.py                 # Load config/patterns/*.yaml
      resolver.py               # Resolve config to tfvars
    github/
      client.py                 # GitHub API (trigger workflows, push files)
  pyproject.toml
  Dockerfile

app-infrastructure/             # Reference for the GitOps repo
  .github/workflows/
    terraform-apply.yaml        # Apply on push to appid/appname/environment/ folders
    promote.yaml                # PR-based environment promotion

scripts/resolve-pattern.py      # Reference pattern resolver (ported to MCP server)
```

## Available Patterns

| Pattern | Category | Description |
|---------|----------|-------------|
| `key_vault` | single | Key Vault with security groups, RBAC |
| `postgresql` | single | PostgreSQL with Key Vault for secrets |
| `container_app` | single | Container App with environment |
| `container_registry` | single | Container Registry with RBAC |
| `web_backend` | composite | Container App + PostgreSQL + Key Vault + ACR |

## Environments

| Environment | Purpose | Default Size | Azure Credentials |
|-------------|---------|-------------|-------------------|
| `prototype` | Developer self-service sandbox | small | `AZURE_CLIENT_ID_prototype` |
| `dev` | Development integration | small | `AZURE_CLIENT_ID_dev` |
| `tst` | Testing/QA | small | `AZURE_CLIENT_ID_tst` |
| `stg` | Staging/pre-prod | medium | `AZURE_CLIENT_ID_stg` |
| `prd` | Production | medium | `AZURE_CLIENT_ID_prd` |

## MCP Server Tools

| Tool | Description |
|------|-------------|
| `list_patterns` | List available patterns with filtering |
| `get_pattern_details` | Sizing, config options for a pattern |
| `validate_config` | Validate config before provisioning |
| `provision` | Prototype only: push tfvars to app-infrastructure, triggers terraform apply |
| `destroy` | Prototype only: trigger workflow_dispatch to run terraform destroy |
| `push_tfvars` | Non-prototype envs (DevOps): push tfvars to app-infrastructure repo |
| `check_status` | Check workflow run status |
| `list_deployments` | List active deployments |

## Module Development Standards

When developing Terraform modules:

- Self-contained, independently versionable, support t-shirt sizing via variables
- All modules produce outputs for downstream consumers and MCP server
- Account for all four application tiers with tier-appropriate defaults
- Never assume portal access or manual steps — everything automated and reproducible
- Include policy-as-code checks and AI-assisted testing
- Follow Azure naming conventions and tagging standards
- Consider multi-business-unit isolation requirements
- Support S, M, L, XL sizing through variable-driven configuration

## Adding New Patterns

1. Create `config/patterns/<name>.yaml` (source of truth)
2. Create module repo `terraform-azurerm-<resource>` with `main.tf`, `variables.tf`, `outputs.tf`
3. Create pattern repo `terraform-pattern-<name>` with `main.tf`, `variables.tf`, `outputs.tf`, `VERSION`
4. MCP server auto-discovers patterns from `config/patterns/`
5. Include tier-appropriate defaults for redundancy, backup, and recovery
6. Add the new repo to the GitHub App installation (Settings > GitHub Apps > Infrastructure Automation)
7. Add the repo name to the `repositories:` list in both `prototype-provision.yaml` and `terraform-apply.yaml` App token steps
8. Add the pattern name to the `options:` list in `prototype-provision.yaml` workflow_dispatch inputs

## Provisioning Workflow Architecture

The provisioning workflows (`prototype-provision.yaml` and `terraform-apply.yaml`) check out pattern repos at a pinned tag and run Terraform:

### Key Workflow Mechanics

- **Pattern repo resolution:** Single-resource patterns use `terraform-azurerm-{name}//pattern` (TF_DIR=`pattern`). Composite patterns use `terraform-pattern-{name}` (TF_DIR=`.`).
- **Git credentials for private modules:** Workflows configure `git config --global url."https://x-access-token:${APP_TOKEN}@github.com/".insteadOf "https://github.com/"` so `terraform init` can clone private module sources.
- **GitHub App token scoping:** The App token must list ALL repos that Terraform might reference — the pattern repo plus every module repo it sources.
- **State key format:** `{app_id}/{business_unit}/{environment}/{project}/{pattern}-{name}/terraform.tfstate`
- **Pinned tag:** Both workflows reference a specific tag (currently `v1.1.3`). Bump the `ref:` in both workflows when releasing new pattern versions.

## Known Issues and Fixes

### Azure ARM Eventual Consistency
Azure resources may return 404 immediately after creation when used as RBAC scopes. All patterns with RBAC assignments must include a `time_sleep` resource (30s) between resource creation and RBAC assignments.

### PostgreSQL Availability Zone Drift
Azure auto-assigns an availability zone to PostgreSQL Flexible Server. On re-apply, Terraform sees `null` → assigned zone as a change, which fails. The `terraform-azurerm-postgresql` module includes `lifecycle { ignore_changes = [zone] }` to prevent this.

### Variable Defaults for Optional Tags
Enterprise tagging variables (`application_id`, `application_name`, `tier`, `cost_center`) must have defaults in pattern `variables.tf` files. The MCP server may not always include them in tfvars, and missing defaults cause Terraform to prompt interactively (hanging the CI job).

## Authentication

The MCP server is secured with Entra ID OAuth when deployed remotely. Auth is **conditionally enabled** — only when `AZURE_TENANT_ID`, `MCP_ENTRA_CLIENT_ID`, and `MCP_SERVER_URL` env vars are set. Local stdio mode has no auth.

**Flow:** Claude Code -> MCP `/authorize` -> Entra ID login -> `/auth/callback` -> Claude Code

- **App Registration:** `Infrastructure MCP Server` (Web platform, confidential client + PKCE)
- **Client ID:** `ff976387-aa84-43d3-a075-c8e292bb715c`
- MCP server issues its own JWT access tokens (RSA-signed, 1hr lifetime, in-memory)
- Dynamic Client Registration enabled for Claude Code auto-registration
- Container restart clears all tokens (users re-auth via browser)

## Required Secrets

**Azure:** `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`, `AZURE_CLIENT_ID_prototype/dev/tst/stg/prd`
**Terraform State:** `TF_STATE_STORAGE_ACCOUNT`, `TF_STATE_CONTAINER`, `TF_STATE_RESOURCE_GROUP`
**GitHub App:** `INFRA_APP_ID`, `INFRA_APP_PRIVATE_KEY`
**Entra ID Auth:** `MCP_ENTRA_CLIENT_SECRET`

## Required Variables

**Entra ID Auth:** `MCP_ENTRA_CLIENT_ID`

## Tagging Strategy

All resources must include these tags:
- `application_id` — unique app identifier
- `application_name` — human-readable app name
- `environment` — prototype/dev/tst/stg/prd
- `business_unit` — owning business unit
- `tier` — application tier (1-4)
- `cost_center` — billing cost center
- `managed_by` — terraform
