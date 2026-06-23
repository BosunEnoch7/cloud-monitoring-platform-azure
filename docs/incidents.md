# Incident and blocker log

This document records meaningful blockers, failed deployments, operational incidents, and recovery actions encountered while building the platform.

The goal is not to hide problems. A production-style project should show how issues were detected, investigated, contained, resolved, and converted into better engineering decisions.

## How incidents are recorded

Each entry should include:

- Date encountered
- Area affected
- Symptom
- Impact
- Root cause or likely cause
- Investigation steps
- Resolution or current status
- Prevention or follow-up action
- Portfolio lesson

## Incident 001: East US VM capacity allocation failures

| Field | Details |
|---|---|
| Date encountered | During Azure Terraform deployment phase |
| Area affected | Azure compute deployment |
| Severity | Medium |
| Status | Mitigation approved: move workload deployment from East US to East US 2 |
| Impact | Terraform successfully created supporting infrastructure, but the Ubuntu monitoring VM could not be allocated. Monitoring services cannot be installed until the VM exists. |

### Symptom

GitHub Actions `terraform apply` created or reconciled the resource group, networking, network security group, public IP, and NIC, but Azure returned `SkuNotAvailable` / capacity allocation errors when creating the Linux VM in `eastus`.

### What we tried

The project kept the user requirement to deploy in East US and attempted several safe Terraform changes:

- Started with `Standard_B2s`
- Tried `Standard_B2als_v2`
- Moved to general-purpose `Standard_D2as_v5`
- Added explicit zonal placement in East US
- Retried Zone 1, Zone 2, and Zone 3
- Switched to another general-purpose family, `Standard_D2s_v3`

### Investigation

The failure was not caused by invalid Terraform syntax or a broken GitHub Actions workflow. The earlier applies proved that:

- Azure authentication through GitHub OIDC worked.
- Remote state locking worked.
- Terraform could create Azure resources.
- The resource group and network layer were valid.
- The failure occurred specifically at VM allocation time.

The Azure error indicated live regional or zonal capacity was unavailable for the requested VM SKU.

### Treatment

The project avoided manual portal fixes and preserved Terraform as the source of truth.

Actions taken:

- Allowed Terraform to keep successfully created resources in remote state.
- Avoided deleting or editing state manually.
- Updated VM SKU and zone through code.
- Added lifecycle protection for public IP replacement when moving from non-zonal to zonal design.
- Stopped blind retrying after multiple East US SKU and zone failures.

### Decision

The user approved moving forward in another region rather than continuing to retry East US capacity.

The selected fallback is:

```text
eastus2
```

This keeps the workload geographically close to the original target while avoiding the exhausted East US allocation pool.

### Recovery action

Terraform was updated so the development workload defaults to `eastus2`. Because Azure resource groups cannot be moved between regions by changing metadata, Terraform may replace the partially-created East US workload resources during the next approved apply. This is acceptable for this project stage because the monitoring VM was never successfully created.

The first region-fallback apply failed before creating the new resource group because the old resource group name still existed in Azure. The recovery was to make the workload resource group region-specific, for example:

```text
cloud-monitoring-dev-eastus2-rg
```

This avoids name collision during region fallback and makes the deployment location visible in Azure.

The next apply successfully created the East US 2 resource group, virtual network, subnet, NSG, public IP, and NIC. VM creation then failed because `Standard_D2s_v3` was unavailable in East US 2 Zone 3. The next controlled retry moved the default availability zone from Zone 3 to Zone 1 while keeping the same region and SKU.

East US 2 Zone 1 also rejected `Standard_D2s_v3`. After testing multiple zones for the same SKU family, the next mitigation changed the VM size to `Standard_D2as_v5`, preserving the 2-vCPU/8-GiB sizing goal while moving to a different compute family.

### Prevention and follow-up

Future improvements:

- Add a preflight SKU/capacity check script before apply.
- Document region fallback criteria.
- Consider a separate `dev` environment in a lower-cost, higher-capacity region.
- After successful deployment, scope the apply identity down from subscription-level bootstrap permissions to the workload resource group.

### Portfolio lesson

Cloud capacity is a real operational constraint. Infrastructure as Code does not eliminate provider-side capacity failures; it makes recovery safer by keeping the desired state declarative, reviewable, and repeatable.

## Incident 002: Public IP zone conversion replacement

| Field | Details |
|---|---|
| Date encountered | During East US zonal retry work |
| Area affected | Azure networking |
| Severity | Low |
| Status | Resolved in Terraform design |
| Impact | Existing public IP configuration could not be converted in place while attached to the NIC. |

### Symptom

When changing from a non-zonal public IP to a zonal public IP, Azure required replacement. A public IP cannot be deleted while still attached to a network interface.

### Investigation

The dependency chain was:

```text
Public IP -> NIC IP configuration -> Linux VM
```

Terraform needed to create a replacement address, update the NIC reference, then remove the old address.

### Treatment

The compute module was adjusted to:

- Give zonal public IPs a distinct name.
- Use `create_before_destroy` on the public IP.
- Allow Terraform to update dependencies in the correct order.

### Portfolio lesson

Infrastructure resources often have replacement constraints. Production Terraform should model these safely instead of relying on manual portal cleanup.

## Incident 003: Bootstrap permission exception

| Field | Details |
|---|---|
| Date encountered | During GitHub Actions and Azure OIDC setup |
| Area affected | Azure IAM |
| Severity | Low |
| Status | Accepted temporary exception |
| Impact | The apply identity needed broader permissions at first because the workload resource group did not exist yet. |

### Symptom

Terraform was responsible for creating the project resource group, but Azure role assignments scoped to that resource group cannot be created before the resource group exists.

### Treatment

The apply identity temporarily received subscription-level `Contributor` for bootstrap. This was documented as an exception, not the intended steady state.

Follow-up after the first successful deployment:

1. Assign `Contributor` to the apply identity at `cloud-monitoring-dev-rg`.
2. Verify GitHub Actions plan/apply still works.
3. Remove the subscription-scoped `Contributor` assignment.

### Portfolio lesson

Least privilege sometimes requires a bootstrap phase. The professional pattern is to document the exception, reduce scope after creation, and keep the steady-state permission model tight.

## Incident 004: Repository and OIDC trust name mismatch risk

| Field | Details |
|---|---|
| Date encountered | During GitHub Actions setup |
| Area affected | GitHub repository identity and Azure federated credentials |
| Severity | Low |
| Status | Resolved |
| Impact | Azure OIDC trust must match the exact GitHub repository name and branch/environment subject. |

### Symptom

The project name is `cloud-monitoring-platform`, while the GitHub repository is intentionally named `cloud-monitoring-platform-azure`.

### Treatment

The repository name was restored to the user's intended name, and Azure federated credentials were aligned with:

```text
repo:BosunEnoch7/cloud-monitoring-platform-azure
```

### Portfolio lesson

OIDC federation is secure because it is exact. Repo renames, branch changes, and environment names can break deployment authentication unless trust subjects are updated deliberately.

## End-of-project review checklist

Before final portfolio completion, review this log and confirm:

- Every significant blocker is listed.
- Each incident has a clear treatment and outcome.
- Screenshots or workflow logs are captured where useful.
- Preventive improvements are reflected in `docs/future-improvements.md`.
- Troubleshooting steps are reflected in `docs/troubleshooting.md`.
- Lessons are summarized in `docs/lessons-learned.md`.

## Future incident entry template

```markdown
## Incident NNN: Short title

| Field | Details |
|---|---|
| Date encountered | YYYY-MM-DD |
| Area affected | Terraform / Azure / Linux / Prometheus / Grafana / Alertmanager / CI/CD |
| Severity | Low / Medium / High |
| Status | Open / Mitigated / Resolved |
| Impact | What was blocked or degraded |

### Symptom

What we observed.

### Investigation

Commands, logs, workflow output, or Azure/GitHub evidence checked.

### Treatment

What was changed, retried, rolled back, or documented.

### Prevention and follow-up

How this should be avoided or detected faster next time.

### Portfolio lesson

What this demonstrates about real-world operations.
```
