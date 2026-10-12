import random
from datetime import datetime, timedelta

import pytest

NOW = datetime(2026, 10, 12, 12, 0, 0)


@pytest.fixture
def now():
    return NOW


@pytest.fixture
def valid_documents(now):
    """Все 4 документа водителя действуют ещё > 30 дней."""
    far = now + timedelta(days=365)
    return {"insurance": far, "driverLicense": far,
            "vehicleRegistration": far, "technicalInspection": far}


@pytest.fixture
def seeded_rng():
    return random.Random(42)


@pytest.fixture
def shipments():
    return [{"trackNumber": "KZ123456789", "status": "accepted"},
            {"trackNumber": "RU987654321", "status": "inTransit"}]
