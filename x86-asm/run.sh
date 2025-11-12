#!/bin/bash
set -e

echo "Running Conway's Game of Life in QEMU with UEFI..."

# Change to script directory
cd "$(dirname "$0")"

# Check if image exists
if [ ! -f build/game-of-life.img ]; then
    echo "Error: build/game-of-life.img not found."
    echo "Please run ./build.sh first."
    exit 1
fi

# Check for QEMU
if ! command -v qemu-system-x86_64 &> /dev/null; then
    echo "Error: qemu-system-x86_64 not found."
    echo "  Fedora/RHEL: sudo dnf install qemu-system-x86"
    echo "  Ubuntu/Debian: sudo apt install qemu-system-x86"
    exit 1
fi

# Check for OVMF firmware
OVMF_CODE=""
OVMF_VARS=""

# Common OVMF locations
OVMF_LOCATIONS=(
    "/usr/share/edk2/ovmf/OVMF_CODE.fd"
    "/usr/share/edk2/x64/OVMF_CODE.fd"
    "/usr/share/OVMF/OVMF_CODE.fd"
    "/usr/share/qemu/OVMF_CODE.fd"
    "/usr/share/ovmf/x64/OVMF_CODE.fd"
    "/usr/share/edk2-ovmf/x64/OVMF_CODE.fd"
)

for location in "${OVMF_LOCATIONS[@]}"; do
    if [ -f "$location" ]; then
        OVMF_CODE="$location"
        break
    fi
done

if [ -z "$OVMF_CODE" ]; then
    echo "Error: OVMF firmware not found."
    echo "Please install UEFI firmware:"
    echo "  Fedora/RHEL: sudo dnf install edk2-ovmf"
    echo "  Ubuntu/Debian: sudo apt install ovmf"
    echo ""
    echo "Searched in:"
    for location in "${OVMF_LOCATIONS[@]}"; do
        echo "  $location"
    done
    exit 1
fi

echo "Using OVMF firmware: $OVMF_CODE"

# Create temporary OVMF_VARS (writable copy)
OVMF_VARS="build/OVMF_VARS.fd"
if [ ! -f "$OVMF_VARS" ]; then
    OVMF_VARS_TEMPLATE="${OVMF_CODE/CODE/VARS}"
    if [ -f "$OVMF_VARS_TEMPLATE" ]; then
        cp "$OVMF_VARS_TEMPLATE" "$OVMF_VARS"
    else
        # Create empty vars file
        dd if=/dev/zero of="$OVMF_VARS" bs=1M count=64 2>/dev/null
    fi
fi

echo "Starting QEMU..."
echo "Press Ctrl+C to exit"
echo ""

# Run QEMU with UEFI - explicit format specification
qemu-system-x86_64 \
    -drive if=pflash,format=raw,readonly=on,file="$OVMF_CODE" \
    -drive if=pflash,format=raw,file="$OVMF_VARS" \
    -drive format=raw,file=build/game-of-life.img \
    -net none \
    -m 256M \
    -vga std

echo ""
echo "QEMU terminated."
