"""A small in-memory CRUD resource, so the app behaves like a real REST API.

State lives in each pod's memory on purpose: it is lost on restart and not shared
between replicas. That makes the effect of pod kills visible in the chaos tests.
A real service would use a database.
"""

import threading

from fastapi import APIRouter, HTTPException, Request, status
from pydantic import BaseModel, Field


class ItemIn(BaseModel):
    name: str = Field(min_length=1, max_length=100)
    price: float = Field(ge=0)


class Item(ItemIn):
    id: int


class ItemStore:
    def __init__(self) -> None:
        self._items: dict[int, Item] = {}
        self._next_id = 1
        self._lock = threading.Lock()  # sync endpoints run in a thread pool

    def list(self) -> list[Item]:
        with self._lock:
            return list(self._items.values())

    def get(self, item_id: int) -> Item | None:
        with self._lock:
            return self._items.get(item_id)

    def create(self, data: ItemIn) -> Item:
        with self._lock:
            item = Item(id=self._next_id, **data.model_dump())
            self._items[item.id] = item
            self._next_id += 1
            return item

    def delete(self, item_id: int) -> bool:
        with self._lock:
            return self._items.pop(item_id, None) is not None


router = APIRouter(prefix="/items", tags=["items"])


def _store(request: Request) -> ItemStore:
    return request.app.state.items


@router.get("")
def list_items(request: Request) -> list[Item]:
    return _store(request).list()


@router.post("", status_code=status.HTTP_201_CREATED)
def create_item(data: ItemIn, request: Request) -> Item:
    return _store(request).create(data)


@router.get("/{item_id}")
def get_item(item_id: int, request: Request) -> Item:
    item = _store(request).get(item_id)
    if item is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "item not found")
    return item


@router.delete("/{item_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_item(item_id: int, request: Request) -> None:
    if not _store(request).delete(item_id):
        raise HTTPException(status.HTTP_404_NOT_FOUND, "item not found")
