"""Front matter and chapters 1–3."""
from lib import *
from systems import SYSTEMS, ORDER, fact

VERSION = "4.6"
DATE = "November 2026"

def default_index(sysid):
    for o in OPTIONS[sysid]["options"]:
        if o["key"] == "mode":
            return o["values"].index(o["default"])
    return 0

def cover():
    return (f'<section class="cover"><div class="top">for macOS</div><h1>BitPast</h1><div class="sub">User’s Guide and Technical Reference</div>'
            f'<div class="tagl">Turn modern pictures into graphics for fifteen classic computers</div>'
            f'<div class="art">{macwin("sys-AppleIIGS", "BitPast", "BitPast converting a photograph for the Apple IIgs")}</div>'
            f'<div class="foot">Version {VERSION}</div>{stripe()}</section>')

def titlepage():
    return (f'<section class="front"><div class="titlepage"><div><h1>BitPast</h1><div class="t2">User’s Guide and Technical Reference</div>'
            f'<p style="margin-top:6mm;font-family:var(--sans);font-size:10pt;letter-spacing:.08em">Version {VERSION} · {DATE}</p></div>'
            '<div class="legal">'
            '<p><b>Written by</b> Walter Tengler.</p>'
            '<p>© 2026 Walter Tengler. BitPast’s user interface code is released under the MIT License. The source code and releases are at github.com/portwally/BitPast.</p>'
            '<p>Apple II, Apple IIgs and Macintosh are trademarks of Apple Inc. Amiga, Commodore 64, VIC-20, Plus/4, Atari 800, Atari ST, ZX Spectrum, Amstrad CPC, MSX, BBC Micro, IBM PC, TRS-80 and other names are trademarks of their respective owners. '
            'BitPast is an independent app and is not affiliated with or endorsed by any of them. This guide is set in its own style and is not an Apple publication.</p>'
            '<p>The sample photographs are from Pixabay and are used under the Pixabay Content License; see Appendix D for the photographers. '
            'The pictures of the old computers’ graphics were made by BitPast itself.</p>'
            '<p>Every effort has been made to make this guide accurate. The settings, modes and file sizes it lists were taken from BitPast version 4.6 itself.</p></div></div></section>')

def about():
    body = (f'<div class="row h2row"><div class="margin"></div><h2>About This Guide</h2></div>'
            + row("", p("This guide explains how to use BitPast, and lists what it can do: every system it supports, every graphics mode and every setting. It is meant to be read from the beginning, and used afterwards as a reference.", "lead"))
            + row("<b>If you are new</b>", p("Read Chapters 1 to 3, then try the exercise in Chapter 2. The rest can wait until you need it."))
            + row("<b>If you want a system</b>", p("Chapter 6 has a section for each of the fifteen systems, with every mode, its picture, its file and its settings. Appendix A lists the files; Appendix B shows the colour palettes."))
            + row("<b>Conventions</b>", p("Names you see on the screen — menu items, buttons and pop-up menus — are set in this typeface: [[Create Disk]]. File names and extensions look like this: {{.shr}}. Keyboard shortcuts are shown with symbols: ^^⇧⌘1^^ means hold Shift and Command and press 1.")
                     + '<p>Three kinds of note appear in the margin:</p>')
            + note("note", "A **Note** adds something that is good to know.")
            + note("important", "An **Important** note warns you about something that could lose work or surprise you.")
            + note("tip", "A **Tip** is a suggestion that makes the result better or the work quicker."))
    return f'<section class="front">{body}</section>'

# ---------------------------------------------------------------- chapter 1
def ch1():
    ch = Chapter("ch1", 1, "Welcome to BitPast")
    b = ""
    b += row("", p("BitPast converts ordinary pictures — photographs, drawings, screenshots — into graphics for fifteen classic home computers. It does not simply shrink a picture and reduce its colours. Each conversion follows the rules of the real hardware.", "lead"))
    b += row("", ps("A ZX Spectrum picture may use only two colours in every 8×8 cell. A Commodore 64 multicolor picture has four colours in each 4×8 cell. An Apple IIgs picture can use a different palette on every line of the screen. BitPast makes these choices for you, shows the result at once, and saves it in a file that the machine or an emulator can load."))
    b += ch.h2("What BitPast does", "ch1-what")
    b += row("<b>Convert</b>", p("Add pictures, choose a system, and the preview shows how the picture will look on that machine. Every change to a setting converts the picture again."))
    b += row("<b>Save</b>", p("Save the preview as PNG, JPEG, GIF or TIFF to share it, or save the machine’s native file — a {{.shr}} for the Apple IIgs, a {{.kla}} for the Commodore 64, a {{.scr}} for the ZX Spectrum — to load on the real thing."))
    b += row("<b>Disk</b>", p("Put a whole set of converted pictures onto a disk image for the system — {{.d64}}, {{.adf}}, {{.po}}, {{.atr}} and more — that an emulator, a floppy emulator or a disk-copying tool can use."))
    tiles = []
    for sid in ORDER:
        tiles.append((f"m-{sid}-{default_index(sid)}", SYSTEMS[sid]["name"], ""))
    b += '<div class="figrow wide"><div class="fig">' + pxgrid(tiles, cols=5) + "</div>" + \
         f'<div class="cap"><b>Figure {fig_number()}</b>One photograph, fifteen machines. Each picture was converted in the system’s default mode, with default settings.</div></div>'
    b += ch.h2("How a conversion works", "ch1-how")
    b += row("", p("Every conversion passes the picture through the same six stages. Knowing them helps you decide which setting to change when a result is not what you hoped for."))
    stages = [("1", "Picture", "Any picture macOS can open: JPEG, PNG, GIF, TIFF, BMP, HEIC and more."),
              ("2", "Place", "Fit, Aspect and the position decide how the picture fills the screen."),
              ("3", "Prepare", "Filters, contrast, saturation and gamma make the picture suit a small palette."),
              ("4", "Colours", "BitPast chooses the best colours the hardware allows, often for each cell or line."),
              ("5", "Dither", "Patterns of dots fake the colours in between."),
              ("6", "Save", "A preview picture, the native file, or a whole disk image.")]
    b += '<div class="pipe">' + "".join(f'<div class="st"><div class="k">Stage {k}</div><div class="h">{h}</div><div class="d">{esc(d)}</div></div>' for k, h, d in stages) + "</div>"
    b += row("", ps("Conversions run in the background, so the window stays responsive while a picture is worked out. When a picture takes a moment, a small [[Converting…]] indicator appears over the preview.",
                    "Only the preview is a picture. The native file contains the screen exactly as the machine’s hardware stores it — bitmaps, colour attributes, palettes — in the layout the machine expects."))
    b += ch.h2("What you need", "ch1-need")
    b += row("<b>A Mac</b>", p("BitPast needs macOS 15.7 or later."))
    b += row("<b>Pictures</b>", p("Any picture macOS can read. Pictures with strong shapes and clear colours convert best, especially for the systems with the smallest palettes."))
    b += row("<b>Somewhere to try the files</b>", p("An emulator for the system you chose, or the real machine with a way to get files onto it. The previews need nothing."))
    b += row("<b>Where to get it</b>", p("BitPast is available from the Mac App Store. Releases are also published at github.com/portwally/BitPast."))
    b += ch.h2("The fifteen systems at a glance", "ch1-glance")
    rows = [
      ["Apple II", "1977", "280×192, 560×192; Lo-Res 40×48, 80×48", "6 or 16", ".BIN .A2FC .A2FM .SLO .DLO"],
      ["Apple IIgs", "1986", "320×200, 640×200", "up to 3,200", ".SHR .3200"],
      ["Amiga 500", "1987", "320×256, 320×512", "32 of 4,096; HAM6", ".iff"],
      ["Amiga 1200", "1992", "320×256 to 640×512", "256; HAM8 262,144", ".iff"],
      ["Amstrad CPC", "1984", "160×200, 320×200", "16 or 4 of 27", ".scr"],
      ["Atari 800", "1979", "80 to 320 × 192", "2 to 16 of 128", ".gr8 .gr9 .gr10 .gr11 .gr15"],
      ["Atari ST", "1985", "320×200, 640×200, 640×400", "16, 4, 2", ".pi1 .pi2 .pi3"],
      ["BBC Micro", "1981", "160 to 640 × 256", "2, 4 or 8", ".bbc"],
      ["Commodore 64", "1982", "160×200, 320×200, 40×25", "16", ".kla .art .prg"],
      ["MSX", "1983", "256×192, 256×212", "16, 16 of 512, 256", ".sc2 .sc5 .sc8"],
      ["IBM PC", "1981", "320×200; text 80×25, 132×50", "4, 16, 256", ".pcx .ans"],
      ["Commodore Plus/4", "1984", "160×200, 320×200", "128", ".prg"],
      ["TRS-80 CoCo", "1980", "128×96 to 640×200", "2, 4 or 16", ".bin .cm3"],
      ["VIC-20", "1980", "88×184, 176×184", "16", ".prg"],
      ["ZX Spectrum", "1982", "256×192", "15", ".scr"],
    ]
    rows = [[f'<span class="nm">{a}</span>', b_, c, d, f'<span class="file">{e_}</span>'] for a, b_, c, d, e_ in rows]
    b += table(["System", "Introduced", "Screen sizes", "Colours", "Native files"], rows, cls="tight", widths=["19%", "11%", "30%", "19%", "21%"])
    return chapter_html(ch, "Turn today’s pictures into the graphics of yesterday’s computers", b)

# ---------------------------------------------------------------- chapter 2
def ch2():
    ch = Chapter("ch2", 2, "Getting Started")
    b = ""
    b += row("", p("This chapter takes you from installing BitPast to saving your first picture. It takes about five minutes.", "lead"))
    b += ch.h2("Installing BitPast", "ch2-install")
    b += row("<b>From the App Store</b>", p("Open the Mac App Store, search for BitPast and click [[Get]]. BitPast appears in your Applications folder."))
    b += row("<b>From GitHub</b>", p("Download {{BitPast.zip}} from the Releases page at github.com/portwally/BitPast, open it, and drag BitPast into your Applications folder."))
    b += note("note", ps("A copy downloaded from GitHub may not be notarized by Apple, so macOS can show a warning the first time: the app “cannot be opened because it is from an unverified developer.” Close the warning, then Control-click the BitPast icon in the Applications folder, choose [[Open]] from the menu and click [[Open]] again. macOS remembers your decision.",
                         "If that does not work, open Terminal and type {{xattr -cr /Applications/BitPast.app}}, then try again."))
    b += ch.h2("Your first conversion", "ch2-first")
    b += step("1", "**Open BitPast.** The window is empty: the Image Browser on the left says “Drag Images Here”.")
    b += step("2", "**Add pictures.** Drag one or more pictures from the Finder into the Image Browser, or click the [[+]] button above it and choose files. Each picture appears as a thumbnail.")
    b += step("3", "**Select a picture.** Click a thumbnail. A blue frame marks the picture you are working on, and the preview shows its conversion.")
    b += step("4", "**Choose a system.** Click one of the fifteen icons across the top of the window — for example [[Apple IIgs]]. The preview changes at once.")
    b += step("5", "**Choose a mode and adjust.** The panel at the bottom holds the settings for the system. Try the [[Display Mode]] pop-up menu, then [[Dithering Algo]]. Each change converts the picture again.")
    b += step("6", "**Save.** Click [[Save Image…]] in the Actions column. Choose [[PNG]] for a picture you can share, or [[Native Format]] for the file the machine loads.")
    b += figrow(macwin("sys-AppleIIGS", "BitPast", "BitPast with the Apple IIgs selected"), "BitPast with a picture selected and the Apple IIgs chosen.", "", wide=True)
    b += ch.h2("What you just made", "ch2-made")
    b += row("", ps("The picture in the preview is what the machine would show on its screen, scaled up. The panel at the bottom left, headed [[Output]], tells you what the file contains: the system, the mode, the size in pixels, the number of colours, the file format and the file size.",
                   "The file you saved with [[Native Format]] is not an ordinary picture. It is the screen as the machine stores it, and only the machine, an emulator or a viewer for that system can show it. The PNG is an ordinary picture you can open anywhere."))
    b += note("tip", "Convert the same picture for several systems, one after another. The picture stays selected when you change system, and each system remembers its own settings while BitPast is open. This is the quickest way to learn what each machine does to a picture.")
    return chapter_html(ch, "From installation to your first saved picture", b)

# ---------------------------------------------------------------- chapter 3
def ch3():
    ch = Chapter("ch3", 3, "The BitPast Window")
    b = ""
    b += row("", p("BitPast has one main window. This chapter names its parts, and the chapters that follow refer to them.", "lead"))
    callouts = [(1, 95.8, 4.0), (2, 15.0, 61.9), (3, 20.3, 10.7), (4, 71.6, 10.7), (5, 32.5, 44.5), (6, 97.6, 16.8), (7, 11.2, 78.9), (8, 55.3, 78.8), (9, 96.5, 79.0)]
    b += '<div class="figrow wide"><div class="fig">' + macwin("sys-AppleIIGS", "BitPast", "The BitPast window", callouts) + "</div>" + \
         f'<div class="cap"><b>Figure {fig_number()}</b>The parts of the BitPast window.</div></div>'
    b += legend([(1, "**System bar.** Fifteen icons, one for each system."),
                 (2, "**Image Browser.** The pictures you have added."),
                 (3, "**Image Browser tools.** Select all, remove, lock settings, add."),
                 (4, "**Preview tools.** Palette editor (Apple IIgs only), flip, histogram."),
                 (5, "**Preview.** The converted picture."),
                 (6, "**Zoom.** Magnify or reduce the preview."),
                 (7, "**Info panel.** Facts about the picture and the result."),
                 (8, "**Settings panel.** The controls for the selected system."),
                 (9, "**Actions.** Save the picture, or create a disk image.")])
    b += ch.h2("The system bar", "ch3-bar")
    b += row("", ps("The bar across the top shows an icon for each of the fifteen systems. Click one to convert for it. The selected system is highlighted, and the settings panel, the preview and the Output facts change to match.",
                    "Each system keeps its own settings while BitPast is open, so you can move between systems without losing what you set. Pictures with locked settings (Chapter 4) are released when you change system."))
    b += row("<b>Keyboard</b>", p("The [[System]] menu lists the same fifteen systems, each with a shortcut: ^^⇧⌘1^^ to ^^⇧⌘0^^ for the first ten, then ^^⇧⌘P^^, ^^⇧⌘L^^, ^^⇧⌘T^^, ^^⇧⌘V^^ and ^^⇧⌘Z^^. Chapter 10 has the full list."))
    b += ch.h2("The Image Browser", "ch3-browser")
    b += row("", ps("The browser on the left holds every picture you have added, as thumbnails with their file names. The picture with the blue frame is the one shown in the preview. The small circle at the top right of each thumbnail selects it for batch work.",
                    "Four tools sit above the thumbnails: a checkbox that selects or deselects every picture, a trash can that removes the selected pictures, a padlock that locks the current settings for the selected picture, and [[+]], which adds pictures."))
    b += ch.h2("The preview", "ch3-preview")
    b += row("", ps("The preview shows the conversion of the selected picture. Above it, from left to right: [[Palette]] (Apple IIgs only), [[H-Flip]], [[V-Flip]] and [[Histogram]], then the zoom buttons. While a new conversion is worked out, a [[Converting…]] indicator appears over the old picture.",
                    "When Fit is set to something other than Stretch, you can drag the preview to choose which part of the picture shows. Chapter 4 explains how."))
    b += ch.h2("The info panel", "ch3-info")
    b += row("", p("The panel at the bottom left tells you about the picture and the result. Under [[Input]]: the file name, the size in pixels, the file size, the format and the colour depth. Under [[Output]]: the system, the mode, the size, the number of colours, the file format and the file size of the native file."))
    b += ch.h2("The settings panel", "ch3-settings")
    b += row("", ps("The wide panel in the middle holds the settings for the selected system. They are arranged in groups: the mode first, then dithering, then contrast and filters, then colour. The list is different for every system, because every machine has its own choices; Chapters 5 and 6 describe them all.",
                    "Some controls appear only when they matter. For example, [[SCB Mode]] shows only in the Apple IIgs’s 256-colour mode, and [[Aspect]] shows only when Fit is not Stretch."))
    b += ch.h2("The Actions column", "ch3-actions")
    b += row("", ps("[[Save Image…]] is a menu. It saves the preview as PNG, JPG, GIF or TIFF, or the machine’s file as [[Native Format]]. When several pictures are selected it changes to [[Save 3 Images…]] (or however many you selected) and saves them all.",
                    "[[Create Disk]] opens a sheet for making a disk image of the system’s files (Chapter 9)."))
    b += ch.h2("The menus", "ch3-menus")
    b += row("<b>System</b>", p("Switch to any of the fifteen systems, with a shortcut for each."))
    b += row("<b>Help</b>", p("[[Graphics Mode Guide]] (^^⌘?^^) opens a window describing every system, mode and setting — the same information as this guide, inside the app. [[Visit GitHub Page]] opens the project page in your browser."))
    b += row("<b>Settings</b>", p("Choose [[BitPast ▸ Settings…]] (^^⌘,^^) to change the appearance of the app (Chapter 10)."))
    return chapter_html(ch, "A tour of everything you see", b)
