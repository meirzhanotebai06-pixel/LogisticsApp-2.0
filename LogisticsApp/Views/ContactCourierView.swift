// ContactCourierView.swift
import SwiftUI
import MessageUI

struct ContactCourierView: View {
    let shipment: Shipment
    @Environment(\.presentationMode) var presentationMode
    @State private var showCallSheet = false
    @State private var showMessageSheet = false
    @State private var messageText = ""
    
    // Тестовые данные курьера (реализацияда бұл деректер серверден келуі керек)
    private var courierInfo: CourierInfo {
        CourierInfo(
            name: "Аслан Курьеров",
            phone: "+77771234567",
            vehicle: "Hyundai Sonata",
            plateNumber: "01A123AA"
        )
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Информация о курьере
                    VStack(spacing: 16) {
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.blue)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(courierInfo.name)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                
                                Text("Курьер")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        
                        Divider()
                        
                        VStack(spacing: 12) {
                            CourierContactInfoRow(icon: "phone.fill", text: courierInfo.phone)
                            CourierContactInfoRow(icon: "car.fill", text: "\(courierInfo.vehicle) (\(courierInfo.plateNumber))")
                            CourierContactInfoRow(icon: "shippingbox.fill", text: shipment.trackNumber)
                            CourierContactInfoRow(icon: "map.fill", text: shipment.route)
                        }
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(color: .gray.opacity(0.2), radius: 3, x: 0, y: 2)
                    
                    // Способы связи
                    VStack(spacing: 12) {
                        Text("Байланыс тәсілдері")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        ContactMethodButton(
                            title: "Қоңырау шалу",
                            subtitle: "Тікелей қоңырау",
                            icon: "phone.fill",
                            color: .green
                        ) {
                            showCallSheet = true
                        }
                        
                        ContactMethodButton(
                            title: "WhatsApp",
                            subtitle: "Хабарлама жіберу",
                            icon: "message.fill",
                            color: Color(red: 0.18, green: 0.64, blue: 0.34)
                        ) {
                            openWhatsApp()
                        }
                        
                        ContactMethodButton(
                            title: "SMS",
                            subtitle: "Мәтіндік хабарлама",
                            icon: "text.bubble.fill",
                            color: .blue
                        ) {
                            showMessageSheet = true
                        }
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(color: .gray.opacity(0.2), radius: 3, x: 0, y: 2)
                    
                    // Важная информация
                    VStack(spacing: 12) {
                        Text("Маңызды ақпарат")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        InfoTipView(
                            icon: "clock.fill",
                            text: "Курьерге 09:00-18:00 аралығында хабарласыңыз"
                        )
                        
                        InfoTipView(
                            icon: "info.circle.fill",
                            text: "Жіберілім туралы ақпаратты дайындаңыз"
                        )
                        
                        InfoTipView(
                            icon: "location.fill",
                            text: "Дәл мекенжайыңызды айтыңыз"
                        )
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(12)
                }
                .padding()
            }
            .navigationTitle("Курьерге хабарласу")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Жабу") {
                presentationMode.wrappedValue.dismiss()
            })
            .actionSheet(isPresented: $showCallSheet) {
                ActionSheet(
                    title: Text("Қоңырау шалу"),
                    message: Text("\(courierInfo.name) курьерге қоңырау шаласыз"),
                    buttons: [
                        .default(Text("Қоңырау шалу")) {
                            callCourier()
                        },
                        .default(Text("WhatsApp арқылы")) {
                            openWhatsAppCall()
                        },
                        .cancel(Text("Бас тарту"))
                    ]
                )
            }
            .sheet(isPresented: $showMessageSheet) {
                MessageComposerView(
                    courierInfo: courierInfo,
                    shipment: shipment,
                    onSend: {
                        presentationMode.wrappedValue.dismiss()
                    }
                )
            }
        }
    }
    
    private func callCourier() {
        let cleanPhone = courierInfo.phone.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "+", with: "")
        if let url = URL(string: "tel://\(cleanPhone)") {
            UIApplication.shared.open(url)
        }
    }
    
    private func openWhatsApp() {
        let cleanPhone = courierInfo.phone.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "+", with: "")
        let message = "Сәлеметсіз бе! Менің жіберілімім туралы: \(shipment.trackNumber)"
        let encodedMessage = message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        if let url = URL(string: "https://wa.me/\(cleanPhone)?text=\(encodedMessage)") {
            UIApplication.shared.open(url)
        }
    }
    
    private func openWhatsAppCall() {
        let cleanPhone = courierInfo.phone.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "+", with: "")
        if let url = URL(string: "https://wa.me/\(cleanPhone)") {
            UIApplication.shared.open(url)
        }
    }
}

// Модель курьера
struct CourierInfo {
    let name: String
    let phone: String
    let vehicle: String
    let plateNumber: String
}

// Компонент строки контактной информации (переименован чтобы избежать конфликта)
struct CourierContactInfoRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            Text(text)
                .font(.subheadline)
            
            Spacer()
        }
    }
}

// Компонент кнопки способа связи
struct ContactMethodButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 15) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(color)
                    .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// Компонент информационной подсказки
struct InfoTipView: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.orange)
                .frame(width: 20)
            
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
}

// Экран отправки сообщения
struct MessageComposerView: View {
    let courierInfo: CourierInfo
    let shipment: Shipment
    let onSend: () -> Void
    @Environment(\.presentationMode) var presentationMode
    @State private var messageText = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(spacing: 12) {
                    Image(systemName: "text.bubble.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Курьерге хабарлама")
                        .font(.headline)
                    
                    Text(courierInfo.name)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Хабарлама мәтіні")
                        .font(.headline)
                    
                    TextEditor(text: $messageText)
                        .frame(height: 120)
                        .padding(8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                }
                .padding(.horizontal)
                
                VStack(spacing: 12) {
                    Button("SMS жіберу") {
                        sendSMS()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    
                    Button("WhatsApp арқылы жіберу") {
                        sendWhatsApp()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(red: 0.18, green: 0.64, blue: 0.34))
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    
                    Button("Бас тарту", role: .cancel) {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .foregroundColor(.primary)
                    .cornerRadius(10)
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle("Хабарлама жіберу")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Жабу") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
    
    private func sendSMS() {
        let cleanPhone = courierInfo.phone.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "+", with: "")
        let finalMessage = messageText.isEmpty ?
            "Сәлеметсіз бе! Менің жіберілімім туралы: \(shipment.trackNumber)" :
            messageText
        
        if let url = URL(string: "sms:\(cleanPhone)&body=\(finalMessage.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") {
            UIApplication.shared.open(url)
            onSend()
        }
    }
    
    private func sendWhatsApp() {
        let cleanPhone = courierInfo.phone.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "+", with: "")
        let finalMessage = messageText.isEmpty ?
            "Сәлеметсіз бе! Менің жіберілімім туралы: \(shipment.trackNumber)" :
            messageText
        
        let encodedMessage = finalMessage.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        if let url = URL(string: "https://wa.me/\(cleanPhone)?text=\(encodedMessage)") {
            UIApplication.shared.open(url)
            onSend()
        }
    }
}
