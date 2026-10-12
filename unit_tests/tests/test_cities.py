"""Функция 5: поиск и проверка городов, маршруты."""
import pytest
from logistics_core import cities


@pytest.mark.positive
@pytest.mark.parametrize("name", ["Almaty", "Алматы", "almaty", "МОСКВА", "Мәскеу", "Усть-Каменогорск"])
def test_is_valid_known_names(name):
    assert cities.is_valid(name)


@pytest.mark.negative
@pytest.mark.parametrize("name", ["", "Paris", "Alma", "12345"])
def test_is_valid_unknown(name):
    assert not cities.is_valid(name)


@pytest.mark.negative
@pytest.mark.parametrize("name", [" Almaty", "Almaty ", "  Астана  "])
def test_city_name_with_spaces_is_accepted(name):
    """DEFECT-03: пробелы по краям (частая ошибка ввода) не должны ломать поиск города."""
    assert cities.is_valid(name)


@pytest.mark.positive
def test_search_substring_in_all_languages():
    assert {c[2] for c in cities.search("alma")} == {"Almaty"}
    assert any(c[2] == "Aktobe" for c in cities.search("акт"))
    assert len(cities.search("a")) > 10


@pytest.mark.edge
def test_search_empty_query_returns_empty():
    assert cities.search("") == []


@pytest.mark.negative
def test_search_no_match():
    assert cities.search("zzzz") == []


@pytest.mark.positive
def test_get_coordinate_almaty():
    lat, lon = cities.get_coordinate("Almaty")
    assert lat == pytest.approx(43.2380) and lon == pytest.approx(76.8829)


@pytest.mark.negative
def test_get_coordinate_unknown_is_none():
    assert cities.get_coordinate("Gotham") is None


@pytest.mark.positive
def test_parse_route_ok():
    a, b = cities.parse_route("Алматы → Астана")
    assert a == (43.2380, 76.8829) and b == (51.1694, 71.4491)


@pytest.mark.negative
@pytest.mark.parametrize("route", ["Алматы", "Алматы → Астана → Шымкент", "Алматы → Gotham", ""])
def test_parse_route_invalid(route):
    assert cities.parse_route(route) is None


@pytest.mark.edge
def test_database_has_no_duplicate_english_names():
    names = [c[2].lower() for c in cities.CITIES]
    assert len(names) == len(set(names))
