import Foundation
import Combine
import Supabase

@MainActor
class StorageService: ObservableObject {
    private let client = SupabaseManager.client
    private let bucket = "driver-documents"

    // MARK: - Upload Document File

    func uploadDocumentFile(
        userId: String,
        documentType: DocumentType,
        fileData: Data,
        fileName: String
    ) async throws -> String {
        let cleanUserId = userId.lowercased()
        let path = "\(cleanUserId)/\(documentType.fieldName)/\(fileName)"
        let options = FileOptions(
            cacheControl: "3600",
            contentType: getContentType(for: fileName),
            upsert: true
        )

        _ = try await client.storage
            .from(bucket)
            .upload(path, data: fileData, options: options)

        let publicURL = try client.storage
            .from(bucket)
            .getPublicURL(path: path)

        return publicURL.absoluteString
    }

    // MARK: - Delete Document File

    func deleteDocumentFile(path: String) async throws {
        _ = try await client.storage
            .from(bucket)
            .remove(paths: [path])
    }

    // MARK: - Download Document File

    func downloadDocumentFile(path: String) async throws -> Data {
        try await client.storage
            .from(bucket)
            .download(path: path)
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
