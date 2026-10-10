"""Draws the hero and NPC pixel sprites and writes them to scripts/sprite_art.gd.

Run:  python3 tools/make_sprites.py   (also writes tools/sprite_preview.png)
Each sprite is a 16x22 grid of palette letters. Edit a draw function, re-run, and the game
picks up the new art. Frame "a" is standing / step one, frame "b" is the other step.
"""
import os

W, H = 16, 22
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "scripts", "sprite_art.gd")

BASE_PAL = {"k": "1a1420", "s": "e8b48a", "S": "c08a68", "w": "f4f2ea", "n": "6b4a2c", "N": "4a3220", "g": "3a3446", "G": "2a2434"}


class Canvas:
    def __init__(self, w=W, h=H):
        self.w, self.h = w, h
        self.g = [["." for _ in range(w)] for _ in range(h)]

    def px(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.g[y][x] = c

    def rect(self, x0, y0, x1, y1, c):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.px(x, y, c)

    def box(self, x0, y0, x1, y1, fill, edge="k"):
        self.rect(x0, y0, x1, y1, edge)
        if x1 - x0 >= 2 and y1 - y0 >= 2:
            self.rect(x0 + 1, y0 + 1, x1 - 1, y1 - 1, fill)

    def vline(self, x, y0, y1, c):
        self.rect(x, y0, x, y1, c)

    def hline(self, x0, x1, y, c):
        self.rect(x0, y, x1, y, c)

    def outline(self):
        """add a dark outline around every filled pixel that touches empty space"""
        add = []
        for y in range(self.h):
            for x in range(self.w):
                if self.g[y][x] != ".":
                    continue
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < self.w and 0 <= ny < self.h and self.g[ny][nx] not in (".", "k"):
                        add.append((x, y))
                        break
        for x, y in add:
            self.g[y][x] = "k"

    def rows(self):
        return ["".join(r) for r in self.g]


# ------------------------------------------------------------------ shared body
def body(c, shirt, shirt_dark, pants, step, sleeve=None, boots="g"):
    sleeve = sleeve or shirt
    # head
    c.rect(5, 4, 10, 9, "s")
    c.rect(5, 9, 10, 9, "S")
    c.px(6, 6, "k"); c.px(9, 6, "k")
    c.px(6, 7, "S"); c.px(9, 7, "S")
    # neck
    c.rect(7, 10, 8, 10, "S")
    # torso
    c.rect(5, 11, 10, 16, shirt)
    c.rect(5, 11, 5, 16, shirt_dark)
    c.rect(10, 11, 10, 16, shirt_dark)
    # arms + hands
    c.rect(3, 11, 4, 15, sleeve)
    c.rect(11, 11, 12, 15, sleeve)
    c.rect(3, 16, 4, 16, "s")
    c.rect(11, 16, 12, 16, "s")
    # belt
    c.hline(5, 10, 16, "n")
    c.px(7, 16, "b"); c.px(8, 16, "b")
    # legs
    if step == "a":
        c.rect(5, 17, 7, 19, pants); c.rect(8, 17, 10, 19, pants)
        c.rect(5, 20, 7, 20, boots); c.rect(8, 20, 10, 20, boots)
        c.px(7, 17, "k"); c.px(8, 18, "k"); c.px(8, 19, "k"); c.px(7, 19, "k"); c.px(7, 18, "k")
    else:
        c.rect(4, 17, 6, 19, pants); c.rect(9, 17, 11, 18, pants)
        c.rect(4, 20, 6, 20, boots); c.rect(9, 19, 11, 19, boots)
        c.rect(7, 17, 8, 18, pants)


def finish(c):
    c.outline()
    return c.rows()


# ------------------------------------------------------------------ heroes
def warrior(step):
    c = Canvas()
    body(c, "r", "R", "d", step, sleeve="M")
    # tabard + mail
    c.rect(6, 12, 9, 15, "r"); c.vline(7, 12, 15, "b"); c.px(8, 13, "b")
    # pauldrons
    c.rect(2, 10, 5, 12, "m"); c.rect(10, 10, 13, 12, "m")
    c.hline(2, 5, 12, "M"); c.hline(10, 13, 12, "M")
    # helmet
    c.rect(4, 2, 11, 5, "m")
    c.rect(4, 5, 11, 5, "M")
    c.rect(4, 6, 4, 8, "M"); c.rect(11, 6, 11, 8, "M")
    c.vline(7, 4, 7, "M"); c.px(8, 4, "M")
    c.rect(6, 3, 9, 3, "w")
    # plume
    c.rect(7, 0, 9, 1, "r"); c.px(10, 1, "R"); c.px(6, 1, "r")
    # sword (right hand, blade up)
    c.vline(14, 3, 14, "w"); c.vline(15, 4, 13, "m")
    c.hline(12, 15, 15, "b")
    c.vline(14, 16, 17, "n")
    # round shield (left arm)
    c.rect(0, 12, 3, 18, "M"); c.rect(1, 11, 2, 19, "M")
    c.rect(1, 13, 2, 17, "r"); c.px(1, 15, "b"); c.px(2, 15, "b")
    return finish(c)


def rogue(step):
    c = Canvas()
    body(c, "a", "A", "d", step, sleeve="A", boots="G")
    # hood
    c.rect(4, 2, 11, 5, "H")
    c.rect(3, 4, 4, 10, "H"); c.rect(11, 4, 12, 10, "H")
    c.rect(5, 3, 10, 4, "I")
    c.px(7, 2, "I")
    # shadowed face + scarf mask
    c.rect(5, 5, 10, 5, "I")
    c.rect(5, 8, 10, 9, "r"); c.px(10, 9, "R"); c.px(5, 9, "R")
    c.px(6, 6, "w"); c.px(9, 6, "w")
    # leather vest straps
    c.px(6, 12, "n"); c.px(7, 13, "n"); c.px(8, 14, "n"); c.px(9, 15, "n")
    # daggers in both hands, pointing down
    c.vline(3, 17, 19, "w"); c.px(4, 17, "m")
    c.vline(12, 17, 19, "w"); c.px(11, 17, "m")
    c.px(3, 16, "n"); c.px(12, 16, "n")
    # short cape edges
    c.vline(2, 11, 15, "C"); c.vline(13, 11, 15, "C")
    return finish(c)


def mage(step):
    c = Canvas()
    body(c, "a", "A", "a", step, sleeve="a")
    # robe skirt over legs
    for y in range(16, 21):
        spread = (y - 16) // 2
        c.rect(5 - spread, y, 10 + spread, y, "a")
        c.px(5 - spread, y, "A"); c.px(10 + spread, y, "A")
    c.hline(4, 11, 20, "A")
    if step == "b":
        c.px(5, 20, "g"); c.px(10, 20, "."); c.px(11, 20, ".")
    c.vline(7, 11, 19, "b")
    c.hline(5, 10, 16, "b")
    # beard
    c.rect(6, 8, 9, 10, "w"); c.px(7, 11, "w"); c.px(8, 11, "w")
    # pointed hat
    c.rect(3, 4, 12, 4, "a")
    c.rect(4, 3, 11, 3, "b")
    c.rect(5, 1, 10, 2, "a")
    c.rect(6, 0, 9, 0, "a")
    c.px(10, 0, "A"); c.px(11, 0, "A")
    c.px(8, 1, "A"); c.px(9, 2, "A")
    # staff with glowing orb
    c.vline(14, 3, 20, "n")
    c.vline(15, 5, 19, "N")
    c.rect(13, 0, 15, 2, "o"); c.px(14, 1, "w")
    c.px(12, 1, "O"); c.px(14, 3, "O")
    return finish(c)


def hunter(step):
    c = Canvas()
    body(c, "a", "A", "d", step, sleeve="A")
    # hood + cloak
    c.rect(4, 2, 11, 4, "H")
    c.rect(3, 3, 4, 10, "H"); c.rect(11, 3, 12, 10, "H")
    c.rect(5, 2, 10, 2, "I")
    c.px(12, 1, "f"); c.px(13, 0, "f"); c.px(13, 1, "F")
    # hair fringe
    c.rect(5, 4, 10, 4, "h")
    # quiver over the right shoulder
    c.rect(12, 9, 13, 14, "n")
    c.px(12, 7, "w"); c.px(13, 8, "w"); c.px(14, 8, "f")
    c.px(12, 8, "n"); c.px(13, 7, "f")
    # leather chest strap
    for i in range(5):
        c.px(6 + i, 11 + i, "n")
    # bow in left hand
    c.vline(1, 9, 19, "N")
    c.px(2, 8, "N"); c.px(2, 20, "N"); c.px(2, 9, "n"); c.px(2, 19, "n")
    c.vline(0, 10, 18, ".")
    c.vline(2, 10, 18, "w")
    c.vline(1, 10, 18, "n")
    return finish(c)


# ------------------------------------------------------------------ NPCs
def merchant(step):
    c = Canvas()
    body(c, "a", "A", "d", step, sleeve="a")
    # apron
    c.rect(6, 12, 9, 18, "p"); c.hline(6, 9, 12, "P")
    # wide hat
    c.rect(2, 4, 13, 4, "n")
    c.rect(4, 1, 11, 3, "n")
    c.hline(4, 11, 3, "b")
    # big moustache
    c.rect(5, 8, 10, 8, "h"); c.px(4, 8, "h"); c.px(11, 8, "h")
    # backpack bulge
    c.rect(12, 9, 14, 15, "N"); c.px(13, 8, "N"); c.rect(13, 10, 14, 11, "b")
    return finish(c)


def villager(hair, shirt, shirt_dark, step, extra=None):
    c = Canvas()
    body(c, shirt, shirt_dark, "d", step)
    c.rect(5, 3, 10, 4, hair); c.px(4, 4, hair); c.px(11, 4, hair); c.px(4, 5, hair); c.px(11, 5, hair)
    if extra:
        extra(c)
    return finish(c)


def farmer(step):
    def hat(c):
        c.rect(2, 3, 13, 3, "y"); c.rect(5, 1, 10, 2, "y"); c.hline(5, 10, 2, "Y")
        c.vline(13, 9, 19, "n"); c.rect(12, 7, 15, 8, "m")  # pitchfork
        c.px(12, 6, "m"); c.px(14, 6, "m")
    return villager("h", "a", "A", step, hat)


def ranger(step):
    def gear(c):
        c.rect(4, 2, 11, 3, "H"); c.px(4, 4, "H"); c.px(11, 4, "H")
        c.rect(12, 9, 13, 14, "n"); c.px(12, 8, "w"); c.px(13, 7, "w")
        for i in range(5):
            c.px(6 + i, 11 + i, "n")
    return villager("h", "a", "A", step, gear)


def hermit(step):
    def robe(c):
        c.rect(4, 2, 11, 4, "H"); c.rect(3, 4, 4, 10, "H"); c.rect(11, 4, 12, 10, "H")
        c.rect(6, 8, 9, 11, "w")
        for y in range(17, 21):
            c.rect(5, y, 10, y, "a")
        c.vline(13, 6, 20, "n"); c.rect(12, 4, 14, 5, "o")  # lantern staff
    return villager("w", "a", "A", step, robe)


def pilgrim(step):
    def garb(c):
        c.rect(5, 2, 10, 3, "h")
        c.rect(4, 11, 11, 11, "b")
        for y in range(17, 21):
            c.rect(5, y, 10, y, "a")
        c.vline(7, 12, 19, "w")
        c.vline(13, 2, 20, "n"); c.rect(12, 2, 14, 2, "n")
    return villager("h", "a", "A", step, garb)




# ------------------------------------------------------------------ creatures (facing right)
def disc(c, cx, cy, rx, ry, col):
    for y in range(cy - ry, cy + ry + 1):
        for x in range(cx - rx, cx + rx + 1):
            if ((x - cx) / (rx + 0.5)) ** 2 + ((y - cy) / (ry + 0.5)) ** 2 <= 1.0:
                c.px(x, y, col)


def beetle(step):
    c = Canvas(16, 11)
    legs = [(4, 8), (7, 8), (10, 8)] if step == "a" else [(3, 8), (7, 9), (11, 8)]
    for lx, ly in legs:
        c.vline(lx, ly, ly + 1, "d"); c.px(lx - 1, ly + 2 if ly + 2 < 11 else 10, "d")
    disc(c, 7, 5, 6, 4, "g")
    disc(c, 6, 4, 4, 2, "G")
    c.vline(7, 2, 8, "d")
    c.rect(12, 4, 13, 7, "d")
    c.px(13, 5, "e")
    c.rect(14, 3, 14, 5, "h"); c.px(15, 2, "h")
    return finish(c)


def puffcap(step):
    c = Canvas(12, 14)
    sq = 0 if step == "a" else 1
    disc(c, 6, 4 + sq, 5, 3 - sq, "r")
    c.px(3, 3 + sq, "w"); c.px(7, 2 + sq, "w"); c.px(9, 4 + sq, "w"); c.px(5, 5, "w")
    c.rect(3, 7, 8, 12, "s")
    c.rect(3, 7, 8, 7, "R")
    c.px(4, 9, "k"); c.px(7, 9, "k")
    c.rect(5, 11, 6, 11, "S")
    c.rect(2 if step == "a" else 3, 13, 4, 13, "S"); c.rect(7, 13, 9 if step == "a" else 8, 13, "S")
    return finish(c)


def sapling(step):
    c = Canvas(16, 20)
    disc(c, 8, 4, 6, 4, "l")
    disc(c, 6, 3, 3, 2, "L")
    disc(c, 10, 5, 3, 2, "m")
    c.rect(5, 8, 10, 16, "b")
    c.rect(5, 8, 6, 16, "B")
    c.px(7, 10, "e"); c.px(9, 10, "e")
    c.rect(7, 13, 9, 13, "B")
    # branch arms
    c.hline(1, 4, 11, "b"); c.px(1, 10, "b"); c.px(0, 9, "l")
    c.hline(11, 14, 11, "b"); c.px(14, 10, "b"); c.px(15, 9, "l")
    if step == "a":
        c.rect(5, 17, 6, 19, "B"); c.rect(9, 17, 10, 19, "B"); c.px(4, 19, "B"); c.px(11, 19, "B")
    else:
        c.rect(4, 17, 5, 18, "B"); c.rect(10, 17, 11, 19, "B"); c.px(3, 18, "B"); c.px(7, 17, "B")
    return finish(c)


def spider(step):
    c = Canvas(18, 11)
    up = 0 if step == "a" else 1
    for i, lx in enumerate([3, 6, 9, 12]):
        dy = up if i % 2 == 0 else 1 - up
        c.px(lx, 6, "d"); c.px(lx - 1, 7, "d"); c.px(lx - 2, 8 + dy, "d"); c.px(lx - 2, 9 + dy if 9 + dy < 11 else 10, "d")
        c.px(lx + 1, 4, "d"); c.px(lx + 1, 3, "d") if i < 2 else None
    disc(c, 6, 5, 5, 3, "g")
    disc(c, 5, 4, 3, 1, "G")
    c.px(4, 5, "r"); c.px(7, 4, "r")
    disc(c, 13, 5, 2, 2, "g")
    c.px(14, 4, "e"); c.px(15, 5, "e"); c.px(14, 6, "e")
    c.px(16, 6, "w"); c.px(16, 7, "w")
    return finish(c)


def leech(step):
    c = Canvas(16, 9)
    off = 0 if step == "a" else 1
    for i in range(5):
        y = 4 + (1 if (i + off) % 2 == 0 else 0)
        disc(c, 2 + i * 2 + 1, y, 2, 2, "g" if i % 2 == 0 else "G")
    disc(c, 13, 4, 2, 3, "g")
    c.rect(14, 3, 15, 5, "r")
    c.px(15, 4, "w"); c.px(12, 2, "e")
    return finish(c)


def crone(step):
    c = Canvas(14, 20)
    c.rect(3, 2, 9, 9, "H")
    c.rect(4, 4, 8, 8, "s")
    c.px(5, 5, "e"); c.px(7, 5, "e")
    c.px(8, 7, "S"); c.px(9, 6, "s")
    c.rect(2, 9, 9, 18, "a")
    c.rect(2, 9, 3, 18, "A")
    c.vline(6, 10, 17, "A")
    c.rect(1, 18, 10, 18, "A")
    if step == "b":
        c.rect(3, 19, 4, 19, "A")
    c.px(10, 12, "s"); c.px(11, 12, "s")
    c.vline(12, 4, 19, "n")
    disc(c, 12, 2, 1, 1, "o"); c.px(12, 2, "w")
    return finish(c)


def golem(step):
    c = Canvas(22, 22)
    c.rect(6, 1, 15, 7, "g")
    c.rect(6, 1, 15, 2, "G")
    c.rect(8, 4, 9, 5, "e"); c.rect(12, 4, 13, 5, "e")
    c.rect(4, 8, 17, 16, "g")
    c.rect(4, 8, 17, 9, "G")
    c.rect(9, 11, 12, 13, "e")
    c.rect(10, 12, 11, 12, "w")
    # arms
    c.rect(0, 9, 3, 17, "g"); c.rect(0, 15, 3, 18, "G")
    c.rect(18, 9, 21, 17, "g"); c.rect(18, 15, 21, 18, "G")
    if step == "a":
        c.rect(5, 17, 9, 21, "g"); c.rect(12, 17, 16, 21, "g")
    else:
        c.rect(4, 17, 8, 20, "g"); c.rect(13, 17, 17, 21, "g")
    c.px(7, 10, "w"); c.px(15, 14, "w"); c.px(2, 11, "w")
    return finish(c)


def frostwisp(step):
    c = Canvas(13, 13)
    disc(c, 6, 6, 3, 3, "g")
    disc(c, 6, 6, 1, 1, "w")
    pts = [(6, 0), (12, 6), (6, 12), (0, 6)] if step == "a" else [(2, 2), (10, 2), (10, 10), (2, 10)]
    for x, y in pts:
        c.px(x, y, "G"); c.px((x + 6) // 2, (y + 6) // 2, "g")
    c.px(5, 5, "e"); c.px(7, 5, "e")
    return finish(c)


def smith(step):
    c = Canvas()
    body(c, "a", "A", "d", step, sleeve="s")
    c.rect(6, 12, 9, 18, "p"); c.hline(6, 9, 12, "P")
    c.rect(5, 3, 10, 4, "h"); c.px(4, 4, "h"); c.px(11, 4, "h")
    c.rect(5, 8, 10, 10, "h"); c.px(6, 11, "h"); c.px(9, 11, "h")
    c.px(6, 6, "k"); c.px(9, 6, "k")
    # hammer
    c.vline(13, 9, 17, "n")
    c.rect(12, 7, 15, 9, "m")
    return finish(c)


CREATURES = {
    "beetle": (beetle, {"g": "3a6a5a", "G": "5aa08a", "d": "1f2a2a", "e": "ffd27a", "h": "c8c0a0"}),
    "puffcap": (puffcap, {"r": "b04060", "R": "802a40", "w": "f0e0e8", "s": "e8d8c0", "S": "b8a890"}),
    "sapling": (sapling, {"l": "4a8a3a", "L": "6aaa4a", "m": "3a6a2a", "b": "7a5a3a", "B": "5a3e28", "e": "c8f070"}),
    "spider": (spider, {"g": "3a3040", "G": "5a4a68", "d": "2a2230", "r": "b04040", "e": "ff4a4a", "w": "e8e0d0"}),
    "leech": (leech, {"g": "5a5a3a", "G": "7a7a4a", "r": "8a2a2a", "w": "e8d8c0", "e": "ffd27a"}),
    "crone": (crone, {"H": "3a4a3a", "a": "4a5a40", "A": "34402c", "s": "a8b890", "S": "788a68", "e": "e0ff70", "n": "5a4a30", "o": "70ff90", "w": "f0fff0"}),
    "golem": (golem, {"g": "8ab0cc", "G": "c8e0f0", "e": "2a7fd0", "w": "f4fbff"}),
    "frostwisp": (frostwisp, {"g": "9fe0ff", "G": "e8f8ff", "w": "ffffff", "e": "2a5a9a"}),
}

SPRITES = {
    "warrior": (warrior, {"m": "dfe5ec", "M": "8c96a3", "r": "b8342c", "R": "7a2020", "b": "d8b04a", "d": "4a3a4a"}),
    "rogue": (rogue, {"a": "3d4452", "A": "2a2f3a", "H": "2f3340", "I": "1f222b", "r": "7a1e2c", "R": "50121c", "C": "22252e", "m": "c9ced6", "d": "2a2830", "b": "a08040"}),
    "mage": (mage, {"a": "5b3c9e", "A": "3e2a70", "b": "e0c060", "o": "b080ff", "O": "e0c8ff", "g": "2a2434"}),
    "hunter": (hunter, {"a": "4f7a3a", "A": "3a5a2c", "H": "3f6b3a", "I": "2c4c28", "h": "8a5a30", "f": "e05a4a", "F": "b8342c", "d": "5a4a30", "b": "c8a050"}),
    "merchant": (merchant, {"a": "a0603a", "A": "7a4428", "p": "e8dcc0", "P": "c8b890", "h": "5a3a20", "b": "e0c060", "d": "4a3a3a"}),
    "farmer": (farmer, {"a": "6a8ac0", "A": "4a6a9a", "h": "8a6a40", "y": "e0c870", "Y": "b8a050", "m": "b0b8c0", "b": "a08040", "d": "6a5a40"}),
    "ranger": (ranger, {"a": "3e6a4a", "A": "2c4c34", "H": "2f5a34", "h": "c07040", "b": "a08040", "d": "4a3a2a"}),
    "hermit": (hermit, {"a": "5a5a48", "A": "3e3e32", "H": "4a4a3a", "o": "ffd27a", "b": "a08040", "d": "3a3a30"}),
    "pilgrim": (pilgrim, {"a": "c8d0dc", "A": "9aa4b0", "h": "e0d0b0", "b": "6a8ac0", "d": "6a6a78"}),
    "smith": (smith, {"a": "8a3a2a", "A": "6a2a20", "p": "5a4030", "P": "3e2c20", "h": "c8642a", "m": "9aa4b0", "d": "3a3030", "b": "a08040"}),
}
SPRITES.update(CREATURES)


def main():
    out = ["## Generated by tools/make_sprites.py. Edit that script and re-run it instead of this file.",
           "class_name SpriteArt", "extends RefCounted", "", "const SPRITES := {"]
    previews = []
    for name, (fn, pal) in SPRITES.items():
        full = dict(BASE_PAL)
        full.update(pal)
        a, b = fn("a"), fn("b")
        for rows in (a, b):
            assert all(len(r) == len(rows[0]) for r in rows) and len(rows) == len(b), name
        out.append('\t"%s": {' % name)
        out.append('\t\t"a": [%s],' % ", ".join('"%s"' % r for r in a))
        out.append('\t\t"b": [%s],' % ", ".join('"%s"' % r for r in b))
        out.append('\t\t"pal": {%s},' % ", ".join('"%s": "%s"' % kv for kv in full.items()))
        out.append("\t},")
        previews.append((name, a, b, full))
    out.append("}")
    with open(OUT, "w") as f:
        f.write("\n".join(out) + "\n")
    try:
        from PIL import Image
        scale = 6
        CW = 24
        img = Image.new("RGBA", (len(previews) * (CW * 2 + 4) * scale, (H + 2) * scale), (60, 70, 60, 255))
        for i, (name, a, b, pal) in enumerate(previews):
            for fi, rows in enumerate((a, b)):
                ox = (i * (CW * 2 + 4) + fi * (CW + 1)) * scale
                for y, row in enumerate(rows):
                    for x, ch in enumerate(row):
                        if ch in pal:
                            col = tuple(int(pal[ch][j:j + 2], 16) for j in (0, 2, 4)) + (255,)
                            for yy in range(scale):
                                for xx in range(scale):
                                    img.putpixel((ox + x * scale + xx, scale + y * scale + yy), col)
        img.save(os.path.join(HERE, "sprite_preview.png"))
    except ImportError:
        pass
    print("wrote", OUT)


if __name__ == "__main__":
    main()
