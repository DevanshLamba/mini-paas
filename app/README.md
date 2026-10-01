# sampleapi

The sample workload the Mini-PaaS builds, deploys, scales and breaks. It's a small FastAPI
service that's deliberately easy to observe.

## Endpoints

| Method | Path | Purpose |
|---|---|---|
| GET | `/` | Service name, version and pod name (shows load balancing and rollouts) |
| GET | `/health` | Liveness probe: is the process alive? |
| GET | `/ready` | Readiness probe: should it receive traffic? Returns 503 during startup and shutdown |
| GET | `/metrics` | Prometheus metrics: request count, latency histogram, in-flight requests |
| GET | `/work?iterations=N` | CPU-heavy chained SHA-256 work, used for autoscaling tests |
| GET/POST | `/items` | In-memory CRUD resource |
| GET/DELETE | `/items/{id}` | |
| POST | `/fault/unhealthy` | Makes liveness fail (only when `FAULT_INJECTION=true`) |

Interactive API docs: <http://localhost:8000/docs>

## Configuration

| Env var | Default | Meaning |
|---|---|---|
| `APP_VERSION` | `dev` | Reported in `/` and in the `app_info` metric. CI sets it to the git SHA |
| `LOG_LEVEL` | `INFO` | Python log level |
| `ACCESS_LOG` | `true` | Log one JSON line per request (probes and scrapes are skipped) |
| `WORK_DEFAULT_ITERATIONS` | `100000` | Default `/work` size (~50 ms CPU) |
| `WORK_MAX_ITERATIONS` | `2000000` | Upper bound, so one request can't hog a pod |
| `FAULT_INJECTION` | `false` | Enables `/fault/unhealthy` |
| `POD_NAME` | hostname | Injected by Kubernetes via the Downward API |

## Develop

```bash
python -m venv .venv
.venv/Scripts/activate            # Windows (Git Bash: source .venv/Scripts/activate)
pip install -r requirements-dev.txt
pytest                            # tests + coverage
ruff check . && ruff format --check .
```

## Run in Docker

```bash
docker compose up --build -d
curl localhost:8000/health
docker compose down
```
