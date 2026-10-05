import SwiftUI
import MapKit

struct RouteMapView: View {
    let shipment: Shipment
    @Environment(\.presentationMode) var presentationMode
    @State private var region: MKCoordinateRegion
    
    init(shipment: Shipment) {
        self.shipment = shipment
        self._region = State(initialValue: MKCoordinateRegion(
            center: shipment.centerCoordinate,
            span: shipment.coordinateSpan
        ))
    }
    
    var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                // Карта с маршрутом
                Map(coordinateRegion: $region, annotationItems: routeAnnotations) { annotation in
                    MapAnnotation(coordinate: annotation.coordinate) {
                        RouteAnnotationView(annotation: annotation)
                    }
                }
                .ignoresSafeArea()
                
                // Маршрут информациясы
                VStack(spacing: 12) {
                    VStack(spacing: 8) {
                        Text("Маршрут ақпараты")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Бастапқы пункт:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(startCity)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Мақсатты пункт:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(endCity)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                        }
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Қашықтық:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(calculatedDistance) км")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Болжамды уақыт:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(shipment.status.rawValue)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(statusColor)
                            }
                        }
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(radius: 5)
                    
                    // Маршрут сызығын көрсету
                    HStack(spacing: 16) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 12, height: 12)
                        
                        Rectangle()
                            .fill(Color.blue)
                            .frame(height: 3)
                        
                        Image(systemName: "shippingbox.fill")
                            .foregroundColor(.blue)
                            .font(.title3)
                        
                        Rectangle()
                            .fill(Color.blue)
                            .frame(height: 3)
                        
                        Circle()
                            .fill(Color.red)
                            .frame(width: 12, height: 12)
                    }
                    .padding(.horizontal, 20)
                }
                .padding()
            }
            .navigationTitle("Маршрут картасы")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Жабу") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
    
    private var routeAnnotations: [RouteAnnotation] {
        var annotations: [RouteAnnotation] = []
        
        if let coords = shipment.routeCoordinates {
            // Бастапқы қала
            annotations.append(RouteAnnotation(
                coordinate: coords.from,
                type: .start,
                title: startCity
            ))
            
            // Мақсатты қала
            annotations.append(RouteAnnotation(
                coordinate: coords.to,
                type: .end,
                title: endCity
            ))
        }
        
        return annotations
    }
    
    private var startCity: String {
        let cities = shipment.route.components(separatedBy: " → ")
        return cities.first ?? ""
    }
    
    private var endCity: String {
        let cities = shipment.route.components(separatedBy: " → ")
        return cities.last ?? ""
    }
    
    private var calculatedDistance: Int {
        if let coords = shipment.routeCoordinates {
            let fromLocation = CLLocation(latitude: coords.from.latitude, longitude: coords.from.longitude)
            let toLocation = CLLocation(latitude: coords.to.latitude, longitude: coords.to.longitude)
            let distance = fromLocation.distance(from: toLocation) / 1000 // км-ге айналдыру
            return Int(distance)
        }
        return 0
    }
    
    private var statusColor: Color {
        switch shipment.status {
        case .accepted: return .blue
        case .inTransit: return .orange
        case .atCustoms: return .yellow
        case .delivered: return .green
        }
    }
}

// Маршрут аннотациясы
struct RouteAnnotation: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let type: AnnotationType
    let title: String
}

enum AnnotationType {
    case start, end
}

// Маршрут аннотациясының көрінісі
struct RouteAnnotationView: View {
    let annotation: RouteAnnotation
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(annotation.type == .start ? Color.green : Color.red)
                    .frame(width: 30, height: 30)
                
                Image(systemName: annotation.type == .start ? "location.fill" : "flag.fill")
                    .foregroundColor(.white)
                    .font(.system(size: 12))
            }
            
            Text(annotation.title)
                .font(.caption2)
                .fontWeight(.medium)
                .padding(4)
                .background(Color.white)
                .cornerRadius(4)
                .shadow(radius: 2)
        }
    }
}
