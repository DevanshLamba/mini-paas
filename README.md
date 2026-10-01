# Mini-PaaS

A self-healing mini Platform-as-a-Service that runs entirely on a laptop:
**GitOps deploys, autoscaling, observability and chaos testing on a local k3d cluster**, built
only from free and open-source tools.

> 🚧 Work in progress. The project is built in phases; see [Roadmap](#roadmap).

## How it works (target)

`git push` → GitHub Actions (test, build, Trivy scan) → image on `ghcr.io` → CI bumps the
image tag in `deploy/` → ArgoCD syncs it to k3d → HPA/KEDA scale it, Prometheus/Grafana/Loki
observe it, and Chaos Mesh tries to break it.

## Repository layout

| Path | Purpose |
|---|---|
| [`app/`](app/) | Sample FastAPI service: the workload the platform deploys |
| [`deploy/`](deploy/) | Kustomize manifests: the GitOps source of truth that ArgoCD watches |
| [`infra/`](infra/) | k3d cluster config, Helm values for platform components, dashboards |
| [`scripts/`](scripts/) | PowerShell helpers: `cluster-up`, `cluster-down`, `deploy` |
| [`ci/`](ci/) | Supporting CI config (scanner settings, helper scripts) |
| [`.github/workflows/`](.github/workflows/) | GitHub Actions pipelines |
| [`loadtest/`](loadtest/) | k6 scenarios and result-analysis scripts |
| [`chaos/`](chaos/) | Chaos Mesh experiments and recovery-time measurement |
| [`dashboard/`](dashboard/) | Control plane: FastAPI + HTMX UI to list, deploy and roll back apps |
| [`docs/`](docs/) | Architecture, per-phase notes and the project report |

## Quick start

Prerequisites (Docker Desktop with cgroup v2, k3d, kubectl): see
[docs/phases/00-prerequisites.md](docs/phases/00-prerequisites.md).

```powershell
.\scripts\cluster-up.ps1      # k3d cluster: 1 server + 1 agent + local registry
.\scripts\deploy.ps1          # build, push, deploy deploy/overlays/dev
kubectl -n sampleapi-dev port-forward svc/sampleapi 8080:80
curl.exe localhost:8080/
.\scripts\cluster-down.ps1    # stop the cluster and free RAM (state is kept)
```

Run the app alone without Kubernetes: `cd app; docker compose up --build`.

## Roadmap

- [x] 0. Machine prerequisites
- [x] 1. Sample app, Docker, tests
- [x] 2. k3d cluster and Kubernetes manifests
- [ ] 3. CI: GitHub Actions, Trivy, ghcr.io
- [ ] 4. GitOps with ArgoCD and a rollback demo
- [ ] 5. Prometheus, Grafana, Loki
- [ ] 6. HPA, then KEDA
- [ ] 7. k6 load tests and graphs
- [ ] 8. Chaos Mesh experiments
- [ ] 9. Control-plane dashboard
- [ ] 10. Security hardening
- [ ] 11. Docs, architecture diagram, report

## License

[MIT](LICENSE)
