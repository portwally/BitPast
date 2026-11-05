"""Chapters 6 to 11 and the appendices."""
from lib import *
from systems import *

SHORTCUT = {"AppleII": "⇧⌘1", "AppleIIGS": "⇧⌘2", "Amiga500": "⇧⌘3", "Amiga1200": "⇧⌘4", "AmstradCPC": "⇧⌘5", "Atari800": "⇧⌘6", "AtariST": "⇧⌘7",
            "BBCMicro": "⇧⌘8", "C64": "⇧⌘9", "MSX": "⇧⌘0", "PC": "⇧⌘P", "Plus4": "⇧⌘L", "TRS80CoCo": "⇧⌘T", "VIC20": "⇧⌘V", "ZXSpectrum": "⇧⌘Z"}
SPEC = {"AppleII": ("NTSC artifact colour (b2d)", "6 in Hi-Res, 16 in Double Hi-Res"), "AppleIIGS": ("Super Hi-Res", "16 per line; up to 3,200 in all"),
        "Amiga500": ("OCS/ECS chipset", "32 of 4,096; 4,096 in HAM6"), "Amiga1200": ("AGA chipset", "256 of 16.7 million; 262,144 in HAM8"),
        "AmstradCPC": ("Gate Array", "4 or 16 of 27"), "Atari800": ("ANTIC and GTIA", "2 to 16 of 128"), "AtariST": ("Shifter", "16, 4 or 2 of 512"),
        "BBCMicro": ("6845 CRTC", "2, 4 or 8"), "C64": ("VIC-II", "16"), "MSX": ("TMS9918 / V9938", "16; 16 of 512; 256"), "PC": ("CGA, EGA, VGA", "4, 16 or 256"),
        "Plus4": ("TED", "128 (16 hues × 8 levels)"), "TRS80CoCo": ("MC6847 and GIME", "2, 4 or 16"), "VIC20": ("VIC", "16"), "ZXSpectrum": ("ULA", "15")}
PALETTE_APPENDIX = {"AppleIIGS": "IIgs Desktop", "AmstradCPC": "CPC", "Atari800": "Atari", "BBCMicro": "BBC", "C64": "C64", "MSX": "MSX", "PC": "PC", "TRS80CoCo": "CoCo", "VIC20": "VIC", "ZXSpectrum": "ZX"}

def sysextras(sid):
    x = ""
    if sid == "AppleIIGS":
        x += "<h3>SCB Mode</h3>"
        x += row("", ps("In the 256-colour mode the hardware has 16 palettes, and every one of the 200 lines uses one of them. **SCB Mode** decides which. Its three choices give three different pictures from the same photograph.",))
        x += table(["SCB Mode", "How lines are given palettes"],
                   [["<span class=\"nm\">Banded</span>", "The screen is divided into 16 even bands of lines, and every band has a palette of its own. Fast and predictable. This is the default."],
                    ["<span class=\"nm\">Palette Reuse</span>", "The older method. A line keeps the previous line’s palette when that fits well enough (see Palette Merge Tolerance), and starts a new palette when it does not. On photographs it usually looks worse than Banded."],
                    ["<span class=\"nm\">Per-Line</span>", "Any line can use any of the 16 palettes. BitPast starts from 16 bands, gives each line the palette that fits it best, rebuilds the palettes from the lines assigned to them, and repeats until nothing changes. Similar lines share a palette even when they are far apart, so this usually gives the best quality."]],
                   widths=["16%", "84%"])
        items = [("v-scb-Banded", "Banded", "16 even bands."), ("v-scb-Palette Reuse", "Palette Reuse", "Reuses the previous line’s palette."), ("v-scb-Per-Line", "Per-Line", "Any line, any palette.")]
        x += '<div class="figrow wide"><div class="fig">' + pxgrid(items, cols=3) + "</div>" + \
             f'<div class="cap"><b>Figure {fig_number()}</b>The three SCB modes on the same picture. Look at the sky.</div></div>'
        x += note("tip", "To fine-tune individual palettes after a conversion, use the palette editor (Chapter 7).")
    if sid == "Amiga500":
        x += note("note", "HAM changes only one colour component from one pixel to the next, so a sharp edge between two very different colours can show a coloured fringe. This is typical of the mode, and is why HAM suits smooth photographs better than line art.")
    if sid == "Amiga1200":
        items = [("v-res-320×256", "320×256", ""), ("v-res-320×512", "320×512 (interlaced)", ""), ("v-res-640×512", "640×512 (hi-res interlaced)", "")]
        x += '<div class="figrow wide"><div class="fig">' + pxgrid(items, cols=3) + "</div>" + \
             f'<div class="cap"><b>Figure {fig_number()}</b>The three resolutions. More pixels give more detail, but bigger files.</div></div>'
    if sid == "PC":
        x += "<h3>CGA palettes</h3>"
        x += table(["CGA Palette", "Colours (plus black)"],
                   [["<span class=\"nm\">Cyan/Magenta/White</span>", "Cyan, magenta and white, in high intensity."], ["<span class=\"nm\">Cyan/Magenta/Gray</span>", "Cyan, magenta and light grey, in low intensity."],
                    ["<span class=\"nm\">Green/Red/Yellow</span>", "Light green, light red and yellow, in high intensity."], ["<span class=\"nm\">Green/Red/Brown</span>", "Green, red and brown, in low intensity."]],
                   widths=["30%", "70%"])
        x += row("", p("Chapter 5 shows how Color Match affects the fixed EGA palette (Figure 5-5)."))
    if sid == "TRS80CoCo":
        items = [("v-coco-set0", "Set 0", "Green, yellow, blue, red."), ("v-coco-set1", "Set 1", "Buff, cyan, magenta, orange."), ("v-coco-artifact", "Artifact (NTSC)", "PMODE 4 with artifact colours.")]
        x += '<div class="figrow wide"><div class="fig">' + pxgrid(items, cols=3) + "</div>" + \
             f'<div class="cap"><b>Figure {fig_number()}</b>The colour sets of the original CoCo.</div></div>'
        x += row("", p("**Color Set** applies to PMODE 3 and PMODE 1. **Artifact (NTSC)** is meant for PMODE 4: on a composite monitor the two colours of that mode produce blue and orange fringes, which BitPast uses to give the picture additional colour."))
    if sid == "AtariST":
        x += row("", p("Chapter 4 shows how Aspect changes a picture in medium resolution (Figure 4-2)."))
    if sid == "C64":
        x += row("", p("Chapter 5 shows Pixel Merge on a Multicolor picture (Figure 5-6)."))
    return x

def ch6():
    ch = Chapter("ch6", 6, "The Systems")
    intro = ""
    intro += row("", p("This chapter has one section for each of the fifteen systems, in the order of the system bar. Each section gives the system’s facts, shows BitPast with the system selected, lists every mode with its picture, its file and the best use for it, and finishes with the settings that system offers.", "lead"))
    intro += row("<b>Reading a section</b>", p("The box in the margin of each section gives the essentials: the year of introduction, the video hardware, the colours and sizes, the native files and the keyboard shortcut. The pictures of the modes were all made from one photograph, with each mode’s default settings, so you can compare them."))
    intro += row("<b>Screen shapes</b>", p("The pictures are shown on a 4:3 screen, as the machines showed them. A picture that looks narrow or wide in the preview is shown here in its true proportions."))
    rows = [[f'<span class="nm">{SYSTEMS[s]["name"]}</span>', SYSTEMS[s]["year"], SPEC[s][0], SHORTCUT[s]] for s in ORDER]
    intro += table(["System", "Introduced", "Video hardware", "Shortcut"], rows, cls="tight", widths=["32%", "16%", "36%", "16%"])
    out = chapter_html(ch, "Fifteen machines, every mode and every setting", intro)
    # one section per system
    sections = ""
    for i, sid in enumerate(ORDER, 1):
        s = SYSTEMS[sid]
        key = f"sys-{sid}"
        TOC.append((2, key, f"6.{i}", s["name"]))
        exts = []
        for m in s["modes"]:
            e, _ = file_info(sid, m["fact"], m.get("size"))
            for xf in m.get("extra_facts", []):
                exts.append(file_info(sid, xf)[0])
            exts.append(e)
        exts = list(dict.fromkeys(exts))
        hw, colours = SPEC[sid]
        specbox = spec([("Introduced", s["year"]), ("Video hardware", hw), ("Colours", colours),
                        ("Native files", " ".join(exts)), ("Shortcut", SHORTCUT[sid])])
        sec = f'<section class="sys sys{i}">'
        sec += (f'<div class="sysband"><div class="no">6.{i}</div><div class="nm"><h2>{mark(key)}{esc(s["name"])}</h2><div class="chip">{esc(s["chip"])}</div></div></div>')
        sec += row(specbox, "".join(p(t) for t in s["intro"]))
        FIG["ch"] = 6
        sec += figrow(macwin(f"sys-{sid}", "BitPast", f"BitPast with the {s['name']} selected"), f"BitPast with the {s['name']} selected.", "", wide=True)
        sec += "<h3>Modes</h3>" + modes_table(sid, s)
        cols = 3 if len(s["gallery"]) not in (2, 4) else (2 if len(s["gallery"]) == 2 else 4)
        sec += pxgrid([(g[0], g[1], "") for g in s["gallery"]], cols=cols)
        sec += mode_text(sid, s)
        sec += sysextras(sid)
        sec += '<h3>Settings <span style="font-weight:normal;font-size:8.6pt;letter-spacing:.02em">&nbsp;(every system also offers Fit and Aspect, Chapter 4)</span></h3>' + settings_table(sid)
        if s.get("settings_note"):
            sec += row("", p(s["settings_note"]))
        sec += "</section>"
        sections += sec
    return out + sections

# ---------------------------------------------------------------- chapter 7
def ch7():
    ch = Chapter("ch7", 7, "The Palette Editor")
    b = ""
    b += row("", p("An Apple IIgs picture is stored together with its palettes, and the palette editor lets you change them: make a sky bluer, a skin tone warmer, or fix one stubborn line. It is available for the Apple IIgs only.", "lead"))
    b += ch.h2("Opening the editor", "ch7-open")
    b += row("", ps("Select the Apple IIgs, choose a picture in a mode that has palettes, and click [[Palette]] above the preview. The editor opens in its own window. The button is dimmed until a picture has been converted.",))
    callouts = [(1, 12.9, 39.8), (2, 66.3, 35.3), (3, 51.0, 87.8), (4, 73.0, 95.7), (5, 76.0, 3.5)]
    b += '<div class="figrow wide"><div class="fig">' + macwin("palette-editor", "Palette Editor", "The palette editor", callouts, dialog=True) + "</div>" + \
         f'<div class="cap"><b>Figure {fig_number()}</b>The palette editor with a 3,200-colour picture.</div></div>'
    b += legend([(1, "**Palette list.** One entry for each palette, with a strip showing its sixteen colours. In 3,200-colour mode the entries are lines (Line 0 to Line 199); in 256-colour mode they are palettes (Palette 0 to Palette 15)."),
                 (2, "**Colour grid.** The sixteen colours of the selected palette."),
                 (3, "**Undo, redo, Copy Palette and Paste Palette.**"),
                 (4, "**Reset, Cancel and Apply.**"),
                 (5, "**Title.** The editor tells you the mode: for example, 3200 Colors (200 Palettes).")])
    b += ch.h2("Changing a colour", "ch7-change")
    b += step("1", "Click an entry in the palette list. The grid shows its sixteen colours.")
    b += step("2", "Click a colour in the grid. The standard macOS colour panel opens; choose the colour you want. The colour’s number, its hexadecimal value and its IIgs value ($RGB) are shown below the grid.")
    b += step("3", "Repeat for any other colours. [[Undo]] and [[Redo]] (^^⌘Z^^ and ^^⇧⌘Z^^) step through your changes.")
    b += step("4", "Click [[Apply]] to keep the changes, [[Cancel]] to leave without them, or [[Reset]] to put the palettes back as BitPast made them.")
    b += row("", p("The IIgs can show only 4,096 colours: sixteen levels each of red, green and blue. A colour you choose is rounded to the nearest of these when it is written to the file, which is why the editor also shows the IIgs value."))
    b += ch.h2("Copying palettes", "ch7-copy")
    b += row("", p("[[Copy Palette]] copies the selected palette; [[Paste Palette]] puts it into another entry of the list. This is the quickest way to give a run of lines the same colours, or to move a good palette to a place that needs it."))
    b += ch.h2("What Apply does", "ch7-apply")
    b += row("", ps("When you click [[Apply]], the preview is redrawn with your colours at once. The edits are also written into the picture’s file — the {{.shr}} or {{.3200}} — so [[Save Image…]], batch export and [[Create Disk]] all use the edited palettes for that picture.",))
    b += note("important", ps("Changing any setting, or moving or flipping the picture, converts it again from the original and discards palette edits. Make palette edits last, once everything else is as you want it.",
                              "Edits belong to the picture and the system they were made for. If you switch to another system and back, convert again."))
    return chapter_html(ch, "Changing the colours of an Apple IIgs picture", b)

# ---------------------------------------------------------------- chapter 8
def ch8():
    ch = Chapter("ch8", 8, "Saving and Exporting")
    b = ""
    b += row("", p("BitPast can save a picture in two ways: as an ordinary picture file for viewing and sharing, and as the machine’s own file for loading on the machine. It can also do either for many pictures at once.", "lead"))
    b += ch.h2("Saving one picture", "ch8-one")
    b += row("", p("Click [[Save Image…]] in the Actions column and choose a format:"))
    b += table(["Choice", "What you get"],
               [["<span class=\"nm\">PNG</span>", "The preview as an ordinary picture, without loss. The best choice for sharing the result."],
                ["<span class=\"nm\">JPG</span>", "The preview as a JPEG. Smaller, but its compression softens the sharp pixels."],
                ["<span class=\"nm\">GIF</span>", "The preview as a GIF."],
                ["<span class=\"nm\">TIFF</span>", "The preview as a TIFF."],
                ["<span class=\"nm\">Native Format (.ext)</span>", "The machine’s own file. The menu shows the extension for the selected mode, for example {{.kla}}."]],
               widths=["28%", "72%"])
    b += note("tip", "The preview is small, because it is the machine’s own screen. To enlarge a saved PNG without blurring it, open it in an app that can scale with nearest-neighbour interpolation, or scale it by a whole number such as 3 or 4.")
    b += ch.h2("Native files", "ch8-native")
    b += row("", ps("A native file contains the screen exactly as the machine’s hardware stores it. What is in it depends on the machine. A Spectrum {{.scr}} holds the bitmap and the colour attributes. An Apple IIgs {{.shr}} holds the 200 lines of bitmap, a scan control byte for each line, and the palettes. A Commodore 64 {{.kla}} holds the bitmap, the screen and colour memory and the background colour.",
                    "Appendix A lists the file for every mode, with its size, and describes the layout of several of them. Chapter 9 explains how to put native files onto a disk image."))
    b += ch.h2("Saving several pictures at once", "ch8-batch")
    b += step("1", "Select the pictures with the small circles in the Image Browser (Chapter 4), or use the checkbox above the browser to select all of them.")
    b += step("2", "Click the [[Save Image…]] menu. It now reads [[Save 3 Images…]], or however many you selected.")
    b += step("3", "Choose a format. BitPast asks you to choose a folder, and converts and saves every selected picture in it, showing its progress as [[Exporting 2/3…]].")
    b += row("", ps("Each picture is converted with the current settings, or with its own settings if you locked them (Chapter 4). Each file is named after its picture, with the extension of the format. The position of each picture, and any flip, is used too."))
    return chapter_html(ch, "Pictures and the machine’s files", b)

# ---------------------------------------------------------------- chapter 9
def ch9():
    ch = Chapter("ch9", 9, "Disk Images")
    b = ""
    b += row("", p("A disk image is a single file that holds the contents of a whole floppy disk. Emulators load disk images directly, and floppy emulators and disk-copying tools can put them on real media. BitPast can create disk images for all fifteen systems and fill them with your converted pictures.", "lead"))
    b += ch.h2("Creating a disk image", "ch9-create")
    b += step("1", "Add your pictures and choose the system. Adjust the settings until the pictures look right.")
    b += step("2", "Select the pictures that should go on the disk. If you select none, every picture in the browser is used.")
    b += step("3", "Click [[Create Disk]] in the Actions column. A sheet opens with the system already chosen to match the main window.")
    b += step("4", "Type a volume name, and choose the disk format and size. The sheet tells you how many pictures will be converted and added.")
    b += step("5", "Click [[Create Disk Image]] and choose where to save it. BitPast converts every picture, writes the files onto the disk and shows its progress.")
    b += '<div class="figrow wide"><div class="fig">' + macwin("disk-c64", "Create Disk Image", "The Create Disk Image sheet for the Commodore 64", dialog=True) + "</div>" + \
         f'<div class="cap"><b>Figure {fig_number()}</b>The Create Disk Image sheet, with the Commodore 64 chosen.</div></div>'
    b += note("tip", "Leave the sheet on the system that is selected in the main window. The pictures are converted for that system, and the disk should be made for the same one.")
    b += ch.h2("Disk formats", "ch9-formats")
    rows = [
      ["Apple II, Apple IIgs", ".PO, .2MG, .HDV", "140 KB, 800 KB, 32 MB", "ProDOS", "AppleWin, KEGS, GSport, Virtual II"],
      ["Commodore 64, VIC-20, Plus/4", ".D64, .D71, .D81", "170 KB, 340 KB, 800 KB", "CBM DOS (files are PRG type)", "VICE (x64, x128, xvic, xplus4)"],
      ["Amiga 500, Amiga 1200", ".ADF", "880 KB, 1.76 MB", "OFS (Original File System)", "FS-UAE, WinUAE, Amiberry"],
      ["Atari 800", ".ATR", "90 KB, 130 KB, 180 KB, 360 KB", "Atari DOS 2.0S; DOS 2.5 for 130 KB", "Altirra, Atari800"],
      ["Atari ST", ".ST", "360 KB, 720 KB, 1.44 MB", "FAT12", "Hatari, Steem"],
      ["BBC Micro", ".SSD, .DSD", "100 KB, 200 KB, 400 KB", "Acorn DFS (up to 31 files)", "BeebEm, b-em, JSBeeb"],
      ["MSX", ".DSK", "360 KB, 720 KB", "MSX-DOS (FAT12)", "openMSX, blueMSX, fMSX"],
      ["Amstrad CPC", ".DSK", "180 KB, 360 KB", "AMSDOS (extended DSK)", "WinAPE, Arnold, Caprice32"],
      ["ZX Spectrum", ".TRD, .DSK", "640 KB, 180 KB", "TR-DOS (80 tracks, double-sided); +3DOS", "Fuse, ZX Spin, SpecEmu"],
      ["IBM PC", ".IMG", "360 KB, 720 KB, 1.2 MB, 1.44 MB", "FAT12 / FAT16", "DOSBox, PCem, 86Box"],
      ["TRS-80 CoCo", ".DSK", "180 KB, 360 KB", "RS-DOS (360 KB as double-sided JVC)", "CoCo emulators that read JVC disks"],
    ]
    rows = [[f'<span class="nm">{a}</span>', f'<span class="file">{b_}</span>', c, d, e_] for a, b_, c, d, e_ in rows]
    b += table(["System", "Image type", "Sizes", "File system", "Emulators"], rows, cls="tight", widths=["17%", "14%", "20%", "26%", "23%"])
    b += row("", p("The Commodore disks: D64 is a 1541 disk (35 tracks), D71 a 1571 disk (70 tracks) and D81 a 1581 disk (80 tracks). The Amiga’s 880 KB image is a double-density disk; 1.76 MB is high density. The Apple’s 140 KB image is a 5.25-inch disk, 800 KB a 3.5-inch disk, and 32 MB a hard-disk image. The BBC’s SSD is single-sided and DSD double-sided."))
    b += ch.h2("Volume names", "ch9-volume")
    b += row("", p("Every system has its own rules for the name of a disk, and the sheet tells you the longest name allowed. BitPast corrects names that break the rules."))
    b += table(["System", "Rule"],
               [["Apple II, Apple IIgs", "Up to 15 characters: letters, digits and periods, starting with a letter."], ["Commodore", "Up to 16 characters; most printable PETSCII characters."],
                ["Amiga", "Up to 30 characters; most ASCII characters except : and /."], ["Atari, PC, MSX", "8 to 11 characters, depending on the system: letters and digits only."],
                ["BBC Micro", "Up to 12 characters, letters and digits."]], widths=["28%", "72%"])
    b += ch.h2("Choosing a size", "ch9-size")
    b += row("", ps("Choose a disk large enough for all your pictures. A picture that does not fit is left off the disk rather than being written as a damaged file, so if a picture is missing, make the disk larger.",
                    "A native file is often much smaller than a disk — a Spectrum picture is under 7 KB — so a single disk usually holds many pictures. Appendix A gives the size of every file."))
    return chapter_html(ch, "Putting your pictures on a disk", b)

# ---------------------------------------------------------------- chapter 10
def ch10():
    ch = Chapter("ch10", 10, "Appearance and Help")
    b = ""
    b += row("", p("BitPast can look like a modern Mac app, or like one of three classic computers. This chapter also lists the keyboard shortcuts and describes the guide built into the app.", "lead"))
    b += ch.h2("Appearance", "ch10-look")
    b += row("", ps("Choose [[BitPast ▸ Settings…]] (^^⌘,^^) to open the Settings window. It has one control, [[Appearance]], with six choices:"))
    b += table(["Choice", "What you get"],
               [["<span class=\"nm\">System</span>", "Follows the light or dark setting of your Mac."], ["<span class=\"nm\">Light</span>", "Always light."], ["<span class=\"nm\">Dark</span>", "Always dark."],
                ["<span class=\"nm\">Retro (Apple IIgs)</span>", "The interface drawn in the style of the IIgs’s GS/OS desktop: platinum grey, with the system’s bitmap type."],
                ["<span class=\"nm\">Retro (Apple II)</span>", "A green-phosphor monochrome screen, with the Apple II’s character set."],
                ["<span class=\"nm\">Retro (Commodore 64)</span>", "The C64’s blue screen, with its character set."]], widths=["26%", "74%"])
    b += '<div class="figrow wide"><div class="fig"><div class="pxgrid c2" style="margin:0 0 5mm;gap:5mm">' + \
         "".join(f'<figure>{macwin(n, "BitPast", t)}<figcaption><b>{t}</b></figcaption></figure>' for n, t in [("theme-dark", "Dark"), ("theme-gsos", "Retro (Apple IIgs)")]) + "</div>" + \
         '<div class="pxgrid c2" style="margin:0;gap:5mm">' + \
         "".join(f'<figure>{macwin(n, "BitPast", t)}<figcaption><b>{t}</b></figcaption></figure>' for n, t in [("theme-apple2", "Retro (Apple II)"), ("theme-c64", "Retro (Commodore 64)")]) + "</div></div>" + \
         f'<div class="cap"><b>Figure {fig_number()}</b>BitPast in four of its six appearances. (Light is the look shown in the rest of this guide.)</div></div>'
    b += row("", p("The retro appearances change only how BitPast looks. They do not change what it does."))
    b += '<div class="figrow"><div class="fig">' + macwin("settings", "Settings", "The Settings window", dialog=False) + "</div>" + \
         f'<div class="cap"><b>Figure {fig_number()}</b>The Settings window.</div></div>'
    b += ch.h2("Keyboard shortcuts", "ch10-keys")
    rows = [[f'<span class="nm">{SYSTEMS[s]["name"]}</span>', f'<span class="key">{SHORTCUT[s]}</span>'] for s in ORDER]
    half = (len(rows) + 1) // 2
    left, right = rows[:half], rows[half:] + [["", ""]]
    paired = [l + r for l, r in zip(left, right)]
    b += table(["System", "Shortcut", "System", "Shortcut"], paired, widths=["30%", "20%", "30%", "20%"])
    b += table(["Command", "Shortcut"],
               [["Graphics Mode Guide", '<span class="key">⌘?</span>'], ["Settings", '<span class="key">⌘,</span>'], ["Undo (palette editor)", '<span class="key">⌘Z</span>'],
                ["Redo (palette editor)", '<span class="key">⇧⌘Z</span>'], ["Select a range of pictures", "Shift-click the second picture"], ["Centre the picture in the preview", "Double-click the preview"]],
               widths=["50%", "50%"])
    b += ch.h2("The Graphics Mode Guide", "ch10-guide")
    b += row("", p("Choose [[Help ▸ Graphics Mode Guide]] (^^⌘?^^) to open a window that describes every system, mode and setting. Systems are listed on the left, and General Options, Preprocessing Filters and Disk Images under [[Reference]]. Click one to read about it."))
    b += '<div class="figrow"><div class="fig">' + macwin("help", "Graphics Mode Guide", "The Graphics Mode Guide window") + "</div>" + \
         f'<div class="cap"><b>Figure {fig_number()}</b>The Graphics Mode Guide (the system list on the left is not shown).</div></div>'
    b += row("", p("The Graphics Mode Guide and this guide cover the same ground. The Guide is always at hand inside the app; this one adds pictures, comparisons and the file formats."))
    return chapter_html(ch, "Looks, shortcuts and the built-in guide", b)

# ---------------------------------------------------------------- chapter 11
def ch11():
    ch = Chapter("ch11", 11, "Questions and Answers")
    b = ""
    b += row("", p("Short answers to the questions people ask most often.", "lead"))
    qa = [
      ("The picture looks nothing like the original.", "That is expected with the smallest palettes. Try more contrast (CLAHE), a little more saturation, or a different colour match. Pictures with strong shapes convert better than detailed ones. Chapter 4 has tips for choosing pictures."),
      ("There are black bars around the picture.", "Fit is set to Contain, which shows the whole picture. Set Fit to Stretch to fill the screen, or to Cover to fill it and crop the edges."),
      ("A slider does nothing.", "The selected picture is probably locked (the padlock is orange). A locked picture keeps its own settings. Click the padlock to release it."),
      ("My palette edits disappeared.", "Any other change converts the picture again and discards palette edits. Make them last, after every other setting is final (Chapter 7)."),
      ("An Atari 800 picture in Graphics 15 is nearly grey.", "Four colours from 128 have to cover the whole picture. A picture with a lot of grey (a pale sky, a dark mountain) gets grey colours. Try more saturation, or a picture with more colour."),
      ("The IIgs 640 pictures look very wide.", "Their pixels are twice as tall as they are wide, so the preview shows them at double height to look right. They are shown as they would be on the machine."),
      ("macOS says BitPast cannot be opened.", "This can happen with a copy downloaded from GitHub. Control-click the app, choose Open, and confirm (Chapter 2)."),
      ("A picture is missing from my disk image.", "It did not fit. Choose a larger disk size and create the disk again."),
      ("The preview takes a moment to update.", "Some conversions — HAM, the IIgs 3,200-colour mode and Per-Line SCB mode — are heavier than others. BitPast works in the background, so you can keep using the window; a Converting… indicator shows while it works."),
      ("The same picture converts differently each time.", "Only the Noise dither is random. Every other setting gives exactly the same result for the same picture and settings."),
    ]
    for q, a in qa:
        b += row(f"<b>{esc(q)}</b>", p(a))
    return chapter_html(ch, "Problems and how to solve them", b)

# ---------------------------------------------------------------- appendices
def swatches(name, colours, cls="", meta="", per_row=None):
    sw = "".join(f'<i style="background:rgb({c[0]},{c[1]},{c[2]})"></i>' for c in colours)
    style = f' style="max-width:{per_row * (7.2 if cls == "" else 5.2 if cls == "s" else 3.6)}mm"' if per_row else ""
    return f'<div class="pal {cls}"><div class="name">{esc(name)}</div><div class="sw"{style}>{sw}</div><div class="meta">{fmt(meta)}</div></div>'

def appendix_a():
    ch = Chapter("appA", "A", "Native File Formats")
    TOC[-1] = (1, "appA", "A", "Native File Formats")
    b = row("", p("Every mode and the file BitPast writes for it. Sizes were measured with BitPast 4.6. Files that are compressed — IFF, PCX and ANSI — vary with the picture.", "lead"))
    rows = []
    for sid in ORDER:
        s = SYSTEMS[sid]
        first = True
        for m in s["modes"]:
            ext, size = file_info(sid, m["fact"], m.get("size"))
            rows.append([f'<span class="nm">{s["name"]}</span>' if first else "", esc(m["label"]), f'<span class="file">{ext}</span>', size])
            first = False
            for xf in m.get("extra_facts", []):
                e2, s2 = file_info(sid, xf)
                rows.append(["", "<i>Mono, 280×192</i>", f'<span class="file">{e2}</span>', s2])
    b += table(["System", "Mode", "File", "Size"], rows, cls="tight", widths=["20%", "42%", "14%", "24%"])
    b += "<h3>Layouts of some files</h3>"
    b += table(["File", "Layout"],
               [["<span class=\"file\">.shr</span> (IIgs)", "32,768 bytes: 32,000 bytes of bitmap (200 lines of 160 bytes), 200 scan control bytes at $7D00, and 16 palettes of 16 colours at $7E00. Each colour is a 16-bit word, $0RGB, with four bits per component."],
                ["<span class=\"file\">.3200</span> (IIgs, Brooks)", "38,400 bytes: 32,000 bytes of bitmap, then a palette of 16 colours for each of the 200 lines (32 bytes each), with the colours stored from 15 down to 0."],
                ["<span class=\"file\">.scr</span> (ZX Spectrum)", "6,912 bytes: 6,144 bytes of bitmap in the Spectrum’s interleaved order, then 768 attribute bytes (ink, paper, brightness)."],
                ["<span class=\"file\">.scr</span> (Amstrad CPC)", "16,512 bytes: a 128-byte AMSDOS header followed by 16,384 bytes of screen memory."],
                ["<span class=\"file\">.pi1</span> <span class=\"file\">.pi2</span> <span class=\"file\">.pi3</span> (Atari ST)", "32,034 bytes: a 2-byte resolution word, the 16-word palette, and 32,000 bytes of bitplane data (DEGAS Elite format)."],
                ["<span class=\"file\">.kla</span> (C64)", "10,003 bytes: a 2-byte load address, 8,000 bytes of bitmap, 1,000 bytes of screen colours, 1,000 bytes of colour memory and the background colour (Koala Painter format)."],
                ["<span class=\"file\">.iff</span> (Amiga)", "An IFF ILBM picture: the standard Amiga picture format, with the palette and bitplanes (and the HAM flag in HAM modes)."],
                ["<span class=\"file\">.pcx</span> (PC)", "A PC Paintbrush picture with run-length compression; the palette is stored in the file."]],
               cls="tight", widths=["24%", "76%"])
    return chapter_html(ch, "Every file, its size and its layout", b)

def appendix_b():
    ch = Chapter("appB", "B", "Colour Palettes")
    TOC[-1] = (1, "appB", "B", "Colour Palettes")
    b = row("", p("The fixed palettes that BitPast chooses from, as it defines them. Systems whose palettes are chosen per picture from a very large set (the Amiga, the Atari ST, the Apple IIgs) are not shown.", "lead"))
    P = PALETTES
    b += swatches("Commodore 64 · 16 colours", P["C64"], meta="The Pepto palette.")
    b += swatches("VIC-20 · 16 colours", P["VIC20"])
    zx = []
    for c in P["ZXSpectrum"]:
        if c not in zx:
            zx.append(c)
    b += swatches("ZX Spectrum · 15 colours", zx, meta="Eight colours at normal brightness and seven at bright (bright black is black).")
    b += swatches("BBC Micro · 8 colours", P["BBCMicro"])
    b += swatches("Amstrad CPC · 27 colours", P["AmstradCPC"], cls="s", meta="Three levels each of red, green and blue.", per_row=9)
    b += swatches("MSX1 (TMS9918) · 16 colours", P["MSX1"], meta="Index 0 is transparent and is shown as black.")
    b += swatches("PC CGA · 16 colours", P["PC-CGA"])
    b += swatches("PC EGA · 64 colours", P["PC-EGA"], cls="s", meta="Two bits each of red, green and blue.", per_row=16)
    b += swatches("Apple IIgs Desktop · 16 colours", P["IIgsDesktop"], meta="The palette of the 640×200 Desktop mode (even and odd columns share these colours in two groups of four).")
    b += swatches("TRS-80 CoCo 3 · 64 colours", P["CoCo3"], cls="s", meta="Two bits each of red, green and blue.", per_row=16)
    b += swatches("Commodore Plus/4 · 128 colours", P["Plus4"], cls="xs", meta="Eight rows of brightness, from dark to light, each with the sixteen hues of the TED chip. Hue 0 is black in every row; the lightest row is almost white.", per_row=16)
    b += swatches("Atari 800 · 128 colours", P["Atari800"], cls="xs", meta="Sixteen hues, one to a row, each in eight levels of brightness. The first row is grey.", per_row=8)
    return chapter_html(ch, "The palettes of the fixed-palette systems", b)

def appendix_c():
    ch = Chapter("appC", "C", "Glossary")
    TOC[-1] = (1, "appC", "C", "Glossary")
    terms = [
      ("Artifact colour", "Colour produced not by the video chip but by the way a television decodes patterns of dots. The Apple II and the CoCo’s PMODE 4 rely on it."),
      ("Attribute clash", "The look of the ZX Spectrum’s colours: each 8×8 cell has only two colours, so a third colour in a cell makes it take on the colours of its neighbours."),
      ("Bitplane", "One layer of a picture: the bits of the same weight for every pixel. Amiga and Atari ST pictures are stored as several bitplanes."),
      ("Brooks format", "The file format for Apple IIgs pictures that have a full palette for each of the 200 lines, 3,200 colours in all."),
      ("Cell", "A small block of the screen, such as 8×8 pixels, that has its own colours. Most 8-bit systems restrict the colours per cell."),
      ("Dithering", "Mixing dots of the available colours so that the eye sees a colour that isn’t in the palette."),
      ("Error diffusion", "A dither that spreads the rounding error of each pixel over the pixels that are still to come."),
      ("HAM", "Hold-And-Modify, an Amiga mode in which a pixel either takes a palette colour or changes one component of the pixel before it, giving thousands of colours."),
      ("Interlace", "Showing a picture in two passes of alternate lines, which doubles the vertical resolution of the Amiga’s screen."),
      ("Native file", "The file a machine loads: the screen memory as the hardware stores it."),
      ("Ordered dithering", "A dither that compares each pixel with a fixed pattern of thresholds, such as a Bayer matrix."),
      ("Palette", "The set of colours a picture may use. Some machines have one palette, some many."),
      ("PETSCII", "The Commodore character set, which includes graphic symbols. PETSCII pictures are made of characters rather than pixels."),
      ("SCB", "Scan Control Byte: on the Apple IIgs, a byte for each line that chooses its palette and mode."),
      ("Super Hi-Res", "The Apple IIgs’s graphics screen: 320×200 or 640×200 pixels with palettes of 16 colours from 4,096."),
      ("Volume name", "The name of a disk. Every system limits its length and characters."),
    ]
    b = row("", p("Words used in this guide.", "lead"))
    for t, d in terms:
        b += row(f"<b>{t}</b>", p(d))
    return chapter_html(ch, "Words used in this guide", b)

def appendix_d():
    ch = Chapter("appD", "D", "Credits and Licences")
    TOC[-1] = (1, "appD", "D", "Credits and Licences")
    b = row("", p("BitPast is the work of Walter Tengler, with the help of the people and projects below.", "lead"))
    b += row("<b>b2d</b>", p("The Apple II conversions are made by b2d (BMP2DHR) by Bill Buckels, built into BitPast with changes for modern macOS. See appleoldies.ca/bmp2dhr."))
    b += row("<b>Fonts</b>", p("The retro appearances use the Print Char 21 and Shaston bitmap fonts included with BitPast."))
    b += row("<b>Photographs</b>", p("The sample photographs in this guide are from Pixabay and are used under the Pixabay Content License: the bee-eater by davidclode, Nyhavn in Copenhagen by ductinh91, the hot-air balloon by guojinliang4104, the toucan by hbieser, the carnival dancer by makabera, the colour pencils by margaret8, the popsicles by motion_vfx_tlx, the flowers by naturerelax and the rainbow by sergiovisor_ph."))
    b += row("<b>Trademarks</b>", p("Apple II, Apple IIgs and Macintosh are trademarks of Apple Inc. Amiga, Commodore 64, VIC-20, Plus/4, Atari 800, Atari ST, ZX Spectrum, Amstrad CPC, MSX, BBC Micro, IBM PC, TRS-80 and other names are trademarks of their respective owners. BitPast is an independent app and is not affiliated with or endorsed by any of them."))
    b += row("<b>Licence</b>", p("BitPast’s user interface code is provided under the MIT License. The source code is at github.com/portwally/BitPast."))
    b += row("<b>This guide</b>", p("Set in Apple Garamond, Myriad-style headings and Geneva, in the manner of the printed guides of the early 1990s. All pictures of converted graphics, and all screenshots, were made with BitPast version 4.6."))
    return chapter_html(ch, "Thanks, sources and licences", b)
