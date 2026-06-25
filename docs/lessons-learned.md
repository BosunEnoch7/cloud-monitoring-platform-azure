# Lessons learned

Technical discoveries, mistakes, tradeoffs, and changes in approach will be recorded here throughout the project.

Detailed incident timelines and treatments are tracked in the [Incident and blocker log](incidents.md). This file summarizes the engineering lessons that came out of those events.

## East US burstable VM capacity

The first GitHub Actions apply successfully created the resource group and network resources but Azure returned `SkuNotAvailable` for `Standard_B2s` in `eastus`.

Terraform preserved the successfully created resources in remote state and released the state lock. No manual deletion or state editing was necessary. The next plan can reconcile the partial deployment and create only the missing VM.

The first replacement, `Standard_B2als_v2`, retained the intended 2-vCPU/4-GiB capacity but was rejected by the same live B-series capacity restriction on the next approved apply.

The project therefore moved to `Standard_D2as_v5`, a 2-vCPU/8-GiB general-purpose SKU. This increases compute cost, but it avoids repeatedly selecting from the constrained burstable pool and gives Prometheus and Grafana more realistic memory headroom.

This demonstrates why regional SKU presence does not guarantee live allocation capacity and why apply workflows must be safely rerunnable. Each failed apply left existing infrastructure and remote state healthy; only the missing VM remained in the next plan.

After the general-purpose SKU was also rejected from the regional pool, the design adopted explicit East US Zone 1 placement for both the VM and its Standard public IP. Azure capacity is partitioned by allocation scope, so a zonal request can succeed even when the non-zonal regional pool is constrained.

Zone 1 accepted the zonal public IP but still rejected the D2as_v5 VM allocation. Zone 2 returned the same capacity restriction. The final East US-only retry moved both resources to Zone 3 while retaining the required East US region.

Zone 3 also rejected `Standard_D2as_v5`. At that point the project stopped retrying the same SKU family and moved to a different general-purpose family, `Standard_D2s_v3`, while keeping East US and Zone 3 unchanged.

After `Standard_D2s_v3` also failed allocation in East US, the project moved the workload default to `eastus2` as an approved region fallback. This is a practical production-style decision: repeated capacity retries create delivery risk, while a documented fallback region preserves momentum and keeps the decision auditable.

Changing an Azure resource group's location is not an in-place update. The first fallback apply exposed a naming issue: Terraform could not create a replacement resource group with the same name while the original group still existed. The fix was to include the location suffix in the workload resource group name so future region fallbacks have a clean target name.

After the East US 2 network layer was created, VM allocation still failed for `Standard_D2s_v3` in Zone 3. This confirmed that capacity can be constrained at the zone level even when the region, quota, and networking are valid. The next retry moved the zonal default to Zone 1.

When Zone 1 also rejected `Standard_D2s_v3`, the project stopped rotating only zones and changed compute families to `Standard_D2as_v5`. This is a better recovery pattern than repeatedly applying the same constrained SKU.

After East US 2 also rejected `Standard_D2as_v5`, the project moved to a different US region, `centralus`, after checking regional vCPU quota. This is the point where persistence becomes operational judgment: retrying the same constrained geography stops being useful.

Central US accepted the network resources but rejected `Standard_D2as_v5` for VM allocation. This reinforces that quota, resource-provider availability, and live VM capacity are separate checks. The next retry used `Standard_D2s_v3` in Central US to test a different compute family pool.

Converting the existing public IP from non-zonal to zonal requires replacement. Azure correctly prevents deletion while a NIC still references the address. The compute module therefore gives the zonal IP a distinct name and uses Terraform's `create_before_destroy` lifecycle: create the zonal IP, update the NIC, and only then delete the old address. This preserves declarative ownership without manual portal changes.

The final successful allocation used `Standard_D2s_v3` in Central US Zone 1. This resolved the capacity incident without abandoning the desired 2-vCPU/8-GiB host profile.

## Administrative access allowlists

Restricting SSH to one public `/32` address prevented access when the workstation address changed. That timeout was expected security behavior, not VM failure. Updating the GitHub variable and applying the NSG change through the protected Terraform workflow restored access without opening port `22` globally.

Repository variables consumed as Terraform complex types must preserve valid JSON/HCL syntax. Passing the CIDR list through a native command-line argument removed its quotation marks; passing the exact value through standard input preserved it. The failed workflow stopped during planning, before any infrastructure mutation.

## Layered host verification

Successful Terraform apply was only the start of operational verification. SSH confirmed the host identity and Azure kernel, systemd confirmed Node Exporter was active and enabled, the local `/metrics` endpoint returned real host metrics, and UFW confirmed default-deny inbound behavior. Multiple signals provide stronger evidence than relying on deployment status alone.

## Prometheus readiness and idempotency

Prometheus passed checksum and configuration validation but was not ready at the exact instant of the first health request. Systemd and journal evidence showed a normal one-second TSDB initialization period. Replacing the single request with a bounded readiness retry removed the false failure without hiding genuine startup problems.

The installer also detects the installed pinned version before downloading. A verification rerun skipped the 145 MB archive, reapplied configuration, restarted services safely, and passed all health checks. Idempotency should cover both correctness and operational efficiency.

## Separate alert transport from notification credentials

Alertmanager can be installed and its local transport path validated before SMTP credentials exist. A temporary no-notification receiver allowed Prometheus discovery, alert ingestion, grouping, and resolution to be tested without committing placeholders or requesting a password through chat.

This separates two failure domains: local alert delivery and external SMTP delivery. When email is enabled, any remaining failure is easier to isolate to provider authentication, TLS, or mailbox policy.

## Provision dashboards instead of clicking them into existence

Grafana's Prometheus data source, dashboard provider, and node dashboard are all version-controlled. The runtime API confirmed that Grafana loaded the dashboard as provisioned and marked the data source read-only.

This preserves reproducibility and makes every PromQL visualization reviewable. Grafana installation increased root-disk use to roughly 3.8 GB of 62 GB and memory use remained comfortably within the 8 GiB VM profile.
