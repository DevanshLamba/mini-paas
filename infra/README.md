# infra/

Everything that builds the platform itself rather than the app: the k3d cluster config,
pinned Helm values for platform components (ArgoCD, Prometheus, Loki, KEDA, Chaos Mesh,
Sealed Secrets) and Grafana dashboards as code. Scripts that use them live in [`scripts/`](../scripts/).

_Filled in from Phase 2 onward._
