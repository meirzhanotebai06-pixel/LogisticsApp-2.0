import SwiftUI

struct TariffsView: View {
    @Environment(\.presentationMode) var presentationMode
    
    // Тарифы синхронизированы с экраном создания заказа
    let tariffs = [
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
            ScrollView {
                VStack(spacing: 20) {
                    // Заголовок
                    VStack(spacing: 10) {
                        Text("Тарифтер")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Біздің жеткізу опцияларымызды таңдаңыз")
                            .font(.title3)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)
                    
                    // Тарифы
                    LazyVStack(spacing: 16) {
                        ForEach(tariffs) { tariff in
                            TariffCard(tariff: tariff)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Дополнительная информация
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Қосымша ақпарат")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        InfoRow(icon: "clock", text: "Жеткізу уақыты жұмыс күндерінде есептеледі")
                        InfoRow(icon: "calendar", text: "Демалыс күндері жеткізу жүргізілмейді")
                        InfoRow(icon: "phone", text: "Кез келген уақытта бізбен хабарласыңыз: +7 777 000 0000")
                        InfoRow(icon: "map", text: "Барлық қалаларға жеткізу қол жетімді")
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    Spacer()
                }
            }
            .navigationBarTitle("Тарифтер", displayMode: .inline)
            .navigationBarItems(trailing: Button("Жабу") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

struct TariffCard: View {
    let tariff: Tariff
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Заголовок и цена
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
            
            // Особенности
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
            
            // Кнопка выбора
            Button("Таңдау") {
                // Здесь можно добавить логику выбора тарифа
                print("Тариф таңдалды: \(tariff.name)")
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .gray.opacity(0.2), radius: 3, x: 0, y: 2)
    }
}

struct InfoRow: View {
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
