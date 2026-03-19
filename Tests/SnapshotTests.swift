import Testing
import SwiftUI
import SnapshotTesting

@MainActor
@Suite(.snapshots(record: .never))
struct AttachmentTests {
    /// This test FAILS because the reference snapshot was recorded as a red square,
    /// but the view now renders green. This mismatch should produce diff attachments
    /// (reference, failure, difference) in the xcresult — but doesn't for UIImage
    /// because UIImage.swift still uses the deprecated Diffing.init path which wraps
    /// attachments as .xcTest(XCTAttachment), silently dropped in Swift Testing.
    @Test("Red square snapshot — mismatched, proves attachment gap")
    func redSquare() {
        let view = Color.green.frame(width: 100, height: 100)
        assertSnapshot(of: view, as: .image(layout: .sizeThatFits))
    }

    /// This test PASSES — the reference matches the view.
    @Test("Blue circle snapshot — matches reference")
    func blueCircle() {
        let view = Circle().fill(.blue).frame(width: 80, height: 80)
        assertSnapshot(of: view, as: .image(layout: .sizeThatFits))
    }
}
