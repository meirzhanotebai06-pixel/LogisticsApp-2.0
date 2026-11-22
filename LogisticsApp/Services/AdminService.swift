import Foundation
import Combine
import Supabase

enum DocumentVerificationStatus: String {
    case pending
    case approved
    case rejected
}

@MainActor
final class AdminService: ObservableObject {
    @Published var drivers: [AppUser] = []
    @Published var allOrders: [Order] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var updatingDocumentKey: String?
    @Published var updatingOrderId: String?

    private let client = SupabaseManager.client
    private var realtimeChannel: RealtimeChannelV2?
    private var realtimeTask: Task<Void, Never>?

    func startListening() {
        stopListening()
        isLoading = true

        Task {
            await reloadAll()
            isLoading = false
        }

        let channel = client.channel("admin-\(UUID().uuidString)")
        let orderChanges = channel.postgresChange(AnyAction.self, schema: "public", table: "orders")
        let docChanges = channel.postgresChange(AnyAction.self, schema: "public", table: "driver_documents")
        self.realtimeChannel = channel

        realtimeTask = Task { [weak self] in
            await channel.subscribe()
            await withTaskGroup(of: Void.self) { group in
                group.addTask { [weak self] in
                    for await _ in orderChanges {
                        if Task.isCancelled { return }
                        await self?.reloadOrders()
                    }
                }
                group.addTask { [weak self] in
                    for await _ in docChanges {
                        if Task.isCancelled { return }
                        await self?.reloadDrivers()
                    }
                }
            }
        }
    }

    func stopListening() {
        realtimeTask?.cancel()
        realtimeTask = nil
        if let channel = realtimeChannel {
            realtimeChannel = nil
            Task {
                await client.removeChannel(channel)
            }
        }
    }

    private func reloadAll() async {
        await reloadDrivers()
        await reloadOrders()
    }

    private func reloadDrivers() async {
        do {
            let profiles: [ProfileRow] = try await client
                .from("profiles")
                .select()
                .eq("user_type", value: UserType.driver.rawValue)
                .order("name", ascending: true)
                .execute()
                .value

            let vehicles: [VehicleRow] = try await client
                .from("vehicles")
                .select()
                .execute()
                .value

            let docRows: [DriverDocumentRow] = try await client
                .from("driver_documents")
                .select()
                .execute()
                .value

            let vehicleByDriver = Dictionary(uniqueKeysWithValues: vehicles.map { ($0.driverId, $0) })
            let docsByDriver = Dictionary(grouping: docRows, by: \.driverId)

            self.drivers = profiles.compactMap { profile in
                let docs = VehicleDocuments.from(rows: docsByDriver[profile.id] ?? [])
                let vehicleInfo: VehicleInfo?
                if let vehicle = vehicleByDriver[profile.id] {
                    vehicleInfo = VehicleInfo(
                        model: vehicle.model,
                        plateNumber: vehicle.plateNumber,
                        capacity: vehicle.capacity,
                        documents: docs
                    )
                } else {
                    vehicleInfo = nil
                }
                return profile.toAppUser(vehicleInfo: vehicleInfo)
            }
        } catch {
            errorMessage = "Жүргізушілерді жүктеу сәтсіз: \(error.localizedDescription)"
        }
    }

    private func reloadOrders() async {
        do {
            let orderRows: [OrderRow] = try await client
                .from("orders")
                .select()
                .order("created_at", ascending: false)
                .execute()
                .value

            let orderIds = orderRows.map(\.id)
            var groupedEvents: [String: [OrderStatusEvent]] = [:]
            if !orderIds.isEmpty {
                let events: [OrderStatusEventRow] = try await client
                    .from("order_status_events")
                    .select()
                    .in("order_id", values: orderIds)
                    .order("created_at", ascending: true)
                    .execute()
                    .value
                for row in events {
                    groupedEvents[row.orderId, default: []].append(row.toEvent())
                }
            }

            self.allOrders = orderRows.map { $0.toOrder(events: groupedEvents[$0.id] ?? []) }
        } catch {
            errorMessage = "Тапсырыстарды жүктеу сәтсіз: \(error.localizedDescription)"
        }
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

        struct ReviewUpdatePayload: Encodable {
            let isVerified: Bool
            let verificationStatus: String
            let rejectionReason: String?
            let verifiedAt: Date

            enum CodingKeys: String, CodingKey {
                case isVerified = "is_verified"
                case verificationStatus = "verification_status"
                case rejectionReason = "rejection_reason"
                case verifiedAt = "verified_at"
            }
        }

        let cleanReason = (status == .rejected && !(rejectionReason ?? "").isEmpty) ? rejectionReason : nil
        let payload = ReviewUpdatePayload(
            isVerified: status == .approved,
            verificationStatus: status.rawValue,
            rejectionReason: cleanReason,
            verifiedAt: Date()
        )

        do {
            try await client
                .from("driver_documents")
                .update(payload)
                .eq("driver_id", value: driverId)
                .eq("document_type", value: documentType.fieldName)
                .execute()

            await reloadDrivers()
        } catch {
            errorMessage = "Құжат статусын өзгерту сәтсіз: \(error.localizedDescription)"
        }
    }

    func cancelOrder(orderId: String) async {
        updatingOrderId = orderId
        defer { updatingOrderId = nil }

        struct AdminCancelPayload: Encodable {
            let status: String
            let cancelledAt: Date
            let updatedAt: Date

            enum CodingKeys: String, CodingKey {
                case status
                case cancelledAt = "cancelled_at"
                case updatedAt = "updated_at"
            }
        }

        let now = Date()
        do {
            try await client
                .from("orders")
                .update(AdminCancelPayload(status: OrderStatus.cancelled.rawValue, cancelledAt: now, updatedAt: now))
                .eq("id", value: orderId)
                .execute()

            let eventRow = OrderStatusEventRow(
                id: UUID().uuidString.lowercased(),
                orderId: orderId,
                status: OrderStatus.cancelled.rawValue,
                note: "Администратор тапсырысты болдырмады",
                createdAt: now
            )
            try await client.from("order_status_events").insert(eventRow).execute()
            await reloadOrders()
        } catch {
            errorMessage = "Тапсырысты болдырмау сәтсіз: \(error.localizedDescription)"
        }
    }

    func unassignDriver(orderId: String) async {
        updatingOrderId = orderId
        defer { updatingOrderId = nil }

        struct UnassignPayload: Encodable {
            let driverId: String? = nil
            let driverName: String? = nil
            let driverPhone: String? = nil
            let driverLatitude: Double? = nil
            let driverLongitude: Double? = nil
            let status: String
            let updatedAt: Date

            enum CodingKeys: String, CodingKey {
                case driverId = "driver_id"
                case driverName = "driver_name"
                case driverPhone = "driver_phone"
                case driverLatitude = "driver_latitude"
                case driverLongitude = "driver_longitude"
                case status
                case updatedAt = "updated_at"
            }

            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encodeNil(forKey: .driverId)
                try container.encodeNil(forKey: .driverName)
                try container.encodeNil(forKey: .driverPhone)
                try container.encodeNil(forKey: .driverLatitude)
                try container.encodeNil(forKey: .driverLongitude)
                try container.encode(status, forKey: .status)
                try container.encode(updatedAt, forKey: .updatedAt)
            }
        }

        let now = Date()
        do {
            try await client
                .from("orders")
                .update(UnassignPayload(status: OrderStatus.accepted.rawValue, updatedAt: now))
                .eq("id", value: orderId)
                .execute()

            let eventRow = OrderStatusEventRow(
                id: UUID().uuidString.lowercased(),
                orderId: orderId,
                status: OrderStatus.accepted.rawValue,
                note: "Администратор жүргізушіні босатты",
                createdAt: now
            )
            try await client.from("order_status_events").insert(eventRow).execute()
            await reloadOrders()
        } catch {
            errorMessage = "Жүргізушіні босату сәтсіз: \(error.localizedDescription)"
        }
    }

    deinit {
        realtimeTask?.cancel()
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
