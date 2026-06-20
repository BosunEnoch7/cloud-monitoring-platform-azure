# Terraform

This directory will contain the infrastructure as code for the platform.

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

## State strategy

The development environment will initially be **remote-state-ready**: its backend configuration will be isolated so local state can be replaced by an Azure Storage backend without restructuring the code.

Terraform state can contain sensitive infrastructure data and must never be committed. A later phase will provision or document the remote-state bootstrap process separately, because a backend cannot normally create the storage it depends on during the same initialization operation.

## Intended workflow

Commands will be run from the selected environment directory:

```text
terraform fmt -check -recursive
terraform init
terraform validate
terraform plan
```

Exact commands and prerequisites will be added with the Terraform implementation.
