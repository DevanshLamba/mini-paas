<#
.SYNOPSIS
    Install or upgrade Argo CD with the slim values, then register the sampleapi Application.
.DESCRIPTION
    Idempotent (helm upgrade --install + kubectl apply). Prints the initial admin password
    location instead of the password itself.
.EXAMPLE
    .\scripts\install-argocd.ps1
#>
[CmdletBinding()]
param()
. "$PSScriptRoot\_common.ps1"

$ChartVersion = '10.9.6'   # Argo CD v3.5.3
$Values       = Join-Path $RepoRoot 'infra\helm-values\argocd.yaml'
$AppManifests = Join-Path $RepoRoot 'deploy\argocd'

Assert-Tool helm, kubectl

Write-Step 'Adding the argo Helm repository'
Invoke-Native helm repo add argo https://argoproj.github.io/argo-helm --force-update
Invoke-Native helm repo update argo

Write-Step "Installing argo/argo-cd $ChartVersion into namespace argocd"
Invoke-Native helm upgrade --install argocd argo/argo-cd `
    --version $ChartVersion --namespace argocd --create-namespace `
    --values $Values --wait --timeout 10m

Write-Step 'Registering the AppProject and Application'
Invoke-Native kubectl apply -f $AppManifests

Write-Step 'Done'
Write-Host 'UI:       kubectl -n argocd port-forward svc/argocd-server 8081:80  ->  http://localhost:8081'
Write-Host 'User:     admin'
Write-Host 'Password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}"  (base64)'
