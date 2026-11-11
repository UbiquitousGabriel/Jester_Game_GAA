#!/usr/bin/env python3
"""Generates the castle: every room of The Jester's Court.

Output: scripts/world/world_data.gd   (class WorldData: rooms, doors, entities)
        docs/world/world_map.png        (overview for review)
        docs/world/world_report.md      (counts, progression check)

Design
------
The castle is a grid of cells, each CW x CH tiles (36 x 20, 64 px tiles =
2304 x 1280 world px). Six areas own rectangular regions of the grid. Each
area grows a connected set of cells from its entrance; some neighbouring
cells merge into wide or tall rooms. Doors sit at fixed positions on cell
edges so neighbouring rooms always line up:

  side doors   rows 12..16 of the cell row, standing on floor row 17
  vertical     columns 15..20 of the cell column, with a ladder of one-way
               platforms on every global row divisible by 3, so a climb
               continues seamlessly from one room into the next

Gates use movement reach (MovementConfig defaults, see docs/WORLD.md):
  glide       15-tile bottomless chasm   jump+dash reaches ~8.6 tiles
  vault       8-row wall                  jump+up-dash reaches ~7 rows
  slam        cracked stone in the door   only a charged Cracking Slam breaks it
  wallkick    18-row smooth shaft         vault+dash reaches ~11 rows
  ghost_dash  spectral barrier            only Phantom Step passes
Gate rooms get no flying enemies (no pogo shortcuts).

Progression is validated by a breadth-first search that unlocks abilities
only by reaching the boss that grants them.

Usage: python3 tools/world/build_world.py [seed]
"""
import json
import random
import sys
from collections import deque
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CW, CH = 36, 20
TILE = 64
DOOR_ROWS = range(12, 17)      # side-door opening rows within a cell row
DOOR_FLOOR = 17                # floor row under a side door
VDOOR_COLS = range(15, 21)     # vertical-door opening columns within a cell column
LADDER_A = range(13, 19)       # ladder platform columns, even steps
LADDER_B = range(17, 23)       # ladder platform columns, odd steps

AREAS = {
    # id: (name, box x0, x1, y0, y1 inclusive, target cells, music, enemies)
    "carnival_gate": ("Carnival Gate", 0, 7, 12, 17, 22,
                      ["guard", "guard", "bat", "balloon", "springer"]),
    "outer_walls": ("Outer Walls", 8, 13, 5, 17, 24,
                    ["guard", "arbalest", "mace_knight", "bulwark", "bat", "cannon"]),
    "royal_gardens": ("Royal Gardens", 0, 7, 5, 11, 23,
                      ["hound", "wisp", "bat", "springer", "arbalest", "guard"]),
    "grand_halls": ("Grand Halls", 1, 13, 0, 4, 25,
                    ["porcelain", "inquisitor", "mace_knight", "bulwark", "arbalest", "wisp"]),
    "clockworks": ("Clockworks", 9, 14, -7, -1, 23,
                   ["springer", "clockwork_knight", "cannon", "hound", "bat", "balloon"]),
    "throne_spire": ("Throne Spire", 4, 8, -7, -1, 15,
                     ["inquisitor", "mace_knight", "bulwark", "wisp", "clockwork_knight", "porcelain"]),
}
ORDER = ["carnival_gate", "outer_walls", "royal_gardens", "grand_halls", "clockworks", "throne_spire"]
BOSS = {"carnival_gate": "ringmaster", "outer_walls": "executioner", "royal_gardens": "mourning_bell",
        "grand_halls": "acrobat_twins", "clockworks": "colossus", "throne_spire": "king"}
GRANTS = {"ringmaster": "glide", "executioner": "vault", "mourning_bell": "slam",
          "acrobat_twins": "wallkick", "colossus": "ghost_dash", "king": None}
# Entrances between areas: (from area, cell, to area, cell, gate). The gate
# guards the from-side room.
LINKS = [
    ("carnival_gate", (7, 14), "outer_walls", (8, 14), "glide"),
    ("outer_walls", (8, 8), "royal_gardens", (7, 8), "vault"),
    ("royal_gardens", (3, 5), "grand_halls", (3, 4), "slam"),
    ("grand_halls", (11, 0), "clockworks", (11, -1), "wallkick"),
    ("clockworks", (9, -5), "throne_spire", (8, -5), "ghost_dash"),
    # Later-ability shortcuts back into earlier areas.
    ("royal_gardens", (1, 11), "carnival_gate", (1, 12), "slam"),
    ("outer_walls", (12, 5), "grand_halls", (12, 4), "wallkick"),
]
ABILITY_ORDER = ["glide", "vault", "slam", "wallkick", "ghost_dash"]
FLYERS = {"bat", "balloon", "wisp"}
HEART_PIECES_PER_AREA = 4
JOKES_PER_AREA = 7


class Room:
    def __init__(self, rid, area, cells):
        self.id = rid
        self.area = area
        self.cells = cells
        self.x0 = min(c[0] for c in cells)
        self.y0 = min(c[1] for c in cells)
        self.cw = max(c[0] for c in cells) - self.x0 + 1
        self.ch = max(c[1] for c in cells) - self.y0 + 1
        self.doors = []          # (side, index along that side, neighbour room id, gate)
        self.kind = "normal"     # normal, start, shrine, shop, boss, altar, npc, entrance
        self.features = []       # heart, joke, bells, sign...
        self.depth = 0
        self.grid = None
        self.entities = []
        self.title = ""


# --------------------------------------------------------------------------- layout


def grow_area(area, rng, seeds, taken):
    _, x0, x1, y0, y1, target, _ = AREAS[area]
    cells = set()
    edges = set()
    frontier = []
    for s in seeds:
        cells.add(s)
        taken[s] = area
        frontier.append(s)
    while len(cells) < target and frontier:
        base = rng.choice(frontier[-6:] if rng.random() < 0.65 else frontier)
        options = []
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            n = (base[0] + dx, base[1] + dy)
            if x0 <= n[0] <= x1 and y0 <= n[1] <= y1 and n not in taken:
                options.append(n)
        if not options:
            frontier.remove(base)
            continue
        # Prefer horizontal growth: castles read better wide than tall.
        options.sort(key=lambda n: (n[1] != base[1]) + rng.random() * 1.2)
        n = options[0]
        cells.add(n)
        taken[n] = area
        edges.add(frozenset((base, n)))
        frontier.append(n)
    # A few loops so the area is not a pure tree.
    cl = sorted(cells)
    for c in cl:
        for dx, dy in ((1, 0), (0, 1)):
            n = (c[0] + dx, c[1] + dy)
            if n in cells and frozenset((c, n)) not in edges and rng.random() < 0.18:
                edges.add(frozenset((c, n)))
    return cells, edges


def connect_cell(area, cells, edges, target, taken):
    """Adds a shortest in-box path from the area to `target`."""
    if target in cells:
        return
    _, x0, x1, y0, y1, _, _ = AREAS[area]
    prev = {c: None for c in cells}
    q = deque(cells)
    while q:
        c = q.popleft()
        if c == target:
            break
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            n = (c[0] + dx, c[1] + dy)
            if n in prev or not (x0 <= n[0] <= x1 and y0 <= n[1] <= y1):
                continue
            if taken.get(n, area) != area:
                continue
            prev[n] = c
            q.append(n)
    if target not in prev:
        raise SystemExit(f"{area}: cannot reach link cell {target}")
    c = target
    while prev[c] is not None:
        cells.add(c)
        taken[c] = area
        edges.add(frozenset((c, prev[c])))
        c = prev[c]


def build_layout(rng):
    taken = {}
    area_cells, area_edges = {}, {}
    for a, ca, b, cb, _ in LINKS:
        taken[ca] = a
        taken[cb] = b
    starts = {
        "carnival_gate": [(0, 17)],
        "outer_walls": [(8, 15)],
        "royal_gardens": [(7, 9)],
        "grand_halls": [(4, 4)],
        "clockworks": [(11, -1)],
        "throne_spire": [(8, -4)],
    }
    for area in ORDER:
        # Link cells are reserved for their area but join it only by a path.
        reserved = [c for c, a in taken.items() if a == area]
        for c in reserved:
            del taken[c]
        for c in reserved:
            if c not in starts[area]:
                taken[c] = "__reserved__" + area
        cells, edges = grow_area(area, rng, starts[area], taken)
        for c in reserved:
            if taken.get(c) == "__reserved__" + area:
                del taken[c]
            connect_cell(area, cells, edges, c, taken)
        area_cells[area] = cells
        area_edges[area] = edges
    # Reserve marks for later areas must not leak into earlier ones.
    for c, a in list(taken.items()):
        if a.startswith("__reserved__"):
            taken[c] = a[len("__reserved__"):]
    return taken, area_cells, area_edges


def find_link(taken, a, b, orient, rng, avoid=()):
    candidates = []
    for c, area in taken.items():
        if area != a:
            continue
        deltas = [(1, 0), (-1, 0)] if orient == "h" else [(0, -1), (0, 1)]
        for dx, dy in deltas:
            n = (c[0] + dx, c[1] + dy)
            if taken.get(n) == b and frozenset((c, n)) not in avoid:
                candidates.append((c, n))
    if not candidates:
        raise SystemExit(f"no {orient} link between {a} and {b}")
    return rng.choice(candidates)


# --------------------------------------------------------------------------- rooms


def merge_rooms(area, cells, edges, rng, reserved):
    """Groups cells into rooms (1x1, 2x1, 1x2) along existing edges."""
    room_of = {}
    rooms = []
    order = sorted(cells, key=lambda c: (c[1], c[0]))
    rng.shuffle(order)
    for c in order:
        if c in room_of:
            continue
        group = [c]
        if c not in reserved and rng.random() < 0.42:
            dirs = [(1, 0), (0, 1)] if rng.random() < 0.7 else [(0, 1), (1, 0)]
            for dx, dy in dirs:
                n = (c[0] + dx, c[1] + dy)
                if n in cells and n not in room_of and n not in reserved and frozenset((c, n)) in edges:
                    group.append(n)
                    break
        rid = f"{area}_{len(rooms) + 1:02d}"
        room = Room(rid, area, group)
        for g in group:
            room_of[g] = room
        rooms.append(room)
    return rooms, room_of


def add_doors(rooms_by_cell, edges, gates):
    for e in edges:
        a, b = tuple(e)
        ra, rb = rooms_by_cell[a], rooms_by_cell[b]
        if ra is rb:
            continue
        gate = gates.get(e)
        for (c, n, r, other) in ((a, b, ra, rb), (b, a, rb, ra)):
            dx, dy = n[0] - c[0], n[1] - c[1]
            if dx == 1:
                side, idx = "R", c[1] - r.y0
            elif dx == -1:
                side, idx = "L", c[1] - r.y0
            elif dy == 1:
                side, idx = "D", c[0] - r.x0
            else:
                side, idx = "U", c[0] - r.x0
            gate_here = gate[0] if gate and gate[1] is r else None
            door = (side, idx, other.id, gate_here)
            if door not in r.doors:
                r.doors.append(door)


# --------------------------------------------------------------------------- interiors


def carve_room(room, rng, area_index):
    W, H = room.cw * CW, room.ch * CH
    g = [["#"] * W for _ in range(H)]

    def put(x, y, ch):
        if 0 <= x < W and 0 <= y < H:
            g[y][x] = ch

    def rect(x0, y0, x1, y1, ch):
        for yy in range(y0, y1 + 1):
            for xx in range(x0, x1 + 1):
                put(xx, yy, ch)

    # Hollow interior: 2-tile walls and ceiling, 3-tile floor.
    rect(2, 2, W - 3, H - 4, ".")
    for r in range(room.ch - 1):
        pass  # interior between stacked cells stays open

    gy0 = room.y0 * CH
    gate_cols = set()
    gated_vertical = {}
    for side, idx, _, gate in room.doors:
        if side in "UD" and gate:
            gated_vertical[(side, idx)] = gate

    # Ladders: every cell column of tall rooms, and every vertical door.
    ladder_cols = set()
    if room.ch > 1:
        ladder_cols.update(range(room.cw))
    for side, idx, _, gate in room.doors:
        if side in "UD":
            ladder_cols.add(idx)

    # Doors.
    for side, idx, _, gate in room.doors:
        if side in "LR":
            x0 = 0 if side == "L" else W - 2
            base = idx * CH
            rect(x0, base + DOOR_ROWS.start, x0 + 1, base + DOOR_ROWS.stop - 1, ".")
            # Ledge from an upper side door to the ladder column.
            if idx < room.ch - 1:
                col = 0 if side == "L" else room.cw - 1
                lx0, lx1 = (2, col * CW + 14) if side == "L" else (col * CW + 21, W - 3)
                for xx in range(lx0, lx1 + 1):
                    put(xx, base + DOOR_FLOOR, "=")
        else:
            cx = idx * CW
            if side == "U":
                rect(cx + VDOOR_COLS.start, 0, cx + VDOOR_COLS.stop - 1, 1, ".")
            else:
                rect(cx + VDOOR_COLS.start, H - 3, cx + VDOOR_COLS.stop - 1, H - 1, ".")

    for col in ladder_cols:
        cx = col * CW
        top_open = any(d[0] == "U" and d[1] == col for d in room.doors)
        bottom_open = any(d[0] == "D" and d[1] == col for d in room.doors)
        y_top = 1 if top_open else 3
        y_bottom = H - 1 if bottom_open else H - 4
        gate = gated_vertical.get(("U", col))
        for y in range(y_top, y_bottom + 1):
            gyy = gy0 + y
            if gyy % 3 != 0:
                continue
            cols = LADDER_A if (gyy // 3) % 2 == 0 else LADDER_B
            if gate == "wallkick" and y < H - 4:
                continue  # smooth shaft: no ladder
            for xx in cols:
                if g[y][cx + xx] == ".":
                    put(cx + xx, y, "=")
        if gate == "wallkick":
            # Smooth shaft walls around the vertical door, open at the bottom.
            for y in range(0, H - 6):
                for xx in (VDOOR_COLS.start - 3, VDOOR_COLS.start - 2, VDOOR_COLS.stop + 1, VDOOR_COLS.stop + 2):
                    put(cx + xx, y, "#")
            # Re-open the ceiling door in case walls overlapped it.
            rect(cx + VDOOR_COLS.start, 0, cx + VDOOR_COLS.stop - 1, 1, ".")
            gate_cols.update(range(cx + VDOOR_COLS.start - 4, cx + VDOOR_COLS.stop + 4))
        elif gate in ("slam", "ghost_dash", "vault", "glide"):
            # Enclose the climb so the gate obstacle guards its entrance.
            for y in range(0, H - 6):
                for xx in (VDOOR_COLS.start - 4, VDOOR_COLS.stop + 3):
                    put(cx + xx, y, "#")
            rect(cx + VDOOR_COLS.start, 0, cx + VDOOR_COLS.stop - 1, 1, ".")
            entrance_x = cx + VDOOR_COLS.start - 4
            ch_ = {"slam": "%", "ghost_dash": "~"}.get(gate)
            if ch_:
                rect(entrance_x, H - 6, entrance_x, H - 4, ch_)
                rect(cx + VDOOR_COLS.stop + 3, H - 6, cx + VDOOR_COLS.stop + 3, H - 4, ch_)
            elif gate == "vault":
                rect(entrance_x - 3, H - 11, entrance_x, H - 4, "#")
                rect(cx + VDOOR_COLS.stop + 3, H - 11, cx + VDOOR_COLS.stop + 6, H - 4, "#")
            gate_cols.update(range(cx + VDOOR_COLS.start - 8, cx + VDOOR_COLS.stop + 8))

    # Horizontal gates in front of side doors.
    for side, idx, _, gate in room.doors:
        if side not in "LR" or not gate:
            continue
        base = idx * CH
        floor = base + DOOR_FLOOR
        inward = 1 if side == "L" else -1
        door_x = 2 if side == "L" else W - 3
        if gate == "glide":
            # 15-tile bottomless chasm with a 2-tile landing by the door.
            start = door_x + inward * 2
            cols = [start + inward * i for i in range(15)]
            for xx in cols:
                for yy in range(floor, H):
                    put(xx, yy, ".")
            gate_cols.update(cols)
        elif gate == "vault":
            xs = [door_x + inward * (5 + i) for i in range(4)]
            for xx in xs:
                for yy in range(floor - 8, floor):
                    put(xx, yy, "#")
            gate_cols.update(range(min(xs) - 4, max(xs) + 5))
        elif gate in ("slam", "ghost_dash"):
            ch_ = "%" if gate == "slam" else "~"
            for xx in (door_x, door_x + inward):
                for yy in DOOR_ROWS:
                    put(xx, base + yy, ch_)
            gate_cols.update(range(door_x - 3, door_x + 4))
        elif gate == "wallkick":
            # Horizontal wallkick gate: the door sits atop a smooth 18-row
            # cliff; a parallel wall 5 tiles in forms the bounce shaft.
            pass

    room.grid = g
    room.gate_cols = gate_cols
    room.ladder_cols = ladder_cols
    decorate_floor(room, rng, area_index)
    add_balconies(room, rng)


def floor_row(room):
    return room.ch * CH - 3


def free_columns(room):
    """Bottom-floor columns safe for features: away from doors, ladders, gates."""
    W = room.cw * CW
    blocked = set(room.gate_cols)
    for col in room.ladder_cols:
        blocked.update(range(col * CW + 11, col * CW + 25))
    for side, idx, _, _ in room.doors:
        if side == "L" and idx == room.ch - 1:
            blocked.update(range(0, 8))
        if side == "R" and idx == room.ch - 1:
            blocked.update(range(W - 8, W))
        if side == "D":
            blocked.update(range(idx * CW + 12, idx * CW + 24))
    return [x for x in range(4, W - 4) if x not in blocked]


def decorate_floor(room, rng, area_index):
    g = room.grid
    W = room.cw * CW
    fr = floor_row(room)
    free = set(free_columns(room))
    if room.kind == "boss":
        # Arena ledges: two side perches and a high centre one, so fights
        # happen in the air as much as on the floor.
        for x0, x1, y in ((8, 15, fr - 4), (W - 16, W - 9, fr - 4), (W // 2 - 4, W // 2 + 4, fr - 8)):
            for c in range(x0, x1):
                if g[y][c] == ".":
                    g[y][c] = "="
        return
    if room.kind in ("shrine", "shop", "altar", "start"):
        return
    x = 6
    while x < W - 10:
        span = [x + i for i in range(rng.randint(3, 6))]
        if not all(s in free for s in span):
            x += 1
            continue
        roll = rng.random()
        if roll < 0.20:
            # Spike pit, jumpable (3-4 wide), spikes 2 rows down.
            width = rng.randint(3, 4)
            cols = [x + i for i in range(width)]
            if all(c in free for c in cols):
                for c in cols:
                    g[fr][c] = "."
                    g[fr + 1][c] = "^"
                x += width + rng.randint(4, 7)
                continue
        elif roll < 0.42:
            # Raised step, 1-2 rows.
            h = rng.randint(1, 2)
            for c in span:
                for yy in range(fr - h, fr):
                    g[yy][c] = "#"
            x += len(span) + rng.randint(3, 6)
            continue
        elif roll < 0.62:
            # Floating platform 3 rows up, sometimes a second tier.
            for c in span:
                g[fr - 3][c] = "="
            if rng.random() < 0.4 and fr - 6 > 3:
                for c in span:
                    g[fr - 6][c + 2 if c + 2 < W - 3 else c] = "="
            x += len(span) + rng.randint(4, 8)
            continue
        elif roll < 0.72:
            g[fr - 1][x] = "C"
            if rng.random() < 0.5 and x + 1 in free:
                g[fr - 1][x + 1] = "C"
            x += rng.randint(5, 9)
            continue
        elif roll < 0.78:
            g[fr - 1][x] = "S"
            x += rng.randint(6, 10)
            continue
        x += rng.randint(2, 5)


def add_balconies(room, rng):
    """One-way side platforms at varied heights: alternative routes, perches
    for enemies and loot. One-way, so they never block a path."""
    if room.kind in ("boss", "shrine", "shop", "altar"):
        return
    g = room.grid
    W, H = room.cw * CW, room.ch * CH
    blocked = set(room.gate_cols)
    for col in room.ladder_cols:
        blocked.update(range(col * CW + 11, col * CW + 25))
    for cy in range(room.ch):
        for cx in range(room.cw):
            for _ in range(rng.randint(2, 4)):
                width = rng.randint(4, 7)
                x0 = cx * CW + rng.randint(3, CW - width - 3)
                y = cy * CH + rng.randint(4, 14)
                cols = range(x0, x0 + width)
                if any(c in blocked for c in cols):
                    continue
                # Keep clear of side-door openings and existing structure.
                near_wall = x0 < 9 or x0 + width > W - 9
                if near_wall and (y % CH) in range(10, 18):
                    continue
                if all(g[yy][c] == "." for yy in range(y - 3, y + 2) for c in cols):
                    for c in cols:
                        g[y][c] = "="


# --------------------------------------------------------------------------- entities


def standing_spots(room, flying=False):
    """Tiles (x, y) where something can stand (floor below) or hover."""
    g = room.grid
    W, H = room.cw * CW, room.ch * CH
    spots = []
    for y in range(3, H - 2):
        for x in range(4, W - 4):
            if x in room.gate_cols:
                continue
            if flying:
                if all(g[y + dy][x + dx] == "." for dy in range(-1, 2) for dx in range(-1, 2)):
                    spots.append((x, y))
            else:
                if g[y][x] == "." and g[y - 1][x] == "." and g[y + 1][x] in "#=":
                    spots.append((x, y))
    return spots


def place_entities(room, rng, area_index, diff):
    _, _, _, _, _, _, roster = AREAS[room.area]
    W, H = room.cw * CW, room.ch * CH
    ents = room.entities
    fr = floor_row(room)

    def ground_spot(min_gap=3):
        spots = standing_spots(room)
        rng.shuffle(spots)
        for s in spots:
            if all(abs(s[0] - e[1]) >= min_gap or abs(s[1] - e[2]) > 2 for e in ents):
                return s
        return spots[0] if spots else (W // 2, fr - 1)

    centre = (W // 2, fr - 1)
    if room.kind == "start":
        ents.append(["spawn", 8, fr - 1, {}])
        ents.append(["sign", 14, fr - 1, {"text": "intro"}])
        ents.append(["lamp", 22, fr - 1, {}])
    if room.kind == "shrine":
        ents.append(["shrine", centre[0], centre[1], {}])
        ents.append(["lamp", centre[0] - 6, fr - 1, {}])
        ents.append(["lamp", centre[0] + 6, fr - 1, {}])
        return
    if room.kind == "shop":
        ents.append(["shop", centre[0], centre[1], {}])
        ents.append(["lamp", centre[0] - 5, fr - 1, {}])
        return
    if room.kind == "boss":
        ents.append(["boss", centre[0], centre[1], {"id": BOSS[room.area]}])
        if "altar_inside" in room.features:
            boss = BOSS[room.area]
            if GRANTS[boss]:
                ents.append(["altar", centre[0] + 7, centre[1], {"ability": GRANTS[boss], "boss": boss}])
            else:
                ents.append(["ending", centre[0] + 7, centre[1], {}])
        ents.append(["torch", 6, fr - 4, {}])
        ents.append(["torch", W - 7, fr - 4, {}])
        return
    if room.kind == "altar":
        boss = BOSS[room.area]
        if GRANTS[boss]:
            ents.append(["altar", centre[0], centre[1], {"ability": GRANTS[boss], "boss": boss}])
        else:
            ents.append(["ending", centre[0], centre[1], {}])
        return
    if room.kind == "npc":
        ents.append(["npc", centre[0] - 3, centre[1], {"who": rng.choice(["spook", "pippet"]), "area": room.area}])
    if room.kind == "seal_door":
        ents.append(["seal_door", centre[0], centre[1], {}])

    # Enemies.
    if room.kind in ("normal", "entrance", "npc") and room.depth > 0:
        n = rng.randint(1, 2) + room.cw * room.ch - 1 + diff // 2
        n = min(n, 2 + room.cw * room.ch * 2)
        gated = bool(room.gate_cols)
        for _ in range(n):
            kind = rng.choice(roster)
            if gated and kind in FLYERS:
                kind = rng.choice([k for k in roster if k not in FLYERS] or ["guard"])
            if kind in FLYERS:
                spots = standing_spots(room, flying=True)
                if not spots:
                    continue
                s = rng.choice(spots)
            else:
                s = ground_spot()
            ents.append(["enemy", s[0], s[1], {"kind": kind, "tier": area_index}])

    # Lights.
    for i in range(room.cw):
        if rng.random() < 0.7:
            s = ground_spot(2)
            ents.append(["lamp" if room.area in ("carnival_gate", "royal_gardens") else "torch", s[0], s[1], {}])

    # Features (collectibles).
    for f in room.features:
        if f in ("heart", "joke", "bells"):
            # Prefer elevated, harder spots.
            spots = [s for s in standing_spots(room) if s[1] < fr - 2] or standing_spots(room)
            s = rng.choice(spots) if spots else centre
            ents.append([f, s[0], s[1], {"id": f"{room.id}:{f}:{len(ents)}"}])
        elif f == "sign":
            s = ground_spot()
            ents.append(["sign", s[0], s[1], {"text": room.sign}])


# --------------------------------------------------------------------------- main


def bfs_depths(rooms, start):
    by_id = {r.id: r for r in rooms}
    depth = {start.id: 0}
    q = deque([start.id])
    while q:
        rid = q.popleft()
        for _, _, nid, _ in by_id[rid].doors:
            if nid not in depth:
                depth[nid] = depth[rid] + 1
                q.append(nid)
    return depth


def validate(rooms, start_id):
    """Reach every room using abilities only after their boss is reached."""
    by_id = {r.id: r for r in rooms}
    have = set()
    order = []
    while True:
        seen = {start_id}
        q = deque([start_id])
        while q:
            rid = q.popleft()
            for side, idx, nid, gate in by_id[rid].doors:
                # Gate obstacles block both directions (chasm, wall, cracked
                # stone, barrier), wherever they sit. A wall-bounce shaft can
                # be dropped down freely.
                back = [d for d in by_id[nid].doors if d[2] == rid]
                gates_here = [g for g in [gate] + [d[3] for d in back] if g]
                blocked = False
                for g in gates_here:
                    if g in have:
                        continue
                    if g == "wallkick" and side == "D":
                        continue
                    blocked = True
                if blocked:
                    continue
                if nid not in seen:
                    seen.add(nid)
                    q.append(nid)
        gained = False
        for r in rooms:
            if r.kind == "boss" and r.id in seen:
                ab = GRANTS[BOSS[r.area]]
                if ab and ab not in have:
                    have.add(ab)
                    order.append((BOSS[r.area], ab, len(seen)))
                    gained = True
        if not gained:
            return seen, order


def main():
    seed = int(sys.argv[1]) if len(sys.argv) > 1 else 1337
    rng = random.Random(seed)
    taken, area_cells, area_edges = build_layout(rng)

    # Cross-area links and gates.
    gates = {}
    link_cells = set()
    for a, c, b, n, gate in LINKS:
        e = frozenset((c, n))
        area_edges[a].add(e)
        gates[e] = (gate, c)  # gate guards the side of cell c (area a)
        link_cells.update((c, n))

    # Rooms.
    rooms, rooms_by_cell = [], {}
    for ai, area in enumerate(ORDER):
        reserved = set(c for c in link_cells if taken.get(c) == area)
        reserved.add((0, 17))  # the start room stays a single, readable cell
        rs, by_cell = merge_rooms(area, area_cells[area], area_edges[area], rng, reserved)
        rooms += rs
        rooms_by_cell.update(by_cell)
    # Gate owner: the room containing the gate's cell.
    gates = {e: (g, rooms_by_cell[c]) for e, (g, c) in gates.items()}
    all_edges = set()
    for area in ORDER:
        all_edges |= area_edges[area]
    add_doors(rooms_by_cell, all_edges, gates)

    start = rooms_by_cell[(0, 17)]
    start.kind = "start"
    depths = bfs_depths(rooms, start)
    for r in rooms:
        r.depth = depths.get(r.id, 999)

    # Special rooms per area.
    srng = random.Random(seed + 7)
    for ai, area in enumerate(ORDER):
        ars = [r for r in rooms if r.area == area and r.kind == "normal"]
        entry = min(ars + [r for r in rooms if r.area == area and r.kind == "start"], key=lambda r: r.depth)
        has_gate = lambda r: any(d[3] for d in r.doors)
        # Boss: a deep room, prefer wide, never one that holds a gate.
        cand = sorted((r for r in ars if not has_gate(r) and r is not entry),
                      key=lambda r: (r.depth + (6 if r.cw > 1 else 0)), reverse=True)
        boss = cand[0]
        boss.kind = "boss"
        # Altar: a neighbour of the boss room (or the boss room itself).
        nbrs = [rr for rr in ars if rr.kind == "normal" and any(d[2] == boss.id for d in rr.doors)
                and not has_gate(rr) and rr.depth > boss.depth - 1]
        if nbrs:
            nbrs[0].kind = "altar"
        else:
            boss.features.append("altar_inside")
        free = [r for r in ars if r.kind == "normal" and not has_gate(r)]
        srng.shuffle(free)
        shrine_n = 2 if area != "throne_spire" else 1
        shrines = sorted(free, key=lambda r: r.depth)
        if shrines:
            # One shrine near the entry, one near the boss.
            near = min(shrines, key=lambda r: abs(r.depth - entry.depth - 2))
            near.kind = "shrine"
            if shrine_n > 1:
                far = [r for r in shrines if r.kind == "normal"]
                if far:
                    mid = min(far, key=lambda r: abs(r.depth - (boss.depth - 2)))
                    mid.kind = "shrine"
        free = [r for r in free if r.kind == "normal"]
        if free:
            free[0].kind = "shop"
        if len(free) > 2:
            free[1].kind = "npc"
        if area == "throne_spire":
            sd = [r for r in ars if r.kind == "normal" and r.depth == min(rr.depth for rr in ars)]
            if sd:
                sd[0].kind = "seal_door"
        # Collectibles: dead ends first.
        normals = [r for r in ars if r.kind in ("normal", "npc")]
        dead = sorted(normals, key=lambda r: (len(r.doors), -r.depth))
        for i in range(HEART_PIECES_PER_AREA):
            if dead:
                dead[i % len(dead)].features.append("heart")
        for i in range(JOKES_PER_AREA):
            srng.choice(normals).features.append("joke")
        for r in normals:
            if srng.random() < 0.35:
                r.features.append("bells")
    # Tutorial signs in the first area.
    tutorial = ["move", "pogo", "air_combo", "dash", "chain", "shrine"]
    cg = sorted((r for r in rooms if r.area == "carnival_gate" and r.kind == "normal"), key=lambda r: r.depth)
    for r, text in zip(cg, tutorial):
        r.features.append("sign")
        r.sign = text

    for ai, area in enumerate(ORDER):
        for r in rooms:
            if r.area == area:
                carve_room(r, rng, ai)
                place_entities(r, rng, ai, ai)

    seen, order = validate(rooms, start.id)
    unreachable = [r.id for r in rooms if r.id not in seen]
    king = next(r for r in rooms if r.kind == "boss" and r.area == "throne_spire")
    got = [o[1] for o in order]
    ok = not unreachable and got == ABILITY_ORDER and king.id in seen
    write_outputs(rooms, start, order, unreachable, ok, seed)
    print(f"seed {seed}: {len(rooms)} rooms, {sum(r.cw * r.ch for r in rooms)} cells, "
          f"abilities in order: {got}, unreachable: {len(unreachable)}, valid: {ok}")
    if not ok:
        raise SystemExit("world failed validation")


def write_outputs(rooms, start, order, unreachable, ok, seed):
    out = ROOT / "scripts" / "world" / "world_data.gd"
    out.parent.mkdir(parents=True, exist_ok=True)
    fr = floor_row(start)
    spawn = next(e for e in start.entities if e[0] == "spawn")
    sx = start.x0 * CW * TILE + spawn[1] * TILE + TILE // 2
    sy = start.y0 * CH * TILE + (spawn[2] + 1) * TILE - 4
    lines = [
        "class_name WorldData",
        "## Generated by tools/world/build_world.py (seed %d). Do not edit." % seed,
        "",
        "const TILE := %d" % TILE,
        "const CELL := Vector2i(%d, %d)" % (CW, CH),
        'const START_ROOM := "%s"' % start.id,
        "const START_POSITION := Vector2(%d, %d)" % (sx, sy),
        "const HEART_PIECE_COUNT := %d" % sum(1 for r in rooms for e in r.entities if e[0] == "heart"),
        "const JOKE_COUNT := %d" % sum(1 for r in rooms for e in r.entities if e[0] == "joke"),
        "const AREAS := %s" % json.dumps({a: {"name": AREAS[a][0], "index": i} for i, a in enumerate(ORDER)}),
        "",
        "## id -> {area, kind, origin (cells), size (cells), rows, doors, entities}",
        "const ROOMS := {",
    ]
    for r in rooms:
        rows = ["".join(row) for row in r.grid]
        doors = [[d[0], d[1], d[2], d[3] or ""] for d in r.doors]
        data = {
            "area": r.area, "kind": r.kind,
            "origin": [r.x0, r.y0], "size": [r.cw, r.ch],
            "doors": doors, "entities": r.entities, "rows": rows,
        }
        lines.append('\t"%s": %s,' % (r.id, json.dumps(data, separators=(",", ":"))))
    lines.append("}")
    out.write_text("\n".join(lines) + "\n")

    # Report and map.
    docs = ROOT / "docs" / "world"
    docs.mkdir(parents=True, exist_ok=True)
    counts = {}
    for r in rooms:
        counts.setdefault(r.area, {}).setdefault(r.kind, 0)
        counts[r.area][r.kind] += 1
    ents = {}
    for r in rooms:
        for e in r.entities:
            k = e[0] if e[0] != "enemy" else "enemy:" + e[3]["kind"]
            ents[k] = ents.get(k, 0) + 1
    rep = ["# World report", "", f"Seed {seed}. Valid: {ok}.", "",
           f"Rooms: {len(rooms)}. Cells: {sum(r.cw * r.ch for r in rooms)}.", "",
           "## Ability order (boss, ability, rooms reachable when gained)", ""]
    rep += [f"- {b} -> {a} ({n} rooms)" for b, a, n in order]
    rep += ["", "## Rooms by area and kind", "", "| Area | Kinds |", "| --- | --- |"]
    rep += [f"| {a} | {', '.join(f'{k} {v}' for k, v in sorted(c.items()))} |" for a, c in counts.items()]
    rep += ["", "## Entities", "", "| Entity | Count |", "| --- | --- |"]
    rep += [f"| {k} | {v} |" for k, v in sorted(ents.items())]
    rep += ["", f"Unreachable rooms: {unreachable or 'none'}"]
    (docs / "world_report.md").write_text("\n".join(rep) + "\n")
    draw_map(rooms, docs / "world_map.png")


def draw_map(rooms, path):
    from PIL import Image, ImageDraw
    colors = {"carnival_gate": (210, 60, 90), "outer_walls": (120, 130, 170), "royal_gardens": (90, 170, 100),
              "grand_halls": (200, 160, 70), "clockworks": (190, 120, 60), "throne_spire": (150, 90, 200)}
    s = 40
    xs = [r.x0 for r in rooms] + [r.x0 + r.cw for r in rooms]
    ys = [r.y0 for r in rooms] + [r.y0 + r.ch for r in rooms]
    ox, oy = -min(xs), -min(ys)
    img = Image.new("RGB", ((max(xs) + ox) * s + 20, (max(ys) + oy) * s + 20), (20, 14, 30))
    d = ImageDraw.Draw(img)
    marks = {"start": "S", "boss": "B", "altar": "A", "shrine": "+", "shop": "$", "npc": "?", "seal_door": "X"}
    for r in rooms:
        x0, y0 = (r.x0 + ox) * s + 10, (r.y0 + oy) * s + 10
        d.rectangle([x0 + 2, y0 + 2, x0 + r.cw * s - 2, y0 + r.ch * s - 2], fill=colors[r.area], outline=(0, 0, 0))
        if r.kind in marks:
            d.text((x0 + 8, y0 + 8), marks[r.kind], fill=(255, 255, 255))
        for side, idx, nid, gate in r.doors:
            if side == "R":
                p = (x0 + r.cw * s, y0 + idx * s + s // 2)
            elif side == "L":
                p = (x0, y0 + idx * s + s // 2)
            elif side == "U":
                p = (x0 + idx * s + s // 2, y0)
            else:
                p = (x0 + idx * s + s // 2, y0 + r.ch * s)
            col = (255, 255, 255) if not gate else (255, 230, 0)
            d.ellipse([p[0] - 3, p[1] - 3, p[0] + 3, p[1] + 3], fill=col)
            if gate:
                d.text((p[0] + 4, p[1] - 10), gate[:2], fill=(255, 230, 0))
    img.save(path)


if __name__ == "__main__":
    main()
