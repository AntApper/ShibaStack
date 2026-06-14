#!/bin/bash
set -e

# ShibaStack Build & DMG Packaging Script
# This script compiles apc-core, apc-cli, apc-network, and apc-gui,
# structures the ShibaStack.app bundle, and packages it into ShibaStack.dmg.

echo "=================================================="
echo "🐕 ShibaStack: Building ShibaStack"
echo "=================================================="

# 1. Setup build directories
echo "Creating build structures..."
rm -rf build dmg_stage *.dmg
mkdir -p build/ShibaStack.app/Contents/MacOS
mkdir -p build/ShibaStack.app/Contents/Resources/bin
mkdir -p dmg_stage

# Generate brand icon assets first
if [ ! -f "ShibaStack.icns" ]; then
	echo "Generating brand icon assets..."
	swift scripts/generate-icon.swift
fi
cp ShibaStack.icns build/ShibaStack.app/Contents/Resources/ShibaStack.icns

# 2. Compile Go Networking helper
echo "Compiling apc-network (Go DNS & Reverse Proxy)..."
CGO_ENABLED=0 go build -ldflags="-s -w" -o build/ShibaStack.app/Contents/Resources/bin/apc-network apc-network/main.go

# 3. Compile Swift virtualization core and helper executables (SPM)
echo "Compiling apc-core, apc-daemon and apc CLI helper..."
cd apc-core
swift build -c release
cd ..

cp apc-core/.build/release/apc-daemon build/ShibaStack.app/Contents/Resources/bin/apc-daemon
cp apc-core/.build/release/apc build/ShibaStack.app/Contents/Resources/bin/apc

# 4. Compile SwiftUI Desktop Dashboard & Menu Bar app
echo "Compiling ShibaStack SwiftUI application..."
swiftc -O -sdk "$(xcrun --show-sdk-path)" -parse-as-library \
	-framework SwiftUI -framework AppKit -framework Virtualization -framework IOKit \
	-o build/ShibaStack.app/Contents/MacOS/ShibaStack \
	apc-gui/main.swift apc-core/Sources/APCCore/*.swift

# 5. Write Info.plist
echo "Generating Info.plist..."
cat <<'EOF' >build/ShibaStack.app/Contents/Info.plist
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>ShibaStack</string>
    <key>CFBundleIconFile</key>
    <string>ShibaStack.icns</string>
    <key>CFBundleIdentifier</key>
    <string>com.shibastack.shibaapp</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>ShibaStack</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>15.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSUIElement</key>
    <true/>
    <key>CFBundleURLTypes</key>
    <array>
        <dict>
            <key>CFBundleURLName</key>
            <string>com.shibastack.url</string>
            <key>CFBundleURLSchemes</key>
            <array>
                <string>shibastack</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
EOF

# 6. Apply Ad-hoc Codesigning
echo "Signing application bundle and embedded binaries..."
# Touch all contents to force Finder timestamp invalidation
touch build/ShibaStack.app/Contents/Resources/ShibaStack.icns
touch build/ShibaStack.app/Contents/Info.plist
touch build/ShibaStack.app

codesign -s - --entitlements scripts/entitlements.plist --force --deep build/ShibaStack.app

# Force Launch Services to register the new app bundle icon
echo "Registering app icon with Launch Services..."
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f build/ShibaStack.app

# 7. Prepare DMG Installer
echo "Preparing DMG disk staging..."
cp -R build/ShibaStack.app dmg_stage/
ln -s /Applications dmg_stage/Applications

# 8. Create standard macOS DMG
echo "Generating ShibaStack.dmg..."
hdiutil create -volname "ShibaStack" -srcfolder dmg_stage -ov -format UDZO ShibaStack.dmg

# Clean up temporary staging
rm -rf dmg_stage

echo "=================================================="
echo "✓ Success: ShibaStack.dmg created!"
echo "=================================================="
