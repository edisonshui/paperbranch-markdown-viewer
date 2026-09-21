import Darwin
import Foundation

/// Watches both a document and its containing folder. The folder watch keeps
/// observing atomic replacements and a document that reappears at its known
/// path after its original vnode has been removed.
final class FileChangeMonitor {
    private var sources: [DispatchSourceFileSystemObject] = []

    init(documentURL: URL, didSignalChange: @escaping @Sendable () -> Void) {
        observe(documentURL, didSignalChange: didSignalChange)
        observe(documentURL.deletingLastPathComponent(), didSignalChange: didSignalChange)
    }

    deinit { cancel() }

    func cancel() {
        sources.forEach { $0.cancel() }
        sources.removeAll()
    }

    private func observe(_ url: URL, didSignalChange: @escaping @Sendable () -> Void) {
        let descriptor = open(url.path, O_EVTONLY)
        guard descriptor >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .delete, .rename, .attrib, .extend, .revoke],
            queue: .global()
        )
        source.setEventHandler(handler: didSignalChange)
        source.setCancelHandler { close(descriptor) }
        sources.append(source)
        source.resume()
    }
}
