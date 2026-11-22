import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authService: AuthService
    @State private var showRegistration = false
    @State private var showForgotPassword = false

    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var successMessage = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    VStack(spacing: 10) {
                        Image(systemName: "shippingbox.circle.fill")
                            .font(.system(size: 64))
                            .foregroundColor(.blue)

                        Text("Кіру")
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Text("Сәлем!")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 40)

                    VStack(spacing: 6) {
                        Text("Тауарды қадағалаңыз, жіберілімдерді құрыңыз")
                        Text("және мерзімдерді тексеріңіз")
                    }
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)

                    VStack(spacing: 16) {
                        TextField("example@domain.com", text: $email)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .textContentType(.emailAddress)

                        HStack {
                            Group {
                                if showPassword {
                                    TextField("Құпия сөз", text: $password)
                                } else {
                                    SecureField("Құпия сөз", text: $password)
                                }
                            }
                            .textContentType(.password)

                            Button {
                                showPassword.toggle()
                            } label: {
                                Image(systemName: showPassword ? "eye.slash" : "eye")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(.separator), lineWidth: 0.5)
                        )

                        HStack {
                            Spacer()
                            Button("Құпия сөзді ұмыттыңыз ба?") {
                                showForgotPassword = true
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal)

                    if !successMessage.isEmpty {
                        Text(successMessage)
                            .foregroundColor(.green)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    Button(action: login) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Кіру")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isLoginFormValid ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .disabled(!isLoginFormValid || isLoading)

                    HStack {
                        VStack { Divider() }
                        Text("немесе")
                            .foregroundColor(.secondary)
                            .font(.caption)
                        VStack { Divider() }
                    }
                    .padding(.horizontal)

                    Button("Тіркелу") {
                        showRegistration = true
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                .padding(.bottom, 30)
            }
            .background(Color(.systemGroupedBackground))
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showRegistration) {
                RegistrationView()
                    .environmentObject(authService)
            }
            .sheet(isPresented: $showForgotPassword) {
                ForgotPasswordView(initialEmail: email) { resetEmail in
                    successMessage = "Құпия сөзді қалпына келтіру сілтемесі \(resetEmail) поштасына жіберілді"
                    errorMessage = ""
                }
                .environmentObject(authService)
            }
        }
    }

    private var isLoginFormValid: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !password.isEmpty
    }

    private func login() {
        errorMessage = ""
        successMessage = ""
        isLoading = true

        authService.login(email: email, password: password) { success, message in
            isLoading = false
            if !success {
                errorMessage = message ?? "Кіру кезінде қате орын алды"
            }
        }
    }
}

private struct ForgotPasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authService: AuthService
    @State var email: String
    let onSuccess: (String) -> Void

    @State private var isSending = false
    @State private var errorMessage = ""

    init(initialEmail: String, onSuccess: @escaping (String) -> Void) {
        _email = State(initialValue: initialEmail)
        self.onSuccess = onSuccess
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(
                    header: Text("Құпия сөзді қалпына келтіру"),
                    footer: Text("Тіркелген email мекенжайыңызға қалпына келтіру сілтемесі жіберіледі.")
                ) {
                    TextField("example@domain.com", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                if !errorMessage.isEmpty {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }

                Section {
                    Button {
                        Task { await sendReset() }
                    } label: {
                        if isSending {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Сілтеме жіберу")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
                }
            }
            .navigationTitle("Құпия сөзді қалпына келтіру")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Жабу") { dismiss() }
                }
            }
        }
    }

    private func sendReset() async {
        errorMessage = ""
        isSending = true
        defer { isSending = false }

        do {
            let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
            try await authService.resetPassword(email: trimmed)
            onSuccess(trimmed)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
