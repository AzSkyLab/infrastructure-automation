# MCP Server Internals

Technical reference for the infrastructure self-service MCP server.

## Component Overview

```
mcp-server/src/
  server.py              FastMCP entry point, tool registration, auth
  patterns/
    loader.py             Load pattern YAMLs from config/patterns/
    resolver.py           Validate configs, resolve to tfvars
  tools/
    patterns.py           list_patterns, get_pattern_details
    provision.py          provision (prototype), destroy (prototype)
    tfvars.py             push_tfvars (non-prototype environments)
    _push.py              Shared: validate → resolve → push to app-infrastructure
    status.py             check_status, list_deployments
  github/
    client.py             GitHub App auth, workflow dispatch, Git tree API
  auth/
    provider.py           Entra ID OAuth (remote deployment only)
```

## Request Flow

### Provision (Prototype)

```
Claude Code
  → MCP protocol
    → server.py: provision()
      → provision.py: provision()
        → _push.py: push_pattern(commit_prefix="prototype")
          → resolver.py: validate_config() → errors or OK
          → resolver.py: resolve() → tfvars dict
          → resolver.py: compute_state_key() → state path
          → client.py: push_tfvars_to_main()
            → GitHub Git API: create blobs, tree, commit, update ref
              → app-infrastructure main updated
                → terraform-apply.yaml triggered (folder-based GitOps)
```

### Destroy (Prototype)

```
Claude Code
  → server.py: destroy()
    → provision.py: destroy()
      → resolver.py: validate_config() + resolve()
      → base64-encode tfvars
      → client.py: trigger_workflow("prototype-provision.yaml", action="destroy")
        → GitHub Actions runs terraform destroy
```

Destroy uses workflow_dispatch because it needs `terraform destroy` — you can't destroy by deleting files from Git.

### Push Tfvars (Non-Prototype)

```
Claude Code
  → server.py: push_tfvars()
    → tfvars.py: push_tfvars()
      → rejects environment=="prototype"
      → _push.py: push_pattern(commit_prefix="deploy")
        → same flow as provision
```

### Pattern Discovery

```
Claude Code
  → server.py: list_patterns() / get_pattern_details()
    → patterns.py: loads from loader.py cache
      → loader.py: reads config/patterns/*.yaml (cached after first load)
```

### Validation

```
Claude Code
  → server.py: validate_config()
    → resolver.py: validate_config()
    → if valid: resolver.py: resolve()
    → returns: errors/warnings, resolved tfvars
```

## Pattern Loader (`loader.py`)

Loads all `*.yaml` files from `config/patterns/` into a dict keyed by pattern name. Uses a module-level cache — patterns are loaded once at startup and never reloaded.

**Pattern YAML structure:**
```yaml
name: key_vault
description: |
  Azure Key Vault with RBAC authorization...
category: single-resource        # or "composite"
components:
  - resource-group
  - key-vault
  - security-groups
  - rbac-assignments
use_cases:
  - Application secret management
sizing:
  small:
    prototype: { sku_name: "standard" }
    dev: { sku_name: "standard" }
    tst: { sku_name: "standard" }
    stg: { sku_name: "standard" }
    prd: { sku_name: "standard" }
  medium:
    # ...per-environment sizing for each t-shirt size
config:
  required:
    - name
  optional:
    - sku_name:
        type: string
        default: "standard"
        description: Key Vault SKU
tier_defaults:
  1: { sku_name: "premium", purge_protection_enabled: true }
  # ...per-tier overrides
```

**Location:** Resolved from `PATTERNS_DIR` env var, or defaults to `config/patterns/` relative to repo root.

## Pattern Resolver (`resolver.py`)

Converts a user's pattern request into a complete `terraform.tfvars.json`.

### Constants

| Constant | Value |
|----------|-------|
| `VALID_ENVIRONMENTS` | `("prototype", "dev", "tst", "stg", "prd")` |
| `VALID_SIZES` | `("small", "medium", "large", "xlarge")` |
| `VALID_TIERS` | `(1, 2, 3, 4)` |
| `DEFAULT_SIZES` | prototype→small, dev→small, tst→small, stg→medium, prd→medium |

### `validate_config(pattern_name, environment, config, metadata)`

Checks:
- Pattern exists in loaded patterns
- Environment is in `VALID_ENVIRONMENTS`
- Size (if provided) is in `VALID_SIZES`
- Required config fields from pattern YAML are present
- Metadata has: project, environment, business_unit, owners, application_id, application_name
- Tier is 1-4

Returns `{"valid": bool, "errors": [...], "warnings": [...]}`.

### `resolve(pattern_name, environment, config, metadata)`

Steps:
1. Validates config (raises ValueError if invalid)
2. Determines t-shirt size: explicit `config["size"]` or `DEFAULT_SIZES[environment]`
3. Looks up sizing values from `pattern["sizing"][size][environment]`
4. Builds base tfvars with standard fields:
   - project, environment, business_unit, owners, location, name
   - application_id, application_name, tier, cost_center
5. Merges sizing values (e.g., sku_name, storage_mb, cpu, memory)
6. Applies optional config with defaults from pattern YAML

Returns a dict ready for `terraform.tfvars.json`.

### `compute_state_key(pattern_name, environment, config, metadata)`

Format: `{app_id}/{business_unit}/{environment}/{project}/{pattern}-{name}/terraform.tfstate`

All path components are validated against `^[a-zA-Z0-9_-]+$`.

## Shared Push Helper (`_push.py`)

`push_pattern()` is the single function that both `provision.py` and `tfvars.py` call to push tfvars to the app-infrastructure repo.

Steps:
1. Validate and resolve via `PatternResolver`
2. Generate `terraform.tfvars.json` (indented JSON)
3. Generate `backend.hcl` containing only the state key (storage account details are injected by CI via `-backend-config` flags)
4. Compute folder path: `{application_id}/{application_name}/{environment}`
5. Call `GitHubClient.push_tfvars_to_main()` with commit message

The `commit_prefix` parameter distinguishes prototype ("prototype: ...") from production ("deploy: ...") commits.

## GitHub Client (`client.py`)

Uses GitHub App authentication (JWT → installation access token).

### Authentication

1. `_generate_jwt()` — Creates a 10-minute JWT signed with the App's private key
2. `_get_installation_token()` — Exchanges JWT for a ~58-minute installation token (cached)
3. All API calls use `token {installation_token}` in the Authorization header

### `push_tfvars_to_main()`

Creates files on the `main` branch of `app-infrastructure` using the Git tree API:

1. Get current main HEAD SHA
2. Create blobs for `terraform.tfvars.json` and `backend.hcl`
3. Create a new tree with both files at `{folder_path}/{pattern_name}/`
4. Create a commit pointing to the new tree
5. Update `refs/heads/main` to the new commit SHA

Retries up to 3 times with exponential backoff on 409 conflicts (concurrent pushes).

### `trigger_workflow()`

Posts to `POST /repos/{repo}/actions/workflows/{file}/dispatches` with inputs. Used only by `destroy()`.

### `get_workflow_runs()` / `get_workflow_run()`

Queries workflow run status. `get_workflow_runs()` accepts a `repo` parameter — `"app_infra"` queries the app-infrastructure repo, otherwise queries the infrastructure-automation repo.

## Environment Variables

### Required for Operation

| Variable | Purpose |
|----------|---------|
| `INFRA_APP_ID` | GitHub App ID |
| `INFRA_APP_PRIVATE_KEY` | GitHub App private key (PEM format) |
| `INFRA_REPO` | infrastructure-automation repo (`owner/repo`) |
| `APP_INFRA_REPO` | app-infrastructure repo (`owner/repo`) |

### Optional

| Variable | Default | Purpose |
|----------|---------|---------|
| `MCP_TRANSPORT` | `streamable-http` | Transport mode (`stdio` for local dev) |
| `MCP_HOST` | `127.0.0.1` | Server bind address |
| `MCP_PORT` | `8000` | Server listen port |
| `LOG_LEVEL` | `INFO` | Logging level |
| `PATTERNS_DIR` | `config/patterns/` | Override pattern YAML location |

### Entra ID Auth (Remote Deployment Only)

| Variable | Purpose |
|----------|---------|
| `AZURE_TENANT_ID` | Azure tenant ID |
| `MCP_ENTRA_CLIENT_ID` | Entra ID app registration client ID |
| `MCP_ENTRA_CLIENT_SECRET` | Entra ID client secret |
| `MCP_SERVER_URL` | Public URL of the MCP server |

Auth is conditionally enabled only when all three of `AZURE_TENANT_ID`, `MCP_ENTRA_CLIENT_ID`, and `MCP_SERVER_URL` are set. Local stdio mode has no auth.

## Tool Reference

| Tool | Parameters | Description |
|------|-----------|-------------|
| `list_patterns` | `category?` | List patterns, optionally filtered by "single-resource" or "composite" |
| `get_pattern_details` | `pattern_name` | Full sizing and config for a pattern |
| `validate_config` | `pattern_name, environment, name, project, application_id, application_name, ...` | Validate + preview resolved tfvars |
| `provision` | `pattern_name, name, project, application_id, application_name, ...` | Push to prototype env in app-infrastructure |
| `destroy` | `pattern_name, name, project, application_id, application_name, ...` | Trigger prototype destroy workflow |
| `push_tfvars` | `pattern_name, environment, name, project, application_id, application_name, ...` | Push to non-prototype env in app-infrastructure |
| `check_status` | `run_id` | Get status of a workflow run |
| `list_deployments` | `status?, limit?` | List recent terraform-apply runs |
