#!/usr/bin/env python3
"""Compose the 4 dossier screenshots for Chess Brainrot Battle Royale.

These are HONEST COMPOSED RENDERS of the game's own world: the board,
pieces, HUD, banners and panels as built in src/ (same data, same names,
same prices). They are not Studio captures — there is no Studio on this VM —
so they are drawn from the game's own PieceData/Config values. Never label
them as Studio screenshots.
"""
import os
from PIL import Image, ImageDraw, ImageFont

OUT = os.path.join(os.path.dirname(__file__), "..", "screenshots")
W, H = 1280, 720

BOLD = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
REG = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"


def font(size):
    return ImageFont.truetype(BOLD, size)


def font_r(size):
    return ImageFont.truetype(REG, size)


LIGHT = (240, 217, 181)
DARK = (176, 126, 84)
GOLD = (255, 210, 60)
INK = (12, 10, 26)
GREEN = (120, 255, 140)
RED = (255, 80, 60)
BLUE = (90, 160, 255)
PURPLE = (180, 90, 255)

PIECES = [  # (name, rarity, face, body color, price, income)
    ("Peewee Pawn", "Common", ":-)", (220, 180, 90), "$50", "$2/s"),
    ("Grumpy Grunt", "Uncommon", ":-|", (110, 220, 110), "$100", "$4/s"),
    ("Neigh-sayer", "Common", "^_^", (150, 100, 60), "$250", "$9/s"),
    ("Holy Sniper", "Rare", "o_O", (90, 160, 255), "$2.4K", "$80/s"),
    ("Castle Crash", "Epic", ">:)", (180, 90, 255), "$12K", "$384/s"),
    ("Queen Bee", "Mythic", ":-*", (255, 90, 200), "$80K", "$2.4K/s"),
    ("The Big Cheese", "Legendary", "B-)", (255, 210, 60), "$640K", "$19.2K/s"),
    ("Kingpin", "Secret", ">:D", (255, 80, 60), "$1.28M", "$38.4K/s"),
]


def draw_piece(d, cx, base_y, h, body, face, crown=False):
    """A chess-piece character: base + torso + head with a face + crown."""
    w = int(h * 0.42)
    # base
    d.ellipse([cx - w // 2, base_y - 8, cx + w // 2, base_y + 4], fill=(40, 32, 48))
    # torso
    d.rounded_rectangle([cx - w // 2, base_y - int(h * 0.42), cx + w // 2, base_y - 6],
                        radius=8, fill=body)
    # arms
    d.rounded_rectangle([cx - w // 2 - 10, base_y - int(h * 0.38), cx - w // 2 - 2, base_y - int(h * 0.12)],
                        radius=4, fill=body)
    d.rounded_rectangle([cx + w // 2 + 2, base_y - int(h * 0.38), cx + w // 2 + 10, base_y - int(h * 0.12)],
                        radius=4, fill=body)
    # head
    hr = int(h * 0.16)
    hy = base_y - int(h * 0.42) - hr
    d.ellipse([cx - hr, hy - hr, cx + hr, hy + hr], fill=body, outline=(0, 0, 0), width=2)
    f = font(max(10, hr))
    d.text((cx, hy), face, font=f, fill=(20, 16, 24), anchor="mm")
    if crown:
        for i, dx in enumerate((-hr, -hr // 2, 0, hr // 2, hr)):
            d.polygon([(cx + dx - 6, hy - hr + 2), (cx + dx, hy - hr - 14),
                       (cx + dx + 6, hy - hr + 2)], fill=GOLD)
    return hy - hr


def draw_board(d, x0, y0, sq, pieces):
    """8x8 board; pieces = {(file, rank): (body, face, crown)}."""
    for f in range(8):
        for r in range(8):
            c = LIGHT if (f + r) % 2 == 0 else DARK
            d.rectangle([x0 + f * sq, y0 + r * sq, x0 + (f + 1) * sq, y0 + (r + 1) * sq], fill=c)
    d.rectangle([x0 - 6, y0 - 6, x0 + 8 * sq + 6, y0 + 8 * sq + 6], outline=GOLD, width=6)
    for (f, r), (body, face, crown) in pieces.items():
        cx = x0 + f * sq + sq // 2
        base = y0 + r * sq + sq - 4
        draw_piece(d, cx, base, int(sq * 0.92), body, face, crown)


def top_bar(d, money="$83.2M", income="+$6.39M/s"):
    d.rectangle([0, 0, W, 64], fill=INK)
    d.text((W // 2, 12), "48 PIECES · 6 TYPES · 8 RARITIES · 8 MUTATIONS · 6 BOARDS · 6 EVENTS · CAPTURE · LOCK · REBIRTH",
           font=font(15), fill=(255, 220, 100), anchor="ma")
    d.text((W // 2, 30), money, font=font(26), fill=GREEN, anchor="ma")
    d.text((W // 2, 58), f"{income} · REBIRTH 2 · x7 · 12 PIECES · 31/48 CODEX",
           font=font_r(13), fill=(200, 200, 220), anchor="ma")


def action_bar(d):
    y = H - 68
    d.rounded_rectangle([64, y, W - 64, y + 56], radius=10, fill=INK)
    labels = [("LOCK [L] READY", BLUE), ("WHACK [F] READY", RED), ("UPGRADES [U] 27/43", PURPLE),
              ("REBIRTH [R] $100M", GOLD), ("CODEX [B] 31/48", (90, 220, 160))]
    bw = (W - 128 - 40) // 5
    for i, (txt, col) in enumerate(labels):
        x = 74 + i * (bw + 8)
        d.rounded_rectangle([x, y + 8, x + bw, y + 48], radius=8, fill=col)
        d.text(((x + x + bw) // 2, y + 28), txt, font=font(15), fill=(255, 255, 255), anchor="mm")


def banner(d, title, sub, color, y=76):
    d.rounded_rectangle([W // 2 - 330, y, W // 2 + 330, y + 76], radius=12, fill=color)
    d.text((W // 2, y + 26), title, font=font(30), fill=(20, 12, 4), anchor="mm")
    d.text((W // 2, y + 58), sub, font=font(16), fill=(40, 24, 8), anchor="mm")


def bg(d, top=(28, 20, 52), bottom=(52, 40, 90)):
    for y in range(H):
        t = y / H
        d.line([(0, y), (W, y)], fill=tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)))


def shot1():
    img = Image.new("RGB", (W, H))
    d = ImageDraw.Draw(img)
    bg(d)
    top_bar(d)
    banner(d, "BLITZ STORM!", "All pieces move 2x, income 2x  ·  19s left", GOLD)
    # board, left-center
    pieces = {
        (3, 6): ((220, 180, 90), ":-)", False),
        (4, 6): ((150, 100, 60), "^_^", False),
        (5, 5): ((90, 160, 255), "o_O", False),
        (2, 5): ((180, 90, 255), ">:)", False),
        (4, 4): ((255, 210, 60), "B-)", True),
        (5, 4): ((255, 90, 200), ":-*", True),
        (6, 3): ((220, 180, 90), ":-)", False),
        (3, 3): ((150, 100, 60), "^_^", False),
    }
    draw_board(d, 120, 180, 52, pieces)
    # legal-move highlight on two squares
    d.rectangle([120 + 4 * 52, 180 + 3 * 52, 120 + 5 * 52, 180 + 4 * 52], outline=(90, 255, 120), width=5)
    d.rectangle([120 + 5 * 52, 180 + 3 * 52, 120 + 6 * 52, 180 + 4 * 52], outline=(255, 80, 60), width=5)
    # parade lane, right side: pedestals with price tags
    d.rectangle([620, 520, 1230, 600], fill=(200, 40, 60))
    for i, p in enumerate(PIECES[:5]):
        x = 680 + i * 112
        d.rounded_rectangle([x - 42, 560, x + 42, 572], radius=4, fill=(235, 230, 220))
        draw_piece(d, x, 560, 78, p[3], p[2], crown=(p[0] in ("The Big Cheese", "Queen Bee")))
        d.rounded_rectangle([x - 52, 470, x + 52, 512], radius=6, fill=(10, 8, 20))
        d.text((x, 482), p[0], font=font(11), fill=(255, 255, 255), anchor="ma")
        d.text((x, 500), f"{p[4]} · {p[5]}", font=font(11), fill=GREEN, anchor="ma")
    # floating income labels
    d.text((300, 210), "+$6.39M/s", font=font(20), fill=GREEN)
    d.text((520, 260), "+$1.2M", font=font(18), fill=GREEN)
    # carrying indicator
    d.rounded_rectangle([W // 2 - 260, 158, W // 2 + 260, 158 + 0], radius=0, fill=GOLD)
    action_bar(d)
    return img


def shot2():
    img = Image.new("RGB", (W, H))
    d = ImageDraw.Draw(img)
    bg(d)
    top_bar(d)
    d.rounded_rectangle([90, 84, W - 90, H - 84], radius=12, fill=INK)
    d.text((W // 2, 108), "PIECE CODEX — 48 pieces. Tap a tile to read its joke.",
           font=font(18), fill=(255, 220, 100), anchor="ma")
    names = ["Peewee Pawn", "Grumpy Grunt", "Helmet Head", "Squire Steve", "Brave Bean", "Tiny Tank",
             "Neigh-sayer", "Sir Gallops", "Horse Power", "Lancelot Jr", "The Knightmare", "Plume Pete",
             "Holy Sniper", "Bishop Blitz", "Diagonal Dan", "The Mitre", "Prayer Pete", "Slopey Steve",
             "Castle Crash", "Tower Tom", "The Fortress", "Brick House", "Rampart Ray", "Stonewall Sam",
             "Queen Bee", "Her Majesty", "Crown Jewel", "The Boss Lady", "Scepter Sue", "Royal Rumble",
             "The Big Cheese", "Kingpin", "Crown King", "Checkmate Charlie", "His Royal Grump", "Throne Tom",
             "Frontline Fred", "Stable Star", "Cross-Eyed Carl", "Turret Tina", "Duchess Doom", "Lord Checkmate"]
    colors = [(180, 180, 180), (110, 220, 110), (90, 160, 255), (180, 90, 255),
              (255, 90, 200), (255, 200, 40), (255, 80, 60), (120, 240, 255)]
    found = 31
    for i, name in enumerate(names):
        col, row = i % 8, i // 8
        x = 120 + col * 132
        y = 140 + row * 84
        is_found = i < found
        c = colors[i % 8] if is_found else (60, 56, 72)
        d.rounded_rectangle([x, y, x + 122, y + 74], radius=8, fill=c)
        d.text((x + 61, y + 26), name if is_found else "?", font=font(13), fill=(255, 255, 255), anchor="mm")
        d.text((x + 61, y + 52), ["Common", "Uncommon", "Rare", "Epic", "Mythic", "Legendary", "Secret", "Divine"][i % 8] if is_found else "???",
               font=font_r(11), fill=(230, 230, 230), anchor="mm")
    d.text((W // 2, 620), "The Big Cheese (Legendary): The most important piece and the worst at moving. One square. Slowly.",
           font=font_r(14), fill=(200, 200, 220), anchor="ma")
    d.text((W // 2, 650), "MILESTONES: 6 found x1.25 · 12 found x1.5 · 18 found x2 · 24 found x2.5 · 36 found x3 · 48 found x5",
           font=font(13), fill=GOLD, anchor="ma")
    action_bar(d)
    return img


def shot3():
    img = Image.new("RGB", (W, H))
    d = ImageDraw.Draw(img)
    bg(d)
    top_bar(d, money="$41.7M", income="+$2.1M/s")
    # rival board, left, with LOCKED tag
    d.text((230, 100), "BIG LOU — LOCKED", font=font(20), fill=RED, anchor="ma")
    pieces = {(2, 2): ((220, 180, 90), ":-)", False), (4, 3): ((150, 100, 60), "^_^", False),
              (5, 5): ((90, 160, 255), "o_O", False), (6, 2): ((255, 210, 60), "B-)", True)}
    draw_board(d, 60, 140, 40, pieces)
    d.ellipse([380, 130, 420, 170], fill=RED)  # lock orb
    d.text((400, 185), "LOCKED 23s", font=font(13), fill=RED, anchor="ma")
    # player board, right, thief being whacked
    d.text((900, 100), "YOUR BOARD", font=font(20), fill=GREEN, anchor="ma")
    pieces2 = {(3, 5): ((220, 180, 90), ":-)", False), (4, 4): ((255, 210, 60), "B-)", True),
               (5, 4): ((255, 90, 200), ":-*", True), (2, 3): ((180, 90, 255), ">:)", False)}
    draw_board(d, 700, 140, 40, pieces2)
    # thief pawn mid-whack + burst
    draw_piece(d, 760, 480, 60, (150, 100, 60), "X_X", crown=False)
    for k in range(8):
        ang = k * 0.785
        x2 = 760 + int(46 * __import__("math").cos(ang))
        y2 = 430 + int(46 * __import__("math").sin(ang))
        d.line([(760, 430), (x2, y2)], fill=GOLD, width=4)
    d.text((760, 500), "WHACKED! +$250", font=font(20), fill=GOLD, anchor="ma")
    # carrying bar
    d.rounded_rectangle([W // 2 - 260, 560, W // 2 + 260, 596], radius=8, fill=(255, 120, 60))
    d.text((W // 2, 578), "CARRYING: Queen Bee -> DROP AT YOUR BOARD", font=font(16), fill=(255, 255, 255), anchor="mm")
    action_bar(d)
    return img


def shot4():
    img = Image.new("RGB", (W, H))
    d = ImageDraw.Draw(img)
    bg(d, top=(16, 30, 80), bottom=(30, 60, 120))
    top_bar(d)
    banner(d, "TIDAL WAVE!", "Bonus zone floods the arena — 3x income  ·  12s left", BLUE)
    pieces = {
        (2, 6): ((220, 180, 90), ":-)", False),
        (3, 5): ((150, 100, 60), "^_^", False),
        (4, 5): ((90, 160, 255), "o_O", False),
        (5, 4): ((180, 90, 255), ">:)", False),
        (4, 3): ((255, 210, 60), "B-)", True),
        (6, 3): ((255, 90, 200), ":-*", True),
        (3, 2): ((220, 180, 90), ":-)", False),
        (6, 6): ((255, 80, 60), ">:D", True),
    }
    draw_board(d, 200, 190, 56, pieces)
    # neon mutation rings under two pieces
    d.ellipse([200 + 4 * 56 - 26, 190 + 3 * 56 + 44, 200 + 5 * 56 + 26, 190 + 4 * 56 + 52], outline=(80, 255, 220), width=4)
    d.ellipse([200 + 6 * 56 - 26, 190 + 6 * 56 + 44, 200 + 7 * 56 + 26, 190 + 7 * 56 + 52], outline=(180, 60, 255), width=4)
    # wave at the bottom
    d.polygon([(0, 640), (200, 600), (400, 640), (600, 600), (800, 640), (1000, 600), (1280, 640), (1280, 720), (0, 720)],
              fill=(40, 120, 220))
    d.text((340, 230), "+$19.2M/s", font=font(22), fill=GREEN)
    d.text((700, 300), "+$3.8M", font=font(20), fill=GREEN)
    d.text((W // 2, 620), "NEXT: NIGHT RAID! in 24s — the Raccoon King is coming", font=font(16), fill=(255, 220, 100), anchor="ma")
    action_bar(d)
    return img


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    shots = [("1-cover.png", shot1), ("2-codex.png", shot2), ("3-capture.png", shot3), ("4-event.png", shot4)]
    for name, fn in shots:
        img = fn()
        path = os.path.join(OUT, name)
        img.save(path, "PNG", optimize=True)
        print(name, os.path.getsize(path), "bytes")
