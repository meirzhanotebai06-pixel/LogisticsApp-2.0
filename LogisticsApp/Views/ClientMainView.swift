import SwiftUI
import MapKit

struct ClientMainView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var orderService = OrderService()

    @State private var searchText = ""
    @State private var showNewOrderSheet = false
    @State private var preselectedTariff: TariffType = .standard
    @State private var showTariffsSheet = false
    @State private var showMapSheet = false
    @State private var showProfileSheet = false
    @State private var showSettingsSheet = false
    @State private var showAllCompletedSheet = false
    @State private var showSearchAlert = false
    @State private var showLogoutAlert = false
    @State private var selectedOrder: Order?
    @State private var selectedOrderForMap: Order?

    private var activeOrders: [Order] {
        orderService.orders.filter { $0.orderStatus.isActive }
    }

    private var completedOrders: [Order] {
        orderService.orders.filter { $0.orderStatus == .delivered || $0.orderStatus == .cancelled }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Track-number search
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Жіберілімді қадағалау")
                            .font(.title2)
                            .fontWeight(.semibold)

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "checkmark.circle")
                                Text("Трек-номері")
                                    .font(.subheadline)
                                Spacer()
                            }
                            .foregroundColor(.secondary)

                            HStack(spacing: 12) {
                                TextField("Мысалы: KZ123456789", text: $searchText)
                                    .textFieldStyle(.roundedBorder)
                                    .textInputAutocapitalization(.characters)

                                Button(action: searchShipment) {
                                    Text("Іздеу")
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color.blue)
                                        .cornerRadius(8)
                                }
                                .disabled(searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }
                        }
                    }

                    // Quick actions
                    HStack(spacing: 12) {
                        ActionButton(title: "Жаңа", icon: "plus.circle") {
                            preselectedTariff = .standard
                            showNewOrderSheet = true
                        }
                        ActionButton(title: "Карта", icon: "map") {
                            showMapSheet = true
                        }
                        ActionButton(title: "Тарифтер", icon: "dollarsign.circle") {
                            showTariffsSheet = true
                        }
                    }

                    // Active orders
                    VStack(alignment: .leading, spacing: 15) {
                        HStack {
                            Text("Белсенді тапсырыстар")
                                .font(.title2)
                                .fontWeight(.semibold)

                            Spacer()

                            if !activeOrders.isEmpty {
                                Text("\(activeOrders.count)")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color.blue)
                                    .cornerRadius(12)
                            }
                        }

                        if orderService.isLoading && orderService.orders.isEmpty {
                            ProgressView("Жүктелуде...")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 30)
                        } else if activeOrders.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "shippingbox")
                                    .font(.system(size: 50))
                                    .foregroundColor(.secondary)

                                Text("Белсенді тапсырыс жоқ")
                                    .font(.headline)
                                    .foregroundColor(.secondary)

                                Text("Жаңа тапсырыс жасау үшін төмендегі батырманы басыңыз")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 30)
                        } else {
                            ForEach(activeOrders) { order in
                                ClientOrderCard(
                                    order: order,
                                    onTap: {
                                        selectedOrder = order
                                    },
                                    onShowRoute: {
                                        selectedOrderForMap = order
                                    }
                                )
                            }
                        }
                    }

                    // Completed / cancelled orders
                    if !completedOrders.isEmpty {
                        VStack(alignment: .leading, spacing: 15) {
                            HStack {
                                Text("Тарих және аяқталғандар")
                                    .font(.title2)
                                    .fontWeight(.semibold)

                                Spacer()

                                Text("\(completedOrders.count)")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color.green)
                                    .cornerRadius(12)
                            }

                            ForEach(completedOrders.prefix(3)) { order in
                                ClientOrderCard(
                                    order: order,
                                    onTap: {
                                        selectedOrder = order
                                    },
                                    onShowRoute: {
                                        selectedOrderForMap = order
                                    }
                                )
                            }

                            if completedOrders.count > 3 {
                                Button("Барлығын көру (\(completedOrders.count))") {
                                    showAllCompletedSheet = true
                                }
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.blue)
                            }
                        }
                    }

                    Button("Жаңа жіберілім жасау") {
                        preselectedTariff = .standard
                        showNewOrderSheet = true
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .fontWeight(.semibold)
                    .cornerRadius(12)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Басты бет")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showProfileSheet = true
                        } label: {
                            Label("Жеке кабинет", systemImage: "person")
                        }
                        Button {
                            showSettingsSheet = true
                        } label: {
                            Label("Баптаулар", systemImage: "gearshape")
                        }
                        Button(role: .destructive) {
                            showLogoutAlert = true
                        } label: {
                            Label("Жүйеден шығу", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title3)
                    }
                }
            }
            .sheet(isPresented: $showNewOrderSheet) {
                NewOrderView(initialTariff: preselectedTariff)
                    .environmentObject(authService)
            }
            .sheet(isPresented: $showTariffsSheet) {
                TariffsView { tariff in
                    preselectedTariff = tariff
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showNewOrderSheet = true
                    }
                }
            }
            .sheet(isPresented: $showMapSheet) {
                MapView()
            }
            .sheet(isPresented: $showProfileSheet) {
                ProfileView()
                    .environmentObject(authService)
            }
            .sheet(isPresented: $showSettingsSheet) {
                SettingsView()
                    .environmentObject(authService)
            }
            .sheet(isPresented: $showAllCompletedSheet) {
                ClientCompletedOrdersView(
                    orders: completedOrders,
                    onSelectOrder: { order in
                        showAllCompletedSheet = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            selectedOrder = order
                        }
                    },
                    onShowRoute: { order in
                        showAllCompletedSheet = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            selectedOrderForMap = order
                        }
                    }
                )
            }
            .sheet(item: $selectedOrder) { order in
                ClientOrderDetailView(order: order, orderService: orderService)
                    .environmentObject(authService)
            }
            .sheet(item: $selectedOrderForMap) { order in
                OrderRouteMapView(order: order)
            }
            .alert("Тапсырыс табылмады", isPresented: $showSearchAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Бұл трек-номермен тапсырыс табылмады")
            }
            .alert("Қате", isPresented: Binding(
                get: { orderService.errorMessage != nil },
                set: { if !$0 { orderService.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { orderService.errorMessage = nil }
            } message: {
                Text(orderService.errorMessage ?? "")
            }
            .alert("Жүйеден шығу", isPresented: $showLogoutAlert) {
                Button("Бас тарту", role: .cancel) { }
                Button("Шығу", role: .destructive) {
                    authService.logout()
                }
            } message: {
                Text("Сіз шынымен жүйеден шығғыңыз келе ме?")
            }
            .onAppear {
                if let clientId = authService.currentUser?.id {
                    orderService.listenToClientOrders(clientId: clientId)
                }
            }
            .onDisappear {
                orderService.stopListening()
            }
        }
    }

    private func searchShipment() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }

        if let found = orderService.searchOrder(byTrackNumber: query) {
            selectedOrder = found
            searchText = ""
        } else {
            showSearchAlert = true
        }
    }
}

// MARK: - Completed Orders Sheet

private struct ClientCompletedOrdersView: View {
    @Environment(\.dismiss) private var dismiss
    let orders: [Order]
    let onSelectOrder: (Order) -> Void
    let onShowRoute: (Order) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 14) {
                    ForEach(orders) { order in
                        ClientOrderCard(
                            order: order,
                            onTap: { onSelectOrder(order) },
                            onShowRoute: { onShowRoute(order) }
                        )
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Аяқталған тапсырыстар")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Жабу") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Client Order Card

struct ClientOrderCard: View {
    let order: Order
    let onTap: () -> Void
    let onShowRoute: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(order.trackNumber)
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)

                        Text(order.createdAt.formattedShortDateTime())
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Text(order.orderStatus.title)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(order.orderStatus.color.opacity(0.15))
                        .foregroundColor(order.orderStatus.color)
                        .cornerRadius(12)
                }
                .padding()
                .background(Color(.tertiarySystemGroupedBackground))

                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        VStack(spacing: 6) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 12, height: 12)

                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 2, height: 30)

                            Circle()
                                .fill(Color.red)
                                .frame(width: 12, height: 12)
                        }

                        VStack(alignment: .leading, spacing: 24) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Қайдан")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(order.fromAddress)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Қайда")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(order.toAddress)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                            }
                        }

                        Spacer()

                        Button(action: onShowRoute) {
                            Image(systemName: "map.fill")
                                .font(.title3)
                                .foregroundColor(.blue)
                                .padding(8)
                                .background(Color.blue.opacity(0.1))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding()

                    if let driverName = order.driverName {
                        HStack(spacing: 8) {
                            Image(systemName: "person.circle.fill")
                                .foregroundColor(.blue)
                            Text("Жеткізуші:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(driverName)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 4)
                    }

                    HStack(spacing: 16) {
                        HStack(spacing: 4) {
                            Image(systemName: "shippingbox")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(order.displayPackageType)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        HStack(spacing: 4) {
                            Image(systemName: "scalemass")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(String(format: "%.1f", order.weight)) кг")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Text(order.price.formattedTenge(currency: order.currency))
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                    }
                    .padding(.horizontal)
                    .padding(.bottom)

                    if order.orderStatus.isActive {
                        ProgressBar(progress: order.orderStatus.progress)
                            .padding(.horizontal)
                            .padding(.bottom)
                    }
                }
            }
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Progress Bar

struct ProgressBar: View {
    let progress: CGFloat

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 6)
                    .cornerRadius(3)

                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.7)]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * progress, height: 6)
                    .cornerRadius(3)
            }
        }
        .frame(height: 6)
    }
}

// MARK: - Order Route Map View

struct OrderRouteMapView: View {
    let order: Order
    @Environment(\.dismiss) private var dismiss
    @State private var cameraPosition: MapCameraPosition

    private let fromCoord: CLLocationCoordinate2D
    private let toCoord: CLLocationCoordinate2D

    init(order: Order) {
        self.order = order
        let from = CitiesDatabase.getCoordinate(cityName: order.fromAddress)
            ?? CLLocationCoordinate2D(latitude: 43.2380, longitude: 76.8829)
        let to = CitiesDatabase.getCoordinate(cityName: order.toAddress)
            ?? CLLocationCoordinate2D(latitude: 51.1694, longitude: 71.4491)
        self.fromCoord = from
        self.toCoord = to

        let centerLat = (from.latitude + to.latitude) / 2
        let centerLon = (from.longitude + to.longitude) / 2
        let latDelta = abs(from.latitude - to.latitude) * 1.5
        let lonDelta = abs(from.longitude - to.longitude) * 1.5

        _cameraPosition = State(
            initialValue: .region(
                MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
                    span: MKCoordinateSpan(latitudeDelta: max(latDelta, 2.0), longitudeDelta: max(lonDelta, 2.0))
                )
            )
        )
    }

    private var polylinePoints: [CLLocationCoordinate2D] {
        if let driverLoc = order.driverLocation {
            return [fromCoord, driverLoc.coordinate, toCoord]
        }
        return [fromCoord, toCoord]
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Map(position: $cameraPosition) {
                    Marker(order.fromAddress, systemImage: "circle.fill", coordinate: fromCoord)
                        .tint(.green)

                    if let driverLoc = order.driverLocation {
                        Annotation("Жеткізуші", coordinate: driverLoc.coordinate) {
                            Image(systemName: "box.truck.fill")
                                .padding(8)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .clipShape(Circle())
                                .shadow(radius: 3)
                        }
                    }

                    Marker(order.toAddress, systemImage: "mappin.circle.fill", coordinate: toCoord)
                        .tint(.red)

                    MapPolyline(coordinates: polylinePoints)
                        .stroke(.blue, lineWidth: 4)
                }
                .ignoresSafeArea()

                VStack {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Маршрут")
                                .font(.headline)
                            Text(order.route)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            if order.distanceKm > 0 {
                                Text("\(order.distanceKm) км")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }

                        Spacer()

                        Text(order.orderStatus.title)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(order.orderStatus.color.opacity(0.15))
                            .foregroundColor(order.orderStatus.color)
                            .cornerRadius(12)
                    }
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                    .shadow(radius: 4)
                    .padding()

                    Spacer()
                }
            }
            .navigationTitle("Маршрут")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Жабу") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Client Order Detail View

struct ClientOrderDetailView: View {
    let order: Order
    @ObservedObject var orderService: OrderService
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss

    @State private var showCancelConfirmation = false
    @State private var showReviewSheet = false
    @State private var reviewSubmitted = false
    @State private var isCancelling = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(spacing: 8) {
                        Text("Трек-номер")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(order.trackNumber)
                            .font(.title2)
                            .fontWeight(.bold)
                        Text(order.price.formattedTenge(currency: order.currency))
                            .font(.headline)
                            .foregroundColor(.blue)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.blue.opacity(0.12), Color.blue.opacity(0.05)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(16)

                    // Status & Timeline
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Статус")
                            .font(.headline)

                        HStack {
                            Text(order.orderStatus.title)
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(order.orderStatus.color)

                            Spacer()

                            Image(systemName: order.orderStatus.icon)
                                .font(.title)
                                .foregroundColor(order.orderStatus.color)
                        }
                        .padding()
                        .background(order.orderStatus.color.opacity(0.1))
                        .cornerRadius(12)

                        if order.orderStatus != .cancelled {
                            OrderProgressView(status: order.status)
                        }

                        if !order.statusHistory.isEmpty {
                            Divider()
                            Text("Өзгерістер тарихы")
                                .font(.subheadline)
                                .fontWeight(.semibold)

                            ForEach(order.statusHistory) { event in
                                HStack(alignment: .top, spacing: 10) {
                                    Circle()
                                        .fill(event.orderStatus.color)
                                        .frame(width: 8, height: 8)
                                        .padding(.top, 6)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(event.orderStatus.title)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        if let note = event.note, !note.isEmpty {
                                            Text(note)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }

                                    Spacer()

                                    Text(event.timestamp.formattedShortDateTime())
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(16)

                    // Route
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Маршрут")
                            .font(.headline)

                        HStack(spacing: 12) {
                            VStack(spacing: 8) {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 14, height: 14)
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 2, height: 40)
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 14, height: 14)
                            }

                            VStack(alignment: .leading, spacing: 32) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Қайдан")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(order.fromAddress)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Қайда")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(order.toAddress)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(16)

                    // Driver info
                    if let driverName = order.driverName {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Жеткізуші")
                                .font(.headline)

                            HStack {
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 50))
                                    .foregroundColor(.blue)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(driverName)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    Text("Жеткізуші")
                                        .font(.caption)
                                        .foregroundColor(.secondary)

                                    if let phone = order.driverPhone {
                                        Text(phone)
                                            .font(.caption)
                                            .foregroundColor(.blue)
                                    }
                                }

                                Spacer()
                            }

                            if let phone = order.driverPhone {
                                HStack(spacing: 12) {
                                    Button {
                                        ContactHelper.call(phone: phone)
                                    } label: {
                                        HStack {
                                            Image(systemName: "phone.fill")
                                            Text("Қоңырау шалу")
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.green)
                                        .foregroundColor(.white)
                                        .cornerRadius(12)
                                    }

                                    Button {
                                        ContactHelper.openWhatsApp(
                                            phone: phone,
                                            message: "Сәлеметсіз бе! Менің тапсырысым туралы сұрағым бар (Трек-номер: \(order.trackNumber))"
                                        )
                                    } label: {
                                        HStack {
                                            Image(systemName: "message.fill")
                                            Text("WhatsApp")
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color(red: 0.15, green: 0.68, blue: 0.38))
                                        .foregroundColor(.white)
                                        .cornerRadius(12)
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(16)
                    }

                    // Package details
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Пакет туралы")
                            .font(.headline)

                        VStack(alignment: .leading, spacing: 8) {
                            DetailRowClient(icon: "shippingbox", label: "Түрі", value: order.displayPackageType)
                            DetailRowClient(icon: "scalemass", label: "Салмағы", value: "\(String(format: "%.1f", order.weight)) кг")
                            DetailRowClient(icon: "doc.text", label: "Сипаттама", value: order.packageDescription)
                            DetailRowClient(icon: "dollarsign.circle", label: "Тариф", value: order.displayTariffType)
                            DetailRowClient(icon: "tenge.circle", label: "Құны", value: order.price.formattedTenge(currency: order.currency))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(16)

                    // Dates
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Мерзімдер")
                            .font(.headline)

                        VStack(alignment: .leading, spacing: 8) {
                            DetailRowClient(icon: "calendar", label: "Жасалды", value: order.createdAt.formattedFullDateTime())
                            DetailRowClient(icon: "clock", label: "Болжамды жеткізу", value: order.estimatedDelivery.formattedFullDateTime())

                            if let deliveredAt = order.deliveredAt {
                                DetailRowClient(icon: "checkmark.circle", label: "Жеткізілді", value: deliveredAt.formattedFullDateTime())
                            }
                            if let cancelledAt = order.cancelledAt {
                                DetailRowClient(icon: "xmark.circle", label: "Болдырылмады", value: cancelledAt.formattedFullDateTime())
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(16)

                    // Actions
                    if order.orderStatus == .accepted && order.driverId == nil {
                        Button(role: .destructive) {
                            showCancelConfirmation = true
                        } label: {
                            if isCancelling {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                            } else {
                                Label("Тапсырысты болдырмау", systemImage: "xmark.circle")
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .padding()
                        .background(Color.red.opacity(0.12))
                        .cornerRadius(12)
                        .disabled(isCancelling)
                    }

                    if order.orderStatus == .delivered && order.driverId != nil && !reviewSubmitted {
                        Button {
                            showReviewSheet = true
                        } label: {
                            Label("Жеткізушіні бағалау", systemImage: "star.fill")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.orange)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Тапсырыс мәліметтері")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Жабу") { dismiss() }
                }
            }
            .confirmationDialog("Тапсырысты болдырмау", isPresented: $showCancelConfirmation, titleVisibility: .visible) {
                Button("Тапсырысты болдырмау", role: .destructive) {
                    Task { await cancelOrder() }
                }
                Button("Жоқ", role: .cancel) { }
            } message: {
                Text("Тапсырысты болдырмағыңыз келе ме?")
            }
            .sheet(isPresented: $showReviewSheet) {
                DriverReviewSheet(order: order, orderService: orderService) {
                    reviewSubmitted = true
                }
                .environmentObject(authService)
            }
            .alert("Қате", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func cancelOrder() async {
        isCancelling = true
        defer { isCancelling = false }
        do {
            try await orderService.cancelOrder(orderId: order.id)
            dismiss()
        } catch {
            errorMessage = "Тапсырысты болдырмау сәтсіз: \(error.localizedDescription)"
        }
    }
}

private struct DriverReviewSheet: View {
    let order: Order
    @ObservedObject var orderService: OrderService
    let onSubmitted: () -> Void

    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss

    @State private var rating = 5
    @State private var comment = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Бағалау") {
                    HStack(spacing: 12) {
                        ForEach(1...5, id: \.self) { star in
                            Button {
                                rating = star
                            } label: {
                                Image(systemName: star <= rating ? "star.fill" : "star")
                                    .font(.title2)
                                    .foregroundColor(.orange)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 6)
                }

                Section("Пікір (міндетті емес)") {
                    TextField("Жеткізу сапасы туралы пікіріңіз", text: $comment, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section {
                    Button {
                        Task { await submit() }
                    } label: {
                        if isSubmitting {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Жіберу")
                                .frame(maxWidth: .infinity)
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(isSubmitting)
                }
            }
            .navigationTitle("Жеткізушіні бағалау")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Жабу") { dismiss() }
                }
            }
            .alert("Қате", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func submit() async {
        guard let user = authService.currentUser else { return }
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            try await orderService.submitReview(
                order: order,
                clientId: user.id,
                clientName: user.name,
                rating: rating,
                comment: comment
            )
            onSubmitted()
            dismiss()
        } catch {
            errorMessage = "Пікір жіберу сәтсіз: \(error.localizedDescription)"
        }
    }
}

struct DetailRowClient: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            Text(label + ":")
                .foregroundColor(.secondary)
                .font(.subheadline)
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

struct OrderProgressView: View {
    let status: String

    private let steps: [(OrderStatus, String, String)] = [
        (.accepted, "Қабылданды", "checkmark.circle"),
        (.inTransit, "Жеткізілуде", "shippingbox"),
        (.atCustoms, "Кеденде", "building.2"),
        (.delivered, "Жеткізілді", "checkmark.seal")
    ]

    private var currentStepIndex: Int {
        steps.firstIndex(where: { $0.0.rawValue == status }) ?? 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(0..<steps.count, id: \.self) { index in
                let step = steps[index]
                let isCompleted = index <= currentStepIndex
                let isCurrent = index == currentStepIndex

                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(isCompleted ? Color.blue : Color.gray.opacity(0.3))
                            .frame(width: 36, height: 36)

                        Image(systemName: step.2)
                            .foregroundColor(.white)
                            .font(.system(size: 16))
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(step.1)
                            .font(.subheadline)
                            .fontWeight(isCurrent ? .semibold : .regular)
                            .foregroundColor(isCompleted ? .primary : .secondary)

                        if isCurrent {
                            Text("Ағымдағы статус")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }

                    Spacer()

                    if isCompleted {
                        Image(systemName: "checkmark")
                            .foregroundColor(.blue)
                            .font(.headline)
                    }
                }

                if index < steps.count - 1 {
                    Rectangle()
                        .fill(isCompleted ? Color.blue : Color.gray.opacity(0.3))
                        .frame(width: 2, height: 16)
                        .padding(.leading, 17)
                }
            }
        }
    }
}
