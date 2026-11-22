import SwiftUI

struct TariffsView: View {
    @Environment(\.dismiss) private var dismiss
    var onSelectTariff: ((TariffType) -> Void)?

    private let tariffs = Tariff.catalog

    init(onSelectTariff: ((TariffType) -> Void)? = nil) {
        self.onSelectTariff = onSelectTariff
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 8) {
                        Text("Тарифтер")
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Text("Біздің жеткізу опцияларымызды таңдаңыз")
                            .font(.title3)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 16)

                    LazyVStack(spacing: 16) {
                        ForEach(tariffs) { tariff in
                            TariffCard(tariff: tariff) {
                                onSelectTariff?(tariff.type)
                                dismiss()
                            }
                        }
                    }
                    .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Қосымша ақпарат")
                            .font(.headline)
                            .fontWeight(.semibold)

                        TariffInfoRow(icon: "clock", text: "Жеткізу уақыты жұмыс күндерінде есептеледі")
                        TariffInfoRow(icon: "calendar", text: "Демалыс күндері жеткізу жүргізілмейді")
                        TariffInfoRow(icon: "phone", text: "Кез келген уақытта бізбен хабарласыңыз: +7 777 000 0000")
                        TariffInfoRow(icon: "map", text: "Барлық қалаларға жеткізу қолжетімді")
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Тарифтер")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Жабу") { dismiss() }
                }
            }
        }
    }
}

struct TariffCard: View {
    let tariff: Tariff
    let onSelect: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(tariff.name)
                        .font(.headline)
                        .fontWeight(.bold)

                    Text(tariff.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(tariff.price)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)

                    Text(tariff.deliveryTime)
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                ForEach(tariff.features, id: \.self) { feature in
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)

                        Text(feature)
                            .font(.caption)
                            .foregroundColor(.primary)

                        Spacer()
                    }
                }
            }

            Button("Таңдау", action: onSelect)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.06), radius: 3, x: 0, y: 2)
    }
}

struct TariffInfoRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)

            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()
        }
    }
}
