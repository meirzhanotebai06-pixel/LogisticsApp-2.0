"""Порт TariffType и calculateTotalPrice из NewOrderView.swift."""

BASE_PRICES = {"express": 2500, "standard": 1500, "economy": 800, "international": 5000}
INSURANCE_FEE = 500
URGENT_FEE = 1000


def base_price(tariff: str) -> int:
    return BASE_PRICES[tariff]


def calculate_total_price(tariff: str, insurance: bool = False, urgent: bool = False) -> int:
    total = base_price(tariff)
    if insurance:
        total += INSURANCE_FEE
    if urgent:
        total += URGENT_FEE
    return total


def format_price(amount: int) -> str:
    """'2 500 ₸' — группировка разрядов пробелом, как NumberFormatter."""
    return f"{amount:,}".replace(",", " ") + " ₸"
