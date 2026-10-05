import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authService: AuthService
    @State private var showRegistration = false
    
    @State private var email = ""
    @State private var password = ""
    @State private var selectedUserType: UserType = .client
    @State private var isLoading = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // Заголовок
                VStack(spacing: 10) {
                    Text("# Login")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Сөлем!")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 50)
                
                // Описание
                VStack(spacing: 8) {
                    Text("Тауарды кадағалаңыз, жіберілімдерді құрыңыз")
                    Text("және мерзімдерді тексеріңіз")
                }
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
                
                // Форма входа
                VStack(spacing: 20) {
                    Picker("Тіркелгі түрі", selection: $selectedUserType) {
                        Text("Клиент").tag(UserType.client)
                        Text("Жүргізуші").tag(UserType.driver)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    TextField("example@domain.com", text: $email)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    
                    SecureField("Құпия сөз", text: $password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                .padding(.horizontal)
                
                // Сообщение об ошибке
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                // Кнопка входа
                Button(action: login) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
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
                .cornerRadius(10)
                .padding(.horizontal)
                .disabled(!isLoginFormValid || isLoading)
                
                // Разделитель
                HStack {
                    VStack { Divider() }
                    Text("немесе")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    VStack { Divider() }
                }
                .padding(.horizontal)
                
                // Кнопка регистрации
                Button("Тіркелу") {
                    showRegistration = true
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(10)
                .padding(.horizontal)
                
                Spacer()
                
                if authService.isAuthenticated {
                    Button("Жүйеден шығу (тест)") {
                        authService.logout()
                    }
                    .foregroundColor(.red)
                    .padding()
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showRegistration) {
                RegistrationView(onRegistrationSuccess: { registeredEmail, registeredPassword in
                    // Автоматически заполняем поля входа после регистрации
                    self.email = registeredEmail
                    self.password = registeredPassword
                    self.errorMessage = "Тіркелу сәтті аяқталды! Енді кіріңіз."
                })
                .environmentObject(authService)
            }
        }
    }
    
    // Проверка валидности формы входа
    private var isLoginFormValid: Bool {
        !email.isEmpty && !password.isEmpty
    }
    
    private func login() {
        errorMessage = ""
        isLoading = true
        
        authService.login(email: email, password: password) { success, message in
            isLoading = false
            
            if !success {
                errorMessage = message ?? "Кіру кезінде қате орын алды"
            }
        }
    }
}
