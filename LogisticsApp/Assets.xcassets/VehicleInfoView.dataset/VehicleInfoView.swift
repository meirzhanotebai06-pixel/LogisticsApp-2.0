// VehicleInfoView.swift
import SwiftUI

struct VehicleInfoView: View {
    @EnvironmentObject var authService: AuthService
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Негізгі ақпарат
                InfoCard(title: "Көлік негізгі ақпараты") {
                    if let vehicleInfo = authService.currentUser?.vehicleInfo {
                        InfoRow(title: "Модель", value: vehicleInfo.model)
                        InfoRow(title: "Транспорт нөмірі", value: vehicleInfo.plateNumber)
                        InfoRow(title: "Сыйымдылық", value: vehicleInfo.capacity)
                    } else {
                        Text("Көлік ақпараты қолжетімсіз")
                            .foregroundColor(.gray)
                    }
                }
                
                // Страховка ақпараты
                InfoCard(title: "Страховка") {
                    if let insurance = authService.currentUser?.vehicleInfo?.insurance {
                        InfoRow(title: "Сақтандыру саны", value: insurance.policyNumber)
                        InfoRow(title: "Компания", value: insurance.insuranceCompany)
                        InfoRow(title: "Сомасы", value: insurance.coverageAmount)
                        InfoRow(title: "Мерзімі бітеді", value: formatDate(insurance.expiryDate))
                    } else {
                        Text("Страховка ақпараты қолжетімсіз")
                            .foregroundColor(.gray)
                    }
                }
                
                // Жеке куәлік
                InfoCard(title: "Жүргізуші куәлігі") {
                    if let license = authService.currentUser?.vehicleInfo?.driverLicense {
                        InfoRow(title: "Куәлік нөмірі", value: license.licenseNumber)
                        InfoRow(title: "Берілген күні", value: formatDate(license.issueDate))
                        InfoRow(title: "Мерзімі бітеді", value: formatDate(license.expiryDate))
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Категориялар:")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            ForEach(license.categories, id: \.self) { category in
                                Text("• \(category)")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.top, 8)
                    } else {
                        Text("Куәлік ақпараты қолжетімсіз")
                            .foregroundColor(.gray)
                    }
                }
                
                // Фуралық көлік құжаттары
                InfoCard(title: "Фуралық көлік құжаттары") {
                    if let documents = authService.currentUser?.vehicleInfo?.truckDocuments {
                        InfoRow(title: "Техникалық тексеру", value: formatDate(documents.technicalInspectionExpiry))
                        InfoRow(title: "Экологиялық сертификат", value: documents.environmentalCertificate)
                        InfoRow(title: "Тахограф", value: documents.tachographValid ? "Жарамды" : "Жарамсыз")
                        InfoRow(title: "Жүк страховкасы", value: documents.cargoInsurance)
                        InfoRow(title: "Халықаралық рұқсат", value: documents.internationalPermit ? "Бар" : "Жоқ")
                    } else {
                        Text("Құжат ақпараты қолжетімсіз")
                            .foregroundColor(.gray)
                    }
                }
                
                // Құжаттарды жүктеу батырмасы
                Button(action: {
                    uploadDocuments()
                }) {
                    HStack {
                        Image(systemName: "doc.badge.plus")
                        Text("Құжаттарды жүктеу")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding(.horizontal)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Көлік ақпараты")
    }
    
    private func uploadDocuments() {
        print("Құжаттар жүктелуде...")
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter.string(from: date)
    }
}

// Компонент карточки с информацией
struct InfoCard<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
            
            content
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .gray.opacity(0.2), radius: 5)
    }
}

// Компонент строки информации
struct InfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.primary)
                .font(.headline)
            
            Spacer()
            
            Text(value)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }
}

#Preview {
    VehicleInfoView()
        .environmentObject(AuthService())
}
