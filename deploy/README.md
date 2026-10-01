# deploy/

Kustomize manifests for the sample app. **ArgoCD watches this folder**: a change merged here
is a deployment. `base/` holds the shared resources; `overlays/` holds per-environment patches.

_Filled in Phase 2 (manifests) and Phase 4 (ArgoCD Applications)._
