# BitPast - Apple II Graphics Converter

![Platform](https://img.shields.io/badge/platform-macOS-lightgrey)
![Language](https://img.shields.io/badge/language-Swift%20%7C%20C-orange)
![License](https://img.shields.io/badge/license-MIT-blue)

**BitPast** is a modern, native macOS application for converting images into authentic **Apple II** graphic formats.

It acts as a powerful GUI wrapper around the legendary [b2d](https://www.appleoldies.ca/bmp2dhr/) tool by Bill Buckels, bringing drag-and-drop simplicity, live previews, and batch processing to retro graphics conversion.

![App Screenshot](screenshots/main_app.png)

## ✨ Features

### 🖥️ Modern macOS Interface
- **Drag & Drop:** Drag multiple images directly from Finder or the web.
- **Batch Processing:** Load dozens of images into a grid browser and process them one by one.
- **Live Preview:** See changes instantly as you adjust sliders for dithering, crosshatch, or color bleed.
- **Zoom & Pan:** Inspect every single pixel with a high-performance zoomable preview.

### 🎨 Powerful Conversion Engine
Powered by `b2d`, BitPast supports the full range of Apple II graphics modes:
- **DHGR** (Double Hi-Res): 140x192 (16 colors) or 560x192 (Monochrome).
- **HGR** (Hi-Res): 280x192 (6 colors).
- **LGR / DLGR**: Lo-Res and Double Lo-Res block graphics.
- **Color & Monochrome**: Fully supported with optimized rendering.

### 🎛️ Fine-Tuning Control
- **Dithering Algorithms:** Floyd-Steinberg, Atkinson (MacPaint style), Jarvis, Stucki, Sierra-Lite.
- **Palettes:** Includes over 15 palettes (Standard, NTSC simulation, RGB, Greyscale, etc.).
- **Smart Scaling:** Automatically maps input resolutions (like 640x480 VGA) to Apple II safe resolutions to prevent artifacts.
- **Effects:**
  - **Crosshatch Threshold:** Simulate monitor scanline effects.
  - **Color Bleed Reduction:** Clean up artifacts for sharper images.

### 💾 Export Formats
- **Modern Previews:** Export as PNG, JPG, GIF, or BMP for web use.
- **Native Binaries:** Exports actual Apple II files (`.BIN`, `.AUX`, `.A2FC`) ready to be loaded onto real hardware or emulators (like AppleWin or Virtual II).

## 🚀 How to Use

1. **Drag Images** into the left "Image Browser" panel.
2. Select an image to preview it.
3. Choose your **Target System** (Apple II) and **Format** (e.g., DHGR).
4. Tweak the **Dither**, **Palette**, and **Sliders** until the Live Preview looks perfect.
5. Click **Export** in the bottom right corner.
   - Choose **PNG** for a visual preview.
   - Choose **Apple II Binary** to generate the raw files for your retro hardware.

## 🛠️ Technical Details

BitPast is built with **Swift** and **SwiftUI** for macOS. It embeds a compiled version of the C-based `b2d` tool.

- **Frontend:** SwiftUI (Grid Views, HSplitView, Combine for debounced live previews).
- **Backend:** `b2d` (modified build with struct packing fixes for modern macOS ARM64/x86_64 architecture).
- **Pipeline:** BitPast handles high-quality pre-scaling using CoreGraphics before passing the data to `b2d` for the final retro conversion.

## 📦 Installation

### From Source
1. Clone the repository.
2. Open `BitPast.xcodeproj` in Xcode.
3. Ensure the `b2d` binary is present in the project bundle resources.
4. Build and Run (Requires macOS 12.0+).

## 👏 Credits

- **Bill Buckels**: For creating the original **b2d** (Bmp2DHR) command-line tool, which performs the core conversion magic. [Visit AppleOldies.ca](https://www.appleoldies.ca/bmp2dhr/).
- **Digarok**: For **Buckshot**, which served as inspiration for the resolution handling logic.

## 📄 License

This project is open source. The UI code is provided under the MIT License. The bundled `b2d` binary follows the original license by Bill Buckels (Royalty-free use/modification allowed).
