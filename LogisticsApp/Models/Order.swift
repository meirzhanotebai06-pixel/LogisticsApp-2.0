import Foundation
import SwiftUI
import CoreLocation
import FirebaseFirestore

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

    func toDict() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "status": status,
            "timestamp": Timestamp(date: timestamp)
        ]
        if let note {
            dict["note"] = note
        }
        return dict
    }

    static func fromDictionary(_ dict: [String: Any]) -> OrderStatusEvent? {
        guard let status = dict["status"] as? String,
              let timestamp = dict["timestamp"] as? Timestamp else {
            return nil
        }
        let id = dict["id"] as? String ?? UUID().uuidString
        let note = dict["note"] as? String
        return OrderStatusEvent(id: id, status: status, timestamp: timestamp.dateValue(), note: note)
    }
}

struct GeoPointData: Codable, Equatable {
    let latitude: Double
    let longitude: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    func toDict() -> [String: Any] {
        [
            "latitude": latitude,
            "longitude": longitude
        ]
    }

    static func fromDictionary(_ dict: [String: Any]) -> GeoPointData? {
        guard let lat = (dict["latitude"] as? NSNumber)?.doubleValue,
              let lon = (dict["longitude"] as? NSNumber)?.doubleValue else {
            return nil
        }
        return GeoPointData(latitude: lat, longitude: lon)
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

    static func fromDictionary(_ dict: [String: Any]) -> Order? {
        guard let id = dict["id"] as? String,
              let trackNumber = dict["trackNumber"] as? String,
              let clientId = dict["clientId"] as? String,
              let clientName = dict["clientName"] as? String,
              let fromAddress = dict["fromAddress"] as? String,
              let toAddress = dict["toAddress"] as? String,
              let route = dict["route"] as? String,
              let packageDescription = dict["packageDescription"] as? String,
              let weight = (dict["weight"] as? NSNumber)?.doubleValue,
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
        let cancelledAtTimestamp = dict["cancelledAt"] as? Timestamp

        let fallbackTariff = TariffType(storageKeyOrRawValue: tariffType) ?? .standard
        let fallbackPrice = Tariff.calculatePrice(
            tariff: fallbackTariff,
            weight: weight,
            distanceKm: 0,
            insurance: hasInsurance,
            urgentDelivery: isUrgent
        )
        let price = (dict["price"] as? NSNumber)?.intValue ?? fallbackPrice
        let currency = dict["currency"] as? String ?? "₸"
        let driverEarning = (dict["driverEarning"] as? NSNumber)?.intValue ?? Int(Double(price) * 0.7)

        let historyArray = dict["statusHistory"] as? [[String: Any]] ?? []
        let parsedHistory = historyArray.compactMap { OrderStatusEvent.fromDictionary($0) }
        let history = parsedHistory.isEmpty
            ? [OrderStatusEvent(status: status, timestamp: createdAtTimestamp.dateValue())]
            : parsedHistory.sorted { $0.timestamp < $1.timestamp }

        let driverLocation = (dict["driverLocation"] as? [String: Any]).flatMap {
            GeoPointData.fromDictionary($0)
        }

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
            createdAt: createdAtTimestamp.dateValue(),
            estimatedDelivery: estimatedDeliveryTimestamp.dateValue(),
            deliveredAt: deliveredAtTimestamp?.dateValue(),
            cancelledAt: cancelledAtTimestamp?.dateValue(),
            statusHistory: history,
            driverLocation: driverLocation
        )
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

    func toDict() -> [String: Any] {
        [
            "id": id,
            "orderId": orderId,
            "driverId": driverId,
            "clientId": clientId,
            "clientName": clientName,
            "rating": rating,
            "comment": comment,
            "createdAt": Timestamp(date: createdAt)
        ]
    }
}
