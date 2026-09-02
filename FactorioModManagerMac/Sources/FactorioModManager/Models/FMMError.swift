import Foundation

/// Type-safe error definitions for Factorio Mod Manager operations.
public enum FMMError: LocalizedError, Sendable, Equatable {
    case emptyModName
    case modNotFound(name: String)
    case corruptedData(modName: String)
    case invalidDownloadURL(url: String)
    case httpError(statusCode: Int, message: String? = nil)
    case destinationFileCreationFailed(path: String)
    case invalidZipArchive(filename: String)
    case emptyProfileName
    case fileNotFound(path: String)
    case invalidModpack(reason: String)
    case noMatchingRelease(modName: String, branch: String?)
    case custom(String)

    public var errorDescription: String? {
        switch self {
        case .emptyModName:
            return loc("error_empty_mod_name")
        case .modNotFound(let name):
            return String(format: loc("error_mod_not_found"), name)
        case .corruptedData(let name):
            return String(format: loc("error_corrupted_data"), name)
        case .invalidDownloadURL(let url):
            return String(format: loc("error_invalid_download_url"), url)
        case .httpError(let code, let message):
            if let msg = message, !msg.isEmpty {
                return "HTTP \(code): \(msg)"
            }
            return "HTTP \(code)"
        case .destinationFileCreationFailed(let path):
            return String(format: loc("error_destination_file_creation"), path)
        case .invalidZipArchive(let filename):
            return String(format: loc("error_invalid_zip"), filename)
        case .emptyProfileName:
            return loc("error_empty_profile_name")
        case .fileNotFound(let path):
            return String(format: loc("error_file_not_found"), path)
        case .invalidModpack(let reason):
            return reason
        case .noMatchingRelease(let modName, let branch):
            if let b = branch {
                return "No matching release found for '\(modName)' on Factorio \(b)"
            }
            return "No matching release found for '\(modName)'"
        case .custom(let msg):
            return msg
        }
    }
}
