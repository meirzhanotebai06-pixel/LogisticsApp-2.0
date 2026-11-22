import SwiftUI

struct VehicleInfoView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var vehicleService = VehicleService()
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showAddVehicleSheet = false

    private var vehicleInfo: VehicleInfo? {
        authService.currentUser?.vehicleInfo
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                if let vehicle = vehicleInfo {
                    ScrollView {
                        VStack(spacing: 20) {
                            VehicleBasicInfoSection(
                                vehicle: vehicle,
                                onEdit: {
                                    showAddVehicleSheet = true
                                }
                            )

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
                        .scaleEffect(1.4)
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
            .alert("Қате", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func saveVehicleBasicInfo(model: String, plateNumber: String, capacity: String) {
        guard let userId = authService.currentUser?.id else { return }

        Task {
            isLoading = true
            defer { isLoading = false }
            do {
                try await vehicleService.saveVehicleBasicInfo(
                    userId: userId,
                    model: model,
                    plateNumber: plateNumber,
                    capacity: capacity
                )
                showAddVehicleSheet = false
            } catch {
                errorMessage = "Сақтау қатесі: \(error.localizedDescription)"
            }
        }
    }

    private func saveDocument(type: DocumentType, documentInfo: DocumentInfo) async throws {
        guard let userId = authService.currentUser?.id else {
            throw NSError(domain: "Auth", code: 401, userInfo: [NSLocalizedDescriptionKey: "Пайдаланушы анықталмады"])
        }
        try await vehicleService.saveDocument(
            userId: userId,
            documentType: type,
            documentInfo: documentInfo
        )
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
                    .font(.system(size: 56))
                    .foregroundColor(.blue)

                VStack(spacing: 12) {
                    VehicleInfoRow(label: "Көлік атауы", value: vehicle.model)
                    Divider()
                    VehicleInfoRow(label: "Нөмір", value: vehicle.plateNumber)
                    Divider()
                    VehicleInfoRow(label: "Сыйымдылық", value: vehicle.capacity)
                }
                .padding()
                .background(Color(.tertiarySystemGroupedBackground))
                .cornerRadius(12)
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.06), radius: 3, x: 0, y: 1)
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
                    HStack(spacing: 6) {
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
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.06), radius: 3, x: 0, y: 1)
        .padding(.horizontal)
    }

    private var statusColor: Color {
        guard let doc = document else { return .gray }
        if doc.isExpired { return .red }
        if doc.verificationStatus == "rejected" { return .red }
        if !doc.isVerified { return .orange }
        if let days = doc.daysUntilExpiry, days <= 30 { return .orange }
        return .green
    }

    private var statusIcon: String {
        guard let doc = document else { return "exclamationmark.circle" }
        if doc.isExpired { return "xmark.circle.fill" }
        if doc.verificationStatus == "rejected" { return "xmark.seal.fill" }
        if !doc.isVerified { return "clock.fill" }
        if let days = doc.daysUntilExpiry, days <= 30 { return "exclamationmark.triangle.fill" }
        return "checkmark.circle.fill"
    }

    private var statusText: String {
        guard let doc = document else { return "Жоқ" }
        if doc.isExpired { return "Мерзімі өтті" }
        if doc.verificationStatus == "rejected" { return "Қабылданбаған" }
        if !doc.isVerified { return "Тексеруді күтуде" }
        if let days = doc.daysUntilExpiry, days <= 30 { return "\(days) күн қалды" }
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
                .foregroundColor(.secondary)

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

    @Environment(\.dismiss) private var dismiss
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
        NavigationStack {
            Form {
                Section(header: Text("Көлік туралы ақпарат")) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Көлік атауы")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Мысалы: Toyota Hiace", text: $model)
                            .textInputAutocapitalization(.words)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Нөмір")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Мысалы: 012ABC02", text: $plateNumber)
                            .textInputAutocapitalization(.characters)
                    }

                    VStack(alignment: .leading, spacing: 6) {
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
                    .disabled(isDisabled)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle(existingVehicle == nil ? "Көлік қосу" : "Көлікті өзгерту")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Бас тарту") { dismiss() }
                }
            }
        }
    }

    private var isDisabled: Bool {
        model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        plateNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        capacity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
