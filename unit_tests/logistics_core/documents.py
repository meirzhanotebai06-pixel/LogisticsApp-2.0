"""Порт DocumentInfo / VehicleService (проверка сроков документов водителя)."""
from datetime import datetime, timedelta


def days_until_expiry(expiry: datetime, now: datetime = None) -> int:
    """Целые дни от now до expiry (усечение к нулю, как Calendar.dateComponents)."""
    now = now or datetime.now()
    delta = expiry - now
    return int(delta.total_seconds() // 86400) if delta.total_seconds() >= 0 else -int((-delta.total_seconds()) // 86400)


def is_expired(expiry: datetime, now: datetime = None) -> bool:
    return expiry < (now or datetime.now())


def expiring_documents(documents: dict, now: datetime = None):
    """Названия документов, истекающих в ближайшие 30 дней (checkExpiringDocuments)."""
    names = {"insurance": "Сақтандыру", "driverLicense": "Жүргізуші куәлігі",
             "vehicleRegistration": "Техпаспорт", "technicalInspection": "Техосмотр"}
    result = []
    for key, title in names.items():
        expiry = documents.get(key)
        if expiry is not None and days_until_expiry(expiry, now) <= 30 and not is_expired(expiry, now):
            result.append(title)
    return result


def are_all_documents_valid(documents: dict, now: datetime = None) -> bool:
    if not documents:
        return False
    keys = ("insurance", "driverLicense", "vehicleRegistration", "technicalInspection")
    return all(documents.get(k) is not None and not is_expired(documents[k], now) for k in keys)
