import SwiftUI

struct NewOrderView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var trackingService: TrackingService
    @EnvironmentObject var authService: AuthService
    @StateObject private var orderService = OrderService()
    
    @State private var fromAddress = ""
    @State private var toAddress = ""
    @State private var packageDescription = ""
    @State private var weight = ""
    @State private var selectedPackageType: PackageType = .medium
    @State private var selectedTariff: TariffType = .standard
    @State private var insurance = false
    @State private var urgentDelivery = false
    @State private var showConfirmation = false
    @State private var newTrackNumber = ""
    @State private var isCreatingOrder = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    // Валидация городов
    @State private var isFromAddressValid = false
    @State private var isToAddressValid = false
    @FocusState private var fromAddressFocused: Bool
    @FocusState private var toAddressFocused: Bool
    
    // Тарифы синхронизированы с экраном тарифов
    let tariffs: [Tariff] = [
        Tariff(
            type: .express,
            name: "Экспресс жеткізу",
            description: "Жедел жеткізу 1-2 күн ішінде",
            price: "2 500 ₸",
            deliveryTime: "1-2 күн",
            features: ["Қауіпсіз орау", "Тегін қайта жіберу", "Телефондық қолдау"]
        ),
        Tariff(
            type: .standard,
            name: "Стандартты жеткізу",
            description: "Қарапайым жеткізу 3-5 күн ішінде",
            price: "1 500 ₸",
            deliveryTime: "3-5 күн",
            features: ["Қауіпсіз орау", "Телефондық қолдау"]
        ),
        Tariff(
            type: .economy,
            name: "Экономикалық жеткізу",
            description: "Үнемді жеткізу 5-7 күн ішінде",
            price: "800 ₸",
            deliveryTime: "5-7 күн",
            features: ["Негізгі орау", "Электрондық қолдау"]
        ),
        Tariff(
            type: .international,
            name: "Халықаралық жеткізу",
            description: "Шетелге жеткізу 7-14 күн ішінде",
            price: "5 000 ₸",
            deliveryTime: "7-14 күн",
            features: ["Кедендік өңдеу", "Сақтандыру", "24/7 қолдау"]
        )
    ]
    
    var body: some View {
        NavigationView {
            Form {
                // Адреса с автодополнением
                Section(header: Text("Жіберу мекенжайы")) {
                    CityAutocompleteField(
                        title: "Қайдан",
                        placeholder: "Қала атын енгізіңіз (қазақша, орысша, ағылшынша)",
                        text: $fromAddress,
                        isValid: $isFromAddressValid,
                        isFocused: $fromAddressFocused
                    )
                    
                    CityAutocompleteField(
                        title: "Қайда",
                        placeholder: "Қала атын енгізіңіз (қазақша, орысша, ағылшынша)",
                        text: $toAddress,
                        isValid: $isToAddressValid,
                        isFocused: $toAddressFocused
                    )
                }
                
                // Информация о посылке
                Section(header: Text("Пакет туралы ақпарат")) {
                    TextField("Сипаттама", text: $packageDescription)
                    TextField("Салмағы (кг)", text: $weight)
                        .keyboardType(.decimalPad)
                    
                    Picker("Пакет түрі", selection: $selectedPackageType) {
                        ForEach(PackageType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                }
                
                // Выбор тарифа
                Section(header: Text("Тарифті таңдау")) {
                    ForEach(tariffs) { tariff in
                        TariffSelectionRow(
                            tariff: tariff,
                            isSelected: selectedTariff == tariff.type,
                            onSelect: {
                                selectedTariff = tariff.type
                            }
                        )
                    }
                }
                
                // Дополнительные услуги
                Section(header: Text("Қосымша қызметтер")) {
                    Toggle("Сақтандыру", isOn: $insurance)
                    Toggle("Жедел жеткізу", isOn: $urgentDelivery)
                }
                
                // Итоговая стоимость
                Section(header: Text("Барлығы")) {
                    HStack {
                        Text("Жалпы бағасы")
                        Spacer()
                        Text(calculateTotalPrice())
                            .font(.headline)
                            .foregroundColor(.blue)
                    }
                    
                    HStack {
                        Text("Болжамды жеткізу уақыты")
                        Spacer()
                        Text(selectedTariff.deliveryTime)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Кнопка создания
                Section {
                    Button {
                        Task {
                            await createNewOrder()
                        }
                    } label: {
                        if isCreatingOrder {
                            HStack {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                Text("Жасалуда...")
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity)
                        } else {
                            Text("Тапсырыс жасау")
                                .foregroundColor(isFormValid ? .white : .gray)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.vertical, 12)
                    .disabled(!isFormValid || isCreatingOrder)
                    .listRowBackground(isFormValid && !isCreatingOrder ? Color.blue : Color.gray.opacity(0.3))
                }
            }
            .navigationTitle("Жаңа тапсырыс")
            .navigationBarItems(
                leading: Button("Бас тарту") {
                    presentationMode.wrappedValue.dismiss()
                }
                .foregroundColor(.blue),
                trailing: Button("Тазарту") {
                    clearForm()
                }
                .foregroundColor(.red)
            )
            .alert("Тапсырыс сәтті жасалды!", isPresented: $showConfirmation) {
                Button("OK") {
                    presentationMode.wrappedValue.dismiss()
                }
            } message: {
                VStack {
                    Text("Трек-номер:")
                    Text(newTrackNumber)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    Text("Тариф: \(selectedTariff.rawValue)")
                        .font(.subheadline)
                }
            }
            .alert("Қате", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    // Проверка валидности формы
    private var isFormValid: Bool {
        isFromAddressValid &&
        isToAddressValid &&
        !packageDescription.isEmpty &&
        !weight.isEmpty &&
        Double(weight) != nil
    }
    
    private func calculateTotalPrice() -> String {
        let basePrice = selectedTariff.basePrice
        var total = basePrice
        
        if insurance {
            total += 500 // Доплата за страховку
        }
        
        if urgentDelivery {
            total += 1000 // Доплата за срочную доставку
        }
        
        // Форматируем цену
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        
        if let formattedPrice = formatter.string(from: NSNumber(value: total)) {
            return "\(formattedPrice) ₸"
        }
        
        return "\(total) ₸"
    }
    
    private func createNewOrder() async {
        guard let weightValue = Double(weight),
              let currentUser = authService.currentUser else { return }
        
        isCreatingOrder = true
        
        do {
            // Создаем заказ в Firebase
            let order = try await orderService.createOrder(
                clientId: currentUser.id,
                clientName: currentUser.name,
                clientPhone: currentUser.phone,
                fromAddress: fromAddress,
                toAddress: toAddress,
                packageDescription: packageDescription,
                weight: weightValue,
                packageType: selectedPackageType,
                tariffType: selectedTariff,
                insurance: insurance,
                urgentDelivery: urgentDelivery
            )
            
            newTrackNumber = order.trackNumber
            isCreatingOrder = false
            showConfirmation = true
            
            // Очистка формы после успешного создания
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                clearForm()
            }
        } catch {
            isCreatingOrder = false
            errorMessage = "Тапсырыс жасау кезінде қате: \(error.localizedDescription)"
            showError = true
        }
    }
    
    private func clearForm() {
        fromAddress = ""
        toAddress = ""
        packageDescription = ""
        weight = ""
        selectedPackageType = .medium
        selectedTariff = .standard
        insurance = false
        urgentDelivery = false
    }
}

// Компонент для выбора тарифа
struct TariffSelectionRow: View {
    let tariff: Tariff
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .top, spacing: 12) {
                // Радио-кнопка
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundColor(isSelected ? .blue : .gray)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(tariff.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text(tariff.price)
                            .font(.headline)
                            .foregroundColor(.blue)
                    }
                    
                    Text(tariff.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(tariff.deliveryTime)
                        .font(.caption)
                        .foregroundColor(.green)
                    
                    // Особенности тарифа
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(tariff.features.prefix(2), id: \.self) { feature in
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.caption2)
                                
                                Text(feature)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .padding(.vertical, 4)
        }
    }
}
