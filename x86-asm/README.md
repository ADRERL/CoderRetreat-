# Conway's Game of Life - UEFI x86-64 Bootable Assembly

Pure x86-64 assembly implementation of Conway's Game of Life that boots as a UEFI application in QEMU.

## Features

**Full parity with C# implementation:**
- ✅ Infinite sparse grid (no boundaries)
- ✅ Random seed generation (30% density)
- ✅ 60×25 character viewport with box-drawing borders
- ✅ Dynamic camera following pattern center
- ✅ Real-time statistics (generation, alive cells, bounds)
- ✅ Conway's classic rules (birth on 3, survive on 2-3)

## Technical Details

### Architecture
- **Platform:** UEFI x86-64 PE32+ executable
- **Assembler:** NASM (Netwide Assembler)
- **Grid:** Hash table with linear probing (4096 cell capacity)
- **PRNG:** Linear Congruential Generator seeded with RDTSC
- **Display:** UEFI Simple Text Output Protocol with Unicode box-drawing

### Implementation Highlights

1. **PE32+ UEFI Header:** Complete DOS stub + PE header for UEFI boot
2. **Sparse Grid:** Dictionary-based storage for infinite simulation
3. **Hash Function:** `(row * 73856093) ^ (col * 19349663) mod 4096`
4. **Viewport:** 60×25 grid centered on pattern with dynamic tracking
5. **Character Set:** Unicode box-drawing (╭─╮│█╰─╯)

## Prerequisites

### Required Tools
```bash
# Fedora/RHEL
sudo dnf install nasm qemu-system-x86 edk2-ovmf dosfstools

# Ubuntu/Debian
sudo apt install nasm qemu-system-x86 ovmf dosfstools
```

### Optional (for manual disk mounting)
```bash
# Fedora/RHEL
sudo dnf install mtools

# Ubuntu/Debian
sudo apt install mtools
```

## Build & Run

### Quick Start
```bash
chmod +x build.sh run.sh
./build.sh
./run.sh
```

### Manual Steps

**Build:**
```bash
# Assemble UEFI application
nasm -f bin -o BOOTX64.EFI main.asm

# Create FAT32 disk image
dd if=/dev/zero of=game-of-life.img bs=1M count=64
mkfs.vfat -F 32 game-of-life.img

# Copy to EFI/BOOT/ directory
mkdir -p /mnt/efi
sudo mount -o loop game-of-life.img /mnt/efi
sudo mkdir -p /mnt/efi/EFI/BOOT
sudo cp BOOTX64.EFI /mnt/efi/EFI/BOOT/
sudo umount /mnt/efi
```

**Run:**
```bash
qemu-system-x86_64 \
    -drive if=pflash,format=raw,readonly=on,file=/usr/share/edk2/ovmf/OVMF_CODE.fd \
    -drive if=pflash,format=raw,file=OVMF_VARS.fd \
    -drive format=raw,file=game-of-life.img \
    -m 256M
```

## Output

```
╭────────────────────────────────────────────────────────────╮
│                                                            │
│          ██  ██                                            │
│        ██      ██                                          │
│          ██  ██                                            │
│                                                            │
╰────────────────────────────────────────────────────────────╯
Gen: 42 | Cells: 107 | Bounds: (-23,-23) to (23,18)
```

## Code Structure

### Entry Point (`_start`)
- Receives UEFI system table
- Initializes Simple Text Output Protocol
- Seeds PRNG with RDTSC timestamp
- Initializes grid with random 30×30 primordial soup
- Enters infinite game loop

### Game Loop
1. `draw_game` - Render 60×25 viewport with borders and stats
2. `delay` - Approximate 150ms pause
3. `update_grid` - Apply Conway's rules to all cells
4. Increment generation counter
5. Repeat

### Core Functions

**Grid Management:**
- `hash_position` - Hash (row, col) to grid index
- `get_cell` - Retrieve cell state with linear probing
- `set_cell` - Update cell state in hash table
- `count_neighbors` - Check all 8 adjacent positions
- `calculate_bounds` - Find min/max row/col of alive cells

**Game Logic:**
- `init_grid` - Random 30% density in 30×30 area
- `update_grid` - Apply rules to expanded bounds region
- Conway's rules: Birth on 3, survive on 2-3, else death

**Display:**
- `draw_game` - Clear screen, draw borders, render viewport
- `print_string` - UEFI OutputString (UTF-16LE)
- `print_number` - Convert integer to string and display

**Utilities:**
- `random` - LCG: `Xn+1 = (1103515245*Xn + 12345) mod 2^32`
- `random_range` - Generate random in `[0, N)`
- `delay` - Busy-wait loop

## Memory Layout

```
0x00400000  DOS Header (64 bytes)
            PE Header (~200 bytes)
            Section Header (40 bytes)
0x00400200  Code Start (.text section)
            - Entry point
            - Game logic
            - Display functions
            Data Section
            - UEFI handles
            - Game state
            - UTF-16 strings
            BSS Section
            - grid: 49,152 bytes (4096 * 12)
            - next_grid: 49,152 bytes
Total:      ~100 KB
```

## Comparison with C# Version

| Feature | C# (.NET 8) | x86 ASM (UEFI) |
|---------|-------------|----------------|
| Grid Type | `Dictionary<Position, CellState>` | Linear-probing hash table |
| Random | `Random.Shared` | LCG with RDTSC seed |
| Display | ANSI console codes | UEFI Text Protocol |
| Viewport | 60×25 dynamic | 60×25 dynamic |
| Borders | Unicode box chars | Unicode box chars |
| Rules | Exact Conway | Exact Conway |
| Infinite | ✅ | ✅ |
| Random Seed | ✅ | ✅ |

## Troubleshooting

**OVMF not found:**
- Install `edk2-ovmf` (Fedora) or `ovmf` (Ubuntu)
- Update `OVMF_LOCATIONS` in `run.sh` if needed

**Build fails:**
- Verify `nasm` version: `nasm --version` (2.15+ recommended)
- Check for syntax errors in `main.asm`

**QEMU doesn't boot:**
- Ensure OVMF firmware path is correct
- Try `sudo ./build.sh` if mount permissions fail
- Check `build/game-of-life.img` is 64MB FAT32

**No display output:**
- UEFI ConOut protocol may not initialize in all VMs
- Try different QEMU display: `-display sdl` or `-nographic`

## License

Same as parent repository (kata-bootstraps).

## Credits

Assembly implementation by GitHub Copilot, matching the C# reference implementation.
