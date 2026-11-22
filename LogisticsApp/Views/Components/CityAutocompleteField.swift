import SwiftUI

struct CityAutocompleteField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    @Binding var isValid: Bool
    @FocusState.Binding var isFocused: Bool

    @State private var suggestions: [City] = []
    @State private var showSuggestions = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)

            ZStack(alignment: .trailing) {
                TextField(placeholder, text: $text)
                    .textFieldStyle(.roundedBorder)
                    .focused($isFocused)
                    .onChange(of: text) { _, newValue in
                        handleTextChange(newValue)
                    }
                    .onChange(of: isFocused) { _, focused in
                        if !focused {
                            validateCity()
                        }
                    }

                if !text.isEmpty {
                    Image(systemName: isValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(isValid ? .green : .red)
                        .padding(.trailing, 8)
                }
            }

            if showSuggestions && !suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(suggestions.prefix(5)) { city in
                        Button {
                            selectCity(city)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(city.nameKZ)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)

                                    HStack(spacing: 4) {
                                        Text(city.nameRU)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text("•")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text(city.nameEN)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    Text(city.country)
                                        .font(.caption2)
                                        .foregroundColor(.blue)
                                }

                                Spacer()

                                Image(systemName: "arrow.up.left")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)

                        if city.id != suggestions.prefix(5).last?.id {
                            Divider()
                        }
                    }
                }
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(8)
                .shadow(color: .black.opacity(0.12), radius: 4, x: 0, y: 2)
                .transition(.opacity)
            }

            if !text.isEmpty && !isValid && !isFocused {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                    Text("Қала табылмады. Тізімнен таңдаңыз")
                        .font(.caption)
                }
                .foregroundColor(.red)
            }
        }
    }

    private func handleTextChange(_ newValue: String) {
        if newValue.isEmpty {
            suggestions = []
            showSuggestions = false
            isValid = false
        } else {
            suggestions = CitiesDatabase.search(query: newValue)
            showSuggestions = isFocused && !suggestions.isEmpty
            isValid = CitiesDatabase.isValid(cityName: newValue)
        }
    }

    private func selectCity(_ city: City) {
        text = city.nameKZ
        isValid = true
        showSuggestions = false
        isFocused = false
    }

    private func validateCity() {
        if !text.isEmpty {
            isValid = CitiesDatabase.isValid(cityName: text)
            if let city = CitiesDatabase.getCity(name: text) {
                text = city.nameKZ
            }
        }
        showSuggestions = false
    }
}
