#!/usr/bin/env python3
"""Traces each MicropolisCore content file the app carries
(packaging/content-used.txt) to its original in EA's 2008 GPL release,
micropolis-activity, and writes micropolis-core/CONTENT-PROVENANCE.md, which
ships with the app.

  python3 packaging/trace_content.py <micropolis-activity clone>

An image is traced when its pixels equal an XPM's; a sound when a WAV of the
same name lasts as long; a city when a .cty or scenario file has the same
bytes, or nearly; a string table when its lines equal a res/stri file's.
Anything else is listed as untraced, and the script fails, so it can be
looked at, dropped or swapped for the OLPC's own file. Needs Pillow; macOS's
afinfo reads the sounds' lengths.
"""
import hashlib, os, re, subprocess, sys
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CORE = os.path.join(ROOT, "micropolis-core")
# MicropolisCore's own text files: XML that holds the OLPC's text, by id.
TEXT = {
    "notices.xml": "MicropolisCore's own (GPLv3): the notices' layout, by id; their text is in strings_en-US.xml",
    "strings_en-US.xml": "MicropolisCore's own (GPLv3): the OLPC's text strings (res/stri.*) and notices, by id",
}
X11 = {"black": (0, 0, 0), "white": (255, 255, 255), "red": (255, 0, 0), "green": (0, 255, 0),
       "blue": (0, 0, 255), "yellow": (255, 255, 0), "gray": (190, 190, 190), "grey": (190, 190, 190)}


def read_xpm(path):
    """An XPM's pixels as a list of RGBA rows (None-coloured pixels clear)."""
    strings = re.findall(r'"((?:[^"\\]|\\.)*)"', open(path, encoding="latin-1").read())
    width, height, ncolors, cpp = (int(v) for v in strings[0].split()[:4])
    colors = {}
    for line in strings[1:1 + ncolors]:
        key, rest = line[:cpp], line[cpp:].split()
        value = rest[rest.index("c") + 1] if "c" in rest else rest[-1]
        if value.lower() == "none":
            colors[key] = (0, 0, 0, 0)
        elif value.startswith("#"):
            hexa = value[1:]
            step = len(hexa) // 3
            colors[key] = tuple(int(hexa[i * step:i * step + 2], 16) for i in range(3)) + (255,)
        else:
            colors[key] = X11.get(value.lower(), (255, 0, 255)) + (255,)
    rows = strings[1 + ncolors:1 + ncolors + height]
    return [[colors[row[x * cpp:x * cpp + cpp]] for x in range(width)] for row in rows]


def png_rows(path):
    image = Image.open(path).convert("RGBA")
    data = list(image.getdata())
    return [data[y * image.width:(y + 1) * image.width] for y in range(image.height)]


def as_column(rows, size=16):
    """Tile art laid out a tile to a row (16 to a row, as tiles.png has it)
    as one column of tiles, as the OLPC's tiles.xpm has it."""
    columns = len(rows[0]) // size
    out = []
    for tile in range(columns * (len(rows) // size)):
        x, y = (tile % columns) * size, (tile // columns) * size
        out.extend(row[x:x + size] for row in rows[y:y + size])
    return out


def compare(png, xpm):
    """None if the pixels differ; else how many are a shade off (conversion
    rounding: no channel off by more than 1 of 255)."""
    a, b = png_rows(png), read_xpm(xpm)
    if len(a) != len(b) and len(a[0]) * len(a) == len(b[0]) * len(b):
        a = as_column(a, len(b[0]))
    if len(a) != len(b) or len(a[0]) != len(b[0]):
        return None
    clear = lambda p: p if p[3] else (0, 0, 0, 0)
    off = 0
    for ra, rb in zip(a, b):
        for p, q in zip(ra, rb):
            p, q = clear(p), clear(q)
            if p != q:
                if max(abs(x - y) for x, y in zip(p, q)) > 1:
                    return None
                off += 1
    return off


def seconds(path):
    out = subprocess.run(["afinfo", path], capture_output=True, text=True).stdout
    found = re.search(r"estimated duration: ([\d.]+)", out)
    return float(found.group(1)) if found else None


def norm(name):
    return re.sub(r"[^a-z0-9]", "", name.lower())


def similarity(a, b):
    x, y = open(a, "rb").read(), open(b, "rb").read()
    if len(x) != len(y):
        return 0.0
    return sum(p == q for p, q in zip(x, y)) / len(x)


def trace(relative, ref):
    path = os.path.join(CORE, relative)
    folder, name = relative.split("/")[1], os.path.basename(relative)
    stem = os.path.splitext(name)[0]
    if folder == "images":
        candidates = [stem, stem.replace("sprite_", "obj").replace("_", "-")]
        for candidate in candidates:
            xpm = os.path.join(ref, "images", candidate + ".xpm")
            off = compare(path, xpm) if os.path.exists(xpm) else None
            if off == 0:
                return "images/%s.xpm, the same pixels" % candidate
            if off is not None:
                return "images/%s.xpm, the same pixels but %d a shade off (128 for 127)" % (candidate, off)
        return None
    if folder == "sounds":
        wavs = {norm(os.path.splitext(f)[0]): f for f in os.listdir(os.path.join(ref, "res/sounds"))}
        wav = wavs.get(norm(stem))
        if wav:
            a, b = seconds(path), seconds(os.path.join(ref, "res/sounds", wav))
            if a is not None and b is not None and abs(a - b) < 0.15:
                return "res/sounds/%s, %.2f s (the MP3 %.2f s)" % (wav, b, a)
        return None
    if folder == "cities":
        best = (0.0, "")
        for sub in ["cities", "res"]:
            for f in os.listdir(os.path.join(ref, sub)):
                if sub == "res" and not f.startswith("snro."):
                    continue
                score = similarity(path, os.path.join(ref, sub, f))
                best = max(best, (score, "%s/%s" % (sub, f)))
        if best[0] == 1.0:
            return "%s, the same bytes" % best[1]
        if best[0] > 0.99:
            return "%s, %.2f%% the same bytes" % (best[1], 100 * best[0])
        return None
    if folder == "data":
        if name in TEXT:
            return TEXT[name]
        found = re.match(r"stri\.(\d+)\.txt$", name)
        if found:
            original = os.path.join(ref, "res", "stri." + found.group(1))
            lines = lambda p: [l.strip() for l in open(p, encoding="latin-1").read().splitlines() if l.strip()]
            if os.path.exists(original) and lines(path) == lines(original):
                return "res/stri.%s, the same lines" % found.group(1)
        return None
    return None


def main():
    ref = sys.argv[1]
    used = [l.strip() for l in open(os.path.join(ROOT, "packaging/content-used.txt")) if l.startswith("content/")]
    rows, untraced = [], []
    for relative in used:
        origin = trace(relative, ref)
        digest = hashlib.sha256(open(os.path.join(CORE, relative), "rb").read()).hexdigest()
        rows.append("| `%s` | %s | `%s` |" % (relative, origin or "**untraced**", digest[:16]))
        if origin is None:
            untraced.append(relative)
    head = open(os.path.join(ROOT, "packaging/content-provenance-head.md")).read()
    with open(os.path.join(CORE, "CONTENT-PROVENANCE.md"), "w") as out:
        out.write(head)
        out.write("| File | Its original in micropolis-activity | SHA-256 (first 16) |\n|---|---|---|\n")
        out.write("\n".join(rows) + "\n")
    print("%d traced, %d untraced" % (len(rows) - len(untraced), len(untraced)))
    for relative in untraced:
        print("  untraced: " + relative)
    sys.exit(1 if untraced else 0)


if __name__ == "__main__":
    main()
