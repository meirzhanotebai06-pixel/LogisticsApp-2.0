import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authService: AuthService

    var body: some View {
        Group {
            if authService.isLoading && !authService.isAuthenticated {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.3)
                    Text("Жүктелуде...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemGroupedBackground))
            } else if authService.isAuthenticated, let user = authService.currentUser {
                switch user.userType {
                case .client:
                    ClientMainView()
                case .driver:
                    DriverView()
                case .admin:
                    AdminDashboardView()
                }
            } else {
                LoginView()
            }
        }
        .animation(.default, value: authService.isAuthenticated)
    }
}
