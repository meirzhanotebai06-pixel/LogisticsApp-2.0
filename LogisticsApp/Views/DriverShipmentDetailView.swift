import SwiftUI
import MapKit

struct DriverShipmentDetailView: View {
    let shipment: Shipment
    @Binding var isOnDuty: Bool
    let onStatusUpdate: (Shipment, ShipmentStatus) -> Void
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedTab = 0
    @State private var showCallSheet = false
    @State private var showMessageSheet = false
    @State private var selectedContact: ContactType = .sender
    @State private var showRouteMap = false
    
    enum ContactType {
        case sender, receiver
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Сегментированный контрол
                Picker("", selection: $selectedTab) {
                    Text("Негізгі").tag(0)
                    Text("Контактілер").tag(1)
                    Text("Пакет").tag(2)
                    Text("Төлем").tag(3)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                TabView(selection: $selectedTab) {
                    // Основная информация
                    mainInfoView
                        .tag(0)
                    
                    // Контакты
                    contactsView
                        .tag(1)
                    
                    // Информация о пакете
                    packageInfoView
                        .tag(2)
                    
                    // Платежная информация
                    paymentInfoView
                        .tag(3)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                
                // Действия
                if isOnDuty {
                    actionButtonsView
                }
            }
            .navigationTitle("Тапсырыс ақпараты")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Жабу") {
                presentationMode.wrappedValue.dismiss()
            })
            .sheet(isPresented: $showCallSheet) {
                CallActionSheet(
                    contact: selectedContact == .sender ? shipment.shipmentDetails.sender : shipment.shipmentDetails.receiver,
                    contactType: selectedContact
                )
            }
            .sheet(isPresented: $showMessageSheet) {
                MessageActionSheet(
                    contact: selectedContact == .sender ? shipment.shipmentDetails.sender : shipment.shipmentDetails.receiver,
                    contactType: selectedContact
                )
            }
            .sheet(isPresented: $showRouteMap) {
                RouteMapView(shipment: shipment)
            }
        }
    }
    
    // MARK: - Основная информация
    private var mainInfoView: some View {
        ScrollView {
            VStack(spacing: 16) {
                ShipmentInfoSectionView(title: "Негізгі ақпарат") {
                    ShipmentInfoRowView(title: "Трек-номер:", value: shipment.trackNumber)
                    ShipmentInfoRowView(title: "Маршрут:", value: shipment.route)
                    ShipmentInfoRowView(title: "Статус:", value: shipment.status.rawValue)
                    ShipmentInfoRowView(title: "Қашықтық:", value: "\(calculatedDistance) км")
                    ShipmentInfoRowView(title: "Жіберілген күні:", value: formattedDate(shipment.date))
                    ShipmentInfoRowView(title: "Болжамды жеткізу:", value: formattedDate(shipment.estimatedDelivery ?? shipment.date))
                }
                
                // Кнопка просмотра маршрута
                Button("Маршрутті картада көру") {
                    showRouteMap = true
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                .padding(.horizontal)
            }
            .padding()
        }
    }
    
    // MARK: - Контакты
    private var contactsView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Отправитель
                ContactCardView(
                    contact: shipment.shipmentDetails.sender,
                    type: .sender,
                    onCall: {
                        selectedContact = .sender
                        showCallSheet = true
                    },
                    onMessage: {
                        selectedContact = .sender
                        showMessageSheet = true
                    }
                )
                
                // Получатель
                ContactCardView(
                    contact: shipment.shipmentDetails.receiver,
                    type: .receiver,
                    onCall: {
                        selectedContact = .receiver
                        showCallSheet = true
                    },
                    onMessage: {
                        selectedContact = .receiver
                        showMessageSheet = true
                    }
                )
            }
            .padding()
        }
    }
    
    // MARK: - Информация о пакете
    private var packageInfoView: some View {
        ScrollView {
            VStack(spacing: 16) {
                ShipmentInfoSectionView(title: "Пакет туралы") {
                    ShipmentInfoRowView(title: "Сипаттама:", value: shipment.shipmentDetails.packageInfo.description)
                    ShipmentInfoRowView(title: "Салмағы:", value: "\(shipment.shipmentDetails.packageInfo.weight) кг")
                    ShipmentInfoRowView(title: "Өлшемі:", value: shipment.shipmentDetails.packageInfo.dimensions)
                    ShipmentInfoRowView(title: "Түрі:", value: shipment.shipmentDetails.packageInfo.packageType.rawValue)
                    ShipmentInfoRowView(title: "Бағасы:", value: shipment.shipmentDetails.packageInfo.value != nil ? "\(Int(shipment.shipmentDetails.packageInfo.value!)) ₸" : "Анықталмаған")
                    ShipmentInfoRowView(title: "Сынуыш пакет:", value: shipment.shipmentDetails.packageInfo.fragile ? "Ия" : "Жоқ")
                }
                
                // Дополнительные услуги
                if !shipment.shipmentDetails.additionalServices.isEmpty {
                    ShipmentInfoSectionView(title: "Қосымша қызметтер") {
                        ForEach(shipment.shipmentDetails.additionalServices.indices, id: \.self) { index in
                            let service = shipment.shipmentDetails.additionalServices[index]
                            HStack {
                                Text(service.name)
                                Spacer()
                                Text("\(Int(service.price)) ₸")
                                    .foregroundColor(service.isSelected ? .green : .secondary)
                                Image(systemName: service.isSelected ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(service.isSelected ? .green : .gray)
                            }
                            .font(.subheadline)
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - Платежная информация
    private var paymentInfoView: some View {
        ScrollView {
            VStack(spacing: 16) {
                ShipmentInfoSectionView(title: "Төлем ақпараты") {
                    ShipmentInfoRowView(title: "Сома:", value: "\(Int(shipment.shipmentDetails.payment.amount)) \(shipment.shipmentDetails.payment.currency)")
                    ShipmentInfoRowView(title: "Төлем әдісі:", value: shipment.shipmentDetails.payment.paymentMethod)
                    ShipmentInfoRowView(title: "Төлем статусы:", value: shipment.shipmentDetails.payment.isPaid ? "Төленген" : "Төленбеген")
                }
                
                // Общая стоимость
                let totalAmount = shipment.shipmentDetails.payment.amount + shipment.shipmentDetails.additionalServices.filter { $0.isSelected }.reduce(0) { $0 + $1.price }
                
                ShipmentInfoSectionView(title: "Жалпы сома") {
                    HStack {
                        Text("Барлығы:")
                            .font(.headline)
                        Spacer()
                        Text("\(Int(totalAmount)) ₸")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - Кнопки действий
    private var actionButtonsView: some View {
        VStack(spacing: 12) {
            if shipment.status == .inTransit {
                HStack(spacing: 12) {
                    Button("Кеденге жетті") {
                        onStatusUpdate(shipment, .atCustoms)
                        presentationMode.wrappedValue.dismiss()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    
                    Button("Жеткізілді") {
                        onStatusUpdate(shipment, .delivered)
                        presentationMode.wrappedValue.dismiss()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            } else if shipment.status == .atCustoms {
                Button("Жолға шықты") {
                    onStatusUpdate(shipment, .inTransit)
                    presentationMode.wrappedValue.dismiss()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
        }
        .padding()
    }
    
    private var calculatedDistance: Int {
        if let coords = shipment.routeCoordinates {
            let fromLocation = CLLocation(latitude: coords.from.latitude, longitude: coords.from.longitude)
            let toLocation = CLLocation(latitude: coords.to.latitude, longitude: coords.to.longitude)
            return Int(fromLocation.distance(from: toLocation) / 1000)
        }
        return 0
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMMM yyyy, HH:mm"
        formatter.locale = Locale(identifier: "kk_KZ")
        return formatter.string(from: date)
    }
}

// MARK: - Contact Card View
struct ContactCardView: View {
    let contact: ContactInfo
    let type: DriverShipmentDetailView.ContactType
    let onCall: () -> Void
    let onMessage: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(type == .sender ? "Жіберуші" : "Алушы")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(contact.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                Spacer()
                
                // Действия
                HStack(spacing: 12) {
                    Button(action: onCall) {
                        Image(systemName: "phone.circle.fill")
                            .font(.title2)
                            .foregroundColor(.green)
                    }
                    
                    Button(action: onMessage) {
                        Image(systemName: "message.circle.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 6) {
                ContactInfoRow(icon: "phone", text: contact.phone)
                ContactInfoRow(icon: "mappin.circle", text: contact.address)
                if let email = contact.email {
                    ContactInfoRow(icon: "envelope", text: email)
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .gray.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

struct ContactInfoRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 20)
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
    }
}

// MARK: - Call Action Sheet
struct CallActionSheet: View {
    let contact: ContactInfo
    let contactType: DriverShipmentDetailView.ContactType
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(spacing: 12) {
                    Image(systemName: "phone.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)
                    
                    Text("\(contactType == .sender ? "Жіберушіге" : "Алушыға") қоңырау шаласыз")
                        .font(.headline)
                    
                    Text(contact.name)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(contact.phone)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                .padding()
                
                VStack(spacing: 12) {
                    Button("Қоңырау шалу") {
                        callNumber(phoneNumber: contact.phone)
                        presentationMode.wrappedValue.dismiss()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    
                    Button("WhatsApp арқылы қоңырау") {
                        openWhatsApp(phoneNumber: contact.phone)
                        presentationMode.wrappedValue.dismiss()
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
                .padding()
            }
            .navigationTitle("Қоңырау шалу")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Жабу") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
    
    private func callNumber(phoneNumber: String) {
        let cleanedPhoneNumber = phoneNumber.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "+", with: "")
        if let url = URL(string: "tel://\(cleanedPhoneNumber)") {
            UIApplication.shared.open(url)
        }
    }
    
    private func openWhatsApp(phoneNumber: String) {
        let cleanedPhoneNumber = phoneNumber.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "+", with: "")
        if let url = URL(string: "https://wa.me/\(cleanedPhoneNumber)") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Message Action Sheet
struct MessageActionSheet: View {
    let contact: ContactInfo
    let contactType: DriverShipmentDetailView.ContactType
    @Environment(\.presentationMode) var presentationMode
    @State private var messageText = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(spacing: 12) {
                    Image(systemName: "message.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("\(contactType == .sender ? "Жіберушіге" : "Алушыға") хабарлама жіберу")
                        .font(.headline)
                    
                    Text(contact.name)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                
                VStack(spacing: 12) {
                    TextField("Хабарлама мәтіні...", text: $messageText, axis: .vertical)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(minHeight: 100, alignment: .top)
                    
                    Button("SMS жіберу") {
                        sendSMS(phoneNumber: contact.phone, message: messageText)
                        presentationMode.wrappedValue.dismiss()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .disabled(messageText.isEmpty)
                    
                    Button("WhatsApp арқылы жіберу") {
                        sendWhatsApp(phoneNumber: contact.phone, message: messageText)
                        presentationMode.wrappedValue.dismiss()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(red: 0.18, green: 0.64, blue: 0.34))
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .disabled(messageText.isEmpty)
                    
                    Button("Бас тарту", role: .cancel) {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .foregroundColor(.primary)
                    .cornerRadius(10)
                }
                .padding()
            }
            .navigationTitle("Хабарлама жіберу")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Жабу") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
    
    private func sendSMS(phoneNumber: String, message: String) {
        let cleanedPhoneNumber = phoneNumber.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "+", with: "")
        if let url = URL(string: "sms:\(cleanedPhoneNumber)&body=\(message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") {
            UIApplication.shared.open(url)
        }
    }
    
    private func sendWhatsApp(phoneNumber: String, message: String) {
        let cleanedPhoneNumber = phoneNumber.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "+", with: "")
        let encodedMessage = message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "https://wa.me/\(cleanedPhoneNumber)?text=\(encodedMessage)") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Вспомогательные структуры (переименованные чтобы избежать конфликтов)
struct ShipmentInfoSectionView<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
            
            content
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .gray.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

struct ShipmentInfoRowView: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}
