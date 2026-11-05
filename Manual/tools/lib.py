"""Helpers for building the BitPast manual: small HTML builders and the table of contents registry."""
import html, json, os, re

HERE = os.path.dirname(os.path.abspath(__file__))
MANUAL = os.path.dirname(HERE)
ASSETS = os.path.join(MANUAL, "assets")
DATA = os.path.join(HERE, "data")

OPTIONS = {m["id"]: m for m in json.load(open(os.path.join(DATA, "options.json")))}
FACTS = json.load(open(os.path.join(DATA, "facts.json")))
PALETTES = json.load(open(os.path.join(DATA, "palettes.json")))
HELP = json.load(open(os.path.join(DATA, "help.json")))

# ---------- inline markup ----------
def esc(s):
    return html.escape(s, quote=False)

def fmt(s):
    """Plain text with light markup: [[Menu Item]] interface name, {{file.ext}} monospace, **bold**, __italic__, ^^key^^ keycap."""
    s = esc(s)
    s = re.sub(r"\[\[(.+?)\]\]", r'<span class="ui">\1</span>', s)
    s = re.sub(r"\{\{(.+?)\}\}", r'<span class="file">\1</span>', s)
    s = re.sub(r"\*\*(.+?)\*\*", r"<b>\1</b>", s)
    s = re.sub(r"__(.+?)__", r"<i>\1</i>", s)
    s = re.sub(r"\^\^(.+?)\^\^", r'<span class="keycap">\1</span>', s)
    return s

def p(s, cls=""):
    return f'<p class="{cls}">{fmt(s)}</p>' if cls else f"<p>{fmt(s)}</p>"

def ps(*paras):
    return "\n".join(p(x) for x in paras)

def bullets(items, cls="bullets"):
    return f'<ul class="{cls}">' + "".join(f"<li>{fmt(i)}</li>" for i in items) + "</ul>"

def indent(html_):
    return f'<div class="row"><div class="main" style="grid-column:2">{html_}</div></div>'

def row(margin, main):
    return f'<div class="row"><div class="margin">{margin}</div><div class="main">{main}</div></div>'

# ---------- table of contents registry ----------
TOC = []          # (level, key, number, title)
FIG = {"n": 0, "ch": 0}

def mark(key):
    return f'<span class="mark">§§{key.replace("-", "_")}§§</span>'

class Chapter:
    def __init__(self, key, num, title):
        self.key, self.num, self.title = key, num, title
        self.sec = 0
        FIG["ch"] = num
        FIG["n"] = 0
        TOC.append((1, key, str(num), title))

    def head(self, sub=""):
        return (f'<div class="chapter-head"><div class="num">{self.num}</div><div class="ttl">'
                f'<div class="label">Chapter {self.num}</div><h1>{mark(self.key)}{esc(self.title)}</h1>'
                + (f'<div class="sub">{esc(sub)}</div>' if sub else "") + "</div></div>")

    def h2(self, title, key=None, toc=True):
        self.sec += 1
        key = key or f"{self.key}-s{self.sec}"
        num = f"{self.num}.{self.sec}"
        if toc:
            TOC.append((2, key, num, title))
        return (f'<div class="row h2row"><div class="margin">{num}</div><h2>{mark(key)}{fmt(title)}</h2></div>')

def chapter_html(ch, sub, body, extra_class=""):
    return (f'<section class="chapter c{ch.num} {extra_class}">{ch.head(sub)}{body}</section>')

# ---------- figures ----------
def fig_number():
    FIG["n"] += 1
    return f'{FIG["ch"]}-{FIG["n"]}'

def find_px(name):
    for ext in ("png", "jpg"):
        path = os.path.join(ASSETS, "px", f"{name}.{ext}")
        if os.path.exists(path):
            return f"assets/px/{name}.{ext}"
    raise FileNotFoundError(name)

def shot_src(name):
    for ext in ("jpg", "png"):
        path = os.path.join(ASSETS, "shots", f"{name}.{ext}")
        if os.path.exists(path):
            return f"assets/shots/{name}.{ext}"
    raise FileNotFoundError(name)

def macwin(name, title="BitPast", alt="", callouts=None, dialog=False):
    """A screenshot in a classic Macintosh window. callouts: [(n, x%, y%)]."""
    marks = "".join(f'<span class="callout" style="left:{x:.2f}%;top:{y:.2f}%">{n}</span>' for n, x, y in (callouts or []))
    return (f'<div class="macwin{" dialog" if dialog else ""}"><div class="bar"><span class="box l"></span><span class="t">{esc(title)}</span><span class="box r"></span></div>'
            f'<div class="shot-wrap"><img src="{shot_src(name)}" alt="{esc(alt)}">{marks}</div></div>')

def figrow(fig, title, text, wide=False):
    n = fig_number()
    cap = f'<div class="cap"><b>Figure {n}</b>{fmt(title)}' + (f"<br>{fmt(text)}" if text else "") + "</div>"
    return f'<div class="figrow{" wide" if wide else ""}"><div class="fig">{fig}</div>{cap}</div>'

def px(name, title, sub="", cls=""):
    src = find_px(name)
    return (f'<figure><img class="px" src="{src}" alt="{esc(title)}"><figcaption><b>{fmt(title)}</b>'
            + (f"<span>{fmt(sub)}</span>" if sub else "") + "</figcaption></figure>")

def pxgrid(items, cols=3):
    return f'<div class="pxgrid c{cols}">' + "".join(px(*i) if isinstance(i, tuple) else i for i in items) + "</div>"

def legend(items):
    return '<ol class="legend">' + "".join(f'<li><span class="c">{n}</span>{fmt(t)}</li>' for n, t in items) + "</ol>"

# ---------- steps, notes, tables ----------
def step(n, text, extra=""):
    return f'<div class="step"><div class="n">{n}</div><div class="main">{fmt(text) if not text.startswith("<") else text}{extra}</div></div>'

def note(kind, body_html, tag=None):
    tag = tag or {"note": "Note", "important": "Important", "tip": "Tip"}[kind]
    if not body_html.startswith("<"):
        body_html = p(body_html)
    return f'<div class="note {kind}"><div class="tag">{tag}</div><div class="body">{body_html}</div></div>'

def table(headers, rows, cls="", widths=None, right=()):
    cols = ""
    if widths:
        cols = "<colgroup>" + "".join(f'<col style="width:{w}">' for w in widths) + "</colgroup>"
    th = "".join(f'<th class="{"r" if i in right else ""}">{fmt(h)}</th>' for i, h in enumerate(headers))
    body = ""
    for r in rows:
        body += "<tr>" + "".join(f'<td class="{"r" if i in right else ""}">{c if str(c).startswith("<") else fmt(str(c))}</td>' for i, c in enumerate(r)) + "</tr>"
    return f'<table class="{cls}">{cols}<thead><tr>{th}</tr></thead><tbody>{body}</tbody></table>'

def spec(items):
    return '<div class="spec"><dl>' + "".join(f"<dt>{esc(k)}</dt><dd>{fmt(v)}</dd>" for k, v in items) + "</dl></div>"

def stripe():
    return '<div class="stripe"><i></i><i></i><i></i><i></i><i></i><i></i></div>'
