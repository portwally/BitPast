# BitPast - Retro Graphics Converter

![Platform](https://img.shields.io/badge/platform-macOS-lightgrey)
![Language](https://img.shields.io/badge/language-Swift%20%7C%20C-orange)
![License](https://img.shields.io/badge/license-MIT-blue)

**BitPast** is a modern, native macOS application for converting images into authentic retro computer graphic formats including **Apple II**, **Apple IIgs**, **BBC Micro**, **Commodore 64**, **VIC-20**, **ZX Spectrum**, **Amstrad CPC**, **Plus/4**, **Atari 800**, **Atari ST**, **Amiga 500**, **Amiga 1200**, **IBM PC**, **MSX**, and **TRS-80 Color Computer**.

![Apple IIgs 3200 Color Mode](rsc/screenshot-iigs-dark.png)

![Apple IIgs GS/OS Theme](rsc/screenshot-iigs-light.png)

![Apple II Green Phosphor Theme](rsc/screenshot-apple2.png)

![Commodore 64 Blue Theme](rsc/screenshot-c64.png)

![Palette Editor](rsc/screenshot-palette-editor.png)


## ✨ Features

### 🖥️ Modern macOS Interface
- **Drag & Drop:** Drag multiple images directly from Finder or the web.
- **Batch Processing:** Load dozens of images into a grid browser and process them one by one.
- **Live Preview:** See changes instantly as you adjust sliders for dithering, contrast, and color matching.
- **Zoom & Pan:** Inspect every single pixel with a high-performance zoomable preview.

### 🎨 Supported Systems

#### 🍏 Apple II (8-Bit)
Powered by `b2d`, supporting the full range of classic graphics modes:
- **DHGR** (Double Hi-Res): 140x192 (16 colors) or 560x192 (Monochrome).
- **HGR** (Hi-Res): 280x192 (6 colors).
- **LGR / DLGR**: Lo-Res and Double Lo-Res block graphics.
- **Output:** `.BIN` files ready for hardware.

#### 🌈 Apple IIgs (16-Bit)
Powered by a **native Swift engine** featuring advanced color quantization:
- **3200 Mode (Brooks Format):** Up to 3200 unique colors using per-scanline palettes.
- **256 Colors (16 Palettes):** Standard SHR format with intelligent palette grouping.
- **320x200 (16 Colors):** Classic Super Hi-Res with single palette.
- **640x200 Modes:** 4-color, Enhanced, and Desktop variants.
- **Output:** `.SHR` and `.3200` files.

#### 📺 BBC Micro
Acorn BBC Micro graphics with 8-color palette:
- **Mode 0:** 640×256, 2 colors (high-resolution).
- **Mode 1:** 320×256, 4 colors from 8-color palette.
- **Mode 2:** 160×256, 8 colors (full palette).
- **Mode 4:** 320×256, 2 colors (compact memory).
- **Mode 5:** 160×256, 4 colors (compact memory).
- **8-color fixed palette** (Black, Red, Green, Yellow, Blue, Magenta, Cyan, White).
- **Output:** `.bbc` (raw screen memory).

#### 💾 Commodore 64
Full VIC-II graphics support:
- **HiRes Mode:** 320×200, 2 colors per 8×8 character cell.
- **Multicolor Mode:** 160×200, 4 colors per 4×8 character cell.
- **PETSCII Mode:** 40×25 character-based graphics using PETSCII charset.
- **16-color VICE/Pepto palette.**
- **Output:** `.art` (Art Studio), `.kla` (Koala Painter), `.prg` (PETSCII executable).

#### 📺 VIC-20
Character-based graphics with full color support:
- **HiRes Mode:** 176×184, 2 colors per 8×8 character cell.
- **LowRes Mode:** 88×184, 4 colors per 4×8 cell (double-wide pixels).
- **16-color VIC-20 palette.**
- **Output:** `.prg` (self-displaying executable).

#### 🔲 ZX Spectrum
Attribute-based graphics with authentic color clash:
- **256×192 resolution** with 8×8 attribute cells.
- **2 colors per cell** (ink + paper) from 15-color palette.
- **8 colors × 2 brightness levels.**
- **Output:** `.scr` (6912 bytes: bitmap + attributes).

#### 🖥️ Amstrad CPC
Hardware palette graphics:
- **Mode 1:** 320×200, 4 colors from 27-color palette.
- **Mode 0:** 160×200, 16 colors from 27-color palette.
- **27-color hardware palette** (3 levels R/G/B).
- **Output:** `.scr` with AMSDOS header.

#### 🎮 Commodore Plus/4
TED chip graphics with extended palette:
- **HiRes Mode:** 320×200, 2 colors per 8×8 character cell.
- **Multicolor Mode:** 160×200, 4 colors per 4×8 cell.
- **128-color TED palette** (16 hues × 8 luminance levels).
- **Output:** `.prg` (10,000 bytes: nibble + screen + bitmap).

#### 🕹️ Atari 800
ANTIC/GTIA graphics with 128-color palette:
- **Graphics 8:** 320×192, 2 colors (high-resolution monochrome).
- **Graphics 15:** 160×192, 4 colors from 128-color palette.
- **Graphics 9:** 80×192, 16 shades (GTIA grayscale mode).
- **Graphics 10:** 80×192, 9 colors from 128-color palette (GTIA color mode).
- **Graphics 11:** 80×192, 16 hues at one luminance (GTIA hue mode).
- **128-color palette** (16 hues × 8 luminances).
- **Output:** `.gr8`, `.gr15`, `.gr9`, `.gr10`, `.gr11` (raw graphics).

#### 🖱️ Atari ST
16-bit graphics with 512-color palette:
- **Low Res (320×200):** 16 colors from 512-color palette → .PI1
- **Medium Res (640×200):** 4 colors from 512-color palette → .PI2
- **High Res (640×400):** Monochrome (2 colors) → .PI3
- **512-color hardware palette** (8 levels R × 8 levels G × 8 levels B).
- **Output:** `.pi1`, `.pi2`, `.pi3` (DEGAS Elite format).

#### 🐚 Amiga 500 (OCS/ECS)
Original Chip Set graphics:
- **Standard Mode:** 320×256/320×512, 32 colors from 4096-color palette.
- **HAM6 Mode:** Up to 4096 colors via Hold-And-Modify encoding.
- **Output:** `.iff` (IFF ILBM format).

#### 🚀 Amiga 1200 (AGA)
Advanced Graphics Architecture:
- **Standard Mode:** 320×256/320×512/640×512, 256 colors from 24-bit palette.
- **HAM8 Mode:** Up to 262,144 colors via Hold-And-Modify encoding.
- **Output:** `.iff` (IFF ILBM format).

#### 💻 IBM PC
CGA, EGA, VGA and text mode graphics:
- **CGA Mode:** 320×200, 4 colors from fixed CGA palettes.
- **EGA Mode:** 320×200, 16 colors (fixed or from 64-color palette).
- **VGA Mode 13h:** 320×200, 256 colors from 262,144-color palette.
- **Text Modes:** CGA 80×25 and VESA 132×50 character displays.
- **Output:** `.pcx` (graphics), `.ans` (text/ANSI art).

#### 📺 MSX
TMS9918 and V9938 video chip graphics:
- **Screen 2 (MSX1):** 256×192, 2 colors per 8×1 line from 16-color palette.
- **Screen 5 (MSX2):** 256×212, 16 colors from 512-color palette.
- **Screen 8 (MSX2):** 256×212, 256 fixed colors (3-3-2 RGB).
- **Output:** `.sc2`, `.sc5`, `.sc8` (BSAVE format).

#### 🖥️ TRS-80 Color Computer
MC6847 VDG and GIME chip graphics:
- **PMODE 1:** 128×96, 4 colors from color set.
- **PMODE 2:** 128×192, 2 colors (high-resolution).
- **PMODE 3:** 128×192, 4 colors from color set.
- **PMODE 4:** 256×192, 2 colors (highest CoCo 1/2 resolution).
- **CoCo 3 320×200:** 16 colors from 64-color GIME palette.
- **CoCo 3 640×200:** 4 colors (high-resolution mode).
- **Color sets:** Set 0 (Green/Yellow/Blue/Red), Set 1 (Buff/Cyan/Magenta/Orange), NTSC Artifact.
- **Output:** `.bin` (CoCo 1/2 raw), `.cm3` (CoCo 3 format).

### 🎛️ Fine-Tuning Control

**Processing Options:**
- **Dithering Algorithms:** None, Floyd-Steinberg, Atkinson, Noise, Bayer (2×2 to 16×16), Blue Noise.
- **Contrast Enhancement:** None, HE, CLAHE, SWAHE (adaptive histogram equalization).
- **Color Matching:** Euclidean, Perceptive, Luma, Chroma, Hue, Mahalanobis.
- **Filters:** Lowpass, Sharpen, Emboss, Edge detection.
- **Saturation & Gamma:** Fine-tune color intensity and brightness.

**Preprocessing Filters:**
- **Median:** Noise reduction with selectable kernel size (3×3, 5×5, 7×7).
- **Sharpen:** Edge enhancement with adjustable strength (0.2–2.5).
- **Sigma:** Edge-preserving blur for smoothing gradients (5–50 range).
- **Solarize:** Artistic partial negative effect (32–224 threshold).
- **Emboss:** 3D relief effect with depth control (0.3–2.0).
- **Find Edges:** Sobel edge detection for line-art output (10–100 sensitivity).

### 💾 Export Formats
- **Modern Previews:** Export as PNG, JPG, GIF, or TIFF for web use.
- **Native Formats:** Each system exports its authentic file format.
- **Virtual Disk Images:** Create disk images for ALL supported systems:

| System | Formats | Sizes |
|--------|---------|-------|
| Apple II/IIgs | .PO, .2MG, .HDV | 140KB, 800KB, 32MB |
| Commodore 64/VIC-20/Plus4 | .D64, .D71, .D81 | 170KB, 340KB, 800KB |
| Amiga 500/1200 | .ADF | 880KB, 1.76MB |
| Atari 800 | .ATR | 90KB, 130KB, 180KB, 360KB |
| Atari ST | .ST | 360KB, 720KB, 1.44MB |
| BBC Micro | .SSD, .DSD | 100KB, 200KB, 400KB |
| MSX | .DSK | 360KB, 720KB |
| Amstrad CPC | .DSK | 180KB, 360KB |
| ZX Spectrum | .TRD, .DSK | 640KB, 180KB |
| PC | .IMG | 360KB, 720KB, 1.2MB, 1.44MB |
| TRS-80 CoCo | .DSK | 180KB, 360KB |

## 🚀 How to Use

1. **Drag Images** into the left "Image Browser" panel.
2. Select an image to preview it.
3. Choose your **System** from the horizontal bar at the top (Apple II, Apple IIgs, BBC Micro, C64, VIC-20, ZX Spectrum, Amstrad CPC, Plus/4, Atari 800, Atari ST, Amiga 500, Amiga 1200, PC, MSX, TRS-80 CoCo).
4. Select the **Mode** and tweak **Dither**, **Contrast**, and other settings.
5. Click **Export** in the bottom right corner.
   - Choose **PNG/JPG** for a visual preview.
   - Choose **Native Format** to save the raw file for the target system.
   - Choose **Create Disk** to package converted files onto a virtual disk image for any system.

## 🛠️ Technical Details

BitPast is built with **Swift** and **SwiftUI** for macOS.

- **Frontend:** SwiftUI (Grid Views, HSplitView, Combine for debounced live previews).
- **Backend (Apple II):** `b2d` (modified build with struct packing fixes for modern macOS ARM64/x86_64).
- **Backend (All Others):** Native Swift implementations with authentic format output.
- **Disk Operations:** Native Swift implementation for ProDOS volume creation and file management.

## 📦 Installation

### From Source
1. Clone the repository.
2. Open `BitPast.xcodeproj` in Xcode.
3. Build and Run (Requires macOS 12.0+).

### From Binary Release

Since this app is not distributed through the official Apple App Store and may not have been notarized by a paid Apple Developer Account, macOS might display a security warning upon the first launch.

You may see a message stating: "The app cannot be opened because it is from an unverified developer."

How to bypass this warning (one-time process):

1. Close the warning window.
2. Go to the app in Finder (e.g., in your Applications Folder).
3. Hold the Control key and click on the app icon (or use the Right-Click menu).
4. Select Open from the context menu.
5. In the subsequent dialog box, confirm that you want to open the app by clicking Open again.
6. The application will now launch and will be trusted by macOS for all future starts.

If this does not work then:
1. Open Terminal (Applications → Utilities → Terminal)
2. Run the following command (if installed in Applications):<br>
```xattr -cr /Applications/BitPast.app```


## 👏 Credits

- **Bill Buckels**: For creating the original **b2d** (Bmp2DHR) command-line tool. [Visit AppleOldies.ca](https://www.appleoldies.ca/bmp2dhr/).


## 📄 License

This project is open source. The UI code is provided under the MIT License.



[![Downloads](https://img.shields.io/github/downloads/portwally/BitPast/total?style=flat&color=0d6efd)](https://github.com/portwally/BitPast/releases)
[![Stars](https://img.shields.io/github/stars/portwally/BitPast?style=flat&color=f1c40f)](https://github.com/portwally/BitPast/stargazers)
[![Forks](https://img.shields.io/github/forks/portwally/BitPast?style=flat&color=2ecc71)](https://github.com/portwally/BitPast/network/members)


