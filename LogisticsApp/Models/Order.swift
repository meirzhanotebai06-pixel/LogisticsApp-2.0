import Foundation
import SwiftUI
import CoreLocation

// MARK: - Order Status

enum OrderStatus: String, Codable, CaseIterable {
    case accepted
    case inTransit
    case atCustoms
    case delivered
    case cancelled

    var title: String {
        switch self {
        case .accepted: return "Қабылданды"
        case .inTransit: return "Жеткізілуде"
        case .atCustoms: return "Кеденде"
        case .delivered: return "Жеткізілді"
        case .cancelled: return "Болдырылмады"
        }
    }

    var color: Color {
        switch self {
        case .accepted: return .blue
        case .inTransit: return .orange
        case .atCustoms: return .yellow
        case .delivered: return .green
        case .cancelled: return .red
        }
    }

    var icon: String {
        switch self {
        case .accepted: return "checkmark.circle.fill"
        case .inTransit: return "shippingbox.fill"
        case .atCustoms: return "building.2.fill"
        case .delivered: return "checkmark.seal.fill"
        case .cancelled: return "xmark.circle.fill"
        }
    }

    var progress: CGFloat {
        switch self {
        case .accepted: return 0.25
        case .inTransit: return 0.55
        case .atCustoms: return 0.80
        case .delivered: return 1.0
        case .cancelled: return 0.0
        }
    }

    var isActive: Bool {
        switch self {
        case .accepted, .inTransit, .atCustoms:
            return true
        case .delivered, .cancelled:
            return false
        }
    }
}

// MARK: - Supporting Types

struct OrderStatusEvent: Identifiable, Codable {
    let id: String
    let status: String
    let timestamp: Date
    let note: String?

    init(id: String = UUID().uuidString, status: String, timestamp: Date = Date(), note: String? = nil) {
        self.id = id
        self.status = status
        self.timestamp = timestamp
        self.note = note
    }

    var orderStatus: OrderStatus {
        OrderStatus(rawValue: status) ?? .accepted
    }
}

struct GeoPointData: Codable, Equatable {
    let latitude: Double
    let longitude: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
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
    var status: String
    let hasInsurance: Bool
    let isUrgent: Bool
    let price: Int
    let currency: String
    let driverEarning: Int
    let createdAt: Date
    let estimatedDelivery: Date
    var deliveredAt: Date?
    var cancelledAt: Date?
    var statusHistory: [OrderStatusEvent]
    var driverLocation: GeoPointData?

    var orderStatus: OrderStatus {
        OrderStatus(rawValue: status) ?? .accepted
    }

    var displayPackageType: String {
        PackageType(storageKeyOrRawValue: packageType)?.rawValue ?? packageType
    }

    var displayTariffType: String {
        TariffType(storageKeyOrRawValue: tariffType)?.rawValue ?? tariffType
    }

    var distanceKm: Int {
        guard let from = CitiesDatabase.getCoordinate(cityName: fromAddress),
              let to = CitiesDatabase.getCoordinate(cityName: toAddress) else {
            return 0
        }
        let fromLoc = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let toLoc = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return Int(fromLoc.distance(from: toLoc) / 1000)
    }
}

// MARK: - PostgreSQL Row DTOs

struct OrderRow: Codable {
    let id: String
    let trackNumber: String
    let clientId: String
    let clientName: String
    let clientPhone: String?
    let driverId: String?
    let driverName: String?
    let driverPhone: String?
    let fromAddress: String
    let toAddress: String
    let route: String
    let packageDescription: String
    let weight: Double
    let packageType: String
    let tariffType: String
    let status: String
    let hasInsurance: Bool
    let isUrgent: Bool
    let price: Int
    let currency: String
    let driverEarning: Int
    let driverLatitude: Double?
    let driverLongitude: Double?
    let createdAt: Date
    let estimatedDelivery: Date
    let deliveredAt: Date?
    let cancelledAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case trackNumber = "track_number"
        case clientId = "client_id"
        case clientName = "client_name"
        case clientPhone = "client_phone"
        case driverId = "driver_id"
        case driverName = "driver_name"
        case driverPhone = "driver_phone"
        case fromAddress = "from_address"
        case toAddress = "to_address"
        case route
        case packageDescription = "package_description"
        case weight
        case packageType = "package_type"
        case tariffType = "tariff_type"
        case status
        case hasInsurance = "has_insurance"
        case isUrgent = "is_urgent"
        case price
        case currency
        case driverEarning = "driver_earning"
        case driverLatitude = "driver_latitude"
        case driverLongitude = "driver_longitude"
        case createdAt = "created_at"
        case estimatedDelivery = "estimated_delivery"
        case deliveredAt = "delivered_at"
        case cancelledAt = "cancelled_at"
    }

    func toOrder(events: [OrderStatusEvent] = []) -> Order {
        let location: GeoPointData?
        if let lat = driverLatitude, let lon = driverLongitude {
            location = GeoPointData(latitude: lat, longitude: lon)
        } else {
            location = nil
        }

        let history = events.isEmpty
            ? [OrderStatusEvent(status: status, timestamp: createdAt)]
            : events.sorted { $0.timestamp < $1.timestamp }

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
            price: price,
            currency: currency,
            driverEarning: driverEarning,
            createdAt: createdAt,
            estimatedDelivery: estimatedDelivery,
            deliveredAt: deliveredAt,
            cancelledAt: cancelledAt,
            statusHistory: history,
            driverLocation: location
        )
    }
}

struct OrderStatusEventRow: Codable {
    let id: String
    let orderId: String
    let status: String
    let note: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case orderId = "order_id"
        case status
        case note
        case createdAt = "created_at"
    }

    func toEvent() -> OrderStatusEvent {
        OrderStatusEvent(id: id, status: status, timestamp: createdAt, note: note)
    }
}

// MARK: - Review Model

struct Review: Identifiable, Codable {
    let id: String
    let orderId: String
    let driverId: String
    let clientId: String
    let clientName: String
    let rating: Int
    let comment: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case orderId = "order_id"
        case driverId = "driver_id"
        case clientId = "client_id"
        case clientName = "client_name"
        case rating
        case comment
        case createdAt = "created_at"
    }
}
