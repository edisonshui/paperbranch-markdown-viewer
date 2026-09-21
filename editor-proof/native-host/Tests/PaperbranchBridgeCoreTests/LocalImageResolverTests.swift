import XCTest

@testable import PaperbranchBridgeCore

final class LocalImageResolverTests: XCTestCase {
    private let pngData = Data(base64Encoded:
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScL8KwAAAABJRU5ErkJggg=="
    )!

    func testReadsAValidRelativeImage() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let imageURL = fixture.directory.appendingPathComponent("photo.png")
        try pngData.write(to: imageURL)

        let resolver = try LocalImageResolver(documentURL: fixture.documentURL)

        XCTAssertEqual(try resolver.data(for: "photo.png"), pngData)
    }

    func testRejectsAMissingImage() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let resolver = try LocalImageResolver(documentURL: fixture.documentURL)

        XCTAssertThrowsError(try resolver.data(for: "missing.png"))
    }

    func testRejectsAnInvalidImageFile() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        try Data("not an image".utf8).write(to: fixture.directory.appendingPathComponent("invalid.png"))
        let resolver = try LocalImageResolver(documentURL: fixture.documentURL)

        XCTAssertThrowsError(try resolver.data(for: "invalid.png"))
    }

    func testReadsAnImageWhosePathContainsSpaces() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let imageURL = fixture.directory.appendingPathComponent("image folder/photo with spaces.png")
        try FileManager.default.createDirectory(at: imageURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try pngData.write(to: imageURL)

        let resolver = try LocalImageResolver(documentURL: fixture.documentURL)

        XCTAssertEqual(try resolver.data(for: "image%20folder/photo%20with%20spaces.png"), pngData)
    }

    func testRejectsAPathOutsideTheDocumentFolder() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let secretURL = fixture.directory.deletingLastPathComponent().appendingPathComponent("secret.png")
        try pngData.write(to: secretURL)
        let resolver = try LocalImageResolver(documentURL: fixture.documentURL)

        XCTAssertThrowsError(try resolver.data(for: "../secret.png"))
    }

    private func makeFixture() throws -> (directory: URL, documentURL: URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("paperbranch-image-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let documentURL = directory.appendingPathComponent("document.md")
        try "# Images\n".write(to: documentURL, atomically: true, encoding: .utf8)
        return (directory, documentURL)
    }
}
