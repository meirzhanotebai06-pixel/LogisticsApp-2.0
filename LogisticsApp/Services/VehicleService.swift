import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

class VehicleService: ObservableObject {
    private let db = Firestore.firestore()
    @Published var isLoading = false
    
    // MARK: - Save Vehicle Info
    
    func saveVehicleInfo(userId: String, vehicleInfo: VehicleInfo) async throws {
        let vehicleData: [String: Any] = [
            "model": vehicleInfo.model,
            "plateNumber": vehicleInfo.plateNumber,
            "capacity": vehicleInfo.capacity,
            "documents": vehicleInfo.documents != nil ? documentsToDict(vehicleInfo.documents!) : [:]
        ]
        
        try await db.collection("users").document(userId).updateData([
            "vehicleInfo": vehicleData
        ])
    }
    
    // MARK: - Save Document
    
    func saveDocument(userId: String, documentType: DocumentType, documentInfo: DocumentInfo) async throws {
        let fieldPath = "vehicleInfo.documents.\(documentType.fieldName)"
        
        try await db.collection("users").document(userId).updateData([
            fieldPath: documentInfoToDict(documentInfo)
        ])
    }
    
    // MARK: - Save Vehicle Basic Info
    
    func saveVehicleBasicInfo(userId: String, model: String, plateNumber: String, capacity: String) async throws {
        try await db.collection("users").document(userId).updateData([
            "vehicleInfo.model": model,
            "vehicleInfo.plateNumber": plateNumber,
            "vehicleInfo.capacity": capacity
        ])
    }
    
    // MARK: - Load Vehicle Info
    
    func loadVehicleInfo(userId: String) async throws -> VehicleInfo? {
        let document = try await db.collection("users").document(userId).getDocument()
        
        guard let data = document.data(),
              let vehicleInfoDict = data["vehicleInfo"] as? [String: Any] else {
            return nil
        }
        
        return VehicleInfo.fromDictionary(vehicleInfoDict)
    }
    
    // MARK: - Check Document Expiry
    
    func checkExpiringDocuments(userId: String) async throws -> [String] {
        guard let vehicleInfo = try await loadVehicleInfo(userId: userId),
              let documents = vehicleInfo.documents else {
            return []
        }
        
        var expiringDocs: [String] = []
        
        if let insurance = documents.insurance, insurance.daysUntilExpiry <= 30 && !insurance.isExpired {
            expiringDocs.append("Сақтандыру")
        }
        
        if let license = documents.driverLicense, license.daysUntilExpiry <= 30 && !license.isExpired {
            expiringDocs.append("Жүргізуші куәлігі")
        }
        
        if let registration = documents.vehicleRegistration, registration.daysUntilExpiry <= 30 && !registration.isExpired {
            expiringDocs.append("Техпаспорт")
        }
        
        if let inspection = documents.technicalInspection, inspection.daysUntilExpiry <= 30 && !inspection.isExpired {
            expiringDocs.append("Техосмотр")
        }
        
        return expiringDocs
    }
    
    // MARK: - Verify All Documents
    
    func areAllDocumentsValid(vehicleInfo: VehicleInfo?) -> Bool {
        guard let documents = vehicleInfo?.documents else {
            return false
        }
        
        let allDocuments = [
            documents.insurance,
            documents.driverLicense,
            documents.vehicleRegistration,
            documents.technicalInspection
        ]
        
        // Документ действителен только после подтверждения администратором.
        return allDocuments.allSatisfy { doc in
            guard let document = doc else { return false }
            return document.isVerified && !document.isExpired
        }
    }
    
    // MARK: - Helper Methods
    
    private func documentsToDict(_ documents: VehicleDocuments) -> [String: Any] {
        var dict: [String: Any] = [:]
        
        if let insurance = documents.insurance {
            dict["insurance"] = documentInfoToDict(insurance)
        }
        
        if let license = documents.driverLicense {
            dict["driverLicense"] = documentInfoToDict(license)
        }
        
        if let registration = documents.vehicleRegistration {
            dict["vehicleRegistration"] = documentInfoToDict(registration)
        }
        
        if let inspection = documents.technicalInspection {
            dict["technicalInspection"] = documentInfoToDict(inspection)
        }
        
        return dict
    }
    
    private func documentInfoToDict(_ doc: DocumentInfo) -> [String: Any] {
        var dict: [String: Any] = [
            "number": doc.number,
            "expiryDate": Timestamp(date: doc.expiryDate),
            "isVerified": doc.isVerified
        ]
        
        if let fileURL = doc.fileURL {
            dict["fileURL"] = fileURL
        }
        
        if let uploadDate = doc.uploadDate {
            dict["uploadDate"] = Timestamp(date: uploadDate)
        }

        if let verificationStatus = doc.verificationStatus {
            dict["verificationStatus"] = verificationStatus
        }

        if let rejectionReason = doc.rejectionReason {
            dict["rejectionReason"] = rejectionReason
        }

        if let issueDate = doc.issueDate {
            dict["issueDate"] = Timestamp(date: issueDate)
        }

        if let issuedBy = doc.issuedBy { dict["issuedBy"] = issuedBy }
        if let fullName = doc.fullName { dict["fullName"] = fullName }
        if let iin = doc.iin { dict["iin"] = iin }
        if let category = doc.category { dict["category"] = category }
        if let insuranceType = doc.insuranceType { dict["insuranceType"] = insuranceType }
        if let insuranceCompany = doc.insuranceCompany { dict["insuranceCompany"] = insuranceCompany }
        if let vin = doc.vin { dict["vin"] = vin }
        if let vehicleYear = doc.vehicleYear { dict["vehicleYear"] = vehicleYear }
        if let color = doc.color { dict["color"] = color }
        if let engineNumber = doc.engineNumber { dict["engineNumber"] = engineNumber }
        if let capacity = doc.capacity { dict["capacity"] = capacity }
        if let inspectionCenter = doc.inspectionCenter { dict["inspectionCenter"] = inspectionCenter }
        
        return dict
    }
}

