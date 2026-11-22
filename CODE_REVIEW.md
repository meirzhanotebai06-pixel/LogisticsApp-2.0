# Код-ревью, аудит проблем и план развития LogisticsApp 2.0

**Дата аудита:** 2026-11-22  
**Стек:** SwiftUI, iOS (Deployment Target 18.6 / Project 26.0), Firebase (Auth, Firestore, Storage, Analytics), MapKit, CoreLocation  
**Объём кодовой базы:** ~33 файла, ~8 380 строк кода  

---

## 1. Общее резюме

**LogisticsApp 2.0** — iOS-приложение для логистики с тремя ролями пользователей: **Клиент**, **Водитель** и **Администратор**. В проекте уже заложен хороший функциональный каркас:

### Что уже сделано хорошо
- Реализована ролевая маршрутизация (`ClientMainView`, `DriverView`, `AdminDashboardView`).
- Настроены real-time подписки Firestore (`addSnapshotListener`) для заказов, профиля пользователя и списка водителей.
- Валидация регистрации/входа вынесена в отдельный переиспользуемый модуль `Services/AuthValidation.swift`.
- Реализована база городов с автодополнением на трёх языках (KZ / RU / EN) (`Models/Cities.swift`, `Views/Components/CityAutocompleteField.swift`).
- Добавлено построение маршрута во внешнем 2ГИС (`Services/TwoGISRouteService.swift`).
- Есть базовая модерация документов водителя администратором (`AdminService.swift`, `AdminDashboardView.swift`) и файл правил `firestore.rules` с защитой от самоповышения роли до `admin`.

### Главные риски сейчас
Несмотря на рабочий прототип, проект **не готов к продакшну**: в нём есть **критические баги в бизнес-логике** (техпаспорт сразу считается просроченным и блокирует верификацию; заказы со статусом `atCustoms` исчезают у водителя; поиск трек-номера не работает), **критические ошибки и уязвимости в `firestore.rules`** (правила ломают создание и чтение заказов, но при этом позволяют водителю самому подтвердить свои документы и читать чужие персональные данные), а также **значительный технический долг** (~1 500+ строк устаревшего дублирующего кода, God Views на 1000+ строк, сломанная тёмная тема и 0 тестов).

---

## 2. Критические проблемы (P0 — исправить в первую очередь)

### 2.1. Критические баги и дыры безопасности в `firestore.rules`
Файл: `LogisticsApp/firestore.rules`

1. **Создание и чтение заказов сломаны из-за отсутствующего поля `driverId`:**
   - В `firestore.rules` (строки 54, 63, 68, 78, 85) проверяется `request.resource.data.driverId == null` и `resource.data.driverId == null`.
   - При этом в `OrderService.swift` (строки 210–212) ключ `driverId` **вообще не добавляется** в словарь при `order.driverId == nil`. В Firestore Rules обращение к отсутствующему свойству вызывает ошибку вычисления и отклоняет запрос (`PERMISSION_DENIED`).
   - **Исправление:** всегда явно записывать `"driverId": NSNull()` при создании заказа и проверять в правилах `(!('driverId' in resource.data) || resource.data.driverId == null)`.

2. **Панель водителя ломается при включённых `firestore.rules`:**
   - `OrderService.listenToAllOrders()` (`Services/OrderService.swift:73-92`) запрашивает **всю** коллекцию `orders` без фильтров `whereField`.
   - В Firestore действует принцип *«Rules are not filters»*: поскольку `firestore.rules:60-63` запрещают водителю читать заказы других водителей, запрос всей коллекции целиком будет отклонён сервером.
   - **Исправление:** разделить подписку на два запроса: доступные заказы (`.whereField("status", isEqualTo: "accepted").whereField("driverId", isEqualTo: NSNull())`) и заказы текущего водителя (`.whereField("driverId", isEqualTo: driverId)`). Добавить файл `firestore.indexes.json` с составными индексами.

3. **Водитель может сам себе подтвердить документы (`isVerified = true`):**
   - `firestore.rules:23-27`: пользователь имеет право обновлять **любые** поля своего документа `users/{userId}`, если не меняет `userType`. Злоумышленник может отправить прямой запрос в Firestore и выставить себе `vehicleInfo.documents.*.isVerified = true` и `verificationStatus = "approved"` в обход администратора.
   - **Исправление:** запретить владельцу профиля менять поля `isVerified`, `verificationStatus` (кроме сброса в `"pending"` при загрузке нового документа), `verifiedAt`, `rejectionReason` или вынести статусы верификации в отдельную подколлекцию/Cloud Function.

4. **Любой пользователь (включая клиента) может читать и «принимать» чужие заказы:**
   - `firestore.rules:60-63` разрешает любому авторизованному пользователю читать все заказы без водителя (включая `clientName`, `clientPhone`, адреса).
   - `firestore.rules:67-69` разрешает **любому** авторизованному пользователю (без проверки `userType == 'driver'` и верификации документов) назначить себя `driverId` и одновременно перезаписать любые поля заказа (`weight`, `clientId`, `tariffType` и т.д.).
   - `firestore.rules:72-73` позволяет водителю менять любые поля своего заказа, а не только `status` и `deliveredAt`.
   - **Исправление:** проверять роль `driver` и верификацию документов на сервере, ограничивать изменяемые ключи через `request.resource.data.diff(resource.data).affectedKeys().hasOnly([...])`.

5. **Утечка персональных данных (PII) всех водителей:**
   - `firestore.rules:16-19`: `resource.data.userType == 'driver'` разрешает **любому** авторизованному пользователю читать полный документ любого водителя, включая ИИН (`iin`), ФИО, номера прав, VIN, техпаспорт и ссылки на файлы документов (`fileURL`).
   - **Исправление:** отделить публичный профиль водителя (имя, рейтинг, модель авто) от приватных документов (хранить документы в подколлекции `users/{uid}/privateDocuments` с доступом только для владельца и `isAdmin()`).

6. **Отсутствуют правила для Firebase Storage и открытая коллекция `notifications`:**
   - В репозитории нет `storage.rules`.
   - В `firestore.rules:105` `allow create: if request.auth != null;` для `/notifications` позволяет любому пользователю создавать уведомления для чужих `userId`.
   - В `firestore.rules:35-47` определены хелперы `isOrderClient()`, `isOrderDriver()`, `isAvailableOrder()`, но они нигде не используются.

---

### 2.2. Критический баг техпаспорта: документ просрочен сразу после сохранения
Файлы: `LogisticsApp/Views/DocumentDetailView.swift:47, 194-216`, `LogisticsApp/Views/AdminDashboardView.swift:328`, `LogisticsApp/Services/VehicleService.swift:102-105`

- В `DocumentDetailView.init` поле `_expiryDate` по умолчанию ставится в `Date()` (текущий момент).
- В `vehicleRegistrationForm()` (форма техпаспорта) **отсутствует `DatePicker` для срока действия** (что логично — у техпаспорта нет срока истечения).
- Однако при сохранении в `DocumentInfo` всё равно записывается `expiryDate = Date()`. Через секунду `document.isExpired` (`expiryDate < Date()`) становится `true`!
- **Последствия:**
  1. В `AdminDashboardView` кнопки «Подтвердить» / «Отклонить» для техпаспорта **навсегда заблокированы** (`.disabled(isUpdating || document.isExpired)`).
  2. `VehicleService.areAllDocumentsValid` **всегда возвращает `false`**, даже если админ обойдёт UI.
- **Исправление:** сделать `expiryDate: Date?` опциональным для документов без срока действия (техпаспорт), либо для `vehicleRegistration` не проверять `isExpired`.

---

### 2.3. Заказ со статусом «Кеденде» (`atCustoms`) бесследно исчезает у водителя
Файл: `LogisticsApp/Views/DriverView.swift:26-36, 1017-1019`

- В `DriverOrderDetailView` водитель может перевести заказ в статус `"atCustoms"`.
- Но фильтр `assignedOrders` проверяет только `($0.status == "inTransit" || $0.status == "accepted")`, а `completedOrders` — только `$0.status == "delivered"`.
- **Последствие:** переведя заказ в «Кеденде», водитель теряет его со всех вкладок и больше не может открыть его, чтобы перевести в «Жеткізілді».
- **Исправление:** включить `"atCustoms"` в `assignedOrders` (а лучше использовать строгий `enum OrderStatus` с вычисляемым свойством `isActive`).

---

### 2.4. Неподтверждённый водитель может принимать заказы + Race Condition
Файлы: `LogisticsApp/Views/DriverView.swift:42-46, 164-178`, `LogisticsApp/Services/OrderService.swift:144-156`

- Если документы не подтверждены, `DriverView` показывает только баннер `DocumentWarningBanner`, но **не запрещает** нажимать «Тапсырысты қабылдау».
- `OrderService.assignOrderToDriver` использует обычный `updateData(...)` без транзакции. Если два водителя одновременно нажмут «Принять заказ», второй молча перезапишет `driverId` первого.
- **Исправление:**
  1. Блокировать принятие заказов в UI + проверять верификацию на стороне Firestore Rules / Cloud Functions.
  2. Переписать `assignOrderToDriver` на `db.runTransaction { ... }` с проверкой, что `driverId == nil` и `status == "accepted"`.

---

### 2.5. Ошибки конфигурации проекта и инициализации Firebase
Файлы: `LogisticsApp.xcodeproj/project.pbxproj`, `GoogleService-Info.plist`, `LogisticsApp/LogisticsApp.swift`, `LogisticsApp/FirebaseManager.swift`

1. **Рассинхрон `PRODUCT_BUNDLE_IDENTIFIER`:**
   - `GoogleService-Info.plist:12` → `com.meirzhan.LogisticsApp`
   - `project.pbxproj:292` (Debug) → `kz.meirzhan.LogisticsApp` (**не совпадает!**)
   - `project.pbxproj:325` (Release) → `com.meirzhan.LogisticsApp`
2. **Несогласованный `IPHONEOS_DEPLOYMENT_TARGET`:**
   - Уровень проекта (`project.pbxproj:203, 261`): `26.0`.
   - Уровень таргета (`project.pbxproj:286, 319`): `18.6` (отсекает пользователей iOS 16–18.5, хотя API проекта спокойно работают с iOS 16/17).
3. **Риск крэша при старте и двойной вызов `FirebaseApp.configure()`:**
   - В `LogisticsApp.swift:24` `@StateObject private var authService = AuthService()` инициализируется при создании `App`, а `AuthService.init()` сразу обращается к `Firestore.firestore()` и `Auth.auth()` — это может выполниться **раньше**, чем `AppDelegate.didFinishLaunchingWithOptions` вызовет `FirebaseApp.configure()`.
   - В `FirebaseManager.swift:16` повторно вызывается `FirebaseApp.configure()` без проверки `FirebaseApp.app() == nil`, что вызовет краш при обращении к `FirebaseManager.shared`. Сам `FirebaseManager` при этом нигде не используется — файл следует либо удалить, либо использовать как единую точку инициализации до создания сервисов.
4. **Закоммиченный `GoogleService-Info.plist` и отсутствие Firebase App Check:**
   - Хотя iOS API Key не является секретом в классическом смысле, при незащищённых правилах Firestore любой может использовать `PROJECT_ID` и `API_KEY` из публичного репозитория. Рекомендуется подключить **Firebase App Check** и вынести конфиги для dev/prod окружений.

---

## 3. Функциональные баги и неточности (P1 — исправить в ближайшее время)

### 3.1. Поиск по трек-номеру в `ClientMainView` не работает
Файлы: `LogisticsApp/Views/ClientMainView.swift:266-275`, `LogisticsApp/Services/TrackingService.swift:163-172`

- Поиск ищет по `trackingService.shipments`, но `TrackingService` — старый локальный сервис с пустым массивом (`loadSampleData()` пустой).
- Реальные заказы создаются и хранятся в `OrderService` (Firestore).
- **Результат:** клиент **никогда** не найдёт свой заказ по трек-номеру (всегда показывается алерт «Тапсырыс табылмады»).
- **Исправление:** искать в `orderService.orders` (и/или выполнять точечный запрос в Firestore по `trackNumber` с учётом прав доступа) и открывать `ClientOrderDetailView`.

### 3.2. Итоговая цена заказа не сохраняется в Firestore
Файлы: `LogisticsApp/Views/NewOrderView.swift:214-258`, `LogisticsApp/Services/OrderService.swift:15-69`, `LogisticsApp/Views/DriverView.swift:589-599`

- На экране создания заказа рассчитывается цена (базовая ставка тарифа + 500 ₸ страховка + 1000 ₸ срочность), но в `Order` и в Firestore цена **не передаётся и не сохраняется**.
- В `ClientOrderDetailView` клиент вообще не видит стоимость своего заказа.
- В `DriverView` (`CompletedOrderCard.calculateEarnings()`) доход водителя пересчитывается хардкодом `60%` только от базового тарифа (без учёта допуслуг, веса, расстояния и возможных изменений тарифов в будущем).
- **Исправление:** добавить поля `price: Double` (или `Int`), `currency: String`, `driverEarning: Double` в модель `Order` и сохранять их (а в идеале — валидировать/считать на сервере через Cloud Function).

### 3.3. Загрузка и просмотр файлов документов не реализованы
Файлы: `LogisticsApp/Services/StorageService.swift`, `LogisticsApp/Views/DocumentDetailView.swift:285`, `LogisticsApp/Views/AdminDashboardView.swift`

- `StorageService` полностью написан, но **нигде не вызывается**.
- В `DocumentDetailView.swift:285` передаётся `fileURL: nil` — водитель не может прикрепить фото/скан документа (хотя в `VehicleInfoView.swift:2` даже есть неиспользуемый `import PhotosUI`).
- В `AdminDashboardView` администратор проверяет документы только по текстовым полям без просмотра фото/PDF.

### 3.4. Баги формы документов `DocumentDetailView` и `VehicleInfoView`
- **Ложное сообщение об успехе (`DocumentDetailView.swift:276-309`):** `saveDocument()` выставляет `isLoading = false` и `showSuccess = true` сразу синхронно, не дожидаясь результата `Task { try await vehicleService.saveDocument(...) }` в `VehicleInfoView`. При ошибке сети/Firestore пользователь видит «Сәтті сақталды!» и экран закрывается.
- **Сломанный `Picker` страховки (`DocumentDetailView.swift:50, 151-154`):** начальное значение `_insuranceType = ""`, тогда как теги пикера — `"ОСАГО"` и `"КАСКО"`. Если не переключить пикер вручную, сохраняется `nil`.
- **Отсутствие валидации реквизитов:** `canSave` проверяет только `!documentNumber.isEmpty` (`DocumentDetailView.swift:236-238`). Не проверяются длина/формат ИИН (12 цифр), VIN (17 символов), год авто, а также что `issueDate <= expiryDate` и обязательность заполнения ключевых полей.
- **Рассинхрон состояния `VehicleInfoView`:** локальный `@State private var vehicleInfo` не обновляется реактивно при изменении `authService.currentUser?.vehicleInfo` (например, когда администратор одобрил или отклонил документ в реальном времени).
- **Неправильный биндинг `.alert`:** `.alert("Қате", isPresented: .constant(errorMessage != nil))` в `DocumentDetailView.swift:135` и `VehicleInfoView.swift:106` — антипаттерн SwiftUI, нужно заменить на `Binding(get:set:)`.

### 3.5. Баги и недоработки авторизации и регистрации
Файлы: `LoginView.swift`, `RegistrationView.swift`, `AuthService.swift`, `AuthValidation.swift`

- **Мусор и опечатки в UI:**
  - `LoginView.swift:18`: `Text("# Login")` — остаток Markdown-заголовка.
  - `LoginView.swift:22`: `"Сөлем!"` вместо `"Сәлем!"`.
  - `LoginView.swift:30` и `ClientMainView.swift:42`: `"кадағалаңыз"` / `"кадағалау"` вместо `"қадағалаңыз"` / `"қадағалау"`.
  - `LoginView.swift:106-112`: отладочная кнопка `"Жүйеден шығу (тест)"` осталась в коде.
- **Бесполезный переключатель ролей на экране входа (`LoginView.swift:9, 39-43`):** `selectedUserType` (Клиент / Жүргізуші) нигде не используется при входе и только путает пользователя (тем более что есть третья роль `admin`).
- **Успешное сообщение красным цветом (`LoginView.swift:120`):** после регистрации `"Тіркелу сәтті аяқталды! Енді кіріңіз."` записывается в `errorMessage` и рендерится красным (`.foregroundColor(.red)`).
- **Нет восстановления пароля («Құпия сөзді ұмыттыңыз ба?»)** и переключателя видимости пароля.
- **Риск «осиротевшего» аккаунта (`AuthService.swift:132-180`):** если `Auth.auth().createUser` прошёл успешно, а `saveUserToFirestore` упал, пользователь остаётся в Firebase Auth без документа в Firestore и не может ни повторно зарегистрироваться, ни войти. Нужно либо удалять Firebase-пользователя при ошибке записи, либо создавать профиль при первом входе.
- **Гонка состояний при `forceLogoutAfterRegistration`:** после `createUser` сразу срабатывает `authStateHandle`, запускает `fetchUserData` на ещё не созданный документ, затем `forceLogoutAfterRegistration()` делает `signOut()`, а потом пароль в открытом виде передаётся колбэком обратно в `LoginView`. Лучше авторизовывать пользователя сразу после успешного сохранения профиля (и опционально отправлять `sendEmailVerification`).
- **Слишком жёсткое правило пароля (`AuthValidation.swift:118-122`):** `^[a-zA-Z0-9]+$` запрещает спецсимволы (включая дефисы из iCloud Keychain AutoFill) и проверяется даже при `login`, что может заблокировать вход пользователю с надёжным паролем.
- **Неточное форматирование телефона (`RegistrationView.swift:165, 180`):** `"+7\(phone.dropFirst(1))"` молча заменяет первую цифру на `+7`, даже если пользователь ввёл некорректный префикс, а `isValidPhone` в `AuthValidation` не проверяет формат Казахстана (`+7 7XX...`).
- **Лишняя запись в несуществующую коллекцию `test` при каждом старте (`AuthService.swift:20, 273-284`):** `checkFirebaseConnection()` пытается писать в `test/connection`, что всегда падает с ошибкой прав и создаёт лишний сетевой трафик.

### 3.6. Нерабочие кнопки, заглушки и логические неточности в UI
- `ClientMainView.swift:175-177`: кнопка `"Барлығын көру (\(completedOrders.count))"` ничего не делает — историю свыше 3 завершённых заказов нельзя открыть.
- `ClientMainView.swift:200-205` и `DriverView.swift:118-120`: пункты меню `"Жеке кабинет"` и `"Баптаулар"` — пустые замыкания.
- `TariffsView.swift:143-146`: кнопка `"Таңдау"` делает только `print(...)` и не передаёт выбранный тариф в `NewOrderView`.
- `NewOrderView.swift:207-212`: можно создать заказ с одинаковыми городами (`Алматы → Алматы`) — нет проверки `fromAddress != toAddress`.
- `NewOrderView.swift:265-267`: очистка формы через `DispatchQueue.main.asyncAfter(deadline: .now() + 2)` срабатывает по таймеру, пока открыт алерт — это может сбросить `selectedTariff` прямо в тексте открытого алерта!
- `DriverView.swift:13, 226`: тумблер `isOnDuty` («Жұмыс режимінде» / «Демалыста») существует только локально в `@State`, сбрасывается при перезапуске, не сохраняется в Firestore и никак не влияет на доступность заказов.
- `ClientMainView.swift:236-240`: `.sheet(isPresented: $showRouteMap)` с проверкой `if let order = selectedOrderForMap` — классический баг SwiftUI, при котором первое открытие sheet может оказаться пустым. Следует использовать `.sheet(item: $selectedOrderForMap)`.
- `DriverView.swift:10-11` и `ClientMainView.swift:17-18`: объявлена неиспользуемая переменная `showOrderDetail`.

### 3.7. Проблемы карт, геолокации и внешних ссылок
- **Захардкоженная геолокация водителя (`DriverView.swift:12`):** `driverLocation` всегда равен координатам Алматы (`43.2380, 76.8829`), `CLLocationManager` не подключён.
- **Нет линии маршрута на карте:** в `RouteMapView`, `OrderRouteMapView` и `DriverMapViewNew` отображаются только маркеры городов без `MapPolyline` / `MKDirections`.
- **Мерцание пинов на карте:** `RouteAnnotation`, `RouteAnnotationItem`, `DriverMapAnnotationNew` генерируют `let id = UUID()` внутри вычисляемых свойств (`routeAnnotations`, `mapAnnotations`). При каждом обновлении SwiftUI View пины пересоздаются заново.
- **Чувствительный к регистру поиск координат:** `OrderRouteMapView.swift:503-504` и `DriverView.swift:695` обращаются к `cityCoordinates[address]` напрямую вместо `CitiesDatabase.getCoordinate(cityName:)`.
- **Отсутствие `Info.plist` ключей:** нет `NSLocationWhenInUseUsageDescription` (потребуется для GPS) и `LSApplicationQueriesSchemes` (для корректной проверки `canOpenURL` для WhatsApp / 2ГИС / звонков).
- **Ошибки обработки номеров в `tel://`:** в `ContactCourierView.swift:160` и `DriverShipmentDetailView.swift:404` удаляется знак `+` (`tel://77771234567`), что может ломать набор международных номеров на iOS.

### 3.8. Полностью сломанная тёмная тема (Dark Mode)
Почти на всех экранах (`ClientMainView`, `DriverView`, `AdminDashboardView`, `VehicleInfoView`, `MapView`, `TariffsView`, `CityAutocompleteField`, `Components`, `ShipmentDetailView`, `DriverShipmentDetailView`) для фонов карточек зашит жёсткий `.background(Color.white)`, при этом текст использует системный `.primary` (который в Dark Mode становится белым).  
**Результат:** в тёмной теме iOS карточки остаются белыми с белым текстом — интерфейс нечитаем.  
**Исправление:** заменить `Color.white` на `Color(.secondarySystemGroupedBackground)` или `Color(.systemBackground)`.

---

## 4. Архитектурные проблемы и качество кода (P2)

### 4.1. Два параллельных слоя данных и ~1 500+ строк мёртвого кода
В проекте остались следы предыдущей версии (локальные моки) рядом с новой (Firebase):

| Устаревший слой (не связан с Firebase) | Новый слой (Firebase) |
|---|---|
| `TrackingService.swift` (включая 157 строк закомментированного кода!) | `OrderService.swift` |
| `Shipment`, `ShipmentDetails`, `ContactInfo`, `PackageInfo`, `PaymentInfo` (`Models.swift`) | `Order` (`OrderService.swift`) |
| `ShipmentCard` (`Data Models/Components.swift`) | `ClientOrderCard` (`ClientMainView.swift`) |
| `ShipmentDetailView.swift` (вес/цена угадываются по префиксу трека!) | `ClientOrderDetailView` (`ClientMainView.swift`) |
| `DriverShipmentDetailView.swift` (546 строк — нигде не вызывается) | `DriverOrderDetailView` (`DriverView.swift`) |
| `ContactCourierView.swift` (378 строк — фейковый «Аслан Курьеров», нигде не вызывается) | Кнопки звонка/WhatsApp в `ClientOrderDetailView` |
| `RouteMapView.swift` | `OrderRouteMapView` (`ClientMainView.swift`) |
| `FirebaseTestView.swift`, `TestDataManager.swift` | Отладочные файлы в основном таргете |
| `Assets.xcassets/VehicleInfoView.dataset/VehicleInfoView.swift` | Старая некомпилируемая копия View внутри Asset Catalog! |

**Рекомендация:** удалить мёртвый код и объединить модели в единую чистую доменную модель `Order` (перенести из `OrderService.swift` в `Models/Order.swift`, а `DocumentType` — из `VehicleInfoView.swift` в `Models/Document.swift`).

### 4.2. Отсутствие архитектуры (MVVM) и «God Views»
- `DriverView.swift` — **1 157 строк** (содержит 13 структур в одном файле!).
- `ClientMainView.swift` — **1 034 строки** (содержит 8 структур в одном файле!).
- `VehicleInfoView.swift` — **470 строк**.
- Сетевая логика, бизнес-правила, форматирование дат/телефонов, валидация и UI смешаны внутри `View`.
- Нет единого контейнера зависимостей: `NewOrderView`, `ClientMainView` и `DriverView` создают отдельные экземпляры `OrderService`.

### 4.3. Массовое дублирование кода
- **Статусы заказа** (`statusText`, `statusColor`, `statusIcon`) продублированы 5+ раз в разных View. Должны быть свойствами одного `enum OrderStatus: String, Codable, CaseIterable`.
- **`DateFormatter`** пересоздаётся на каждый вызов в 7 файлах (`Extensions.swift` при этом вообще не используется!). Создание `DateFormatter` — дорогая операция; нужно использовать один `static let` форматтер или встроенный iOS 15+ `Date.FormatStyle`.
- **Звонок и WhatsApp** продублированы 4 раза с разной логикой очистки номера. Нужно вынести в `ContactActionService` / `PhoneFormatter`.
- **Тарифы** (`let tariffs = [...]`) скопированы в `NewOrderView.swift` и `TariffsView.swift`. Нужно вынести в единый источник (а затем — в Firestore).
- **Конфликты имён компонентов:** `DetailRow` vs `DetailRowClient`, `InfoRow` (в двух файлах), `ContactInfoRow` vs `CourierContactInfoRow`, суффиксы `*New` (`CurrentDeliveriesViewNew`, `DriverMapViewNew`).

### 4.4. Хрупкая работа с Firestore и моделями
- **Ручной парсинг словарей** (`fromDictionary` / `orderToDict` / `documentInfoToDict`) вместо встроенной поддержки `Codable` в `FirebaseFirestore` (`document.data(as: Order.self)`, `setData(from: order)`, `@DocumentID`).
- **Потенциальная потеря заказов при парсинге чисел:** в `OrderService.swift:268` используется `dict["weight"] as? Double`. Если в Firestore записано целое число (`NSNumber`/`Int`), каст к `Double` вернёт `nil`, и заказ бесшумно отфильтруется через `compactMap`.
- **Локализованные строки в БД:** `packageType` (`"Орташа пакет"`) и `tariffType` (`"Экспресс"`) хранятся в Firestore как казахский текст, а не стабильные ключи (`"medium"`, `"express"`). Это делает невозможной нормальную мультиязычность и ломает расчёты при изменении формулировок.
- **Обработка ошибок и многопоточность:**
  - `OrderService` и `DriverView` «проглатывают» ошибки через `print(...)` — пользователь не получает обратной связи при сбоях сети/прав.
  - В `OrderService.swift:88, 112, 136` обновление `@Published var orders` происходит без гарантии главного потока (в отличие от `AuthService` и `AdminService`). Все `ObservableObject` сервисы/ViewModel стоит явно пометить `@MainActor`.
- **Логирование персональных данных:** `AuthService.swift:84` выводит в `print` полный словарь документа пользователя (email, телефон, ИИН, номера документов). Следует перейти на `os.Logger` с маскированием приватных данных (`.private`).

### 4.5. Устаревшие (Deprecated) API SwiftUI / MapKit
При таргете iOS 18.6 проект использует устаревшие конструкции времён iOS 13–15:
- `NavigationView` → заменить на `NavigationStack`.
- `.navigationBarItems(...)` / `.navigationBarTitle(...)` → заменить на `.toolbar` и `.navigationTitle`.
- `@Environment(\.presentationMode)` → заменить на `@Environment(\.dismiss)`.
- `.actionSheet(...)` → заменить на `.confirmationDialog(...)`.
- `Map(coordinateRegion:annotationItems:)` → заменить на новый MapKit SwiftUI API (`Map(position:)` + `Marker` / `Annotation` + `MapPolyline`).
- `.onChange(of:) { newValue in }` → заменить на двухпараметрический `.onChange(of:) { _, newValue in }`.

### 4.6. Смешение языков и отсутствие локализации
- Клиент и водитель — на казахском (с опечатками и русскими вкраплениями вроде `Трек-номер`, `Статус`, `Техосмотр`, `Двигатель нөмірі`).
- Админ-панель (`AdminDashboardView`, `AdminService`) — полностью на русском.
- Часть ошибок выводится сырым английским `error.localizedDescription`.
- В проекте не создан `Localizable.xcstrings` (String Catalog), хотя `LOCALIZATION_PREFERS_STRING_CATALOGS = YES` включён.

### 4.7. Отсутствие тестов и CI/CD
- В `LogisticsApp.xcodeproj` нет тест-таргетов (`LogisticsAppTests`, `LogisticsAppUITests`) — **0 автоматических тестов**.
- Нет GitHub Actions для проверки сборки, тестов и линтинга (`SwiftLint`).

---

## 5. Что предлагаю усилить и добавить

### Продуктовые улучшения (Фичи с высокой ценностью)
1. **Полноценная загрузка и проверка документов водителя:**
   - Прикрепление фото (камера / галерея через `PhotosPicker`) и PDF (`fileImporter`) в `DocumentDetailView` с автоматическим сжатием изображений перед загрузкой в `StorageService`.
   - Просмотр загруженных сканов/фото с зумом в `AdminDashboardView`.
   - Автоматические напоминания водителю за 30 / 7 / 1 день до истечения срока документа (и авто-блокировка выхода на линию при истечении).
2. **Реальный GPS-трекинг и полноценная навигация:**
   - Подключение `CLLocationManager` для водителя (при активном `isOnDuty` и выполнении заказа) с периодической отправкой координат в Firestore / Realtime Database.
   - Отображение реального местоположения курьера на карте у клиента и расчёт маршрута/ETA через `MKDirections` + `MapPolyline` (плюс кнопка открытия в 2ГИС / Apple Maps / Yandex Navigator).
   - Геокодирование конкретных адресов (улица, дом), а не только центров городов из статического списка.
3. **Push-уведомления (Firebase Cloud Messaging + Cloud Functions):**
   - Клиенту: водитель принял заказ, статус изменился (`inTransit`, `atCustoms`, `delivered`), курьер рядом.
   - Водителю: новый доступный заказ поблизости, результат проверки документа админом (одобрен/отклонён с причиной).
   - Админу: новый документ на проверке.
4. **Прозрачное ценообразование, оплата и кошелёк водителя:**
   - Динамический калькулятор цены: базовый тариф + вес + расстояние между городами + допуслуги, с фиксацией цены на сервере (Cloud Function).
   - Статусы оплаты (оплата картой / Apple Pay / Kaspi QR / наличные при получении).
   - Раздел «Доходы и статистика» для водителя (за день/неделю/месяц, количество выполненных заказов).
5. **Завершение клиентского и водительского UX:**
   - **Отмена заказа клиентом** (в `firestore.rules` уже прописано правило для `status == 'cancelled'`, но в UI кнопки отмены нет!).
   - **Подтверждение доставки (Proof of Delivery):** фото доставленной посылки или одноразовый PIN/QR-код от получателя.
   - **История статусов (Timeline)** с точными датами/временем каждого этапа.
   - **Экран профиля и настроек** (редактирование имени/телефона, переключение языка KZ/RU/EN, сброс пароля, удаление аккаунта — **обязательное требование App Store Review Guidelines 5.1.1(v)!**).
   - **Рейтинг и отзывы** после завершения доставки (в `firestore.rules` уже есть заготовка для `reviews`).
   - **Внутренний чат** клиент ↔ водитель по заказу (вместо принудительного ухода в WhatsApp).
   - **Фильтры и сортировка** доступных заказов для водителя (по городу отправления/назначения, весу, срочности, тарифу).
6. **Усиление админ-панели:**
   - Вкладки: *Документы на проверке*, *Все заказы* (с возможностью вручную переназначить водителя или отменить заказ), *Пользователи* (блокировка/разблокировка), *Тарифы и отделения* (управление через Firestore вместо хардкода в приложении), *Базовая аналитика*.
   - Фильтрация водителей по статусу верификации (ожидают / отклонены / одобрены) и поиск.

### Технические усиления
- **Переход на MVVM + Repository / Service Protocols** (внедрение зависимостей через протоколы для тестируемости).
- **Cloud Functions (TypeScript)** для критичных операций: расчёт и фиксация цены заказа, атомарное принятие заказа, триггеры Push-уведомлений, генерация уникального трек-номера, проверка прав администратора через **Firebase Custom Claims** (вместо лишнего `get()` в `firestore.rules`, который стоит денег и замедляет каждый запрос!).
- **Firebase Crashlytics** и структурированное логирование (`os.Logger`).
- **Офлайн-индикатор (`NWPathMonitor`)** и корректные состояния `loading / empty / error` на каждом экране.
- **Локализация через `Localizable.xcstrings`** (KZ, RU, EN).
- **Поддержка Dark Mode и Dynamic Type** (доступность).

---

## 6. План дальнейшего развития (Roadmap)

### Этап 1: Стабилизация, безопасность и исправление блокеров (1–2 недели)
*Цель: устранить все критические баги и дыры безопасности, чтобы базовые сценарии работали надёжно.*

- [ ] **Безопасность Firestore & Storage:**
  - Исправить `firestore.rules` (проверка отсутствующего `driverId`, роли `driver` при принятии заказа, запрет самоподтверждения документов, ограничение `affectedKeys`, защита PII водителей, очистка неиспользуемых функций).
  - Добавить `storage.rules` (загрузка документов только владельцем с ограничением размера/MIME-типа, чтение только владельцем и админом) и `firestore.indexes.json`.
  - В `OrderService.createOrder` явно писать `"driverId": NSNull()`.
  - Разделить `listenToAllOrders()` на два безопасных запроса (доступные + заказы водителя).
  - Перевести `assignOrderToDriver` на Firestore Transaction + проверять верификацию документов перед принятием.
- [ ] **Исправление критических багов:**
  - Сделать `expiryDate` опциональным для техпаспорта (исправить вечную просрочку).
  - Включить `"atCustoms"` в `assignedOrders` в `DriverView`.
  - Починить поиск по трек-номеру в `ClientMainView` (искать через `OrderService`).
  - Сохранять цену заказа в `Order` / Firestore и отображать её клиенту и водителю.
  - Починить `DocumentDetailView` (реальный async `saveDocument`, дефолтное значение `insuranceType`, валидация ИИН/VIN/дат).
  - Починить `LoginView` / `RegistrationView` / `AuthService` (убрать `# Login`, лишний `Picker`, отладочную кнопку, опечатки, `checkFirebaseConnection()`, поправить цвет успеха, смягчить валидацию пароля, добавить «Забыли пароль?», обработать сбой записи профиля при регистрации).
- [ ] **Конфигурация Xcode:**
  - Синхронизировать `PRODUCT_BUNDLE_IDENTIFIER` в Debug/Release и `GoogleService-Info.plist`.
  - Понизить и выровнять `IPHONEOS_DEPLOYMENT_TARGET` (например, `17.0`).
  - Удалить `FirebaseManager.swift` и гарантировать вызов `FirebaseApp.configure()` до инициализации `AuthService`.

### Этап 2: Рефакторинг архитектуры, очистка и UI-полировка (2 недели)
*Цель: избавиться от технического долга и сделать код масштабируемым.*

- [ ] Удалить мёртвый код (`TrackingService`, `DriverShipmentDetailView`, `ContactCourierView`, `ShipmentDetailView`, `RouteMapView`, `FirebaseTestView`, `TestDataManager`, `Assets.xcassets/VehicleInfoView.dataset`).
- [ ] Выделить единые модели (`Models/Order.swift`, `Models/OrderStatus.swift`, `Models/Tariff.swift`, `Models/Document.swift`) и перевести Firestore на `Codable` (`@DocumentID`) со стабильными английскими ключами для всех enum.
- [ ] Разбить `ClientMainView` и `DriverView` на отдельные экраны, переиспользуемые компоненты (`Components/`) и `ViewModel` с `@MainActor`.
- [ ] Вынести общие утилиты: `Formatters.swift` (переиспользуемые `DateFormatter`/`NumberFormatter`), `ContactHelper.swift` (звонок/WhatsApp/SMS).
- [ ] Починить Dark Mode (заменить все `Color.white` на семантические цвета), перейти с deprecated SwiftUI/MapKit API на современные (`NavigationStack`, `.toolbar`, `@Environment(\.dismiss)`, `.confirmationDialog`, новый `Map`).
- [ ] Добавить `Localizable.xcstrings` (KZ / RU / EN) и перевести все экраны (включая админку и ошибки).
- [ ] Добавить таргет `LogisticsAppTests` (unit-тесты для `AuthValidation`, расчёта цен, переходов статусов, парсинга моделей, `CitiesDatabase`, `TwoGISRouteService`) и базовый CI.

### Этап 3: Ключевые продуктовые фичи для MVP 2.0 (3–4 недели)
*Цель: превратить прототип в полноценный логистический продукт.*

- [ ] Подключить `StorageService` в `DocumentDetailView` (загрузка фото/PDF) и просмотр сканов в `AdminDashboardView`.
- [ ] Реализовать экраны «Жеке кабинет» (редактирование профиля + **удаление аккаунта для App Store**) и «Баптаулар» (язык, тема, уведомления).
- [ ] Реализовать отмену заказа клиентом, историю всех завершённых заказов («Барлығын көру») и выбор тарифа из `TariffsView` с переходом в `NewOrderView`.
- [ ] Подключить `CLLocationManager`, реальную позицию водителя, сохранение статуса `isOnDuty` в Firestore и отрисовку линии маршрута (`MapPolyline` / `MKDirections`).
- [ ] Внедрить Push-уведомления (FCM) и базовые Firebase Cloud Functions (триггеры статусов, верификация, серверный расчёт цены).
- [ ] Добавить рейтинг/отзывы водителя, фильтрацию заказов для водителя и историю изменений статуса заказа (Timeline).

### Этап 4: Масштабирование и подготовка к релизу в App Store (3–4 недели)
*Цель: готовность к реальным пользователям и коммерческой эксплуатации.*

- [ ] Интеграция платёжного провайдера (Kaspi / FreedomPay / Apple Pay) и учёта заработка/выплат водителей.
- [ ] Proof of Delivery (фото/подпись или OTP-код подтверждения вручения) и PDF-накладная/чек.
- [ ] Полноценное геокодирование адресов «от двери до двери» (2ГИС API / MapKit `MKLocalSearch`) вместо списка из 35 городов.
- [ ] Расширенная админ-панель (управление заказами, тарифами, офисами, аналитика, Firebase Custom Claims).
- [ ] Подключить Firebase App Check, Crashlytics, Analytics, UI-тесты критических сценариев и аудит соответствия App Store Review Guidelines.

---

## 7. Краткий чек-лист приоритетов (с чего начать завтра)

1. Починить `firestore.rules` + добавить `NSNull()` для `driverId` + разбить запрос `listenToAllOrders()` (иначе база либо небезопасна, либо не работает).
2. Починить баг с `expiryDate` техпаспорта и потерей статуса `atCustoms`.
3. Подключить транзакцию и проверку верификации документов при принятии заказа водителем.
4. Починить поиск по трек-номеру в `ClientMainView` и сохранить цену в `Order`.
5. Выровнять `PRODUCT_BUNDLE_IDENTIFIER` и удалить мёртвый код (`TrackingService` и старые View).
