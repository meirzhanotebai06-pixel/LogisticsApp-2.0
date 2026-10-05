import SwiftUI
import PhotosUI

struct VehicleInfoView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var vehicleService = VehicleService()
    @State private var vehicleInfo: VehicleInfo?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showAddVehicleSheet = false
    
    var body: some View {
        NavigationView {
            ZStack {
                if let vehicle = vehicleInfo {
                    ScrollView {
                        VStack(spacing: 20) {
                            // Основная информация о транспорте
                            VehicleBasicInfoSection(
                                vehicle: vehicle,
                                onEdit: {
                                    showAddVehicleSheet = true
                                }
                            )
                            
                            // Разделы документов
                            VStack(spacing: 16) {
                                Text("Құжаттар")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal)
                                
                                NavigationLink(destination: DocumentDetailView(
                                    documentType: .insurance,
                                    document: vehicle.documents?.insurance,
                                    onSave: saveDocument
                                )) {
                                    DocumentSectionCard(
                                        title: "Сақтандыру",
                                        icon: "shield.fill",
                                        document: vehicle.documents?.insurance
                                    )
                                }
                                
                                NavigationLink(destination: DocumentDetailView(
                                    documentType: .driverLicense,
                                    document: vehicle.documents?.driverLicense,
                                    onSave: saveDocument
                                )) {
                                    DocumentSectionCard(
                                        title: "Жүргізуші куәлігі",
                                        icon: "person.text.rectangle.fill",
                                        document: vehicle.documents?.driverLicense
                                    )
                                }
                                
                                NavigationLink(destination: DocumentDetailView(
                                    documentType: .vehicleRegistration,
                                    document: vehicle.documents?.vehicleRegistration,
                                    onSave: saveDocument
                                )) {
                                    DocumentSectionCard(
                                        title: "Техпаспорт",
                                        icon: "doc.text.fill",
                                        document: vehicle.documents?.vehicleRegistration
                                    )
                                }
                                
                                NavigationLink(destination: DocumentDetailView(
                                    documentType: .technicalInspection,
                                    document: vehicle.documents?.technicalInspection,
                                    onSave: saveDocument
                                )) {
                                    DocumentSectionCard(
                                        title: "Техосмотр",
                                        icon: "wrench.and.screwdriver.fill",
                                        document: vehicle.documents?.technicalInspection
                                    )
                                }
                            }
                        }
                        .padding(.vertical)
                    }
                } else {
                    EmptyVehicleView(onAdd: {
                        showAddVehicleSheet = true
                    })
                }
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.2))
                }
            }
            .navigationTitle("Көлік ақпараты")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showAddVehicleSheet) {
                AddVehicleBasicInfoView(
                    existingVehicle: vehicleInfo,
                    onSave: saveVehicleBasicInfo
                )
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
            .onAppear {
                loadVehicleInfo()
            }
        }
    }
    
    private func loadVehicleInfo() {
        vehicleInfo = authService.currentUser?.vehicleInfo
        
        if vehicleInfo == nil, let userId = authService.currentUser?.id {
            Task {
                isLoading = true
                do {
                    vehicleInfo = try await vehicleService.loadVehicleInfo(userId: userId)
                } catch {
                    errorMessage = "Жүктеу қатесі: \(error.localizedDescription)"
                }
                isLoading = false
            }
        }
    }
    
    private func saveVehicleBasicInfo(model: String, plateNumber: String, capacity: String) {
        guard let userId = authService.currentUser?.id else { return }
        
        Task {
            isLoading = true
            do {
                try await vehicleService.saveVehicleBasicInfo(
                    userId: userId,
                    model: model,
                    plateNumber: plateNumber,
                    capacity: capacity
                )
                
                vehicleInfo = try await vehicleService.loadVehicleInfo(userId: userId)
                showAddVehicleSheet = false
            } catch {
                errorMessage = "Сақтау қатесі: \(error.localizedDescription)"
            }
            isLoading = false
        }
    }
    
    private func saveDocument(type: DocumentType, documentInfo: DocumentInfo) {
        guard let userId = authService.currentUser?.id else { return }
        
        Task {
            isLoading = true
            do {
                try await vehicleService.saveDocument(
                    userId: userId,
                    documentType: type,
                    documentInfo: documentInfo
                )
                
                vehicleInfo = try await vehicleService.loadVehicleInfo(userId: userId)
            } catch {
                errorMessage = "Сақтау қатесі: \(error.localizedDescription)"
            }
            isLoading = false
        }
    }
}

// MARK: - Vehicle Basic Info Section

struct VehicleBasicInfoSection: View {
    let vehicle: VehicleInfo
    let onEdit: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Көлік туралы")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button(action: onEdit) {
                    Image(systemName: "pencil.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal)
            
            VStack(spacing: 16) {
                Image(systemName: "car.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                VStack(spacing: 12) {
                    VehicleInfoRow(label: "Көлік атауы", value: vehicle.model)
                    Divider()
                    VehicleInfoRow(label: "Нөмір", value: vehicle.plateNumber)
                    Divider()
                    VehicleInfoRow(label: "Сыйымдылық", value: vehicle.capacity)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
            }
            .padding()
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: .gray.opacity(0.2), radius: 3, x: 0, y: 1)
            .padding(.horizontal)
        }
    }
}

struct VehicleInfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.headline)
        }
    }
}

// MARK: - Document Section Card

struct DocumentSectionCard: View {
    let title: String
    let icon: String
    let document: DocumentInfo?
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(statusColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                if document != nil {
                    HStack(spacing: 8) {
                        Image(systemName: statusIcon)
                            .font(.caption)
                            .foregroundColor(statusColor)
                        
                        Text(statusText)
                            .font(.caption)
                            .foregroundColor(statusColor)
                    }
                } else {
                    Text("Құжат қосылмаған")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .gray.opacity(0.1), radius: 3, x: 0, y: 1)
        .padding(.horizontal)
    }
    
    private var statusColor: Color {
        guard let doc = document else { return .gray }
        if doc.isExpired { return .red }
        if doc.verificationStatus == "rejected" { return .red }
        if !doc.isVerified { return .orange }
        if doc.daysUntilExpiry <= 30 { return .orange }
        return .green
    }
    
    private var statusIcon: String {
        guard let doc = document else { return "exclamationmark.circle" }
        if doc.isExpired { return "xmark.circle.fill" }
        if doc.verificationStatus == "rejected" { return "xmark.seal.fill" }
        if !doc.isVerified { return "clock.fill" }
        if doc.daysUntilExpiry <= 30 { return "exclamationmark.triangle.fill" }
        return "checkmark.circle.fill"
    }
    
    private var statusText: String {
        guard let doc = document else { return "Жоқ" }
        if doc.isExpired { return "Мерзімі өтті" }
        if doc.verificationStatus == "rejected" { return "Қабылданбаған" }
        if !doc.isVerified { return "Тексеруді күтуде" }
        if doc.daysUntilExpiry <= 30 { return "\(doc.daysUntilExpiry) күн қалды" }
        return "Бекітілген"
    }
}

// MARK: - Empty Vehicle View

struct EmptyVehicleView: View {
    let onAdd: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "car.circle")
                .font(.system(size: 80))
                .foregroundColor(.gray)
            
            Text("Көлік ақпараты жоқ")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Жеткізу жасау үшін көлік туралы ақпарат қосыңыз")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Көлік қосу", action: onAdd)
                .padding(.horizontal, 30)
                .padding(.vertical, 12)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
        }
        .padding()
    }
}

// MARK: - Add Vehicle Basic Info View

struct AddVehicleBasicInfoView: View {
    let existingVehicle: VehicleInfo?
    let onSave: (String, String, String) -> Void
    
    @Environment(\.dismiss) var dismiss
    @State private var model: String
    @State private var plateNumber: String
    @State private var capacity: String
    
    init(existingVehicle: VehicleInfo?, onSave: @escaping (String, String, String) -> Void) {
        self.existingVehicle = existingVehicle
        self.onSave = onSave
        _model = State(initialValue: existingVehicle?.model ?? "")
        _plateNumber = State(initialValue: existingVehicle?.plateNumber ?? "")
        _capacity = State(initialValue: existingVehicle?.capacity ?? "")
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Көлік туралы ақпарат")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Көлік атауы")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Мысалы: Toyota Camry", text: $model)
                            .textInputAutocapitalization(.words)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Нөмір")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Мысалы: A123BC77", text: $plateNumber)
                            .textInputAutocapitalization(.characters)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Сыйымдылық")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Мысалы: 1500 кг", text: $capacity)
                    }
                }
                
                Section {
                    Button("Сақтау") {
                        onSave(model, plateNumber, capacity)
                        dismiss()
                    }
                    .disabled(model.isEmpty || plateNumber.isEmpty || capacity.isEmpty)
                    .frame(maxWidth: .infinity)
                    .foregroundColor(model.isEmpty || plateNumber.isEmpty || capacity.isEmpty ? .gray : .blue)
                }
            }
            .navigationTitle(existingVehicle == nil ? "Көлік қосу" : "Көлікті өзгерту")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Бас тарту") {
                    dismiss()
                }
            )
        }
    }
}

// MARK: - Document Type Enum

enum DocumentType: CaseIterable, Identifiable {
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
        switch self {
        case .insurance: return "insurance"
        case .driverLicense: return "driverLicense"
        case .vehicleRegistration: return "vehicleRegistration"
        case .technicalInspection: return "technicalInspection"
        }
    }
}

// MARK: - Preview

struct VehicleInfoView_Previews: PreviewProvider {
    static var previews: some View {
        VehicleInfoView()
            .environmentObject(AuthService())
    }
}
