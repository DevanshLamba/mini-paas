<#
.SYNOPSIS
    Build the app image, push it to the local registry and deploy the dev overlay.
.DESCRIPTION
    The image tag defaults to the short git SHA, plus a timestamp when app/ has uncommitted
    changes, so every deploy of new code gets a unique, traceable tag. The tag is
    written into deploy/overlays/dev/kustomization.yaml, the same change CI will make
    in the GitOps flow (Phase 4).
.EXAMPLE
    .\scripts\deploy.ps1
    .\scripts\deploy.ps1 -Tag v1.0.0
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

Write-Step "Setting dev overlay image tag to $Tag"
$kustomization = Join-Path $DevOverlay 'kustomization.yaml'
$content = [IO.File]::ReadAllText($kustomization)
$updated = $content -replace '(?m)^(\s*newTag:\s*).*$', "`${1}$Tag"
# Write UTF-8 without BOM and keep LF line endings (PowerShell 5.1's Set-Content adds a BOM).
[IO.File]::WriteAllText($kustomization, $updated, (New-Object Text.UTF8Encoding $false))

Write-Step 'Applying deploy/overlays/dev'
Invoke-Native kubectl apply -k $DevOverlay
Invoke-Native kubectl -n $AppNamespace rollout status deployment/sampleapi --timeout=180s
Invoke-Native kubectl -n $AppNamespace get pods -o wide
