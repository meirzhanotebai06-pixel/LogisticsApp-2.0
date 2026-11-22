import Foundation
import Combine
import FirebaseFirestore

enum DocumentVerificationStatus: String {
    case pending
    case approved
    case rejected
}

@MainActor
final class AdminService: ObservableObject {
    @Published var drivers: [User] = []
    @Published var allOrders: [Order] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var updatingDocumentKey: String?
    @Published var updatingOrderId: String?

    private let db = Firestore.firestore()
    private var driversListener: ListenerRegistration?
    private var ordersListener: ListenerRegistration?

    func startListening() {
        stopListening()
        isLoading = true

        driversListener = db.collection("users")
            .whereField("userType", isEqualTo: UserType.driver.rawValue)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.isLoading = false

                    if let error {
                        self.errorMessage = "Жүргізушілерді жүктеу сәтсіз: \(error.localizedDescription)"
                        return
                    }

                    self.drivers = snapshot?.documents
                        .compactMap { User.fromDictionary($0.data()) }
                        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending } ?? []
                }
            }

        ordersListener = db.collection("orders")
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor [weak self] in
                    guard let self else { return }

                    if let error {
                        self.errorMessage = "Тапсырыстарды жүктеу сәтсіз: \(error.localizedDescription)"
                        return
                    }

                    self.allOrders = snapshot?.documents
                        .compactMap { Order.fromDictionary($0.data()) } ?? []
                }
            }
    }

    func stopListening() {
        driversListener?.remove()
        driversListener = nil
        ordersListener?.remove()
        ordersListener = nil
    }

    func reviewDocument(
        driverId: String,
        documentType: DocumentType,
        status: DocumentVerificationStatus,
        rejectionReason: String? = nil
    ) async {
        let key = "\(driverId)-\(documentType.fieldName)"
        updatingDocumentKey = key
        defer { updatingDocumentKey = nil }

        let fieldPath = "vehicleInfo.documents.\(documentType.fieldName)"
        var updates: [String: Any] = [
            "\(fieldPath).isVerified": status == .approved,
            "\(fieldPath).verificationStatus": status.rawValue,
            "\(fieldPath).verifiedAt": FieldValue.serverTimestamp()
        ]

        if status == .rejected, let rejectionReason, !rejectionReason.isEmpty {
            updates["\(fieldPath).rejectionReason"] = rejectionReason
        } else {
            updates["\(fieldPath).rejectionReason"] = FieldValue.delete()
        }

        do {
            try await db.collection("users").document(driverId).updateData(updates)
        } catch {
            errorMessage = "Құжат статусын өзгерту сәтсіз: \(error.localizedDescription)"
        }
    }

    func cancelOrder(orderId: String) async {
        updatingOrderId = orderId
        defer { updatingOrderId = nil }

        let now = Date()
        let event = OrderStatusEvent(
            status: OrderStatus.cancelled.rawValue,
            timestamp: now,
            note: "Администратор тапсырысты болдырмады"
        )

        do {
            try await db.collection("orders").document(orderId).updateData([
                "status": OrderStatus.cancelled.rawValue,
                "cancelledAt": Timestamp(date: now),
                "updatedAt": Timestamp(date: now),
                "statusHistory": FieldValue.arrayUnion([event.toDict()])
            ])
        } catch {
            errorMessage = "Тапсырысты болдырмау сәтсіз: \(error.localizedDescription)"
        }
    }

    func unassignDriver(orderId: String) async {
        updatingOrderId = orderId
        defer { updatingOrderId = nil }

        let now = Date()
        let event = OrderStatusEvent(
            status: OrderStatus.accepted.rawValue,
            timestamp: now,
            note: "Администратор жүргізушіні босатты"
        )

        do {
            try await db.collection("orders").document(orderId).updateData([
                "driverId": NSNull(),
                "driverName": FieldValue.delete(),
                "driverPhone": FieldValue.delete(),
                "driverLocation": FieldValue.delete(),
                "status": OrderStatus.accepted.rawValue,
                "updatedAt": Timestamp(date: now),
                "statusHistory": FieldValue.arrayUnion([event.toDict()])
            ])
        } catch {
            errorMessage = "Жүргізушіні босату сәтсіз: \(error.localizedDescription)"
        }
    }

    deinit {
        driversListener?.remove()
        ordersListener?.remove()
    }
}

extension VehicleDocuments {
    func document(for type: DocumentType) -> DocumentInfo? {
        switch type {
        case .insurance: return insurance
        case .driverLicense: return driverLicense
        case .vehicleRegistration: return vehicleRegistration
        case .technicalInspection: return technicalInspection
        }
    }

    var allDocuments: [DocumentInfo] {
        [insurance, driverLicense, vehicleRegistration, technicalInspection].compactMap { $0 }
    }
}

extension DocumentInfo {
    var effectiveVerificationStatus: DocumentVerificationStatus {
        if let verificationStatus,
           let status = DocumentVerificationStatus(rawValue: verificationStatus) {
            return status
        }
        return isVerified ? .approved : .pending
    }
}
