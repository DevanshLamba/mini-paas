<#
.SYNOPSIS
    Stop Azure credit usage: destroy everything (default) or just deallocate the VM.
.DESCRIPTION
    Default: `tofu destroy` removes every resource in infra/terraform/azure (resource group,
    network, public IP, VM and disk). Credit use drops to zero. Recreate later with
    `.\scripts\azure.ps1 apply`.

    -StopOnly: deallocate the VM instead. Compute billing stops, but the public IP and the
    disk keep costing a little (about $0.21/day in centralindia). The cluster state survives.
.EXAMPLE
    .\scripts\azure-destroy.ps1             # asks for confirmation, then destroys everything
    .\scripts\azure-destroy.ps1 -StopOnly   # pause: deallocate the VM only
#>
param(
    [switch]$StopOnly,
    [switch]$Force,
    [ValidateSet('tofu', 'terraform')]
    [string]$Tool = 'tofu'
)
. "$PSScriptRoot\_common.ps1"

Assert-Tool az
$rg = 'minipaas-rg'
$vm = 'minipaas-k3s'

if ($StopOnly) {
    Write-Step "Deallocating VM $vm (compute billing stops; disk + IP remain)"
    Invoke-Native az vm deallocate --resource-group $rg --name $vm
    Invoke-Native az vm show --resource-group $rg --name $vm -d --query powerState -o tsv
    return
}

if (-not $Force) {
    $answer = Read-Host "Destroy ALL Azure resources in $rg (VM, disk, IP, network)? [y/N]"
    if ($answer -notmatch '^(y|yes)$') { Write-Host 'Aborted.'; return }
}

& "$PSScriptRoot\azure.ps1" -Tool $Tool destroy -auto-approve
if ($LASTEXITCODE -ne 0) { throw 'destroy failed; check the output above and the Azure portal.' }

Write-Step 'Verifying nothing is left'
$exists = az group exists --name $rg
Write-Host "Resource group $rg exists: $exists"
if ($exists -eq 'true') { throw "Resource group $rg still exists. Check the portal." }
Write-Host 'All project resources are gone; no further credit is being used.'
