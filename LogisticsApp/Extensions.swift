import Foundation

enum Formatters {
    static let shortDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM, HH:mm"
        formatter.locale = Locale(identifier: "kk_KZ")
        return formatter
    }()

    static let fullDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy, HH:mm"
        formatter.locale = Locale(identifier: "kk_KZ")
        return formatter
    }()

    static let shortDayMonth: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        formatter.locale = Locale(identifier: "kk_KZ")
        return formatter
    }()

    static let dateOnly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter
    }()

    static let tengeFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        return formatter
    }()
}

extension Date {
    func formattedShortDateTime() -> String {
        Formatters.shortDateTime.string(from: self)
    }

    func formattedFullDateTime() -> String {
        Formatters.fullDateTime.string(from: self)
    }

    func formattedShortDayMonth() -> String {
        Formatters.shortDayMonth.string(from: self)
    }

    func formattedDateOnly() -> String {
        Formatters.dateOnly.string(from: self)
    }
}

extension Int {
    func formattedTenge(currency: String = "₸") -> String {
        let formatted = Formatters.tengeFormatter.string(from: NSNumber(value: self)) ?? "\(self)"
        return "\(formatted) \(currency)"
    }
}
