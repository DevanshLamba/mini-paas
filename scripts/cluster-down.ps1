<#
.SYNOPSIS
    Stop the local cluster to free RAM, or delete it entirely with -Delete.
.DESCRIPTION
    By default the cluster is only stopped: its state and the pushed images survive,
    and cluster-up.ps1 starts it again in seconds. -Delete removes the cluster and its
    registry (asks for confirmation unless -Force is given).
.EXAMPLE
    .\scripts\cluster-down.ps1            # stop, keep everything
    .\scripts\cluster-down.ps1 -Delete    # remove cluster + registry
#>
[CmdletBinding()]
param(
    [switch]$Delete,
    [switch]$Force
)
. "$PSScriptRoot\_common.ps1"

Assert-Tool k3d

if (-not $Delete) {
    Write-Step "Stopping cluster '$ClusterName' (state is kept)"
    Invoke-Native k3d cluster stop $ClusterName
    return
}

if (-not $Force) {
    $answer = Read-Host "Delete cluster '$ClusterName' and its registry? All cluster state is lost. [y/N]"
    if ($answer -notmatch '^(y|yes)$') {
        Write-Host 'Aborted.'
        return
    }
}
Write-Step "Deleting cluster '$ClusterName'"
Invoke-Native k3d cluster delete $ClusterName
