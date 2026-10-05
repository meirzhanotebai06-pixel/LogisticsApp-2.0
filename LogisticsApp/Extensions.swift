// Extensions.swift
import Foundation

extension Date {
    func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM, HH:mm"
        formatter.locale = Locale(identifier: "kk_KZ")
        return formatter.string(from: self)
    }
}
