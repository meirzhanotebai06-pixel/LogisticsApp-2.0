import Foundation
import CoreLocation

enum TwoGISRouteService {
    static func routeURL(fromAddress: String, toAddress: String) -> URL? {
        guard let from = CitiesDatabase.getCoordinate(cityName: fromAddress),
              let to = CitiesDatabase.getCoordinate(cityName: toAddress) else {
            return nil
        }

        let urlString = String(
            format: "https://2gis.ru/routeSearch/rsType/car/from/%.6f,%.6f/to/%.6f,%.6f",
            locale: Locale(identifier: "en_US_POSIX"),
            from.longitude,
            from.latitude,
            to.longitude,
            to.latitude
        )

        return URL(string: urlString)
    }
}
