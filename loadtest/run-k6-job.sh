#!/usr/bin/env bash
# Run the shared k6 scenario as a Job inside a cluster and save the results as JSON.
#
#   loadtest/run-k6-job.sh --env local --app-namespace sampleapi-dev
#   loadtest/run-k6-job.sh --env azure --app-namespace sampleapi-cloud --context minipaas-azure
#
# Options: --step 60s (duration per load step), --iterations 20000 (CPU per request),
#          --context <kube-context>, --out-dir loadtest/results
# Writes loadtest/results/<env>-<UTC timestamp>.json: environment metadata + k6 summary.
set -euo pipefail

ENV_NAME="" APP_NS="" CONTEXT="" STEP="60s" ITERATIONS="20000" OUT_DIR="loadtest/results"
while [ $# -gt 0 ]; do
  case "$1" in
    --env) ENV_NAME="$2"; shift 2 ;;
    --app-namespace) APP_NS="$2"; shift 2 ;;
    --context) CONTEXT="$2"; shift 2 ;;
    --step) STEP="$2"; shift 2 ;;
    --iterations) ITERATIONS="$2"; shift 2 ;;
    --out-dir) OUT_DIR="$2"; shift 2 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done
[ -n "$ENV_NAME" ] && [ -n "$APP_NS" ] || { echo "usage: $0 --env NAME --app-namespace NS [--context CTX]" >&2; exit 2; }

cd "$(dirname "$0")/.."   # repo root, so relative paths work on Windows Python too
K=(kubectl); [ -n "$CONTEXT" ] && K+=(--context "$CONTEXT")
PY=python3; "$PY" -c 1 >/dev/null 2>&1 || PY=python
TARGET="http://sampleapi.${APP_NS}.svc"
STAMP=$(date -u +%Y%m%dT%H%M%SZ)
WORK="$OUT_DIR/.work-$STAMP"; mkdir -p "$WORK"
trap 'rm -rf "$WORK"' EXIT

echo "==> Environment snapshot"
"${K[@]}" get nodes -o json > "$WORK/nodes.json"
"${K[@]}" -n "$APP_NS" get deploy sampleapi -o json > "$WORK/deploy.json"
"${K[@]}" -n "$APP_NS" get pods -l app.kubernetes.io/name=sampleapi -o json > "$WORK/pods-before.json"

echo "==> Starting k6 Job against $TARGET (3 steps x $STEP)"
"${K[@]}" apply -f loadtest/k6/namespace.yaml >/dev/null
"${K[@]}" -n loadtest create configmap k6-scenario --from-file=scenario.js=loadtest/k6/scenario.js \
  --dry-run=client -o yaml | "${K[@]}" apply -f - >/dev/null
"${K[@]}" -n loadtest delete job k6-run --ignore-not-found --wait=true >/dev/null
sed -e "s|__TARGET__|$TARGET|" -e "s|__WORK_ITERATIONS__|$ITERATIONS|" -e "s|__STEP_DURATION__|$STEP|" \
  loadtest/k6/job.yaml | "${K[@]}" apply -f - >/dev/null

step_s=${STEP%s}
deadline=$(( $(date +%s) + 3 * step_s + 300 ))
while :; do
  status=$("${K[@]}" -n loadtest get job k6-run -o jsonpath='{.status.succeeded}/{.status.failed}')
  case "$status" in
    1/*) echo "==> k6 Job completed"; break ;;
    */1) echo "!! k6 Job failed" >&2; "${K[@]}" -n loadtest logs job/k6-run --tail=40 >&2 || true; exit 1 ;;
  esac
  [ "$(date +%s)" -lt "$deadline" ] || { echo "!! timed out waiting for k6" >&2; exit 1; }
  sleep 5
done

"${K[@]}" -n loadtest logs job/k6-run > "$WORK/k6.log"
"${K[@]}" -n "$APP_NS" get pods -l app.kubernetes.io/name=sampleapi -o json > "$WORK/pods-after.json"

mkdir -p "$OUT_DIR"
OUT="$OUT_DIR/${ENV_NAME}-${STAMP}.json"
"$PY" - "$WORK" "$OUT" "$ENV_NAME" "${CONTEXT:-current}" "$STAMP" <<'PYEOF'
import json, re, sys, pathlib
work, out, env, ctx, stamp = sys.argv[1:]
w = pathlib.Path(work)
log = (w / "k6.log").read_text(encoding="utf-8")
m = re.search(r"===K6_SUMMARY_JSON_BEGIN===\s*(\{.*\})\s*===K6_SUMMARY_JSON_END===", log, re.S)
if not m:
    sys.exit("k6 summary markers not found in Job logs")
k6 = json.loads(m.group(1))
# k6's per-scenario "rate" is averaged over the whole test, not the step, so derive the
# achieved throughput of each step from its request count instead.
step_s = int(str(k6["step_duration"]).rstrip("s"))
for s in k6["steps"]:
    s["achieved_rps"] = round((s["requests"] or {}).get("count", 0) / step_s, 1)
nodes = json.loads((w / "nodes.json").read_text())["items"]
dep = json.loads((w / "deploy.json").read_text())
c = dep["spec"]["template"]["spec"]["containers"][0]
def restarts(f):
    return sum(cs.get("restartCount", 0) for p in json.loads((w / f).read_text())["items"]
               for cs in p["status"].get("containerStatuses", []))
result = {
    "environment": env,
    "kube_context": ctx,
    "timestamp_utc": stamp,
    "cluster": {
        "nodes": [{
            "name": n["metadata"]["name"],
            "arch": n["status"]["nodeInfo"]["architecture"],
            "kubelet": n["status"]["nodeInfo"]["kubeletVersion"],
            "os_image": n["status"]["nodeInfo"]["osImage"],
            "cpu_capacity": n["status"]["capacity"]["cpu"],
            "memory_capacity": n["status"]["capacity"]["memory"],
        } for n in nodes],
    },
    "app": {
        "namespace": dep["metadata"]["namespace"],
        "image": c["image"],
        "replicas": dep["spec"]["replicas"],
        "resources": c.get("resources", {}),
        "container_restarts_during_test": restarts("pods-after.json") - restarts("pods-before.json"),
    },
    "k6": k6,
}
pathlib.Path(out).write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
print(f"==> Saved {out}")
print(f"{'target rps':>10} {'achieved':>9} {'p50 ms':>8} {'p95 ms':>8} {'p99 ms':>8} {'failed':>7} {'dropped':>8}")
for s in k6["steps"]:
    req, lat = s["requests"] or {}, s["latency_ms"] or {}
    print(f"{s['target_rps']:>10} {s['achieved_rps']:>9.1f} {lat.get('med', 0):>8.1f} {lat.get('p95', 0):>8.1f} "
          f"{lat.get('p99', 0):>8.1f} {100 * (s['failed_rate'] or 0):>6.2f}% {s['dropped_iterations']:>8}")
print(f"replicas={result['app']['replicas']} restarts_during_test={result['app']['container_restarts_during_test']} "
      f"nodes={len(nodes)} cpu={[n['cpu_capacity'] for n in result['cluster']['nodes']]}")
PYEOF
