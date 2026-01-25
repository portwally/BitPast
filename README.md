# BitPast - Apple II Graphics Converter


![Platform](https://img.shields.io/badge/platform-macOS-lightgrey)
![Language](https://img.shields.io/badge/language-Swift%20%7C%20C-orange)
![License](https://img.shields.io/badge/license-MIT-blue)

**BitPast** is a modern, native macOS application for converting images into authentic **Apple II** and **Apple IIgs** graphic formats.


<img width="1309" height="876" alt="Bildschirmfoto 2025-12-21 um 04 02 10" src="https://github.com/user-attachments/assets/09703f9b-8439-4207-8cbb-4a5495b6b18a" />

<img width="1309" height="876" alt="Bildschirmfoto 2025-12-21 um 04 01 44" src="https://github.com/user-attachments/assets/1dc4d534-9914-4349-b0d6-98cd4711dc81" />


## ✨ Features

### 🖥️ Modern macOS Interface
- **Drag & Drop:** Drag multiple images directly from Finder or the web.
- **Batch Processing:** Load dozens of images into a grid browser and process them one by one.
- **Live Preview:** See changes instantly as you adjust sliders for dithering, crosshatch, or color bleed.
- **Zoom & Pan:** Inspect every single pixel with a high-performance zoomable preview.

### 🎨 Powerful Conversion Engines

#### 🍏 Apple II (8-Bit)
Powered by `b2d`, supporting the full range of classic graphics modes:
- **DHGR** (Double Hi-Res): 140x192 (16 colors) or 560x192 (Monochrome).
- **HGR** (Hi-Res): 280x192 (6 colors).
- **LGR / DLGR**: Lo-Res and Double Lo-Res block graphics.
- **Color & Monochrome**: Fully supported with optimized rendering.

#### 🌈 Apple IIgs (16-Bit)
Powered by a **native Swift engine** featuring advanced color quantization:
- **3200 Mode (Smart Scanlines):** Uses **Median Cut Quantization** and intelligent scanline clustering to utilize all 16 palettes simultaneously. This allows for near-photorealistic images by dynamically assigning specific palettes to different vertical sections of the image.
- **Standard Modes:** 320x200 (16 colors) and 640x200 (4 colors).
- **Color Accuracy:** Full utilization of the Apple IIgs 12-bit RGB color space (4096 colors).

### 🎛️ Fine-Tuning Control

**General:**
- **Dithering Algorithms:** Floyd-Steinberg, Atkinson, Jarvis-Judice-Ninke, Stucki, Burkes, and Ordered (Bayer 4x4).
- **Smart Scaling:** Automatically maps input resolutions (like 640x480 VGA) to safe resolutions to prevent artifacts.

**Apple II Specific:**
- **Crosshatch Threshold:** Simulate monitor scanline effects.
- **Color Bleed Reduction:** Clean up NTSC artifacts for sharper images.
- **Palettes:** Over 15 historic palettes (Standard, NTSC simulation, RGB, Greyscale, etc.).

**Apple IIgs Specific:**
- **Merge Tolerance:** Controls how aggressively scanlines are clustered in 3200 mode.
- **Saturation Boost:** Compensates for the limited 4-bit color depth to make images "pop".
- **Gamma Correction:** Adjust brightness distribution for retro CRTs.

### 💾 Export Formats
- **Modern Previews:** Export as PNG, JPG, GIF, or TIFF for web use.
- **Native Binaries:** - **Apple II:** `.BIN` (binary dumps) ready for hardware.
  - **Apple IIgs:** `.SHR` (Super Hi-Res, Type $C1) compatible with GS Paint and generic loaders.
- **ProDOS Disk Images:** Create bootable `.PO`, `.2MG`, or `.HDV` disk images directly from the app.

## 🚀 How to Use

1. **Drag Images** into the left "Image Browser" panel.
2. Select an image to preview it.
3. Choose your **System** (Apple II or Apple IIgs).
4. Tweak the **Mode**, **Dither**, and **Sliders** until the Live Preview looks perfect.
5. Click **Export** in the bottom right corner.
   - Choose **PNG/JPG** for a visual preview.
   - Choose **Native Format** to save the raw file (`.BIN` / `.SHR`).
   - Choose **Create ProDOS Disk** to package the file onto a disk image.

## 🛠️ Technical Details

BitPast is built with **Swift** and **SwiftUI** for macOS.

- **Frontend:** SwiftUI (Grid Views, HSplitView, Combine for debounced live previews).
- **Backend (Apple II):** `b2d` (modified build with struct packing fixes for modern macOS ARM64/x86_64 architecture).
- **Backend (Apple IIgs):** Native Swift implementation using Median Cut algorithm and Euclidean distance scanline clustering.
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

Close the warning window.
Go to the app in Finder (e.g., in your Applications Folder).
Hold the Control key and click on the app icon (or use the Right-Click menu).
Select Open from the context menu.
In the subsequent dialog box, confirm that you want to open the app by clicking Open again.
The application will now launch and will be trusted by macOS for all future starts.
If this does not work then
1. Open Terminal
You can find it in:
Applications → Utilities → Terminal
2. Run the following command (in case you installed it in the Applications directory):<br>
```xattr -cr /Applications/BitPast.app```


## 👏 Credits

- **Bill Buckels**: For creating the original **b2d** (Bmp2DHR) command-line tool. [Visit AppleOldies.ca](https://www.appleoldies.ca/bmp2dhr/).


## 📄 License

This project is open source. The UI code is provided under the MIT License.



[![Downloads](https://img.shields.io/github/downloads/portwally/BitPast/total?style=flat&color=0d6efd)](https://github.com/portwally/BitPast/releases)
[![Stars](https://img.shields.io/github/stars/portwally/BitPast?style=flat&color=f1c40f)](https://github.com/portwally/BitPast/stargazers)
[![Forks](https://img.shields.io/github/forks/portwally/BitPast?style=flat&color=2ecc71)](https://github.com/portwally/BitPast/network/members)



