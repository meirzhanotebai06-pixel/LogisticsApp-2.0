import Foundation
import Supabase

enum SupabaseConfig {
    // Замените на ваши значения из Supabase Dashboard → Project Settings → API
    private static let defaultURL = "https://YOUR-PROJECT-REF.supabase.co"
    private static let defaultAnonKey = "YOUR-SUPABASE-ANON-KEY"

    static var url: URL {
        let raw = ProcessInfo.processInfo.environment["SUPABASE_URL"]
            ?? (Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String)
            ?? defaultURL
        return URL(string: raw) ?? URL(string: "https://placeholder.supabase.co")!
    }

    static var anonKey: String {
        ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"]
            ?? (Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String)
            ?? defaultAnonKey
    }
}

enum SupabaseManager {
    static let client = SupabaseClient(
        supabaseURL: SupabaseConfig.url,
        supabaseKey: SupabaseConfig.anonKey
    )
}
