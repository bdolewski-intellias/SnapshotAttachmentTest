# SnapshotAttachmentTest

Minimal reproduction project demonstrating that **swift-snapshot-testing 1.19.0** does not attach UIImage diff images (reference, failure, difference) to the xcresult bundle when running under **Swift Testing**.

## The Problem

[swift-snapshot-testing 1.19.0](https://github.com/pointfreeco/swift-snapshot-testing/releases/tag/1.19.0) introduced Swift Testing attachment support via `DiffAttachment` ([PR #1064](https://github.com/pointfreeco/swift-snapshot-testing/pull/1064)). `NSImage` (macOS), `String`, and `Data` diffing strategies were migrated to the new `DiffAttachment.data` API, which works in both XCTest and Swift Testing.

However, **`UIImage.swift` (iOS/tvOS) was not migrated**. It still uses the deprecated `Diffing.init(toData:fromData:diff:)` which wraps attachments as `.xcTest(XCTAttachment)`. In `verifySnapshot`, `.xcTest` cases are [silently dropped](https://github.com/pointfreeco/swift-snapshot-testing/blob/1.19.0/Sources/SnapshotTesting/AssertSnapshot.swift#L466-L468) in Swift Testing context:

```swift
case .xcTest:
    break  // dropped — no attachment recorded
```

This means **iOS snapshot test failures produce zero image attachments** in the xcresult when using `@Test` / `@Suite`.

## How to Reproduce

### Prerequisites

- Xcode 26+ (Swift 6.2)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`

### Steps

```bash
# 1. Generate the Xcode project
xcodegen generate

# 2. First run — record reference snapshots
#    Edit Tests/SnapshotTests.swift: change record: .never → record: .all
#    Then change Color.green back to Color.red in redSquare()
xcodebuild test \
  -project SnapshotAttachmentTest.xcodeproj \
  -scheme SnapshotAttachmentTest \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath .derivedData \
  -resultBundlePath test-results.xcresult

# 3. Second run — trigger a mismatch
#    Revert record: .all → record: .never
#    Change Color.red → Color.green in redSquare()
rm -rf test-results.xcresult
xcodebuild test \
  -project SnapshotAttachmentTest.xcodeproj \
  -scheme SnapshotAttachmentTest \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath .derivedData \
  -resultBundlePath test-results.xcresult

# 4. Inspect attachments
xcrun xcresulttool export attachments \
  --path test-results.xcresult \
  --output-path exported-attachments

cat exported-attachments/manifest.json | python3 -m json.tool
```

### Expected Result

The manifest should contain `reference.png`, `failure.png`, and `difference.png` attachments for the failing `redSquare()` test — just like `NSImage` diffing produces on macOS.

### Actual Result

```
Skipped export for AttachmentTests/redSquare(): no matching attachments
```

The manifest contains only a text attachment (`Complete Issue Description.txt`). **No image attachments.**

```json
[
  {
    "attachments": [
      {
        "exportedFileName": "...",
        "suggestedHumanReadableName": "Complete Issue Description.txt"
      }
    ],
    "testIdentifier": "AttachmentTests/redSquare()"
  }
]
```

## Verified Fix

The [`fix/uiimage-diffattachment`](https://github.com/bdolewski-intellias/SnapshotAttachmentTest/tree/fix/uiimage-diffattachment) branch contains a **working, verified fix**. It migrates `UIImage.swift` to `Diffing.diff(toData:fromData:diffV2:)` with `DiffAttachment.data` — the same pattern already applied to `NSImage.swift` in PR #1064.

The fix is a 14-line patch ([`uiimage-diffattachment.patch`](https://github.com/bdolewski-intellias/SnapshotAttachmentTest/blob/fix/uiimage-diffattachment/uiimage-diffattachment.patch)):

```swift
// Before (current — deprecated, attachments dropped in Swift Testing):
return Diffing(
    toData: { $0.pngData() ?? emptyImage().pngData()! },
    fromData: { UIImage(data: $0, scale: imageScale)! }
) { old, new in
    ...
    let oldAttachment = XCTAttachment(image: old)
    ...
}

// After (works in both XCTest and Swift Testing):
return .diff(
    toData: { $0.pngData() ?? emptyImage().pngData()! },
    fromData: { UIImage(data: $0, scale: imageScale)! }
) { old, new in
    ...
    let oldAttachment = DiffAttachment.data(old.pngData()!, name: "reference.png")
    ...
}
```

### Results after fix

Running the same failing test with the patched `UIImage.swift` produces **3 image attachments** in the xcresult:

```
Exported 4 attachments for: AttachmentTests/redSquare():
  reference_0_*.png  (2,755 bytes)
  failure_0_*.png    (2,756 bytes)
  difference_0_*.png (1,368 bytes)
  Complete Issue Description.txt
```

### Reproduce the fix

The branch includes a [`reproduce.sh`](https://github.com/bdolewski-intellias/SnapshotAttachmentTest/blob/fix/uiimage-diffattachment/reproduce.sh) script that clones 1.19.0, applies the patch, and runs the tests in one command:

```bash
git checkout fix/uiimage-diffattachment
./reproduce.sh
```

## Project Setup

- **swift-snapshot-testing**: 1.19.0 (exact)
- **iOS deployment target**: 18.0
- **Swift**: 6.2
- **Test framework**: Swift Testing (`@Test` / `@Suite`)
- **Generated with**: [XcodeGen](https://github.com/yonaskolb/XcodeGen)

## Reference Snapshots

The `Tests/__Snapshots__/` directory contains pre-recorded reference snapshots:
- `redSquare.1.png` — a **red** square (the test renders **green**, causing mismatch)
- `blueCircle.1.png` — a blue circle (matches, test passes)
