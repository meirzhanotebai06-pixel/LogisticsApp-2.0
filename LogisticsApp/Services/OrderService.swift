import Foundation
import CoreLocation
import Combine
import OSLog
import FirebaseFirestore

@MainActor
class OrderService: ObservableObject {
    private let db = Firestore.firestore()
    private let logger = Logger(subsystem: "com.meirzhan.LogisticsApp", category: "orders")

    @Published var orders: [Order] = []
    @Published var availableOrders: [Order] = []
    @Published var myOrders: [Order] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var clientOrdersListener: ListenerRegistration?
    private var availableOrdersListener: ListenerRegistration?
    private var driverOrdersListener: ListenerRegistration?

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
        price: Int,
        insurance: Bool,
        urgentDelivery: Bool
    ) async throws -> Order {
        let trackNumber = generateTrackNumber()
        let now = Date()
        let estimatedDelivery = Calendar.current.date(byAdding: .day, value: tariffType.deliveryDays, to: now) ?? now
        let driverEarning = Int(Double(price) * 0.7)

        let initialEvent = OrderStatusEvent(
            status: OrderStatus.accepted.rawValue,
            timestamp: now,
            note: "Тапсырыс жасалды"
        )

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
            packageDescription: packageDescription.trimmingCharacters(in: .whitespacesAndNewlines),
            weight: weight,
            packageType: packageType.storageKey,
            tariffType: tariffType.storageKey,
            status: OrderStatus.accepted.rawValue,
            hasInsurance: insurance,
            isUrgent: urgentDelivery,
            price: price,
            currency: "₸",
            driverEarning: driverEarning,
            createdAt: now,
            estimatedDelivery: estimatedDelivery,
            deliveredAt: nil,
            cancelledAt: nil,
            statusHistory: [initialEvent],
            driverLocation: nil
        )

        let orderData = orderToDict(order)
        try await db.collection("orders").document(order.id).setData(orderData)
        return order
    }

    // MARK: - Listen to Client Orders

    func listenToClientOrders(clientId: String) {
        stopListening()
        isLoading = true

        clientOrdersListener = db.collection("orders")
            .whereField("clientId", isEqualTo: clientId)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.isLoading = false

                    if let error {
                        self.logger.error("Client orders listener error: \(error.localizedDescription, privacy: .public)")
                        self.errorMessage = "Тапсырыстарды жүктеу сәтсіз: \(error.localizedDescription)"
                        return
                    }

                    self.orders = snapshot?.documents.compactMap { Order.fromDictionary($0.data()) } ?? []
                }
            }
    }

    // MARK: - Listen to Driver Workspace (2 secure queries)

    func listenToDriverWorkspace(driverId: String) {
        stopListening()
        isLoading = true

        availableOrdersListener = db.collection("orders")
            .whereField("status", isEqualTo: OrderStatus.accepted.rawValue)
            .whereField("driverId", isEqualTo: NSNull())
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.isLoading = false

                    if let error {
                        self.logger.error("Available orders listener error: \(error.localizedDescription, privacy: .public)")
                        self.errorMessage = "Қолжетімді тапсырыстарды жүктеу қатесі: \(error.localizedDescription)"
                        return
                    }

                    self.availableOrders = snapshot?.documents.compactMap { Order.fromDictionary($0.data()) } ?? []
                }
            }

        driverOrdersListener = db.collection("orders")
            .whereField("driverId", isEqualTo: driverId)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.isLoading = false

                    if let error {
                        self.logger.error("Driver orders listener error: \(error.localizedDescription, privacy: .public)")
                        self.errorMessage = "Жүргізуші тапсырыстарын жүктеу қатесі: \(error.localizedDescription)"
                        return
                    }

                    self.myOrders = snapshot?.documents.compactMap { Order.fromDictionary($0.data()) } ?? []
                }
            }
    }

    // MARK: - Assign Order to Driver (Atomic Transaction)

    func assignOrderToDriver(
        orderId: String,
        driverId: String,
        driverName: String,
        driverPhone: String? = nil
    ) async throws {
        let orderRef = db.collection("orders").document(orderId)
        let now = Date()

        _ = try await db.runTransaction { transaction, errorPointer in
            let snapshot: DocumentSnapshot
            do {
                snapshot = try transaction.getDocument(orderRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }

            guard let data = snapshot.data() else {
                errorPointer?.pointee = NSError(
                    domain: "OrderService",
                    code: 404,
                    userInfo: [NSLocalizedDescriptionKey: "Тапсырыс табылмады"]
                )
                return nil
            }

            let existingDriver = data["driverId"] as? String
            let currentStatus = data["status"] as? String
            guard existingDriver == nil, currentStatus == OrderStatus.accepted.rawValue else {
                errorPointer?.pointee = NSError(
                    domain: "OrderService",
                    code: 409,
                    userInfo: [NSLocalizedDescriptionKey: "Бұл тапсырысты басқа жүргізуші қабылдап қойған"]
                )
                return nil
            }

            var history = data["statusHistory"] as? [[String: Any]] ?? []
            history.append(
                OrderStatusEvent(
                    status: OrderStatus.inTransit.rawValue,
                    timestamp: now,
                    note: "Жүргізуші тағайындалды: \(driverName)"
                ).toDict()
            )

            var updateData: [String: Any] = [
                "driverId": driverId,
                "driverName": driverName,
                "status": OrderStatus.inTransit.rawValue,
                "acceptedAt": Timestamp(date: now),
                "updatedAt": Timestamp(date: now),
                "statusHistory": history
            ]
            if let driverPhone {
                updateData["driverPhone"] = driverPhone
            }

            transaction.updateData(updateData, forDocument: orderRef)
            return nil
        }
    }

    // MARK: - Update Order Status

    func updateOrderStatus(orderId: String, status: OrderStatus, note: String? = nil) async throws {
        let now = Date()
        let event = OrderStatusEvent(status: status.rawValue, timestamp: now, note: note)

        var updateData: [String: Any] = [
            "status": status.rawValue,
            "updatedAt": Timestamp(date: now),
            "statusHistory": FieldValue.arrayUnion([event.toDict()])
        ]

        if status == .delivered {
            updateData["deliveredAt"] = Timestamp(date: now)
        }

        try await db.collection("orders").document(orderId).updateData(updateData)
    }

    // MARK: - Cancel Order (Client)

    func cancelOrder(orderId: String) async throws {
        let now = Date()
        let event = OrderStatusEvent(
            status: OrderStatus.cancelled.rawValue,
            timestamp: now,
            note: "Клиент тапсырысты болдырмады"
        )

        try await db.collection("orders").document(orderId).updateData([
            "status": OrderStatus.cancelled.rawValue,
            "cancelledAt": Timestamp(date: now),
            "updatedAt": Timestamp(date: now),
            "statusHistory": FieldValue.arrayUnion([event.toDict()])
        ])
    }

    // MARK: - Update Driver Live Location

    func updateDriverLocation(orderId: String, coordinate: CLLocationCoordinate2D) async throws {
        let locationData = GeoPointData(latitude: coordinate.latitude, longitude: coordinate.longitude).toDict()
        try await db.collection("orders").document(orderId).updateData([
            "driverLocation": locationData,
            "updatedAt": Timestamp(date: Date())
        ])
    }

    // MARK: - Search Order by Track Number

    func searchOrder(byTrackNumber query: String) -> Order? {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return nil }
        return orders.first { $0.trackNumber.lowercased() == normalized }
    }

    // MARK: - Reviews

    func submitReview(
        order: Order,
        clientId: String,
        clientName: String,
        rating: Int,
        comment: String
    ) async throws {
        guard let driverId = order.driverId else { return }
        let clampedRating = min(max(rating, 1), 5)
        let review = Review(
            id: UUID().uuidString,
            orderId: order.id,
            driverId: driverId,
            clientId: clientId,
            clientName: clientName,
            rating: clampedRating,
            comment: comment.trimmingCharacters(in: .whitespacesAndNewlines),
            createdAt: Date()
        )
        try await db.collection("reviews").document(review.id).setData(review.toDict())
    }

    // MARK: - Stop Listening

    func stopListening() {
        clientOrdersListener?.remove()
        clientOrdersListener = nil
        availableOrdersListener?.remove()
        availableOrdersListener = nil
        driverOrdersListener?.remove()
        driverOrdersListener = nil
    }

    // MARK: - Helpers

    private func generateTrackNumber() -> String {
        let numbers = "0123456789"
        let randomNumbers = (0..<9).map { _ in numbers.randomElement()! }
        return "KZ\(String(randomNumbers))"
    }

    private func orderToDict(_ order: Order) -> [String: Any] {
        var dict: [String: Any] = [
            "id": order.id,
            "trackNumber": order.trackNumber,
            "clientId": order.clientId,
            "clientName": order.clientName,
            "driverId": order.driverId ?? NSNull(),
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
            "price": order.price,
            "currency": order.currency,
            "driverEarning": order.driverEarning,
            "createdAt": Timestamp(date: order.createdAt),
            "estimatedDelivery": Timestamp(date: order.estimatedDelivery),
            "updatedAt": Timestamp(date: order.createdAt),
            "statusHistory": order.statusHistory.map { $0.toDict() }
        ]

        if let clientPhone = order.clientPhone {
            dict["clientPhone"] = clientPhone
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
        if let cancelledAt = order.cancelledAt {
            dict["cancelledAt"] = Timestamp(date: cancelledAt)
        }
        if let driverLocation = order.driverLocation {
            dict["driverLocation"] = driverLocation.toDict()
        }

        return dict
    }

    deinit {
        clientOrdersListener?.remove()
        availableOrdersListener?.remove()
        driverOrdersListener?.remove()
    }
}
