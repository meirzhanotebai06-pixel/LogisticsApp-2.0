import SwiftUI

// ContentView.swift - исправленная версия

struct ContentView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var trackingService: TrackingService
    @State private var showLogin = true
    
    var body: some View {
        Group {
            if authService.isAuthenticated {
                if let user = authService.currentUser {
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
            } else {
                LoginView()
            }
        }
        .animation(.default, value: authService.isAuthenticated)
        .onAppear {
            // Бірінші рет іске қосылғанда логин экранын көрсету
            if !authService.isAuthenticated {
                showLogin = true
            }
        }
    }
}
