/*import Foundation
import Combine

class TrackingService: ObservableObject {
    @Published var shipments: [Shipment] = []
    
    init() {
        loadSampleData()
    }
    
    private func loadSampleData() {
        let calendar = Calendar.current
        
        shipments = [
            Shipment(
                trackNumber: "KZ123456789",
                route: "Алматы → Астана",
                status: .inTransit,
                date: calendar.date(byAdding: .day, value: -2, to: Date())!,
                estimatedDelivery: calendar.date(byAdding: .day, value: 3, to: Date())!
            ),
            Shipment(
                trackNumber: "RU987654321",
                route: "Новосибирск → Алматы",
                status: .atCustoms,
                date: calendar.date(byAdding: .day, value: -1, to: Date())!,
                estimatedDelivery: calendar.date(byAdding: .day, value: 6, to: Date())!
            ),
            Shipment(
                trackNumber: "CN556677889",
                route: "Урумчи → Шымкент",
                status: .accepted,
                date: Date(),
                estimatedDelivery: calendar.date(byAdding: .day, value: 8, to: Date())!
            )
        ]
    }
    
    func createNewShipment(fromAddress: String, toAddress: String, packageDescription: String, weight: Double) -> Shipment {
        let newTrackNumber = generateTrackNumber()
        let calendar = Calendar.current
        
        let newShipment = Shipment(
            trackNumber: newTrackNumber,
            route: "\(fromAddress) → \(toAddress)",
            status: .accepted,
            date: Date(),
            estimatedDelivery: calendar.date(byAdding: .day, value: 7, to: Date())!
        )
        
        shipments.insert(newShipment, at: 0)
        return newShipment
    }
    
    private func generateTrackNumber() -> String {
        let numbers = "0123456789"
        let countryCode = ["KZ", "RU", "CN", "US"].randomElement()!
        let randomNumbers = (0..<9).map { _ in numbers.randomElement()! }
        let trackNumber = "\(countryCode)\(String(randomNumbers))"
        
        return trackNumber
    }
    
    func searchShipment(trackNumber: String) -> Shipment? {
        return shipments.first { $0.trackNumber.lowercased() == trackNumber.lowercased() }
    }
}*/


/*import Foundation
import Combine

class TrackingService: ObservableObject {
    @Published var shipments: [Shipment] = []
    
    init() {
        loadSampleData()
    }
    
    private func loadSampleData() {
        let calendar = Calendar.current
        
        shipments = [
            Shipment(
                trackNumber: "KZ123456789",
                route: "Алматы → Астана",
                status: .accepted,
                date: calendar.date(byAdding: .day, value: -2, to: Date())!,
                estimatedDelivery: calendar.date(byAdding: .day, value: 3, to: Date())!
            ),
            Shipment(
                trackNumber: "RU987654321",
                route: "Новосибирск → Алматы",
                status: .inTransit,
                date: calendar.date(byAdding: .day, value: -1, to: Date())!,
                estimatedDelivery: calendar.date(byAdding: .day, value: 6, to: Date())!
            ),
            Shipment(
                trackNumber: "CN556677889",
                route: "Урумчи → Шымкент",
                status: .accepted,
                date: Date(),
                estimatedDelivery: calendar.date(byAdding: .day, value: 8, to: Date())!
            ),
            Shipment(
                trackNumber: "KZ111222333",
                route: "Астана → Қарағанды",
                status: .delivered,
                date: calendar.date(byAdding: .day, value: -5, to: Date())!,
                estimatedDelivery: calendar.date(byAdding: .day, value: -2, to: Date())!
            )
        ]
    }
    
    func createNewShipment(fromAddress: String, toAddress: String, packageDescription: String, weight: Double) -> Shipment {
        let newTrackNumber = generateTrackNumber()
        let calendar = Calendar.current
        
        let newShipment = Shipment(
            trackNumber: newTrackNumber,
            route: "\(fromAddress) → \(toAddress)",
            status: .accepted,
            date: Date(),
            estimatedDelivery: calendar.date(byAdding: .day, value: 7, to: Date())!
        )
        
        shipments.insert(newShipment, at: 0)
        return newShipment
    }
    
    private func generateTrackNumber() -> String {
        let numbers = "0123456789"
        let countryCode = ["KZ", "RU", "CN", "US"].randomElement()!
        let randomNumbers = (0..<9).map { _ in numbers.randomElement()! }
        let trackNumber = "\(countryCode)\(String(randomNumbers))"
        
        return trackNumber
    }
    
    func searchShipment(trackNumber: String) -> Shipment? {
        return shipments.first { $0.trackNumber.lowercased() == trackNumber.lowercased() }
    }
    
    // Новый метод для обновления статуса заказа
    func updateShipmentStatus(trackNumber: String, newStatus: ShipmentStatus) {
        if let index = shipments.firstIndex(where: { $0.trackNumber == trackNumber }) {
            let shipment = shipments[index]
            shipments[index] = Shipment(
                trackNumber: shipment.trackNumber,
                route: shipment.route,
                status: newStatus,
                date: shipment.date,
                estimatedDelivery: shipment.estimatedDelivery
            )
        }
    }
}*/


import Foundation
import Combine

class TrackingService: ObservableObject {
    @Published var shipments: [Shipment] = []
    
    init() {
        loadSampleData()
    }
    
    private func loadSampleData() {
        let calendar = Calendar.current
    }
    
    func createNewShipment(fromAddress: String, toAddress: String, packageDescription: String, weight: Double) -> Shipment {
        let newTrackNumber = generateTrackNumber()
        let calendar = Calendar.current
        
        let newShipment = Shipment(
            trackNumber: newTrackNumber,
            route: "\(fromAddress) → \(toAddress)",
            status: .accepted,
            date: Date(),
            estimatedDelivery: calendar.date(byAdding: .day, value: 7, to: Date())!,
            shipmentDetails: createDefaultShipmentDetails(from: fromAddress, to: toAddress, description: packageDescription, weight: weight)
        )
        
        shipments.insert(newShipment, at: 0)
        return newShipment
    }
    
    private func createDefaultShipmentDetails(from: String, to: String, description: String, weight: Double) -> ShipmentDetails {
        return ShipmentDetails(
            sender: ContactInfo(
                name: "Жіберуші",
                phone: "+77001234567",
                address: from,
                email: nil
            ),
            receiver: ContactInfo(
                name: "Алушы",
                phone: "+77009876543",
                address: to,
                email: nil
            ),
            packageInfo: PackageInfo(
                description: description,
                weight: weight,
                dimensions: "30x20x15 см",
                packageType: .medium,
                value: nil,
                fragile: false
            ),
            payment: PaymentInfo(
                amount: 1500,
                currency: "₸",
                paymentMethod: "Карта",
                isPaid: true
            ),
            additionalServices: []
        )
    }
    
    private func generateTrackNumber() -> String {
        let numbers = "0123456789"
        let countryCode = ["KZ", "RU", "CN", "US"].randomElement()!
        let randomNumbers = (0..<9).map { _ in numbers.randomElement()! }
        let trackNumber = "\(countryCode)\(String(randomNumbers))"
        
        return trackNumber
    }
    
    func searchShipment(trackNumber: String) -> Shipment? {
        return shipments.first { $0.trackNumber.lowercased() == trackNumber.lowercased() }
    }
    
    func updateShipmentStatus(trackNumber: String, newStatus: ShipmentStatus) {
        if let index = shipments.firstIndex(where: { $0.trackNumber == trackNumber }) {
            let shipment = shipments[index]
            shipments[index] = Shipment(
                trackNumber: shipment.trackNumber,
                route: shipment.route,
                status: newStatus,
                date: shipment.date,
                estimatedDelivery: shipment.estimatedDelivery,
                shipmentDetails: shipment.shipmentDetails
            )
        }
    }
}
