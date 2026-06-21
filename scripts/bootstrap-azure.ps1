[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')]
    [string]$SubscriptionId,

    [Parameter(Mandatory)]
    [ValidatePattern('^[a-z0-9]{3,24}$')]
    [string]$StateStorageAccount,

    [string]$GitHubOwner = 'BosunEnoch7',
    [string]$GitHubRepository = 'cloud-monitoring-platform-azure',
    [string]$StateResourceGroup = 'cloud-monitoring-tfstate-rg',
    [string]$StateContainer = 'tfstate',
    [string]$Location = 'eastus'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if ($Location -ne 'eastus') {
    throw 'This project standardizes Azure resources in eastus.'
}

function Invoke-AzCli {
    param([Parameter(Mandatory)][string[]]$Arguments)

    $output = & az @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Azure CLI command failed: az $($Arguments -join ' ')"
    }

    return $output
}

function Get-OrCreateApplication {
    param([Parameter(Mandatory)][string]$DisplayName)

    $appId = Invoke-AzCli @('ad', 'app', 'list', '--display-name', $DisplayName, '--query', '[0].appId', '--output', 'tsv')
    if ([string]::IsNullOrWhiteSpace($appId)) {
        $appId = Invoke-AzCli @('ad', 'app', 'create', '--display-name', $DisplayName, '--query', 'appId', '--output', 'tsv')
    }

    $servicePrincipalId = Invoke-AzCli @('ad', 'sp', 'list', '--filter', "appId eq '$appId'", '--query', '[0].id', '--output', 'tsv')
    if ([string]::IsNullOrWhiteSpace($servicePrincipalId)) {
        $servicePrincipalId = Invoke-AzCli @('ad', 'sp', 'create', '--id', $appId, '--query', 'id', '--output', 'tsv')
    }

    return @{
        AppId              = $appId.Trim()
        ServicePrincipalId = $servicePrincipalId.Trim()
    }
}

function Add-FederatedCredential {
    param(
        [Parameter(Mandatory)][string]$AppId,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Subject
    )

    $existingSubject = Invoke-AzCli @('ad', 'app', 'federated-credential', 'list', '--id', $AppId, '--query', "[?name=='$Name'].subject | [0]", '--output', 'tsv')
    if ($existingSubject -eq $Subject) {
        return
    }

    $definition = @{
        name        = $Name
        issuer      = 'https://token.actions.githubusercontent.com'
        subject     = $Subject
        description = "GitHub OIDC trust for $Subject"
        audiences   = @('api://AzureADTokenExchange')
    } | ConvertTo-Json -Compress

    $definitionPath = [System.IO.Path]::GetTempFileName()
    try {
        Set-Content -LiteralPath $definitionPath -Value $definition -Encoding utf8
        if ([string]::IsNullOrWhiteSpace($existingSubject)) {
            Invoke-AzCli @('ad', 'app', 'federated-credential', 'create', '--id', $AppId, '--parameters', $definitionPath) | Out-Null
        }
        else {
            Invoke-AzCli @('ad', 'app', 'federated-credential', 'update', '--id', $AppId, '--federated-credential-id', $Name, '--parameters', $definitionPath) | Out-Null
        }
    }
    finally {
        Remove-Item -LiteralPath $definitionPath -Force -ErrorAction SilentlyContinue
    }
}

function Add-RoleAssignment {
    param(
        [Parameter(Mandatory)][string]$PrincipalId,
        [Parameter(Mandatory)][string]$Role,
        [Parameter(Mandatory)][string]$Scope
    )

    $existing = Invoke-AzCli @('role', 'assignment', 'list', '--assignee', $PrincipalId, '--role', $Role, '--scope', $Scope, '--query', '[0].id', '--output', 'tsv')
    if (-not [string]::IsNullOrWhiteSpace($existing)) {
        return
    }

    Invoke-AzCli @(
        'role', 'assignment', 'create',
        '--assignee-object-id', $PrincipalId,
        '--assignee-principal-type', 'ServicePrincipal',
        '--role', $Role,
        '--scope', $Scope
    ) | Out-Null
}

Invoke-AzCli @('account', 'set', '--subscription', $SubscriptionId) | Out-Null
$tenantId = (Invoke-AzCli @('account', 'show', '--query', 'tenantId', '--output', 'tsv')).Trim()
$subscriptionScope = "/subscriptions/$SubscriptionId"

foreach ($resourceProvider in @('Microsoft.Compute', 'Microsoft.Network', 'Microsoft.Storage')) {
    Invoke-AzCli @('provider', 'register', '--namespace', $resourceProvider, '--wait') | Out-Null
}

Invoke-AzCli @(
    'group', 'create',
    '--name', $StateResourceGroup,
    '--location', $Location,
    '--tags', 'project=cloud-monitoring', 'environment=bootstrap', 'managed_by=bootstrap-script'
) | Out-Null

Invoke-AzCli @(
    'storage', 'account', 'create',
    '--name', $StateStorageAccount,
    '--resource-group', $StateResourceGroup,
    '--location', $Location,
    '--sku', 'Standard_LRS',
    '--kind', 'StorageV2',
    '--https-only', 'true',
    '--min-tls-version', 'TLS1_2',
    '--allow-blob-public-access', 'false'
) | Out-Null

Invoke-AzCli @(
    'storage', 'container-rm', 'create',
    '--name', $StateContainer,
    '--storage-account', $StateStorageAccount,
    '--resource-group', $StateResourceGroup,
    '--public-access', 'off'
) | Out-Null

Invoke-AzCli @(
    'storage', 'account', 'blob-service-properties', 'update',
    '--account-name', $StateStorageAccount,
    '--resource-group', $StateResourceGroup,
    '--enable-versioning', 'true',
    '--enable-delete-retention', 'true',
    '--delete-retention-days', '14',
    '--enable-container-delete-retention', 'true',
    '--container-delete-retention-days', '14'
) | Out-Null

Invoke-AzCli @(
    'storage', 'account', 'update',
    '--name', $StateStorageAccount,
    '--resource-group', $StateResourceGroup,
    '--allow-shared-key-access', 'false'
) | Out-Null

$storageScope = (Invoke-AzCli @(
    'storage', 'account', 'show',
    '--name', $StateStorageAccount,
    '--resource-group', $StateResourceGroup,
    '--query', 'id',
    '--output', 'tsv'
)).Trim()

$planIdentity = Get-OrCreateApplication 'github-cloud-monitoring-plan'
$applyIdentity = Get-OrCreateApplication 'github-cloud-monitoring-apply'
$repositorySubject = "repo:$GitHubOwner/$GitHubRepository"

Add-FederatedCredential $planIdentity.AppId 'pull-request-plan' "$repositorySubject`:pull_request"
Add-FederatedCredential $planIdentity.AppId 'main-branch-plan' "$repositorySubject`:ref:refs/heads/main"
Add-FederatedCredential $applyIdentity.AppId 'dev-environment-apply' "$repositorySubject`:environment:dev"

Add-RoleAssignment $planIdentity.ServicePrincipalId 'Reader' $subscriptionScope
Add-RoleAssignment $planIdentity.ServicePrincipalId 'Storage Blob Data Contributor' $storageScope
Add-RoleAssignment $applyIdentity.ServicePrincipalId 'Contributor' $subscriptionScope
Add-RoleAssignment $applyIdentity.ServicePrincipalId 'Storage Blob Data Contributor' $storageScope

Write-Host ''
Write-Host 'Bootstrap complete. Configure these GitHub repository variables:'
Write-Host "AZURE_TENANT_ID=$tenantId"
Write-Host "AZURE_SUBSCRIPTION_ID=$SubscriptionId"
Write-Host "AZURE_PLAN_CLIENT_ID=$($planIdentity.AppId)"
Write-Host "AZURE_APPLY_CLIENT_ID=$($applyIdentity.AppId)"
Write-Host "TF_STATE_RESOURCE_GROUP=$StateResourceGroup"
Write-Host "TF_STATE_STORAGE_ACCOUNT=$StateStorageAccount"
Write-Host "TF_STATE_CONTAINER=$StateContainer"
Write-Host 'TF_STATE_KEY=cloud-monitoring/dev.tfstate'
Write-Host ''
Write-Warning 'The apply identity initially has Contributor at subscription scope so Terraform can create the workload resource group. Re-scope it to the workload resource group after the first deployment.'
