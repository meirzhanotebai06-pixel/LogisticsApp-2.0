import Foundation
import UIKit

enum ContactHelper {
    static func cleanTelNumber(_ phone: String) -> String {
        let trimmed = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasLeadingPlus = trimmed.hasPrefix("+")
        let digits = trimmed.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        return hasLeadingPlus ? "+\(digits)" : digits
    }

    static func cleanWhatsAppDigits(_ phone: String) -> String {
        var digits = phone.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        if digits.hasPrefix("8") && digits.count == 11 {
            digits = "7" + digits.dropFirst()
        } else if !digits.hasPrefix("7") && digits.count == 10 {
            digits = "7" + digits
        }
        return digits
    }

    static func call(phone: String) {
        let number = cleanTelNumber(phone)
        guard !number.isEmpty, let url = URL(string: "tel://\(number)") else { return }
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }

    static func openWhatsApp(phone: String, message: String? = nil) {
        let digits = cleanWhatsAppDigits(phone)
        guard !digits.isEmpty else { return }

        let query: String
        if let message, !message.isEmpty {
            let encoded = message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            query = "?text=\(encoded)"
        } else {
            query = ""
        }

        if let url = URL(string: "https://wa.me/\(digits)\(query)"), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else if let webURL = URL(string: "https://web.whatsapp.com/send?phone=\(digits)") {
            UIApplication.shared.open(webURL)
        }
    }

    static func sendSMS(phone: String, message: String) {
        let number = cleanTelNumber(phone)
        guard !number.isEmpty else { return }
        let encoded = message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "sms:\(number)&body=\(encoded)") {
            UIApplication.shared.open(url)
        }
    }
}
