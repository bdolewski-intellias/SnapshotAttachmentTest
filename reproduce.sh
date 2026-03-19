#!/bin/bash
set -euo pipefail

# Reproduce the UIImage attachment fix for swift-snapshot-testing 1.19.0
# This script:
# 1. Clones swift-snapshot-testing 1.19.0
# 2. Applies the UIImage → DiffAttachment.data patch
# 3. Generates the Xcode project pointing to the local package
# 4. Runs tests (redSquare fails with mismatch)
# 5. Exports attachments and shows the manifest

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "=== Step 1: Clone swift-snapshot-testing 1.19.0 ==="
if [ -d swift-snapshot-testing-local ]; then
    echo "Already cloned, skipping..."
else
    git clone --branch 1.19.0 --depth 1 \
        https://github.com/pointfreeco/swift-snapshot-testing.git \
        swift-snapshot-testing-local
fi

echo ""
echo "=== Step 2: Apply UIImage fix ==="
cd swift-snapshot-testing-local
git checkout -- . 2>/dev/null || true
git apply ../uiimage-diffattachment.patch
cd ..
echo "Patch applied successfully."

echo ""
echo "=== Step 3: Generate Xcode project ==="
xcodegen generate

echo ""
echo "=== Step 4: Run tests ==="
rm -rf test-results-fixed.xcresult
xcodebuild test \
    -project SnapshotAttachmentTest.xcodeproj \
    -scheme SnapshotAttachmentTest \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
    -derivedDataPath .derivedData-fixed \
    -resultBundlePath test-results-fixed.xcresult \
    2>&1 | xcbeautify 2>&1 | tail -15 || true

echo ""
echo "=== Step 5: Export attachments ==="
rm -rf exported-attachments-fixed
mkdir -p exported-attachments-fixed
xcrun xcresulttool export attachments \
    --path test-results-fixed.xcresult \
    --output-path exported-attachments-fixed

echo ""
echo "=== Results ==="
echo "Exported files:"
ls -la exported-attachments-fixed/
echo ""
echo "Manifest:"
cat exported-attachments-fixed/manifest.json | python3 -m json.tool
