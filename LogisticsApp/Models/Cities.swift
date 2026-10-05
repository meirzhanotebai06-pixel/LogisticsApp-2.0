import Foundation
import CoreLocation

// MARK: - City Model

struct City: Identifiable, Hashable {
    let id = UUID()
    let nameKZ: String          // Казахское название
    let nameRU: String          // Русское название
    let nameEN: String          // Английское название
    let coordinate: CLLocationCoordinate2D
    let country: String
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: City, rhs: City) -> Bool {
        lhs.id == rhs.id
    }
    
    // Все возможные названия города
    var allNames: [String] {
        return [nameKZ, nameRU, nameEN]
    }
}

// MARK: - Cities Database

struct CitiesDatabase {
    static let cities: [City] = [
        // Казахстан
        City(nameKZ: "Алматы", nameRU: "Алматы", nameEN: "Almaty", coordinate: CLLocationCoordinate2D(latitude: 43.2380, longitude: 76.8829), country: "Қазақстан"),
        City(nameKZ: "Астана", nameRU: "Астана", nameEN: "Astana", coordinate: CLLocationCoordinate2D(latitude: 51.1694, longitude: 71.4491), country: "Қазақстан"),
        City(nameKZ: "Шымкент", nameRU: "Шымкент", nameEN: "Shymkent", coordinate: CLLocationCoordinate2D(latitude: 42.3417, longitude: 69.5901), country: "Қазақстан"),
        City(nameKZ: "Қарағанды", nameRU: "Караганда", nameEN: "Karaganda", coordinate: CLLocationCoordinate2D(latitude: 49.7989, longitude: 73.0874), country: "Қазақстан"),
        City(nameKZ: "Ақтөбе", nameRU: "Актобе", nameEN: "Aktobe", coordinate: CLLocationCoordinate2D(latitude: 50.2839, longitude: 57.1670), country: "Қазақстан"),
        City(nameKZ: "Тараз", nameRU: "Тараз", nameEN: "Taraz", coordinate: CLLocationCoordinate2D(latitude: 42.9000, longitude: 71.3667), country: "Қазақстан"),
        City(nameKZ: "Павлодар", nameRU: "Павлодар", nameEN: "Pavlodar", coordinate: CLLocationCoordinate2D(latitude: 52.2873, longitude: 76.9674), country: "Қазақстан"),
        City(nameKZ: "Өскемен", nameRU: "Усть-Каменогорск", nameEN: "Oskemen", coordinate: CLLocationCoordinate2D(latitude: 49.9787, longitude: 82.6147), country: "Қазақстан"),
        City(nameKZ: "Семей", nameRU: "Семей", nameEN: "Semey", coordinate: CLLocationCoordinate2D(latitude: 50.4111, longitude: 80.2275), country: "Қазақстан"),
        City(nameKZ: "Орал", nameRU: "Уральск", nameEN: "Oral", coordinate: CLLocationCoordinate2D(latitude: 51.2333, longitude: 51.3667), country: "Қазақстан"),
        City(nameKZ: "Ақтау", nameRU: "Актау", nameEN: "Aktau", coordinate: CLLocationCoordinate2D(latitude: 43.6500, longitude: 51.1500), country: "Қазақстан"),
        City(nameKZ: "Атырау", nameRU: "Атырау", nameEN: "Atyrau", coordinate: CLLocationCoordinate2D(latitude: 47.1164, longitude: 51.8833), country: "Қазақстан"),
        City(nameKZ: "Қостанай", nameRU: "Костанай", nameEN: "Kostanay", coordinate: CLLocationCoordinate2D(latitude: 53.2144, longitude: 63.6246), country: "Қазақстан"),
        City(nameKZ: "Қызылорда", nameRU: "Кызылорда", nameEN: "Kyzylorda", coordinate: CLLocationCoordinate2D(latitude: 44.8479, longitude: 65.4822), country: "Қазақстан"),
        City(nameKZ: "Петропавл", nameRU: "Петропавловск", nameEN: "Petropavl", coordinate: CLLocationCoordinate2D(latitude: 54.8667, longitude: 69.1500), country: "Қазақстан"),
        City(nameKZ: "Талдықорған", nameRU: "Талдыкорган", nameEN: "Taldykorgan", coordinate: CLLocationCoordinate2D(latitude: 45.0167, longitude: 78.3833), country: "Қазақстан"),
        City(nameKZ: "Түркістан", nameRU: "Туркестан", nameEN: "Turkistan", coordinate: CLLocationCoordinate2D(latitude: 43.3000, longitude: 68.2500), country: "Қазақстан"),
        
        // Россия
        City(nameKZ: "Мәскеу", nameRU: "Москва", nameEN: "Moscow", coordinate: CLLocationCoordinate2D(latitude: 55.7558, longitude: 37.6173), country: "Ресей"),
        City(nameKZ: "Санкт-Петербург", nameRU: "Санкт-Петербург", nameEN: "Saint Petersburg", coordinate: CLLocationCoordinate2D(latitude: 59.9343, longitude: 30.3351), country: "Ресей"),
        City(nameKZ: "Новосибирск", nameRU: "Новосибирск", nameEN: "Novosibirsk", coordinate: CLLocationCoordinate2D(latitude: 55.0084, longitude: 82.9357), country: "Ресей"),
        City(nameKZ: "Екатеринбург", nameRU: "Екатеринбург", nameEN: "Yekaterinburg", coordinate: CLLocationCoordinate2D(latitude: 56.8389, longitude: 60.6057), country: "Ресей"),
        City(nameKZ: "Қазан", nameRU: "Казань", nameEN: "Kazan", coordinate: CLLocationCoordinate2D(latitude: 55.7964, longitude: 49.1089), country: "Ресей"),
        City(nameKZ: "Омбы", nameRU: "Омск", nameEN: "Omsk", coordinate: CLLocationCoordinate2D(latitude: 54.9885, longitude: 73.3242), country: "Ресей"),
        City(nameKZ: "Челябі", nameRU: "Челябинск", nameEN: "Chelyabinsk", coordinate: CLLocationCoordinate2D(latitude: 55.1644, longitude: 61.4368), country: "Ресей"),
        City(nameKZ: "Самара", nameRU: "Самара", nameEN: "Samara", coordinate: CLLocationCoordinate2D(latitude: 53.1959, longitude: 50.1002), country: "Ресей"),
        City(nameKZ: "Ростов", nameRU: "Ростов-на-Дону", nameEN: "Rostov-on-Don", coordinate: CLLocationCoordinate2D(latitude: 47.2357, longitude: 39.7015), country: "Ресей"),
        City(nameKZ: "Уфа", nameRU: "Уфа", nameEN: "Ufa", coordinate: CLLocationCoordinate2D(latitude: 54.7388, longitude: 55.9721), country: "Ресей"),
        
        // Китай
        City(nameKZ: "Өрімші", nameRU: "Урумчи", nameEN: "Urumqi", coordinate: CLLocationCoordinate2D(latitude: 43.8256, longitude: 87.6168), country: "Қытай"),
        City(nameKZ: "Пекин", nameRU: "Пекин", nameEN: "Beijing", coordinate: CLLocationCoordinate2D(latitude: 39.9042, longitude: 116.4074), country: "Қытай"),
        City(nameKZ: "Шанхай", nameRU: "Шанхай", nameEN: "Shanghai", coordinate: CLLocationCoordinate2D(latitude: 31.2304, longitude: 121.4737), country: "Қытай"),
        City(nameKZ: "Гуанчжоу", nameRU: "Гуанчжоу", nameEN: "Guangzhou", coordinate: CLLocationCoordinate2D(latitude: 23.1291, longitude: 113.2644), country: "Қытай"),
        
        // Узбекистан
        City(nameKZ: "Ташкент", nameRU: "Ташкент", nameEN: "Tashkent", coordinate: CLLocationCoordinate2D(latitude: 41.2995, longitude: 69.2401), country: "Өзбекстан"),
        City(nameKZ: "Самарқанд", nameRU: "Самарканд", nameEN: "Samarkand", coordinate: CLLocationCoordinate2D(latitude: 39.6270, longitude: 66.9750), country: "Өзбекстан"),
        
        // Кыргызстан
        City(nameKZ: "Бішкек", nameRU: "Бишкек", nameEN: "Bishkek", coordinate: CLLocationCoordinate2D(latitude: 42.8746, longitude: 74.5698), country: "Қырғызстан"),
        City(nameKZ: "Ош", nameRU: "Ош", nameEN: "Osh", coordinate: CLLocationCoordinate2D(latitude: 40.5283, longitude: 72.7985), country: "Қырғызстан"),
        
        // Туркменистан
        City(nameKZ: "Ашхабад", nameRU: "Ашхабад", nameEN: "Ashgabat", coordinate: CLLocationCoordinate2D(latitude: 37.9601, longitude: 58.3261), country: "Түркіменстан"),
        
        // Таджикистан
        City(nameKZ: "Душанбе", nameRU: "Душанбе", nameEN: "Dushanbe", coordinate: CLLocationCoordinate2D(latitude: 38.5598, longitude: 68.7738), country: "Тәжікстан"),
    ]
    
    // Поиск городов по запросу (поддерживает казахский, русский, английский)
    static func search(query: String) -> [City] {
        guard !query.isEmpty else { return [] }
        
        let lowercasedQuery = query.lowercased()
        
        return cities.filter { city in
            city.nameKZ.lowercased().contains(lowercasedQuery) ||
            city.nameRU.lowercased().contains(lowercasedQuery) ||
            city.nameEN.lowercased().contains(lowercasedQuery)
        }
    }
    
    // Проверка существования города (принимает любое название)
    static func isValid(cityName: String) -> Bool {
        return cities.contains { city in
            city.nameKZ.lowercased() == cityName.lowercased() ||
            city.nameRU.lowercased() == cityName.lowercased() ||
            city.nameEN.lowercased() == cityName.lowercased()
        }
    }
    
    // Получить город по названию (принимает любое название)
    static func getCity(name: String) -> City? {
        return cities.first { city in
            city.nameKZ.lowercased() == name.lowercased() ||
            city.nameRU.lowercased() == name.lowercased() ||
            city.nameEN.lowercased() == name.lowercased()
        }
    }
    
    // Получить координаты города
    static func getCoordinate(cityName: String) -> CLLocationCoordinate2D? {
        return getCity(name: cityName)?.coordinate
    }
}

// MARK: - Обновленный cityCoordinates для совместимости

let cityCoordinates: [String: CLLocationCoordinate2D] = {
    var dict: [String: CLLocationCoordinate2D] = [:]
    for city in CitiesDatabase.cities {
        // Добавляем все варианты названий
        dict[city.nameKZ] = city.coordinate
        dict[city.nameRU] = city.coordinate
        dict[city.nameEN] = city.coordinate
    }
    return dict
}()
