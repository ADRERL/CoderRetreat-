#!/bin/bash
set -e

echo "Building Conway's Game of Life UEFI x86-64 Bootable Image..."

# Change to script directory
cd "$(dirname "$0")"

# Check for nasm
if ! command -v nasm &> /dev/null; then
    echo "Error: nasm not found. Please install nasm assembler."
    echo "  Fedora/RHEL: sudo dnf install nasm"
    echo "  Ubuntu/Debian: sudo apt install nasm"
    exit 1
fi

# Create build directory
mkdir -p build
mkdir -p build/EFI/BOOT

# Assemble the code
echo "Assembling main.asm..."
nasm -f bin -o build/EFI/BOOT/BOOTX64.EFI main.asm

# Check output
if [ ! -f build/EFI/BOOT/BOOTX64.EFI ]; then
    echo "Error: Failed to create BOOTX64.EFI"
    exit 1
fi

FILE_SIZE=$(stat -c%s build/EFI/BOOT/BOOTX64.EFI 2>/dev/null || stat -f%z build/EFI/BOOT/BOOTX64.EFI 2>/dev/null)
echo "Successfully created BOOTX64.EFI (${FILE_SIZE} bytes)"

# Create disk image
echo "Creating UEFI bootable disk image..."
dd if=/dev/zero of=build/game-of-life.img bs=1M count=64 2>/dev/null

# Create GPT partition table and FAT32 ESP partition
if command -v parted &> /dev/null; then
    # Use parted for GPT partitioning
    parted -s build/game-of-life.img mklabel gpt
    parted -s build/game-of-life.img mkpart primary fat32 1MiB 100%
    parted -s build/game-of-life.img set 1 esp on
    
    # Create loopback device for partition
    LOOP_DEV=$(sudo losetup --show -fP build/game-of-life.img)
    
    # Format partition as FAT32
    sudo mkfs.vfat -F 32 "${LOOP_DEV}p1" > /dev/null 2>&1
    
    # Mount and copy files
    MOUNT_POINT=$(mktemp -d)
    sudo mount "${LOOP_DEV}p1" "$MOUNT_POINT"
    sudo mkdir -p "$MOUNT_POINT/EFI/BOOT"
    sudo cp build/EFI/BOOT/BOOTX64.EFI "$MOUNT_POINT/EFI/BOOT/"
    sudo umount "$MOUNT_POINT"
    sudo losetup -d "$LOOP_DEV"
    rmdir "$MOUNT_POINT"
    
    echo "Successfully created bootable image with GPT: build/game-of-life.img"
else
    echo "Warning: parted not found, creating simple FAT32 image (may not boot in all configurations)"
    
    # Format as FAT32
    if command -v mkfs.vfat &> /dev/null; then
        mkfs.vfat -F 32 build/game-of-life.img > /dev/null 2>&1
    else
        echo "Warning: mkfs.vfat not found. Attempting with mkfs.fat..."
        if command -v mkfs.fat &> /dev/null; then
            mkfs.fat -F 32 build/game-of-life.img > /dev/null 2>&1
        else
            echo "Error: Neither mkfs.vfat nor mkfs.fat found."
            echo "  Fedora/RHEL: sudo dnf install dosfstools"
            echo "  Ubuntu/Debian: sudo apt install dosfstools"
            exit 1
        fi
    fi

    # Mount and copy files
    echo "Copying UEFI application to disk image..."
    MOUNT_POINT=$(mktemp -d)

    # Try different mount methods
    if sudo mount -o loop build/game-of-life.img "$MOUNT_POINT" 2>/dev/null; then
        sudo cp -r build/EFI "$MOUNT_POINT/"
        sudo umount "$MOUNT_POINT"
        rmdir "$MOUNT_POINT"
        echo "Successfully created bootable image: build/game-of-life.img"
    elif command -v mtools &> /dev/null; then
        # Fallback to mtools if mount fails
        echo "Using mtools to copy files..."
        mmd -i build/game-of-life.img ::/EFI
        mmd -i build/game-of-life.img ::/EFI/BOOT
        mcopy -i build/game-of-life.img build/EFI/BOOT/BOOTX64.EFI ::/EFI/BOOT/
        rmdir "$MOUNT_POINT"
        echo "Successfully created bootable image: build/game-of-life.img"
    else
        rmdir "$MOUNT_POINT"
        echo "Error: Cannot mount image and mtools not available."
        echo "  Fedora/RHEL: sudo dnf install mtools"
        echo "  Ubuntu/Debian: sudo apt install mtools"
        echo ""
        echo "Raw UEFI executable is available at: build/EFI/BOOT/BOOTX64.EFI"
        echo "You can manually copy this to a FAT32 formatted USB drive."
        exit 1
    fi
fi

echo ""
echo "Build complete!"
echo "  UEFI Application: build/EFI/BOOT/BOOTX64.EFI"
echo "  Bootable Image: build/game-of-life.img"
echo ""
echo "Run with: ./run.sh"
