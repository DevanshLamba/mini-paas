# Phase 0: Prerequisites (Windows 11 + Docker Desktop)

## Tools

| Tool | Version | Install |
|---|---|---|
| Docker Desktop (WSL2 backend) | 29.8.1 | docker.com |
| kubectl | 1.36.x (bundled with Docker Desktop) | |
| k3d | 5.9.0 | `winget install --id k3d.k3d --version 5.9.0 -e` |
| Helm | 4.3.0 | `winget install --id Helm.Helm --version 4.3.0 -e` |
| git, Python 3.13 | | |

Open a new terminal after installing, so `PATH` picks up the new tools.

## WSL2 settings: `%USERPROFILE%\.wslconfig`

```ini
[wsl2]
memory=4096MB
processors=4
swap=4GB
# Kubernetes 1.35+ refuses to run on cgroup v1; force the unified cgroup v2 hierarchy.
kernelCommandLine = cgroup_no_v1=all
```

Apply it with `wsl --shutdown`, then restart Docker Desktop.

- **`memory`** caps the Linux VM that runs Docker, so the cluster can't starve Windows on
  an 8 GB laptop.
- **`kernelCommandLine`** is required with WSL 2.4.x (kernel 5.15), which boots with
  *hybrid* cgroups, so Docker reports `CgroupVersion=1`. Since Kubernetes 1.35 the kubelet
  refuses cgroup v1 by default. The symptom is a k3s server that logs
  `kubelet is configured to not run on a host using cgroup v1` and exits, while
  `k3d cluster create` waits forever.

Verify:

```powershell
docker info --format "{{.CgroupVersion}}"   # must print 2
docker info --format "{{.MemTotal}}"        # about 4.1e9 bytes
```

`scripts/cluster-up.ps1` checks the cgroup version and stops with this explanation if it's wrong.
