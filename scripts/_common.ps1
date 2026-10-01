# Shared settings and helpers, dot-sourced by the other scripts.
# Kept ASCII-only so Windows PowerShell 5.1 reads it correctly without a BOM.

$ErrorActionPreference = 'Stop'

$RepoRoot      = Split-Path -Parent $PSScriptRoot
$ClusterName   = 'minipaas'
$K3dConfig     = Join-Path $RepoRoot 'infra\k3d\k3d-config.yaml'
$RegistryPush  = 'localhost:5050'                      # address the host pushes to
$RegistryPull  = 'minipaas-registry.localhost:5050'    # address the cluster pulls from
# deploy.ps1's inner loop. The dev overlay/namespace belong to Argo CD (GitOps).
$LocalNamespace = 'sampleapi-local'
$LocalOverlay  = Join-Path $RepoRoot 'deploy\overlays\local'

# Pick up tools installed (e.g. by winget) after this terminal was opened.
$env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
            [Environment]::GetEnvironmentVariable('Path', 'User')

function Write-Step([string]$Message) {
    Write-Host "==> $Message" -ForegroundColor Cyan
}

# Run a native command and throw if it fails (PowerShell 5.1 does not do this by itself).
# Deliberately a simple function using $args: an advanced function (with [Parameter])
# would treat flags like `-o` as its own common parameters (-OutVariable, ...).
function Invoke-Native {
    $Command, $Arguments = $args
    # Many CLIs (k3d, docker) log progress to stderr; don't let that count as an error.
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        & $Command @Arguments
        $code = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previous
    }
    if ($code -ne 0) {
        throw "'$Command $($Arguments -join ' ')' failed with exit code $code"
    }
}

function Assert-Tool([string[]]$Names) {
    foreach ($name in $Names) {
        if (-not (Get-Command $name -ErrorAction SilentlyContinue)) {
            throw "'$name' not found on PATH. See docs/phases/00-prerequisites.md."
        }
    }
}

function Show-ClusterMemory {
    docker stats --no-stream --format "{{.Name}}`t{{.MemUsage}}" |
        Where-Object { $_ -match "k3d-$ClusterName|minipaas-registry" }
}
