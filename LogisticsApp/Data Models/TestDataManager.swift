import Foundation
import FirebaseFirestore

class TestDataManager {
    private let db = Firestore.firestore()
    
    func addTestOffices() {
        let offices = [
            [
                "id": UUID().uuidString,
                "name": "Астана бөлімшесі",
                "address": "Ә.Қашаубаев көшесі, 12",
                "phone": "+7 7172 123 456",
                "hours": "09:00 - 18:00",
                "latitude": 51.1694,
                "longitude": 71.4491
            ],
            [
                "id": UUID().uuidString,
                "name": "Алматы бөлімшесі",
                "address": "Әбілқайыр хан даңғылы, 45",
                "phone": "+7 727 234 5678",
                "hours": "09:00 - 19:00",
                "latitude": 43.2380,
                "longitude": 76.8829
            ]
        ]
        
        for office in offices {
            db.collection("offices").document(office["id"] as! String).setData(office) { error in
                if let error = error {
                    print("Error adding office: \(error)")
                } else {
                    print("Office added successfully: \(office["name"] ?? "")")
                }
            }
        }
    }
    
    func addTestTariffs() {
        let tariffs = [
            [
                "id": UUID().uuidString,
                "type": "express",
                "name": "Экспресс жеткізу",
                "description": "Жедел жеткізу 1-2 күн ішінде",
                "price": "2 500 ₸",
                "deliveryTime": "1-2 күн",
                "features": ["Қауіпсіз орау", "Тегін қайта жіберу", "Телефондық қолдау"]
            ],
            [
                "id": UUID().uuidString,
                "type": "standard",
                "name": "Стандартты жеткізу",
                "description": "Қарапайым жеткізу 3-5 күн ішінде",
                "price": "1 500 ₸",
                "deliveryTime": "3-5 күн",
                "features": ["Қауіпсіз орау", "Телефондық қолдау"]
            ]
        ]
        
        for tariff in tariffs {
            db.collection("tariffs").document(tariff["id"] as! String).setData(tariff) { error in
                if let error = error {
                    print("Error adding tariff: \(error)")
                } else {
                    print("Tariff added successfully: \(tariff["name"] ?? "")")
                }
            }
        }
    }
    
    func addTestDriverWithVehicle(userId: String) {
        let calendar = Calendar.current
        
        // Создаем даты истечения документов
        let insuranceExpiry = calendar.date(byAdding: .month, value: 6, to: Date())!
        let licenseExpiry = calendar.date(byAdding: .year, value: 2, to: Date())!
        let registrationExpiry = calendar.date(byAdding: .month, value: 3, to: Date())! // Скоро истекает
        let inspectionExpiry = calendar.date(byAdding: .day, value: 15, to: Date())! // Скоро истекает
        
        let vehicleData: [String: Any] = [
            "model": "Toyota Hiace",
            "plateNumber": "A123BC77",
            "capacity": "1500 кг",
            "documents": [
                "insurance": [
                    "number": "INS-2024-12345",
                    "expiryDate": Timestamp(date: insuranceExpiry),
                    "isVerified": true,
                    "uploadDate": Timestamp(date: Date())
                ],
                "driverLicense": [
                    "number": "DL-KZ-67890",
                    "expiryDate": Timestamp(date: licenseExpiry),
                    "isVerified": true,
                    "uploadDate": Timestamp(date: Date())
                ],
                "vehicleRegistration": [
                    "number": "REG-2024-11111",
                    "expiryDate": Timestamp(date: registrationExpiry),
                    "isVerified": false,
                    "uploadDate": Timestamp(date: Date())
                ],
                "technicalInspection": [
                    "number": "TI-2024-22222",
                    "expiryDate": Timestamp(date: inspectionExpiry),
                    "isVerified": false,
                    "uploadDate": Timestamp(date: Date())
                ]
            ]
        ]
        
        db.collection("users").document(userId).updateData([
            "vehicleInfo": vehicleData
        ]) { error in
            if let error = error {
                print("Error adding vehicle info: \(error)")
            } else {
                print("Vehicle info added successfully for driver: \(userId)")
            }
        }
    }
}
