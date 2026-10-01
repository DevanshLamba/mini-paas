<#
.SYNOPSIS
    Run Terraform or OpenTofu in infra/terraform/oci with the inputs filled in safely.
.DESCRIPTION
    - TF_VAR_tenancy_ocid is read from ~/.oci/config (never printed or written to disk).
    - TF_VAR_ssh_allowed_cidr is your current public IP as a /32, so SSH is open to you only.
    The OCI provider itself reads the API key from ~/.oci/config.
.EXAMPLE
    .\scripts\oci.ps1 init
    .\scripts\oci.ps1 plan -out tfplan
    .\scripts\oci.ps1 apply tfplan
    .\scripts\oci.ps1 destroy
    .\scripts\oci.ps1 -Tool tofu plan
#>
# A simple (non-advanced) script on purpose: everything not bound below is passed to
# Terraform via $args. An advanced script would claim flags like -out as -OutVariable.
param(
    [ValidateSet('terraform', 'tofu')]
    [string]$Tool = 'terraform',
    [string]$OciProfile = 'DEFAULT'
)
$TfArgs = $args
. "$PSScriptRoot\_common.ps1"

Assert-Tool $Tool
$tfDir = Join-Path $RepoRoot 'infra\terraform\oci'
$ociConfig = Join-Path $HOME '.oci\config'
if (-not (Test-Path $ociConfig)) {
    throw "No $ociConfig. Create an API key in the OCI Console first (see docs/phases/045-cloud.md)."
}

# Read tenancy= from the chosen profile without echoing it.
$inProfile = $false
foreach ($line in Get-Content $ociConfig) {
    if ($line -match '^\s*\[(.+)\]\s*$') { $inProfile = ($Matches[1] -eq $OciProfile); continue }
    if ($inProfile -and $line -match '^\s*tenancy\s*=\s*(\S+)') { $env:TF_VAR_tenancy_ocid = $Matches[1] }
}
if (-not $env:TF_VAR_tenancy_ocid) { throw "No 'tenancy' key in profile [$OciProfile] of $ociConfig." }
$env:TF_VAR_oci_profile = $OciProfile

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
    Remove-Item Env:TF_VAR_tenancy_ocid -ErrorAction SilentlyContinue
}
