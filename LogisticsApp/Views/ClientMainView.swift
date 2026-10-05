// ClientMainView.swift
import SwiftUI
import MapKit

struct ClientMainView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var trackingService: TrackingService
    @StateObject private var orderService = OrderService()
    @State private var searchText = ""
    @State private var showNewOrderSheet = false
    @State private var showTariffsSheet = false
    @State private var showMapSheet = false
    @State private var showSearchResult: Shipment?
    @State private var showShipmentDetail: Shipment?
    @State private var showSearchAlert = false
    @State private var showLogoutAlert = false
    @State private var selectedOrder: Order?
    @State private var showOrderDetail = false
    @State private var showRouteMap = false
    @State private var selectedOrderForMap: Order?
    
    // Фильтруем заказы клиента
    var clientOrders: [Order] {
        guard let clientId = authService.currentUser?.id else { return [] }
        return orderService.orders.filter { $0.clientId == clientId }
    }
    
    var activeOrders: [Order] {
        clientOrders.filter { $0.status != "delivered" }
    }
    
    var completedOrders: [Order] {
        clientOrders.filter { $0.status == "delivered" }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Заголовок отслеживания
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Жіберілімді кадағалау")
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
                            
                            // Поисковая строка
                            HStack(spacing: 12) {
                                TextField("Трек-номер енгізіңіз", text: $searchText)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                
                                Button(action: searchShipment) {
                                    Text("Іздеу")
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(Color.blue)
                                        .cornerRadius(8)
                                }
                                .disabled(searchText.isEmpty)
                            }
                        }
                    }
                    
                    // Быстрые действия
                    HStack(spacing: 15) {
                        ActionButton(title: "Жаңа", icon: "plus.circle") {
                            showNewOrderSheet = true
                        }
                        ActionButton(title: "Карта", icon: "map") {
                            showMapSheet = true
                        }
                        ActionButton(title: "Тарифтер", icon: "dollarsign.circle") {
                            showTariffsSheet = true
                        }
                    }
                    
                    // Активные заказы
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
                        
                        if activeOrders.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "shippingbox")
                                    .font(.system(size: 50))
                                    .foregroundColor(.gray)
                                
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
                                        showOrderDetail = true
                                    },
                                    onShowRoute: {
                                        selectedOrderForMap = order
                                        showRouteMap = true
                                    }
                                )
                            }
                        }
                    }
                    
                    // Завершенные заказы
                    if !completedOrders.isEmpty {
                        VStack(alignment: .leading, spacing: 15) {
                            HStack {
                                Text("Аяқталған тапсырыстар")
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
                                        showOrderDetail = true
                                    },
                                    onShowRoute: {
                                        selectedOrderForMap = order
                                        showRouteMap = true
                                    }
                                )
                            }
                            
                            if completedOrders.count > 3 {
                                Button("Барлығын көру (\(completedOrders.count))") {
                                    // Показать все завершенные
                                }
                                .font(.subheadline)
                                .foregroundColor(.blue)
                            }
                        }
                    }
                    
                    // Кнопка создания отправления
                    Button("Жаңа жіберілім жасау") {
                        showNewOrderSheet = true
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding()
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.large)
            .navigationBarItems(
                trailing: Menu {
                    Button("Жеке кабинет", systemImage: "person") {
                        // Жеке кабинет функциясы
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
            .sheet(isPresented: $showNewOrderSheet) {
                NewOrderView()
                    .environmentObject(trackingService)
                    .environmentObject(authService)
            }
            .sheet(isPresented: $showTariffsSheet) {
                TariffsView()
            }
            .sheet(isPresented: $showMapSheet) {
                MapView()
            }
            .sheet(item: $showShipmentDetail) { shipment in
                ShipmentDetailView(shipment: shipment)
            }
            .sheet(item: $showSearchResult) { shipment in
                ShipmentDetailView(shipment: shipment)
            }
            .sheet(item: $selectedOrder) { order in
                ClientOrderDetailView(order: order)
            }
            .sheet(isPresented: $showRouteMap) {
                if let order = selectedOrderForMap {
                    OrderRouteMapView(order: order)
                }
            }
            .alert("Тапсырыс табылмады", isPresented: $showSearchAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Бұл трек-номермен тапсырыс табылмады")
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
                // Подписываемся на заказы клиента
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
        guard !searchText.isEmpty else { return }
        
        if let shipment = trackingService.searchShipment(trackNumber: searchText) {
            showSearchResult = shipment
            searchText = ""
        } else {
            showSearchAlert = true
        }
    }
}

// MARK: - Client Order Card (Улучшенный стиль)

struct ClientOrderCard: View {
    let order: Order
    let onTap: () -> Void
    let onShowRoute: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                // Заголовок с трек-номером
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(order.trackNumber)
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Text(formattedDate(order.createdAt))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Статус
                    Text(statusText)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(statusColor.opacity(0.15))
                        .foregroundColor(statusColor)
                        .cornerRadius(12)
                }
                .padding()
                .background(Color(UIColor.systemGray6))
                
                // Маршрут
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
                        
                        Spacer()
                        
                        // Кнопка карты
                        Button(action: onShowRoute) {
                            Image(systemName: "map.fill")
                                .font(.title3)
                                .foregroundColor(.blue)
                                .padding(8)
                                .background(Color.blue.opacity(0.1))
                                .clipShape(Circle())
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding()
                    
                    // Информация о водителе
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
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                    }
                    
                    // Детали посылки
                    HStack(spacing: 16) {
                        HStack(spacing: 4) {
                            Image(systemName: "shippingbox")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(order.packageType)
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
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                    
                    // Прогресс бар
                    if order.status != "delivered" {
                        ProgressBar(status: order.status)
                            .padding(.horizontal)
                            .padding(.bottom)
                    }
                }
            }
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: .gray.opacity(0.15), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
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

// MARK: - Progress Bar

struct ProgressBar: View {
    let status: String
    
    var progress: CGFloat {
        switch status {
        case "accepted": return 0.25
        case "inTransit": return 0.5
        case "atCustoms": return 0.75
        case "delivered": return 1.0
        default: return 0.0
        }
    }
    
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
    @Environment(\.presentationMode) var presentationMode
    @State private var region: MKCoordinateRegion
    
    init(order: Order) {
        self.order = order
        
        // Определяем координаты
        let fromCoord = cityCoordinates[order.fromAddress] ?? CLLocationCoordinate2D(latitude: 43.2380, longitude: 76.8829)
        let toCoord = cityCoordinates[order.toAddress] ?? CLLocationCoordinate2D(latitude: 51.1694, longitude: 71.4491)
        
        // Центр между точками
        let centerLat = (fromCoord.latitude + toCoord.latitude) / 2
        let centerLon = (fromCoord.longitude + toCoord.longitude) / 2
        
        // Span чтобы показать обе точки
        let latDelta = abs(fromCoord.latitude - toCoord.latitude) * 1.5
        let lonDelta = abs(fromCoord.longitude - toCoord.longitude) * 1.5
        
        _region = State(initialValue: MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
            span: MKCoordinateSpan(latitudeDelta: max(latDelta, 2.0), longitudeDelta: max(lonDelta, 2.0))
        ))
    }
    
    var body: some View {
        NavigationView {
            ZStack(alignment: .top) {
                Map(coordinateRegion: $region, annotationItems: routeAnnotations) { annotation in
                    MapAnnotation(coordinate: annotation.coordinate) {
                        VStack(spacing: 4) {
                            ZStack {
                                Circle()
                                    .fill(annotation.isStart ? Color.green : Color.red)
                                    .frame(width: 40, height: 40)
                                
                                Image(systemName: annotation.isStart ? "circle.fill" : "mappin.circle.fill")
                                    .foregroundColor(.white)
                                    .font(.system(size: 20))
                            }
                            
                            Text(annotation.title)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .padding(4)
                                .background(Color.white)
                                .cornerRadius(4)
                                .shadow(radius: 2)
                        }
                    }
                }
                .ignoresSafeArea()
                
                // Информационная панель
                VStack {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Маршрут")
                                .font(.headline)
                            Text(order.route)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Text(statusText)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(statusColor.opacity(0.15))
                            .foregroundColor(statusColor)
                            .cornerRadius(12)
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(radius: 4)
                    .padding()
                    
                    Spacer()
                }
            }
            .navigationTitle("Маршрут")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Жабу") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
    
    private var routeAnnotations: [RouteAnnotationItem] {
        var annotations: [RouteAnnotationItem] = []
        
        if let fromCoord = cityCoordinates[order.fromAddress] {
            annotations.append(RouteAnnotationItem(
                coordinate: fromCoord,
                title: order.fromAddress,
                isStart: true
            ))
        }
        
        if let toCoord = cityCoordinates[order.toAddress] {
            annotations.append(RouteAnnotationItem(
                coordinate: toCoord,
                title: order.toAddress,
                isStart: false
            ))
        }
        
        return annotations
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
}

struct RouteAnnotationItem: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let title: String
    let isStart: Bool
}

// MARK: - Client Order Detail View (продолжение в следующем файле из-за размера)

// MARK: - Client Order Detail View

struct ClientOrderDetailView: View {
    let order: Order
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
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
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.blue.opacity(0.1), Color.blue.opacity(0.05)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(16)
                    
                    // Статус
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Статус")
                            .font(.headline)
                        
                        HStack {
                            Text(statusText)
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(statusColor)
                            
                            Spacer()
                            
                            Image(systemName: statusIcon)
                                .font(.title)
                                .foregroundColor(statusColor)
                        }
                        .padding()
                        .background(statusColor.opacity(0.1))
                        .cornerRadius(12)
                        
                        // Прогресс
                        OrderProgressView(status: order.status)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(16)
                    .shadow(color: .gray.opacity(0.1), radius: 4, x: 0, y: 2)
                    
                    // Маршрут
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
                    .background(Color.white)
                    .cornerRadius(16)
                    .shadow(color: .gray.opacity(0.1), radius: 4, x: 0, y: 2)
                    
                    // Информация о водителе
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
                            
                            // Кнопки связи с водителем
                            if let phone = order.driverPhone {
                                HStack(spacing: 12) {
                                    // Кнопка звонка
                                    Button(action: {
                                        callDriver(phone: phone)
                                    }) {
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
                                        .cornerRadius(12)
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(16)
                        .shadow(color: .gray.opacity(0.1), radius: 4, x: 0, y: 2)
                    }
                    
                    // Детали посылки
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Пакет туралы")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            DetailRowClient(icon: "shippingbox", label: "Түрі", value: order.packageType)
                            DetailRowClient(icon: "scalemass", label: "Салмағы", value: "\(String(format: "%.1f", order.weight)) кг")
                            DetailRowClient(icon: "doc.text", label: "Сипаттама", value: order.packageDescription)
                            DetailRowClient(icon: "dollarsign.circle", label: "Тариф", value: order.tariffType)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(16)
                    .shadow(color: .gray.opacity(0.1), radius: 4, x: 0, y: 2)
                    
                    // Даты
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Мерзімдер")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            DetailRowClient(icon: "calendar", label: "Жасалды", value: formattedDate(order.createdAt))
                            DetailRowClient(icon: "clock", label: "Болжамды жеткізу", value: formattedDate(order.estimatedDelivery))
                            
                            if let deliveredAt = order.deliveredAt {
                                DetailRowClient(icon: "checkmark.circle", label: "Жеткізілді", value: formattedDate(deliveredAt))
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(16)
                    .shadow(color: .gray.opacity(0.1), radius: 4, x: 0, y: 2)
                }
                .padding()
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Тапсырыс мәліметтері")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Жабу") {
                presentationMode.wrappedValue.dismiss()
            })
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
    
    private var statusColor: Color {
        switch order.status {
        case "accepted": return .blue
        case "inTransit": return .orange
        case "atCustoms": return .yellow
        case "delivered": return .green
        default: return .gray
        }
    }
    
    private var statusIcon: String {
        switch order.status {
        case "accepted": return "checkmark.circle.fill"
        case "inTransit": return "shippingbox.fill"
        case "atCustoms": return "building.2.fill"
        case "delivered": return "checkmark.seal.fill"
        default: return "circle"
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy, HH:mm"
        formatter.locale = Locale(identifier: "kk_KZ")
        return formatter.string(from: date)
    }
    
    // MARK: - Contact Driver Functions
    
    private func callDriver(phone: String) {
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
        
        let message = "Сәлеметсіз бе! Менің тапсырысым туралы сұрағым бар (Трек-номер: \(order.trackNumber))"
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
    
    let steps = [
        ("accepted", "Қабылданды", "checkmark.circle"),
        ("inTransit", "Жеткізілуде", "shippingbox"),
        ("atCustoms", "Кеденде", "building.2"),
        ("delivered", "Жеткізілді", "checkmark.seal")
    ]
    
    var currentStepIndex: Int {
        steps.firstIndex(where: { $0.0 == status }) ?? 0
    }
    
    var body: some View {
        VStack(spacing: 16) {
            ForEach(0..<steps.count, id: \.self) { index in
                let step = steps[index]
                let isCompleted = index <= currentStepIndex
                let isCurrent = index == currentStepIndex
                
                HStack(spacing: 12) {
                    // Иконка
                    ZStack {
                        Circle()
                            .fill(isCompleted ? Color.blue : Color.gray.opacity(0.3))
                            .frame(width: 40, height: 40)
                        
                        Image(systemName: step.2)
                            .foregroundColor(.white)
                            .font(.system(size: 18))
                    }
                    
                    // Текст
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
                
                // Линия между шагами
                if index < steps.count - 1 {
                    Rectangle()
                        .fill(isCompleted ? Color.blue : Color.gray.opacity(0.3))
                        .frame(width: 2, height: 20)
                        .offset(x: 19)
                }
            }
        }
    }
}
