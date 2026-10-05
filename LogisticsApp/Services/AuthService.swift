// AuthService.swift
import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore

class AuthService: ObservableObject {
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    @Published var isLoading = false
    
    private let db = Firestore.firestore()
    private var authStateHandle: AuthStateDidChangeListenerHandle?
    private var userProfileListener: ListenerRegistration?
    
    init() {
        // Бірінші қосылымда автоматты түрде кіруді өшіру
        checkFirstLaunch()
        setupAuthListener()
        checkFirebaseConnection()
    }
    
    deinit {
        if let handle = authStateHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
        userProfileListener?.remove()
    }
    
    // MARK: - Бірінші қосылымды тексеру
    private func checkFirstLaunch() {
        let hasLaunchedBefore = UserDefaults.standard.bool(forKey: "hasLaunchedBefore")
        if !hasLaunchedBefore {
            // Бірінші қосылым - жүйеден шығу
            do {
                try Auth.auth().signOut()
                UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
                print("✅ Бірінші іске қосу: жүйеден шықты")
            } catch {
                print("❌ Бірінші іске қосу кезіндегі қате: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Auth Тыңдаушысы
    private func setupAuthListener() {
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, firebaseUser in
            DispatchQueue.main.async {
                if let firebaseUser = firebaseUser {
                    print("🔄 Auth listener: Пайдаланушы табылды - \(firebaseUser.uid)")
                    self?.fetchUserData(userId: firebaseUser.uid)
                } else {
                    print("🔄 Auth listener: Пайдаланушы жүйеден шықты")
                    self?.userProfileListener?.remove()
                    self?.userProfileListener = nil
                    self?.currentUser = nil
                    self?.isAuthenticated = false
                    self?.isLoading = false
                }
            }
        }
    }
    
    // MARK: - Пайдаланушы Деректерін Алу
    private func fetchUserData(userId: String) {
        isLoading = true
        print("🔄 Firestore-дан пайдаланушы деректерін жүктеу: \(userId)")

        userProfileListener?.remove()
        userProfileListener = db.collection("users").document(userId).addSnapshotListener { [weak self] snapshot, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    print("❌ Firestore-дан пайдаланушыны жүктеу қатесі: \(error.localizedDescription)")
                    return
                }
                
                guard let data = snapshot?.data() else {
                    print("⚠️ Firestore-да пайдаланушы деректері табылмады")
                    return
                }
                
                print("✅ Firestore-дан пайдаланушы деректері алынды: \(data)")
                
                if let user = User.fromDictionary(data) {
                    self?.currentUser = user
                    self?.isAuthenticated = true
                    print("✅ Пайдаланушы currentUser-ге орнатылды: \(user.name)")
                } else {
                    print("❌ Firestore деректерінен User нысанын жасау мүмкін болмады")
                }
            }
        }
    }
    
    // MARK: - Тіркелу (Тіркелуден кейін авторизация бөліміне бағыттау)
    func register(email: String, password: String, name: String, phone: String, userType: UserType, completion: @escaping (Bool, String?) -> Void) {
        // Email тексеру
        if let emailError = validateEmailDetailed(email) {
            completion(false, emailError)
            return
        }
        
        // Құпия сөз тексеру
        guard isValidPassword(password) else {
            completion(false, "Құпия сөз тек сандар мен латын әріптерінен тұруы керек")
            return
        }
        
        // Телефон нөмірін тексеру
        guard isValidPhone(phone) else {
            completion(false, "Телефон нөмірі 11 саннан тұруы керек")
            return
        }
        
        // Есім тексеру
        guard isValidName(name) else {
            completion(false, "Есім тек әріптер, дефис (-), астынғы сызық (_) және бір бос орыннан тұруы керек")
            return
        }
        
        // Құпия сөз ұзындығын тексеру
        guard password.count >= 6 else {
            completion(false, "Құпия сөз кемінде 6 таңбадан тұруы керек")
            return
        }
        
        isLoading = true
        print("🔄 Пайдаланушыны тіркеу басталуда: \(email)")
        
        Auth.auth().createUser(withEmail: email, password: password) { [weak self] authResult, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    print("❌ Auth-те пайдаланушыны жасау қатесі: \(error.localizedDescription)")
                    
                    // Firebase қателерін қазақшаға аудару
                    let localizedError = self?.localizeFirebaseError(error)
                    completion(false, localizedError)
                    return
                }
                
                guard let firebaseUser = authResult?.user else {
                    print("❌ Firebase пайдаланушысын алу мүмкін болмады")
                    completion(false, "Аутентификация сәтсіз аяқталды")
                    return
                }
                
                print("✅ Authentication-да пайдаланушы жасалды: \(firebaseUser.uid)")
                
                // Жүргізушілер үшін vehicleInfo бастапқыда nil
                let vehicleInfo: VehicleInfo? = nil
                
                // Пайдаланушы нысанын жасау
                let user = User(
                    id: firebaseUser.uid,
                    email: email,
                    name: name,
                    userType: userType,
                    phone: phone,
                    vehicleInfo: vehicleInfo
                )
                
                print("🔄 Firestore-да пайдаланушыны сақтау: \(user.id)")
                
                // Firestore-да сақтау
                self?.saveUserToFirestore(user: user) { success, error in
                    if success {
                        print("✅ Тіркелу сәтті аяқталды! Жүйеден шығамыз...")
                        
                        // Тіркелу сәтті аяқталғаннан кейін ЖҮЙЕДЕН ШЫҒУ
                        self?.forceLogoutAfterRegistration()
                        completion(true, nil)
                    } else {
                        completion(false, error)
                    }
                }
            }
        }
    }
    
    // MARK: - Кіру
    func login(email: String, password: String, completion: @escaping (Bool, String?) -> Void) {
        // Email тексеру
        if let emailError = validateEmailDetailed(email) {
            completion(false, emailError)
            return
        }
        
        // Құпия сөз тексеру
        guard isValidPassword(password) else {
            completion(false, "Құпия сөз тек сандар мен латын әріптерінен тұруы керек")
            return
        }
        
        isLoading = true
        print("🔄 Кіру әрекеті: \(email)")
        
        Auth.auth().signIn(withEmail: email, password: password) { [weak self] authResult, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    print("❌ Кіру қатесі: \(error.localizedDescription)")
                    
                    // Firebase қателерін қазақшаға аудару
                    let localizedError = self?.localizeFirebaseError(error)
                    completion(false, localizedError)
                } else {
                    print("✅ Кіру сәтті!")
                    completion(true, nil)
                }
            }
        }
    }
    
    // MARK: - Firestore-да Пайдаланушыны Сақтау
    private func saveUserToFirestore(user: User, completion: @escaping (Bool, String?) -> Void) {
        let userData: [String: Any] = [
            "id": user.id,
            "email": user.email,
            "name": user.name,
            "userType": user.userType.rawValue,
            "phone": user.phone ?? "",
            "createdAt": Timestamp(date: Date()),
            "vehicleInfo": user.vehicleInfo != nil ? [
                "model": user.vehicleInfo!.model,
                "plateNumber": user.vehicleInfo!.plateNumber,
                "capacity": user.vehicleInfo!.capacity
            ] : [:]
        ]
        
        db.collection("users").document(user.id).setData(userData) { error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Firestore-да сақтау қатесі: \(error.localizedDescription)")
                    completion(false, error.localizedDescription)
                } else {
                    print("✅ Пайдаланушы Firestore-да сәтті сақталды!")
                    completion(true, nil)
                }
            }
        }
    }
    
    // MARK: - Тіркелуден кейін міндетті түрде жүйеден шығу
    private func forceLogoutAfterRegistration() {
        do {
            try Auth.auth().signOut()
            self.currentUser = nil
            self.isAuthenticated = false
            print("✅ Тіркелуден кейін пайдаланушы міндетті түрде жүйеден шықты")
        } catch {
            print("❌ Тіркелуден кейін жүйеден шығу кезіндегі қате: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Жүйеден шығу
    func logout() {
        do {
            try Auth.auth().signOut()
            currentUser = nil
            isAuthenticated = false
            print("✅ Пайдаланушы жүйеден шықты")
        } catch {
            print("❌ Жүйеден шығу кезіндегі қате: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Firebase Байланысын Тексеру
    func checkFirebaseConnection() {
        print("🔍 Firebase байланысын тексеру...")
        
        let testDoc = db.collection("test").document("connection")
        testDoc.setData(["test": true, "timestamp": Date()]) { error in
            if let error = error {
                print("❌ Firestore қатесі: \(error.localizedDescription)")
            } else {
                print("✅ Firestore жұмыс істейді - жазу сәтті")
            }
        }
    }
    
    // MARK: - Валидация Әдістері
    
    // Детальная проверка email с возвратом конкретной ошибки
    private func validateEmailDetailed(_ email: String) -> String? {
        // Проверка на пустоту
        if email.isEmpty {
            return "Email енгізіңіз"
        }
        
        // Проверка длины
        if email.count > 100 {
            return "Email тым ұзын"
        }
        
        // Проверка первого символа
        if let firstChar = email.first, firstChar == "." || firstChar == "-" || firstChar == "_" {
            return "Email нүкте, дефис немесе астынғы сызықпен басталмауы керек"
        }
        
        // Проверка наличия @
        guard let atIndex = email.firstIndex(of: "@") else {
            return "Email @ белгісін қамтуы керек"
        }
        
        let localPart = String(email[..<atIndex])
        let domainPart = String(email[atIndex...])
        
        // Проверка local part
        if localPart.isEmpty {
            return "Email @ белгісінен бұрын бөлігі болуы керек"
        }
        
        // Проверка последнего символа local part
        if let lastLocalChar = localPart.last, lastLocalChar == "." || lastLocalChar == "-" || lastLocalChar == "_" {
            return "Email @ белгісінен бұрын нүкте, дефис немесе астынғы сызықпен аяқталмауы керек"
        }
        
        // Проверка количества дефисов в local part
        let dashCount = localPart.filter { $0 == "-" }.count
        if dashCount > 2 {
            return "Email 2 дефисден көп болмауы керек"
        }
        
        // Проверка последовательных специальных символов
        if localPart.contains("--") || localPart.contains("__") || localPart.contains("..") {
            return "Email бірінен соң бір дефис, астынғы сызық немесе нүкте болмауы керек"
        }
        
        // Проверка комбинаций символов
        if localPart.contains(".-") || localPart.contains("-.") ||
           localPart.contains("._") || localPart.contains("_.") ||
           localPart.contains("-_") || localPart.contains("_-") {
            return "Email дефис, астынғы сызық және нүкте бір-бірінің жанында болмауы керек"
        }
        
        // Проверка domain part
        let domainWithoutAt = String(domainPart.dropFirst())
        if domainWithoutAt.isEmpty {
            return "Email домен бөлігі болуы керек"
        }
        
        // Проверка первого символа domain part
        if let firstDomainChar = domainWithoutAt.first, firstDomainChar == "." || firstDomainChar == "-" || firstDomainChar == "_" {
            return "Домен нүкте, дефис немесе астынғы сызықпен басталмауы керек"
        }
        
        // Проверка последнего символа domain part
        if let lastDomainChar = domainWithoutAt.last, lastDomainChar == "." || lastDomainChar == "-" || lastDomainChar == "_" {
            return "Домен нүкте, дефис немесе астынғы сызықпен аяқталмауы керек"
        }
        
        // Проверка наличия точки в domain
        if !domainWithoutAt.contains(".") {
            return "Доменде нүкте болуы керек"
        }
        
        // Проверка на дефис/подчеркивание сразу после @ (f@gmail-.com)
        if domainPart.hasPrefix("@-") || domainPart.hasPrefix("@_") || domainPart.hasPrefix("@.") {
            return "Домен @ белгісінен кейін дефис, астынғы сызық немесе нүктемен басталмауы керек"
        }
        
        // Проверка на дефис/подчеркивание перед точкой в domain
        let domainParts = domainWithoutAt.split(separator: ".")
        for part in domainParts {
            let domainSegment = String(part)
            
            // Проверка первого символа каждого сегмента домена
            if let firstChar = domainSegment.first, firstChar == "-" || firstChar == "_" {
                return "Домен бөліктері дефис немесе астынғы сызықпен басталмауы керек"
            }
            
            // Проверка последнего символа каждого сегмента домена
            if let lastChar = domainSegment.last, lastChar == "-" || lastChar == "_" {
                return "Домен бөліктері дефис немесе астынғы сызықпен аяқталмауы керек"
            }
            
            // Проверка на последовательные дефисы в домене
            if domainSegment.contains("--") || domainSegment.contains("__") {
                return "Доменде бірінен соң бір дефис немесе астынғы сызық болмауы керек"
            }
        }
        
        // Финальная проверка regex
        let emailRegex = "^[A-Z0-9a-z]([A-Z0-9a-z._%+-]*[A-Z0-9a-z])?@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}$"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        
        if !emailPredicate.evaluate(with: email) {
            return "Email дұрыс форматта емес"
        }
        
        return nil
    }
    
    // Валидация пароля (только цифры и латинские буквы)
    private func isValidPassword(_ password: String) -> Bool {
        let passwordRegex = "^[a-zA-Z0-9]*$"
        let passwordPredicate = NSPredicate(format: "SELF MATCHES %@", passwordRegex)
        return passwordPredicate.evaluate(with: password)
    }
    
    // Валидация номера телефона (ровно 11 цифр)
    private func isValidPhone(_ phone: String) -> Bool {
        let cleanedPhone = phone.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        return cleanedPhone.count == 11
    }
    
    // Валидация имени (только буквы, дефис, нижнее подчеркивание и один пробел)
    private func isValidName(_ name: String) -> Bool {
        let nameRegex = "^[\\p{L}]+([-_][\\p{L}]+)?( [\\p{L}]+([-_][\\p{L}]+)?)?$"
        let namePredicate = NSPredicate(format: "SELF MATCHES %@", nameRegex)
        return namePredicate.evaluate(with: name) && name.count >= 2 && name.count <= 50
    }
    
    // MARK: - Firebase қателерін қазақшаға аудару
    // AuthService.swift - түзетілген бөлігі

    // MARK: - Firebase қателерін қазақшаға аудару
    private func localizeFirebaseError(_ error: Error) -> String {
        let nsError = error as NSError
        
        // Firebase Auth қателерін анықтау
        if let errorCode = AuthErrorCode(rawValue: nsError.code) {
            switch errorCode {
            case .emailAlreadyInUse:
                return "Бұл email-мен пайдаланушы тіркелген"
            case .invalidEmail:
                return "Email дұрыс форматта емес"
            case .weakPassword:
                return "Құпия сөз тым әлсіз"
            case .networkError:
                return "Желі қатесі. Интернет байланысын тексеріңіз"
            case .userNotFound:
                return "Пайдаланушы табылмады"
            case .wrongPassword:
                return "Қате құпия сөз"
            case .tooManyRequests:
                return "Тым көп сұрау жіберілді. Кейінірек қайталаңыз"
            case .userDisabled:
                return "Пайдаланушының есебі өшірілген"
            case .operationNotAllowed:
                return "Бұл операция рұқсат етілмеген"
            default:
                return "Аутентификация қатесі: \(error.localizedDescription)"
            }
        }
        
        // Firestore қателері
        if nsError.domain == "FIRFirestoreErrorDomain" {
            switch nsError.code {
            case 7: // .unavailable
                return "Firestore қолжетімсіз. Интернет байланысын тексеріңіз"
            case 3: // .invalidArgument
                return "Деректерді сақтау кезінде қате орын алды"
            default:
                return "Firestore қатесі: \(error.localizedDescription)"
            }
        }
        
        return "Қате орын алды: \(error.localizedDescription)"
    }
}
