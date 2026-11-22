import Foundation
import CoreLocation
import FirebaseFirestore

// MARK: - User Models

struct User: Codable, Identifiable {
    let id: String
    let email: String
    let name: String
    let userType: UserType
    let phone: String?
    let vehicleInfo: VehicleInfo?
    let isOnDuty: Bool?
    let rating: Double?

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
        let vehicleInfo = vehicleInfoDict.flatMap { VehicleInfo.fromDictionary($0) }
        let isOnDuty = dict["isOnDuty"] as? Bool
        let rating = (dict["rating"] as? NSNumber)?.doubleValue

        return User(
            id: id,
            email: email,
            name: name,
            userType: userType,
            phone: phone,
            vehicleInfo: vehicleInfo,
            isOnDuty: isOnDuty,
            rating: rating
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
        let documents = documentsDict.flatMap { VehicleDocuments.fromDictionary($0) }

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
        guard let expiryDate else { return false }
        return expiryDate < Date()
    }

    var daysUntilExpiry: Int? {
        guard let expiryDate else { return nil }
        let calendar = Calendar.current
        return calendar.dateComponents([.day], from: Date(), to: expiryDate).day
    }

    static func fromDictionary(_ dict: [String: Any]) -> DocumentInfo? {
        guard let number = dict["number"] as? String,
              let isVerified = dict["isVerified"] as? Bool else {
            return nil
        }

        let expiryDate = (dict["expiryDate"] as? Timestamp)?.dateValue()
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
            expiryDate: expiryDate,
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

    var displayTitle: String {
        switch self {
        case .client: return "Клиент"
        case .driver: return "Жүргізуші"
        case .admin: return "Администратор"
        }
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
