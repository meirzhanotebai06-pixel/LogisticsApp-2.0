import Foundation

/// Shared, deterministic validation used by registration, login, and document forms.
enum AuthValidation {
    static func validateEmailDetailed(_ email: String) -> String? {
        if email.isEmpty {
            return "Email енгізіңіз"
        }

        if email.count > 100 {
            return "Email тым ұзын"
        }

        if let firstChar = email.first, firstChar == "." || firstChar == "-" || firstChar == "_" {
            return "Email нүкте, дефис немесе астынғы сызықпен басталмауы керек"
        }

        guard let atIndex = email.firstIndex(of: "@") else {
            return "Email @ белгісін қамтуы керек"
        }

        let localPart = String(email[..<atIndex])
        let domainPart = String(email[atIndex...])

        if localPart.isEmpty {
            return "Email @ белгісінен бұрын бөлігі болуы керек"
        }

        if let lastLocalChar = localPart.last, lastLocalChar == "." || lastLocalChar == "-" || lastLocalChar == "_" {
            return "Email @ белгісінен бұрын нүкте, дефис немесе астынғы сызықпен аяқталмауы керек"
        }

        let dashCount = localPart.filter { $0 == "-" }.count
        if dashCount > 2 {
            return "Email 2 дефисден көп болмауы керек"
        }

        if localPart.contains("--") || localPart.contains("__") || localPart.contains("..") {
            return "Email бірінен соң бір дефис, астынғы сызық немесе нүкте болмауы керек"
        }

        if localPart.contains(".-") || localPart.contains("-.") ||
           localPart.contains("._") || localPart.contains("_.") ||
           localPart.contains("-_") || localPart.contains("_-") {
            return "Email дефис, астынғы сызық және нүкте бір-бірінің жанында болмауы керек"
        }

        let domainWithoutAt = String(domainPart.dropFirst())
        if domainWithoutAt.isEmpty {
            return "Email домен бөлігі болуы керек"
        }

        if let firstDomainChar = domainWithoutAt.first, firstDomainChar == "." || firstDomainChar == "-" || firstDomainChar == "_" {
            return "Домен нүкте, дефис немесе астынғы сызықпен басталмауы керек"
        }

        if let lastDomainChar = domainWithoutAt.last, lastDomainChar == "." || lastDomainChar == "-" || lastDomainChar == "_" {
            return "Домен нүкте, дефис немесе астынғы сызықпен аяқталмауы керек"
        }

        if !domainWithoutAt.contains(".") {
            return "Доменде нүкте болуы керек"
        }
        if domainWithoutAt.contains("..") {
            return "Email дұрыс форматта емес"
        }

        if domainPart.hasPrefix("@-") || domainPart.hasPrefix("@_") || domainPart.hasPrefix("@.") {
            return "Домен @ белгісінен кейін дефис, астынғы сызық немесе нүктемен басталмауы керек"
        }

        let domainParts = domainWithoutAt.split(separator: ".")
        for part in domainParts {
            let domainSegment = String(part)

            if let firstChar = domainSegment.first, firstChar == "-" || firstChar == "_" {
                return "Домен бөліктері дефис немесе астынғы сызықпен басталмауы керек"
            }

            if let lastChar = domainSegment.last, lastChar == "-" || lastChar == "_" {
                return "Домен бөліктері дефис немесе астынғы сызықпен аяқталмауы керек"
            }

            if domainSegment.contains("--") || domainSegment.contains("__") {
                return "Доменде бірінен соң бір дефис немесе астынғы сызық болмауы керек"
            }
        }

        let emailRegex = "^[A-Z0-9a-z]([A-Z0-9a-z._%+-]*[A-Z0-9a-z])?@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}$"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)

        if !emailPredicate.evaluate(with: email) {
            return "Email дұрыс форматта емес"
        }

        return nil
    }

    static func isValidPassword(_ password: String) -> Bool {
        let trimmed = password.trimmingCharacters(in: .whitespacesAndNewlines)
        return password.count >= 6 && trimmed.count == password.count
    }

    static func normalizePhone(_ phone: String) -> String? {
        let allowedCharacters = CharacterSet(charactersIn: "+- ()0123456789")
        guard phone.unicodeScalars.allSatisfy({ allowedCharacters.contains($0) }) else {
            return nil
        }
        let digits = phone.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        if digits.count == 11, digits.hasPrefix("7") || digits.hasPrefix("8") {
            return "+7\(digits.dropFirst())"
        }
        if digits.count == 10, digits.hasPrefix("7") {
            return "+7\(digits)"
        }
        return nil
    }

    static func isValidPhone(_ phone: String) -> Bool {
        normalizePhone(phone) != nil
    }

    static func isValidName(_ name: String) -> Bool {
        let nameRegex = "^[\\p{L}]+([-_][\\p{L}]+)?( [\\p{L}]+([-_][\\p{L}]+)?)?$"
        let namePredicate = NSPredicate(format: "SELF MATCHES %@", nameRegex)
        return namePredicate.evaluate(with: name) && name.count >= 2 && name.count <= 50
    }

    static func isValidIIN(_ iin: String) -> Bool {
        let trimmed = iin.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count == 12 && trimmed.allSatisfy(\.isNumber)
    }

    static func isValidVIN(_ vin: String) -> Bool {
        let trimmed = vin.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let vinRegex = "^[A-HJ-NPR-Z0-9]{17}$"
        return NSPredicate(format: "SELF MATCHES %@", vinRegex).evaluate(with: trimmed)
    }

    static func isValidVehicleYear(_ yearString: String) -> Bool {
        let trimmed = yearString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let year = Int(trimmed) else { return false }
        let currentYear = Calendar.current.component(.year, from: Date())
        return year >= 1950 && year <= currentYear + 1
    }
}
