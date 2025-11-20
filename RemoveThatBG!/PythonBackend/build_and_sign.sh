#!/bin/bash
# Build and Sign Script for RemoveThatBG Python Backend

set -e  # Exit on error

echo "🔨 Building Python backend with PyInstaller..."
rm -rf build dist
pyinstaller remove_bg.spec

echo ""
echo "🔐 Signing all binaries..."

cd dist/remove_bg

# Sign Python framework first
echo "  ✓ Signing Python.framework..."
codesign --force --deep --sign - _internal/Python.framework

# Sign all dylibs and .so files
echo "  ✓ Signing dynamic libraries..."
find _internal -name "*.dylib" -o -name "*.so" | while read lib; do
    codesign --force --sign - "$lib" 2>/dev/null || true
done

# Sign the main executable
echo "  ✓ Signing main executable..."
codesign --force --deep --sign - remove_bg

cd ../..

echo ""
echo "✅ Build complete!"
echo ""
echo "📦 Output: PythonBackend/dist/remove_bg/"
echo ""
echo "📋 Next steps:"
echo "   1. Copy 'remove_bg' folder to Xcode project"
echo "   2. Add 'remove_bg' executable to 'Copy Bundle Resources'"
echo "   3. Add '_internal' folder as reference (not copied items)"
echo ""
