import SwiftUI

struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authService: AuthService

    @State private var name = ""
    @State private var phone = ""
    @State private var isSaving = false
    @State private var isDeleting = false
    @State private var showDeleteAlert = false
    @State private var showSuccessAlert = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                if let user = authService.currentUser {
                    Section("Аккаунт") {
                        HStack {
                            Text("Рөл")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(user.userType.displayTitle)
                                .fontWeight(.medium)
                        }

                        HStack {
                            Text("Email")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(user.email)
                                .foregroundColor(.secondary)
                        }
                    }

                    Section("Жеке деректер") {
                        TextField("Аты-жөні", text: $name)
                            .textInputAutocapitalization(.words)
                        TextField("Телефон нөмірі", text: $phone)
                            .keyboardType(.phonePad)
                    }

                    Section {
                        Button {
                            Task { await saveProfile() }
                        } label: {
                            if isSaving {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                            } else {
                                Text("Сақтау")
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .disabled(isSaving || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }

                    Section(
                        footer: Text("Аккаунтты жойғаннан кейін барлық профиль деректері қайтарымсыз өшіріледі.")
                    ) {
                        Button(role: .destructive) {
                            showDeleteAlert = true
                        } label: {
                            if isDeleting {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                            } else {
                                Label("Аккаунтты жою", systemImage: "trash")
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .disabled(isDeleting)
                    }
                }
            }
            .navigationTitle("Жеке кабинет")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Жабу") { dismiss() }
                }
            }
            .onAppear {
                if let user = authService.currentUser {
                    name = user.name
                    phone = user.phone ?? ""
                }
            }
            .alert("Сәтті сақталды", isPresented: $showSuccessAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Профиль деректері жаңартылды.")
            }
            .alert("Аккаунтты жою", isPresented: $showDeleteAlert) {
                Button("Бас тарту", role: .cancel) { }
                Button("Жою", role: .destructive) {
                    Task { await deleteAccount() }
                }
            } message: {
                Text("Сіз шынымен аккаунтыңызды толық жойғыңыз келе ме?")
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

    private func saveProfile() async {
        isSaving = true
        defer { isSaving = false }

        do {
            try await authService.updateProfile(name: name, phone: phone)
            showSuccessAlert = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteAccount() async {
        isDeleting = true
        defer { isDeleting = false }

        do {
            try await authService.deleteAccount()
            dismiss()
        } catch {
            errorMessage = "Аккаунтты жою сәтсіз: \(error.localizedDescription)"
        }
    }
}
