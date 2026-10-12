"""Порт generateTrackNumber (OrderService.swift) и статусов заказа."""
import random

STATUSES = ("accepted", "inTransit", "atCustoms", "delivered")


def generate_track_number(country_code: str = "KZ", rng=random) -> str:
    digits = "".join(rng.choice("0123456789") for _ in range(9))
    return f"{country_code}{digits}"


def search_shipment(shipments, track_number: str):
    """Регистронезависимый поиск по трек-номеру (TrackingService.searchShipment)."""
    for s in shipments:
        if s["trackNumber"].lower() == track_number.lower():
            return s
    return None


def update_order_status(order: dict, status: str) -> dict:
    """OrderService.updateOrderStatus: при 'delivered' ставит deliveredAt."""
    data = {"status": status}
    if status == "delivered":
        data["deliveredAt"] = True
    return data
