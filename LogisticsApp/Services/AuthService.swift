import Foundation
import Combine
import OSLog
import FirebaseAuth
import FirebaseFirestore

@MainActor
class AuthService: ObservableObject {
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    @Published var isLoading = false

    private let db = Firestore.firestore()
    private let logger = Logger(subsystem: "com.meirzhan.LogisticsApp", category: "auth")
    private var authStateHandle: AuthStateDidChangeListenerHandle?
    private var userProfileListener: ListenerRegistration?

    init() {
        checkFirstLaunch()
        setupAuthListener()
    }

    deinit {
        if let handle = authStateHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
        userProfileListener?.remove()
    }

    // MARK: - First Launch Check

    private func checkFirstLaunch() {
        let hasLaunchedBefore = UserDefaults.standard.bool(forKey: "hasLaunchedBefore")
        if !hasLaunchedBefore {
            do {
                try Auth.auth().signOut()
                UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
            } catch {
                logger.error("First launch signOut error: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    // MARK: - Auth Listener

    private func setupAuthListener() {
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, firebaseUser in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let firebaseUser {
                    self.fetchUserData(userId: firebaseUser.uid)
                } else {
                    self.userProfileListener?.remove()
                    self.userProfileListener = nil
                    self.currentUser = nil
                    self.isAuthenticated = false
                    self.isLoading = false
                }
            }
        }
    }

    // MARK: - Fetch User Profile

    private func fetchUserData(userId: String) {
        isLoading = true

        userProfileListener?.remove()
        userProfileListener = db.collection("users").document(userId).addSnapshotListener { [weak self] snapshot, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isLoading = false

                if let error {
                    self.logger.error("Firestore user fetch error: \(error.localizedDescription, privacy: .public)")
                    return
                }

                guard let data = snapshot?.data() else {
                    self.logger.warning("Firestore user document missing for uid")
                    return
                }

                if let user = User.fromDictionary(data) {
                    self.currentUser = user
                    self.isAuthenticated = true
                } else {
                    self.logger.error("Failed to decode User model from Firestore")
                }
            }
        }
    }

    // MARK: - Registration

    func register(
        email: String,
        password: String,
        name: String,
        phone: String,
        userType: UserType,
        completion: @escaping (Bool, String?) -> Void
    ) {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        if let emailError = AuthValidation.validateEmailDetailed(normalizedEmail) {
            completion(false, emailError)
            return
        }

        guard AuthValidation.isValidPassword(password) else {
            completion(false, "Құпия сөз кемінде 6 таңбадан тұруы және бос орындармен басталмауы керек")
            return
        }

        guard let normalizedPhone = AuthValidation.normalizePhone(phone) else {
            completion(false, "Телефон нөмірі +7 7XX XXX XX XX форматында 11 саннан тұруы керек")
            return
        }

        guard AuthValidation.isValidName(normalizedName) else {
            completion(false, "Есім тек әріптер, дефис (-), астынғы сызық (_) және бір бос орыннан тұруы керек")
            return
        }

        isLoading = true

        Auth.auth().createUser(withEmail: normalizedEmail, password: password) { [weak self] authResult, error in
            Task { @MainActor [weak self] in
                guard let self else { return }

                if let error {
                    self.isLoading = false
                    completion(false, self.localizeFirebaseError(error))
                    return
                }

                guard let firebaseUser = authResult?.user else {
                    self.isLoading = false
                    completion(false, "Аутентификация сәтсіз аяқталды")
                    return
                }

                let user = User(
                    id: firebaseUser.uid,
                    email: normalizedEmail,
                    name: normalizedName,
                    userType: userType,
                    phone: normalizedPhone,
                    vehicleInfo: nil,
                    isOnDuty: userType == .driver ? false : nil,
                    rating: nil
                )

                self.saveUserToFirestore(user: user) { success, saveError in
                    self.isLoading = false
                    if success {
                        completion(true, nil)
                    } else {
                        // Prevent orphaned Auth accounts if Firestore profile write fails
                        firebaseUser.delete { _ in }
                        completion(false, saveError)
                    }
                }
            }
        }
    }

    // MARK: - Login

    func login(email: String, password: String, completion: @escaping (Bool, String?) -> Void) {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)

        if let emailError = AuthValidation.validateEmailDetailed(normalizedEmail) {
            completion(false, emailError)
            return
        }

        guard !password.isEmpty else {
            completion(false, "Құпия сөзді енгізіңіз")
            return
        }

        isLoading = true

        Auth.auth().signIn(withEmail: normalizedEmail, password: password) { [weak self] _, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isLoading = false

                if let error {
                    completion(false, self.localizeFirebaseError(error))
                } else {
                    completion(true, nil)
                }
            }
        }
    }

    // MARK: - Password Reset & Profile Management

    func resetPassword(email: String) async throws {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        if let emailError = AuthValidation.validateEmailDetailed(normalizedEmail) {
            throw NSError(domain: "AuthValidation", code: 400, userInfo: [NSLocalizedDescriptionKey: emailError])
        }
        try await Auth.auth().sendPasswordReset(withEmail: normalizedEmail)
    }

    func updateProfile(name: String, phone: String) async throws {
        guard let userId = currentUser?.id else { return }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard AuthValidation.isValidName(trimmedName) else {
            throw NSError(
                domain: "AuthValidation",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "Есім тек әріптер, дефис (-), астынғы сызық (_) және бір бос орыннан тұруы керек"]
            )
        }
        guard let normalizedPhone = AuthValidation.normalizePhone(phone) else {
            throw NSError(
                domain: "AuthValidation",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "Телефон нөмірі +7 7XX XXX XX XX форматында болуы керек"]
            )
        }

        try await db.collection("users").document(userId).updateData([
            "name": trimmedName,
            "phone": normalizedPhone
        ])
    }

    func updateDriverDutyStatus(isOnDuty: Bool) async throws {
        guard let userId = currentUser?.id else { return }
        try await db.collection("users").document(userId).updateData([
            "isOnDuty": isOnDuty
        ])
    }

    func deleteAccount() async throws {
        guard let firebaseUser = Auth.auth().currentUser else { return }
        let uid = firebaseUser.uid

        userProfileListener?.remove()
        userProfileListener = nil

        try await db.collection("users").document(uid).delete()
        try await firebaseUser.delete()

        currentUser = nil
        isAuthenticated = false
    }

    // MARK: - Save User To Firestore

    private func saveUserToFirestore(user: User, completion: @escaping (Bool, String?) -> Void) {
        var userData: [String: Any] = [
            "id": user.id,
            "email": user.email,
            "name": user.name,
            "userType": user.userType.rawValue,
            "phone": user.phone ?? "",
            "createdAt": Timestamp(date: Date()),
            "vehicleInfo": NSNull()
        ]
        if let isOnDuty = user.isOnDuty {
            userData["isOnDuty"] = isOnDuty
        }

        db.collection("users").document(user.id).setData(userData) { error in
            Task { @MainActor in
                if let error {
                    completion(false, error.localizedDescription)
                } else {
                    completion(true, nil)
                }
            }
        }
    }

    // MARK: - Logout

    func logout() {
        do {
            try Auth.auth().signOut()
            userProfileListener?.remove()
            userProfileListener = nil
            currentUser = nil
            isAuthenticated = false
        } catch {
            logger.error("Logout error: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Error Localization

    private func localizeFirebaseError(_ error: Error) -> String {
        let nsError = error as NSError

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
            case .wrongPassword, .invalidCredential:
                return "Email немесе құпия сөз қате"
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

        if nsError.domain == "FIRFirestoreErrorDomain" {
            switch nsError.code {
            case 7:
                return "Firestore қолжетімсіз. Интернет байланысын тексеріңіз"
            case 3:
                return "Деректерді сақтау кезінде қате орын алды"
            default:
                return "Firestore қатесі: \(error.localizedDescription)"
            }
        }

        return "Қате орын алды: \(error.localizedDescription)"
    }
}
