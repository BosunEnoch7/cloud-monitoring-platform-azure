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

Converting the existing public IP from non-zonal to zonal requires replacement. Azure correctly prevents deletion while a NIC still references the address. The compute module therefore gives the zonal IP a distinct name and uses Terraform's `create_before_destroy` lifecycle: create the zonal IP, update the NIC, and only then delete the old address. This preserves declarative ownership without manual portal changes.
