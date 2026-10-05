import SwiftUI

struct RegistrationView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var authService: AuthService
    
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var name = ""
    @State private var phone = ""
    @State private var selectedUserType: UserType = .client
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showSuccessAlert = false
    
    var onRegistrationSuccess: ((String, String) -> Void)?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Заголовок
                    VStack(spacing: 10) {
                        Text("Тіркелу")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Жаңа аккаунт жасау")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 20)
                    
                    // Форма регистрации
                    VStack(spacing: 16) {
                        // Тип аккаунта
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Аккаунт түрі")
                                .font(.headline)
                            
                            Picker("Аккаунт түрі", selection: $selectedUserType) {
                                Text("Клиент").tag(UserType.client)
                                Text("Жүргізуші").tag(UserType.driver)
                            }
                            .pickerStyle(SegmentedPickerStyle())
                        }
                        
                        // Имя
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Аты-жөні")
                                .font(.headline)
                            
                            TextField("Қасым-Жомарт Тоқаев", text: $name)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .autocapitalization(.words)
                        }
                        
                        // Телефон
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Телефон нөмірі")
                                .font(.headline)
                            
                            TextField("77001234567", text: $phone)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.numberPad)
                        }
                        
                        // Email
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Электрондық пошта")
                                .font(.headline)
                            
                            TextField("example@domain.com", text: $email)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                        }
                        
                        // Пароль
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Құпия сөз")
                                .font(.headline)
                            
                            SecureField("Құпия сөз енгізіңіз", text: $password)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        
                        // Подтверждение пароля
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Құпия сөзді растау")
                                .font(.headline)
                            
                            SecureField("Құпия сөзді қайта енгізіңіз", text: $confirmPassword)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                    }
                    .padding(.horizontal)
                    
                    // Валидационные сообщения
                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    // Кнопка регистрации
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
                    .cornerRadius(10)
                    .padding(.horizontal)
                    .disabled(!isFormValid || isLoading)
                    
                    // Ссылка на вход
                    Button("Аккаунтыңыз бар ма? Кіру") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .foregroundColor(.blue)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
            }
            .navigationBarTitle("Тіркелу", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Бас тарту") {
                    presentationMode.wrappedValue.dismiss()
                }
                .foregroundColor(.blue)
            )
            .alert("Тіркелу сәтті аяқталды!", isPresented: $showSuccessAlert) {
                Button("OK", role: .cancel) {
                    // Передаем данные на страницу входа и закрываем форму
                    onRegistrationSuccess?(email, password)
                    presentationMode.wrappedValue.dismiss()
                }
            } message: {
                Text("Енді жаңа деректеріңізбен кіріңіз")
            }
        }
    }
    
    // Проверка валидности формы
    private var isFormValid: Bool {
        !name.isEmpty &&
        !phone.isEmpty &&
        phone.count == 11 &&
        !email.isEmpty &&
        !password.isEmpty &&
        !confirmPassword.isEmpty &&
        password == confirmPassword &&
        password.count >= 6
    }
    
    // RegistrationView.swift - өзгерістер

    private func register() {
        errorMessage = ""
        isLoading = true
        
        // Телефонды халықаралық форматқа түрлендіру
        let formattedPhone = "+7\(phone.dropFirst(1))"
        
        authService.register(
            email: email,
            password: password,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            phone: formattedPhone,
            userType: selectedUserType
        ) { success, message in
            isLoading = false
            
            if success {
                showSuccessAlert = true
            } else {
                errorMessage = message ?? "Тіркелу кезінде қате орын алды"
            }
        }
    }
    
    private func clearForm() {
        email = ""
        password = ""
        confirmPassword = ""
        name = ""
        phone = ""
        selectedUserType = .client
        errorMessage = ""
    }
}
