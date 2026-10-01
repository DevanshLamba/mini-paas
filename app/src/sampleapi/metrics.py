"""Prometheus metrics and the HTTP middleware that records them.

These are the RED metrics (Rate, Errors, Duration) that the Grafana dashboards,
the HPA/KEDA autoscalers and the load-test graphs are built on.
"""

import logging
import time
import uuid

from fastapi import Request, Response
from prometheus_client import Counter, Gauge, Histogram

REQUESTS = Counter(
    "http_requests_total",
    "Total HTTP requests",
    ["method", "route", "status"],
)
LATENCY = Histogram(
    "http_request_duration_seconds",
    "HTTP request latency in seconds",
    ["method", "route"],
    buckets=(0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10),
)
IN_PROGRESS = Gauge(
    "http_requests_in_progress",
    "HTTP requests currently being served",
)
WORK_ITERATIONS = Counter(
    "work_iterations_total",
    "Hash iterations performed by the CPU-heavy /work endpoint",
)
APP_INFO = Gauge("app_info", "Build information; value is always 1", ["version"])

# Probes and scrapes are high-frequency noise in the access log.
_QUIET_PATHS = {"/health", "/ready", "/metrics"}

access_logger = logging.getLogger("sampleapi.access")


def _route_template(request: Request) -> str:
    # Label with the route template ("/items/{item_id}"), not the raw path ("/items/42"),
    # so one label value per endpoint keeps Prometheus cardinality bounded.
    route = request.scope.get("route")
    return getattr(route, "path", "unmatched")


async def metrics_middleware(request: Request, call_next) -> Response:
    request_id = request.headers.get("x-request-id") or uuid.uuid4().hex
    start = time.perf_counter()
    status = 500
    IN_PROGRESS.inc()
    try:
        response = await call_next(request)
        status = response.status_code
        response.headers["x-request-id"] = request_id
        return response
    finally:
        elapsed = time.perf_counter() - start
        IN_PROGRESS.dec()
        route = _route_template(request)
        REQUESTS.labels(request.method, route, str(status)).inc()
        LATENCY.labels(request.method, route).observe(elapsed)
        if request.app.state.settings.access_log and request.url.path not in _QUIET_PATHS:
            access_logger.info(
                "request",
                extra={
                    "fields": {
                        "request_id": request_id,
                        "method": request.method,
                        "route": route,
                        "status": status,
                        "duration_ms": round(elapsed * 1000, 2),
                    }
                },
            )
