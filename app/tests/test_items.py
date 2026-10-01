def test_crud_lifecycle(client):
    assert client.get("/items").json() == []

    r = client.post("/items", json={"name": "widget", "price": 9.5})
    assert r.status_code == 201
    item = r.json()
    assert item == {"id": 1, "name": "widget", "price": 9.5}

    assert client.get(f"/items/{item['id']}").json() == item
    assert client.get("/items").json() == [item]

    assert client.delete(f"/items/{item['id']}").status_code == 204
    assert client.get(f"/items/{item['id']}").status_code == 404


def test_missing_item_returns_404(client):
    assert client.get("/items/999").status_code == 404
    assert client.delete("/items/999").status_code == 404


def test_validation_errors_return_422(client):
    assert client.post("/items", json={"name": "", "price": 1}).status_code == 422
    assert client.post("/items", json={"name": "x", "price": -1}).status_code == 422
    assert client.get("/items/not-a-number").status_code == 422


def test_each_app_has_its_own_store(make_client):
    with make_client() as a:
        a.post("/items", json={"name": "only-in-a", "price": 1})
    with make_client() as b:
        assert b.get("/items").json() == []
