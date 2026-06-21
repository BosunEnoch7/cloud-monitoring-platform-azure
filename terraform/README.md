# Terraform

This directory contains the infrastructure as code for the platform.

## Layout

```text
terraform/
|-- modules/
|   |-- network/
|   `-- compute/
`-- environments/
    `-- dev/
```

`modules/` contains reusable infrastructure components. `environments/dev/` is the deployable root module that will compose those components and supply environment-specific values.

Terraform files are deliberately not placed directly in this directory. Having both this directory and `environments/dev/` act as root modules would make initialization and state ownership ambiguous.

## Provider strategy

The development root requires Terraform `>= 1.6.0, < 2.0.0` and AzureRM `~> 4.0`. The broad compatible constraint allows reviewed 4.x upgrades, while the committed dependency lock file makes normal initialization reproducible by selecting the same exact provider build.

Azure credentials are not declared as Terraform variables or stored in files. Local development will use Azure CLI authentication; CI/CD will later use GitHub-to-Azure workload identity federation instead of a long-lived client secret.

## State strategy

The development environment is **remote-state-ready**: backend configuration is isolated in `backend.tf`. It currently uses local state so the first infrastructure lesson remains focused. A later phase will migrate it to Azure Storage without restructuring the resource code.

Terraform state can contain sensitive infrastructure data and must never be committed. A later phase will provision or document the remote-state bootstrap process separately, because a backend cannot normally create the storage it depends on during the same initialization operation.

## Intended workflow

Commands will be run from the selected environment directory:

```text
terraform fmt -check -recursive
terraform init
terraform validate
terraform plan
```

Run environment commands from `terraform/environments/dev`. Module directories are reusable components, not independently deployed environments.
