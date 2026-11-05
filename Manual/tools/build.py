"""Builds BitPast-Manual.html and BitPast-Manual.pdf.  Usage: python3 build.py"""
import os, re, subprocess, sys
import lib
from lib import *
import chapters_a as A, chapters_b as B, chapters_c as C

CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
HTML = os.path.join(MANUAL, "BitPast-Manual.html")
PDF = os.path.join(MANUAL, "BitPast-Manual.pdf")

def toc_html(pages):
    out = '<section class="front"><div class="row h2row"><div class="margin"></div><h2>Contents</h2></div><ul class="toc">'
    for level, key, num, title in lib.TOC:
        pg = pages.get(key.replace("-", "_"), "")
        if level == 1:
            label = "Appendix " + num if not num.isdigit() else num
            out += f'<li class="ch"><span class="n">{"" if not num.isdigit() else num}</span><span class="t">{esc(("Appendix " + num + "  ") if not num.isdigit() else "")}{esc(title)}</span><span class="dots"></span><span class="pg">{pg}</span></li>'
        else:
            cls = "se sy" if key.startswith("sys-") else "se"
            out += f'<li class="{cls}"><span class="t">{esc(num)}&nbsp;&nbsp;{esc(title)}</span><span class="dots"></span><span class="pg">{pg}</span></li>'
    return out + "</ul></section>"

def page_css():
    css = ""
    head = "font-family:'Myriad Pro','Optima',sans-serif; font-size:8pt; letter-spacing:.14em; text-transform:uppercase; vertical-align:bottom; padding-bottom:5mm;"
    for level, key, num, title in lib.TOC:
        if level == 1:
            name = key.replace("ch", "c") if key.startswith("ch") else key
            label = f"{num}&nbsp; {title}" if num.isdigit() else f"Appendix {num} · {title}"
            label = label.replace("&nbsp;", "\\00a0")
            css += f'@page {name}:left {{ @top-left {{ content: "{label}"; {head} }} }}\n@page {name}:right {{ @top-right {{ content: "{label}"; {head} }} }}\n.chapter.{name} {{ page: {name}; }}\n'
    for i, sid in enumerate(C.ORDER, 1):
        label = f"6 The Systems · {C.SYSTEMS[sid]['name']}".replace("&", "&amp;")
        css += f'@page s{i}:left {{ @top-left {{ content: "{label}"; {head} }} }}\n@page s{i}:right {{ @top-right {{ content: "{label}"; {head} }} }}\n.sys.sys{i} {{ page: s{i}; }}\n'
    css += "@page plain:left, @page plain:right { }\n"
    css += "@page plain:left { @bottom-left { content: none; } @bottom-right { content: none; } }\n@page plain:right { @bottom-left { content: none; } @bottom-right { content: none; } }\n.front.plain { page: plain; }\n"
    return css

def assemble(pages):
    lib.TOC.clear()
    lib.FIG.update({"n": 0, "ch": 0})
    body_chapters = [A.ch1(), A.ch2(), A.ch3(), B.ch4(), B.ch5(), C.ch6(), C.ch7(), C.ch8(), C.ch9(), C.ch10(), C.ch11(), C.appendix_a(), C.appendix_b(), C.appendix_c(), C.appendix_d()]
    front = A.cover() + A.titlepage().replace('<section class="front">', '<section class="front plain">') + toc_html(pages) + A.about()
    css = open(os.path.join(MANUAL, "manual.css")).read()
    html_ = (f'<!DOCTYPE html><html lang="en"><head><meta charset="utf-8"><title>BitPast User’s Guide and Technical Reference</title>'
             f'<style>{css}\n{page_css()}</style></head><body>{front}{"".join(body_chapters)}</body></html>')
    open(HTML, "w").write(html_)

def render():
    cmd = [CHROME, "--headless=new", "--disable-gpu", "--no-pdf-header-footer", "--run-all-compositor-stages-before-draw", "--virtual-time-budget=20000",
           f"--print-to-pdf={PDF}", "file://" + HTML]
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=600)
    if not os.path.exists(PDF):
        print(r.stderr[-1500:]); sys.exit("Chrome did not produce a PDF")

def find_pages():
    text = subprocess.run(["pdftotext", "-raw", PDF, "-"], capture_output=True, text=True).stdout
    pages = {}
    for n, page in enumerate(text.split("\f"), 1):
        for key in re.findall(r"§§([^§]+)§§", page):
            pages.setdefault(key, n)
    return pages

def strip_markers():
    s = open(HTML).read()
    open(HTML, "w").write(re.sub(r'<span class="mark">§§[^§]*§§</span>', "", s))

if __name__ == "__main__":
    assemble({})
    render()
    pages = find_pages()
    print("pass 1:", len(pages), "markers found")
    assemble(pages)
    render()
    pages2 = find_pages()
    if pages2 != pages:
        print("page numbers moved; running another pass")
        assemble(pages2); render(); pages2 = find_pages()
    assemble(pages2)           # final html with the correct numbers
    render()                    # final pdf (markers are still in the pdf as invisible text)
    info = subprocess.run(["pdfinfo", PDF], capture_output=True, text=True).stdout
    print([l for l in info.splitlines() if l.startswith(("Pages", "Page size", "File size"))])
    strip_markers()
