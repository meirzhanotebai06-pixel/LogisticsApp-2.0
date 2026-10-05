import Foundation
import FirebaseStorage
import UIKit
import Combine

class StorageService: ObservableObject {
    private let storage = Storage.storage()
    
    // MARK: - Upload Document File
    
    func uploadDocumentFile(userId: String, documentType: DocumentType, fileData: Data, fileName: String) async throws -> String {
        let storageRef = storage.reference()
        let documentPath = "drivers/\(userId)/documents/\(documentType.fieldName)/\(fileName)"
        let fileRef = storageRef.child(documentPath)
        
        // Загружаем файл
        let metadata = StorageMetadata()
        metadata.contentType = getContentType(for: fileName)
        
        _ = try await fileRef.putDataAsync(fileData, metadata: metadata)
        
        // Получаем URL загруженного файла
        let downloadURL = try await fileRef.downloadURL()
        return downloadURL.absoluteString
    }
    
    // MARK: - Delete Document File
    
    func deleteDocumentFile(fileURL: String) async throws {
        let storageRef = storage.reference(forURL: fileURL)
        try await storageRef.delete()
    }
    
    // MARK: - Download Document File
    
    func downloadDocumentFile(fileURL: String) async throws -> Data {
        let storageRef = storage.reference(forURL: fileURL)
        let maxSize: Int64 = 10 * 1024 * 1024 // 10 MB
        return try await storageRef.data(maxSize: maxSize)
    }
    
    // MARK: - Helper Methods
    
    private func getContentType(for fileName: String) -> String {
        let fileExtension = (fileName as NSString).pathExtension.lowercased()
        
        switch fileExtension {
        case "pdf":
            return "application/pdf"
        case "jpg", "jpeg":
            return "image/jpeg"
        case "png":
            return "image/png"
        case "heic":
            return "image/heic"
        default:
            return "application/octet-stream"
        }
    }
}
