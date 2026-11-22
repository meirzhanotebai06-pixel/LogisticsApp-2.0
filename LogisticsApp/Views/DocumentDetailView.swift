import SwiftUI
import PhotosUI
import UIKit

struct DocumentDetailView: View {
    let documentType: DocumentType
    let document: DocumentInfo?
    let onSave: (DocumentType, DocumentInfo) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authService: AuthService
    @StateObject private var storageService = StorageService()

    @State private var documentNumber: String
    @State private var expiryDate: Date
    @State private var issueDate: Date
    @State private var issuedBy: String

    @State private var insuranceType: String
    @State private var insuranceCompany: String

    @State private var fullName: String
    @State private var iin: String
    @State private var category: String

    @State private var vin: String
    @State private var vehicleYear: String
    @State private var color: String
    @State private var engineNumber: String
    @State private var capacity: String

    @State private var inspectionCenter: String

    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var existingFileURL: String?

    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showSuccess = false

    init(
        documentType: DocumentType,
        document: DocumentInfo?,
        onSave: @escaping (DocumentType, DocumentInfo) async throws -> Void
    ) {
        self.documentType = documentType
        self.document = document
        self.onSave = onSave

        let defaultExpiry = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
        _documentNumber = State(initialValue: document?.number ?? "")
        _expiryDate = State(initialValue: document?.expiryDate ?? defaultExpiry)
        _issueDate = State(initialValue: document?.issueDate ?? Date())
        _issuedBy = State(initialValue: document?.issuedBy ?? "")
        _insuranceType = State(initialValue: document?.insuranceType ?? "ОСАГО")
        _insuranceCompany = State(initialValue: document?.insuranceCompany ?? "")
        _fullName = State(initialValue: document?.fullName ?? "")
        _iin = State(initialValue: document?.iin ?? "")
        _category = State(initialValue: document?.category ?? "")
        _vin = State(initialValue: document?.vin ?? "")
        _vehicleYear = State(initialValue: document?.vehicleYear ?? "")
        _color = State(initialValue: document?.color ?? "")
        _engineNumber = State(initialValue: document?.engineNumber ?? "")
        _capacity = State(initialValue: document?.capacity ?? "")
        _inspectionCenter = State(initialValue: document?.inspectionCenter ?? "")
        _existingFileURL = State(initialValue: document?.fileURL)
    }

    var body: some View {
        Form {
            if let status = document?.verificationStatus {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: statusIcon(status))
                            .foregroundColor(statusColor(status))

                        VStack(alignment: .leading, spacing: 4) {
                            Text(statusTitle(status))
                                .font(.headline)
                                .foregroundColor(statusColor(status))

                            Text(statusDescription(status))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    if status == "rejected", let reason = document?.rejectionReason {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Қабылданбау себебі:")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.red)

                            Text(reason)
                                .font(.subheadline)
                        }
                    }
                }
            }

            switch documentType {
            case .insurance:
                insuranceForm()
            case .driverLicense:
                driverLicenseForm()
            case .vehicleRegistration:
                vehicleRegistrationForm()
            case .technicalInspection:
                technicalInspectionForm()
            }

            Section(header: Text("Құжат фотосуреті")) {
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Label(
                        selectedImageData != nil || existingFileURL != nil ? "Фотоны ауыстыру" : "Фото тіркеу",
                        systemImage: "photo.on.rectangle.angled"
                    )
                }

                if let data = selectedImageData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 200)
                        .cornerRadius(8)
                } else if let urlString = existingFileURL, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(height: 120)
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 200)
                                .cornerRadius(8)
                        case .failure:
                            Label("Файл жүктелді, алдын ала көру мүмкін емес", systemImage: "doc.fill")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        @unknown default:
                            EmptyView()
                        }
                    }
                }
            }

            if let validationError {
                Section {
                    Text(validationError)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }

            Section {
                Button {
                    Task { await saveDocument() }
                } label: {
                    if isLoading {
                        HStack {
                            ProgressView()
                            Text("Сақталуда...")
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        Text("Сақтау")
                            .frame(maxWidth: .infinity)
                            .fontWeight(.semibold)
                    }
                }
                .disabled(!canSave || isLoading)
            }
        }
        .navigationTitle(documentType.title)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: selectedPhotoItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                    if let uiImage = UIImage(data: data),
                       let compressed = uiImage.jpegData(compressionQuality: 0.7) {
                        selectedImageData = compressed
                    } else {
                        selectedImageData = data
                    }
                }
            }
        }
        .alert("Сәтті сақталды!", isPresented: $showSuccess) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Құжат деректері сәтті сақталды және тексеруге жіберілді")
        }
        .alert("Қате", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Forms

    @ViewBuilder
    private func insuranceForm() -> some View {
        Section(header: Text("Сақтандыру деректері")) {
            Picker("Сақтандыру түрі", selection: $insuranceType) {
                Text("ОСАГО").tag("ОСАГО")
                Text("КАСКО").tag("КАСКО")
            }

            TextField("Полис нөмірі", text: $documentNumber)
                .textInputAutocapitalization(.characters)

            TextField("Сақтандыру компаниясы", text: $insuranceCompany)

            DatePicker("Берілген күні", selection: $issueDate, displayedComponents: .date)
            DatePicker("Жарамдылық мерзімі", selection: $expiryDate, in: Date()..., displayedComponents: .date)
        }
    }

    @ViewBuilder
    private func driverLicenseForm() -> some View {
        Section(header: Text("Жүргізуші куәлігі деректері")) {
            TextField("Куәлік нөмірі", text: $documentNumber)
                .textInputAutocapitalization(.characters)

            TextField("Толық аты-жөні", text: $fullName)

            TextField("ЖСН (12 цифр)", text: $iin)
                .keyboardType(.numberPad)

            TextField("Категориялар (мысалы: B, C)", text: $category)
                .textInputAutocapitalization(.characters)

            TextField("Берген орган", text: $issuedBy)

            DatePicker("Берілген күні", selection: $issueDate, displayedComponents: .date)
            DatePicker("Жарамдылық мерзімі", selection: $expiryDate, in: Date()..., displayedComponents: .date)
        }
    }

    @ViewBuilder
    private func vehicleRegistrationForm() -> some View {
        Section(
            header: Text("Техпаспорт деректері"),
            footer: Text("Техпаспорт мерзімсіз құжат болып табылады.")
        ) {
            TextField("Техпаспорт нөмірі", text: $documentNumber)
                .textInputAutocapitalization(.characters)

            TextField("VIN-код (17 таңба)", text: $vin)
                .textInputAutocapitalization(.characters)

            TextField("Шыққан жылы", text: $vehicleYear)
                .keyboardType(.numberPad)

            TextField("Түсі", text: $color)

            TextField("Двигатель нөмірі", text: $engineNumber)
                .textInputAutocapitalization(.characters)

            TextField("Сыйымдылық (мысалы: 2000 cc)", text: $capacity)

            TextField("Берген орган", text: $issuedBy)

            DatePicker("Берілген күні", selection: $issueDate, displayedComponents: .date)
        }
    }

    @ViewBuilder
    private func technicalInspectionForm() -> some View {
        Section(header: Text("Техосмотр деректері")) {
            TextField("Диагностикалық карта нөмірі", text: $documentNumber)
                .textInputAutocapitalization(.characters)

            TextField("Өткізген орын", text: $inspectionCenter)

            DatePicker("Өткізілген күні", selection: $issueDate, displayedComponents: .date)
            DatePicker("Жарамдылық мерзімі", selection: $expiryDate, in: Date()..., displayedComponents: .date)
        }
    }

    // MARK: - Validation

    private var validationError: String? {
        if documentNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Құжат нөмірін енгізіңіз"
        }

        if documentType.requiresExpiryDate && expiryDate <= issueDate {
            return "Жарамдылық мерзімі берілген күннен кейін болуы керек"
        }

        switch documentType {
        case .driverLicense:
            if !iin.isEmpty && !AuthValidation.isValidIIN(iin) {
                return "ЖСН 12 цифрдан тұруы керек"
            }
        case .vehicleRegistration:
            if !vin.isEmpty && !AuthValidation.isValidVIN(vin) {
                return "VIN-код 17 латын әрпі мен цифрдан тұруы керек (I, O, Q қолданылмайды)"
            }
            if !vehicleYear.isEmpty && !AuthValidation.isValidVehicleYear(vehicleYear) {
                return "Шыққан жылын дұрыс енгізіңіз"
            }
        case .insurance, .technicalInspection:
            break
        }

        return nil
    }

    private var canSave: Bool {
        validationError == nil
    }

    private func statusIcon(_ status: String) -> String {
        switch status {
        case "pending": return "clock.fill"
        case "approved": return "checkmark.seal.fill"
        case "rejected": return "xmark.seal.fill"
        default: return "clock.fill"
        }
    }

    private func statusColor(_ status: String) -> Color {
        switch status {
        case "pending": return .orange
        case "approved": return .green
        case "rejected": return .red
        default: return .orange
        }
    }

    private func statusTitle(_ status: String) -> String {
        switch status {
        case "pending": return "Тексеруді күтуде"
        case "approved": return "Бекітілген"
        case "rejected": return "Қабылданбаған"
        default: return "Тексеруді күтуде"
        }
    }

    private func statusDescription(_ status: String) -> String {
        switch status {
        case "pending": return "Құжат администратор тарапынан тексерілуде"
        case "approved": return "Құжат бекітілді және қолдануға дайын"
        case "rejected": return "Құжат қабылданбады, деректерді түзетіп қайта жіберіңіз"
        default: return "Тексеруді күтуде"
        }
    }

    private func saveDocument() async {
        guard let userId = authService.currentUser?.id else {
            errorMessage = "Пайдаланушы анықталмады"
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            var uploadedURL = existingFileURL
            if let imageData = selectedImageData {
                let fileName = "\(UUID().uuidString).jpg"
                uploadedURL = try await storageService.uploadDocumentFile(
                    userId: userId,
                    documentType: documentType,
                    fileData: imageData,
                    fileName: fileName
                )
            }

            let trimmedNumber = documentNumber.trimmingCharacters(in: .whitespacesAndNewlines)
            let documentInfo = DocumentInfo(
                number: trimmedNumber,
                expiryDate: documentType.requiresExpiryDate ? expiryDate : nil,
                isVerified: false,
                fileURL: uploadedURL,
                uploadDate: Date(),
                verificationStatus: "pending",
                rejectionReason: nil,
                issueDate: issueDate,
                issuedBy: issuedBy.isEmpty ? nil : issuedBy.trimmingCharacters(in: .whitespacesAndNewlines),
                fullName: fullName.isEmpty ? nil : fullName.trimmingCharacters(in: .whitespacesAndNewlines),
                iin: iin.isEmpty ? nil : iin.trimmingCharacters(in: .whitespacesAndNewlines),
                category: category.isEmpty ? nil : category.trimmingCharacters(in: .whitespacesAndNewlines),
                insuranceType: insuranceType.isEmpty ? nil : insuranceType,
                insuranceCompany: insuranceCompany.isEmpty ? nil : insuranceCompany.trimmingCharacters(in: .whitespacesAndNewlines),
                vin: vin.isEmpty ? nil : vin.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
                vehicleYear: vehicleYear.isEmpty ? nil : vehicleYear.trimmingCharacters(in: .whitespacesAndNewlines),
                color: color.isEmpty ? nil : color.trimmingCharacters(in: .whitespacesAndNewlines),
                engineNumber: engineNumber.isEmpty ? nil : engineNumber.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
                capacity: capacity.isEmpty ? nil : capacity.trimmingCharacters(in: .whitespacesAndNewlines),
                inspectionCenter: inspectionCenter.isEmpty ? nil : inspectionCenter.trimmingCharacters(in: .whitespacesAndNewlines)
            )

            try await onSave(documentType, documentInfo)
            existingFileURL = uploadedURL
            showSuccess = true
        } catch {
            errorMessage = "Сақтау сәтсіз: \(error.localizedDescription)"
        }
    }
}
