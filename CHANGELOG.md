# Changelog

All notable changes to BitPast will be documented in this file.

## [4.1] - 2026-02-03

### Added
- **Per-Image Conversion Settings** - Lock individual settings for each image during batch export:
  - Click the **lock icon** in the image toolbar to save current settings for the selected image
  - Locked images display an **orange lock indicator** on their thumbnail
  - During batch export or disk creation, each locked image uses its saved settings
  - Unlocked images continue to use the current global settings
  - Settings are tied to the machine type (e.g., C64 settings won't apply to Apple IIgs)
  - Click the lock again to unlock and revert to global settings

### Technical
- Added `lockedSettings` and `lockedMachineIndex` fields to `InputImage` struct
- Extended `RetroMachine` protocol with optional settings parameter
- Updated all 15 converters to accept per-image settings
- Modified batch export methods to use per-image settings when available
- Added lock/unlock button and thumbnail indicator in ContentView

## [4.0] - 2026-01-31

### Added
- **Universal Create Disk Feature** - Create disk images for ALL supported retro systems:
  - **Commodore 64/VIC-20/Plus4**: D64 (170KB), D71 (340KB), D81 (800KB) - CBM DOS format
  - **Amiga 500/1200**: ADF (880KB, 1.76MB HD) - OFS filesystem
  - **Atari 800**: ATR (90KB, 130KB, 180KB, 360KB) - Atari DOS 2.0S format
  - **Atari ST**: ST (360KB, 720KB, 1.44MB) - FAT12 filesystem
  - **BBC Micro**: SSD (100KB, 200KB), DSD (200KB, 400KB) - Acorn DFS format
  - **MSX**: DSK (360KB, 720KB) - MSX-DOS FAT12 format
  - **Amstrad CPC**: DSK (180KB, 360KB) - CPCEMU extended format
  - **ZX Spectrum**: TRD (640KB), DSK (180KB) - TR-DOS format
  - **PC**: IMG (360KB, 720KB, 1.2MB, 1.44MB) - DOS FAT12/FAT16 format
  - **Apple II/IIgs**: PO, 2MG, HDV (140KB, 800KB, 32MB) - ProDOS format (existing)
- **Create Disk Sheet** - New unified UI with:
  - Horizontal system icon bar showing all 14 systems
  - Pre-selects currently active conversion system
  - Dynamic format and size options per system
  - System-specific volume name validation
  - Volume name character set enforcement per platform
- **Disk Creation Progress Bar** - Visual progress indicator when creating disk images:
  - Shows current file being converted and progress percentage
  - Theme-aware styling (works with retro themes)
  - Replaces the spinning beachball with informative feedback
- **Atari ST Medium and High Res Modes** - Additional graphics modes for Atari ST:
  - **Low Res** (320×200) - 16 colors from 512-color palette → .PI1
  - **Medium Res** (640×200) - 4 colors from 512-color palette → .PI2
  - **High Res** (640×400) - Monochrome (2 colors) → .PI3

### Changed
- **ProDOS Button renamed to Create Disk** - Now supports all systems, not just Apple II/IIgs

### Fixed
- **VIC-20 HiRes Dot Artifacts** - Fixed random dots appearing in uniform areas of VIC-20 HiRes images:
  - Changed pixel comparison from `<=` to `<` so equidistant pixels default to background color
  - Added 10% minimum contrast threshold for foreground color selection to ignore noise
  - Prevents gray or noisy pixels from being incorrectly assigned to foreground
- **D64/D71/D81 PETSCII Encoding** - Fixed filename and disk name display in Commodore disk images:
  - Now uses correct unshifted PETSCII range ($41-$5A) that displays properly on C64
  - Fixed BAM format with proper $A0 shifted space padding bytes
  - Filenames and block counts now display correctly in VICE and VirtualC64
- **D64/D71 Sector Allocation** - Fixed broken interleave logic that wasted disk space:
  - Previous code only used ~3 sectors per track before moving to next track
  - Now uses sequential allocation, utilizing all sectors per track
  - D64 can now fit ~16 files instead of 2-3
- **Batch Conversion for Disk Images** - All selected images are now converted when creating a disk image (previously only converted one)
- **Image Count Display** - CreateDiskSheet now shows correct number of selected images
- **ADFWriter Multi-File Crash** - Fixed crash when exporting multiple images to Amiga ADF disk:
  - File blocks now start at block 2 (after boot blocks) instead of overlapping root/bitmap area
  - Proper skip logic for root block (880 DD / 1760 HD) and bitmap block allocation
- **CPC Disk File Truncation** - Fixed Amstrad CPC DSK files being truncated:
  - Files > 16KB now correctly use multiple directory extents (CP/M format requirement)
  - 16512-byte screen files (16384 + 128 AMSDOS header) now fully stored
- **Atari ST High Res Crash** - Fixed crash when using High Res (640×400) monochrome mode:
  - DEGAS format requires 16 palette entries even for monochrome mode
  - Monochrome palette now padded to 16 entries (white, black + 14 black)
- **Apple IIgs 3200-Color Brooks Format** - Fixed ProDOS disk export using wrong aux type:
  - 3200-color Brooks format files now use correct aux type $0002
  - Other retro graphics converters can now properly identify Brooks format images
  - Standard SHR files continue to use aux type $0000

### Technical
- Added `DiskFormats.swift` with centralized disk system/format/size enumerations
- Added `CreateDiskSheet.swift` with unified disk creation UI
- Added `D64Writer.swift` for Commodore D64/D71/D81 disk images (CBM DOS with BAM)
- Added `ADFWriter.swift` for Amiga ADF disk images (OFS filesystem)
- Added `ATRWriter.swift` for Atari 800 ATR disk images (Atari DOS 2.0S)
- Added `STWriter.swift` for Atari ST disk images (FAT12)
- Added `BBCDiskWriter.swift` for BBC Micro SSD/DSD disk images (Acorn DFS)
- Added `MSXDiskWriter.swift` for MSX DSK disk images (MSX-DOS)
- Added `CPCDiskWriter.swift` for Amstrad CPC DSK disk images (CPCEMU format)
- Added `TRDWriter.swift` for ZX Spectrum TRD disk images (TR-DOS)
- Added `IMGWriter.swift` for PC IMG disk images (DOS FAT12/FAT16)
- Added `createDiskImage(configuration:)` routing method to ConverterViewModel

## [3.2] - 2026-01-30

### Added
- **C64 PETSCII Mode** - Character-based graphics conversion for Commodore 64:
  - **PETSCII (40×25)** - 40×25 character grid (320×200 with 8×8 character cells)
  - 2 colors per character cell: 1 global background + 1 foreground per character
  - XOR-based pattern matching to find best PETSCII character for each 8×8 tile
  - Automatic background color selection (most common dark color)
  - **Output:** `.prg` (self-displaying executable with BASIC loader)

### Fixed
- **PC Text Mode ANSI Output** - Fixed .ans file export for ANSI art viewers:
  - Now uses valid CP437 block characters (░▒▓█▄▌▐▀) instead of control characters
  - Proper ANSI.SYS escape sequences with bold attribute for bright colors
  - Added SAUCE metadata record for viewer compatibility
  - CGA to ANSI color mapping corrected
- **Retro Theme Fonts** - Fixed font loading for retro appearance modes:
  - Apple IIgs theme now correctly uses "Shaston 640" font
  - Commodore 64 theme now correctly uses "Pet Me 64" font
  - Apple II theme uses "Print Char 21" font
  - Added ATSApplicationFontsPath to Info.plist for proper font discovery

### Technical
- Added `convertPETSCII()`, `findBestPETSCIIChar()`, and `createPETSCIIPRG()` functions to C64Converter
- PETSCII charset loaded from `c64petscii.bin` bundle resource (2048 bytes)
- PRG file includes BASIC stub loader and machine code viewer
- Refactored `findBestCharacter()` to only match valid CP437 block characters
- Added `ansiBlockChars` array with correct CP437 codes and bitmap patterns
- Separated SAUCE record generation into `createSAUCERecord()` function

## [3.4] - 2026-01-29

### Added
- **BBC Micro Converter** - Acorn BBC Micro graphics conversion support:
  - **Mode 0** - 640×256, 2 colors (high-resolution)
  - **Mode 1** - 320×256, 4 colors from 8-color palette
  - **Mode 2** - 160×256, 8 colors (full palette)
  - **Mode 4** - 320×256, 2 colors (compact memory)
  - **Mode 5** - 160×256, 4 colors (compact memory)
  - Native .bbc file output (raw screen memory)
- **System Menu Update** - BBC Micro (⇧⌘8), keyboard shortcuts reorganized

### Technical
- Added `BBCMicroConverter.swift` with 6845 CRTC video emulation
- 8-color fixed palette (Black, Red, Green, Yellow, Blue, Magenta, Cyan, White)
- Interleaved memory layout for authentic BBC Micro screen format
- BBC Micro icon added to Assets.xcassets

## [3.3] - 2026-01-29

### Added
- **Atari 800 Converter** - Atari 8-bit computer graphics conversion support:
  - **Graphics 8** - 320×192, 2 colors (high-resolution monochrome)
  - **Graphics 15** - 160×192, 4 colors from 128-color GTIA palette
  - **Graphics 9** - 80×192, 16 shades (GTIA grayscale mode)
  - **Graphics 10** - 80×192, 9 colors from 128-color palette (GTIA color mode)
  - **Graphics 11** - 80×192, 16 hues at one luminance (GTIA hue mode)
  - Native .gr8, .gr15, .gr9, .gr10, .gr11 file output
- **System Menu Update** - Atari 800 (⇧⌘6), keyboard shortcuts reorganized

### Technical
- Added `Atari800Converter.swift` with ANTIC/GTIA video chip emulation
- 128-color palette (16 hues × 8 luminances) with NTSC color approximation
- All five GTIA graphics modes fully implemented
- Atari 800 icon added to Assets.xcassets

## [3.2] - 2026-01-29

### Added
- **MSX Converter** - MSX/MSX2 graphics conversion support:
  - **Screen 2 (MSX1)** - 256×192, 2 colors per 8×1 line from TMS9918 palette
  - **Screen 5 (MSX2)** - 256×212, 16 colors from 512-color V9938 palette
  - **Screen 8 (MSX2)** - 256×212, 256 fixed colors (3-3-2 RGB)
  - Native .sc2, .sc5, .sc8 file output (BSAVE format)
- **PC Converter** - IBM PC graphics conversion support:
  - **CGA Mode** - 320×200, 4 colors from fixed CGA palettes
  - **EGA Mode** - 320×200, fixed 16-color EGA palette
  - **EGA 64 Mode** - 320×200, 16 colors selected from 64-color EGA palette
  - **VGA Mode 13h** - 320×200, 256 colors from 262,144-color palette
  - **CGA 80×25 Text** - 640×200, character-based display with 16 colors
  - **VESA 132×50 Text** - 1056×400, extended text mode
  - Native .pcx file output for graphics modes, .ans for text modes
- **System Menu Update** - PC (⇧⌘P), MSX (⇧⌘M)
- **Hue Color Matching** - New color matching algorithm that preserves color hues, best for images with saturated colors
- **Apple IIgs Enhancements**:
  - Lowpass preprocessing filter
  - Extended dithering options: Noise, Bayer 2×2/4×4/8×8/16×16, Blue Noise 8×8/16×16
- **PC Processing Options**:
  - CGA Palette selection: Cyan/Magenta/White, Cyan/Magenta/Gray, Green/Red/Yellow, Green/Red/Brown
  - Dithering: None, Floyd-Steinberg, Atkinson, Bayer (2×2, 4×4, 8×8)
  - Contrast: None (default), HE, CLAHE, SWAHE
  - Color Matching: Euclidean, Perceptive, Luma, Chroma, Hue
  - Saturation and Gamma controls

### Fixed
- **PCX CGA Header** - Fixed bits-per-pixel value (now correctly writes 2bpp for 4-color CGA)

### Technical
- Added `MSXConverter.swift` with TMS9918 and V9938 video chip emulation
- Added `PCConverter.swift` with CGA, EGA, VGA and text mode implementations
- K-D tree optimization for VGA 256-color palette matching (10-20x faster)
- CGA 16-color palette and 4-color graphics palettes
- EGA 64-color palette generation
- VGA adaptive 256-color palette using median-cut algorithm
- Character pattern matching for text modes
- MSX and PC icons added to Assets.xcassets

## [3.1] - 2026-01-29

### Added
- **Amiga 500 Converter** - Full Amiga 500 OCS/ECS graphics conversion support:
  - **Standard Mode** - 320×256/320×512, 32 colors from 4096-color palette (5 bitplanes)
  - **HAM6 Mode** - 320×256/320×512, up to 4096 colors via hold-and-modify (6 bitplanes)
  - Native .iff file output (IFF ILBM format)
- **Amiga 1200 Converter** - Full Amiga 1200 AGA graphics conversion support:
  - **Standard Mode** - 320×256/320×512/640×512, 256 colors from 24-bit palette (8 bitplanes)
  - **HAM8 Mode** - 320×256/320×512/640×512, up to 262144 colors via hold-and-modify (8 bitplanes)
  - Native .iff file output (IFF ILBM format)
- **System Menu Update** - Amiga 500 (⇧⌘9), Amiga 1200 (⇧⌘0)
- **Amiga Processing Options**:
  - Dithering: None, Floyd-Steinberg, Atkinson, Noise, Bayer (2×2-16×16), Blue Noise
  - Contrast: None (default), HE, CLAHE, SWAHE
  - Color Matching: Euclidean, Perceptive, Luma, Chroma, Mahalanobis
  - Saturation and Gamma controls

### Technical
- Added `Amiga500Converter.swift` with OCS 4096-color palette and HAM6 encoding
- Added `Amiga1200Converter.swift` with AGA 24-bit palette and HAM8 encoding
- IFF ILBM file format writer with BMHD, CMAP, CAMG, BODY chunks
- Amiga 500 and Amiga 1200 icons added to Assets.xcassets
- Interleaved bitplane encoding for authentic Amiga graphics format

## [3.0] - 2026-01-29

### Added
- **ZX Spectrum Converter** - Full ZX Spectrum graphics conversion support:
  - 256×192 resolution with 8×8 attribute cells
  - 2 colors per attribute cell (ink + paper)
  - 16-color palette (8 colors × 2 brightness levels)
  - Native .scr file output (6912 bytes: 6144 bitmap + 768 attributes)
- **Amstrad CPC Converter** - Full Amstrad CPC graphics conversion support:
  - **Mode 1** - 320×200, 4 colors from 27-color hardware palette
  - **Mode 0** - 160×200, 16 colors from 27-color hardware palette
  - Native .scr file output with AMSDOS header (128 + 16384 bytes)
- **Plus/4 Converter** - Full Commodore Plus/4 graphics conversion support:
  - **HiRes Mode** - 320×200, 2 colors per 8×8 character cell
  - **Multicolor Mode** - 160×200, 4 colors per 4×8 character cell (2 global + 2 per cell)
  - 128-color palette (16 hues × 8 luminance levels)
  - Native .prg file output (10000 bytes: nibble + screen + bitmap)
- **Atari ST Converter** - Full Atari ST graphics conversion support:
  - 320×200 resolution with 16 colors from 512-color palette
  - 512-color hardware palette (8 levels R × 8 levels G × 8 levels B)
  - Native .pi1 file output (DEGAS Elite format, 32034 bytes)
- **System Menu Update** - ZX Spectrum (⇧⌘5), Amstrad CPC (⇧⌘6), Plus/4 (⇧⌘7), Atari ST (⇧⌘8)
- **ZX Spectrum Processing Options**:
  - Dithering: None, Floyd-Steinberg, Atkinson, Noise, Bayer (2×2-16×16), Blue Noise
  - Contrast: None (default), HE, CLAHE, SWAHE
  - Filters: None, Lowpass, Sharpen, Emboss, Edge
  - Color Matching: Euclidean, Perceptive, Luma, Chroma, Mahalanobis
  - Saturation and Gamma controls
- **Amstrad CPC Processing Options**:
  - Same dithering, contrast, filter, and color matching options as ZX Spectrum
  - Pixel Merge option for Mode 0 (Average/Brightest)
- **Plus/4 Processing Options**:
  - Same dithering, contrast, filter, and color matching options as ZX Spectrum
  - Pixel Merge option for Multicolor mode (Average/Brightest)
- **Atari ST Processing Options**:
  - Same dithering, contrast, filter, and color matching options as ZX Spectrum
  - Automatic optimal 16-color palette selection from 512 colors

### Changed
- **UI Redesign** - System selector moved to horizontal bar at top
- **Image Info Panel** - New panel showing file info where system selector was
- **Larger System Icons** - System bar icons increased to 46×90px for better visibility
- **Mode Labels with Resolution** - VIC-20 and C64 mode labels now show resolution:
  - VIC-20: "HiRes (176×184)", "LowRes (88×184)"
  - C64: "HiRes (320×200)", "Multicolor (160×200)"
- **Default Presets** - VIC-20, C64, ZX Spectrum, Amstrad CPC, Plus/4, Atari ST now default to:
  - Contrast: None
  - Dither Amount: 0.5

### Fixed
- **Amstrad CPC Filters** - Implemented missing filter processing (Lowpass, Sharpen, Emboss, Edge)

### Technical
- Added `ZXSpectrumConverter.swift` with attribute-based conversion
- Added `AmstradCPCConverter.swift` with optimal palette selection from 27-color hardware palette
- Added `Plus4Converter.swift` with 128-color TED palette and HiRes/Multicolor modes
- Added `AtariSTConverter.swift` with 512-color palette and DEGAS PI1 output
- ZX Spectrum, Amstrad CPC, Plus/4, and Atari ST icons added to Assets.xcassets
- Added `HorizontalSystemBar` and `ImageInfoPanel` components
- ZX Spectrum interleaved memory format for authentic screen layout
- Amstrad CPC interleaved memory format with AMSDOS file headers
- Plus/4 file format: nibble (1000) + screen (1000) + bitmap (8000) bytes

## [2.9] - 2026-01-29

### Added
- **VIC-20 Converter** - Full VIC-20 graphics conversion support:
  - **HiRes Mode** - 176×184 resolution, 2 colors per 8×8 character cell
  - **LowRes Mode** - 88×184 resolution (double-wide pixels), 4 colors per 4×8 cell
- **System Menu Update** - VIC-20 added (⇧⌘4)
- **VIC-20 Processing Options**:
  - Dithering: None, Floyd-Steinberg, Atkinson, Noise, Bayer (2×2-16×16), Blue Noise
  - Contrast: HE, CLAHE, SWAHE (default: SWAHE)
  - Filters: Lowpass, Sharpen (default), Emboss, Edge
  - Color Matching: Euclidean, Perceptive, Luma, Chroma, Mahalanobis
- **VIC-20 Palette** - Authentic 16-color VIC-20 palette

### Technical
- Added `VIC20Converter.swift` with HiRes and LowRes conversion
- VIC-20 icon added to Assets.xcassets
- Native file format: .prg (VIC-20 executable)
- Screen: 22×23 character cells (506 characters)

### Fixed
- **SWAHE Performance** - Optimized sliding window algorithm with incremental histogram updates (40x faster)

## [2.8] - 2026-01-28

### Added
- **Commodore 64 Converter** - Full C64 graphics conversion support:
  - **HiRes Mode** - 320×200 resolution, 2 colors per 8×8 character cell (Art Studio .art format)
  - **Multicolor Mode** - 160×200 resolution, 4 colors per 4×8 character cell (Koala .kla format)
- **System Menu** - New menu to switch between target systems:
  - Apple II (⇧⌘1)
  - Apple IIgs (⇧⌘2)
  - C64 (⇧⌘3)
- **C64 Dithering Algorithms** - Full set from retropic reference:
  - None, Floyd-Steinberg, Atkinson, Noise
  - Bayer 2×2, 4×4, 8×8, 16×16
  - Blue Noise 8×8, 16×16
- **C64 Contrast Processing** - HE, CLAHE, SWAHE histogram equalization
- **C64 Image Filters** - Lowpass, Sharpen, Emboss, Edge detection
- **C64 Color Matching Algorithms**:
  - Euclidean, Perceptive, Luma-weighted, Chroma-weighted, Mahalanobis
- **C64 Pixel Merge Options** - Average or Brightest for multicolor mode
- **C64 Saturation/Gamma Controls** - Fine-tune image appearance before conversion

### Changed
- **Toolbar Layout** - Reorganized control groups for better C64 options display:
  - Contrast + Filter in one group
  - Pixel Merge + Color Match in another group
- **C64 Palette** - Uses accurate VICE/Pepto palette (16 colors)

### Technical
- Added `C64Converter.swift` with full HiRes and Multicolor conversion
- Added `ConverterViewModel.shared` singleton for menu access
- C64 icon added to Assets.xcassets
- Native file format support: Art Studio (.art) and Koala (.kla)

## [2.7] - 2026-01-25

### Added
- **Preprocessing Filters** - Apply image filters before color conversion:
  - **Median** - Noise reduction with selectable kernel size (3×3, 5×5, 7×7)
  - **Sharpen** - Edge enhancement with adjustable strength (0.2–2.5)
  - **Sigma** - Edge-preserving blur/noise reduction (5–50 range)
  - **Solarize** - Artistic partial negative effect (32–224 threshold)
  - **Emboss** - 3D relief effect with depth control (0.3–2.0)
  - **Find Edges** - Sobel edge detection with sensitivity control (10–100)
- **Filter-Specific Parameters** - Each filter now has its own dedicated control with appropriate range and labeling
- **Help Menu: Preprocessing Filters Section** - Comprehensive documentation for all filters with:
  - Parameter descriptions and ranges
  - Best use cases for each filter
  - Value recommendations
- **Help Menu: Visit GitHub Page** - Quick link to the BitPast GitHub repository
- **Palette Editor Undo/Redo** - Full undo/redo support (⌘Z / ⇧⌘Z) with 50-level history
- **Palette Editor Copy/Paste** - Copy and paste entire palettes between scanlines

### Changed
- **Settings Toolbar Reorganization** - Controls now grouped in vertical pairs:
  - Mode + Resolution + 3200-specific options in first column
  - Dither + Error Matrix + Dither Amount grouped together
  - Preprocessing filter with its parameter below
  - Each group has subtle visual separation for clarity
- **3200 Quantization Visibility** - Now only appears when 3200 Colors mode is selected
- **640x200 Preview Aspect Ratio** - Fixed stretched preview for 640×200 modes (now displays with correct 2:1 aspect correction)
- **Palette Editor Layout** - Fixed heights for header, footer, and button bar to prevent layout compression

### Fixed
- **Preview Aspect Ratio** - 640×200 images no longer appear horizontally stretched in preview
- **Palette Editor Stability** - Header and footer no longer compress when resizing window

## [2.2] - 2026-01-24

### Added
- **Image Tools Toolbar** - New toolbar buttons in the preview area:
  - **Palette Editor** - Edit Apple IIgs palettes directly (IIgs modes only)
  - **H-Flip** - Horizontally flip the converted image
  - **V-Flip** - Vertically flip the converted image
  - **Histogram** - Display RGB/Luma histogram overlay with channel toggles
- **Histogram Channel Toggles** - R, G, B, and Luma (L) buttons to show/hide individual channels
- **Floating Palette Editor Window** - Palette editor now opens as a draggable floating panel instead of a modal sheet, allowing you to see the preview while editing colors
- **Direct Color Picker** - Clicking a palette color now opens the native macOS color panel directly without an intermediate popup

### Changed
- **Retro Theme Support for Toolbar** - All new toolbar buttons and histogram now properly styled for:
  - Apple IIgs theme (GS/OS style with gray background)
  - Apple II theme (green phosphor with Print Char 21 font)
  - Commodore 64 theme (blue background with PetMe64 font)
- **Palette Display Fix** - Non-3200 modes now correctly show the actual number of palettes:
  - 320x200 (16 Colors): 1 palette
  - 640x200 modes: 1 palette
  - 256 Colors (16 Palettes): 16 palettes
  - 3200 Colors (Brooks): 200 palettes
- **Smaller Button Labels** - Apple IIgs theme now uses smaller 8pt text for toolbar button labels

### Fixed
- **Crash Fix** - Fixed "Index out of range" crash when selecting 320x200 mode after palette storage optimization
- **Palette Editor Colors** - Colors now update live as you adjust them in the color picker

### Removed
- **cadius binary** - Removed the external cadius tool; ProDOS disk creation now uses native Swift implementation exclusively

### Technical
- Refactored `ToolbarButton` component with theme-aware styling
- Added `HistogramOverlay`, `HistogramChart`, `HistogramPath`, and `ChannelToggleButton` components
- Added `PaletteEditorWindowController` for floating window management
- Updated `AppleIIGSConverter` to store only unique palettes per mode
