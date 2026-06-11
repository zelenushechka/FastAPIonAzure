# FastAPI on Azure — Private Deployment

Terraform code that deploys a containerized FastAPI application to a private
Azure spoke VNet, reachable only from the corporate network through the hub's
VPN gateway. All service-to-service traffic stays on the Azure backbone via
Private Endpoints. Secrets and registry pulls are authenticated through a
user-assigned managed identity with least-privileged RBAC.

## Architecture

```
On-prem ─── VPN ───► Hub VNet ───► Spoke VNet (vnet-usecase-private-01, 10.0.0.0/24)
                                    │
                                    ├── snet-containerapps (10.0.0.0/26) ─── Container App (internal LB)
                                    │                                            │
                                    │                                            └─ UAI ─┐
                                    └── snet-private-endpoints (10.0.0.64/27)            │
                                          │                                              │
                                          ├── PE → Storage Account (blob, public OFF) ◄──┤
                                          ├── PE → Key Vault (vault, public OFF)      ◄──┤
                                          └── PE → ACR (registry, public OFF)         ◄──┘
                                                  (DNS via hub privatelink zones)
```

| Component | Choice | Why |
|---|---|---|
| Compute | **Azure Container Apps** (workload profile, internal LB) | Serverless containers with native VNet injection and MI support; no AKS overhead. Internal LB means the app is unreachable from the public internet by design. |
| Identity | **User-assigned managed identity** | Created before the app so RBAC roles can be granted first — avoids the chicken-and-egg of system-assigned. Same identity used for ACR pull, Key Vault read, and Storage data access. |
| Secrets | **Key Vault** (RBAC, public access disabled, private endpoint) | Container App references secrets via `key_vault_secret_id` resolved at runtime by the MI. Secret values never enter Terraform state. |
| Media storage | **Storage Account** (public access disabled, `shared_access_key_enabled = false`) | Account keys disabled — Entra ID auth only. Reached exclusively via Private Endpoint. |
| Image registry | **ACR Premium** (admin disabled, private endpoint) | Premium SKU is required for Private Endpoints; admin user is off, so the MI is the only way to pull. |
| Observability | **Log Analytics workspace** | Default ACA log sink. |
| DNS | **Central private DNS zones in hub** | Spoke VNet linked to hub zones; A records created by hub automation. |

## Security & Identity Flow

1. GitHub Actions authenticates to Azure via **OIDC** federated credentials (no client secrets in CI).
2. Terraform creates a **user-assigned managed identity** for the FastAPI app.
3. The MI receives only three role assignments:
   - `Storage Blob Data Contributor` scoped to the **single** storage account
   - `Key Vault Secrets User` scoped to the **single** vault
   - `AcrPull` scoped to the **single** registry
4. The Container App pulls its image from ACR and resolves Key Vault secret references using that MI.
5. At runtime the application uses `DefaultAzureCredential` (Python SDK) which picks up the MI to access blob storage and any further secrets.

## Repository Layout

```
.
├── modules/
│   ├── networking/          # RG, VNet, subnets, NSGs, peering, DNS links
│   ├── storage/             # Storage account + PE + RBAC
│   ├── key_vault/           # Key Vault + PE + RBAC
│   ├── container_registry/  # ACR + PE + RBAC
│   └── container_app/       # Log Analytics + ACA env + Container App
├── envs/
│   └── dev/                 # Composition root for the dev environment
│       ├── backend.tf
│       ├── main.tf
│       ├── outputs.tf
│       ├── providers.tf
│       ├── terraform.tfvars
│       └── variables.tf
├── app/                     # Reference FastAPI app + Dockerfile
└── .github/workflows/
    ├── terraform-dev.yml    # PR plan → main apply (with manual approval)
    └── terraform-drift.yml  # Scheduled drift detection
```

## Terraform State

- **Remote backend**: Azure Blob Storage in a dedicated `tfstate-rg` resource group, isolated from the application spoke and managed by a separate "platform foundation" Terraform stack.
- **Locking**: native Azure blob lease locks (no Cosmos DB / DynamoDB needed).
- **Authentication**: GitHub Actions OIDC (`ARM_USE_OIDC=true`, `use_azuread_auth=true`) — no storage account keys, no client secrets.
- **State layout**: one state file per environment under `envs/<env>/terraform.tfstate`. For very large estates the next step is to split per layer (networking / platform / app) so the blast radius of a single state corruption is smaller.

## Variables Strategy

Three tiers, mapped to their lifecycle:

| Tier | Storage | Example | Why |
|---|---|---|---|
| **Non-secret config** | `terraform.tfvars` (committed) | regions, CIDRs, tag values, hub IDs | Reviewable in Git, identical for everyone. |
| **CI-only identifiers** | GitHub Actions `secrets` injected as `TF_VAR_*` or `ARM_*` env vars | subscription ID, tenant ID, client ID | Not secret in the cryptographic sense, but environment-specific — kept out of the repo. |
| **Runtime app secrets** | Azure Key Vault | API keys, connection strings | Never touch Terraform state. The app reads them at startup via the MI. |

## CI/CD

`terraform-dev.yml`:

1. **Validate** — `fmt`, `init -backend=false`, `validate`, `tflint`, `tfsec` (HIGH/CRITICAL fail).
2. **Plan** — runs on every PR and every push to `main`. The plan output is commented on the PR and uploaded as a workflow artifact.
3. **Apply** — runs only on `main` and only if the plan reported changes (exit code `2`). The job uses a GitHub Environment with **required reviewers** for the gate.

`terraform-drift.yml`:

- Runs every 6 hours on `main`. Any non-empty refresh-plan opens a GitHub Issue.

## Bootstrapping

The backend storage account and the GitHub Actions OIDC App Registration are
not in this repo — they are provisioned by a separate **platform-foundation**
stack so destroying the application stack can never break its own state
backend. Required Azure resources before first run:

1. Resource group `tfstate-rg`
2. Storage account with versioning + soft delete (referenced in `backend.tf`)
3. Container `tfstate`
4. Entra ID App Registration with a Federated Credential trusting
   `repo:<org>/FastAPIonAzure:ref:refs/heads/main` and the relevant PR refs
5. Role assignments on the target subscription: `Contributor` + `User Access Administrator` (the latter is needed because the stack creates RBAC role assignments).
6. GitHub Actions secrets: `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`.

## Local Use

```bash
cd envs/dev
az login
terraform init
terraform plan
terraform apply
```

Locally, the AzureRM provider falls back to your `az login` credentials.
