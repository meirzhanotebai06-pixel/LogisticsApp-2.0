import Foundation
import FirebaseFirestore
import Combine

enum DocumentVerificationStatus: String {
    case pending
    case approved
    case rejected
}

final class AdminService: ObservableObject {
    @Published var drivers: [User] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var updatingDocumentKey: String?

    private let db = Firestore.firestore()
    private var driversListener: ListenerRegistration?

    func startListening() {
        stopListening()
        isLoading = true

        driversListener = db.collection("users")
            .whereField("userType", isEqualTo: UserType.driver.rawValue)
            .addSnapshotListener { [weak self] snapshot, error in
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.isLoading = false

                    if let error {
                        self.errorMessage = "Не удалось загрузить водителей: \(error.localizedDescription)"
                        return
                    }

                    self.drivers = snapshot?.documents
                        .compactMap { User.fromDictionary($0.data()) }
                        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending } ?? []
                }
            }
    }

    func stopListening() {
        driversListener?.remove()
        driversListener = nil
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
            errorMessage = "Не удалось изменить статус документа: \(error.localizedDescription)"
        }
    }

    deinit {
        driversListener?.remove()
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
