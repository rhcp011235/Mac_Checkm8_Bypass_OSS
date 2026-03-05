#!/bin/bash
# CheckM8 macOS build script
# Usage: ./build.sh [--release] [--clean]

set -e
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_DIR"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

CONFIGURATION="Debug"
CLEAN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --release) CONFIGURATION="Release"; shift ;;
        --clean)   CLEAN=true; shift ;;
        --help)
            echo "Usage: $0 [--release] [--clean]"
            exit 0
            ;;
        *) echo -e "${RED}Unknown option: $1${NC}"; exit 1 ;;
    esac
done

echo -e "${GREEN}Building CheckM8 for macOS (Universal — arm64 + x86_64)...${NC}"

if [ "$CLEAN" = true ]; then
    echo -e "${YELLOW}Cleaning...${NC}"
    xcodebuild clean -project CheckM8.xcodeproj -scheme CheckM8 -configuration "$CONFIGURATION" 2>/dev/null || true
    rm -rf build/
fi

echo -e "${GREEN}Building $CONFIGURATION...${NC}"
xcodebuild \
    -project CheckM8.xcodeproj \
    -scheme CheckM8 \
    -configuration "$CONFIGURATION" \
    -derivedDataPath ./build \
    ARCHS="arm64 x86_64" \
    ONLY_ACTIVE_ARCH=NO \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=YES \
    | grep -E "^(Build|CompileSwift|error:|warning:|note:)" | sed 's/^/  /'

APP_PATH="build/Build/Products/${CONFIGURATION}/CheckM8.app"

if [ -d "$APP_PATH" ]; then
    echo ""
    echo -e "${GREEN}=========================================${NC}"
    echo -e "${GREEN}Build Successful!${NC}"
    echo -e "${GREEN}=========================================${NC}"
    echo ""
    echo -e "App: ${GREEN}$APP_PATH${NC}"
    echo ""
    echo "Architecture:"
    lipo -info "$APP_PATH/Contents/MacOS/CheckM8" 2>/dev/null | sed 's/^/  /'
    echo ""
    echo "To run:"
    echo -e "  ${YELLOW}open \"$APP_PATH\"${NC}"
else
    echo -e "${RED}Build failed — app not found at $APP_PATH${NC}"
    exit 1
fi
