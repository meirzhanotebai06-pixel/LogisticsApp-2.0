import SwiftUI
import CoreLocation

struct ShipmentDetailView: View {
    let shipment: Shipment
    @Environment(\.presentationMode) var presentationMode
    @State private var showRouteMap = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Негізгі ақпарат
                    VStack(spacing: 16) {
                        // Трек номері
                        HStack {
                            Text("Трек-номер:")
                                .font(.headline)
                            Spacer()
                            Text(shipment.trackNumber)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                        }
                        
                        // Маршрут
                        HStack {
                            Text("Маршрут:")
                                .font(.headline)
                            Spacer()
                            Text(shipment.route)
                                .font(.title3)
                                .fontWeight(.semibold)
                        }
                        
                        // Статус
                        HStack {
                            Text("Статус:")
                                .font(.headline)
                            Spacer()
                            Text(shipment.status.rawValue)
                                .font(.headline)
                                .foregroundColor(statusColor)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(statusColor.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(color: .gray.opacity(0.2), radius: 3, x: 0, y: 2)
                    
                    // Уақыт ақпараты
                    VStack(spacing: 16) {
                        Text("Уақыт ақпараты")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        DetailInfoRow(title: "Жіберілген күні:", value: formattedDate(shipment.date))
                        DetailInfoRow(title: "Болжамды жеткізу:", value: formattedDate(shipment.estimatedDelivery ?? shipment.date))
                        DetailInfoRow(title: "Қалған уақыт:", value: remainingTime)
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(color: .gray.opacity(0.2), radius: 3, x: 0, y: 2)
                    
                    // Баға және төлем
                    VStack(spacing: 16) {
                        Text("Төлем ақпараты")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        DetailInfoRow(title: "Тариф:", value: tariffForShipment(shipment))
                        DetailInfoRow(title: "Бағасы:", value: priceForShipment(shipment))
                        DetailInfoRow(title: "Төлем статусы:", value: "Төленген")
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(color: .gray.opacity(0.2), radius: 3, x: 0, y: 2)
                    
                    // Қосымша ақпарат
                    VStack(spacing: 16) {
                        Text("Қосымша ақпарат")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        DetailInfoRow(title: "Пакет түрі:", value: packageTypeForShipment(shipment))
                        DetailInfoRow(title: "Салмағы:", value: "\(weightForShipment(shipment)) кг")
                        DetailInfoRow(title: "Жеткізу түрі:", value: deliveryTypeForShipment(shipment))
                        DetailInfoRow(title: "Қашықтық:", value: "\(calculatedDistance) км")
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(color: .gray.opacity(0.2), radius: 3, x: 0, y: 2)
                    
                    // Іс-әрекеттер
                    VStack(spacing: 12) {
                        Button("Картада көру") {
                            showRouteMap = true
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        
                        // ShipmentDetailView.swift қосымша бөлігі
                        // Іс-әрекеттер бөліміне мына түймені қосыңыз:

                        Button("Курьерге хабарласу") {
                            // Хабарласу логикасы
                            if let url = URL(string: "tel://+77771234567") {
                                UIApplication.shared.open(url)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        
                        Button("Құжатты жүктеу") {
                            // Құжат жүктеу
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        
                
                    }
                    .padding()
                }
                .padding()
            }
            .navigationTitle("Тапсырыс ақпараты")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Жабу") {
                presentationMode.wrappedValue.dismiss()
            })
            .sheet(isPresented: $showRouteMap) {
                RouteMapView(shipment: shipment)
            }
        }
    }
    
    // Статус бойынша түс
    private var statusColor: Color {
        switch shipment.status {
        case .accepted: return .blue
        case .inTransit: return .orange
        case .atCustoms: return .yellow
        case .delivered: return .green
        }
    }
    
    // Қалған уақыт
    private var remainingTime: String {
        guard let deliveryDate = shipment.estimatedDelivery else {
            return "Анықталмаған"
        }
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day, .hour], from: Date(), to: deliveryDate)
        
        if let days = components.day, days > 0 {
            return "\(days) күн"
        } else if let hours = components.hour, hours > 0 {
            return "\(hours) сағат"
        } else {
            return "Бүгін"
        }
    }
    
    // Күнді форматтау
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMMM yyyy, HH:mm"
        formatter.locale = Locale(identifier: "kk_KZ")
        return formatter.string(from: date)
    }
    
    // Тарифті анықтау
    private func tariffForShipment(_ shipment: Shipment) -> String {
        if shipment.route.contains("→") {
            let cities = shipment.route.components(separatedBy: " → ")
            if cities.count == 2 {
                let from = cities[0]
                let to = cities[1]
                
                if from == "Алматы" && to == "Астана" {
                    return "Экспресс жеткізу"
                } else if from == "Новосибирск" && to == "Алматы" {
                    return "Халықаралық жеткізу"
                } else if from == "Урумчи" && to == "Шымкент" {
                    return "Халықаралық жеткізу"
                }
            }
        }
        return "Стандартты жеткізу"
    }
    
    // Бағаны анықтау
    private func priceForShipment(_ shipment: Shipment) -> String {
        let tariff = tariffForShipment(shipment)
        switch tariff {
        case "Экспресс жеткізу": return "2 500 ₸"
        case "Халықаралық жеткізу": return "5 000 ₸"
        default: return "1 500 ₸"
        }
    }
    
    // Пакет түрін анықтау
    private func packageTypeForShipment(_ shipment: Shipment) -> String {
        if shipment.trackNumber.hasPrefix("KZ") {
            return "Орташа пакет"
        } else if shipment.trackNumber.hasPrefix("RU") {
            return "Үлкен пакет"
        } else if shipment.trackNumber.hasPrefix("CN") {
            return "Паллета"
        }
        return "Шағын пакет"
    }
    
    // Салмақты анықтау
    private func weightForShipment(_ shipment: Shipment) -> Double {
        if shipment.trackNumber.hasPrefix("KZ") {
            return 2.5
        } else if shipment.trackNumber.hasPrefix("RU") {
            return 5.0
        } else if shipment.trackNumber.hasPrefix("CN") {
            return 15.0
        }
        return 1.0
    }
    
    // Жеткізу түрін анықтау
    private func deliveryTypeForShipment(_ shipment: Shipment) -> String {
        switch shipment.status {
        case .accepted: return "Дайындалуда"
        case .inTransit: return "Жолда"
        case .atCustoms: return "Кеденде"
        case .delivered: return "Жеткізілді"
        }
    }
    
    // Қашықтықты есептеу
    private var calculatedDistance: Int {
        if let coords = shipment.routeCoordinates {
            let fromLocation = CLLocation(latitude: coords.from.latitude, longitude: coords.from.longitude)
            let toLocation = CLLocation(latitude: coords.to.latitude, longitude: coords.to.longitude)
            let distance = fromLocation.distance(from: toLocation) / 1000 // км-ге айналдыру
            return Int(distance)
        }
        return 0
    }
}

// DetailInfoRow компоненті
struct DetailInfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.body)
                .fontWeight(.semibold)
        }
    }
}
