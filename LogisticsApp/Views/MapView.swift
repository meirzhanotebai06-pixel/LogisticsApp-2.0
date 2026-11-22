import SwiftUI
import MapKit

struct MapView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 48.0, longitude: 67.0),
            span: MKCoordinateSpan(latitudeDelta: 15.0, longitudeDelta: 25.0)
        )
    )

    private let offices = [
        OfficeLocation(
            id: "astana",
            name: "Астана бөлімшесі",
            address: "Ә.Қашаубаев көшесі, 12",
            phone: "+7 7172 123 456",
            hours: "09:00 - 18:00",
            coordinate: CLLocationCoordinate2D(latitude: 51.1694, longitude: 71.4491)
        ),
        OfficeLocation(
            id: "almaty",
            name: "Алматы бөлімшесі",
            address: "Әбілқайыр хан даңғылы, 45",
            phone: "+7 727 234 5678",
            hours: "09:00 - 19:00",
            coordinate: CLLocationCoordinate2D(latitude: 43.2380, longitude: 76.8829)
        ),
        OfficeLocation(
            id: "shymkent",
            name: "Шымкент бөлімшесі",
            address: "Тәуелсіздік көшесі, 78",
            phone: "+7 7252 345 678",
            hours: "08:00 - 17:00",
            coordinate: CLLocationCoordinate2D(latitude: 42.3417, longitude: 69.5901)
        ),
        OfficeLocation(
            id: "karaganda",
            name: "Қарағанды бөлімшесі",
            address: "Бұқар жырау көшесі, 32",
            phone: "+7 7212 456 789",
            hours: "09:00 - 18:00",
            coordinate: CLLocationCoordinate2D(latitude: 49.7989, longitude: 73.0874)
        ),
        OfficeLocation(
            id: "aktau",
            name: "Ақтау бөлімшесі",
            address: "Мәңгілік Ел даңғылы, 15",
            phone: "+7 7292 567 890",
            hours: "09:00 - 18:00",
            coordinate: CLLocationCoordinate2D(latitude: 43.6500, longitude: 51.1500)
        )
    ]

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Map(position: $cameraPosition) {
                    ForEach(offices) { office in
                        Annotation(office.name, coordinate: office.coordinate) {
                            OfficeAnnotation(office: office)
                        }
                    }
                }
                .ignoresSafeArea()

                VStack(spacing: 0) {
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

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(offices) { office in
                                OfficeCard(office: office) {
                                    withAnimation {
                                        cameraPosition = .region(
                                            MKCoordinateRegion(
                                                center: office.coordinate,
                                                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                                            )
                                        )
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 12)
                    }
                }
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: -2)
                .padding(.horizontal)
                .padding(.bottom, 16)
            }
            .navigationTitle("Бөлімшелер картасы")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Жабу") { dismiss() }
                }
            }
        }
    }
}

struct OfficeLocation: Identifiable {
    let id: String
    let name: String
    let address: String
    let phone: String
    let hours: String
    let coordinate: CLLocationCoordinate2D
}

struct OfficeAnnotation: View {
    let office: OfficeLocation

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: "mappin.circle.fill")
                .font(.title2)
                .foregroundColor(.red)

            Text(office.name)
                .font(.caption2)
                .fontWeight(.medium)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color(.systemBackground))
                .cornerRadius(4)
                .shadow(radius: 2)
        }
    }
}

struct OfficeCard: View {
    let office: OfficeLocation
    let onSelect: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
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

                    Text(office.hours)
                        .font(.caption2)
                        .foregroundColor(.green)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            Button {
                ContactHelper.call(phone: office.phone)
            } label: {
                Label(office.phone, systemImage: "phone.fill")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .frame(width: 210, alignment: .leading)
        .background(Color(.tertiarySystemGroupedBackground))
        .cornerRadius(10)
    }
}
