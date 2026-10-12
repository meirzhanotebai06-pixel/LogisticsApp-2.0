"""Функция 3: calculate_total_price / format_price."""
import pytest
from logistics_core.pricing import base_price, calculate_total_price, format_price


@pytest.mark.positive
@pytest.mark.parametrize("tariff, expected", [
    ("express", 2500), ("standard", 1500), ("economy", 800), ("international", 5000)])
def test_base_prices(tariff, expected):
    assert base_price(tariff) == expected


@pytest.mark.positive
@pytest.mark.parametrize("tariff, ins, urg, expected", [
    ("standard", False, False, 1500),
    ("standard", True, False, 2000),
    ("standard", False, True, 2500),
    ("standard", True, True, 3000),
    ("international", True, True, 6500),
    ("economy", True, True, 2300),
])
def test_total_price_with_extras(tariff, ins, urg, expected):
    assert calculate_total_price(tariff, insurance=ins, urgent=urg) == expected


@pytest.mark.edge
def test_extras_are_additive():
    base = calculate_total_price("express")
    assert calculate_total_price("express", True, True) - base == 1500


@pytest.mark.negative
@pytest.mark.parametrize("bad", ["", "premium", "EXPRESS", None])
def test_unknown_tariff_raises(bad):
    with pytest.raises(KeyError):
        calculate_total_price(bad)


@pytest.mark.positive
@pytest.mark.parametrize("amount, text", [
    (800, "800 ₸"), (1500, "1 500 ₸"), (2500, "2 500 ₸"), (6500, "6 500 ₸"), (1000000, "1 000 000 ₸")])
def test_format_price(amount, text):
    assert format_price(amount) == text
