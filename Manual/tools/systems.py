"""The fifteen system sections: facts from the app's option lists, in-app Help and measured output files."""
from lib import *

HELPKEY = {"AppleII": "AppleII", "AppleIIGS": "AppleIIgs", "Amiga500": "Amiga500", "Amiga1200": "Amiga1200", "AmstradCPC": "AmstradCPC",
           "Atari800": "Atari800", "AtariST": "AtariST", "BBCMicro": "BBCMicro", "C64": "C64", "MSX": "MSX", "PC": "PC", "Plus4": "Plus4",
           "TRS80CoCo": "TRS80CoCo", "VIC20": "VIC20", "ZXSpectrum": "ZXSpectrum"}
ORDER = ["AppleII", "AppleIIGS", "Amiga500", "Amiga1200", "AmstradCPC", "Atari800", "AtariST", "BBCMicro", "C64", "MSX", "PC", "Plus4", "TRS80CoCo", "VIC20", "ZXSpectrum"]
VARIES = {"iff", "pcx", "ans"}

def fact(machine, index):
    for f in FACTS:
        if f["machine"] == machine and f["index"] == index:
            return f
    raise KeyError((machine, index))

def clean(s):
    return s.replace('\\"', '"')

def file_info(machine, index, override=None):
    f = fact(machine, index)
    a = f["assets"][0]
    ext = "." + a["ext"].upper() if a["ext"].isupper() else "." + a["ext"]
    if a["ext"] in ("shr", "scr", "iff", "pcx", "ans", "prg", "bin", "bbc", "kla", "art", "cm3"):
        ext = "." + a["ext"].upper() if machine in ("AppleIIGS",) else "." + a["ext"]
    size = override or ("varies" if a["ext"] in VARIES else f'{a["bytes"]:,} bytes')
    return ext, size

# Screen size and colours for every mode, in the order of the app's Mode pop-up menu.
SYSTEMS = {
 "AppleII": dict(
    name="Apple II", year="1977", chip="NTSC artifact colour · converted with b2d",
    intro=["The Apple II makes its colours in a way no other computer does: colour comes from where a dot lands on the NTSC television signal, so what you see depends on the pattern of the dots. BitPast converts Apple II pictures with __b2d__ (BMP2DHR), Bill Buckels’ converter, which is built into the app and understands this artifact colour.",
           "Choose the screen format with **Target Format** and the size of the working bitmap with **Output Resolution**. The Apple II is the one system whose settings differ from all the others: b2d brings its own error-diffusion methods, ten colour tables and three tuning sliders."],
    modes=[
      dict(label="DHGR (Double Hi-Res)", res="140×192 colour pixels (560 dots)", col="16", fact=0,
           desc="Double Hi-Res uses both banks of the Apple II’s memory and shows 16 colours. Each colour pixel is four dots wide; the picture has 140 of them across, with the dots in between available for fine shading.",
           best="Photographs and artwork on a machine with 128 KB: an Apple IIe, IIc or IIgs.", tips=["Floyd-Steinberg is recommended for photographs. Choose 560×384 as Output Resolution for the best result."]),
      dict(label="HGR (Hi-Res)", res="280×192", col="6", fact=1,
           desc="Hi-Res is the classic Apple II graphics mode: 280×192 dots and six colours (black, white, green, violet, orange and blue). The colours come from the horizontal position of each dot and from the dot patterns next to it.",
           best="Classic Apple II graphics, games, and artwork that needs an authentic period look.", tips=["Error diffusion works well; Floyd-Steinberg is recommended for photographs."]),
      dict(label="LGR (Lo-Res)", res="40×48 blocks", col="16", fact=2,
           desc="Lo-Res is the Apple II’s block graphics: 40 by 48 coloured blocks, each one of 16 colours. The picture is tiny and chunky, and instantly recognisable.",
           best="Chunky, abstract pictures; the smallest Apple II files.", tips=[]),
      dict(label="DLGR (Double Lo-Res)", res="80×48 blocks", col="16", fact=3,
           desc="Double Lo-Res doubles the number of blocks across the screen to 80, using the second memory bank of a 128 KB machine.",
           best="A little more detail than Lo-Res, in the same blocky style.", tips=[]),
      dict(label="Mono (Monochrome)", res="560×192 or 280×192", col="2 (black and white)", fact=4,
           desc="Black and white only. With a 560×384 working bitmap BitPast writes a double hi-res monochrome picture (560×192 dots, {{.A2FM}}); with 280×192 it writes an ordinary hi-res monochrome picture ({{.BIN}}).",
           best="Line art, text and pictures that should look like a green-screen or black-and-white monitor.", tips=[], extra_facts=[5]),
    ],
    settings_note="The Apple II list is different from the others. **Dither Algo** offers b2d’s nine error-diffusion methods (the choice of ordered dithers is not available), **Palette** chooses which table of NTSC and RGB colours is used to display and judge the colours — the default is __tohgr NTSC__ — and the three sliders are passed straight to b2d: **Cross-hatch Pattern** (0 turns it off), **Cross-hatch Threshold** and **Error Matrix Index**. Leave them alone unless you want to experiment; the b2d documentation by Bill Buckels describes them in detail.",
    gallery=[("m-AppleII-0", "DHGR"), ("m-AppleII-1", "HGR"), ("m-AppleII-2", "LGR"), ("m-AppleII-3", "DLGR"), ("m-AppleII-4", "Mono (560×192)"), ("m-AppleII-5", "Mono (280×192)")],
 ),
 "AppleIIGS": dict(
    name="Apple IIgs", year="1986", chip="Super Hi-Res · up to 3,200 colours",
    intro=["The Apple IIgs shows pictures on its Super Hi-Res screen: 320×200 pixels with 16 colours chosen from 4,096, or 640×200 pixels with 4. The hardware can change palette from line to line. A __scan control byte__ (SCB) for each of the 200 lines picks one of 16 stored palettes — and the Brooks 3,200-colour format goes further and stores a full palette for every line, so a single picture can show 3,200 colours.",
           "The IIgs converter is written natively in Swift. It is the only one with a palette editor (Chapter 7) and the only one with an extra choice of how palettes are shared between lines: **SCB Mode**."],
    modes=[
      dict(label="3200 Colors (Brooks)", res="320×200", col="3,200 (16 per line)", fact=0, help=0),
      dict(label="256 Colors (16 Palettes)", res="320×200", col="256 (16 palettes of 16)", fact=1, help=1),
      dict(label="320x200 (16 Colors)", res="320×200", col="16", fact=2, help=2),
      dict(label="640x200 (4 Colors)", res="640×200", col="4", fact=3, help=3),
      dict(label="640x200 Enhanced (16 Colors)", res="640×200", col="16 (8 effective)", fact=4, help=4),
      dict(label="640x200 Desktop (16 Colors)", res="640×200", col="GS/OS Finder colours", fact=5, help=5),
    ],
    settings_note="**3200 Quantization** applies to the 3,200-colour mode: __Per-Scanline__ builds a new palette for every line, __Palette Reuse__ lets a line keep the previous line’s palette when it fits well enough (see **Palette Merge Tolerance**), which reduces banding where neighbouring lines are alike. **SCB Mode** applies to the 256-colour mode and is explained below. **Preprocessing** offers the seven filters described in Chapter 5.",
    gallery=[("m-AppleIIGS-0", "3200 Colors"), ("m-AppleIIGS-1", "256 Colors (Per-Line)"), ("m-AppleIIGS-2", "320×200, 16 colors"),
             ("m-AppleIIGS-3", "640×200, 4 colors"), ("m-AppleIIGS-4", "640×200 Enhanced"), ("m-AppleIIGS-5", "640×200 Desktop")],
 ),
 "Amiga500": dict(
    name="Amiga 500", year="1987", chip="OCS/ECS · 32 colours · HAM6",
    intro=["The Amiga 500’s Original Chip Set shows up to 32 colours at a time, chosen from a palette of 4,096 (16 levels each of red, green and blue). Its famous trick is __HAM6__, “hold and modify”: each pixel either takes a colour from a small palette or changes one colour component of the pixel to its left, which puts all 4,096 colours on one screen.",
           "BitPast saves standard IFF/ILBM pictures, the format Amiga painting programs and emulators load. The picture is 320 pixels wide and either 256 lines high (the PAL screen) or 512 lines (interlaced)."],
    modes=[dict(label="Standard (32 colors)", res="320×256 or 320×512", col="32 of 4,096", fact=0, help=0),
           dict(label="HAM6 (4096 colors)", res="320×256 or 320×512", col="4,096", fact=1, help=1)],
    gallery=[("m-Amiga500-0", "Standard (32 colors)"), ("m-Amiga500-1", "HAM6 (4096 colors)")],
 ),
 "Amiga1200": dict(
    name="Amiga 1200", year="1992", chip="AGA · 256 colours · HAM8",
    intro=["The Amiga 1200’s Advanced Graphics Architecture lifts the palette to 24 bits (16.7 million colours) and the number of colours on screen to 256. HAM8, the improved hold-and-modify mode, can show 262,144 colours at once with six bits for each colour component.",
           "Choose between three screen sizes with **Resolution**: 320×256, 320×512 (interlaced) and 640×512 (high-resolution interlaced)."],
    modes=[dict(label="Standard (256 colors)", res="320×256, 320×512 or 640×512", col="256 of 16.7 million", fact=0, help=0),
           dict(label="HAM8 (262144 colors)", res="320×256, 320×512 or 640×512", col="262,144", fact=1, help=1)],
    gallery=[("m-Amiga1200-0", "Standard (256 colors)"), ("m-Amiga1200-1", "HAM8 (262144 colors)")],
 ),
 "AmstradCPC": dict(
    name="Amstrad CPC", year="1984", chip="Gate Array · 27-colour palette",
    intro=["The Amstrad CPC has a hardware palette of 27 colours (three levels each of red, green and blue). In Mode 1, four of them are on screen at once at 320×200. In Mode 0, sixteen are on screen at 160×200, with pixels twice as wide. BitPast chooses the best four or sixteen colours for each picture.",
           "Files are written with an AMSDOS header, which is what lets them load from a CPC disk image."],
    modes=[dict(label="Mode 1 (320×200, 4 colors)", res="320×200", col="4 of 27", fact=0, help=0),
           dict(label="Mode 0 (160×200, 16 colors)", res="160×200", col="16 of 27", fact=1, help=1)],
    gallery=[("m-AmstradCPC-0", "Mode 1"), ("m-AmstradCPC-1", "Mode 0")],
 ),
 "Atari800": dict(
    name="Atari 800", year="1979", chip="ANTIC/GTIA · 128-colour palette",
    intro=["The Atari 800’s ANTIC and GTIA chips have a palette of 128 colours: 16 hues, each in 8 levels of brightness. The five modes BitPast offers have very different characters. Graphics 8 is a sharp two-colour mode (both colours are shades of one hue, as on the real hardware). Graphics 15 gives four colours in double-wide pixels. The three GTIA modes — 9, 10 and 11 — trade resolution (only 80 pixels across) for 16 shades, nine colours or 16 hues."],
    modes=[dict(label="Graphics 8 (320×192, 2 colors)", res="320×192", col="2", fact=0, help=0),
           dict(label="Graphics 15 (160×192, 4 colors)", res="160×192", col="4 of 128", fact=1, help=1),
           dict(label="Graphics 9 (80×192, 16 shades)", res="80×192", col="16 shades", fact=2, help=2),
           dict(label="Graphics 10 (80×192, 9 colors)", res="80×192", col="9 of 128", fact=3, help=3),
           dict(label="Graphics 11 (80×192, 16 hues)", res="80×192", col="16 hues", fact=4, help=4)],
    gallery=[("m-Atari800-0", "Graphics 8"), ("m-Atari800-1", "Graphics 15"), ("m-Atari800-2", "Graphics 9"), ("m-Atari800-3", "Graphics 10"), ("m-Atari800-4", "Graphics 11")],
 ),
 "AtariST": dict(
    name="Atari ST", year="1985", chip="Shifter · 512-colour palette",
    intro=["The Atari ST’s palette has 512 colours (eight levels each of red, green and blue). Low resolution shows 16 of them at 320×200, medium resolution shows 4 at 640×200, and high resolution is black and white at 640×400 on the ST’s monochrome monitor. BitPast saves DEGAS Elite pictures (.PI1, .PI2, .PI3).",
           "Medium resolution is a good place to see what **Aspect** does: its pixels are very tall, so a picture placed with Fit set to Contain looks quite different with Aspect set to Correct or Ignore (Chapter 4)."],
    modes=[dict(label="Low Res (320×200)", res="320×200", col="16 of 512", fact=0, help=0),
           dict(label="Medium Res (640×200)", res="640×200", col="4 of 512", fact=1, help=1),
           dict(label="High Res (640×400)", res="640×400", col="2 (black and white)", fact=2, help=2)],
    gallery=[("m-AtariST-0", "Low Res"), ("m-AtariST-1", "Medium Res"), ("m-AtariST-2", "High Res")],
 ),
 "BBCMicro": dict(
    name="BBC Micro", year="1981", chip="6845 CRTC · 8 colours",
    intro=["The BBC Micro has eight fixed colours — black, red, green, yellow, blue, magenta, cyan and white. How many are on screen at once, and at what resolution, depends on the mode. Mode 0 gives two colours at 640×256, Mode 1 four at 320×256, Mode 2 all eight at 160×256, and Modes 4 and 5 are the half-memory versions of Modes 1 and 2. BitPast writes the raw screen memory ({{.bbc}})."],
    modes=[dict(label="Mode 0 (640×256, 2 colors)", res="640×256", col="2 of 8", fact=0, help=0),
           dict(label="Mode 1 (320×256, 4 colors)", res="320×256", col="4 of 8", fact=1, help=1),
           dict(label="Mode 2 (160×256, 8 colors)", res="160×256", col="8", fact=2, help=2),
           dict(label="Mode 4 (320×256, 2 colors)", res="320×256", col="2 of 8", fact=3, help=3),
           dict(label="Mode 5 (160×256, 4 colors)", res="160×256", col="4 of 8", fact=4, help=4)],
    gallery=[("m-BBCMicro-0", "Mode 0"), ("m-BBCMicro-1", "Mode 1"), ("m-BBCMicro-2", "Mode 2"), ("m-BBCMicro-3", "Mode 4"), ("m-BBCMicro-4", "Mode 5")],
 ),
 "C64": dict(
    name="Commodore 64", year="1982", chip="VIC-II · 16 colours",
    intro=["Commodore 64 pictures follow the rules of the VIC-II chip. In HiRes mode every 8×8 cell of the picture may use two colours. In Multicolor mode every 4×8 cell may use four: three chosen for that cell and a background colour shared by the whole picture. The palette has 16 colours (the well-known Pepto palette).",
           "BitPast saves Art Studio ({{.art}}) for HiRes, Koala Painter ({{.kla}}) for Multicolor and, for PETSCII, a program ({{.prg}}) that shows the picture when you run it."],
    modes=[dict(label="HiRes (320×200)", res="320×200", col="2 per 8×8 cell", fact=0, help=0),
           dict(label="Multicolor (160×200)", res="160×200", col="4 per 4×8 cell", fact=1, help=1),
           dict(label="PETSCII (40×25)", res="40×25 characters", col="16 (2 per cell)", fact=2, help=2, size="varies")],
    gallery=[("m-C64-0", "HiRes"), ("m-C64-1", "Multicolor"), ("m-C64-2", "PETSCII")],
 ),
 "MSX": dict(
    name="MSX", year="1983", chip="TMS9918 · V9938",
    intro=["MSX computers come in two generations of video chip. Screen 2 is the MSX1 mode of the TMS9918: 256×192 pixels, two colours in every 8-pixel stretch of a line, from a fixed palette of 16. Screens 5 and 8 belong to the MSX2’s V9938. Screen 5 shows 16 colours chosen from 512, and Screen 8 shows 256 fixed colours. Files are written in BSAVE format ({{.sc2}}, {{.sc5}}, {{.sc8}})."],
    modes=[dict(label="Screen 2 (MSX1)", res="256×192", col="2 per 8×1 stretch (16 fixed)", fact=0, help=0),
           dict(label="Screen 5 (MSX2)", res="256×212", col="16 of 512", fact=1, help=1),
           dict(label="Screen 8 (MSX2)", res="256×212", col="256 fixed (3-3-2 RGB)", fact=2, help=2)],
    gallery=[("m-MSX-0", "Screen 2"), ("m-MSX-1", "Screen 5"), ("m-MSX-2", "Screen 8")],
 ),
 "PC": dict(
    name="IBM PC", year="1981", chip="CGA · EGA · VGA · text modes",
    intro=["The PC section covers the graphics standards that followed one another on DOS machines: CGA with four colours, EGA with 16, VGA with 256, and two text modes for ANSI art. Graphics modes are saved as PC Paintbrush ({{.pcx}}) pictures and text modes as ANSI files ({{.ans}}).",
           "With the CGA mode, **CGA Palette** picks one of four fixed sets of three colours (plus black). With the EGA modes you can choose between the fixed 16 colours of the standard palette and 16 chosen from the full set of 64."],
    modes=[dict(label="CGA (4 colors)", res="320×200", col="4 (fixed palettes)", fact=0, help=0),
           dict(label="EGA (16 colors)", res="320×200", col="16 (fixed)", fact=1, help=1),
           dict(label="EGA 64 (16 from 64)", res="320×200", col="16 of 64", fact=2, help=2),
           dict(label="VGA (256 colors)", res="320×200", col="256 of 262,144", fact=3, help=3),
           dict(label="CGA 80×25 Text", res="80×25 characters (640×200)", col="16 + 8 per cell", fact=4, help=4),
           dict(label="VESA 132×50 Text", res="132×50 characters (1056×400)", col="16 + 8 per cell", fact=5, help=5)],
    gallery=[("m-PC-0", "CGA"), ("m-PC-1", "EGA"), ("m-PC-2", "EGA 64"), ("m-PC-3", "VGA"), ("m-PC-4", "CGA 80×25 Text"), ("m-PC-5", "VESA 132×50 Text")],
 ),
 "Plus4": dict(
    name="Commodore Plus/4", year="1984", chip="TED · 128-colour palette",
    intro=["The Plus/4’s TED chip has a palette of 128 colours: 16 hues, each in 8 levels of brightness. Like the Commodore 64 it works in cells: 8×8 cells with two colours in HiRes mode, and 4×8 cells with four colours in Multicolor mode — but with far more colours to choose from. Pictures are saved as {{.prg}} programs."],
    modes=[dict(label="HiRes (320×200)", res="320×200", col="2 per 8×8 cell (of 128)", fact=0, help=0),
           dict(label="Multicolor (160×200)", res="160×200", col="4 per 4×8 cell (of 128)", fact=1, help=1)],
    gallery=[("m-Plus4-0", "HiRes"), ("m-Plus4-1", "Multicolor")],
 ),
 "TRS80CoCo": dict(
    name="TRS-80 Color Computer", year="1980", chip="MC6847 VDG · GIME",
    intro=["The Color Computer’s original video chip, the MC6847, works with a handful of fixed colours in modes the BASIC programmer knows as PMODE 1 to 4. The CoCo 3 added the GIME chip, with 320×200 pictures in 16 colours and 640×200 pictures in 4, chosen from a palette of 64.",
           "For the four-colour PMODEs, **Color Set** picks one of two fixed sets of colours, or the NTSC artifact colours that appear on a composite monitor with the high-resolution two-colour mode."],
    modes=[dict(label="PMODE 3 (128×192, 4 colors)", res="128×192", col="4 (colour set)", fact=0, help=0),
           dict(label="PMODE 4 (256×192, 2 colors)", res="256×192", col="2 (+ artifact)", fact=1, help=1),
           dict(label="PMODE 1 (128×96, 4 colors)", res="128×96", col="4 (colour set)", fact=2, help=2),
           dict(label="PMODE 2 (128×192, 2 colors)", res="128×192", col="2", fact=3, help=3),
           dict(label="CoCo 3 (320×200, 16 colors)", res="320×200", col="16 of 64", fact=4, help=4),
           dict(label="CoCo 3 (640×200, 4 colors)", res="640×200", col="4 of 64", fact=5, help=5)],
    gallery=[("m-TRS80CoCo-0", "PMODE 3"), ("m-TRS80CoCo-1", "PMODE 4"), ("m-TRS80CoCo-2", "PMODE 1"), ("m-TRS80CoCo-3", "PMODE 2"),
             ("m-TRS80CoCo-4", "CoCo 3 320×200"), ("m-TRS80CoCo-5", "CoCo 3 640×200")],
 ),
 "VIC20": dict(
    name="VIC-20", year="1980", chip="VIC · 16 colours",
    intro=["The VIC-20 builds its pictures from a custom character set: the screen is 22 by 23 characters, each 8 pixels high. HiRes mode gives two colours per 8×8 cell at 176×184 pixels. LowRes is the VIC-20’s multicolor mode, with double-wide pixels (88×184) and four colours per cell: background, border, auxiliary and one chosen for the cell. Files are {{.prg}} programs that show the picture when you run them."],
    modes=[dict(label="HiRes (176×184)", res="176×184", col="2 per 8×8 cell", fact=0, help=0, size="varies"),
           dict(label="LowRes (88×184)", res="88×184", col="4 per cell", fact=1, help=1, size="varies")],
    gallery=[("m-VIC20-0", "HiRes"), ("m-VIC20-1", "LowRes")],
 ),
 "ZXSpectrum": dict(
    name="ZX Spectrum", year="1982", chip="ULA · 15 colours",
    intro=["The ZX Spectrum has one graphics mode: 256×192 pixels in which every 8×8 cell may use only two colours, called __ink__ and __paper__, taken from 8 colours in two levels of brightness (15 colours in all, because bright black is the same as black). Where a picture needs more colours in a cell than the hardware allows, the colours of neighbouring cells “clash”, and BitPast’s output shows that clash exactly as the real machine would. Files are {{.scr}} screen dumps of 6,912 bytes: 6,144 bytes of bitmap and 768 of colour attributes."],
    modes=[dict(label="Standard (256×192)", res="256×192", col="2 per 8×8 cell (15 colours)", fact=0, help=0)],
    gallery=[("m-ZXSpectrum-0", "Standard (256×192)")],
 ),
}

# What the generic settings do
OPT_DESC = {
 "dither": "How colours that the machine can’t show are approximated (Chapter 5).",
 "dither_amount": "How strongly the dither is applied; 0 is none, 1 is full strength.",
 "contrast": "Contrast enhancement applied before the colours are chosen.",
 "filter": "A quick filter applied before converting.",
 "color_match": "How BitPast judges which colour is closest.",
 "saturation": "Colour intensity; 1 leaves it unchanged.",
 "gamma": "Brightness of the mid-tones; below 1 brightens, above 1 darkens.",
 "pixel_merge": "How the two halves of a double-wide pixel are combined: Average blends them, Brightest keeps the brighter one.",
 "mode": "The graphics mode, described above.",
 "resolution": "The size of the picture.",
 "cga_palette": "The fixed set of three colours (plus black) used in CGA mode.",
 "colorset": "The set of colours used by the CoCo’s four-colour modes.",
 "quantization_method": "How palettes are chosen in 3,200-colour mode.",
 "scb_mode": "Which of the 16 palettes each line uses in 256-colour mode.",
 "threshold": "How alike two lines must be to share a palette. Shown with Palette Reuse.",
 "preprocess": "A filter applied before converting (Chapter 5).",
 "median_size": "Size of the area used by the Median filter.",
 "sharpen_strength": "Strength of the Sharpen filter.",
 "sigma_range": "How different colours may be and still be smoothed together by the Sigma filter.",
 "solarize_threshold": "Brightness above which the Solarize filter inverts tones.",
 "emboss_depth": "Depth of the Emboss effect.",
 "edge_threshold": "How strong an edge must be for Find Edges to draw it.",
 "palette": "The colour table used to display and judge the Apple II’s colours.",
 "crosshatch": "A b2d pattern setting; 0 turns it off.",
 "z_threshold": "A b2d threshold setting for the cross-hatch pattern.",
 "error_matrix": "A b2d setting for the error-diffusion matrix.",
}
OPT_NAMES = {"mode": "Mode"}

def choices(o):
    if o["type"] == "slider":
        lo, hi = o["range"]
        f = lambda v: f"{v:g}"
        return f"slider, {f(lo)} to {f(hi)}"
    return ", ".join(o["values"])

def settings_table(sysid):
    rows = []
    for o in OPTIONS[sysid]["options"]:
        if o["key"] in ("fit", "aspect"):
            continue
        rows.append([f'<span class="nm">{esc(o["label"])}</span>', esc(choices(o)), esc(o["default"]), esc(OPT_DESC.get(o["key"], ""))])
    return table(["Setting", "Choices", "Default", "What it does"], rows, cls="tight", widths=["24%", "36%", "12%", "28%"])

def modes_table(sysid, s):
    rows = []
    for m in s["modes"]:
        ext, size = file_info(sysid, m["fact"], m.get("size"))
        rows.append([f'<span class="nm">{esc(m["label"])}</span>', esc(m["res"]), esc(m["col"]), f'<span class="file">{esc(ext)}</span>', esc(size)])
        for xf in m.get("extra_facts", []):
            e2, s2 = file_info(sysid, xf)
            rows.append(["<i>… with 280×192</i>", "280×192", "2", f'<span class="file">{esc(e2)}</span>', esc(s2)])
    return table(["Mode", "Screen", "Colours", "File", "Size"], rows, cls="tight", widths=["30%", "22%", "21%", "12%", "15%"])

def mode_text(sysid, s):
    hk = HELP[HELPKEY[sysid]]["modes"] if sysid != "AppleII" else None
    out = ""
    for m in s["modes"]:
        if hk is not None:
            h = hk[m["help"]]
            desc, best, tips = clean(h["desc"]), clean(h["best"]), [(n, clean(d)) for n, d in h["opts"]]
        else:
            desc, best, tips = m["desc"], m["best"], [(None, t) for t in m["tips"]]
        ext, size = file_info(sysid, m["fact"], m.get("size"))
        tip_html = ""
        if tips:
            tip_html = "<ul class=\"bullets modetips\">" + "".join(f"<li>{('<b>' + esc(n) + ':</b> ') if n else ''}{fmt(t)}</li>" for n, t in tips) + "</ul>"
        out += (f'<div class="mode"><div class="mh"><b>{esc(m["label"])}</b><span>{esc(m["res"])} · {esc(m["col"])} · <span class="file">{esc(ext)}</span></span></div>'
                f'<p>{fmt(desc)}</p><p class="best"><b>Best for</b> {fmt(best)}</p>{tip_html}</div>')
    return out
