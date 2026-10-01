import logging

import pytest
from prometheus_client import REGISTRY


class _Collect(logging.Handler):
    def __init__(self) -> None:
        super().__init__()
        self.records: list[logging.LogRecord] = []

    def emit(self, record: logging.LogRecord) -> None:
        self.records.append(record)


@pytest.fixture
def access_log():
    # Attach directly to our logger: create_app() resets root handlers, which would
    # detach pytest's caplog.
    handler = _Collect()
    logger = logging.getLogger("sampleapi.access")
    logger.addHandler(handler)
    yield handler.records
    logger.removeHandler(handler)


def _count(method: str, route: str, status: int) -> float:
    labels = {"method": method, "route": route, "status": str(status)}
    return REGISTRY.get_sample_value("http_requests_total", labels) or 0.0


@pytest.mark.parametrize(
    ("method", "path", "route", "status", "logged"),
    [
        ("GET", "/health", "/health", 200, False),
        ("GET", "/ready", "/ready", 200, False),
        ("GET", "/items", "/items", 200, True),
        ("POST", "/items", "/items", 201, True),
        ("GET", "/items/1", "/items/{item_id}", 200, True),
        ("GET", "/items/999", "/items/{item_id}", 404, True),
        # Plain Starlette routes and method mismatches: previously labelled "unmatched".
        ("GET", "/docs", "/docs", 200, True),
        ("GET", "/openapi.json", "/openapi.json", 200, True),
        ("PUT", "/items", "/items", 405, True),
        ("GET", "/no-such-path", "unmatched", 404, True),
    ],
)
def test_route_label(client, access_log, method, path, route, status, logged):
    client.post("/items", json={"name": "seed", "price": 1})  # so /items/1 exists
    access_log.clear()
    before = _count(method, route, status)

    kwargs = {"json": {"name": "x", "price": 1}} if method == "POST" else {}
    assert client.request(method, path, **kwargs).status_code == status

    assert _count(method, route, status) == before + 1
    logged_routes = [(r.fields["route"], r.fields["status"]) for r in access_log]
    assert logged_routes == ([(route, status)] if logged else [])
