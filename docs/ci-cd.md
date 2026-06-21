# Terraform CI/CD design

## Principle

GitHub Actions will be the authoritative path for Terraform plans and deployments. Local Terraform remains useful for fast formatting and static validation, but infrastructure changes should not be applied from an engineer's workstation.

Terraform code does not inherently run “in GitHub Actions.” Terraform runs wherever its CLI is invoked. Consistency comes from central state, pinned dependencies, controlled identity, and a documented workflow.

## Intended workflow

### Developer workstation

Developers may run:

```text
terraform fmt -recursive
terraform validate
```

Local `apply` is prohibited by project convention.

### Pull requests

GitHub Actions will run:

1. Terraform formatting check
2. Initialization against remote state
3. Configuration validation
4. Security and lint checks
5. Terraform plan
6. Plan publication for review

Pull-request workflows receive read-only or planning permissions and cannot deploy.

### Deployment

Apply will run after review through a protected GitHub environment. The environment should require manual approval and restrict which branch may deploy.

The apply job must use the reviewed commit and regenerate or securely consume its plan. It must not blindly deploy code from an untrusted pull request.

## Azure authentication

GitHub Actions will use OpenID Connect workload identity federation:

```text
GitHub Actions OIDC token
        |
        v
Microsoft Entra application or managed identity
        |
        v
Scoped Azure role assignment
```

This avoids storing a long-lived Azure client secret in GitHub. The deployment identity will receive only the permissions needed for this project scope.

## Remote-state prerequisite

Ephemeral GitHub runners cannot safely use local state. Before CI planning or deployment, state must move to a protected Azure Storage backend with locking, recovery controls, and Microsoft Entra authorization.

The dependency order is therefore:

1. Define workload infrastructure locally.
2. Bootstrap the remote-state storage separately.
3. Configure Azure federated identity and scoped authorization.
4. Add pull-request validation and plan workflows.
5. Add a protected apply workflow.
6. Perform the first workload deployment through GitHub Actions.

## Phase 6 bootstrap procedure

### Required operator permissions

Run the bootstrap as an Azure identity permitted to:

- Create resource groups and storage accounts
- Register Azure resource providers
- Create Microsoft Entra applications and service principals
- Create role assignments at subscription scope

In many subscriptions this means Azure `Owner` plus permission to register Entra applications. If application registration is restricted, an Entra administrator must perform or approve that portion.

Authenticate first:

```powershell
az login
az account set --subscription <subscription-id>
```

Choose a globally unique storage account name containing only 3-24 lowercase letters and numbers, then run:

```powershell
.\scripts\bootstrap-azure.ps1 `
  -SubscriptionId '<subscription-id>' `
  -StateStorageAccount '<globally-unique-name>'
```

The script is idempotent: it checks applications, federated credentials, and role assignments before creating them.

### GitHub repository variables

Record the values printed by the script as GitHub repository variables:

| Variable | Purpose |
|---|---|
| `AZURE_TENANT_ID` | Microsoft Entra tenant |
| `AZURE_SUBSCRIPTION_ID` | Target Azure subscription |
| `AZURE_PLAN_CLIENT_ID` | Read-only plan application |
| `AZURE_APPLY_CLIENT_ID` | Deployment application |
| `TF_STATE_RESOURCE_GROUP` | State resource group |
| `TF_STATE_STORAGE_ACCOUNT` | Globally unique state account |
| `TF_STATE_CONTAINER` | State blob container |
| `TF_STATE_KEY` | Environment state path |
| `TF_OWNER` | Value for mandatory owner tags |
| `TF_ADMIN_SOURCE_CIDRS_JSON` | JSON list such as `["203.0.113.10/32"]` using your real public IP |
| `TF_SSH_PUBLIC_KEY` | OpenSSH public key; never the private key |

Identifiers and the SSH public key are not authentication secrets, but repository variables still provide centralized configuration. No client secret is created or stored.

### Protected environment

Create a GitHub environment named `dev` and configure required reviewers. The apply identity trusts only OIDC tokens whose subject identifies that environment. GitHub will pause the apply job until the environment approval is granted.

### Backend activation

The committed backend remains local until bootstrap succeeds. Afterward, change `backend.tf` to an empty `azurerm` backend block and initialize it with the generated backend values. GitHub Actions supplies those values dynamically; they are not hard-coded into Terraform.

The workflow templates were activated after the backend, repository variables, OIDC trust, and protected environment were verified.

Because this is a public repository, Azure-backed plans run only when the pull-request branch belongs to the same repository. Untrusted public forks never receive the plan identity's OIDC access to remote state.

## Initial role-scope exception

The deployment identity initially receives `Contributor` at subscription scope because Terraform must create the workload resource group. Azure cannot assign a role at the scope of a resource group that does not exist yet.

After the first successful deployment, an Azure administrator should:

1. Add `Contributor` for the apply identity at `cloud-monitoring-dev-rg` scope.
2. Verify a GitHub Actions plan still succeeds.
3. Remove its subscription-scoped `Contributor` assignment.

This is a documented bootstrap exception, not the intended steady-state permission model. Destroying and later recreating the resource group will require temporarily repeating the bootstrap grant.

## Supply-chain controls

Third-party GitHub Actions are pinned to immutable commit SHAs. Version comments retain readability while preventing a mutable major-version tag from silently changing executed code. Dependabot or deliberate review should manage future SHA updates.

## Secret boundary

Subscription, tenant, and client identifiers are configuration identifiers rather than authentication secrets, but they should still be managed consistently as repository or environment variables. Credentials, private keys, SMTP passwords, and Terraform state must never be committed.
