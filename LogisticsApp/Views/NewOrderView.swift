import SwiftUI
import CoreLocation

struct NewOrderView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authService: AuthService
    @StateObject private var orderService = OrderService()

    @State private var fromAddress = ""
    @State private var toAddress = ""
    @State private var packageDescription = ""
    @State private var weight = ""
    @State private var selectedPackageType: PackageType = .medium
    @State private var selectedTariff: TariffType
    @State private var insurance = false
    @State private var urgentDelivery = false
    @State private var showConfirmation = false
    @State private var newTrackNumber = ""
    @State private var isCreatingOrder = false
    @State private var showError = false
    @State private var errorMessage = ""

    @State private var isFromAddressValid = false
    @State private var isToAddressValid = false
    @FocusState private var fromAddressFocused: Bool
    @FocusState private var toAddressFocused: Bool

    private let tariffs = Tariff.catalog

    init(initialTariff: TariffType = .standard) {
        _selectedTariff = State(initialValue: initialTariff)
    }

    var body: some View {
        NavigationStack {
            Form {
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

                    if isSameCity {
                        Label("Жіберу және алу қалалары әртүрлі болуы керек", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundColor(.red)
                    } else if estimatedDistanceKm > 0 {
                        HStack {
                            Text("Қашықтық")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(estimatedDistanceKm) км")
                                .fontWeight(.medium)
                        }
                        .font(.subheadline)
                    }
                }

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

                Section(header: Text("Қосымша қызметтер")) {
                    Toggle("Сақтандыру (+500 ₸)", isOn: $insurance)
                    Toggle("Жедел жеткізу (+1 000 ₸)", isOn: $urgentDelivery)
                }

                Section(header: Text("Барлығы")) {
                    HStack {
                        Text("Жалпы бағасы")
                        Spacer()
                        Text(totalPriceInt.formattedTenge())
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

                Section {
                    Button {
                        Task { await createNewOrder() }
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
                                .foregroundColor(isFormValid ? .white : .secondary)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.vertical, 8)
                    .disabled(!isFormValid || isCreatingOrder)
                    .listRowBackground(isFormValid && !isCreatingOrder ? Color.blue : Color(.systemFill))
                }
            }
            .navigationTitle("Жаңа тапсырыс")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Бас тарту") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Тазарту", role: .destructive) {
                        clearForm()
                    }
                }
            }
            .alert("Тапсырыс сәтті жасалды!", isPresented: $showConfirmation) {
                Button("OK") {
                    clearForm()
                    dismiss()
                }
            } message: {
                Text("Трек-номер: \(newTrackNumber)\nТариф: \(selectedTariff.rawValue)\nБағасы: \(totalPriceInt.formattedTenge())")
            }
            .alert("Қате", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    private var parsedWeight: Double? {
        let normalized = weight.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        guard let value = Double(normalized), value.isFinite, value > 0 else {
            return nil
        }
        return value
    }

    private var isSameCity: Bool {
        let from = fromAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        let to = toAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !from.isEmpty, !to.isEmpty else { return false }
        if let fromCity = CitiesDatabase.getCity(name: from),
           let toCity = CitiesDatabase.getCity(name: to) {
            return fromCity.nameKZ == toCity.nameKZ
        }
        return from.caseInsensitiveCompare(to) == .orderedSame
    }

    private var estimatedDistanceKm: Int {
        guard let from = CitiesDatabase.getCoordinate(cityName: fromAddress),
              let to = CitiesDatabase.getCoordinate(cityName: toAddress) else {
            return 0
        }
        let fromLoc = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let toLoc = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return Int(fromLoc.distance(from: toLoc) / 1000)
    }

    private var isFormValid: Bool {
        isFromAddressValid &&
        isToAddressValid &&
        !isSameCity &&
        !packageDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        parsedWeight != nil
    }

    private var totalPriceInt: Int {
        Tariff.calculatePrice(
            tariff: selectedTariff,
            weight: parsedWeight ?? 1.0,
            distanceKm: estimatedDistanceKm,
            insurance: insurance,
            urgentDelivery: urgentDelivery
        )
    }

    private func createNewOrder() async {
        guard let weightValue = parsedWeight,
              let currentUser = authService.currentUser else { return }

        isCreatingOrder = true

        do {
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
                price: totalPriceInt,
                insurance: insurance,
                urgentDelivery: urgentDelivery
            )

            newTrackNumber = order.trackNumber
            isCreatingOrder = false
            showConfirmation = true
        } catch {
            isCreatingOrder = false
            errorMessage = "Тапсырыс жасау кезінде қате: \(error.localizedDescription)"
            showError = true
        }
    }

    private func clearForm() {
        fromAddress = ""
        toAddress = ""
        isFromAddressValid = false
        isToAddressValid = false
        packageDescription = ""
        weight = ""
        selectedPackageType = .medium
        selectedTariff = .standard
        insurance = false
        urgentDelivery = false
    }
}

struct TariffSelectionRow: View {
    let tariff: Tariff
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .top, spacing: 12) {
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
