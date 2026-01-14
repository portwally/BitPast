# BitPast Changelog

## [Unreleased] - 2026-01-14

### Fixed
- **Critical: Mode switching bug fixed** - Switching between graphics modes (DHGR, HGR, LGR, DLGR) no longer causes corrupted output. Previously, switching from HGR back to DHGR would result in a dark image rendered in HGR mode instead of DHGR.

### Root Cause
The b2d conversion library uses global variables that persist between calls. When used as a library (not a standalone executable), these variables retained their values from previous conversions, causing mode confusion.

Key issues fixed in `b2d_wrapper.c`:
1. **Wrong variable names** - The wrapper was trying to reset variables that didn't exist (`hgr`, `monochrome`, `dlores`) instead of the actual variables (`hgroutput`, `mono`, `loresoutput`)
2. **grpal palette corruption** - HGR mode permanently modifies the `grpal[]` array (sets 10 of 16 colors to black), which broke subsequent DHGR conversions. Now restored to original values before each conversion.
3. **Memory buffer handling** - Fixed double-free crash by not freeing buffers in wrapper (b2d already frees them at end of each call)
4. **Comprehensive state reset** - Now resets 40+ global variables and clears all buffer arrays before each conversion

### Changed
- **Dither algorithms updated** - Names now match b2d.c exactly:
  - "Jarvis, Judice, Ninke" → "Jarvis"
  - "Sierra-2" → "Sierra Two"
  - "Sierra-Lite" → "Sierra Lite"
  - Added "Buckels" dither algorithm (-D9)

- **Color palettes overhauled** - Corrected palette mappings to match b2d.c indices:
  - "Apple IIgs RGB" → "Kegs32 RGB" (-P0)
  - Added "AppleWin New NTSC" (-P3)
  - Added "Super Convert RGB" (-P12)
  - Added "Jace NTSC" (-P13)
  - Added "Cybernesto NTSC" (-P14)
  - Added "tohgr NTSC HGR" (-P16)
  - Removed non-functional legacy palettes (Legacy Canvas, Legacy Win16, Legacy Win32, Legacy VGA BIOS, Legacy VGA PCX) that displayed as black

### Technical Details

#### Variables Reset Before Each Conversion
- Mode flags: `hgroutput`, `mono`, `lores`, `loresoutput`, `appletop`
- Dither settings: `dither`, `hgrdither`, `dither7`, `errorsum`, `serpentine`, `ditheroneline`, `ditherstart`
- Palette settings: `hgrpaltype`, `hgrcolortype`
- Output flags: `preview`, `vbmp`, `dosheader`, `spritemask`, `tags`, `debug`, `quietmode`, `outputtype`
- Processing flags: `diffuse`, `merge`, `scale`, `reformat`, `applesoft`, `reverse`
- Color settings: `paletteclip`, `globalclip`, `colorbleed`, `bleed`, `backgroundcolor`, `clearcolor`
- And many more...

#### Buffers Cleared
- Dither buffers: `redDither`, `greenDither`, `blueDither`, `redSeed`, `greenSeed`, `blueSeed`, etc.
- HGR buffers: `redSave`, `greenSave`, `blueSave`, `OrangeBlueError`, `GreenVioletError`, etc.
- Scanline buffers: `bmpscanline`, `dibscanline1-4`, `previewline`, `maskline`
- Color arrays: `rgbArray`, `rgbPreview`, `rgbDouble`, `rgbLuma`, etc.
- Palette restoration: `grpal` array restored to original tohgr NTSC values

---

## Available Options

### Target Formats
- DHGR (Double Hi-Res) - 560x192, 16 colors
- HGR (Hi-Res) - 280x192, 6 colors
- LGR (Lo-Res) - 40x48, 16 colors
- DLGR (Double Lo-Res) - 80x48, 16 colors
- Mono - Monochrome output

### Dither Algorithms
| Name | Flag | Description |
|------|------|-------------|
| None | - | No dithering |
| Floyd-Steinberg | -D1 | Classic error diffusion |
| Jarvis | -D2 | Jarvis, Judice, Ninke |
| Stucki | -D3 | Stucki dither |
| Atkinson | -D4 | Bill Atkinson's algorithm (Mac classic) |
| Burkes | -D5 | Burkes dither |
| Sierra | -D6 | Sierra dither |
| Sierra Two | -D7 | Sierra two-row |
| Sierra Lite | -D8 | Sierra lite |
| Buckels | -D9 | Bill Buckels' custom algorithm |

### Color Palettes
| Name | Flag | Description |
|------|------|-------------|
| Kegs32 RGB | -P0 | Apple IIgs emulator colors |
| CiderPress RGB | -P1 | CiderPress file viewer colors |
| AppleWin Old NTSC | -P2 | Legacy AppleWin NTSC |
| AppleWin New NTSC | -P3 | Current AppleWin NTSC |
| Wikipedia NTSC | -P4 | Wikipedia Apple II colors |
| tohgr NTSC (Default) | -P5 | Default for DHGR conversion |
| Super Convert RGB | -P12 | Super Convert colors |
| Jace NTSC | -P13 | Jace emulator colors |
| Cybernesto NTSC | -P14 | Cybernesto/Munafo NTSC |
| tohgr NTSC HGR | -P16 | Optimized for HGR mode |
