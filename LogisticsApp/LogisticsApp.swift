import SwiftUI
import FirebaseCore
import FirebaseFirestore

enum AppTheme: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "Жүйелік"
        case .light: return "Жарық"
        case .dark: return "Қараңғы"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

@main
struct LogisticsApp: App {
    @StateObject private var authService: AuthService
    @AppStorage("appTheme") private var appThemeRaw = AppTheme.system.rawValue

    init() {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        let db = Firestore.firestore()
        let settings = db.settings
        settings.cacheSettings = PersistentCacheSettings()
        db.settings = settings

        _authService = StateObject(wrappedValue: AuthService())
    }

    private var selectedTheme: AppTheme {
        AppTheme(rawValue: appThemeRaw) ?? .system
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authService)
                .preferredColorScheme(selectedTheme.colorScheme)
        }
    }
}
