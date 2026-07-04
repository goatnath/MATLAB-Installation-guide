#!/bin/bash
# MATLAB on Arch Linux / Wayland - Automated Fix Script
# See README.md for full details on what this script does.

set -e

# --- Configuration ---
MATLAB_ROOT="/opt/MATLAB/R2026a"
SERVICEHOST_ROOT="$HOME/.MathWorks/ServiceHost/-mw_shared_installs"
GNUTLS_URL="https://archive.archlinux.org/packages/g/gnutls/gnutls-3.8.8-1-x86_64.pkg.tar.zst"
NETTLE_URL="https://archive.archlinux.org/packages/n/nettle/nettle-3.10-1-x86_64.pkg.tar.zst"

echo "================================================="
echo "   MATLAB Arch Linux & Wayland Automated Fix"
echo "================================================="

# 1. Fix the Wayland UI Crash (Hide bundled graphics libs)
echo ""
echo "[1/3] Fixing Wayland UI Crashes (Requires sudo)..."
if [ -d "$MATLAB_ROOT/bin/glnxa64" ]; then
    sudo mkdir -p "$MATLAB_ROOT/bin/glnxa64/exclude"
    echo "Moving conflicting bundled libraries to exclude folder..."
    
    sudo mv $MATLAB_ROOT/bin/glnxa64/libfreetype.so* $MATLAB_ROOT/bin/glnxa64/exclude/ 2>/dev/null || true
    sudo mv $MATLAB_ROOT/bin/glnxa64/libglib-2.0.so* $MATLAB_ROOT/bin/glnxa64/exclude/ 2>/dev/null || true
    sudo mv $MATLAB_ROOT/bin/glnxa64/libgio-2.0.so* $MATLAB_ROOT/bin/glnxa64/exclude/ 2>/dev/null || true
    sudo mv $MATLAB_ROOT/bin/glnxa64/libharfbuzz.so* $MATLAB_ROOT/bin/glnxa64/exclude/ 2>/dev/null || true
    sudo mv $MATLAB_ROOT/bin/glnxa64/libfontconfig.so* $MATLAB_ROOT/bin/glnxa64/exclude/ 2>/dev/null || true
    echo "Graphics libraries successfully excluded."
else
    echo "Warning: MATLAB root directory not found at $MATLAB_ROOT."
fi

# 2. Fix MathWorksServiceHost lc_init Crash
echo ""
echo "[2/3] Fixing MathWorksServiceHost (lc_init collision)..."
if [ -d "$SERVICEHOST_ROOT" ]; then
    SH_VERSION_DIR=$(ls "$SERVICEHOST_ROOT" | head -n 1)
    TARGET_DIR="$SERVICEHOST_ROOT/$SH_VERSION_DIR/bin/glnxa64"
    
    if [ -n "$SH_VERSION_DIR" ] && [ -d "$TARGET_DIR" ]; then
        echo "Found ServiceHost directory: $TARGET_DIR"
        mkdir -p /tmp/matlab-fix/gnutls-pkg /tmp/matlab-fix/nettle-pkg
        wget -q --show-progress "$GNUTLS_URL" -O /tmp/matlab-fix/gnutls.pkg.tar.zst
        wget -q --show-progress "$NETTLE_URL" -O /tmp/matlab-fix/nettle.pkg.tar.zst
        
        tar -xf /tmp/matlab-fix/gnutls.pkg.tar.zst -C /tmp/matlab-fix/gnutls-pkg
        tar -xf /tmp/matlab-fix/nettle.pkg.tar.zst -C /tmp/matlab-fix/nettle-pkg
        
        cp -P /tmp/matlab-fix/gnutls-pkg/usr/lib/libgnutls* "$TARGET_DIR/"
        cp -P /tmp/matlab-fix/nettle-pkg/usr/lib/libnettle* "$TARGET_DIR/"
        cp -P /tmp/matlab-fix/nettle-pkg/usr/lib/libhogweed* "$TARGET_DIR/"
        
        rm -rf /tmp/matlab-fix
        pkill -9 -f MathWorksServiceHost || true
        echo "MathWorksServiceHost successfully fixed."
    else
        echo "Could not find a valid MathWorksServiceHost version directory."
    fi
else
    echo "ServiceHost root not found."
fi

# 3. Final reminders
echo ""
echo "[3/3] Fixes applied!"
echo "-------------------------------------------------"
echo "IMPORTANT REMINDER:"
echo "Always launch MATLAB with the XWayland compatibility flag:"
echo "  env QT_QPA_PLATFORM=xcb /usr/bin/matlab"
echo "-------------------------------------------------"
