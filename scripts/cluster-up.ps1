<#
.SYNOPSIS
    Create (or restart) the local k3d cluster and its image registry.
.DESCRIPTION
    Idempotent: if the cluster already exists it is started, not recreated.
.EXAMPLE
    .\scripts\cluster-up.ps1
#>
[CmdletBinding()]
param()
. "$PSScriptRoot\_common.ps1"

Assert-Tool docker, k3d, kubectl

# Kubernetes 1.35+ kubelets refuse cgroup v1, which shows up as a cluster that never
# becomes ready. Fail early with a clear message instead.
$cgroup = docker info --format '{{.CgroupVersion}}'
if ($cgroup -ne '2') {
    throw "Docker reports cgroup v$cgroup; k3s needs v2. Add 'kernelCommandLine = cgroup_no_v1=all' under [wsl2] in ~/.wslconfig, run 'wsl --shutdown', and restart Docker Desktop."
}

$existing = k3d cluster list -o json | ConvertFrom-Json | Where-Object { $_.name -eq $ClusterName }
if ($existing) {
    Write-Step "Cluster '$ClusterName' exists; starting it"
    Invoke-Native k3d cluster start $ClusterName
    Invoke-Native k3d kubeconfig merge $ClusterName --kubeconfig-merge-default --kubeconfig-switch-context
} else {
    Write-Step "Creating cluster '$ClusterName' from $K3dConfig"
    Invoke-Native k3d cluster create --config $K3dConfig
}

Write-Step 'Waiting for nodes to be Ready'
Invoke-Native kubectl wait --for=condition=Ready nodes --all --timeout=120s
Invoke-Native kubectl get nodes -o wide

Write-Step 'Container memory usage'
Show-ClusterMemory
