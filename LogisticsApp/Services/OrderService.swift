import Foundation
import CoreLocation
import Combine
import OSLog
import Supabase

@MainActor
class OrderService: ObservableObject {
    private let client = SupabaseManager.client
    private let logger = Logger(subsystem: "com.meirzhan.LogisticsApp", category: "orders")

    @Published var orders: [Order] = []
    @Published var availableOrders: [Order] = []
    @Published var myOrders: [Order] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var realtimeChannel: RealtimeChannelV2?
    private var realtimeTask: Task<Void, Never>?
    private var activeClientId: String?
    private var activeDriverId: String?

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
        let orderId = UUID().uuidString.lowercased()
        let trackNumber = generateTrackNumber()
        let now = Date()
        let estimatedDelivery = Calendar.current.date(byAdding: .day, value: tariffType.deliveryDays, to: now) ?? now
        let driverEarning = Int(Double(price) * 0.7)
        let cleanDescription = packageDescription.trimmingCharacters(in: .whitespacesAndNewlines)

        let row = OrderRow(
            id: orderId,
            trackNumber: trackNumber,
            clientId: clientId.lowercased(),
            clientName: clientName,
            clientPhone: clientPhone,
            driverId: nil,
            driverName: nil,
            driverPhone: nil,
            fromAddress: fromAddress,
            toAddress: toAddress,
            route: "\(fromAddress) → \(toAddress)",
            packageDescription: cleanDescription,
            weight: weight,
            packageType: packageType.storageKey,
            tariffType: tariffType.storageKey,
            status: OrderStatus.accepted.rawValue,
            hasInsurance: insurance,
            isUrgent: urgentDelivery,
            price: price,
            currency: "₸",
            driverEarning: driverEarning,
            driverLatitude: nil,
            driverLongitude: nil,
            createdAt: now,
            estimatedDelivery: estimatedDelivery,
            deliveredAt: nil,
            cancelledAt: nil
        )

        try await client.from("orders").insert(row).execute()

        let eventRow = OrderStatusEventRow(
            id: UUID().uuidString.lowercased(),
            orderId: orderId,
            status: OrderStatus.accepted.rawValue,
            note: "Тапсырыс жасалды",
            createdAt: now
        )
        try await client.from("order_status_events").insert(eventRow).execute()

        return row.toOrder(events: [eventRow.toEvent()])
    }

    // MARK: - Listen to Client Orders

    func listenToClientOrders(clientId: String) {
        stopListening()
        activeClientId = clientId.lowercased()
        activeDriverId = nil
        isLoading = true

        Task {
            await fetchClientOrders(clientId: clientId.lowercased())
            isLoading = false
        }

        subscribeToOrderChanges { [weak self] in
            guard let self, let id = self.activeClientId else { return }
            await self.fetchClientOrders(clientId: id)
        }
    }

    private func fetchClientOrders(clientId: String) async {
        do {
            let rows: [OrderRow] = try await client
                .from("orders")
                .select()
                .eq("client_id", value: clientId)
                .order("created_at", ascending: false)
                .execute()
                .value

            let eventsMap = await fetchEvents(for: rows.map(\.id))
            self.orders = rows.map { $0.toOrder(events: eventsMap[$0.id] ?? []) }
        } catch {
            logger.error("Client orders fetch error: \(error.localizedDescription, privacy: .public)")
            errorMessage = "Тапсырыстарды жүктеу сәтсіз: \(error.localizedDescription)"
        }
    }

    // MARK: - Listen to Driver Workspace

    func listenToDriverWorkspace(driverId: String) {
        stopListening()
        activeDriverId = driverId.lowercased()
        activeClientId = nil
        isLoading = true

        Task {
            await fetchDriverWorkspace(driverId: driverId.lowercased())
            isLoading = false
        }

        subscribeToOrderChanges { [weak self] in
            guard let self, let id = self.activeDriverId else { return }
            await self.fetchDriverWorkspace(driverId: id)
        }
    }

    private func fetchDriverWorkspace(driverId: String) async {
        do {
            let availableRows: [OrderRow] = try await client
                .from("orders")
                .select()
                .eq("status", value: OrderStatus.accepted.rawValue)
                .is("driver_id", value: nil)
                .order("created_at", ascending: false)
                .execute()
                .value

            let myRows: [OrderRow] = try await client
                .from("orders")
                .select()
                .eq("driver_id", value: driverId)
                .order("created_at", ascending: false)
                .execute()
                .value

            let allIds = (availableRows + myRows).map(\.id)
            let eventsMap = await fetchEvents(for: allIds)

            self.availableOrders = availableRows.map { $0.toOrder(events: eventsMap[$0.id] ?? []) }
            self.myOrders = myRows.map { $0.toOrder(events: eventsMap[$0.id] ?? []) }
        } catch {
            logger.error("Driver workspace fetch error: \(error.localizedDescription, privacy: .public)")
            errorMessage = "Тапсырыстарды жүктеу қатесі: \(error.localizedDescription)"
        }
    }

    // MARK: - Assign Order to Driver (Atomic PostgreSQL RPC)

    func assignOrderToDriver(
        orderId: String,
        driverId: String,
        driverName: String,
        driverPhone: String? = nil
    ) async throws {
        try await client
            .rpc("accept_order", params: ["p_order_id": orderId])
            .execute()

        await fetchDriverWorkspace(driverId: driverId.lowercased())
    }

    // MARK: - Update Order Status

    func updateOrderStatus(orderId: String, status: OrderStatus, note: String? = nil) async throws {
        struct StatusUpdatePayload: Encodable {
            let status: String
            let updatedAt: Date
            let deliveredAt: Date?

            enum CodingKeys: String, CodingKey {
                case status
                case updatedAt = "updated_at"
                case deliveredAt = "delivered_at"
            }
        }

        let now = Date()
        let payload = StatusUpdatePayload(
            status: status.rawValue,
            updatedAt: now,
            deliveredAt: status == .delivered ? now : nil
        )

        try await client
            .from("orders")
            .update(payload)
            .eq("id", value: orderId)
            .execute()

        let eventRow = OrderStatusEventRow(
            id: UUID().uuidString.lowercased(),
            orderId: orderId,
            status: status.rawValue,
            note: note,
            createdAt: now
        )
        try await client.from("order_status_events").insert(eventRow).execute()

        await refreshActiveWorkspace()
    }

    // MARK: - Cancel Order (Client)

    func cancelOrder(orderId: String) async throws {
        struct CancelPayload: Encodable {
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
        try await client
            .from("orders")
            .update(CancelPayload(status: OrderStatus.cancelled.rawValue, cancelledAt: now, updatedAt: now))
            .eq("id", value: orderId)
            .execute()

        let eventRow = OrderStatusEventRow(
            id: UUID().uuidString.lowercased(),
            orderId: orderId,
            status: OrderStatus.cancelled.rawValue,
            note: "Клиент тапсырысты болдырмады",
            createdAt: now
        )
        try await client.from("order_status_events").insert(eventRow).execute()

        await refreshActiveWorkspace()
    }

    // MARK: - Update Driver Live Location

    func updateDriverLocation(orderId: String, coordinate: CLLocationCoordinate2D) async throws {
        struct LocationPayload: Encodable {
            let driverLatitude: Double
            let driverLongitude: Double
            let updatedAt: Date

            enum CodingKeys: String, CodingKey {
                case driverLatitude = "driver_latitude"
                case driverLongitude = "driver_longitude"
                case updatedAt = "updated_at"
            }
        }

        try await client
            .from("orders")
            .update(LocationPayload(driverLatitude: coordinate.latitude, driverLongitude: coordinate.longitude, updatedAt: Date()))
            .eq("id", value: orderId)
            .execute()
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
        let review = Review(
            id: UUID().uuidString.lowercased(),
            orderId: order.id,
            driverId: driverId,
            clientId: clientId.lowercased(),
            clientName: clientName,
            rating: min(max(rating, 1), 5),
            comment: comment.trimmingCharacters(in: .whitespacesAndNewlines),
            createdAt: Date()
        )
        try await client.from("reviews").insert(review).execute()
    }

    // MARK: - Stop Listening

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

    // MARK: - Helpers

    private func refreshActiveWorkspace() async {
        if let clientId = activeClientId {
            await fetchClientOrders(clientId: clientId)
        } else if let driverId = activeDriverId {
            await fetchDriverWorkspace(driverId: driverId)
        }
    }

    private func subscribeToOrderChanges(onChange: @escaping @MainActor () async -> Void) {
        let channel = client.channel("orders-\(UUID().uuidString)")
        let stream = channel.postgresChange(AnyAction.self, schema: "public", table: "orders")
        self.realtimeChannel = channel

        realtimeTask = Task { [weak self] in
            await channel.subscribe()
            for await _ in stream {
                if Task.isCancelled || self == nil { return }
                await onChange()
            }
        }
    }

    private func fetchEvents(for orderIds: [String]) async -> [String: [OrderStatusEvent]] {
        guard !orderIds.isEmpty else { return [:] }
        do {
            let rows: [OrderStatusEventRow] = try await client
                .from("order_status_events")
                .select()
                .in("order_id", values: orderIds)
                .order("created_at", ascending: true)
                .execute()
                .value

            var grouped: [String: [OrderStatusEvent]] = [:]
            for row in rows {
                grouped[row.orderId, default: []].append(row.toEvent())
            }
            return grouped
        } catch {
            logger.error("Order events fetch error: \(error.localizedDescription, privacy: .public)")
            return [:]
        }
    }

    private func generateTrackNumber() -> String {
        let numbers = "0123456789"
        let randomNumbers = (0..<9).map { _ in numbers.randomElement()! }
        return "KZ\(String(randomNumbers))"
    }

    deinit {
        realtimeTask?.cancel()
    }
}
