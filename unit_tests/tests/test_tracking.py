"""Функция 4: generate_track_number, search_shipment, update_order_status."""
import re
import pytest
from logistics_core.tracking import (generate_track_number, search_shipment,
                                     update_order_status)


@pytest.mark.positive
def test_track_number_format(seeded_rng):
    tn = generate_track_number(rng=seeded_rng)
    assert re.fullmatch(r"KZ\d{9}", tn)


@pytest.mark.positive
@pytest.mark.parametrize("cc", ["KZ", "RU", "CN", "US"])
def test_track_number_country_prefix(cc, seeded_rng):
    assert generate_track_number(cc, rng=seeded_rng).startswith(cc)


@pytest.mark.edge
def test_track_number_length_is_11(seeded_rng):
    assert len(generate_track_number(rng=seeded_rng)) == 11


@pytest.mark.edge
def test_track_numbers_are_mostly_unique():
    numbers = {generate_track_number() for _ in range(500)}
    assert len(numbers) > 490


@pytest.mark.positive
@pytest.mark.parametrize("query", ["KZ123456789", "kz123456789", "Kz123456789"])
def test_search_case_insensitive(shipments, query):
    assert search_shipment(shipments, query)["status"] == "accepted"


@pytest.mark.negative
@pytest.mark.parametrize("query", ["", "KZ000000000", "KZ12345678"])
def test_search_not_found(shipments, query):
    assert search_shipment(shipments, query) is None


@pytest.mark.positive
def test_status_delivered_sets_timestamp():
    assert update_order_status({}, "delivered") == {"status": "delivered", "deliveredAt": True}


@pytest.mark.positive
@pytest.mark.parametrize("st", ["accepted", "inTransit", "atCustoms"])
def test_status_other_has_no_timestamp(st):
    assert update_order_status({}, st) == {"status": st}
