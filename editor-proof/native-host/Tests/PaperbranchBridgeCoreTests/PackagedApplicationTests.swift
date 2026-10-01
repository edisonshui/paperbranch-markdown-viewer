import Foundation
import XCTest

final class PackagedApplicationTests: XCTestCase {
    func testPackagedApplicationContainsTheOfflineDocumentView() throws {
        let appPath = try XCTUnwrap(ProcessInfo.processInfo.environment["PAPERBRANCH_PACKAGED_APP_PATH"])
        let appBundle = try XCTUnwrap(Bundle(path: appPath))

        XCTAssertEqual(appBundle.object(forInfoDictionaryKey: "CFBundleName") as? String, "Paperbranch")
        XCTAssertNotNil(appBundle.url(forResource: "index", withExtension: "html", subdirectory: "Web"))
    }
}
