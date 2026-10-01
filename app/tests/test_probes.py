def test_root_reports_version_and_pod(client):
    assert client.get("/").json() == {"service": "sampleapi", "version": "test", "pod": "test-pod"}


def test_version_endpoint(client):
    body = client.get("/version").json()
    assert body["version"] == "test"
    assert body["pod"] == "test-pod"
    assert body["python"].startswith("3.")


def test_health_ok(client):
    r = client.get("/health")
    assert r.status_code == 200
    assert r.json() == {"status": "ok"}


def test_ready_after_startup(client):
    assert client.get("/ready").status_code == 200


def test_not_ready_before_startup(make_client):
    # Without `with`, the lifespan never runs, which is like a pod that is still starting.
    assert make_client().get("/ready").status_code == 503


def test_not_ready_after_shutdown(make_client):
    c = make_client()
    with c:
        pass
    assert c.get("/ready").status_code == 503


def test_fault_injection_disabled_by_default(client):
    assert client.post("/fault/unhealthy").status_code == 404
    assert client.get("/health").status_code == 200


def test_fault_injection_breaks_liveness(make_client):
    with make_client(fault_injection=True) as c:
        assert c.post("/fault/unhealthy").status_code == 200
        assert c.get("/health").status_code == 500
