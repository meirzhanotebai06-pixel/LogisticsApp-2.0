import Foundation
import CoreLocation

// MARK: - User Models

struct AppUser: Codable, Identifiable {
    let id: String
    let email: String
    let name: String
    let userType: UserType
    let phone: String?
    let vehicleInfo: VehicleInfo?
    let isOnDuty: Bool?
    let rating: Double?
}

struct VehicleInfo: Codable {
    let model: String
    let plateNumber: String
    let capacity: String
    let documents: VehicleDocuments?
}

struct VehicleDocuments: Codable {
    let insurance: DocumentInfo?
    let driverLicense: DocumentInfo?
    let vehicleRegistration: DocumentInfo?
    let technicalInspection: DocumentInfo?
}

enum DocumentType: String, CaseIterable, Identifiable {
    case insurance
    case driverLicense
    case vehicleRegistration
    case technicalInspection

    var id: String { fieldName }

    var title: String {
        switch self {
        case .insurance: return "Сақтандыру"
        case .driverLicense: return "Жүргізуші куәлігі"
        case .vehicleRegistration: return "Техпаспорт"
        case .technicalInspection: return "Техосмотр"
        }
    }

    var description: String {
        switch self {
        case .insurance: return "Көлік сақтандыру полисі"
        case .driverLicense: return "Жүргізуші куәлігі"
        case .vehicleRegistration: return "Көлік техникалық паспорты"
        case .technicalInspection: return "Техникалық тексеру куәлігі"
        }
    }

    var fieldName: String {
        rawValue
    }

    var requiresExpiryDate: Bool {
        self != .vehicleRegistration
    }
}

struct DocumentInfo: Codable {
    let number: String
    let expiryDate: Date?
    let isVerified: Bool
    let fileURL: String?
    let uploadDate: Date?
    let verificationStatus: String?
    let rejectionReason: String?

    let issueDate: Date?
    let issuedBy: String?

    let fullName: String?
    let iin: String?
    let category: String?

    let insuranceType: String?
    let insuranceCompany: String?

    let vin: String?
    let vehicleYear: String?
    let color: String?
    let engineNumber: String?
    let capacity: String?

    let inspectionCenter: String?

    var isExpired: Bool {
        guard let expiryDate else { return false }
        return expiryDate < Date()
    }

    var daysUntilExpiry: Int? {
        guard let expiryDate else { return nil }
        return Calendar.current.dateComponents([.day], from: Date(), to: expiryDate).day
    }
}

enum UserType: String, Codable {
    case client
    case driver
    case admin

    var displayTitle: String {
        switch self {
        case .client: return "Клиент"
        case .driver: return "Жүргізуші"
        case .admin: return "Администратор"
        }
    }
}

// MARK: - PostgreSQL Row DTOs

struct ProfileRow: Codable {
    let id: String
    let email: String
    let name: String
    let userType: String
    let phone: String?
    let isOnDuty: Bool?
    let rating: Double?

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case name
        case userType = "user_type"
        case phone
        case isOnDuty = "is_on_duty"
        case rating
    }

    func toAppUser(vehicleInfo: VehicleInfo?) -> AppUser? {
        guard let role = UserType(rawValue: userType) else { return nil }
        return AppUser(
            id: id,
            email: email,
            name: name,
            userType: role,
            phone: phone,
            vehicleInfo: vehicleInfo,
            isOnDuty: isOnDuty,
            rating: rating
        )
    }
}

struct VehicleRow: Codable {
    let driverId: String
    let model: String
    let plateNumber: String
    let capacity: String

    enum CodingKeys: String, CodingKey {
        case driverId = "driver_id"
        case model
        case plateNumber = "plate_number"
        case capacity
    }
}

struct DriverDocumentRow: Codable {
    let driverId: String
    let documentType: String
    let number: String
    let expiryDate: Date?
    let isVerified: Bool
    let verificationStatus: String?
    let rejectionReason: String?
    let fileURL: String?
    let uploadDate: Date?
    let issueDate: Date?
    let issuedBy: String?
    let fullName: String?
    let iin: String?
    let category: String?
    let insuranceType: String?
    let insuranceCompany: String?
    let vin: String?
    let vehicleYear: String?
    let color: String?
    let engineNumber: String?
    let capacity: String?
    let inspectionCenter: String?

    enum CodingKeys: String, CodingKey {
        case driverId = "driver_id"
        case documentType = "document_type"
        case number
        case expiryDate = "expiry_date"
        case isVerified = "is_verified"
        case verificationStatus = "verification_status"
        case rejectionReason = "rejection_reason"
        case fileURL = "file_url"
        case uploadDate = "upload_date"
        case issueDate = "issue_date"
        case issuedBy = "issued_by"
        case fullName = "full_name"
        case iin
        case category
        case insuranceType = "insurance_type"
        case insuranceCompany = "insurance_company"
        case vin
        case vehicleYear = "vehicle_year"
        case color
        case engineNumber = "engine_number"
        case capacity
        case inspectionCenter = "inspection_center"
    }

    func toDocumentInfo() -> DocumentInfo {
        DocumentInfo(
            number: number,
            expiryDate: expiryDate,
            isVerified: isVerified,
            fileURL: fileURL,
            uploadDate: uploadDate,
            verificationStatus: verificationStatus,
            rejectionReason: rejectionReason,
            issueDate: issueDate,
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

    static func from(driverId: String, type: DocumentType, info: DocumentInfo) -> DriverDocumentRow {
        DriverDocumentRow(
            driverId: driverId,
            documentType: type.fieldName,
            number: info.number,
            expiryDate: info.expiryDate,
            isVerified: info.isVerified,
            verificationStatus: info.verificationStatus,
            rejectionReason: info.rejectionReason,
            fileURL: info.fileURL,
            uploadDate: info.uploadDate,
            issueDate: info.issueDate,
            issuedBy: info.issuedBy,
            fullName: info.fullName,
            iin: info.iin,
            category: info.category,
            insuranceType: info.insuranceType,
            insuranceCompany: info.insuranceCompany,
            vin: info.vin,
            vehicleYear: info.vehicleYear,
            color: info.color,
            engineNumber: info.engineNumber,
            capacity: info.capacity,
            inspectionCenter: info.inspectionCenter
        )
    }
}

extension VehicleDocuments {
    static func from(rows: [DriverDocumentRow]) -> VehicleDocuments? {
        guard !rows.isEmpty else { return nil }
        var byType: [DocumentType: DocumentInfo] = [:]
        for row in rows {
            if let type = DocumentType(rawValue: row.documentType) {
                byType[type] = row.toDocumentInfo()
            }
        }
        return VehicleDocuments(
            insurance: byType[.insurance],
            driverLicense: byType[.driverLicense],
            vehicleRegistration: byType[.vehicleRegistration],
            technicalInspection: byType[.technicalInspection]
        )
    }
}

// MARK: - Package & Tariff Models

enum PackageType: String, CaseIterable, Codable {
    case document = "Құжат"
    case small = "Шағын пакет"
    case medium = "Орташа пакет"
    case large = "Үлкен пакет"
    case pallet = "Паллета"

    var storageKey: String {
        switch self {
        case .document: return "document"
        case .small: return "small"
        case .medium: return "medium"
        case .large: return "large"
        case .pallet: return "pallet"
        }
    }

    init?(storageKeyOrRawValue: String) {
        if let direct = PackageType(rawValue: storageKeyOrRawValue) {
            self = direct
            return
        }
        switch storageKeyOrRawValue {
        case "document": self = .document
        case "small": self = .small
        case "medium": self = .medium
        case "large": self = .large
        case "pallet": self = .pallet
        default: return nil
        }
    }
}

enum TariffType: String, CaseIterable, Codable {
    case express = "Экспресс"
    case standard = "Стандартты"
    case economy = "Экономикалық"
    case international = "Халықаралық"

    var storageKey: String {
        switch self {
        case .express: return "express"
        case .standard: return "standard"
        case .economy: return "economy"
        case .international: return "international"
        }
    }

    init?(storageKeyOrRawValue: String) {
        if let direct = TariffType(rawValue: storageKeyOrRawValue) {
            self = direct
            return
        }
        switch storageKeyOrRawValue {
        case "express": self = .express
        case "standard": self = .standard
        case "economy": self = .economy
        case "international": self = .international
        default: return nil
        }
    }

    var basePrice: Int {
        switch self {
        case .express: return 2500
        case .standard: return 1500
        case .economy: return 800
        case .international: return 5000
        }
    }

    var deliveryDays: Int {
        switch self {
        case .express: return 2
        case .standard: return 5
        case .economy: return 7
        case .international: return 14
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

    static let catalog: [Tariff] = [
        Tariff(
            type: .express,
            name: "Экспресс жеткізу",
            description: "Жедел жеткізу 1-2 күн ішінде",
            price: "2 500 ₸",
            deliveryTime: "1-2 күн",
            features: ["Қауіпсіз орау", "Тегін қайта жіберу", "Телефондық қолдау"]
        ),
        Tariff(
            type: .standard,
            name: "Стандартты жеткізу",
            description: "Қарапайым жеткізу 3-5 күн ішінде",
            price: "1 500 ₸",
            deliveryTime: "3-5 күн",
            features: ["Қауіпсіз орау", "Телефондық қолдау"]
        ),
        Tariff(
            type: .economy,
            name: "Экономикалық жеткізу",
            description: "Үнемді жеткізу 5-7 күн ішінде",
            price: "800 ₸",
            deliveryTime: "5-7 күн",
            features: ["Негізгі орау", "Электрондық қолдау"]
        ),
        Tariff(
            type: .international,
            name: "Халықаралық жеткізу",
            description: "Шетелге жеткізу 7-14 күн ішінде",
            price: "5 000 ₸",
            deliveryTime: "7-14 күн",
            features: ["Кедендік өңдеу", "Сақтандыру", "24/7 қолдау"]
        )
    ]

    static func calculatePrice(
        tariff: TariffType,
        weight: Double,
        distanceKm: Int,
        insurance: Bool,
        urgentDelivery: Bool
    ) -> Int {
        var total = tariff.basePrice
        if weight > 2.0 {
            total += Int(((weight - 2.0) * 150.0).rounded())
        }
        if distanceKm > 0 {
            total += (distanceKm / 100) * 100
        }
        if insurance {
            total += 500
        }
        if urgentDelivery {
            total += 1000
        }
        return total
    }
}

enum DriverAnnotationType {
    case driver, delivery
}
