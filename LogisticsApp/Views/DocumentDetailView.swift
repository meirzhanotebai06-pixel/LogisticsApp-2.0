import SwiftUI

struct DocumentDetailView: View {
    let documentType: DocumentType
    let document: DocumentInfo?
    let onSave: (DocumentType, DocumentInfo) -> Void
    
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authService: AuthService
    
    // Общие поля
    @State private var documentNumber: String
    @State private var expiryDate: Date
    @State private var issueDate: Date
    @State private var issuedBy: String
    
    // Для страховки
    @State private var insuranceType: String
    @State private var insuranceCompany: String
    
    // Для водительских прав
    @State private var fullName: String
    @State private var iin: String
    @State private var category: String
    
    // Для техпаспорта
    @State private var vin: String
    @State private var vehicleYear: String
    @State private var color: String
    @State private var engineNumber: String
    @State private var capacity: String
    
    // Для техосмотра
    @State private var inspectionCenter: String
    
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showSuccess = false
    
    init(documentType: DocumentType, document: DocumentInfo?, onSave: @escaping (DocumentType, DocumentInfo) -> Void) {
        self.documentType = documentType
        self.document = document
        self.onSave = onSave
        
        // Все поля пустые по умолчанию
        _documentNumber = State(initialValue: document?.number ?? "")
        _expiryDate = State(initialValue: document?.expiryDate ?? Date())
        _issueDate = State(initialValue: document?.issueDate ?? Date())
        _issuedBy = State(initialValue: document?.issuedBy ?? "")
        _insuranceType = State(initialValue: document?.insuranceType ?? "")
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
    }
    
    var body: some View {
        Form {
            // Статус проверки
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
                        VStack(alignment: .leading, spacing: 8) {
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
            
            // Форма в зависимости от типа документа
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
            
            // Кнопка сохранения
            Section {
                Button(action: saveDocument) {
                    if isLoading {
                        HStack {
                            ProgressView()
                            Text("Сақталуда...")
                        }
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
        .alert("Сәтті сақталды!", isPresented: $showSuccess) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Құжат деректері сәтті сақталды және тексеруге жіберілді")
        }
        .alert("Қате", isPresented: .constant(errorMessage != nil)) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            if let error = errorMessage {
                Text(error)
            }
        }
    }
    
    // MARK: - Insurance Form
    
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
    
    // MARK: - Driver License Form
    
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
    
    // MARK: - Vehicle Registration Form
    
    @ViewBuilder
    private func vehicleRegistrationForm() -> some View {
        Section(header: Text("Техпаспорт деректері")) {
            TextField("Техпаспорт нөмірі", text: $documentNumber)
                .textInputAutocapitalization(.characters)
            
            TextField("VIN-код", text: $vin)
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
    
    // MARK: - Technical Inspection Form
    
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
    
    // MARK: - Helper Methods
    
    private var canSave: Bool {
        return !documentNumber.isEmpty
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
    
    private func saveDocument() {
        print("📝 Сохранение документа \(documentType.title)")
        
        isLoading = true
        
        let documentInfo = DocumentInfo(
            number: documentNumber,
            expiryDate: expiryDate,
            isVerified: false,
            fileURL: nil,
            uploadDate: Date(),
            verificationStatus: "pending",
            rejectionReason: nil,
            issueDate: issueDate,
            issuedBy: issuedBy.isEmpty ? nil : issuedBy,
            fullName: fullName.isEmpty ? nil : fullName,
            iin: iin.isEmpty ? nil : iin,
            category: category.isEmpty ? nil : category,
            insuranceType: insuranceType.isEmpty ? nil : insuranceType,
            insuranceCompany: insuranceCompany.isEmpty ? nil : insuranceCompany,
            vin: vin.isEmpty ? nil : vin,
            vehicleYear: vehicleYear.isEmpty ? nil : vehicleYear,
            color: color.isEmpty ? nil : color,
            engineNumber: engineNumber.isEmpty ? nil : engineNumber,
            capacity: capacity.isEmpty ? nil : capacity,
            inspectionCenter: inspectionCenter.isEmpty ? nil : inspectionCenter
        )
        
        print("✅ Документ создан, отправка на сохранение")
        onSave(documentType, documentInfo)
        
        isLoading = false
        showSuccess = true
    }
}
