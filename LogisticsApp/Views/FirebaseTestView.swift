import SwiftUI
import Firebase
import FirebaseAuth

struct FirebaseTestView: View {
    @State private var firebaseStatus = "Проверка..."
    @State private var authStatus = "Проверка..."
    @State private var firestoreStatus = "Проверка..."
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Firebase Status Test")
                .font(.title)
                .padding()
            
            StatusRow(title: "Firebase Config", status: firebaseStatus)
            StatusRow(title: "Authentication", status: authStatus)
            StatusRow(title: "Firestore", status: firestoreStatus)
            
            Button("Test Connection") {
                testFirebaseConnection()
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .onAppear {
            testFirebaseConnection()
        }
    }
    
    private func testFirebaseConnection() {
        // Проверка конфигурации Firebase
        firebaseStatus = FirebaseApp.app() != nil ? "✅ Успешно" : "❌ Ошибка"
        
        // Проверка аутентификации
        authStatus = Auth.auth().app != nil ? "✅ Успешно" : "❌ Ошибка"
        
        // Проверка Firestore
        let db = Firestore.firestore()
        firestoreStatus = "✅ Успешно"
        
        // Тест записи
        let testRef = db.collection("test").document("connection")
        testRef.setData(["test": true, "timestamp": Date()]) { error in
            if let error = error {
                firestoreStatus = "❌ Ошибка: \(error.localizedDescription)"
            } else {
                firestoreStatus = "✅ Запись успешна"
            }
        }
    }
}

struct StatusRow: View {
    let title: String
    let status: String
    
    var body: some View {
        HStack {
            Text(title)
                .fontWeight(.medium)
            Spacer()
            Text(status)
                .foregroundColor(status.contains("✅") ? .green : .red)
        }
        .padding(.horizontal)
    }
}
