<#
.SYNOPSIS
    Install or upgrade Argo CD with the slim values, then register the Applications.
.DESCRIPTION
    Idempotent (helm upgrade --install + kubectl apply). Prints the initial admin password
    location instead of the password itself. The same values file is used for every cluster.
.EXAMPLE
    .\scripts\install-argocd.ps1                                   # local k3d -> deploy/argocd
    .\scripts\install-argocd.ps1 -KubeContext minipaas-azure -AppsPath deploy\argocd\cloud
#>
param(
    [string]$KubeContext = '',
    [string]$AppsPath = 'deploy\argocd'
)
. "$PSScriptRoot\_common.ps1"

$ChartVersion = '10.9.6'   # Argo CD v3.5.3
$Values       = Join-Path $RepoRoot 'infra\helm-values\argocd.yaml'
$AppManifests = Join-Path $RepoRoot $AppsPath
$helmCtx = @(); $kubeCtx = @()
if ($KubeContext) { $helmCtx = @('--kube-context', $KubeContext); $kubeCtx = @('--context', $KubeContext) }

Assert-Tool helm, kubectl

Write-Step 'Adding the argo Helm repository'
Invoke-Native helm repo add argo https://argoproj.github.io/argo-helm --force-update
Invoke-Native helm repo update argo

Write-Step "Installing argo/argo-cd $ChartVersion into namespace argocd $(if ($KubeContext) { "(context $KubeContext)" })"
Invoke-Native helm upgrade --install argocd argo/argo-cd @helmCtx `
    --version $ChartVersion --namespace argocd --create-namespace `
    --values $Values --wait --timeout 10m

Write-Step "Registering AppProject and Applications from $AppsPath"
Invoke-Native kubectl @kubeCtx apply -f $AppManifests

Write-Step 'Done'
$c = if ($KubeContext) { " --context $KubeContext" } else { '' }
Write-Host "UI:       kubectl$c -n argocd port-forward svc/argocd-server 8081:80  ->  http://localhost:8081"
Write-Host 'User:     admin'
Write-Host "Password: kubectl$c -n argocd get secret argocd-initial-admin-secret -o jsonpath=`"{.data.password}`"  (base64)"
