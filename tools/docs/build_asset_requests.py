#!/usr/bin/env python3
"""Builds docs/ASSET_REQUESTS.pdf: every visual asset the art department
needs to replace the labelled-shape stand-ins and finish the game.

    python3 tools/docs/build_asset_requests.py
"""
from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER
from reportlab.lib.pagesizes import A4, landscape
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.platypus import (Image, KeepTogether, PageBreak, Paragraph, SimpleDocTemplate,
                                Spacer, Table, TableStyle)

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "docs" / "ASSET_REQUESTS.pdf"
SHOTS = ROOT / "docs" / "art" / "standins"

PLUM = colors.HexColor("#2a1638")
GOLD = colors.HexColor("#f5b83a")
CREAM = colors.HexColor("#f7eed6")
ROSE = colors.HexColor("#c8344c")
GREY = colors.HexColor("#6b6170")

ss = getSampleStyleSheet()
H1 = ParagraphStyle("H1", parent=ss["Heading1"], textColor=PLUM, fontSize=20, spaceAfter=6, spaceBefore=4)
H2 = ParagraphStyle("H2", parent=ss["Heading2"], textColor=ROSE, fontSize=14, spaceAfter=4, spaceBefore=10)
BODY = ParagraphStyle("Body", parent=ss["BodyText"], fontSize=9.5, leading=13)
SMALL = ParagraphStyle("Small", parent=BODY, fontSize=8.2, leading=10.5)
CELL = ParagraphStyle("Cell", parent=BODY, fontSize=8.2, leading=10.4)
CELLB = ParagraphStyle("CellB", parent=CELL, fontName="Helvetica-Bold")
TITLE = ParagraphStyle("Title", parent=ss["Title"], textColor=PLUM, fontSize=34, leading=40, alignment=TA_CENTER)
SUB = ParagraphStyle("Sub", parent=BODY, fontSize=13, leading=18, alignment=TA_CENTER, textColor=GREY)

PRIORITY = {"P1": "P1 - needed to ship", "P2": "P2 - strongly wanted", "P3": "P3 - polish"}


def p(text, style=BODY):
    return Paragraph(text, style)


def table(rows, widths, header=True):
    data = [[p(str(c), CELLB if (header and i == 0) else CELL) for c in r] for i, r in enumerate(rows)]
    t = Table(data, colWidths=widths, repeatRows=1 if header else 0)
    style = [
        ("GRID", (0, 0), (-1, -1), 0.4, colors.HexColor("#cfc4d6")),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("LEFTPADDING", (0, 0), (-1, -1), 4),
        ("RIGHTPADDING", (0, 0), (-1, -1), 4),
        ("TOPPADDING", (0, 0), (-1, -1), 3),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 3),
    ]
    if header:
        style += [("BACKGROUND", (0, 0), (-1, 0), CREAM)]
    for i in range(1, len(rows)):
        if i % 2 == 0:
            style.append(("BACKGROUND", (0, i), (-1, i), colors.HexColor("#faf7fb")))
    t.setStyle(TableStyle(style))
    return t


# ---------------------------------------------------------------------------
# Content
# ---------------------------------------------------------------------------

ENEMY_ANIMS = "idle, walk/move, windup (attack anticipation), attack (active), recover, hurt, launched (tumbling, 1-2 frames), knocked down (lying, 1 frame), death"

CHARACTERS = [
    # id, name, where, size in game (w x h px at 1080p), look, animations, priority
    ("NPC-01", "Pippet (shopkeeper)", "All 6 shops, 3 NPC rooms", "~44 x 70",
     "Small, nervous goblin-ish court page with a rickety bell cart (the cart can stay the pack's cart.png). Blue livery.",
     "idle (4-6), talk (4), happy/sale (3), wave (4)", "P1"),
    ("NPC-02", "The Court Spook", "NPC rooms, all areas", "~56 x 76 (floats)",
     "Friendly bell-shaped ghost, teal and translucent, with a jester collar. Speaks in hints.",
     "float idle (6), talk (4), giggle (4)", "P1"),
    ("NPC-03", "Princess Seraphine", "Ending cards only", "Illustration",
     "The only royal who laughs. Appears in the ending story card.", "Illustration only", "P2"),
]

ENEMIES = [
    ("EN-01", "Arbalest", "Outer Walls, Throne Spire", "54 x 92",
     "Crossbow guard who keeps distance. Must read aim clearly: the windup is a 0.7 s aim pose; the bolt is batted back by the player.",
     ENEMY_ANIMS + "; plus aim (held) and reload", "P1"),
    ("EN-02", "Bulwark", "Outer Walls, Grand Halls, King's court", "70 x 104",
     "Tower-shield bearer. The shield must be unmistakably in FRONT: hits from the front clank off, hits from above/behind land.",
     ENEMY_ANIMS + "; plus block (shield spark), shield bash", "P1"),
    ("EN-03", "Springer", "Carnival Gate, Gardens", "50 x 66",
     "Jack-in-the-box on a coil that bounces toward the player in big arcs.",
     "idle, crouch (windup), spring (airborne, 2-3), land squash, hurt, launched, death", "P1"),
    ("EN-04", "Gargoyle Hound", "Outer Walls, Clockworks", "92 x 52",
     "Stone dog. Growls (windup), then charges flat out and stuns itself on walls.",
     "idle, walk, growl (windup), run (charge, 6), skid, dazed (wall stun), hurt, launched, death", "P1"),
    ("EN-05", "Wisp", "Royal Gardens", "52 x 52 (flying)",
     "Drifting garden ghost-light; lobs slow homing orbs.",
     "float (6), cast (4), hurt, launched, death (fade/pop)", "P1"),
    ("EN-06", "Balloon Clown", "Carnival Gate", "70 x 70 (flying)",
     "Clown face on a balloon that drops spiked juggling balls. 1 HP: pops. Prime pogo target.",
     "float (4), drop (3), pop death (4)", "P1"),
    ("EN-07", "Siege Cannon", "Outer Walls, Clockworks", "96 x 70",
     "Stationary cannon on wheels (optionally crewed by a tiny gnome). Fires arcing cannonballs.",
     "idle, aim/recoil windup, fire (3, with muzzle flash), hurt, destroyed", "P1"),
    ("EN-08", "Inquisitor", "Grand Halls, Throne Spire", "56 x 110",
     "Robed caster. Blinks around the player, casts orb fans and pillars of judgement.",
     "idle, cast fan (windup+release), cast pillar, blink out / in (3+3), hurt, launched, death", "P1"),
    ("EN-09", "Porcelain Courtier", "Grand Halls", "48 x 88",
     "Doll-like noble that moves in stiff ticks and pirouettes. Shatters on death.",
     "idle, tick-step walk (4), pirouette (6), hurt, launched, shatter death (5)", "P1"),
    ("EN-10", "Clockwork Knight", "Clockworks", "72 x 112",
     "Wind-up automaton with blade arms. Spins (armoured), then must rewind its key (wide open).",
     "idle, walk, wind-up, spin (6, loop), wind-down/key turn (6), hurt, launched, death", "P1"),
    ("EN-11", "Court Guard (real art)", "Everywhere", "~48 x 104",
     "Replaces the Community Aide stand-in. Halberd lunge attack.",
     ENEMY_ANIMS, "P1"),
]

BOSSES = [
    ("BS-01", "The Ringmaster", "Carnival Gate", "96 x 176",
     "Top hat, red tailcoat, whip. Theatrical. Throws flaming hoops, cartwheels across the ring, leaps and slams; summons balloon clowns late.",
     "intro pose, idle, walk, whip crack (windup 0.55 s + crack), hoop throw, cartwheel (loop), dizzy (after wall), leap/land, summon, hurt flash, phase change, death",
     "P1"),
    ("BS-02", "The Executioner", "Outer Walls", "130 x 210",
     "Hooded giant with a huge axe. Slow, telegraphed chops; armoured whirlwind; leap slam; returning axe throw.",
     "intro, idle, walk, chop windup (0.8 s) + chop, whirlwind (loop), leap/land, axe throw/catch, phase change, death; AXE projectile (spinning, 4 frames)",
     "P1"),
    ("BS-03", "The Mourning Bell", "Royal Gardens", "190 x 210 (flies)",
     "A floating bronze funeral bell, overgrown with roses, with a sorrowful face. Tolls shockwaves, drops to crush, gets stuck in the soil.",
     "hover (loop), toll (windup + ring), rise, drop, stuck/struggle (loop), pendulum swing, summon wisps, phase change (cracks appear), death (shatter)",
     "P1"),
    ("BS-04", "The Acrobat Twins (Pim & Pom)", "Grand Halls", "76 x 140 each",
     "Two mirrored acrobats sharing one health bar: Pim (blue) and Pom (pink). Tumble, throw knives, dive from the ceiling.",
     "per twin: intro, idle, tumble (loop), knife throw, ceiling spring, dive, land, hurt, death; KNIFE projectile",
     "P1"),
    ("BS-05", "The Clockwork Colossus", "Clockworks", "230 x 330",
     "Towering automaton. Its plating only cracks from ABOVE: the head/shoulders must read as the weak point (glowing seams). Fist slams, steam vents, gear volleys, stomps.",
     "idle (gears turning), fist slam L/R (windup + impact), vent steam, gear launch, stomp, hurt (upper body only), phase change (armour falls away), death (collapse)",
     "P1"),
    ("BS-06", "The King", "Throne Spire", "110 x 196",
     "The villain. Pompous, petty, terrified of a joke. Act 1 sceptre + crown boomerang + card fans; Act 2 calls guards and blinks; Act 3 takes to the air on a flying throne/cape and rains cards.",
     "intro, idle, sceptre strike, crown throw/catch, card fan, blink, summon, airborne idle, swoop, rain cast, phase changes (2), defeat (laughing - he finally gets the joke)",
     "P1"),
]

PROJECTILES = [
    ("PR-01", "Crossbow bolt", "Arbalest", "~44 x 10", "2 frames + reflected (gold) tint is done in code"),
    ("PR-02", "Homing orb", "Wisp, Inquisitor", "~28", "4-frame loop; teal (wisp) and pink (inquisitor) variants"),
    ("PR-03", "Spiked juggling ball", "Balloon Clown", "~32", "spinning loop 4"),
    ("PR-04", "Cannonball", "Siege Cannon", "~40", "1-2 frames + smoke trail"),
    ("PR-05", "Flaming hoop", "Ringmaster", "~52", "4-frame flame loop"),
    ("PR-06", "Executioner's axe", "Executioner", "~80", "spin loop 4"),
    ("PR-07", "Throwing knife", "Acrobat Twins", "~30 x 8", "1-2 frames"),
    ("PR-08", "Gear", "Colossus", "~44", "spin loop 4"),
    ("PR-09", "Playing card", "King", "~28 x 40", "flip loop 4"),
    ("PR-10", "Crown boomerang", "King", "~60", "spin loop 4"),
    ("PR-11", "Ground shockwave", "Bosses, Cracking Slam", "~48 x 48 travelling", "4-frame loop"),
]

ENVIRONMENT = [
    ("ENV-01", "Outer Walls terrain set", "Ramparts: cold blue-grey stone, battlements, arrow slits, iron braces. Same tile format as the existing pack (128 px authored, 7 top variants, 5 body variants, cracked, ledges).", "P1"),
    ("ENV-02", "Royal Gardens terrain set", "Hedges, trellises, mossy marble, rose vines; overgrown, moonlit, a little funereal.", "P1"),
    ("ENV-03", "Grand Halls terrain set", "Polished parquet and marble, gilded trim, carpet runners, porcelain display plinths.", "P1"),
    ("ENV-04", "Clockworks terrain set", "Riveted brass and iron, catwalk grates, pipes; warm orange furnace light.", "P1"),
    ("ENV-05", "Throne Spire terrain set", "Royal purple stone, gold leaf, stained glass, velvet; gets grander toward the top.", "P1"),
    ("ENV-06", "Back walls x5 (one per area)", "Tileable background wall per area (currently a darkened stone tile). 512 x 512 seamless.", "P1"),
    ("ENV-07", "Parallax backdrops x5", "Far + mid layers per area in the format of the Carnival Gate set (castle silhouette, gardens, hall interiors through arches, clock gears, spire skyline). Width tiles horizontally, ~2048 x 1100.", "P2"),
    ("ENV-08", "Area props x6-10 per area", "Wall decor that hangs from ceilings or stands on floors: banners, lanterns, candelabras, topiary, statues, portraits, gears, pipes, stained-glass windows.", "P2"),
    ("ENV-09", "Cracked stone block", "Breakable by Cracking Slam (64 x 64 tile, plus 6-frame break). Must read as 'breakable' at a glance in every area.", "P1"),
    ("ENV-10", "Spectral barrier", "Ghostly wall the Phantom Step passes through (64 x 64 tile, looping shimmer 6). Currently a procedural shimmer.", "P1"),
    ("ENV-11", "Boss portcullis", "Iron gate that slams shut over doors during boss fights; drop + rise (4 + 4).", "P2"),
    ("ENV-12", "Spikes per area", "64 px strip, 6 variants (one per area).", "P2"),
    ("ENV-13", "Spring / bounce pad", "Rest + compress + launch (4).", "P2"),
    ("ENV-14", "Ladder-ledge variants", "One-way ledges per area (current ledges are carnival wood/stone).", "P2"),
]

INTERACT = [
    ("OB-01", "Shrine of the Grin", "Rest point: save, heal, swap charms. Grinning jester bust on a plinth with candles. Idle glow loop + activate flash.", "P1"),
    ("OB-02", "Ability altar", "Appears after each boss; holds a glowing orb with the new trick. Idle + claim burst.", "P1"),
    ("OB-03", "Seal door", "Throne Spire gate with five seals (one per champion). States: 0-5 seals lit, open.", "P1"),
    ("OB-04", "Ending throne", "The empty throne the Jester takes a bow at.", "P2"),
    ("OB-05", "Sign post", "Readable wooden sign (per area tint is fine).", "P2"),
    ("OB-06", "Heart piece", "Collectible quarter-heart, bobbing; 4 make a heart. Idle shine loop 6.", "P1"),
    ("OB-07", "Lost joke page", "Torn page from the Jester's joke book. Flutter loop 6.", "P1"),
    ("OB-08", "Bell (currency)", "Small jester bell, spin loop 4, plus a bell cache (pile/chest) pickup.", "P1"),
]

UI = [
    ("UI-01", "Game logo / title lettering", "'The Jester's Court' for the title screen (transparent PNG, ~1600 px wide).", "P1"),
    ("UI-02", "Fonts", "Display font for titles/banners and a readable body font (licensed for commercial use; OTF/TTF).", "P1"),
    ("UI-03", "HUD hearts", "Full, empty, breaking (4) and quarter-piece indicator. Current heart is the pack heart.", "P1"),
    ("UI-04", "Bell counter icon", "Small bell icon for the HUD.", "P1"),
    ("UI-05", "Ability icons x5", "Hammer Twirl, Hammer Vault, Cracking Slam, Wall Bounce, Phantom Step.", "P1"),
    ("UI-06", "Charm icons x9", "Rubber Nose, Juggler's Gloves, Lucky Bell, Heavy Head, Spring Heels, Cartwheel, Thick Skull, Pratfall, Encore.", "P1"),
    ("UI-07", "Menu frame kit", "9-slice panel, button (normal/hover/focus/pressed/disabled), slider, checkbox, in the court style.", "P2"),
    ("UI-08", "Map icons", "Shrine, shop, boss, friend, heart piece, player marker; room fill per area.", "P2"),
    ("UI-09", "Boss health bar frame", "Ornate frame + fill + damage-lag fill.", "P2"),
    ("UI-10", "Input prompts", "Keyboard and gamepad glyphs for E/Y interact, etc.", "P3"),
]

STORY = [
    ("ST-01..06", "Intro cards x6", "One illustration per intro line: the Fool's joke, the King not laughing, the moat, the festival moon a year later, the grin climbing out, 'the punchline is upstairs'. 1920 x 1080."),
    ("ST-07..12", "Ending cards x6", "Crown rolling, Seraphine laughing, the whole Court laughing, the King finally laughing, the bow, curtain down. 1920 x 1080."),
    ("ST-13", "Title background", "Optional painted key art for the title screen (currently the Carnival Gate sky)."),
]

VFX = [
    ("FX-01", "Parry flash", "Gold ring + sparkle when a shot is batted back."),
    ("FX-02", "Phantom Step trail", "Ghostly afterimage tint/streak for the ghost dash."),
    ("FX-03", "Shockwave ring", "Ground ring for Cracking Slam / boss slams (current ring.png is a placeholder)."),
    ("FX-04", "Steam column", "Colossus vents, looping 6 frames, ~110 x 900."),
    ("FX-05", "Judgement pillar", "Inquisitor's light pillar, 6 frames, ~120 x 420."),
    ("FX-06", "Telegraph textures", "Optional: patterned warning zones to replace the flat flashing rectangles."),
    ("FX-07", "Area motes", "Optional sprites for ambient particles per area (petals, dust, embers, sparks)."),
]

JESTER = [
    ("JS-01", "Wall slide + wall bounce", "slide (2-3 loop), kick off (3)", "P1"),
    ("JS-02", "Phantom Step dash", "ghost dash pose (can reuse dash with a variant palette)", "P2"),
    ("JS-03", "Shrine rest / interact", "sit/bow at shrine (4), read sign / talk (2)", "P2"),
    ("JS-04", "Ability get", "triumphant hammer raise (4-6)", "P2"),
    ("JS-05", "Ending bow", "deep theatrical bow (6)", "P2"),
    ("JS-06", "Drop through ledge", "brief crouch (2)", "P3"),
]


# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------

def on_page(canvas, doc):
    canvas.saveState()
    w, h = doc.pagesize
    canvas.setFillColor(PLUM)
    canvas.rect(0, h - 10 * mm, w, 10 * mm, stroke=0, fill=1)
    canvas.setFillColor(GOLD)
    canvas.setFont("Helvetica-Bold", 9)
    canvas.drawString(12 * mm, h - 6.5 * mm, "THE JESTER'S COURT  -  ART ASSET REQUESTS")
    canvas.setFillColor(GREY)
    canvas.setFont("Helvetica", 8)
    canvas.drawRightString(w - 12 * mm, 7 * mm, "Page %d" % doc.page)
    canvas.restoreState()


def section(title, intro, rows, widths, story):
    story.append(p(title, H1))
    if intro:
        story.append(p(intro))
        story.append(Spacer(1, 6))
    story.append(table(rows, widths))


def main():
    doc = SimpleDocTemplate(str(OUT), pagesize=landscape(A4), leftMargin=12 * mm, rightMargin=12 * mm,
                            topMargin=16 * mm, bottomMargin=14 * mm, title="The Jester's Court - Art Asset Requests",
                            author="Lead developer")
    W = landscape(A4)[0] - 24 * mm
    story = []

    # Cover.
    story.append(Spacer(1, 30 * mm))
    story.append(p("The Jester's Court", TITLE))
    story.append(Spacer(1, 4 * mm))
    story.append(p("Art asset requests for the art department", SUB))
    story.append(p("Everything the finished game needs that is currently a labelled shape, a placeholder or reused carnival art.", SUB))
    story.append(Spacer(1, 12 * mm))
    counts = [
        ["Section", "Items", "Priority P1"],
        ["Characters & NPCs", len(CHARACTERS), sum(1 for r in CHARACTERS if r[6] == "P1")],
        ["Enemies", len(ENEMIES), len(ENEMIES)],
        ["Bosses", len(BOSSES), len(BOSSES)],
        ["Jester additions", len(JESTER), sum(1 for r in JESTER if r[3] == "P1")],
        ["Projectiles", len(PROJECTILES), len(PROJECTILES)],
        ["Environments", len(ENVIRONMENT), sum(1 for r in ENVIRONMENT if r[3] == "P1")],
        ["Interactables & pickups", len(INTERACT), sum(1 for r in INTERACT if r[3] == "P1")],
        ["UI", len(UI), sum(1 for r in UI if r[3] == "P1")],
        ["Story illustrations", 13, 0],
        ["Effects", len(VFX), 0],
    ]
    t = table(counts, [90 * mm, 30 * mm, 30 * mm])
    t.hAlign = "CENTER"
    story.append(t)
    story.append(PageBreak())

    # Delivery spec.
    story.append(p("How to deliver", H1))
    story.append(p(
        "Deliver the same way as the Jester, mace knight and bat knight sheets: one PNG sprite sheet per animation, frames in a grid, "
        "the character facing <b>right</b>, the same scale on every sheet of a character. The existing pipelines "
        "(<font face='Courier'>tools/art/process_*_sheets.py</font>) key the background, split the grid, align every frame on the feet "
        "(or body centre for flyers) and build the Godot animations, so loose generator output is fine; clean transparent PNGs are better."))
    story.append(Spacer(1, 4))
    spec = [
        ["Rule", "Detail"],
        ["Resolution", "Author at <b>2x</b> the in-game size listed (the game draws at 0.5 with mipmaps). Example: the Arbalest is 92 px tall in game, so draw it about 184 px tall."],
        ["Background", "Transparent PNG preferred. Flat white/near-white or checker also works (the pipeline keys it). Avoid painted ground shadows, captions and motion lines - or keep them clearly detached so they are dropped."],
        ["Framing", "Leave padding around each frame; keep effects that belong to a frame inside its cell. Same camera distance on every sheet."],
        ["Facing", "Right-facing only. The game mirrors."],
        ["Anchor", "Ground characters: feet on a common baseline. Flyers: body centre. Bosses: feet."],
        ["Frame counts", "The numbers given are guides. Attack frames are picked from the gameplay phase (windup / active / recover), so tell us which frames belong to which phase."],
        ["Readability", "Every windup must read as a warning at 1080p from across a room. Weak points (Bulwark's back, Colossus's head) must be obvious."],
        ["Palette", "Vivid, moonlit carnival; each area has its own tint (see the stand-in screenshots). Ink outlines like the Jester."],
        ["Tiles", "Terrain tiles as in the current pack: 128 px authored squares, top-surface variants and body variants, seamless."],
        ["Naming", "<font face='Courier'>&lt;id&gt;_&lt;animation&gt;.png</font>, e.g. <font face='Courier'>EN-01_windup.png</font>. Put them in assets/source/&lt;name&gt;/sheets/."],
    ]
    story.append(table(spec, [40 * mm, W - 40 * mm]))
    story.append(Spacer(1, 8))
    story.append(p("Priorities", H2))
    story.append(p("<b>P1</b> - needed to ship (the game still shows a labelled shape or the wrong area's art). "
                   "<b>P2</b> - strongly wanted for polish. <b>P3</b> - nice to have."))
    story.append(PageBreak())

    # Stand-in screenshots.
    story.append(p("What the stand-ins look like today", H1))
    story.append(p("Everything below is in the game and playable. Labelled shapes mark every character still waiting for art; the "
                   "tint and lighting per area are final-ish and show the intended mood."))
    story.append(Spacer(1, 4))
    if (SHOTS / "bosses.png").exists():
        img = Image(str(SHOTS / "bosses.png"), width=W * 0.58, height=W * 0.58 * (1620 / 1920))
        side = []
        for name in ("03_royal_gardens.png", "04_grand_halls.png"):
            if (SHOTS / name).exists():
                side.append([Image(str(SHOTS / name), width=W * 0.38, height=W * 0.38 * 9 / 16)])
        grid = Table([[img, Table(side)]], colWidths=[W * 0.6, W * 0.4])
        story.append(grid)
        story.append(p("Left: all six bosses mid-fight (stand-ins). Right: Royal Gardens and Grand Halls rooms with enemy stand-ins.", SMALL))
    story.append(PageBreak())

    section("1. Bosses (P1)",
            "Six bosses, each with three health phases. Sizes are in-game pixels at 1080p (draw at 2x). Every attack has a "
            "telegraph in code; the art should sell the windup.",
            [["ID", "Boss", "Area", "Size", "Look & behaviour", "Animations needed"]] +
            [[r[0], r[1], r[2], r[3], r[4], r[5]] for r in BOSSES],
            [16 * mm, 32 * mm, 24 * mm, 22 * mm, 85 * mm, W - 179 * mm], story)
    story.append(PageBreak())

    section("2. Enemies (P1)",
            "Ten new enemy types plus final art for the Court Guard. The mace knight and bat knight are already done. "
            "All enemies can be launched, so each needs a tumbling 'launched' pose and a lying 'knocked down' frame.",
            [["ID", "Enemy", "Where", "Size", "Look & behaviour", "Animations needed"]] +
            [[r[0], r[1], r[2], r[3], r[4], r[5]] for r in ENEMIES],
            [16 * mm, 28 * mm, 30 * mm, 20 * mm, 80 * mm, W - 174 * mm], story)
    story.append(PageBreak())

    section("3. Characters, NPCs and Jester additions",
            None,
            [["ID", "Character", "Where", "Size", "Look", "Animations", "Priority"]] +
            [list(r) for r in CHARACTERS],
            [16 * mm, 34 * mm, 34 * mm, 22 * mm, 90 * mm, W - 226 * mm, 30 * mm], story)
    story.append(Spacer(1, 8))
    story.append(p("Jester: new animations for the earned abilities", H2))
    story.append(table([["ID", "Animation", "Frames", "Priority"]] + [list(r) for r in JESTER],
                       [16 * mm, 60 * mm, W - 116 * mm, 40 * mm]))
    story.append(PageBreak())

    section("4. Environments",
            "The castle has six areas. Only the Carnival Gate has its own art; the other five reuse the carnival tile pack with a "
            "colour tint. Each area needs its own terrain set, back wall, backdrop and props.",
            [["ID", "Asset", "Description", "Priority"]] + [list(r) for r in ENVIRONMENT],
            [18 * mm, 50 * mm, W - 98 * mm, 30 * mm], story)
    story.append(Spacer(1, 6))
    story.append(p("Area mood references (current lighting): Carnival Gate - moonlit festival pinks; Outer Walls - cold blue night; "
                   "Royal Gardens - green moonlight, roses; Grand Halls - warm candlelit amber; Clockworks - orange furnace glow; "
                   "Throne Spire - royal purple and gold.", SMALL))
    story.append(PageBreak())

    section("5. Projectiles",
            "Every enemy shot can be hit back by the hammer, so shots need to be readable and 'hittable'. A gold reflected tint is applied in code.",
            [["ID", "Projectile", "Used by", "Size", "Frames"]] + [list(r) for r in PROJECTILES],
            [18 * mm, 50 * mm, 50 * mm, 40 * mm, W - 158 * mm], story)
    story.append(Spacer(1, 8))
    section("6. Interactables and pickups", None,
            [["ID", "Object", "Description", "Priority"]] + [list(r) for r in INTERACT],
            [18 * mm, 45 * mm, W - 93 * mm, 30 * mm], story)
    story.append(PageBreak())

    section("7. UI", "All menus and HUD are built in code with a placeholder theme and the engine's default font.",
            [["ID", "Asset", "Description", "Priority"]] + [list(r) for r in UI],
            [18 * mm, 50 * mm, W - 98 * mm, 30 * mm], story)
    story.append(Spacer(1, 8))
    section("8. Story illustrations (P2)", "Minimal story: an intro and an ending, each six full-screen cards. Text is already written (scripts/systems/story.gd).",
            [["ID", "Asset", "Description"]] + [list(r) for r in STORY],
            [22 * mm, 45 * mm, W - 67 * mm], story)
    story.append(Spacer(1, 8))
    section("9. Effects (P2-P3)", None,
            [["ID", "Effect", "Description"]] + [list(r) for r in VFX],
            [18 * mm, 45 * mm, W - 63 * mm], story)
    story.append(PageBreak())

    story.append(p("Not needed from art", H1))
    story.append(p("Music, ambience and every sound effect are synthesised in code (tools/audio/synth.py) and already in the game. "
                   "If the audio team wants to replace them, the file names in assets/audio/ are the contract: drop in an OGG with the same name. "
                   "Lighting, screen shake, slow motion, flashes, telegraph timing and all particles are code-driven."))
    story.append(Spacer(1, 6))
    story.append(p("Questions for the creative director", H2))
    for q in [
        "Pippet and the Court Spook: are these the right two recurring NPCs, or should one be a known character from the Bible?",
        "The King's Act 3 flight: flying throne, cape glide, or carried by guards? The code only needs 'airborne' poses.",
        "Should the five areas keep the carnival tile shapes (only re-skinned) or get new silhouettes? New shapes are fine; collision is generated, not drawn.",
    ]:
        story.append(p("- " + q))

    doc.build(story, onFirstPage=on_page, onLaterPages=on_page)
    print("wrote", OUT)


if __name__ == "__main__":
    main()
