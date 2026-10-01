# Phase 1: Sample app, Docker and tests

## What was built

A FastAPI service (`app/`) that gives the platform something worth deploying. It exposes
health probes, Prometheus metrics, a CPU-heavy endpoint and a small CRUD resource, and it
ships as a multi-stage, non-root container image.

## File-by-file

| File | What and why |
|---|---|
| `src/sampleapi/main.py` | App factory (`create_app`) with all routes. The factory lets tests build isolated apps with custom settings |
| `src/sampleapi/config.py` | Reads settings from env vars (12-factor), so one image runs in compose, k3d and CI |
| `src/sampleapi/metrics.py` | Prometheus RED metrics and the middleware that records them. Labels use the route template, not the raw path, to bound cardinality |
| `src/sampleapi/logging_setup.py` | One JSON object per log line on stdout, so Loki can filter by field. Also reroutes uvicorn's logs into the same format |
| `src/sampleapi/items.py` | In-memory CRUD with a lock (sync endpoints run in a thread pool). Per-pod state makes pod kills visible |
| `tests/` | 29 pytest tests: probe semantics, per-route metric and log labels, `/work` correctness and bounds, CRUD and validation |
| `requirements.txt` | Pinned runtime dependencies, so builds are reproducible |
| `requirements-dev.txt` | Test and lint tools layered on the runtime dependencies (`-r`) |
| `pyproject.toml` | pytest (src path, coverage) and ruff (lint and format) configuration |
| `Dockerfile` | Two stages: the builder installs dependencies into a venv, and the runtime copies only the venv and code. Pinned base image, non-root UID 10001, exec-form CMD |
| `.dockerignore` | Keeps tests, the venv and caches out of the build context and image |
| `docker-compose.yml` | Local run with a read-only filesystem, all capabilities dropped and memory/CPU limits, mirroring the Kubernetes security context |

## Interview talking points

- **Liveness vs. readiness.** If liveness fails, the container is restarted. If readiness
  fails, the pod only stops receiving traffic. Liveness deliberately checks no dependencies:
  if a database outage failed liveness, every pod would restart in a loop.
- **Graceful shutdown.** On SIGTERM, readiness switches to "not ready" before the app
  exits, and uvicorn runs as PID 1 (exec-form CMD) so it actually receives the signal.
- **Why `def` instead of `async def` for `/work`.** CPU-bound code in an `async` handler
  blocks the event loop, so health probes would time out and Kubernetes would kill a pod
  that is merely busy. A plain `def` handler runs in a thread pool.
- **Metric cardinality.** Labelling by raw path (`/items/1`, `/items/2`, …) would create
  one time series per ID and could exhaust Prometheus memory.
- **Multi-stage build.** The runtime image contains no pip cache or build tooling: a
  smaller attack surface and faster pulls.
- **Numeric `USER`.** Kubernetes `runAsNonRoot` can only verify a numeric UID.
- **One worker per container.** We scale by adding pods (HPA), not uvicorn workers.
  That keeps each pod's metrics simple and its resource use predictable.

## Verified results (from this machine, 2026-10-01)

- `pytest`: 29 passed, 99% coverage, no warnings
- `ruff check` and `ruff format --check`: clean
- Container: `healthy`, runs as `uid=10001`, root filesystem read-only
- Image `sampleapi:local`: 218 MB. Idle memory: ~39 MiB
- `/work?iterations=100000`: ~44 ms in the container
