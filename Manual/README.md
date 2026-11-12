# BitPast User's Guide

- `BitPast-Manual.pdf` — the printable guide (A4, 91 pages)
- `BitPast-Manual.html` — the same guide for the screen (needs the `assets/` folder and is set in Apple Garamond, Optima and Geneva if installed)

## Rebuilding

```
python3 tools/build.py        # needs Google Chrome and poppler (pdftotext)
```

`tools/build.py` writes the HTML, prints it to PDF with Chrome, finds the page of every heading and builds the table of contents from that.
The text lives in `tools/chapters_*.py` and `tools/systems.py`; the look is in `manual.css`.

## Pictures

`assets/px` (pictures of converted graphics) and `assets/shots` (screenshots) were made with BitPast 4.7.
`tools/capture/*.swift.txt` are the temporary test files that made them (copy them into `BitPastTests/`, add photos in a `ManualSrc` folder, run with `TEST_RUNNER_BITPAST_MANUAL=1`),
and `tools/process_assets.swift` turns the raw captures into the files in `assets/`.
Facts about the options and file sizes are in `tools/data/`.
