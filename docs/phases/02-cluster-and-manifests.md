# Phase 2: k3d cluster and Kubernetes manifests

## What was built

- A reproducible local Kubernetes cluster: k3d running k3s v1.36.5, with 1 server, 1 agent
  and a local image registry.
- Kustomize manifests for the sample app, with probes, resource limits, zero-downtime
  rolling updates and a "restricted" security posture.
- PowerShell scripts to bring the cluster up and down and to build-push-deploy.

## File-by-file

| File | What and why |
|---|---|
| `infra/k3d/k3d-config.yaml` | Declarative cluster definition (nodes, pinned k3s image, registry, disabled add-ons), so the cluster is reproducible from git instead of a long CLI command |
| `deploy/base/deployment.yaml` | The app's Deployment: 2 replicas, startup, liveness and readiness probes, small requests and limits, `maxUnavailable: 0` rolling update, preStop sleep, non-root read-only security context, spread across nodes |
| `deploy/base/service.yaml` | Stable ClusterIP and DNS name (`sampleapi`) that load-balances across Ready pods only |
| `deploy/base/kustomization.yaml` | Lists the base resources and adds standard `app.kubernetes.io/*` labels |
| `deploy/overlays/dev/kustomization.yaml` | Dev environment: sets the namespace, environment label and image name and tag. The tag is the one field CI will change in GitOps |
| `deploy/overlays/dev/namespace.yaml` | `sampleapi-dev` namespace, with Pod Security Admission enforcing the `restricted` profile |
| `scripts/_common.ps1` | Shared constants (cluster name, registry addresses) and helpers. `Invoke-Native` makes failed CLI calls stop the script |
| `scripts/cluster-up.ps1` | Idempotent: checks for cgroup v2, creates or starts the cluster, waits for nodes, prints memory |
| `scripts/cluster-down.ps1` | Stops the cluster to free RAM while keeping its state. `-Delete` removes it, after confirmation |
| `scripts/deploy.ps1` | Builds an image tagged with the git SHA, pushes it to the local registry, sets the tag in the overlay, applies it and waits for the rollout |

## Usage

```powershell
.\scripts\cluster-up.ps1
.\scripts\deploy.ps1
kubectl -n sampleapi-dev get pods -o wide
kubectl -n sampleapi-dev port-forward svc/sampleapi 8080:80   # then open http://localhost:8080/docs
.\scripts\cluster-down.ps1          # stop and free RAM; state is kept
```

## Design decisions

- **Why k3d?** k3s in Docker containers: about 1 GB for the whole cluster, multi-node, a
  built-in registry, and creation in under a minute. kind runs full upstream Kubernetes and
  is heavier. minikube usually runs a VM per cluster.
- **Why disable the k3d load balancer?** With a single server there is nothing to balance,
  and dropping it saves a container.
- **Why a local registry?** `docker build` puts images in Docker's store, not the cluster's
  containerd. Pushing to a registry is how real clusters get images, and it avoids
  `k3d image import` copying the whole image into every node.
- **Two registry names.** The host pushes to `localhost:5050`, because Docker trusts
  `localhost` over plain HTTP. Nodes pull `minipaas-registry.localhost:5050`, which k3d maps
  to the registry container in each node's `registries.yaml`.
- **Kustomize over Helm for our app.** Plain YAML plus patches, no templating language. It's
  built into `kubectl` (`apply -k`) and natively supported by ArgoCD. Helm is used for
  third-party software in later phases.
- **Requests vs. limits.** A small request (50m CPU, 64Mi) lets many pods fit on a laptop.
  The CPU limit (500m) makes HPA behaviour predictable in load tests. The memory limit
  (128Mi, about 3x observed use) contains leaks: the pod is OOM-killed instead of the node.
- **Three probes.** Startup protects slow starts. Liveness restarts a hung process.
  Readiness gates traffic.
- **preStop `sleep: 5`.** When a pod is deleted, endpoint removal and SIGTERM happen in
  parallel. The pause lets every node stop routing to the pod before it exits. The native
  `sleep` action (GA in 1.34) needs no shell in the image.
- **`automountServiceAccountToken: false`.** The app never calls the Kubernetes API, so it
  gets no credentials to leak.
- **Image tag = git SHA, never `latest`.** Every running pod can be traced to a commit,
  and a rollback is just a previous tag.

## Verified results (this machine, 2026-10-01)

| Check | Result |
|---|---|
| Nodes | 2/2 Ready, `v1.36.5+k3s1` |
| Pods | 2/2 Running and Ready, one per node |
| Port-forward `GET /` | `{"version":"ce87432","pod":"sampleapi-…"}` |
| In-cluster Service | 10/10 requests OK, split 5/5 across the two pods |
| Rolling restart under continuous traffic (60 s busybox loop) | **13,076 requests, 0 failures** |
| Delete a pod | Replacement Ready in ~3 s (rough, measured with kubectl) |
| Root pod in `sampleapi-dev` | Rejected by PodSecurity `restricted` |
| Cluster memory (settled) | server ~750 MiB, agent ~246 MiB, registry ~94 MiB, tools ~5 MiB: **~1.07 GiB total** |
