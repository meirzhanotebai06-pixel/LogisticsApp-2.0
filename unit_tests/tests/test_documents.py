"""Функция 6: сроки документов водителя."""
from datetime import timedelta
import pytest
from logistics_core.documents import (are_all_documents_valid, days_until_expiry,
                                      expiring_documents, is_expired)


@pytest.mark.positive
@pytest.mark.parametrize("days", [1, 10, 30, 365])
def test_days_until_expiry(now, days):
    assert days_until_expiry(now + timedelta(days=days, hours=3), now) == days


@pytest.mark.edge
def test_is_expired_boundary(now):
    assert is_expired(now - timedelta(seconds=1), now)
    assert not is_expired(now + timedelta(seconds=1), now)


@pytest.mark.positive
def test_all_valid(valid_documents, now):
    assert are_all_documents_valid(valid_documents, now)


@pytest.mark.negative
def test_one_expired_makes_invalid(valid_documents, now):
    valid_documents["insurance"] = now - timedelta(days=1)
    assert not are_all_documents_valid(valid_documents, now)


@pytest.mark.negative
@pytest.mark.parametrize("missing", ["insurance", "driverLicense", "vehicleRegistration", "technicalInspection"])
def test_missing_document_makes_invalid(valid_documents, now, missing):
    valid_documents.pop(missing)
    assert not are_all_documents_valid(valid_documents, now)


@pytest.mark.negative
@pytest.mark.parametrize("docs", [None, {}])
def test_no_documents_invalid(docs, now):
    assert not are_all_documents_valid(docs, now)


@pytest.mark.positive
def test_expiring_soon_detected(valid_documents, now):
    valid_documents["driverLicense"] = now + timedelta(days=10)
    valid_documents["technicalInspection"] = now + timedelta(days=30)
    assert expiring_documents(valid_documents, now) == ["Жүргізуші куәлігі", "Техосмотр"]


@pytest.mark.edge
def test_expiring_excludes_already_expired(valid_documents, now):
    valid_documents["insurance"] = now - timedelta(days=2)
    assert expiring_documents(valid_documents, now) == []


@pytest.mark.edge
def test_expiring_boundary_31_days_not_listed(valid_documents, now):
    valid_documents["insurance"] = now + timedelta(days=31, hours=1)
    assert expiring_documents(valid_documents, now) == []
