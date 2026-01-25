# Changelog

All notable changes to BitPast will be documented in this file.

## [2.3] - 2026-01-25

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
