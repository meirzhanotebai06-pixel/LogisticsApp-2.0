import SwiftUI
import MapKit

struct DriverView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var vehicleService = VehicleService()
    @StateObject private var orderService = OrderService()
    @StateObject private var locationManager = LocationManager()

    @State private var selectedTab = 0
    @State private var selectedOrder: Order?
    @State private var isOnDuty = false
    @State private var showLogoutAlert = false
    @State private var showVehicleInfo = false
    @State private var showProfileSheet = false
    @State private var showSettingsSheet = false
    @State private var showVerificationRequiredAlert = false
    @State private var errorMessage: String?

    @State private var searchQuery = ""
    @State private var onlyUrgent = false

    private var areDocumentsValid: Bool {
        vehicleService.areAllDocumentsValid(vehicleInfo: authService.currentUser?.vehicleInfo)
    }

    private var filteredAvailableOrders: [Order] {
        orderService.availableOrders.filter { order in
            let matchesUrgent = !onlyUrgent || order.isUrgent
            let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let matchesSearch = q.isEmpty ||
                order.trackNumber.lowercased().contains(q) ||
                order.fromAddress.lowercased().contains(q) ||
                order.toAddress.lowercased().contains(q)
            return matchesUrgent && matchesSearch
        }
    }

    private var assignedOrders: [Order] {
        orderService.myOrders.filter { $0.orderStatus.isActive }
    }

    private var completedOrders: [Order] {
        orderService.myOrders.filter { $0.orderStatus == .delivered }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if !areDocumentsValid {
                    DocumentWarningBanner {
                        showVehicleInfo = true
                    }
                }

                DriverStatusHeader(
                    isOnDuty: Binding(
                        get: { isOnDuty },
                        set: { newValue in
                            isOnDuty = newValue
                            if newValue {
                                locationManager.startUpdating()
                            } else {
                                locationManager.stopUpdating()
                            }
                            Task {
                                try? await authService.updateDriverDutyStatus(isOnDuty: newValue)
                            }
                        }
                    ),
                    assignedCount: assignedOrders.count,
                    availableCount: orderService.availableOrders.count
                )

                Picker("", selection: $selectedTab) {
                    Text("Қолжетімді (\(filteredAvailableOrders.count))").tag(0)
                    Text("Менің (\(assignedOrders.count))").tag(1)
                    Text("Аяқталған (\(completedOrders.count))").tag(2)
                    Text("Карта").tag(3)
                }
                .pickerStyle(.segmented)
                .padding()

                TabView(selection: $selectedTab) {
                    AvailableOrdersView(
                        orders: filteredAvailableOrders,
                        searchQuery: $searchQuery,
                        onlyUrgent: $onlyUrgent,
                        areDocumentsValid: areDocumentsValid,
                        onAcceptOrder: { order in
                            Task { await acceptOrder(order) }
                        }
                    )
                    .tag(0)

                    CurrentDeliveriesView(
                        orders: assignedOrders,
                        onSelectOrder: { order in
                            selectedOrder = order
                        },
                        onStartDelivery: { order in
                            Task { await startDelivery(order) }
                        }
                    )
                    .tag(1)

                    CompletedDeliveriesView(orders: completedOrders)
                        .tag(2)

                    DriverMapView(
                        orders: assignedOrders,
                        driverLocation: locationManager.currentLocation,
                        onSelectOrder: { order in
                            selectedOrder = order
                        }
                    )
                    .tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Жеткізуші панелі")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showVehicleInfo = true
                        } label: {
                            Label("Көлік ақпараты", systemImage: "car")
                        }
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
            .sheet(item: $selectedOrder) { order in
                DriverOrderDetailView(
                    order: order,
                    onStatusUpdate: { orderId, status in
                        Task { await updateOrderStatus(orderId: orderId, status: status) }
                    },
                    onShareLocation: { orderId in
                        Task { await shareLocation(orderId: orderId) }
                    }
                )
            }
            .sheet(isPresented: $showVehicleInfo) {
                VehicleInfoView()
                    .environmentObject(authService)
            }
            .sheet(isPresented: $showProfileSheet) {
                ProfileView()
                    .environmentObject(authService)
            }
            .sheet(isPresented: $showSettingsSheet) {
                SettingsView()
                    .environmentObject(authService)
            }
            .alert("Құжаттар расталмаған", isPresented: $showVerificationRequiredAlert) {
                Button("Құжаттарды ашу") {
                    showVehicleInfo = true
                }
                Button("Жабу", role: .cancel) { }
            } message: {
                Text("Тапсырыс қабылдау үшін барлық көлік құжаттары жүктеліп, администратормен расталуы керек.")
            }
            .alert("Қате", isPresented: Binding(
                get: { errorMessage != nil || orderService.errorMessage != nil },
                set: {
                    if !$0 {
                        errorMessage = nil
                        orderService.errorMessage = nil
                    }
                }
            )) {
                Button("OK", role: .cancel) {
                    errorMessage = nil
                    orderService.errorMessage = nil
                }
            } message: {
                Text(errorMessage ?? orderService.errorMessage ?? "")
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
                isOnDuty = authService.currentUser?.isOnDuty ?? false
                if isOnDuty {
                    locationManager.startUpdating()
                }
                if let driverId = authService.currentUser?.id {
                    orderService.listenToDriverWorkspace(driverId: driverId)
                }
            }
            .onDisappear {
                orderService.stopListening()
                locationManager.stopUpdating()
            }
        }
    }

    private func acceptOrder(_ order: Order) async {
        guard areDocumentsValid else {
            showVerificationRequiredAlert = true
            return
        }
        guard let currentUser = authService.currentUser else { return }

        do {
            try await orderService.assignOrderToDriver(
                orderId: order.id,
                driverId: currentUser.id,
                driverName: currentUser.name,
                driverPhone: currentUser.phone
            )
            selectedTab = 1
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func startDelivery(_ order: Order) async {
        do {
            try await orderService.updateOrderStatus(orderId: order.id, status: .inTransit, note: "Жеткізу басталды")
            selectedTab = 3
        } catch {
            errorMessage = "Статусты өзгерту сәтсіз: \(error.localizedDescription)"
        }
    }

    private func updateOrderStatus(orderId: String, status: OrderStatus) async {
        do {
            try await orderService.updateOrderStatus(orderId: orderId, status: status)
        } catch {
            errorMessage = "Статусты өзгерту сәтсіз: \(error.localizedDescription)"
        }
    }

    private func shareLocation(orderId: String) async {
        locationManager.startUpdating()
        do {
            try await orderService.updateDriverLocation(orderId: orderId, coordinate: locationManager.currentLocation)
        } catch {
            errorMessage = "Геолокацияны жіберу сәтсіз: \(error.localizedDescription)"
        }
    }
}

// MARK: - Driver Header

struct DriverStatusHeader: View {
    @Binding var isOnDuty: Bool
    let assignedCount: Int
    let availableCount: Int

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Жеткізуші")
                        .font(.headline)

                    Text(isOnDuty ? "Жұмыс режимінде" : "Демалыста")
                        .font(.subheadline)
                        .foregroundColor(isOnDuty ? .green : .red)
                }

                Spacer()

                Toggle("", isOn: $isOnDuty)
                    .labelsHidden()
            }

            if isOnDuty {
                HStack(spacing: 16) {
                    StatusInfoView(
                        title: "Қолжетімді",
                        value: "\(availableCount)",
                        color: .blue
                    )

                    StatusInfoView(
                        title: "Белсенді",
                        value: "\(assignedCount)",
                        color: .orange
                    )
                }
            }
        }
        .padding()
        .background(isOnDuty ? Color.blue.opacity(0.1) : Color(.secondarySystemGroupedBackground))
    }
}

struct StatusInfoView: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Available Orders

struct AvailableOrdersView: View {
    let orders: [Order]
    @Binding var searchQuery: String
    @Binding var onlyUrgent: Bool
    let areDocumentsValid: Bool
    let onAcceptOrder: (Order) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                HStack(spacing: 10) {
                    TextField("Қала немесе трек-номер...", text: $searchQuery)
                        .textFieldStyle(.roundedBorder)

                    Toggle(isOn: $onlyUrgent) {
                        Label("Жедел", systemImage: "bolt.fill")
                            .font(.caption)
                    }
                    .toggleStyle(.button)
                    .tint(.orange)
                }

                if orders.isEmpty {
                    EmptyStateView(
                        icon: "tray",
                        title: "Қолжетімді тапсырыс жоқ",
                        message: "Жаңа тапсырыстар пайда болғанда олар осында көрсетіледі"
                    )
                } else {
                    ForEach(orders) { order in
                        AvailableOrderCard(
                            order: order,
                            areDocumentsValid: areDocumentsValid,
                            onAccept: { onAcceptOrder(order) }
                        )
                    }
                }
            }
            .padding()
        }
    }
}

struct AvailableOrderCard: View {
    let order: Order
    let areDocumentsValid: Bool
    let onAccept: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(order.trackNumber)
                        .font(.headline)
                        .fontWeight(.semibold)

                    Text(order.route)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("+\(order.driverEarning.formattedTenge(currency: order.currency))")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.green)

                    Text("ЖАҢА")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.green.opacity(0.2))
                        .foregroundColor(.green)
                        .cornerRadius(6)
                }
            }

            HStack(spacing: 8) {
                Image(systemName: "person.circle.fill")
                    .foregroundColor(.blue)
                Text(order.clientName)
                    .font(.subheadline)
            }

            HStack(spacing: 16) {
                InfoItemView(icon: "shippingbox", text: order.displayPackageType)
                InfoItemView(icon: "scalemass", text: "\(String(format: "%.1f", order.weight)) кг")
                if order.isUrgent {
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Text("Жедел")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }

            Button(areDocumentsValid ? "Тапсырысты қабылдау" : "Құжаттарды растау қажет", action: onAccept)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(areDocumentsValid ? Color.blue : Color.orange)
                .foregroundColor(.white)
                .fontWeight(.semibold)
                .cornerRadius(8)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.06), radius: 3, x: 0, y: 1)
    }
}

// MARK: - Current Deliveries

struct CurrentDeliveriesView: View {
    let orders: [Order]
    let onSelectOrder: (Order) -> Void
    let onStartDelivery: (Order) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if orders.isEmpty {
                    EmptyStateView(
                        icon: "shippingbox",
                        title: "Тапсырыс жоқ",
                        message: "Сізде әлі белсенді тапсырыс жоқ"
                    )
                } else {
                    ForEach(orders) { order in
                        DriverOrderCard(
                            order: order,
                            onSelect: { onSelectOrder(order) },
                            onStart: { onStartDelivery(order) }
                        )
                    }
                }
            }
            .padding()
        }
    }
}

struct DriverOrderCard: View {
    let order: Order
    let onSelect: () -> Void
    let onStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(order.trackNumber)
                        .font(.headline)
                        .fontWeight(.semibold)

                    Text(order.route)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text(order.orderStatus.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(order.orderStatus.color.opacity(0.2))
                    .foregroundColor(order.orderStatus.color)
                    .cornerRadius(6)
            }

            HStack(spacing: 8) {
                Image(systemName: "person.circle.fill")
                    .foregroundColor(.blue)
                Text(order.clientName)
                    .font(.subheadline)
            }

            HStack(spacing: 16) {
                InfoItemView(icon: "clock", text: order.createdAt.formattedShortDateTime())
                InfoItemView(icon: "scalemass", text: "\(String(format: "%.1f", order.weight)) кг")
                Spacer()
                Text("+\(order.driverEarning.formattedTenge(currency: order.currency))")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
            }

            if order.orderStatus == .accepted {
                Button("Жеткізуді бастау", action: onStart)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            } else {
                Button("Мәліметтерді көру", action: onSelect)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.06), radius: 3, x: 0, y: 1)
    }
}

struct InfoItemView: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Completed Deliveries

struct CompletedDeliveriesView: View {
    let orders: [Order]

    private var totalEarnings: Int {
        orders.reduce(0) { $0 + $1.driverEarning }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if !orders.isEmpty {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Жалпы табыс")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(totalEarnings.formattedTenge())
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Жеткізулер")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(orders.count)")
                                .font(.title2)
                                .fontWeight(.bold)
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                }

                if orders.isEmpty {
                    EmptyStateView(
                        icon: "checkmark.circle",
                        title: "Аяқталған жоқ",
                        message: "Сіз әлі ешқандай тапсырысты аяқтаған жоқсыз"
                    )
                } else {
                    ForEach(orders) { order in
                        CompletedOrderCard(order: order)
                    }
                }
            }
            .padding()
        }
    }
}

struct CompletedOrderCard: View {
    let order: Order

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundColor(.green)

            VStack(alignment: .leading, spacing: 4) {
                Text(order.trackNumber)
                    .font(.headline)
                    .fontWeight(.medium)

                Text(order.route)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                if let deliveredAt = order.deliveredAt {
                    Text("Жеткізілді: \(deliveredAt.formattedShortDayMonth())")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Text("+\(order.driverEarning.formattedTenge(currency: order.currency))")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.green)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Driver Map View

struct DriverMapView: View {
    let orders: [Order]
    let driverLocation: CLLocationCoordinate2D
    let onSelectOrder: (Order) -> Void

    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 43.2380, longitude: 76.8829),
            span: MKCoordinateSpan(latitudeDelta: 5.0, longitudeDelta: 5.0)
        )
    )

    private var orderPins: [(order: Order, coordinate: CLLocationCoordinate2D)] {
        orders.compactMap { order in
            guard let coord = CitiesDatabase.getCoordinate(cityName: order.toAddress) else {
                return nil
            }
            return (order, coord)
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            Map(position: $cameraPosition) {
                Annotation("Менің орным", coordinate: driverLocation) {
                    ZStack {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 32, height: 32)
                        Image(systemName: "car.fill")
                            .foregroundColor(.white)
                            .font(.system(size: 14))
                    }
                }

                ForEach(orderPins, id: \.order.id) { item in
                    Annotation(item.order.trackNumber, coordinate: item.coordinate) {
                        Button {
                            onSelectOrder(item.order)
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color.orange)
                                    .frame(width: 32, height: 32)
                                Image(systemName: "shippingbox.fill")
                                    .foregroundColor(.white)
                                    .font(.system(size: 13))
                            }
                        }
                    }
                }
            }
            .ignoresSafeArea()

            VStack {
                HStack {
                    Text("\(orders.count) белсенді тапсырыс")
                        .font(.headline)
                        .padding()
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(10)
                        .shadow(radius: 2)

                    Spacer()
                }
                .padding()

                Spacer()

                HStack(spacing: 12) {
                    DriverActionButton(title: "Менің орным", icon: "location.fill") {
                        withAnimation {
                            cameraPosition = .region(
                                MKCoordinateRegion(
                                    center: driverLocation,
                                    span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
                                )
                            )
                        }
                    }

                    DriverActionButton(title: "Барлық маршрут", icon: "map.fill") {
                        withAnimation {
                            cameraPosition = .region(
                                MKCoordinateRegion(
                                    center: CLLocationCoordinate2D(latitude: 48.0, longitude: 67.0),
                                    span: MKCoordinateSpan(latitudeDelta: 15.0, longitudeDelta: 22.0)
                                )
                            )
                        }
                    }
                }
                .padding()
            }
        }
    }
}

// MARK: - Empty State & Action Button

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 50))
                .foregroundColor(.secondary)

            Text(title)
                .font(.headline)
                .foregroundColor(.primary)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

struct DriverActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity, minHeight: 64)
            .padding(8)
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(10)
            .shadow(radius: 2)
        }
        .buttonStyle(.plain)
        .foregroundColor(.primary)
    }
}

// MARK: - Driver Order Detail View

struct DriverOrderDetailView: View {
    let order: Order
    let onStatusUpdate: (String, OrderStatus) -> Void
    let onShareLocation: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var showStatusPicker = false
    @State private var showRouteError = false
    @State private var showLocationSharedAlert = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 6) {
                        Text("Трек-номер")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(order.trackNumber)
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Табыс: +\(order.driverEarning.formattedTenge(currency: order.currency))")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)

                    // Client info
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Клиент")
                            .font(.headline)

                        HStack {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.blue)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(order.clientName)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Text("Тапсырыс беруші")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                if let phone = order.clientPhone {
                                    Text(phone)
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                }
                            }

                            Spacer()
                        }

                        if let phone = order.clientPhone {
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
                                    .cornerRadius(10)
                                }

                                Button {
                                    ContactHelper.openWhatsApp(
                                        phone: phone,
                                        message: "Сәлеметсіз бе! Сіздің тапсырысыңыз туралы хабарласамын (Трек-номер: \(order.trackNumber))"
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
                                    .cornerRadius(10)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(12)

                    // Route
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Маршрут")
                            .font(.headline)

                        HStack(spacing: 12) {
                            VStack(spacing: 8) {
                                Image(systemName: "circle.fill")
                                    .foregroundColor(.green)
                                    .font(.caption)
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 2, height: 30)
                                Image(systemName: "mappin.circle.fill")
                                    .foregroundColor(.red)
                                    .font(.caption)
                            }

                            VStack(alignment: .leading, spacing: 30) {
                                VStack(alignment: .leading) {
                                    Text("Қайдан")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(order.fromAddress)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }

                                VStack(alignment: .leading) {
                                    Text("Қайда")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(order.toAddress)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }
                            }
                        }

                        Button(action: openRouteInTwoGIS) {
                            HStack {
                                Image(systemName: "location.fill")
                                Text("2ГИС-те маршрут құру")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }

                        Button {
                            onShareLocation(order.id)
                            showLocationSharedAlert = true
                        } label: {
                            HStack {
                                Image(systemName: "location.viewfinder")
                                Text("Клиентке GPS орнымды жіберу")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(12)

                    // Package details
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Пакет туралы")
                            .font(.headline)

                        VStack(alignment: .leading, spacing: 8) {
                            DetailRow(icon: "shippingbox", label: "Түрі", value: order.displayPackageType)
                            DetailRow(icon: "scalemass", label: "Салмағы", value: "\(String(format: "%.1f", order.weight)) кг")
                            DetailRow(icon: "doc.text", label: "Сипаттама", value: order.packageDescription)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(12)

                    // Status
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Статус")
                            .font(.headline)

                        Button {
                            showStatusPicker = true
                        } label: {
                            HStack {
                                Text(order.orderStatus.title)
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color(.tertiarySystemGroupedBackground))
                            .cornerRadius(8)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(12)
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
            .confirmationDialog("Статусты өзгерту", isPresented: $showStatusPicker, titleVisibility: .visible) {
                Button("Жеткізілуде") {
                    onStatusUpdate(order.id, .inTransit)
                }
                Button("Кеденде") {
                    onStatusUpdate(order.id, .atCustoms)
                }
                Button("Жеткізілді") {
                    onStatusUpdate(order.id, .delivered)
                    dismiss()
                }
                Button("Бас тарту", role: .cancel) { }
            }
            .alert("Маршрутты ашу мүмкін емес", isPresented: $showRouteError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Бастапқы немесе соңғы қаланың координаттары табылмады.")
            }
            .alert("Геолокация жаңартылды", isPresented: $showLocationSharedAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Сіздің ағымдағы орныңыз клиентке жіберілді.")
            }
        }
    }

    private func openRouteInTwoGIS() {
        guard let url = TwoGISRouteService.routeURL(
            fromAddress: order.fromAddress,
            toAddress: order.toAddress
        ) else {
            showRouteError = true
            return
        }
        openURL(url)
    }
}

struct DetailRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            Text(label + ":")
                .foregroundColor(.secondary)
                .font(.subheadline)
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

struct DocumentWarningBanner: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title3)
                    .foregroundColor(.white)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Құжаттарды толтырыңыз")
                        .font(.headline)
                        .foregroundColor(.white)

                    Text("Жеткізу жасау үшін барлық құжаттар расталуы қажет")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.9))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.white)
            }
            .padding()
            .background(Color.orange)
        }
        .buttonStyle(.plain)
    }
}
