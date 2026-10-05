import Foundation
import Firebase
import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage

class FirebaseManager: NSObject {
    let auth: Auth
    let firestore: Firestore
    let storage: Storage
    
    static let shared = FirebaseManager()
    
    override init() {
        // Настройка Firebase
        FirebaseApp.configure()
        
        self.auth = Auth.auth()
        self.firestore = Firestore.firestore()
        self.storage = Storage.storage()
        
        super.init()
    }
}
