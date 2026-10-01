def test_metrics_exposed_in_prometheus_format(client):
    client.get("/")
    r = client.get("/metrics")
    assert r.status_code == 200
    assert r.headers["content-type"].startswith("text/plain")
    assert "http_requests_total" in r.text
    assert 'app_info{version="test"} 1.0' in r.text


def test_metrics_use_route_template_not_raw_path(client):
    client.get("/items/12345")
    body = client.get("/metrics").text
    assert 'route="/items/{item_id}"' in body
    assert "/items/12345" not in body


def test_unknown_paths_share_one_label(client):
    client.get("/does-not-exist")
    assert 'route="unmatched",status="404"' in client.get("/metrics").text


def test_request_id_is_echoed_or_generated(client):
    assert client.get("/", headers={"x-request-id": "abc"}).headers["x-request-id"] == "abc"
    assert len(client.get("/").headers["x-request-id"]) == 32
