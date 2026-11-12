"""Chapters 4 and 5."""
from lib import *
from systems import SYSTEMS, ORDER

def ch4():
    ch = Chapter("ch4", 4, "Working with Pictures")
    b = ""
    b += row("", p("This chapter covers everything you can do with a picture before and after it is converted: adding and selecting pictures, looking at the result closely, and choosing how the picture fills the screen.", "lead"))
    b += ch.h2("Adding pictures", "ch4-add")
    b += row("", ps("Drag pictures from the Finder into the Image Browser. You can also click [[+]] above the browser, [[Open Images…]] in the empty browser, or choose [[File ▸ Open Images…]] (^^⌘O^^), and choose files. [[File ▸ Open Recent]] brings back any of the last ten pictures you opened. Add as many as you like: they appear as thumbnails, and the first picture you add is selected automatically.",
                    "BitPast opens any picture format macOS can read, such as JPEG, PNG, GIF, TIFF, BMP and HEIC. Adding a picture never changes the original file."))
    b += ch.h2("Selecting and removing pictures", "ch4-select")
    b += row("", ps("Click a thumbnail to show it in the preview. That is the picture you are working on, and it has a blue frame.",
                    "To work on several pictures at once — to save them together, or to put them on a disk — use the small circle at the top right of each thumbnail. Click a circle to select that picture. Hold Shift and click another thumbnail to select every picture between the two. The checkbox above the browser selects or deselects all of them."))
    b += row("<b>Remove</b>", p("The trash can above the browser removes the selected pictures from BitPast. It does not delete the files from your Mac."))
    b += ch.h2("Looking closely", "ch4-look")
    b += ch.h2("Zooming and panning", "ch4-zoom", toc=False).replace('class="row h2row"', 'class="row h2row" style="display:none"') if False else ""
    b += row("<b>Zoom</b>", p("The magnifying-glass buttons at the right end of the preview toolbar change the size of the preview. At 100% the picture is fitted to the space available. The buttons step the magnification by 20% at a time, up to about 500%. When the picture is larger than the preview, scroll to move around it."))
    b += row("<b>Flip</b>", ps("[[H-Flip]] mirrors the picture left to right and [[V-Flip]] top to bottom. The flip is applied to the original picture before it is converted, so the saved file and any disk image are flipped too — not only the preview. A flipped picture’s button stays lit; click it again to undo the flip. The flip belongs to the picture, so other pictures are not affected, and it stays when you change settings or system."))
    b += row("<b>Histogram</b>", p("[[Histogram]] shows how the red, green and blue values (and, if you wish, the brightness) of the converted picture are spread. It is a good way to see how much of the range a small palette really uses. Click the letters [[R]], [[G]], [[B]] and [[L]] to show or hide a channel; close the panel with the × at its corner."))
    b += figrow(macwin("histogram", "BitPast", "The histogram", dialog=True), "The histogram of a converted picture.", "R, G and B show the colour channels; L shows brightness.")
    b += ch.h2("Fit, Aspect and position", "ch4-fit")
    b += row("", ps("Your picture and the machine’s screen rarely have the same shape. **Fit** decides what happens when they differ. It is available for every system.",))
    b += table(["Fit", "What it does"],
               [["<span class=\"nm\">Stretch</span>", "Fills the screen and ignores the shape of the picture. This is the default, and the only choice before BitPast 4.6."],
                ["<span class=\"nm\">Contain</span>", "Shows the whole picture, with black bars where it does not fill the screen."],
                ["<span class=\"nm\">Cover</span>", "Fills the screen and crops whatever sticks out."],
                ["<span class=\"nm\">None</span>", "Does not scale at all: one picture pixel for each screen pixel, centred, so you see only the middle part of a large picture."]],
               widths=["16%", "84%"])
    items = [("v-fit-Stretch", "Stretch", "The picture is squeezed to fit."), ("v-fit-Contain", "Contain", "The whole picture, with bars at the sides."),
             ("v-fit-Cover", "Cover", "The screen is filled; the top and bottom are cropped."), ("v-fit-None", "None", "One picture pixel per screen pixel.")]
    b += '<div class="figrow wide"><div class="fig">' + pxgrid(items, cols=4) + "</div>" + \
         f'<div class="cap"><b>Figure {fig_number()}</b>The four choices of Fit, with a tall picture on the Amiga 1200.</div></div>'
    b += ch.h3("Aspect") if hasattr(ch, "h3") else "<h3>Aspect</h3>"
    b += row("", ps("The pixels of old computers are not square. On an Atari ST in medium resolution, for example, each pixel is much taller than it is wide, because 640 pixels share a screen with only 200 lines. **Aspect** takes this into account whenever Fit is not Stretch.",
                    "With **Correct**, BitPast assumes the picture is shown on a 4:3 screen and shapes it so circles stay round. With **Ignore**, it treats the pixels as square. The Aspect control appears only when Fit is Contain, Cover or None."))
    items = [("v-aspect-Correct", "Correct", "The proportions are right on the real screen."), ("v-aspect-Ignore", "Ignore", "Pixels are treated as square, so on the real screen the picture comes out too narrow.")]
    b += '<div class="figrow wide"><div class="fig">' + pxgrid(items, cols=2) + "</div>" + \
         f'<div class="cap"><b>Figure {fig_number()}</b>Aspect on the Atari ST in medium resolution, with Fit set to Contain.</div></div>'
    b += "<h3>Choosing which part shows</h3>"
    b += row("", ps("When Fit is Contain, Cover or None, you can move the picture. Point at the preview: the cursor turns into an open hand. **Drag** the preview and the picture follows your mouse; when you let go, BitPast converts it again at the new position. **Double-click** the preview to centre the picture again.",
                    "Each picture keeps its own position, and the position is used when you save, when you export several pictures and when you make a disk image. With Stretch there is nothing to move, so dragging does nothing."))
    items = [("v-pos-top", "Top", "Dragged down."), ("v-pos-center", "Centre", "The default."), ("v-pos-bottom", "Bottom", "Dragged up.")]
    b += '<div class="figrow wide"><div class="fig">' + pxgrid(items, cols=3) + "</div>" + \
         f'<div class="cap"><b>Figure {fig_number()}</b>The same picture with Fit set to Cover, at three positions.</div></div>'
    b += note("important", "Moving a picture converts it again, and so does every other change of settings. On the Apple IIgs, changes made in the palette editor are lost when the picture is converted again, so make them last (Chapter 7).")
    b += ch.h2("Locking settings for one picture", "ch4-lock")
    b += row("", ps("Normally one set of settings applies to every picture. When you want one picture to keep its own settings — a dark photograph that needs more contrast than the others, say — you can **lock** them.",))
    b += step("1", "Select the picture and adjust the settings until the preview looks right.")
    b += step("2", "Click the padlock above the Image Browser. It turns orange, and the picture keeps these settings.")
    b += step("3", "Select another picture and adjust the settings for it; lock that one too if you wish.")
    b += step("4", "Save or export. Each locked picture is converted with its own settings; pictures that are not locked use the current settings.")
    b += row("", ps("To release a picture, select it and click the orange padlock again. Locked settings belong to the system you were using when you locked them: they apply only to that system, and they are released when you switch to another."))
    b += note("note", "A locked picture does not follow the settings panel. If a slider seems to do nothing, check whether the selected picture is locked.")
    b += ch.h2("Choosing and preparing pictures", "ch4-tips")
    b += bullets(["**Strong shapes win.** The smaller the palette, the more a picture needs clear shapes and contrast. A toucan on a dark background converts better than a distant landscape.",
                  "**Crop first, or use Cover.** A close crop puts more of the machine’s few pixels on the subject.",
                  "**Contrast and saturation are cheap fixes.** A flat picture gets muddy in a small palette: try CLAHE contrast and a little extra saturation before anything else.",
                  "**Size does not matter.** BitPast scales every picture to the machine’s screen, so a large original gives a better result than a small one, never a worse one.",
                  "**Compare systems.** Converting the same picture for several machines shows quickly which suits it."])
    return chapter_html(ch, "Adding, selecting, flipping, framing and locking", b)

def settings_matrix():
    keys = [("dither", "Dithering"), ("dither_amount", "Dither amount"), ("contrast", "Contrast"), ("filter", "Filter"), ("color_match", "Colour match"),
            ("pixel_merge", "Pixel merge"), ("saturation", "Saturation"), ("gamma", "Gamma"), ("preprocess", "Preprocessing")]
    short = {"AppleII": "II", "AppleIIGS": "GS", "Amiga500": "A5", "Amiga1200": "A12", "AmstradCPC": "CPC", "Atari800": "800", "AtariST": "ST", "BBCMicro": "BBC",
             "C64": "C64", "MSX": "MSX", "PC": "PC", "Plus4": "P/4", "TRS80CoCo": "CoCo", "VIC20": "V20", "ZXSpectrum": "ZX",
             "ColecoVision": "CV", "PET": "PET", "Atari2600": "2600"}
    rows = []
    for k, label in keys:
        r = [f'<span class="nm">{label}</span>']
        for sid in ORDER:
            has = any(o["key"] == k for o in OPTIONS[sid]["options"])
            r.append("●" if has else "")
        rows.append(r)
    heads = ["Setting"] + [short[s] for s in ORDER]
    t = table(heads, rows, cls="tight", widths=["19%"] + [f"{81 / len(ORDER):.2f}%"] * len(ORDER))
    return t.replace("<td class=\"\">●", '<td class="" style="text-align:center">●').replace("<th class=\"\">", '<th class="" style="text-align:center">')

def ch5():
    ch = Chapter("ch5", 5, "Settings Reference")
    b = ""
    b += row("", p("Most settings have the same name and the same effect on every system. This chapter describes them once. Settings that belong to one system only — the Apple II’s b2d options, the IIgs’s SCB Mode, the CoCo’s colour sets — are described in the section for that system in Chapter 6.", "lead"))
    b += ch.h2("Which settings each system has", "ch5-matrix")
    b += settings_matrix()
    b += row("", p("● means the system offers the setting. Fit and Aspect (Chapter 4) are offered by every system."))
    b += ch.h2("Dithering", "ch5-dither")
    b += row("", ps("A machine with few colours cannot show a smooth gradient, so it fakes one with __dithering__: it mixes dots of the colours it has, and your eye blends them. There are two families of method.",
                    "**Error diffusion** (Floyd-Steinberg, Atkinson, Jarvis-Judice-Ninke, Stucki, Burkes and others) works through the picture dot by dot. Each time it must round a colour, it spreads the error over the dots that are still to come. The result looks organic, a little like grain. **Ordered dithering** (Bayer, Blue Noise) lays a fixed pattern of thresholds over the picture. It is more regular, and in the machines that work in cells it often looks cleaner."))
    items = [("v-dither-None", "None", "Each dot takes the nearest colour."), ("v-dither-Floyd-Steinberg", "Floyd-Steinberg", "The classic all-round choice."),
             ("v-dither-Atkinson", "Atkinson", "Less diffusion; crisper, with a Macintosh look."),
             ("v-dither-Bayer 4x4", "Bayer 4×4", "A small, regular pattern."), ("v-dither-Bayer 8x8", "Bayer 8×8", "A larger pattern, smoother gradients."),
             ("v-dither-Blue 16x16", "Blue Noise 16×16", "Irregular, but without clumps.")]
    b += '<div class="figrow wide"><div class="fig">' + pxgrid(items, cols=3) + "</div>" + \
         f'<div class="cap"><b>Figure {fig_number()}</b>Six dithers on the Amstrad CPC in Mode 1, which has only four colours.</div></div>'
    b += table(["Algorithm", "Character"],
               [["<span class=\"nm\">None</span>", "No dithering; every dot takes the nearest colour."],
                ["<span class=\"nm\">Floyd-Steinberg</span>", "Classic error diffusion. A good all-round choice, and the usual one for photographs."],
                ["<span class=\"nm\">Atkinson</span>", "Diffuses less of the error, so highlights and shadows stay clean. It gives the classic early-Macintosh look."],
                ["<span class=\"nm\">Jarvis-Judice-Ninke</span>", "Spreads the error further; smoother gradients."],
                ["<span class=\"nm\">Stucki</span>", "Similar to Jarvis-Judice-Ninke, with a slightly different character."],
                ["<span class=\"nm\">Burkes</span>", "A faster variant of Stucki."],
                ["<span class=\"nm\">Noise</span>", "Random dither. Adds a film-grain texture. Because it is random, the same picture converts a little differently each time."],
                ["<span class=\"nm\">Bayer 2×2 to 16×16</span>", "Ordered pattern dither. Small sizes give a fine pattern; larger sizes give more levels but a more visible pattern."],
                ["<span class=\"nm\">Blue Noise 8×8, 16×16</span>", "Random-looking, but without clumps, so the texture is pleasing."]],
               widths=["28%", "72%"])
    b += row("", p("Not every system offers every method. The lists are in the settings tables in Chapter 6. The Apple II is converted by b2d, which has its own set of error-diffusion methods."))
    b += ch.h2("Dither amount", "ch5-amount")
    b += row("", p("**Dither Amount** (called **Dither Strength** on the Apple IIgs) controls how strongly the dither is applied. 0 turns it off; 1 is full strength. Around 0.5 is a subtle dither and is the default for most systems. Values above 1 can produce artefacts."))
    b += ch.h2("Contrast", "ch5-contrast")
    b += row("", p("Contrast enhancement stretches the tones of the picture before the colours are chosen, which helps flat, dull pictures. Three methods are offered:"))
    b += table(["Method", "What it does"],
               [["<span class=\"nm\">None</span>", "No adjustment."], ["<span class=\"nm\">HE</span>", "Histogram Equalization: a global contrast stretch."],
                ["<span class=\"nm\">CLAHE</span>", "Local adaptive contrast. Good for photographs."], ["<span class=\"nm\">SWAHE</span>", "Sliding-window adaptive contrast. Smooth results."]], widths=["16%", "84%"])
    items = [("v-contrast-None", "None", ""), ("v-contrast-HE", "HE", ""), ("v-contrast-CLAHE", "CLAHE", ""), ("v-contrast-SWAHE", "SWAHE", "")]
    b += '<div class="figrow wide"><div class="fig">' + pxgrid(items, cols=4) + "</div>" + \
         f'<div class="cap"><b>Figure {fig_number()}</b>The four contrast methods on the Amiga 500.</div></div>'
    b += ch.h2("Filters and preprocessing", "ch5-filter")
    b += row("", ps("Most systems have a **Filter** menu with four quick filters: **Lowpass** (a gentle blur), **Sharpen**, **Emboss** and **Edge** (edges emphasised on top of the picture). They are applied before the colours are chosen.",
                    "The Apple IIgs has a richer menu called **Preprocessing**, with seven filters and a control for each. Choose a filter and its control appears beside it."))
    items = [("v-prefilter-None", "None", ""), ("v-prefilter-Lowpass", "Lowpass", ""), ("v-prefilter-Median", "Median", ""), ("v-prefilter-Sharpen", "Sharpen", ""),
             ("v-prefilter-Sigma", "Sigma", ""), ("v-prefilter-Solarize", "Solarize", ""), ("v-prefilter-Emboss", "Emboss", ""), ("v-prefilter-Find Edges", "Find Edges", "")]
    b += '<div class="figrow wide"><div class="fig">' + pxgrid(items, cols=4) + "</div>" + \
         f'<div class="cap"><b>Figure {fig_number()}</b>The Apple IIgs’s preprocessing filters in 3,200-colour mode.</div></div>'
    b += table(["Filter", "Control", "What it does", "Good for"],
               [["<span class=\"nm\">Lowpass</span>", "none", "A simple blur that averages neighbouring pixels.", "Noise; softening harsh detail before conversion."],
                ["<span class=\"nm\">Median</span>", "Kernel Size: 3×3, 5×5, 7×7", "Replaces each pixel with the median of its neighbours; removes noise while keeping edges.", "Noisy or scanned pictures, JPEG artefacts."],
                ["<span class=\"nm\">Sharpen</span>", "Sharpen Amount: 0.2 to 2.5", "Unsharp masking: increases local contrast along edges. 1.0 is standard; above 2 can create halos.", "Soft or blurry pictures."],
                ["<span class=\"nm\">Sigma</span>", "Sigma Range: 5 to 50", "An edge-preserving blur (a bilateral filter): smooths similar colours but keeps sharp boundaries.", "Colour banding, smooth gradients, heavy compression."],
                ["<span class=\"nm\">Solarize</span>", "Threshold: 32 to 224", "Inverts the tones above the threshold, like the darkroom effect.", "Artistic effects."],
                ["<span class=\"nm\">Emboss</span>", "Emboss Depth: 0.3 to 2.0", "A raised, three-dimensional relief effect.", "Artistic effects, metallic looks."],
                ["<span class=\"nm\">Find Edges</span>", "Edge Sensitivity: 10 to 100", "Sobel edge detection; the result looks like line art. Low values find many edges, high values only the strong ones.", "Line-art extraction."],
                ["<span class=\"nm\">Edge</span> (Filter menu)", "none", "Sobel edge detection blended with the original, rather than replacing it.", "Making a flat picture look sharper."]],
               cls="tight", widths=["14%", "21%", "40%", "25%"])
    b += ch.h2("Colour matching", "ch5-match")
    b += row("", p("Whenever BitPast has to decide which palette colour is closest to a colour in your picture, it needs a way to measure “closest”. **Color Match** chooses the measure. The default, __Perceptive__, is right for most pictures."))
    b += table(["Method", "What it favours"],
               [["<span class=\"nm\">Euclidean</span>", "Plain distance in RGB. Simple and fast."], ["<span class=\"nm\">Perceptive</span>", "Weighted for how people see colour. Recommended."],
                ["<span class=\"nm\">Luma</span>", "Matches brightness first."], ["<span class=\"nm\">Chroma</span>", "Matches colour and saturation first."],
                ["<span class=\"nm\">Hue</span>", "Keeps the hue. Best for saturated pictures and for fixed, saturated palettes."], ["<span class=\"nm\">Mahalanobis</span>", "A statistical distance (offered by some systems)."]],
               widths=["20%", "80%"])
    items = [("v-match-Euclidean", "Euclidean", ""), ("v-match-Perceptive", "Perceptive", ""), ("v-match-Luma", "Luma", ""), ("v-match-Chroma", "Chroma", ""), ("v-match-Hue", "Hue", "")]
    b += '<div class="figrow wide"><div class="fig">' + pxgrid(items, cols=5) + "</div>" + \
         f'<div class="cap"><b>Figure {fig_number()}</b>Colour matching on the PC’s fixed 16-colour EGA palette.</div></div>'
    b += note("tip", "With a fixed, strongly saturated palette — EGA, the BBC Micro, the MSX1 screen — Hue or Chroma often keeps colours that Perceptive turns into grey.")
    b += ch.h2("Pixel merge", "ch5-merge")
    b += row("", p("In the modes where a pixel is twice as wide as it is high — C64 Multicolor, VIC-20 LowRes, Plus/4 Multicolor and CPC Mode 0 — two neighbouring dots of your picture become one machine pixel. **Pixel Merge** decides how: **Average** blends the two, for a smoother look; **Brightest** keeps the brighter one, which preserves highlights."))
    items = [("v-merge-Average", "Average", ""), ("v-merge-Brightest", "Brightest", "")]
    b += '<div class="figrow"><div class="fig"><div style="width:62%">' + pxgrid(items, cols=2) + "</div></div>" + \
         f'<div class="cap"><b>Figure {fig_number()}</b>Pixel Merge on the Commodore 64 in Multicolor mode.</div></div>'
    b += ch.h2("Saturation and gamma", "ch5-sat")
    b += row("<b>Saturation</b>", p("Changes the intensity of the colours before they are matched. 1 leaves them as they are. A small boost, 1.1 to 1.2, helps most pictures (the Apple IIgs starts at 1.10); beyond about 1.5 the colours become very strong and may clip."))
    b += row("<b>Gamma</b>", p("Changes the brightness of the mid-tones, not black and white. Below 1 brightens them, above 1 darkens them; useful values lie between 0.8 and 1.2."))
    return chapter_html(ch, "The controls that every system shares", b)
