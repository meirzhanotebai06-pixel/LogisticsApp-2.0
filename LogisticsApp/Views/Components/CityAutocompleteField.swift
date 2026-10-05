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
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .focused($isFocused)
                    .onChange(of: text) { newValue in
                        handleTextChange(newValue)
                    }
                    .onChange(of: isFocused) { focused in
                        if !focused {
                            validateCity()
                        }
                    }
                
                // Индикатор валидности
                if !text.isEmpty {
                    Image(systemName: isValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(isValid ? .green : .red)
                        .padding(.trailing, 8)
                }
            }
            
            // Подсказки
            if showSuggestions && !suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(suggestions.prefix(5)) { city in
                        Button(action: {
                            selectCity(city)
                        }) {
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
                        .buttonStyle(PlainButtonStyle())
                        
                        if city.id != suggestions.prefix(5).last?.id {
                            Divider()
                        }
                    }
                }
                .background(Color.white)
                .cornerRadius(8)
                .shadow(color: .gray.opacity(0.2), radius: 4, x: 0, y: 2)
                .transition(.opacity)
            }
            
            // Сообщение об ошибке
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
        // Поиск подсказок
        if newValue.isEmpty {
            suggestions = []
            showSuggestions = false
            isValid = false
        } else {
            suggestions = CitiesDatabase.search(query: newValue)
            showSuggestions = isFocused && !suggestions.isEmpty
            
            // Проверяем валидность
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
            
            // Если город найден, заменяем на казахское название
            if let city = CitiesDatabase.getCity(name: text) {
                text = city.nameKZ
            }
        }
        showSuggestions = false
    }
}

// MARK: - Preview

struct CityAutocompleteField_Previews: PreviewProvider {
    struct PreviewWrapper: View {
        @State private var cityText = ""
        @State private var isValid = false
        @FocusState private var isFocused: Bool
        
        var body: some View {
            VStack {
                CityAutocompleteField(
                    title: "Қайдан",
                    placeholder: "Қала атын енгізіңіз",
                    text: $cityText,
                    isValid: $isValid,
                    isFocused: $isFocused
                )
                .padding()
                
                Text("Текст: \(cityText)")
                Text("Валидно: \(isValid ? "Иә" : "Жоқ")")
                
                Spacer()
            }
        }
    }
    
    static var previews: some View {
        PreviewWrapper()
    }
}
