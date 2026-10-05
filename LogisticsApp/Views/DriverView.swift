import SwiftUI
import MapKit

struct DriverView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var trackingService: TrackingService
    @StateObject private var vehicleService = VehicleService()
    @StateObject private var orderService = OrderService()
    @State private var selectedTab = 0
    @State private var selectedOrder: Order?
    @State private var showOrderDetail = false
    @State private var driverLocation = CLLocationCoordinate2D(latitude: 43.2380, longitude: 76.8829)
    @State private var isOnDuty = false
    @State private var currentDelivery: Order?
    @State private var showRouteMap = false
    @State private var showLogoutAlert = false
    @State private var showVehicleInfo = false
    @State private var showDocumentWarning = false
    @State private var documentWarningMessage = ""
    
    // Фильтруем заказы для водителя
    var availableOrders: [Order] {
        orderService.orders.filter { $0.status == "accepted" && $0.driverId == nil }
    }
    
    var assignedOrders: [Order] {
        guard let driverId = authService.currentUser?.id else { return [] }
        return orderService.orders.filter { 
            $0.driverId == driverId && ($0.status == "inTransit" || $0.status == "accepted")
        }
    }
    
    var completedOrders: [Order] {
        guard let driverId = authService.currentUser?.id else { return [] }
        return orderService.orders.filter { $0.driverId == driverId && $0.status == "delivered" }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Предупреждение о документах
                if !vehicleService.areAllDocumentsValid(vehicleInfo: authService.currentUser?.vehicleInfo) {
                    DocumentWarningBanner {
                        showVehicleInfo = true
                    }
                }
                
                // Панель статуса водителя
                DriverStatusHeader(
                    isOnDuty: $isOnDuty,
                    currentDelivery: currentDelivery,
                    assignedCount: assignedOrders.count,
                    availableCount: availableOrders.count
                )
                
                // Сегментированный контрол
                Picker("", selection: $selectedTab) {
                    Text("Қолжетімді (\(availableOrders.count))").tag(0)
                    Text("Менің (\(assignedOrders.count))").tag(1)
                    Text("Аяқталған (\(completedOrders.count))").tag(2)
                    Text("Карта").tag(3)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                // Контент в зависимости от выбранной вкладки
                TabView(selection: $selectedTab) {
                    // Доступные заказы
                    AvailableOrdersView(
                        orders: availableOrders,
                        onAcceptOrder: { order in
                            Task {
                                await acceptOrder(order)
                            }
                        }
                    )
                    .tag(0)
                    
                    // Мои текущие заказы
                    CurrentDeliveriesViewNew(
                        orders: assignedOrders,
                        onSelectOrder: { order in
                            selectedOrder = order
                            showOrderDetail = true
                        },
                        onStartDelivery: { order in
                            Task {
                                await startDelivery(order)
                            }
                        }
                    )
                    .tag(1)
                    
                    // Завершенные заказы
                    CompletedDeliveriesViewNew(orders: completedOrders)
                    .tag(2)
                    
                    // Карта маршрутов
                    DriverMapViewNew(
                        orders: assignedOrders,
                        driverLocation: $driverLocation,
                        onSelectOrder: { order in
                            selectedOrder = order
                            showOrderDetail = true
                        }
                    )
                    .tag(3)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .navigationTitle("Жеткізуші панелі")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Menu {
                    Button("Көлік ақпараты", systemImage: "car") {
                        showVehicleInfo = true
                    }
                    Button("Баптаулар", systemImage: "gearshape") {
                        // Баптаулар функциясы
                    }
                    Button(role: .destructive) {
                        showLogoutAlert = true
                    } label: {
                        Label("Жүйеден шығу", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title2)
                }
            )
            .sheet(item: $selectedOrder) { order in
                DriverOrderDetailView(
                    order: order,
                    onStatusUpdate: { orderId, status in
                        Task {
                            await updateOrderStatus(orderId: orderId, status: status)
                        }
                    }
                )
            }
            .onAppear {
                // Начинаем слушать все заказы для водителя
                orderService.listenToAllOrders()
            }
            .onDisappear {
                orderService.stopListening()
            }

            .sheet(isPresented: $showVehicleInfo) {
                VehicleInfoView()
                    .environmentObject(authService)
            }
            .alert("Жүйеден шығу", isPresented: $showLogoutAlert) {
                Button("Бас тарту", role: .cancel) { }
                Button("Шығу", role: .destructive) {
                    authService.logout()
                }
            } message: {
                Text("Сіз шынымен жүйеден шығғыңыз келе ме?")
            }
        }
    }
    
    private func acceptOrder(_ order: Order) async {
        guard let currentUser = authService.currentUser else { return }
        
        do {
            try await orderService.assignOrderToDriver(
                orderId: order.id,
                driverId: currentUser.id,
                driverName: currentUser.name,
                driverPhone: currentUser.phone
            )
            selectedTab = 1 // Переключаем на "Мои заказы"
        } catch {
            print("Error accepting order: \(error.localizedDescription)")
        }
    }
    
    private func startDelivery(_ order: Order) async {
        currentDelivery = order
        do {
            try await orderService.updateOrderStatus(orderId: order.id, status: "inTransit")
            selectedTab = 3 // Переключаем на карту
        } catch {
            print("Error starting delivery: \(error.localizedDescription)")
        }
    }
    
    private func updateOrderStatus(orderId: String, status: String) async {
        do {
            try await orderService.updateOrderStatus(orderId: orderId, status: status)
            
            if status == "delivered" {
                currentDelivery = nil
            }
        } catch {
            print("Error updating order status: \(error.localizedDescription)")
        }
    }
}

// MARK: - Компоненты панели водителя

struct DriverStatusHeader: View {
    @Binding var isOnDuty: Bool
    let currentDelivery: Order?
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
                
                // Переключатель статуса
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
                        title: "Менің",
                        value: "\(assignedCount)",
                        color: .orange
                    )
                    
                    StatusInfoView(
                        title: "Ағымдағы",
                        value: currentDelivery != nil ? "1" : "0",
                        color: .green
                    )
                }
            }
        }
        .padding()
        .background(isOnDuty ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
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

// MARK: - Доступные заказы

struct AvailableOrdersView: View {
    let orders: [Order]
    let onAcceptOrder: (Order) -> Void
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
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
                            onAccept: {
                                onAcceptOrder(order)
                            }
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
    let onAccept: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Заголовок
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
                
                // Новый заказ
                Text("ЖАҢА")
                    .font(.caption)
                    .fontWeight(.bold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.2))
                    .foregroundColor(.green)
                    .cornerRadius(6)
            }
            
            // Детали клиента
            HStack(spacing: 8) {
                Image(systemName: "person.circle.fill")
                    .foregroundColor(.blue)
                Text(order.clientName)
                    .font(.subheadline)
            }
            
            // Детали заказа
            HStack(spacing: 16) {
                InfoItemView(icon: "shippingbox", text: order.packageType)
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
            
            // Кнопка принятия
            Button("Тапсырысты қабылдау", action: onAccept)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .gray.opacity(0.2), radius: 3, x: 0, y: 1)
    }
}

// MARK: - Текущие заказы

struct CurrentDeliveriesViewNew: View {
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
                            onSelect: {
                                onSelectOrder(order)
                            },
                            onStart: {
                                onStartDelivery(order)
                            }
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
            // Заголовок
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
                
                // Статус
                Text(statusText)
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.2))
                    .foregroundColor(statusColor)
                    .cornerRadius(6)
            }
            
            // Детали клиента
            HStack(spacing: 8) {
                Image(systemName: "person.circle.fill")
                    .foregroundColor(.blue)
                Text(order.clientName)
                    .font(.subheadline)
            }
            
            // Детали
            HStack(spacing: 16) {
                InfoItemView(icon: "clock", text: formattedDate(order.createdAt))
                InfoItemView(icon: "scalemass", text: "\(String(format: "%.1f", order.weight)) кг")
            }
            
            // Кнопки действий
            if order.status == "accepted" {
                Button("Жеткізуді бастау", action: onStart)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            } else {
                Button("Мәліметтерді көру", action: onSelect)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .gray.opacity(0.2), radius: 3, x: 0, y: 1)
    }
    
    private var statusText: String {
        switch order.status {
        case "accepted": return "Қабылданды"
        case "inTransit": return "Жеткізілуде"
        case "atCustoms": return "Кеденде"
        case "delivered": return "Жеткізілді"
        default: return order.status
        }
    }
    
    private var statusColor: Color {
        switch order.status {
        case "accepted": return .blue
        case "inTransit": return .orange
        case "atCustoms": return .yellow
        case "delivered": return .green
        default: return .gray
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM, HH:mm"
        formatter.locale = Locale(identifier: "kk_KZ")
        return formatter.string(from: date)
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

// MARK: - Завершенные заказы

struct CompletedDeliveriesViewNew: View {
    let orders: [Order]
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
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
                    Text("Жеткізілді: \(formattedDate(deliveredAt))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Text("+\(calculateEarnings()) ₸")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.green)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .gray.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private func calculateEarnings() -> Int {
        let baseEarning: Int
        switch order.tariffType {
        case "Экспресс": baseEarning = 2500
        case "Стандартты": baseEarning = 1500
        case "Экономикалық": baseEarning = 800
        case "Халықаралық": baseEarning = 5000
        default: baseEarning = 1500
        }
        return Int(Double(baseEarning) * 0.6) // 60% водителю
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        formatter.locale = Locale(identifier: "kk_KZ")
        return formatter.string(from: date)
    }
}

// MARK: - Карта для водителя

struct DriverMapViewNew: View {
    let orders: [Order]
    @Binding var driverLocation: CLLocationCoordinate2D
    let onSelectOrder: (Order) -> Void
    
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 43.2380, longitude: 76.8829),
        span: MKCoordinateSpan(latitudeDelta: 5.0, longitudeDelta: 5.0)
    )
    
    var body: some View {
        ZStack(alignment: .top) {
            Map(coordinateRegion: $region, annotationItems: mapAnnotations) { annotation in
                MapAnnotation(coordinate: annotation.coordinate) {
                    DriverMapAnnotationView(
                        annotation: annotation,
                        onSelect: {
                            if let order = annotation.order {
                                onSelectOrder(order)
                            }
                        }
                    )
                }
            }
            .ignoresSafeArea()
            
            // Панель информации
            VStack {
                HStack {
                    Text("\(orders.count) белсенді тапсырыс")
                        .font(.headline)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(8)
                        .shadow(radius: 2)
                    
                    Spacer()
                }
                .padding()
                
                Spacer()
                
                // Быстрые действия
                HStack(spacing: 12) {
                    DriverActionButton(title: "Менің орным", icon: "location.fill") {
                        centerOnDriver()
                    }
                    
                    DriverActionButton(title: "Барлық маршрут", icon: "map.fill") {
                        showAllRoutes()
                    }
                }
                .padding()
            }
        }
    }
    
    private var mapAnnotations: [DriverMapAnnotationNew] {
        var annotations: [DriverMapAnnotationNew] = []
        
        // Добавляем местоположение водителя
        annotations.append(DriverMapAnnotationNew(
            coordinate: driverLocation,
            type: .driver,
            title: "Менің орным",
            order: nil
        ))
        
        // Добавляем заказы
        for order in orders {
            if let coord = getCoordinate(for: order.toAddress) {
                annotations.append(DriverMapAnnotationNew(
                    coordinate: coord,
                    type: .delivery,
                    title: order.trackNumber,
                    order: order
                ))
            }
        }
        
        return annotations
    }
    
    private func getCoordinate(for address: String) -> CLLocationCoordinate2D? {
        return cityCoordinates[address]
    }
    
    private func centerOnDriver() {
        withAnimation {
            region.center = driverLocation
            region.span = MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        }
    }
    
    private func showAllRoutes() {
        withAnimation {
            region.center = CLLocationCoordinate2D(latitude: 43.2380, longitude: 76.8829)
            region.span = MKCoordinateSpan(latitudeDelta: 8.0, longitudeDelta: 8.0)
        }
    }
}

struct DriverMapAnnotationNew: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let type: DriverAnnotationType
    let title: String
    let order: Order?
}

struct DriverMapAnnotationView: View {
    let annotation: DriverMapAnnotationNew
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 2) {
                ZStack {
                    Circle()
                        .fill(annotation.type == .driver ? Color.blue : Color.orange)
                        .frame(width: 30, height: 30)
                    
                    Image(systemName: annotation.type == .driver ? "car.fill" : "shippingbox.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 12))
                }
                
                Text(annotation.title)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .padding(2)
                    .background(Color.white)
                    .cornerRadius(2)
            }
        }
    }
}

// MARK: - Empty State View

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 50))
                .foregroundColor(.gray)
            
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
        .background(Color.white)
        .cornerRadius(12)
    }
}

// MARK: - Driver Action Button Component

struct DriverActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity, minHeight: 70)
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
        }
        .buttonStyle(PlainButtonStyle())
        .foregroundColor(.primary)
    }
}

// MARK: - Driver Order Detail View

struct DriverOrderDetailView: View {
    let order: Order
    let onStatusUpdate: (String, String) -> Void
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.openURL) private var openURL
    @State private var showStatusPicker = false
    @State private var showRouteError = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Трек-номер
                    VStack(spacing: 8) {
                        Text("Трек-номер")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(order.trackNumber)
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                    
                    // Информация о клиенте
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
                        
                        // Кнопки связи с клиентом
                        if let phone = order.clientPhone {
                            HStack(spacing: 12) {
                                // Кнопка звонка
                                Button(action: {
                                    callClient(phone: phone)
                                }) {
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
                                
                                // Кнопка WhatsApp
                                Button(action: {
                                    openWhatsApp(phone: phone)
                                }) {
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
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(radius: 2)
                    
                    // Маршрут
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
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(radius: 2)
                    
                    // Детали посылки
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Пакет туралы")
                            .font(.headline)
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 8) {
                                DetailRow(icon: "shippingbox", label: "Түрі", value: order.packageType)
                                DetailRow(icon: "scalemass", label: "Салмағы", value: "\(String(format: "%.1f", order.weight)) кг")
                                DetailRow(icon: "doc.text", label: "Сипаттама", value: order.packageDescription)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(radius: 2)
                    
                    // Статус
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Статус")
                            .font(.headline)
                        
                        Button {
                            showStatusPicker = true
                        } label: {
                            HStack {
                                Text(statusText)
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(radius: 2)
                }
                .padding()
            }
            .navigationTitle("Тапсырыс мәліметтері")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Жабу") {
                presentationMode.wrappedValue.dismiss()
            })
            .actionSheet(isPresented: $showStatusPicker) {
                ActionSheet(
                    title: Text("Статусты өзгерту"),
                    buttons: [
                        .default(Text("Жеткізілуде")) {
                            onStatusUpdate(order.id, "inTransit")
                        },
                        .default(Text("Кеденде")) {
                            onStatusUpdate(order.id, "atCustoms")
                        },
                        .default(Text("Жеткізілді")) {
                            onStatusUpdate(order.id, "delivered")
                            presentationMode.wrappedValue.dismiss()
                        },
                        .cancel(Text("Бас тарту"))
                    ]
                )
            }
            .alert("Маршрутты ашу мүмкін емес", isPresented: $showRouteError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Бастапқы немесе соңғы қаланың координаттары табылмады.")
            }
        }
    }
    
    private var statusText: String {
        switch order.status {
        case "accepted": return "Қабылданды"
        case "inTransit": return "Жеткізілуде"
        case "atCustoms": return "Кеденде"
        case "delivered": return "Жеткізілді"
        default: return order.status
        }
    }
    
    // MARK: - Contact Client Functions

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
    
    private func callClient(phone: String) {
        let cleanPhone = phone.replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")
        
        if let url = URL(string: "tel://\(cleanPhone)") {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            }
        }
    }
    
    private func openWhatsApp(phone: String) {
        var cleanPhone = phone.replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")
            .replacingOccurrences(of: "+", with: "")
        
        if cleanPhone.hasPrefix("8") {
            cleanPhone = "7" + cleanPhone.dropFirst()
        }
        
        if !cleanPhone.hasPrefix("7") && cleanPhone.count == 10 {
            cleanPhone = "7" + cleanPhone
        }
        
        let message = "Сәлеметсіз бе! Сіздің тапсырысыңыз туралы хабарласамын (Трек-номер: \(order.trackNumber))"
        let encodedMessage = message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        let whatsappURL = "https://wa.me/\(cleanPhone)?text=\(encodedMessage)"
        
        if let url = URL(string: whatsappURL) {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            } else {
                if let webURL = URL(string: "https://web.whatsapp.com/send?phone=\(cleanPhone)&text=\(encodedMessage)") {
                    UIApplication.shared.open(webURL)
                }
            }
        }
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

// MARK: - Document Warning Banner

struct DocumentWarningBanner: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title3)
                    .foregroundColor(.orange)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Құжаттарды толтырыңыз")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text("Жеткізу жасау үшін барлық құжаттар қажет")
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
        .buttonStyle(PlainButtonStyle())
    }
}
