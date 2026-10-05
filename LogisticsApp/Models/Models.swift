import Foundation
import CoreLocation
import MapKit
import FirebaseFirestore

// MARK: - User Models

struct User: Codable, Identifiable {
    let id: String
    let email: String
    let name: String
    let userType: UserType
    let phone: String?
    let vehicleInfo: VehicleInfo?
    
    static func fromDictionary(_ dict: [String: Any]) -> User? {
        guard let id = dict["id"] as? String,
              let email = dict["email"] as? String,
              let name = dict["name"] as? String,
              let userTypeRaw = dict["userType"] as? String,
              let userType = UserType(rawValue: userTypeRaw) else {
            return nil
        }
        
        let phone = dict["phone"] as? String
        let vehicleInfoDict = dict["vehicleInfo"] as? [String: Any]
        let vehicleInfo = vehicleInfoDict != nil ? VehicleInfo.fromDictionary(vehicleInfoDict!) : nil
        
        return User(
            id: id,
            email: email,
            name: name,
            userType: userType,
            phone: phone,
            vehicleInfo: vehicleInfo
        )
    }
}

struct VehicleInfo: Codable {
    let model: String
    let plateNumber: String
    let capacity: String
    let documents: VehicleDocuments?
    
    static func fromDictionary(_ dict: [String: Any]) -> VehicleInfo? {
        guard let model = dict["model"] as? String,
              let plateNumber = dict["plateNumber"] as? String,
              let capacity = dict["capacity"] as? String else {
            return nil
        }
        
        let documentsDict = dict["documents"] as? [String: Any]
        let documents = documentsDict != nil ? VehicleDocuments.fromDictionary(documentsDict!) : nil
        
        return VehicleInfo(
            model: model,
            plateNumber: plateNumber,
            capacity: capacity,
            documents: documents
        )
    }
}

struct VehicleDocuments: Codable {
    let insurance: DocumentInfo?
    let driverLicense: DocumentInfo?
    let vehicleRegistration: DocumentInfo?
    let technicalInspection: DocumentInfo?
    
    static func fromDictionary(_ dict: [String: Any]) -> VehicleDocuments? {
        let insurance = (dict["insurance"] as? [String: Any]).flatMap { DocumentInfo.fromDictionary($0) }
        let driverLicense = (dict["driverLicense"] as? [String: Any]).flatMap { DocumentInfo.fromDictionary($0) }
        let vehicleRegistration = (dict["vehicleRegistration"] as? [String: Any]).flatMap { DocumentInfo.fromDictionary($0) }
        let technicalInspection = (dict["technicalInspection"] as? [String: Any]).flatMap { DocumentInfo.fromDictionary($0) }
        
        return VehicleDocuments(
            insurance: insurance,
            driverLicense: driverLicense,
            vehicleRegistration: vehicleRegistration,
            technicalInspection: technicalInspection
        )
    }
}

struct DocumentInfo: Codable {
    let number: String
    let expiryDate: Date
    let isVerified: Bool
    let fileURL: String?
    let uploadDate: Date?
    let verificationStatus: String?
    let rejectionReason: String?
    
    // Additional fields for different document types
    let issueDate: Date?
    let issuedBy: String?
    
    // Driver license fields
    let fullName: String?
    let iin: String?
    let category: String?
    
    // Insurance fields
    let insuranceType: String?
    let insuranceCompany: String?
    
    // Vehicle registration fields
    let vin: String?
    let vehicleYear: String?
    let color: String?
    let engineNumber: String?
    let capacity: String?
    
    // Technical inspection fields
    let inspectionCenter: String?
    
    var isExpired: Bool {
        return expiryDate < Date()
    }
    
    var daysUntilExpiry: Int {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: Date(), to: expiryDate).day ?? 0
        return days
    }
    
    static func fromDictionary(_ dict: [String: Any]) -> DocumentInfo? {
        guard let number = dict["number"] as? String,
              let timestamp = dict["expiryDate"] as? Timestamp,
              let isVerified = dict["isVerified"] as? Bool else {
            return nil
        }
        
        let fileURL = dict["fileURL"] as? String
        let uploadTimestamp = dict["uploadDate"] as? Timestamp
        let verificationStatus = dict["verificationStatus"] as? String
        let rejectionReason = dict["rejectionReason"] as? String
        
        let issueTimestamp = dict["issueDate"] as? Timestamp
        let issuedBy = dict["issuedBy"] as? String
        
        let fullName = dict["fullName"] as? String
        let iin = dict["iin"] as? String
        let category = dict["category"] as? String
        
        let insuranceType = dict["insuranceType"] as? String
        let insuranceCompany = dict["insuranceCompany"] as? String
        
        let vin = dict["vin"] as? String
        let vehicleYear = dict["vehicleYear"] as? String
        let color = dict["color"] as? String
        let engineNumber = dict["engineNumber"] as? String
        let capacity = dict["capacity"] as? String
        
        let inspectionCenter = dict["inspectionCenter"] as? String
        
        return DocumentInfo(
            number: number,
            expiryDate: timestamp.dateValue(),
            isVerified: isVerified,
            fileURL: fileURL,
            uploadDate: uploadTimestamp?.dateValue(),
            verificationStatus: verificationStatus,
            rejectionReason: rejectionReason,
            issueDate: issueTimestamp?.dateValue(),
            issuedBy: issuedBy,
            fullName: fullName,
            iin: iin,
            category: category,
            insuranceType: insuranceType,
            insuranceCompany: insuranceCompany,
            vin: vin,
            vehicleYear: vehicleYear,
            color: color,
            engineNumber: engineNumber,
            capacity: capacity,
            inspectionCenter: inspectionCenter
        )
    }
}

enum UserType: String, Codable {
    case client
    case driver
    case admin
}

// DocumentType moved to VehicleInfoView.swift

// MARK: - Shipment Models

struct Shipment: Identifiable {
    let id = UUID()
    let trackNumber: String
    let route: String
    let status: ShipmentStatus
    let date: Date
    let estimatedDelivery: Date?
    let shipmentDetails: ShipmentDetails
    
    var routeCoordinates: (from: CLLocationCoordinate2D, to: CLLocationCoordinate2D)? {
        let cities = route.components(separatedBy: " → ")
        guard cities.count == 2,
              let fromCoord = CitiesDatabase.getCoordinate(cityName: cities[0]),
              let toCoord = CitiesDatabase.getCoordinate(cityName: cities[1]) else {
            return nil
        }
        return (fromCoord, toCoord)
    }
    
    var centerCoordinate: CLLocationCoordinate2D {
        if let coords = routeCoordinates {
            let lat = (coords.from.latitude + coords.to.latitude) / 2
            let lon = (coords.from.longitude + coords.to.longitude) / 2
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
        return CLLocationCoordinate2D(latitude: 43.2380, longitude: 76.8829)
    }
    
    var coordinateSpan: MKCoordinateSpan {
        if let coords = routeCoordinates {
            let latDelta = abs(coords.from.latitude - coords.to.latitude) * 1.5
            let lonDelta = abs(coords.from.longitude - coords.to.longitude) * 1.5
            return MKCoordinateSpan(latitudeDelta: max(latDelta, 2.0), longitudeDelta: max(lonDelta, 2.0))
        }
        return MKCoordinateSpan(latitudeDelta: 5.0, longitudeDelta: 5.0)
    }
}

struct ShipmentDetails {
    let sender: ContactInfo
    let receiver: ContactInfo
    let packageInfo: PackageInfo
    let payment: PaymentInfo
    let additionalServices: [AdditionalService]
}

struct ContactInfo {
    let name: String
    let phone: String
    let address: String
    let email: String?
}

struct PackageInfo {
    let description: String
    let weight: Double
    let dimensions: String
    let packageType: PackageType
    let value: Double?
    let fragile: Bool
}

struct PaymentInfo {
    let amount: Double
    let currency: String
    let paymentMethod: String
    let isPaid: Bool
}

struct AdditionalService {
    let name: String
    let price: Double
    let isSelected: Bool
}

enum PackageType: String, CaseIterable {
    case document = "Құжат"
    case small = "Шағын пакет"
    case medium = "Орташа пакет"
    case large = "Үлкен пакет"
    case pallet = "Паллета"
}

enum ShipmentStatus: String {
    case accepted = "Қабылданды"
    case inTransit = "Жеткізілуде"
    case atCustoms = "Кеденде"
    case delivered = "Жеткізілді"
}

// MARK: - Tariff Models

enum TariffType: String, CaseIterable {
    case express = "Экспресс"
    case standard = "Стандартты"
    case economy = "Экономикалық"
    case international = "Халықаралық"
    
    var basePrice: Int {
        switch self {
        case .express: return 2500
        case .standard: return 1500
        case .economy: return 800
        case .international: return 5000
        }
    }
    
    var deliveryTime: String {
        switch self {
        case .express: return "1-2 күн"
        case .standard: return "3-5 күн"
        case .economy: return "5-7 күн"
        case .international: return "7-14 күн"
        }
    }
}

struct Tariff: Identifiable {
    let id = UUID()
    let type: TariffType
    let name: String
    let description: String
    let price: String
    let deliveryTime: String
    let features: [String]
}

// MARK: - Driver Specific Models

struct DriverMapAnnotation: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let type: DriverAnnotationType
    let title: String
    let shipment: Shipment?
}

enum DriverAnnotationType {
    case driver, delivery
}
