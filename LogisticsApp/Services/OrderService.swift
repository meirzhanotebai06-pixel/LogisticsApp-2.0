import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

class OrderService: ObservableObject {
    private let db = Firestore.firestore()
    @Published var orders: [Order] = []
    @Published var isLoading = false
    
    private var ordersListener: ListenerRegistration?
    
    // MARK: - Create Order
    
    func createOrder(
        clientId: String,
        clientName: String,
        clientPhone: String?,
        fromAddress: String,
        toAddress: String,
        packageDescription: String,
        weight: Double,
        packageType: PackageType,
        tariffType: TariffType,
        insurance: Bool,
        urgentDelivery: Bool
    ) async throws -> Order {
        
        let trackNumber = generateTrackNumber()
        let calendar = Calendar.current
        let estimatedDelivery = calendar.date(byAdding: .day, value: tariffType == .express ? 2 : 7, to: Date())!
        
        let order = Order(
            id: UUID().uuidString,
            trackNumber: trackNumber,
            clientId: clientId,
            clientName: clientName,
            clientPhone: clientPhone,
            driverId: nil,
            driverName: nil,
            driverPhone: nil,
            fromAddress: fromAddress,
            toAddress: toAddress,
            route: "\(fromAddress) → \(toAddress)",
            packageDescription: packageDescription,
            weight: weight,
            packageType: packageType.rawValue,
            tariffType: tariffType.rawValue,
            status: "accepted",
            hasInsurance: insurance,
            isUrgent: urgentDelivery,
            createdAt: Date(),
            estimatedDelivery: estimatedDelivery,
            deliveredAt: nil
        )
        
        let orderData = orderToDict(order)
        
        try await db.collection("orders").document(order.id).setData(orderData)
        
        return order
    }
    
    // MARK: - Listen to All Orders (for Drivers)
    
    func listenToAllOrders() {
        ordersListener?.remove()
        
        ordersListener = db.collection("orders")
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("Error listening to orders: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                self.orders = documents.compactMap { doc -> Order? in
                    return Order.fromDictionary(doc.data())
                }
            }
    }
    
    // MARK: - Listen to Client Orders
    
    func listenToClientOrders(clientId: String) {
        ordersListener?.remove()
        
        ordersListener = db.collection("orders")
            .whereField("clientId", isEqualTo: clientId)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("Error listening to client orders: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                self.orders = documents.compactMap { doc -> Order? in
                    return Order.fromDictionary(doc.data())
                }
            }
    }
    
    // MARK: - Listen to Driver Orders
    
    func listenToDriverOrders(driverId: String) {
        ordersListener?.remove()
        
        ordersListener = db.collection("orders")
            .whereField("driverId", isEqualTo: driverId)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("Error listening to driver orders: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                self.orders = documents.compactMap { doc -> Order? in
                    return Order.fromDictionary(doc.data())
                }
            }
    }
    
    // MARK: - Assign Order to Driver
    
    func assignOrderToDriver(orderId: String, driverId: String, driverName: String, driverPhone: String? = nil) async throws {
        var updateData: [String: Any] = [
            "driverId": driverId,
            "driverName": driverName,
            "status": "inTransit"
        ]
        
        if let phone = driverPhone {
            updateData["driverPhone"] = phone
        }
        
        try await db.collection("orders").document(orderId).updateData(updateData)
    }
    
    // MARK: - Update Order Status
    
    func updateOrderStatus(orderId: String, status: String) async throws {
        var updateData: [String: Any] = ["status": status]
        
        if status == "delivered" {
            updateData["deliveredAt"] = Timestamp(date: Date())
        }
        
        try await db.collection("orders").document(orderId).updateData(updateData)
    }
    
    // MARK: - Stop Listening
    
    func stopListening() {
        ordersListener?.remove()
        ordersListener = nil
    }
    
    // MARK: - Helper Methods
    
    private func generateTrackNumber() -> String {
        let numbers = "0123456789"
        let countryCode = "KZ"
        let randomNumbers = (0..<9).map { _ in numbers.randomElement()! }
        return "\(countryCode)\(String(randomNumbers))"
    }
    
    private func orderToDict(_ order: Order) -> [String: Any] {
        var dict: [String: Any] = [
            "id": order.id,
            "trackNumber": order.trackNumber,
            "clientId": order.clientId,
            "clientName": order.clientName,
            "fromAddress": order.fromAddress,
            "toAddress": order.toAddress,
            "route": order.route,
            "packageDescription": order.packageDescription,
            "weight": order.weight,
            "packageType": order.packageType,
            "tariffType": order.tariffType,
            "status": order.status,
            "hasInsurance": order.hasInsurance,
            "isUrgent": order.isUrgent,
            "createdAt": Timestamp(date: order.createdAt),
            "estimatedDelivery": Timestamp(date: order.estimatedDelivery)
        ]
        
        if let clientPhone = order.clientPhone {
            dict["clientPhone"] = clientPhone
        }
        
        if let driverId = order.driverId {
            dict["driverId"] = driverId
        }
        
        if let driverName = order.driverName {
            dict["driverName"] = driverName
        }
        
        if let driverPhone = order.driverPhone {
            dict["driverPhone"] = driverPhone
        }
        
        if let deliveredAt = order.deliveredAt {
            dict["deliveredAt"] = Timestamp(date: deliveredAt)
        }
        
        return dict
    }
    
    deinit {
        stopListening()
    }
}

// MARK: - Order Model

struct Order: Identifiable, Codable {
    let id: String
    let trackNumber: String
    let clientId: String
    let clientName: String
    let clientPhone: String?
    var driverId: String?
    var driverName: String?
    var driverPhone: String?
    let fromAddress: String
    let toAddress: String
    let route: String
    let packageDescription: String
    let weight: Double
    let packageType: String
    let tariffType: String
    var status: String // "accepted", "inTransit", "atCustoms", "delivered"
    let hasInsurance: Bool
    let isUrgent: Bool
    let createdAt: Date
    let estimatedDelivery: Date
    var deliveredAt: Date?
    
    static func fromDictionary(_ dict: [String: Any]) -> Order? {
        guard let id = dict["id"] as? String,
              let trackNumber = dict["trackNumber"] as? String,
              let clientId = dict["clientId"] as? String,
              let clientName = dict["clientName"] as? String,
              let fromAddress = dict["fromAddress"] as? String,
              let toAddress = dict["toAddress"] as? String,
              let route = dict["route"] as? String,
              let packageDescription = dict["packageDescription"] as? String,
              let weight = dict["weight"] as? Double,
              let packageType = dict["packageType"] as? String,
              let tariffType = dict["tariffType"] as? String,
              let status = dict["status"] as? String,
              let hasInsurance = dict["hasInsurance"] as? Bool,
              let isUrgent = dict["isUrgent"] as? Bool,
              let createdAtTimestamp = dict["createdAt"] as? Timestamp,
              let estimatedDeliveryTimestamp = dict["estimatedDelivery"] as? Timestamp else {
            return nil
        }
        
        let clientPhone = dict["clientPhone"] as? String
        let driverId = dict["driverId"] as? String
        let driverName = dict["driverName"] as? String
        let driverPhone = dict["driverPhone"] as? String
        let deliveredAtTimestamp = dict["deliveredAt"] as? Timestamp
        
        return Order(
            id: id,
            trackNumber: trackNumber,
            clientId: clientId,
            clientName: clientName,
            clientPhone: clientPhone,
            driverId: driverId,
            driverName: driverName,
            driverPhone: driverPhone,
            fromAddress: fromAddress,
            toAddress: toAddress,
            route: route,
            packageDescription: packageDescription,
            weight: weight,
            packageType: packageType,
            tariffType: tariffType,
            status: status,
            hasInsurance: hasInsurance,
            isUrgent: isUrgent,
            createdAt: createdAtTimestamp.dateValue(),
            estimatedDelivery: estimatedDeliveryTimestamp.dateValue(),
            deliveredAt: deliveredAtTimestamp?.dateValue()
        )
    }
}
