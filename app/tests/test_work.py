import hashlib


def test_work_is_deterministic(client):
    r = client.get("/work", params={"iterations": 3})
    assert r.status_code == 200

    expected = b"mini-paas"
    for _ in range(3):
        expected = hashlib.sha256(expected).digest()
    body = r.json()
    assert body["digest"] == expected.hex()
    assert body["iterations"] == 3
    assert body["pod"] == "test-pod"


def test_work_uses_default_iterations(make_client):
    with make_client(work_default_iterations=10) as c:
        assert c.get("/work").json()["iterations"] == 10


def test_work_rejects_out_of_range(make_client):
    with make_client(work_max_iterations=100) as c:
        assert c.get("/work", params={"iterations": 101}).status_code == 422
        assert c.get("/work", params={"iterations": 0}).status_code == 422


def test_work_counts_iterations(client):
    client.get("/work", params={"iterations": 5})
    assert "work_iterations_total" in client.get("/metrics").text
