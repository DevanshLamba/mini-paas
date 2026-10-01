"""FastAPI application: health probes, metrics, a CPU-heavy endpoint and a CRUD resource."""

import hashlib
import logging
import time
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException, Query, Request, Response, status
from prometheus_client import CONTENT_TYPE_LATEST, generate_latest

from sampleapi import items
from sampleapi.config import Settings
from sampleapi.logging_setup import configure_logging
from sampleapi.metrics import APP_INFO, WORK_ITERATIONS, metrics_middleware

log = logging.getLogger("sampleapi")


def create_app(settings: Settings | None = None) -> FastAPI:
    settings = settings or Settings.from_env()
    configure_logging(settings.log_level)

    @asynccontextmanager
    async def lifespan(app: FastAPI):
        app.state.ready = True
        log.info("startup", extra={"fields": {"version": settings.version}})
        yield
        # Fail readiness first so Kubernetes stops routing traffic while we drain.
        app.state.ready = False
        log.info("shutdown")

    app = FastAPI(title="sampleapi", version=settings.version, lifespan=lifespan)
    app.state.settings = settings
    app.state.ready = False
    app.state.healthy = True
    app.state.items = items.ItemStore()
    app.middleware("http")(metrics_middleware)
    app.include_router(items.router)
    APP_INFO.labels(settings.version).set(1)

    @app.get("/")
    def root() -> dict:
        # Returning the pod name shows load balancing and rollouts in action.
        return {"service": "sampleapi", "version": settings.version, "pod": settings.pod_name}

    @app.get("/health")
    def health(request: Request, response: Response) -> dict:
        # Liveness: "is this process stuck?" It checks no dependencies, because a
        # failing liveness probe makes Kubernetes restart the container.
        if not request.app.state.healthy:
            response.status_code = status.HTTP_500_INTERNAL_SERVER_ERROR
            return {"status": "unhealthy"}
        return {"status": "ok"}

    @app.get("/ready")
    def ready(request: Request, response: Response) -> dict:
        # Readiness: "should I receive traffic?" A failure removes the pod from the
        # Service endpoints without restarting it.
        if not request.app.state.ready:
            response.status_code = status.HTTP_503_SERVICE_UNAVAILABLE
            return {"status": "not ready"}
        return {"status": "ready"}

    @app.get("/metrics", include_in_schema=False)
    def metrics() -> Response:
        return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)

    @app.get("/work")
    def work(
        iterations: int = Query(
            default=settings.work_default_iterations, ge=1, le=settings.work_max_iterations
        ),
    ) -> dict:
        # Deliberately CPU-bound: chained SHA-256 hashing drives CPU usage up so the
        # HPA has something to react to. A plain `def` endpoint runs in FastAPI's
        # thread pool, so the event loop stays free to answer health probes.
        start = time.perf_counter()
        digest = b"mini-paas"
        for _ in range(iterations):
            digest = hashlib.sha256(digest).digest()
        WORK_ITERATIONS.inc(iterations)
        return {
            "iterations": iterations,
            "digest": digest.hex(),
            "duration_ms": round((time.perf_counter() - start) * 1000, 2),
            "pod": settings.pod_name,
        }

    @app.post("/fault/unhealthy", include_in_schema=False)
    def make_unhealthy(request: Request) -> dict:
        # Self-healing demo: make the liveness probe fail so the kubelet restarts the
        # container. Disabled unless FAULT_INJECTION=true.
        if not settings.fault_injection:
            raise HTTPException(status.HTTP_404_NOT_FOUND)
        request.app.state.healthy = False
        log.warning("fault injected: liveness will now fail")
        return {"status": "liveness will fail"}

    return app


app = create_app()
