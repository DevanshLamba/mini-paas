<#
.SYNOPSIS
    Inner loop: build the app image, push it to the local registry and deploy it to the
    sampleapi-local namespace, without going through git.
.DESCRIPTION
    The dev environment (sampleapi-dev) is owned by Argo CD and only changes through git
    (see docs/phases/04-gitops.md). This script is for trying uncommitted code quickly.

    The image tag defaults to the short git SHA, plus a timestamp when app/ has uncommitted
    changes, so every deploy gets a unique, traceable tag. The tag is substituted into the
    rendered manifests at apply time, so no tracked file is modified.
.EXAMPLE
    .\scripts\deploy.ps1
    .\scripts\deploy.ps1 -Tag experiment-1
#>
[CmdletBinding()]
param(
    [string]$Tag
)
. "$PSScriptRoot\_common.ps1"

Assert-Tool docker, kubectl, git

if (-not $Tag) {
    $Tag = (git -C $RepoRoot rev-parse --short HEAD).Trim()
    if (git -C $RepoRoot status --porcelain -- app) {
        $Tag = "$Tag-dirty-$(Get-Date -Format 'yyyyMMddHHmmss')"
    }
}

$image = "sampleapi:$Tag"
Write-Step "Building $image"
Invoke-Native docker build --build-arg "APP_VERSION=$Tag" -t "$RegistryPush/$image" (Join-Path $RepoRoot 'app')

Write-Step "Pushing to $RegistryPush"
Invoke-Native docker push "$RegistryPush/$image"

Write-Step "Applying deploy/overlays/local with image $RegistryPull/$image"
$rendered = (kubectl kustomize $LocalOverlay) -join "`n"
if ($LASTEXITCODE -ne 0) { throw 'kubectl kustomize failed' }
$rendered = $rendered.Replace("$RegistryPull/sampleapi:local", "$RegistryPull/$image")
$rendered | kubectl apply -f -
if ($LASTEXITCODE -ne 0) { throw 'kubectl apply failed' }

Invoke-Native kubectl -n $LocalNamespace rollout status deployment/sampleapi --timeout=180s
Invoke-Native kubectl -n $LocalNamespace get pods -o wide
