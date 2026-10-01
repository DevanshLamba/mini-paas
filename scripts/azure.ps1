<#
.SYNOPSIS
    Run OpenTofu (or Terraform) in infra/terraform/azure with the inputs filled in safely.
.DESCRIPTION
    Requires that YOU have already run `az login` in your browser. This script then sets:
      ARM_SUBSCRIPTION_ID          from `az account show` (never printed)
      TF_VAR_allowed_locations     from your subscription's "Allowed resource deployment
                                   regions" policy (Azure for Students limits regions)
      TF_VAR_ssh_allowed_cidr      your current public IP as a /32
.EXAMPLE
    .\scripts\azure.ps1 init
    .\scripts\azure.ps1 plan -out tfplan
    .\scripts\azure.ps1 apply tfplan
    .\scripts\azure.ps1 output
    .\scripts\azure.ps1 -Location southeastasia plan -out tfplan
#>
# A simple (non-advanced) script on purpose: everything not bound below is passed to the
# tool via $args. An advanced script would claim flags like -out as -OutVariable.
param(
    [ValidateSet('tofu', 'terraform')]
    [string]$Tool = 'tofu',
    [string]$Location
)
$TfArgs = $args
. "$PSScriptRoot\_common.ps1"

Assert-Tool az, $Tool
$tfDir = Join-Path $RepoRoot 'infra\terraform\azure'

$account = az account show -o json 2>$null | ConvertFrom-Json
if (-not $account) { throw "Not logged in. Run 'az login' yourself first (browser sign-in), then re-run." }
$env:ARM_SUBSCRIPTION_ID = $account.id
Write-Step "Subscription: '$($account.name)' (state: $($account.state))"

# Azure for Students restricts deployments to a per-account list of regions.
$allowed = az policy assignment list `
    --query "[?contains(displayName, 'Allowed resource deployment regions') || contains(displayName, 'Allowed locations')].parameters.listOfAllowedLocations.value | [0]" `
    -o json 2>$null | ConvertFrom-Json
if ($allowed) {
    # Built by hand: PowerShell 5.1 has no ConvertTo-Json -AsArray, and a one-element
    # array would otherwise serialise as a bare string.
    $env:TF_VAR_allowed_locations = '["' + (@($allowed) -join '","') + '"]'
    Write-Step "Regions allowed by policy: $($allowed -join ', ')"
} else {
    Write-Warning 'No region policy found; region will not be pre-checked.'
}
if ($Location) { $env:TF_VAR_location = $Location }

if (-not $env:TF_VAR_ssh_allowed_cidr) {
    $ip = (Invoke-RestMethod -Uri 'https://api.ipify.org' -TimeoutSec 10).ToString().Trim()
    if ($ip -notmatch '^\d{1,3}(\.\d{1,3}){3}$') { throw "Could not determine public IPv4 (got '$ip')." }
    $env:TF_VAR_ssh_allowed_cidr = "$ip/32"
}
Write-Step "SSH will be allowed from $env:TF_VAR_ssh_allowed_cidr only"

Push-Location $tfDir
try {
    Invoke-Native $Tool @TfArgs
} finally {
    Pop-Location
    Remove-Item Env:ARM_SUBSCRIPTION_ID -ErrorAction SilentlyContinue
}
