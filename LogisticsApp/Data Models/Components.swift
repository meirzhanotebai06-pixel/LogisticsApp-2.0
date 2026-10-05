

import SwiftUI

struct ActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    init(title: String, icon: String, action: @escaping () -> Void = {}) {
        self.title = title
        self.icon = icon
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            VStack {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity, minHeight: 70)
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
        }
        .buttonStyle(PlainButtonStyle())
        .foregroundColor(.primary)
    }
}

struct ShipmentCard: View {
    let shipment: Shipment
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM, HH:mm"
        formatter.locale = Locale(identifier: "kk_KZ")
        return formatter
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(shipment.trackNumber)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text(dateFormatter.string(from: shipment.date))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Text(shipment.route)
                .font(.subheadline)
                .fontWeight(.medium)
            
            HStack {
                Text("Статус: \(shipment.status.rawValue)")
                    .font(.caption)
                    .foregroundColor(statusColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.1))
                    .cornerRadius(4)
                
                Spacer()
                
                Text(priceForShipment(shipment))
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .gray.opacity(0.2), radius: 2, x: 0, y: 1)
    }
    
    private var statusColor: Color {
        switch shipment.status {
        case .accepted: return .blue
        case .inTransit: return .orange
        case .atCustoms: return .yellow
        case .delivered: return .green
        }
    }
    
    private func priceForShipment(_ shipment: Shipment) -> String {
        if shipment.trackNumber.hasPrefix("KZ") {
            return "2 500 ₸"
        } else if shipment.trackNumber.hasPrefix("RU") {
            return "5 000 ₸"
        } else if shipment.trackNumber.hasPrefix("CN") {
            return "5 000 ₸"
        }
        return "1 500 ₸"
    }
}
