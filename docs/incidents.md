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
| Date encountered | 2026-06-21 through 2026-06-23 |
| Area affected | Azure compute deployment |
| Severity | Medium |
| Status | Resolved |
| Impact | Terraform successfully created supporting infrastructure, but repeated Azure capacity failures delayed creation of the Ubuntu monitoring VM. |

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

East US 2 also rejected `Standard_D2as_v5`. At this point the evidence showed broad capacity pressure across the East US / East US 2 target area for the requested VM class. The next mitigation moved the workload default to `centralus`, with quota checked before the change.

Central US successfully created the resource group and network layer, but rejected `Standard_D2as_v5` at VM allocation time. The next controlled retry kept Central US and changed the VM SKU to `Standard_D2s_v3`, using a different compute family pool while preserving the 2-vCPU/8-GiB sizing target.

The controlled retry succeeded on 2026-06-23 with:

```text
Region: Central US
Availability zone: 1
VM size: Standard_D2s_v3
Resource group: cloud-monitoring-dev-centralus-rg
```

GitHub Actions run `28044710581` completed both the saved-plan and protected-apply jobs successfully. The Ubuntu VM was subsequently reached over SSH and bootstrapped.

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

1. Assign `Contributor` to the apply identity at `cloud-monitoring-dev-centralus-rg`.
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

## Incident 005: SSH blocked after administrator IP changed

| Field | Details |
|---|---|
| Date encountered | 2026-06-25 |
| Area affected | Azure networking and administrative access |
| Severity | Low |
| Status | Resolved |
| Impact | The VM was healthy, but SSH from the administrator workstation timed out. |

### Symptom

TCP connectivity to port `22` failed after deployment even though the VM and public IP had been created successfully.

### Investigation

The NSG allowed only the previously recorded administrator address, `102.91.93.8/32`. The workstation's current public address was `102.91.103.173`, so Azure correctly rejected the connection.

### Treatment

The GitHub repository variable `TF_ADMIN_SOURCE_CIDRS_JSON` was updated to the new `/32` address. The Terraform apply workflow generated a new plan, paused at the protected `dev` environment, and applied the reviewed NSG-only update after approval.

The first workflow retry failed safely at plan time because a command-line update had removed the JSON quotation marks from the variable. The value was corrected through standard input as:

```json
["102.91.103.173/32"]
```

The second plan and apply succeeded in GitHub Actions run `28167787774`. SSH then connected successfully and reported hostname `monitoring`.

### Prevention and follow-up

- Add a small validation command or script that checks the CIDR variable is valid JSON before dispatching Terraform.
- Document the administrator-IP rotation procedure in the operations guide.
- Keep SSH restricted to explicit `/32` addresses rather than opening it broadly.

### Portfolio lesson

A failed access test can prove a security control is working. The correct response is a reviewed allowlist update, not temporarily exposing SSH to the internet.

## Incident 006: Local Azure CLI verification connectivity

| Field | Details |
|---|---|
| Date encountered | 2026-06-25 |
| Area affected | Local operational verification |
| Severity | Low |
| Status | Mitigated |
| Impact | Read-only Azure CLI inventory commands could not initially verify the deployment. |

### Symptom

Azure CLI reported a DNS resolution failure for `login.microsoftonline.com`, and a later resource inventory request timed out.

### Treatment

DNS resolution was tested independently and recovered. The deployment was verified through the successful GitHub Actions jobs and Terraform outputs, followed by direct SSH and service-level checks on the VM.

### Prevention and follow-up

- Retry transient control-plane checks with bounded timeouts.
- Keep more than one verification path: CI evidence, Azure inventory, SSH, and service health.
- Do not mistake a local client connectivity failure for an Azure workload failure.

### Portfolio lesson

Operational verification should use independent signals. A single failing client or control-plane path should not determine workload health.

## Incident 007: Prometheus readiness startup race

| Field | Details |
|---|---|
| Date encountered | 2026-06-25 |
| Area affected | Prometheus installation automation |
| Severity | Low |
| Status | Resolved |
| Impact | The installer returned a failure even though Prometheus started successfully moments later. |

### Symptom

The checksum and `promtool` validation passed, but the immediate request to `127.0.0.1:9090/-/ready` received `connection refused`.

### Investigation

Systemd showed Prometheus active and enabled. The journal showed that Prometheus needed roughly one second to initialize its TSDB, load configuration, and begin listening. Both Prometheus and Node Exporter were then confirmed on loopback-only listeners.

### Treatment

The installer health check was changed from a single immediate request to a bounded retry loop with a 30-second timeout. Reruns also detect the installed pinned version and avoid downloading the 145 MB archive again.

### Portfolio lesson

Service startup and service readiness are different events. Deployment automation should tolerate normal initialization time while retaining a clear upper timeout.

## Incident 008: Validated rules not loaded into the running process

| Field | Details |
|---|---|
| Date encountered | 2026-06-25 |
| Area affected | Prometheus configuration deployment |
| Severity | Low |
| Status | Resolved |
| Impact | Alert files existed on disk and passed validation, but the running Prometheus process still had zero loaded rule groups. |

### Symptom

`promtool check config` found two rule files and five valid rules, but the Prometheus runtime rules API returned an empty group list.

### Investigation

The installer used `systemctl enable --now prometheus`. The `--now` operation starts an inactive unit, but it does not restart an already-running unit after configuration changes. Journal timestamps confirmed the process had not reloaded.

### Treatment

The installer now enables the unit and explicitly restarts Prometheus after successful validation. Runtime API verification remains a required post-deployment check.

### Portfolio lesson

Configuration validity, files on disk, and runtime state are three separate verification layers. Production changes are complete only when the running service confirms the intended configuration is active.

## Incident 009: Alert exercise interrupted by administrator IP rotation

| Field | Details |
|---|---|
| Date encountered | 2026-06-25 |
| Area affected | Live alert testing and SSH access |
| Severity | Low |
| Status | Mitigated; alert exercise scheduled for repetition |
| Impact | The Node Exporter outage was started, but the firing-state observation could not be completed over SSH. |

### Symptom

During the two-minute `NodeExporterDown` exercise, the workstation address changed from `102.91.103.173` to `102.91.78.75`. The Azure NSG correctly stopped accepting SSH from the old address.

### Treatment

Azure VM Run Command was used as an independent management path to start Node Exporter. The service reported active. The GitHub Terraform CIDR variable was then updated to the new `/32`, and protected Terraform run `28186011923` applied successfully.

### Follow-up

Repeat the live outage after Alertmanager is installed. Capture the pending, firing, notification, and resolved states as one complete incident exercise.

### Portfolio lesson

Break-glass operational access should not depend entirely on the same network path being tested. Azure Run Command provided a controlled recovery channel without widening SSH exposure.

## Incident 010: Grafana JSON CI false failure

| Field | Details |
|---|---|
| Date encountered | 2026-06-25 |
| Area affected | Observability GitHub Actions validation |
| Severity | Low |
| Status | Resolved |
| Impact | The first observability validation workflow failed even though the Grafana dashboard JSON was valid. |

### Symptom

The Grafana JSON step exited with code `123` through `xargs`.

### Investigation

The command used `jq --exit-status empty`. The `empty` filter intentionally emits no output, while `--exit-status` treats no result as a non-zero condition. `xargs` converted the child failure into exit code `123`.

### Treatment

The workflow now runs `jq empty` without `--exit-status`. Invalid JSON still causes a parser failure, while valid JSON completes successfully.

### Portfolio lesson

Validation commands must be tested for their exit semantics, not just their visible output. A CI failure can originate in the validator wrapper rather than the artifact being validated.

## Incident 011: Bootstrap IAM exception closed

| Field | Details |
|---|---|
| Date encountered | 2026-06-25 |
| Area affected | Azure IAM |
| Severity | Low |
| Status | Resolved |
| Impact | The deployment identity initially had subscription-wide Contributor so Terraform could create the workload resource group. |

### Treatment

After the workload resource group existed, the apply identity was granted `Contributor` only on:

```text
cloud-monitoring-dev-centralus-rg
```

The temporary subscription-wide `Contributor` assignment was removed. A protected Terraform apply run, `28196178635`, succeeded afterward, proving the reduced permission model still supports deployment.

The identity retains `Storage Blob Data Contributor` on the Terraform state storage account so it can read and write remote state.

### Portfolio lesson

Bootstrap privileges should be temporary. The mature pattern is to document the exception, reduce scope once resources exist, and verify the delivery pipeline still works under least privilege.

## Incident 012: Grafana access blocked by repeated IP drift

| Field | Details |
|---|---|
| Date encountered | 2026-06-27 |
| Area affected | Azure networking / Linux firewall / Terraform CI/CD |
| Severity | Low |
| Status | Resolved |
| Impact | The Grafana dashboard could not be opened from the administrator workstation. |

### Symptom

The VM was running, but TCP connections to `20.83.32.114:3000` timed out.

### Investigation

The workstation address no longer matched the administrator `/32` stored in the Azure NSG. During recovery, the ISP changed the address a second time. After Terraform updated the NSG, Grafana was still blocked because UFW retained the older Grafana-specific source address.

The first attempt to update `TF_ADMIN_SOURCE_CIDRS_JSON` also exposed a Windows CLI quoting issue: GitHub received `[102.91.5.192/32]` rather than valid JSON. Terraform rejected this during planning, so no infrastructure change occurred.

### Treatment

1. Updated the GitHub variable through the GitHub JSON API to preserve the required quotes.
2. Ran the protected Terraform workflow and approved the reviewed NSG-only plan.
3. Repeated the rotation when the ISP address changed again.
4. Used Azure VM Run Command to replace the stale UFW port `3000` rule with the current `/32`.
5. Verified TCP connectivity and an HTTP `200` response from `/login`.

Successful recovery workflow: `28281568823`.

### Prevention and follow-up

- Keep `/32` allowlisting for the current portfolio deployment.
- Treat both Azure NSG and UFW as required checks during access incidents.
- Prefer a stable private-access solution such as a VPN, Tailscale, or Azure Bastion for longer-lived environments.
- Pass structured GitHub variable values through JSON input when automating from PowerShell.

### Portfolio lesson

Layered controls can produce the same timeout independently. Effective troubleshooting validates client identity, cloud firewall state, host firewall state, service listening state, and HTTP response in order.

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
