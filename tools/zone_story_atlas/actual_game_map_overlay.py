"""Overlay every current game zone and the proposed merged region plan."""
from pathlib import Path
import base64
import re
import zlib

from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
ASSET_DIR = ROOT / "assets" / "zone_story_atlas"
SOURCE = ASSET_DIR / "actual_game_map_clean.png"
DATA = ROOT / "scripts" / "layout_data.gd"
OUT = ASSET_DIR / "actual_game_map_regions.png"
FONT_PATH = "/System/Library/Fonts/Supplemental/Arial.ttf"


def font(size):
    return ImageFont.truetype(FONT_PATH, size) if Path(FONT_PATH).exists() else ImageFont.load_default()


def load_zone_mask():
    src = DATA.read_text()
    blob = re.search(r'const BLOB := "([^"]+)"', src).group(1)
    gx = int(re.search(r"const GX := (\d+)", src).group(1))
    gy = int(re.search(r"const GY := (\d+)", src).group(1))
    raw = zlib.decompress(base64.b64decode(blob))
    n = gx * gy
    return gx, gy, raw[4 * n:5 * n]


def add_label(draw, center, text, size=15):
    f = font(size)
    box = draw.textbbox((0, 0), text, font=f)
    w, h = box[2] - box[0] + 22, box[3] - box[1] + 14
    x, y = center
    draw.rounded_rectangle((x - w / 2, y - h / 2, x + w / 2, y + h / 2), radius=7,
                           fill=(22, 25, 35, 232), outline=(248, 238, 215, 255), width=2)
    draw.text((x - w / 2 + 11, y - h / 2 + 5), text, font=f, fill=(255, 249, 231, 255))


im = Image.open(SOURCE).convert("RGBA")
MAP = (0, 0, im.width, im.height)
MW, MH = im.width, im.height
gx, gy, zone = load_zone_mask()

# Sample the exact zone mask the game uses at each pixel of the map viewport.
# The transform matches LayoutMap.cell_uv()/zone_at() in the game.
zone_img = Image.new("L", (MW, MH), 255)
zpix = zone_img.load()
source_pixels = im.load()
land_img = Image.new("1", (MW, MH), 0)
lp = land_img.load()
for py in range(MH):
    world_y = py * 1200.0 / MH
    iy = int((0.53 + (world_y - 600.0) / 790.0) * gy)
    if iy < 0 or iy >= gy:
        continue
    row = iy * gx
    for px in range(MW):
        world_x = px * 1200.0 / MW
        ix = int((0.515 + (world_x - 600.0) / 1180.0) * gx)
        if 0 <= ix < gx:
            zpix[px, py] = zone[row + ix]
            # The mask includes broad rectangular ocean cells. The game's
            # terrain screenshot makes ocean exactly this solid blue.
            sx, sy = MAP[0] + px, MAP[1] + py
            r, g, b, _ = source_pixels[sx, sy]
            lp[px, py] = max(abs(r - 55), abs(g - 89), abs(b - 134)) > 12

# The narrow rocky strip immediately west of Hearthmoor's town grid belongs
# to Hearthmoor Basin; the legacy mask left it in Saltfen Reach.
force_basin = Image.new("1", (MW, MH), 0)
ImageDraw.Draw(force_basin).polygon(
    [(638, 642), (661, 642), (670, 659), (672, 681), (679, 701),
     (673, 724), (682, 747), (674, 779), (659, 793), (644, 777),
     (640, 751), (641, 716), (634, 683)], fill=1)
for y in range(MH):
    for x in range(MW):
        if force_basin.getpixel((x, y)) and lp[x, y]:
            zpix[x, y] = 2

# Parent-region palette. Adjacent subzones that the design has merged share
# the same color; all other game zones receive their own distinct color.
group = {0: 6, 1: 1, 2: 2, 3: 3, 4: 3, 5: 5, 6: 6, 7: 1, 8: 8}
colors = {
    1: (244, 143, 56),   # Meadow & Uplands
    2: (245, 207, 96),   # Hearthmoor Basin
    3: (50, 170, 102),   # Forest Region
    5: (188, 126, 91),   # Saltfen Reach
    6: (70, 205, 229),   # Bellwater Delta including Campwater Vale
    8: (142, 194, 238),  # Frostspine Crown
}
name_text = {
    1: "MEADOW & UPLANDS", 2: "HEARTHMOOR BASIN",
    3: "FOREST REGION", 5: "SALTFEN REACH",
    6: "BELLWATER DELTA", 8: "FROSTSPINE CROWN",
}

# Draw clean, continuous boundaries for every zone on the true game mask.
# Same-parent internal boundaries are omitted to keep the merged regions clear.
edge = Image.new("L", (MW, MH), 0)
ep = edge.load()
zp = zone_img.load()
for y in range(1, MH - 1):
    for x in range(1, MW - 1):
        a = zp[x, y]
        if a == 255 or not lp[x, y]:
            continue
        ga = group.get(a)
        if any(lp[nx, ny] and (b := zp[nx, ny]) != 255 and group.get(b) != ga
               for nx, ny in ((x-1,y),(x+1,y),(x,y-1),(x,y+1))):
            ep[x, y] = 255
edge = edge.filter(ImageFilter.MaxFilter(9))

# A restrained transparent tint makes the territories readable as areas while
# leaving the original biome art and all its texture visible underneath.
tint = Image.new("RGBA", (MW, MH), (0, 0, 0, 0))
tp = tint.load()
for y in range(MH):
    for x in range(MW):
        if lp[x, y]:
            z = zp[x, y]
            if z in colors:
                tp[x, y] = (*colors[group[z]], 32)
im.alpha_composite(tint)

halo = Image.new("RGBA", (MW, MH), (0, 0, 0, 0))
hp = halo.load()
stroke = Image.new("RGBA", (MW, MH), (0, 0, 0, 0))
sp = stroke.load()
for y in range(MH):
    for x in range(MW):
        if edge.getpixel((x, y)):
            hp[x, y] = (19, 24, 28, 255)
            sp[x, y] = (255, 241, 204, 255)
halo = halo.filter(ImageFilter.MaxFilter(7))
im.alpha_composite(halo)
im.alpha_composite(stroke)
draw = ImageDraw.Draw(im, "RGBA")

# One label per merged region; component names stay off the map.
label_positions = {
    1: (690, 445), 2: (575, 752), 3: (1020, 655),
    5: (270, 520), 6: (790, 900), 8: (1080, 365),
}
for i, (x, y) in label_positions.items():
    add_label(draw, (MAP[0] + x, MAP[1] + y), name_text[i], 17)

# Add an uncluttered key alongside the actual screenshot.
panel_w = 570
canvas = Image.new("RGBA", (im.width + panel_w, im.height), (27, 25, 38, 255))
canvas.alpha_composite(im, (0, 0))
pd = ImageDraw.Draw(canvas, "RGBA")
px = im.width + 30
pd.rounded_rectangle((px, 28, im.width + panel_w - 25, im.height - 28), radius=16,
                     fill=(31, 29, 43, 255), outline=(83, 72, 105, 255), width=3)
pd.text((px + 24, 52), "THORNVALE", font=font(30), fill=(255, 245, 222, 255))
pd.text((px + 24, 94), "ALL ZONES · PROGRESSION OVERVIEW", font=font(18), fill=(197, 184, 221, 255))
pd.multiline_text((px + 24, 133), "Every region has one continuous outline.\nOne zone name appears on the map per region.",
                  font=font(15), fill=(235, 230, 220, 255), spacing=6)

items = [(colors[1], "MEADOW & UPLANDS"), (colors[2], "HEARTHMOOR BASIN"),
         (colors[3], "FOREST REGION"), (colors[5], "SALTFEN REACH"),
         (colors[6], "BELLWATER DELTA"), (colors[8], "FROSTSPINE CROWN")]
y = 225
for color, title in items:
    pd.rounded_rectangle((px + 22, y, im.width + panel_w - 47, y + 82), radius=10,
                         fill=(40, 38, 52, 255), outline=(86, 78, 101, 255), width=2)
    pd.rounded_rectangle((px + 38, y + 23, px + 54, y + 59), radius=4, fill=(*color, 255))
    pd.text((px + 68, y + 27), title, font=font(17), fill=(255, 246, 225, 255))
    y += 98

pd.text((px + 24, y + 6), "STORY / LEVEL MILESTONES", font=font(16), fill=(255, 245, 220, 255))
pd.multiline_text((px + 24, y + 38), "Warden encounters: levels 12 · 22 · 32 · 42\nGuided story reaches combat cap 45.\nDeep Runs unlock at 45: heroic remixes + new dungeons.",
                  font=font(15), fill=(232, 226, 216, 255), spacing=8)
canvas.convert("RGB").save(OUT, quality=96)
print(f"Wrote map overlay: {OUT}")
