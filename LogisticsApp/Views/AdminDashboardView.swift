import SwiftUI

struct AdminDashboardView: View {
    @EnvironmentObject private var authService: AuthService
    @StateObject private var adminService = AdminService()

    private var pendingCount: Int {
        adminService.drivers.reduce(0) { result, driver in
            result + (driver.vehicleInfo?.documents?.allDocuments.filter {
                $0.effectiveVerificationStatus == .pending
            }.count ?? 0)
        }
    }

    var body: some View {
        NavigationView {
            Group {
                if adminService.isLoading && adminService.drivers.isEmpty {
                    ProgressView("Загрузка водителей...")
                } else if adminService.drivers.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "person.badge.shield.checkmark")
                            .font(.system(size: 56))
                            .foregroundColor(.secondary)
                        Text("Водителей пока нет")
                            .font(.headline)
                        Text("Зарегистрированные водители появятся здесь.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                } else {
                    List {
                        Section {
                            HStack(spacing: 24) {
                                AdminMetricView(
                                    title: "Водители",
                                    value: adminService.drivers.count,
                                    color: .blue
                                )
                                AdminMetricView(
                                    title: "Ожидают",
                                    value: pendingCount,
                                    color: .orange
                                )
                            }
                            .padding(.vertical, 8)
                        }

                        Section("Документы водителей") {
                            ForEach(adminService.drivers) { driver in
                                NavigationLink {
                                    AdminDriverDetailView(driverId: driver.id)
                                        .environmentObject(adminService)
                                } label: {
                                    AdminDriverRow(driver: driver)
                                }
                            }
                        }
                    }
                    .refreshable {
                        adminService.startListening()
                    }
                }
            }
            .navigationTitle("Админ-панель")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Выйти", role: .destructive) {
                        authService.logout()
                    }
                }
            }
            .onAppear {
                adminService.startListening()
            }
            .onDisappear {
                adminService.stopListening()
            }
            .alert("Ошибка", isPresented: Binding(
                get: { adminService.errorMessage != nil },
                set: { if !$0 { adminService.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {
                    adminService.errorMessage = nil
                }
            } message: {
                Text(adminService.errorMessage ?? "Неизвестная ошибка")
            }
        }
    }
}

private struct AdminMetricView: View {
    let title: String
    let value: Int
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.title2.bold())
                .foregroundColor(color)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct AdminDriverRow: View {
    let driver: User

    private var pendingCount: Int {
        driver.vehicleInfo?.documents?.allDocuments.filter {
            $0.effectiveVerificationStatus == .pending
        }.count ?? 0
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.crop.circle.badge.checkmark")
                .font(.title2)
                .foregroundColor(.blue)

            VStack(alignment: .leading, spacing: 4) {
                Text(driver.name)
                    .font(.headline)
                Text(driver.email)
                    .font(.caption)
                    .foregroundColor(.secondary)

                if let vehicle = driver.vehicleInfo {
                    Text("\(vehicle.model) · \(vehicle.plateNumber)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if pendingCount > 0 {
                Text("\(pendingCount)")
                    .font(.caption.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange)
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 4)
    }
}

private struct AdminDriverDetailView: View {
    @EnvironmentObject private var adminService: AdminService
    let driverId: String

    @State private var rejectionType: DocumentType?

    private var driver: User? {
        adminService.drivers.first { $0.id == driverId }
    }

    var body: some View {
        ScrollView {
            if let driver {
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(driver.name)
                            .font(.title2.bold())
                        Text(driver.email)
                            .foregroundColor(.secondary)
                        if let phone = driver.phone, !phone.isEmpty {
                            Text(phone)
                                .foregroundColor(.secondary)
                        }
                        if let vehicle = driver.vehicleInfo {
                            Divider()
                            Text("\(vehicle.model) · \(vehicle.plateNumber)")
                                .font(.headline)
                            Text("Грузоподъёмность: \(vehicle.capacity)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)

                    ForEach(DocumentType.allCases) { type in
                        AdminDocumentReviewCard(
                            type: type,
                            document: driver.vehicleInfo?.documents?.document(for: type),
                            isUpdating: adminService.updatingDocumentKey == "\(driver.id)-\(type.fieldName)",
                            onApprove: {
                                Task {
                                    await adminService.reviewDocument(
                                        driverId: driver.id,
                                        documentType: type,
                                        status: .approved
                                    )
                                }
                            },
                            onReject: {
                                rejectionType = type
                            }
                        )
                    }
                }
                .padding()
            } else {
                ProgressView()
                    .padding()
            }
        }
        .navigationTitle("Проверка документов")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $rejectionType) { type in
            RejectionReasonView(documentTitle: type.title) { reason in
                Task {
                    await adminService.reviewDocument(
                        driverId: driverId,
                        documentType: type,
                        status: .rejected,
                        rejectionReason: reason
                    )
                }
            }
        }
    }
}

private struct AdminDocumentReviewCard: View {
    let type: DocumentType
    let document: DocumentInfo?
    let isUpdating: Bool
    let onApprove: () -> Void
    let onReject: () -> Void

    private var status: DocumentVerificationStatus? {
        document?.effectiveVerificationStatus
    }

    private var statusText: String {
        guard let document else { return "Не загружен" }
        if document.isExpired { return "Срок истёк" }
        switch status {
        case .approved: return "Подтверждён"
        case .rejected: return "Отклонён"
        case .pending: return "Ожидает проверки"
        case nil: return "Не загружен"
        }
    }

    private var statusColor: Color {
        guard let document else { return .secondary }
        if document.isExpired { return .red }
        switch status {
        case .approved: return .green
        case .rejected: return .red
        case .pending: return .orange
        case nil: return .secondary
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(type.title)
                        .font(.headline)
                    Text(statusText)
                        .font(.caption)
                        .foregroundColor(statusColor)
                }
                Spacer()
                Image(systemName: status == .approved ? "checkmark.seal.fill" : "doc.text.magnifyingglass")
                    .font(.title2)
                    .foregroundColor(statusColor)
            }

            if let document {
                Divider()
                AdminDocumentField(title: "Номер", value: document.number)
                AdminDocumentField(title: "Действителен до", value: document.expiryDate.formatted(date: .numeric, time: .omitted))

                if let issuedBy = document.issuedBy, !issuedBy.isEmpty {
                    AdminDocumentField(title: "Кем выдан", value: issuedBy)
                }
                if let fullName = document.fullName, !fullName.isEmpty {
                    AdminDocumentField(title: "ФИО", value: fullName)
                }
                if let iin = document.iin, !iin.isEmpty {
                    AdminDocumentField(title: "ИИН", value: iin)
                }
                if let vin = document.vin, !vin.isEmpty {
                    AdminDocumentField(title: "VIN", value: vin)
                }
                if let reason = document.rejectionReason, !reason.isEmpty {
                    Text("Причина: \(reason)")
                        .font(.caption)
                        .foregroundColor(.red)
                }

                HStack(spacing: 12) {
                    Button(action: onReject) {
                        Label("Отклонить", systemImage: "xmark")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)

                    Button(action: onApprove) {
                        if isUpdating {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Label("Подтвердить", systemImage: "checkmark")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                }
                .disabled(isUpdating || document.isExpired)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
    }
}

private struct AdminDocumentField: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(title)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }
}

private struct RejectionReasonView: View {
    @Environment(\.dismiss) private var dismiss
    let documentTitle: String
    let onSubmit: (String) -> Void

    @State private var reason = ""

    var body: some View {
        NavigationView {
            Form {
                Section("Причина отклонения") {
                    TextField("Что необходимо исправить", text: $reason, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle(documentTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Отклонить") {
                        onSubmit(reason.trimmingCharacters(in: .whitespacesAndNewlines))
                        dismiss()
                    }
                    .disabled(reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
