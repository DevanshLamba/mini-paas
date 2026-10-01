import pytest
from fastapi.testclient import TestClient

from sampleapi.config import Settings
from sampleapi.main import create_app


@pytest.fixture
def make_client():
    """Build a client for an app with custom settings; `with` runs startup/shutdown."""

    def _make(**overrides) -> TestClient:
        settings = Settings(version="test", pod_name="test-pod", **overrides)
        return TestClient(create_app(settings))

    return _make


@pytest.fixture
def client(make_client):
    with make_client() as c:
        yield c
