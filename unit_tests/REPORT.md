# Практическая работа №6 — Unit Testing и автоматизированное тестирование

**Проект:** LogisticsApp (iOS, SwiftUI + Firebase) — https://github.com/meirzhanotebai06-pixel/LogisticsApp
**Инструменты:** Python 3.12, pytest 8, pytest-cov

## 1. Постановка и подход

LogisticsApp написан на Swift и тесно связан с Firebase/MapKit, поэтому pytest напрямую его код запускать не может. Чистая бизнес-логика (без UI и сети) перенесена на Python **1:1** в пакет `logistics_core/`, и именно она покрыта unit-тестами. Соответствие модулей исходникам:

| Python-модуль | Swift-оригинал | Что тестируется |
|---|---|---|
| `validators.py` | `Services/AuthService.swift` | `validateEmailDetailed`, `isValidPassword`, `isValidPhone`, `isValidName`; проверка веса (`NewOrderView.isFormValid`) |
| `pricing.py` | `Views/NewOrderView.swift`, `Models.swift` | `TariffType.basePrice`, `calculateTotalPrice`, форматирование цены |
| `tracking.py` | `Services/OrderService.swift`, `TrackingService.swift` | `generateTrackNumber`, `searchShipment`, `updateOrderStatus` |
| `cities.py` | `Models/Cities.swift` | `search`, `isValid`, `getCity`, `getCoordinate`, разбор маршрута «A → B» |
| `documents.py` | `Models.swift`, `Services/VehicleService.swift` | `daysUntilExpiry`, `isExpired`, `checkExpiringDocuments`, `areAllDocumentsValid` |

## 2. Структура

```
unit_tests_lab6/
├── logistics_core/          # тестируемые модули (5 групп функций + документы)
├── tests/
│   ├── conftest.py          # fixtures: now, valid_documents, seeded_rng, shipments
│   ├── test_validators.py   # 70 тестов
│   ├── test_pricing.py      # 20
│   ├── test_tracking.py     # 17
│   ├── test_cities.py       # 24
│   └── test_documents.py    # 16
├── pytest.ini, requirements.txt
└── reports/                 # логи запусков и HTML-отчёт покрытия
```

Запуск: `pip install -r requirements.txt && pytest` и `pytest --cov=logistics_core --cov-branch --cov-report=term-missing`.

## 3. Использованные приёмы (по заданию)

| Требование | Реализация |
|---|---|
| Positive Test | маркер `@pytest.mark.positive`, напр. `test_email_valid`, `test_total_price_with_extras` |
| Negative Test | `@pytest.mark.negative`, напр. `test_email_invalid_returns_message`, `test_search_not_found` |
| Edge Case | `@pytest.mark.edge`: длина email 100/101, имя 1/2/50/51 символов, граница 30/31 день для документов |
| Exception Test | `pytest.raises(KeyError)` в `test_unknown_tariff_raises` (`""`, `"premium"`, `"EXPRESS"`, `None`) |
| `assert` | во всех тестах |
| Parametrization | `@pytest.mark.parametrize` — большинство тестов |
| Fixture | `conftest.py`: `now`, `valid_documents`, `seeded_rng`, `shipments` |
| Test Suite | запуск всего каталога `tests/`; выборочно по маркерам: `pytest -m negative` |

## 4. Результаты

**Первый запуск (до исправлений): 143 теста — 131 passed, 12 failed** (`reports/01_run_before_fix.txt`).
**После исправления + 4 доп. теста: 147 тестов — 147 passed** (`reports/02_run_after_fix.txt`).

### Найденные дефекты

| ID | Модуль / Swift-оригинал | Описание | Severity | Падавшие тесты |
|---|---|---|---|---|
| DEFECT-01 | `isValidPhone` (AuthService) | Функция удаляет все нецифровые символы и считает цифры, поэтому `abc77001234567` или `7700123456x7` признаются корректным телефоном | Medium | 3 |
| DEFECT-02 | `isFormValid` (NewOrderView): `Double(weight) != nil` | Принимает вес `0`, `-5`, `nan`, `inf` — можно создать заказ с отрицательным/бесконечным весом | High | 6 |
| DEFECT-03 | `CitiesDatabase.getCity/isValid` | Название города не обрезается по пробелам: `" Almaty"` или `"Астана "` считаются несуществующими, форма заказа отвергает корректный адрес | Low | 3 |

### Исправления (Symptom → Cause → Fix → Retest)

1. **DEFECT-01.** Симптом: номер с буквами проходит проверку. Причина: подсчёт цифр без проверки остальных символов. Исправление: допускаются только цифры и разделители `+ ( ) - пробел`, затем проверка «ровно 11 цифр». Retest: 3 теста → passed.
2. **DEFECT-02.** Симптом: вес `-5`/`nan` принимается. Причина: проверка только «строка парсится в число». Исправление: `math.isfinite(value) and value > 0`. Retest: 6 тестов → passed.
3. **DEFECT-03.** Симптом: город с пробелом не найден. Причина: нет `strip()`. Исправление: `name.strip().lower()`. Retest: 3 теста → passed.

**Рекомендуемые правки в Swift-коде** (в самом репозитории не вносились, так как в моём окружении нет компилятора Swift и проверить сборку нельзя):

```swift
// NewOrderView.isFormValid
Double(weight).map { $0.isFinite && $0 > 0 } == true

// AuthService.isValidPhone
guard phone.range(of: "^[0-9+()\\-\\s]+$", options: .regularExpression) != nil else { return false }

// CitiesDatabase: в getCity / isValid / search
let name = name.trimmingCharacters(in: .whitespaces)
```

## 5. Code Coverage (pytest-cov, с учётом ветвей)

| Модуль | Stmts | Branch | Cover |
|---|---|---|---|
| cities.py | 20 | 4 | 100% |
| documents.py | 20 | 6 | 100% |
| pricing.py | 14 | 4 | 100% |
| tracking.py | 15 | 6 | 100% |
| validators.py | 61 | 40 | 100% |
| **Итого** | **130** | **60** | **100%** |

Первоначально покрытие было 96% (validators.py: 92%, не хватало проверок сегментов домена в email); добавлены 4 теста — `user@gmail.com-`, `user@mail.-gmail.com`, `user@gmail-.com`, `user@gm--ail.com`. HTML-отчёт: `reports/htmlcov/index.html`.

## 6. Вывод

Автоматизированный набор из 147 unit-тестов выявил 3 дефекта логики валидации и поиска, включая один высокой серьёзности (некорректный вес посылки). Покрытие строк и ветвей — 100%. Важно: 100% coverage не означает отсутствия ошибок — оно показывает лишь, что каждая строка выполнялась; корректность определяют проверки (assert). Сбой Firebase, UI и MapKit данным набором не проверяется — для них нужны интеграционные и UI-тесты (XCTest). Следующий шаг — подключить `pytest` к CI (GitHub Actions) и портировать тесты в XCTest для Swift-кода.

## 7. Ответы на контрольные вопросы (кратко)

1. **Unit Testing** — проверка отдельного модуля/функции изолированно от остальной системы.
2. **pytest** — фреймворк тестирования Python; **unittest** — встроенный xUnit-фреймворк стандартной библиотеки.
3. **assert** — проверка условия; при ложном значении тест падает.
4. **Fixture** — подготовленные данные/окружение, переиспользуемые тестами (`@pytest.fixture`).
5. **Parametrization** — один тест на множество наборов входных данных.
6. **Mock** — подменный объект, имитирующий зависимость (например, Firebase) в изолированном тесте.
7. **Exception Testing** — проверка, что код выбрасывает ожидаемое исключение (`pytest.raises`).
8. **Test Suite** — набор тестов, запускаемый вместе.
9. **Code Coverage** — доля кода (строк/ветвей), выполняемая тестами; **100% ≠ отсутствие багов**.
10. **Retest** — повторный запуск упавшего теста после исправления дефекта.
11. **Unit vs Integration** — unit проверяет один модуль изолированно, integration — взаимодействие модулей (например, приложение + Firestore).
12. **CI/CD** — `pytest --cov --cov-fail-under=80` в шаге Test workflow GitHub Actions.
