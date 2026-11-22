import Foundation
import Supabase

enum SupabaseConfig {
    private static let placeholderURL = "https://YOUR-PROJECT-REF.supabase.co"
    private static let placeholderAnonKey = "YOUR-SUPABASE-ANON-KEY"

    private static let secretsDict: [String: Any]? = {
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist") else {
            return nil
        }
        return NSDictionary(contentsOf: url) as? [String: Any]
    }()

    static var url: URL {
        let raw = (secretsDict?["SUPABASE_URL"] as? String)
            ?? ProcessInfo.processInfo.environment["SUPABASE_URL"]
            ?? (Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String)
            ?? placeholderURL

        var normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        for suffix in ["/rest/v1/", "/rest/v1"] {
            if normalized.hasSuffix(suffix) {
                normalized = String(normalized.dropLast(suffix.count))
                break
            }
        }
        return URL(string: normalized) ?? URL(string: "https://placeholder.supabase.co")!
    }

    static var anonKey: String {
        (secretsDict?["SUPABASE_ANON_KEY"] as? String)
            ?? ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"]
            ?? (Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String)
            ?? placeholderAnonKey
    }
}

enum SupabaseManager {
    static let client = SupabaseClient(
        supabaseURL: SupabaseConfig.url,
        supabaseKey: SupabaseConfig.anonKey
    )
}
