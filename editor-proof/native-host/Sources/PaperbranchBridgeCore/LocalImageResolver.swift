import Foundation
import ImageIO
import UniformTypeIdentifiers

public enum LocalImageResolverError: LocalizedError {
    case invalidReference
    case unauthorizedPath
    case unavailableImage

    public var errorDescription: String? {
        switch self {
        case .invalidReference: "The image reference is invalid."
        case .unauthorizedPath: "The image is outside this Markdown document's folder."
        case .unavailableImage: "The image is missing, unreadable, or not a supported image file."
        }
    }
}

/// Resolves only relative image references beneath one Markdown document's
/// containing folder. It is the native authorization boundary for image data.
public struct LocalImageResolver {
    private let documentFolder: URL

    public init(documentURL: URL) throws {
        documentFolder = documentURL
            .deletingLastPathComponent()
            .standardizedFileURL
            .resolvingSymlinksInPath()
    }

    public func data(for reference: String) throws -> Data {
        guard let decodedReference = reference.removingPercentEncoding,
              !decodedReference.isEmpty,
              !decodedReference.hasPrefix("/"),
              URL(string: decodedReference)?.scheme == nil
        else { throw LocalImageResolverError.invalidReference }

        let candidate = documentFolder
            .appendingPathComponent(decodedReference)
            .standardizedFileURL
            .resolvingSymlinksInPath()
        guard candidate.path.hasPrefix(documentFolder.path + "/") else {
            throw LocalImageResolverError.unauthorizedPath
        }

        let values = try? candidate.resourceValues(forKeys: [.isRegularFileKey, .isReadableKey])
        guard values?.isRegularFile == true,
              values?.isReadable == true,
              let type = UTType(filenameExtension: candidate.pathExtension),
              type.conforms(to: .image),
              let data = try? Data(contentsOf: candidate),
              let imageSource = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetType(imageSource) != nil
        else { throw LocalImageResolverError.unavailableImage }
        return data
    }
}
