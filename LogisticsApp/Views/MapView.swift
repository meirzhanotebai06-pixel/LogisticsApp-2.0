import SwiftUI
import MapKit

struct MapView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 51.1694, longitude: 71.4491), // Астана
        span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
    )
    
    let offices = [
        OfficeLocation(
            name: "Астана бөлімшесі",
            address: "Ә.Қашаубаев көшесі, 12",
            phone: "+7 7172 123 456",
            hours: "09:00 - 18:00",
            coordinate: CLLocationCoordinate2D(latitude: 51.1694, longitude: 71.4491)
        ),
        OfficeLocation(
            name: "Алматы бөлімшесі",
            address: "Әбілқайыр хан даңғылы, 45",
            phone: "+7 727 234 5678",
            hours: "09:00 - 19:00",
            coordinate: CLLocationCoordinate2D(latitude: 43.2380, longitude: 76.8829)
        ),
        OfficeLocation(
            name: "Шымкент бөлімшесі",
            address: "Тәуелсіздік көшесі, 78",
            phone: "+7 7252 345 678",
            hours: "08:00 - 17:00",
            coordinate: CLLocationCoordinate2D(latitude: 42.3417, longitude: 69.5901)
        ),
        OfficeLocation(
            name: "Қарағанды бөлімшесі",
            address: "Бұқар жырау көшесі, 32",
            phone: "+7 7212 456 789",
            hours: "09:00 - 18:00",
            coordinate: CLLocationCoordinate2D(latitude: 49.7989, longitude: 73.0874)
        ),
        OfficeLocation(
            name: "Ақтау бөлімшесі",
            address: "Мәңгілік Ел даңғылы, 15",
            phone: "+7 7292 567 890",
            hours: "09:00 - 18:00",
            coordinate: CLLocationCoordinate2D(latitude: 43.6500, longitude: 51.1500)
        )
    ]
    
    var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                // Карта
                Map(coordinateRegion: $region, annotationItems: offices) { office in
                    MapAnnotation(coordinate: office.coordinate) {
                        OfficeAnnotation(office: office)
                    }
                }
                .ignoresSafeArea()
                
                // Список офисов
                VStack(spacing: 0) {
                    // Заголовок
                    HStack {
                        Text("Біздің бөлімшелер")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        Text("\(offices.count) бөлімше")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.white)
                    
                    // Список
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(offices) { office in
                                OfficeCard(office: office) {
                                    // Центрируем карту на выбранном офисе
                                    withAnimation {
                                        region.center = office.coordinate
                                        region.span = MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .frame(height: 120)
                    .background(Color.white)
                }
                .background(Color.white)
                .cornerRadius(12)
                .shadow(color: .gray.opacity(0.3), radius: 5, x: 0, y: -2)
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .navigationBarTitle("Карта", displayMode: .inline)
            .navigationBarItems(trailing: Button("Жабу") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

struct OfficeLocation: Identifiable {
    let id = UUID()
    let name: String
    let address: String
    let phone: String
    let hours: String
    let coordinate: CLLocationCoordinate2D
}

struct OfficeAnnotation: View {
    let office: OfficeLocation
    
    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: "mappin.circle.fill")
                .font(.title2)
                .foregroundColor(.red)
            
            Text(office.name)
                .font(.caption2)
                .fontWeight(.medium)
                .padding(4)
                .background(Color.white)
                .cornerRadius(4)
                .shadow(radius: 2)
        }
    }
}

struct OfficeCard: View {
    let office: OfficeLocation
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 6) {
                Text(office.name)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(office.address)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                
                Text(office.phone)
                    .font(.caption)
                    .foregroundColor(.blue)
                
                Text(office.hours)
                    .font(.caption2)
                    .foregroundColor(.green)
            }
            .padding()
            .frame(width: 200, alignment: .leading)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
    }
}
