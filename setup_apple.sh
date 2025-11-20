#!/bin/bash
# Quick Setup Script for Apple-Native RemoveThatBG

echo "🍎 RemoveThatBG - Apple Native Setup"
echo "===================================="
echo ""

# Check we're in the right directory
if [ ! -d "RemoveThatBG!" ]; then
    echo "❌ Error: Run this from the RemoveThatBG root directory"
    exit 1
fi

# Check Python version
PYTHON_VERSION=$(python3 --version 2>&1 | awk '{print $2}')
echo "✓ Python version: $PYTHON_VERSION"

# Check pip
if python3 -m pip --version > /dev/null 2>&1; then
    echo "✓ pip is installed"
else
    echo "⚠️  pip not found, installing..."
    python3 -m ensurepip --upgrade
fi

echo ""
echo "📦 Setting up virtual environment..."
cd PythonBackend
python3 setup_venv.py

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Virtual environment ready!"
    echo "   Location: ~/Library/Application Support/RemoveThatBG/venv"
else
    echo ""
    echo "⚠️  Virtual environment setup had issues"
    echo "   You can try manually: cd PythonBackend && python3 setup_venv.py"
fi

cd ..
echo ""
echo "📋 Next Steps:"
echo ""
echo "1. Open Xcode:"
echo "   open 'RemoveThatBG!/RemoveThatBG!.xcodeproj'"
echo ""
echo "2. Add PythonBackend folder to project:"
echo "   - Right-click project navigator"
echo "   - Add Files to RemoveThatBG!..."
echo "   - Select PythonBackend folder"
echo "   - Check 'Create folder references' (blue folder)"
echo "   - Check 'Copy items if needed'"
echo "   - Click Add"
echo ""
echo "3. Build and Run (Cmd+R)"
echo ""
echo "📖 For detailed instructions, see:"
echo "   APPLE_NATIVE_IMPLEMENTATION.md"
echo "   SETUP_XCODE.md"
echo ""
