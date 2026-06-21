# Lessons learned

Technical discoveries, mistakes, tradeoffs, and changes in approach will be recorded here throughout the project.

## East US burstable VM capacity

The first GitHub Actions apply successfully created the resource group and network resources but Azure returned `SkuNotAvailable` for `Standard_B2s` in `eastus`.

Terraform preserved the successfully created resources in remote state and released the state lock. No manual deletion or state editing was necessary. The next plan can reconcile the partial deployment and create only the missing VM.

The replacement, `Standard_B2als_v2`, retains the intended 2-vCPU/4-GiB capacity with a burstable cost profile. This demonstrates why regional SKU presence does not guarantee live allocation capacity and why apply workflows must be safely rerunnable.
