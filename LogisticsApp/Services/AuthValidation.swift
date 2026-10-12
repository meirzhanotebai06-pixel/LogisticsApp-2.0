import Foundation

/// Shared, deterministic validation used by registration and login.
enum AuthValidation {
    static func validateEmailDetailed(_ email: String) -> String? {
        // Проверка на пустоту
        if email.isEmpty {
            return "Email енгізіңіз"
        }
        
        // Проверка длины
        if email.count > 100 {
            return "Email тым ұзын"
        }
        
        // Проверка первого символа
        if let firstChar = email.first, firstChar == "." || firstChar == "-" || firstChar == "_" {
            return "Email нүкте, дефис немесе астынғы сызықпен басталмауы керек"
        }
        
        // Проверка наличия @
        guard let atIndex = email.firstIndex(of: "@") else {
            return "Email @ белгісін қамтуы керек"
        }
        
        let localPart = String(email[..<atIndex])
        let domainPart = String(email[atIndex...])
        
        // Проверка local part
        if localPart.isEmpty {
            return "Email @ белгісінен бұрын бөлігі болуы керек"
        }
        
        // Проверка последнего символа local part
        if let lastLocalChar = localPart.last, lastLocalChar == "." || lastLocalChar == "-" || lastLocalChar == "_" {
            return "Email @ белгісінен бұрын нүкте, дефис немесе астынғы сызықпен аяқталмауы керек"
        }
        
        // Проверка количества дефисов в local part
        let dashCount = localPart.filter { $0 == "-" }.count
        if dashCount > 2 {
            return "Email 2 дефисден көп болмауы керек"
        }
        
        // Проверка последовательных специальных символов
        if localPart.contains("--") || localPart.contains("__") || localPart.contains("..") {
            return "Email бірінен соң бір дефис, астынғы сызық немесе нүкте болмауы керек"
        }
        
        // Проверка комбинаций символов
        if localPart.contains(".-") || localPart.contains("-.") ||
           localPart.contains("._") || localPart.contains("_.") ||
           localPart.contains("-_") || localPart.contains("_-") {
            return "Email дефис, астынғы сызық және нүкте бір-бірінің жанында болмауы керек"
        }
        
        // Проверка domain part
        let domainWithoutAt = String(domainPart.dropFirst())
        if domainWithoutAt.isEmpty {
            return "Email домен бөлігі болуы керек"
        }
        
        // Проверка первого символа domain part
        if let firstDomainChar = domainWithoutAt.first, firstDomainChar == "." || firstDomainChar == "-" || firstDomainChar == "_" {
            return "Домен нүкте, дефис немесе астынғы сызықпен басталмауы керек"
        }
        
        // Проверка последнего символа domain part
        if let lastDomainChar = domainWithoutAt.last, lastDomainChar == "." || lastDomainChar == "-" || lastDomainChar == "_" {
            return "Домен нүкте, дефис немесе астынғы сызықпен аяқталмауы керек"
        }
        
        // Проверка наличия точки в domain
        if !domainWithoutAt.contains(".") {
            return "Доменде нүкте болуы керек"
        }
        if domainWithoutAt.contains("..") {
            return "Email дұрыс форматта емес"
        }
        
        // Проверка на дефис/подчеркивание сразу после @ (f@gmail-.com)
        if domainPart.hasPrefix("@-") || domainPart.hasPrefix("@_") || domainPart.hasPrefix("@.") {
            return "Домен @ белгісінен кейін дефис, астынғы сызық немесе нүктемен басталмауы керек"
        }
        
        // Проверка на дефис/подчеркивание перед точкой в domain
        let domainParts = domainWithoutAt.split(separator: ".")
        for part in domainParts {
            let domainSegment = String(part)
            
            // Проверка первого символа каждого сегмента домена
            if let firstChar = domainSegment.first, firstChar == "-" || firstChar == "_" {
                return "Домен бөліктері дефис немесе астынғы сызықпен басталмауы керек"
            }
            
            // Проверка последнего символа каждого сегмента домена
            if let lastChar = domainSegment.last, lastChar == "-" || lastChar == "_" {
                return "Домен бөліктері дефис немесе астынғы сызықпен аяқталмауы керек"
            }
            
            // Проверка на последовательные дефисы в домене
            if domainSegment.contains("--") || domainSegment.contains("__") {
                return "Доменде бірінен соң бір дефис немесе астынғы сызық болмауы керек"
            }
        }
        
        // Финальная проверка regex
        let emailRegex = "^[A-Z0-9a-z]([A-Z0-9a-z._%+-]*[A-Z0-9a-z])?@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}$"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        
        if !emailPredicate.evaluate(with: email) {
            return "Email дұрыс форматта емес"
        }
        
        return nil
    }

    static func isValidPassword(_ password: String) -> Bool {
        let passwordRegex = "^[a-zA-Z0-9]+$"
        let passwordPredicate = NSPredicate(format: "SELF MATCHES %@", passwordRegex)
        return passwordPredicate.evaluate(with: password)
    }

    static func isValidPhone(_ phone: String) -> Bool {
        let allowedCharacters = CharacterSet(charactersIn: "+- ()0123456789")
        guard phone.unicodeScalars.allSatisfy({ allowedCharacters.contains($0) }) else {
            return false
        }
        let cleanedPhone = phone.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        return cleanedPhone.count == 11
    }

    static func isValidName(_ name: String) -> Bool {
        let nameRegex = "^[\\p{L}]+([-_][\\p{L}]+)?( [\\p{L}]+([-_][\\p{L}]+)?)?$"
        let namePredicate = NSPredicate(format: "SELF MATCHES %@", nameRegex)
        return namePredicate.evaluate(with: name) && name.count >= 2 && name.count <= 50
    }
}
