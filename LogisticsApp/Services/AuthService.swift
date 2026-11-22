import Foundation
import Combine
import OSLog
import Supabase

@MainActor
class AuthService: ObservableObject {
    @Published var currentUser: AppUser?
    @Published var isAuthenticated = false
    @Published var isLoading = false

    private let client = SupabaseManager.client
    private let logger = Logger(subsystem: "com.meirzhan.LogisticsApp", category: "auth")
    private var authTask: Task<Void, Never>?

    init() {
        setupAuthListener()
    }

    deinit {
        authTask?.cancel()
    }

    // MARK: - Auth Listener

    private func setupAuthListener() {
        isLoading = true
        authTask = Task { [weak self] in
            guard let self else { return }
            for await (_, session) in client.auth.authStateChanges {
                if Task.isCancelled { return }
                if let session {
                    await self.fetchUserData(userId: session.user.id.uuidString.lowercased())
                } else {
                    self.currentUser = nil
                    self.isAuthenticated = false
                    self.isLoading = false
                }
            }
        }
    }

    // MARK: - Fetch User Profile

    func refreshCurrentUser() async {
        guard let userId = currentUser?.id else { return }
        await fetchUserData(userId: userId)
    }

    private func fetchUserData(userId: String) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let profiles: [ProfileRow] = try await client
                .from("profiles")
                .select()
                .eq("id", value: userId)
                .limit(1)
                .execute()
                .value

            guard let profile = profiles.first else {
                logger.warning("Profile row missing for authenticated user")
                return
            }

            var vehicleInfo: VehicleInfo?
            if profile.userType == UserType.driver.rawValue {
                let vehicles: [VehicleRow] = try await client
                    .from("vehicles")
                    .select()
                    .eq("driver_id", value: userId)
                    .limit(1)
                    .execute()
                    .value

                let docRows: [DriverDocumentRow] = try await client
                    .from("driver_documents")
                    .select()
                    .eq("driver_id", value: userId)
                    .execute()
                    .value

                let docs = VehicleDocuments.from(rows: docRows)
                if let vehicle = vehicles.first {
                    vehicleInfo = VehicleInfo(
                        model: vehicle.model,
                        plateNumber: vehicle.plateNumber,
                        capacity: vehicle.capacity,
                        documents: docs
                    )
                }
            }

            if let appUser = profile.toAppUser(vehicleInfo: vehicleInfo) {
                self.currentUser = appUser
                self.isAuthenticated = true
            }
        } catch {
            logger.error("Supabase user fetch error: \(error.localizedDescription, privacy: .public)")
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
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
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

        Task {
            do {
                let authResponse = try await client.auth.signUp(
                    email: normalizedEmail,
                    password: password
                )

                let uid = authResponse.user.id.uuidString.lowercased()
                let profile = ProfileRow(
                    id: uid,
                    email: normalizedEmail,
                    name: normalizedName,
                    userType: userType.rawValue,
                    phone: normalizedPhone,
                    isOnDuty: false,
                    rating: nil
                )

                try await client
                    .from("profiles")
                    .insert(profile)
                    .execute()

                await fetchUserData(userId: uid)
                isLoading = false
                completion(true, nil)
            } catch {
                isLoading = false
                completion(false, localizeSupabaseError(error))
            }
        }
    }

    // MARK: - Login

    func login(email: String, password: String, completion: @escaping (Bool, String?) -> Void) {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if let emailError = AuthValidation.validateEmailDetailed(normalizedEmail) {
            completion(false, emailError)
            return
        }

        guard !password.isEmpty else {
            completion(false, "Құпия сөзді енгізіңіз")
            return
        }

        isLoading = true

        Task {
            do {
                let session = try await client.auth.signIn(
                    email: normalizedEmail,
                    password: password
                )
                await fetchUserData(userId: session.user.id.uuidString.lowercased())
                isLoading = false
                completion(true, nil)
            } catch {
                isLoading = false
                completion(false, localizeSupabaseError(error))
            }
        }
    }

    // MARK: - Password Reset & Profile Management

    func resetPassword(email: String) async throws {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let emailError = AuthValidation.validateEmailDetailed(normalizedEmail) {
            throw NSError(domain: "AuthValidation", code: 400, userInfo: [NSLocalizedDescriptionKey: emailError])
        }
        try await client.auth.resetPasswordForEmail(normalizedEmail)
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

        struct ProfileUpdate: Encodable {
            let name: String
            let phone: String
        }

        try await client
            .from("profiles")
            .update(ProfileUpdate(name: trimmedName, phone: normalizedPhone))
            .eq("id", value: userId)
            .execute()

        await fetchUserData(userId: userId)
    }

    func updateDriverDutyStatus(isOnDuty: Bool) async throws {
        guard let userId = currentUser?.id else { return }
        struct DutyUpdate: Encodable {
            let isOnDuty: Bool
            enum CodingKeys: String, CodingKey {
                case isOnDuty = "is_on_duty"
            }
        }

        try await client
            .from("profiles")
            .update(DutyUpdate(isOnDuty: isOnDuty))
            .eq("id", value: userId)
            .execute()

        await fetchUserData(userId: userId)
    }

    func deleteAccount() async throws {
        try await client.rpc("delete_my_account").execute()
        try? await client.auth.signOut()
        currentUser = nil
        isAuthenticated = false
    }

    // MARK: - Logout

    func logout() {
        Task {
            do {
                try await client.auth.signOut()
            } catch {
                logger.error("Logout error: \(error.localizedDescription, privacy: .public)")
            }
            currentUser = nil
            isAuthenticated = false
        }
    }

    // MARK: - Error Localization

    private func localizeSupabaseError(_ error: Error) -> String {
        let lower = error.localizedDescription.lowercased()
        if lower.contains("already registered") || lower.contains("already exists") {
            return "Бұл email-мен пайдаланушы тіркелген"
        }
        if lower.contains("invalid login credentials") {
            return "Email немесе құпия сөз қате"
        }
        if lower.contains("email not confirmed") {
            return "Email расталмаған. Поштаңызды тексеріңіз"
        }
        if lower.contains("network") || lower.contains("offline") {
            return "Желі қатесі. Интернет байланысын тексеріңіз"
        }
        return "Қате орын алды: \(error.localizedDescription)"
    }
}
