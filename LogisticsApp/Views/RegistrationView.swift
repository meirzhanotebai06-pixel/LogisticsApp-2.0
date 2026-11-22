import SwiftUI

struct RegistrationView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authService: AuthService

    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var name = ""
    @State private var phone = ""
    @State private var selectedUserType: UserType = .client
    @State private var showPassword = false
    @State private var isLoading = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 8) {
                        Text("Тіркелу")
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Text("Жаңа аккаунт жасау")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 20)

                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Аккаунт түрі")
                                .font(.headline)

                            Picker("Аккаунт түрі", selection: $selectedUserType) {
                                Text("Клиент").tag(UserType.client)
                                Text("Жүргізуші").tag(UserType.driver)
                            }
                            .pickerStyle(.segmented)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Аты-жөні")
                                .font(.headline)

                            TextField("Айдар Нұрлан", text: $name)
                                .textFieldStyle(.roundedBorder)
                                .textInputAutocapitalization(.words)
                                .textContentType(.name)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Телефон нөмірі")
                                .font(.headline)

                            TextField("+77001234567", text: $phone)
                                .textFieldStyle(.roundedBorder)
                                .keyboardType(.phonePad)
                                .textContentType(.telephoneNumber)

                            if !phone.isEmpty && !AuthValidation.isValidPhone(phone) {
                                Text("Мысалы: +77001234567 немесе 87001234567")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Электрондық пошта")
                                .font(.headline)

                            TextField("example@domain.com", text: $email)
                                .textFieldStyle(.roundedBorder)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .textContentType(.emailAddress)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Құпия сөз")
                                .font(.headline)

                            HStack {
                                Group {
                                    if showPassword {
                                        TextField("Кемінде 6 таңба", text: $password)
                                    } else {
                                        SecureField("Кемінде 6 таңба", text: $password)
                                    }
                                }
                                .textContentType(.newPassword)

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
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Құпия сөзді растау")
                                .font(.headline)

                            SecureField("Құпия сөзді қайта енгізіңіз", text: $confirmPassword)
                                .textFieldStyle(.roundedBorder)
                                .textContentType(.newPassword)

                            if !confirmPassword.isEmpty && password != confirmPassword {
                                Text("Құпия сөздер сәйкес келмейді")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    .padding(.horizontal)

                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    Button(action: register) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Тіркелу")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isFormValid ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .disabled(!isFormValid || isLoading)

                    Button("Аккаунтыңыз бар ма? Кіру") {
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .foregroundColor(.blue)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Тіркелу")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Бас тарту") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        AuthValidation.isValidPhone(phone) &&
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        AuthValidation.isValidPassword(password) &&
        password == confirmPassword
    }

    private func register() {
        errorMessage = ""
        isLoading = true

        authService.register(
            email: email,
            password: password,
            name: name,
            phone: phone,
            userType: selectedUserType
        ) { success, message in
            isLoading = false
            if success {
                dismiss()
            } else {
                errorMessage = message ?? "Тіркелу кезінде қате орын алды"
            }
        }
    }
}
