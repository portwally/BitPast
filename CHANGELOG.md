# Changelog

All notable changes to BitPast will be documented in this file.

## [Unreleased] - 2026-01-24

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
