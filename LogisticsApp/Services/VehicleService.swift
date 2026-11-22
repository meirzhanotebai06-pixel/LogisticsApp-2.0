import Foundation
import Combine
import Supabase

@MainActor
class VehicleService: ObservableObject {
    private let client = SupabaseManager.client
    @Published var isLoading = false

    // MARK: - Save Vehicle Basic Info

    func saveVehicleBasicInfo(userId: String, model: String, plateNumber: String, capacity: String) async throws {
        let row = VehicleRow(
            driverId: userId.lowercased(),
            model: model.trimmingCharacters(in: .whitespacesAndNewlines),
            plateNumber: plateNumber.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
            capacity: capacity.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        try await client
            .from("vehicles")
            .upsert(row, onConflict: "driver_id")
            .execute()
    }

    // MARK: - Save Document

    func saveDocument(userId: String, documentType: DocumentType, documentInfo: DocumentInfo) async throws {
        let row = DriverDocumentRow.from(
            driverId: userId.lowercased(),
            type: documentType,
            info: documentInfo
        )

        try await client
            .from("driver_documents")
            .upsert(row, onConflict: "driver_id,document_type")
            .execute()
    }

    // MARK: - Load Vehicle Info

    func loadVehicleInfo(userId: String) async throws -> VehicleInfo? {
        let uid = userId.lowercased()

        let vehicles: [VehicleRow] = try await client
            .from("vehicles")
            .select()
            .eq("driver_id", value: uid)
            .limit(1)
            .execute()
            .value

        guard let vehicle = vehicles.first else { return nil }

        let docRows: [DriverDocumentRow] = try await client
            .from("driver_documents")
            .select()
            .eq("driver_id", value: uid)
            .execute()
            .value

        return VehicleInfo(
            model: vehicle.model,
            plateNumber: vehicle.plateNumber,
            capacity: vehicle.capacity,
            documents: VehicleDocuments.from(rows: docRows)
        )
    }

    // MARK: - Check Document Expiry

    func checkExpiringDocuments(userId: String) async throws -> [String] {
        guard let vehicleInfo = try await loadVehicleInfo(userId: userId),
              let documents = vehicleInfo.documents else {
            return []
        }

        var expiringDocs: [String] = []

        if let insurance = documents.insurance, let days = insurance.daysUntilExpiry, days <= 30 && !insurance.isExpired {
            expiringDocs.append("Сақтандыру")
        }
        if let license = documents.driverLicense, let days = license.daysUntilExpiry, days <= 30 && !license.isExpired {
            expiringDocs.append("Жүргізуші куәлігі")
        }
        if let registration = documents.vehicleRegistration, let days = registration.daysUntilExpiry, days <= 30 && !registration.isExpired {
            expiringDocs.append("Техпаспорт")
        }
        if let inspection = documents.technicalInspection, let days = inspection.daysUntilExpiry, days <= 30 && !inspection.isExpired {
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

        return allDocuments.allSatisfy { doc in
            guard let document = doc else { return false }
            return document.isVerified && !document.isExpired
        }
    }
}
