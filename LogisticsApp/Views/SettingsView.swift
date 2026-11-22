import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authService: AuthService
    @AppStorage("appTheme") private var appThemeRaw = AppTheme.system.rawValue
    @State private var showLogoutAlert = false

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "2.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Сыртқы түрі") {
                    Picker("Тақырып", selection: $appThemeRaw) {
                        ForEach(AppTheme.allCases) { theme in
                            Text(theme.title).tag(theme.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Қолдау қызметі") {
                    Button {
                        ContactHelper.call(phone: "+77770000000")
                    } label: {
                        Label("Қоңырау шалу (+7 777 000 00 00)", systemImage: "phone.fill")
                    }

                    Button {
                        ContactHelper.openWhatsApp(phone: "+77770000000", message: "Сәлеметсіз бе! LogisticsApp бойынша сұрағым бар.")
                    } label: {
                        Label("WhatsApp арқылы жазу", systemImage: "message.fill")
                            .foregroundColor(.green)
                    }
                }

                Section("Қосымша туралы") {
                    HStack {
                        Text("Нұсқасы")
                        Spacer()
                        Text(appVersion)
                            .foregroundColor(.secondary)
                    }
                }

                Section {
                    Button(role: .destructive) {
                        showLogoutAlert = true
                    } label: {
                        Label("Жүйеден шығу", systemImage: "rectangle.portrait.and.arrow.right")
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle("Баптаулар")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Жабу") { dismiss() }
                }
            }
            .alert("Жүйеден шығу", isPresented: $showLogoutAlert) {
                Button("Бас тарту", role: .cancel) { }
                Button("Шығу", role: .destructive) {
                    dismiss()
                    authService.logout()
                }
            } message: {
                Text("Сіз шынымен жүйеден шығғыңыз келе ме?")
            }
        }
    }
}
