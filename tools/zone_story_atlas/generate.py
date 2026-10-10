from html import escape
from pathlib import Path

OUT = Path(__file__).resolve().parents[2] / "assets" / "zone_story_atlas"
OUT.mkdir(parents=True, exist_ok=True)

# x/y are normalized to the local map panel. Levels are recommended threat / quest bands.
ZONES = [
    dict(slug="tallowfields", name="Tallowfields / Meadow", band="1-12", theme="meadow", colors=[("Field green", "#8eaa69"), ("Oat gold", "#d6c27d"), ("Earth", "#766044")],
         story="A quiet farm start becomes a fight to keep the lanes, spring, and harvest safe. The first Warden is dangerous, but the grove around it also loses something after the encounter.",
         settlement="Wanderer's Rest is a tutorial camp; Tallowmere is the farm hamlet and service stop. Farmsteads, orchard, and windmill sit along the hedged lanes.",
         build="Plaster, thatch, timber frames, cart sheds, haylofts, a granary, fenced yards. Grain, flax, hides, herbs, and timber feed cooking, tailoring, smithing, and trade.",
         clue="Optional boundary stones and spring marks hint that the Hornstag watched the water. Nothing confirms why it became hostile.",
         pois=[("camp","Wanderer's Rest","1-3",8,68,-2,-17),("village","Farmsteads","2-6",34,43,-55,-17),("town","Tallowmere","4-8",59,40,14,-8),("landmark","Windmill Ridge","6-9",79,26,-92,-13),("cave","Burrow Cave","6-9",33,24,-5,-22),("boss","Grove Arena","10-12",86,72,-100,18)],
         roads=[("main",[(8,68),(19,58),(34,43),(48,48),(59,40),(73,42),(86,72)]),("side",[(34,43),(33,24),(49,18),(61,24),(79,26)]),("side",[(59,40),(72,56),(86,72)])]),
    dict(slug="campwater", name="Campwater Vale", band="2-11", theme="coast", colors=[("Vale grass", "#9fb791"), ("Shore sand", "#dfcda5"), ("Pond / sea", "#72aab4")],
         story="Fishing families and shore camps notice unreliable catches and crossings. A small local problem introduces cooking and gathering before the island's larger mysteries emerge.",
         settlement="Campwater Landing is a fishing hamlet. Southshore is a seasonal camp; Broken Towers and Tidegate Arch mark old coast routes.",
         build="Whitewashed cottages, slate-blue roofs, net racks, upturned boats, smoke sheds, and raised granaries. Fish, shell, cordage, and driftwood support food and crafting.",
         clue="A tide mark inside a dry tower is newer than the stonework around it; it is strange, not an explanation.",
         pois=[("camp","Southshore Camp","2-5",15,73,-4,19),("landmark","Pond / Oak Copse","3-6",42,45,-80,-11),("town","Campwater Landing","4-8",66,60,14,-8),("ruin","Broken Towers","6-9",30,25,-78,-12),("landmark","Tidegate Arch","8-11",85,32,-74,-15)],
         roads=[("main",[(15,73),(27,58),(42,45),(56,48),(66,60),(79,55),(85,32)]),("side",[(42,45),(30,25),(48,18),(66,60)]),("side",[(15,73),(10,45),(20,31),(30,25)])]),
    dict(slug="hearthmoor", name="Hearthmoor Basin", band="6-15", theme="basin", colors=[("Basin grass", "#9eb28a"), ("River", "#6ea6ad"), ("Old stone", "#a89b7d")],
         story="Hearthmoor coordinates relief as roads fail and reports conflict. The capital offers services, faces, and competing theories, but no final answer about the Wardens.",
         settlement="Hearthmoor is the largest city. Crossing Camp is a smaller arrival point. Farms, ferry landings, bridge stairs, and shrines extend beyond the walls.",
         build="Stone walls, bridge arches, jettied houses, market stalls, workshops, inn, apothecary, farms, and civic hall. This is the first full trade and crafting hub.",
         clue="City records disagree on when the trouble began. Optional archives deepen the question but never resolve it.",
         pois=[("camp","Crossing Camp","5-9",18,70,-6,20),("landmark","Old Bridge","7-11",40,49,-58,-14),("city","Hearthmoor","6-15",58,55,15,-3),("shrine","Shrine Terrace","10-15",81,33,-98,-15),("village","Outer Farms","8-13",79,76,-85,19)],
         roads=[("main",[(18,70),(30,61),(40,49),(58,55),(75,55),(81,33)]),("side",[(58,55),(61,27),(75,18),(81,33)]),("side",[(58,55),(67,71),(79,76)]),("side",[(40,49),(28,31),(18,70)])]),
    dict(slug="brackenwood", name="Brackenwood Fringe", band="9-18", theme="forest", colors=[("Fern floor", "#617f61"), ("Canopy", "#3f644e"), ("Timber", "#887052")],
         story="Ashford depends on forest work but patrols vanish as people push farther along old paths. The player reconnects the frontier without being told which side caused the danger.",
         settlement="Ashford is a timber-walled frontier village. Forest-edge farms, logging camps, and watch platforms form a working boundary.",
         build="Dark timber, covered porches, moss roofs, watch towers, log yards, and small clearings. Timber, resin, mushrooms, and herbs connect to building, woodcraft, and herblore.",
         clue="Old boundary cuts and fresh logging marks support different readings of why creatures guard certain groves.",
         pois=[("camp","Timber Camp","9-12",15,62,-3,20),("town","Ashford","10-15",37,54,-63,-12),("landmark","Lookout A","12-15",55,25,-65,-15),("village","Edge Farms","11-15",70,70,12,19),("cave","Spider Hollow","15-18",83,38,-100,-15),("landmark","Fern Ravine","17-18",69,38,14,18)],
         roads=[("main",[(15,62),(25,58),(37,54),(55,56),(69,38),(83,38)]),("side",[(37,54),(55,25),(69,38)]),("side",[(55,56),(70,70),(83,62)])]),
    dict(slug="blackbriar", name="Blackbriar Wilds", band="12-22", theme="oldforest", colors=[("Deep moss", "#4b684d"), ("Old canopy", "#2f4f3d"), ("Root / bark", "#655540")],
         story="Root bridges and thorn paths close around the ravine. The Warden's aggression blocks travel, yet the grove it guards changes after the fight too.",
         settlement="Blackbriar Lodge is a hunter hamlet. A few refuges and lookouts support a sparse population of people who know the ravine paths.",
         build="Longhouse, raised walkways, rope bridges, lookout platforms, lean-tos, and bark shelters. Hardwood, fungi, venom, and herbs feed tools, potions, and poisons.",
         clue="Root patterns bend around an old spring and buried stones. The signs suggest a boundary, not what it was meant to keep in or out.",
         pois=[("town","Blackbriar Lodge","12-17",17,62,-4,21),("camp","Hunter Refuge","15-18",39,31,-80,-13),("cave","Root Cavern","17-20",53,56,14,19),("landmark","Ravine Bridge","19-21",70,41,-85,-16),("boss","Rootbound Ring","20-22",83,67,-98,20)],
         roads=[("main",[(17,62),(31,53),(39,31),(53,56),(70,41),(83,67)]),("side",[(31,53),(47,76),(65,78),(83,67)]),("side",[(53,56),(65,25),(70,41)])]),
    dict(slug="magenta_heath", name="Magenta Heath / Upland Scrub", band="19-28", theme="heath", colors=[("Cream heath", "#e4d9b6"), ("Warm tan earth", "#c5b58d"), ("Hardy scrub", "#929b76")],
         story="Shared wells weaken or change course. Villages debate opening an old channel or expanding pasture and quarrying. The springs foreshadow the water Warden downstream without hosting its main encounter.",
         settlement="A human, community-minded people live in a substantial market-and-gathering town and several villages. A common hall, communal well yards, and shared stores make cooperation visible.",
         build="Low stone-and-timber houses, windbreak walls, covered assembly yards, cisterns, sheep pens, and roadside shrines. Hardy herbs, wool, stone, and spring water support food, clothing, building, and potions.",
         clue="Fresh cuts suggest people changed the water; residents remember shrine lights and springs failing before the work. Both explanations remain plausible.",
         pois=[("camp","Ridge Refuge","19-21",13,70,-4,19),("village","North Well","20-23",31,37,-68,-14),("town","Gathering Town","21-27",55,55,14,-3),("ruin","Cairn Walk","24-26",76,28,-72,-14),("shrine","Headwater Spring","25-28",84,75,-103,19)],
         roads=[("main",[(13,70),(25,56),(31,37),(44,43),(55,55),(72,58),(84,75)]),("side",[(55,55),(63,32),(76,28)]),("side",[(13,70),(39,77),(55,55)]),("side",[(72,58),(83,43),(84,75)])]),
    dict(slug="cyan_floodplain", name="Cyan Wooded River Floodplain", band="23-31", theme="floodplain", colors=[("Willow green", "#698b70"), ("Wet earth", "#718078"), ("Channel blue", "#70aab7")],
         story="Channels shift, breaking crossings and mill work. Upstream and downstream villages disagree about who should maintain or redirect water; the player restores safe trade routes.",
         settlement="A market town at the confluence links raised-bank villages, ferry points, mills, and woodland clearings. Its people are connected by river trade and shared waterworks.",
         build="Willow-framed halls, raised plank walks, ferry yards, mill wheels, stilted store sheds, and flood markers. Reeds, clay, willow, river fish, and stone feed food, potions, construction, and craft.",
         clue="Water-carved marks continue upstream toward the heath and downstream toward the fen. They provide observations, not a verdict on the cause.",
         pois=[("camp","Upper Ferry Camp","23-26",13,30,-7,-18),("village","Willowbank","23-27",32,61,-73,20),("town","River Junction","24-30",56,48,14,-4),("landmark","Mill Ford","26-29",75,30,-69,-16),("shrine","Old Sluice","29-31",84,74,-81,20)],
         roads=[("main",[(13,30),(24,43),(32,61),(48,58),(56,48),(75,50),(84,74)]),("side",[(32,61),(43,78),(56,80),(75,68),(84,74)]),("side",[(56,48),(64,29),(75,30)])]),
    dict(slug="saltfen", name="Saltfen Reach", band="21-31", theme="fen", colors=[("Peat earth", "#756b58"), ("Reed olive", "#a49b68"), ("Fen water", "#5b91a0")],
         story="Channels are hard to read and supplies go missing along flooded routes. The player maps a reliable passage and finds evidence of water changes beyond the normal season.",
         settlement="Sunkettle is a stilt market on a dry island. Reed-side hamlets, fishing platforms, dry islands, and wooded banks feed into its trade routes.",
         build="Stilt huts, reed huts on raised peat, plank boardwalks, tied skiffs, drying racks, and peat stores. Peat, reeds, bog herbs, fish, and salvage support fuel, food, herblore, and crafting.",
         clue="The fen carries clues from the floodplain toward the delta, but silt and roots obscure where the changes began.",
         pois=[("camp","Dry Isle Camp","21-24",13,67,-4,20),("village","Reedbank","22-25",31,33,-67,-16),("town","Sunkettle","24-30",53,56,14,-3),("cave","Weeping Grotto","26-30",74,31,-98,-16),("landmark","Peat Walk","29-31",85,73,-82,20)],
         roads=[("main",[(13,67),(24,54),(31,33),(43,45),(53,56),(74,57),(85,73)]),("side",[(31,33),(51,23),(74,31)]),("side",[(24,54),(39,76),(58,78),(74,57)])]),
    dict(slug="bellwater", name="Bellwater Delta", band="27-34", theme="delta", colors=[("Tidal water", "#6093a3"), ("Mudflat", "#b5a27c"), ("Driftwood", "#706656")],
         story="Tides strand people and expose old structures. The player restores a safe crossing, follows upstream clues, and confronts the water Warden around level 32. The delta changes after the fight.",
         settlement="Bellwharf is a working shore town of reclaimed hulls and driftwood. Boat camps, wreck beaches, the drowned chapel, bell tower, and sluice ruins sit among the channels.",
         build="Hull-shacks, net lofts, tide ladders, rope bridges, stilt docks, and a signal bell. Salt, fish, shells, wreck timber, and salvage connect cooking, smithing, and trade.",
         clue="A chapel's low-water markings and new flood lines disagree. Neither proves whether people or the Ember changed the tide pattern.",
         pois=[("camp","Wreck Camp","27-30",15,64,-4,21),("town","Bellwharf","27-31",36,50,-75,-16),("ruin","Drowned Chapel","29-32",57,30,-93,-16),("landmark","Sluice Gate","30-32",70,57,14,18),("boss","Delta Arena","31-34",84,72,-95,21)],
         roads=[("main",[(15,64),(27,57),(36,50),(48,40),(57,30),(70,34),(70,57),(84,72)]),("side",[(36,50),(43,72),(56,79),(70,57)]),("side",[(57,30),(78,22),(84,39),(84,72)])]),
    dict(slug="greyfold", name="Greyfold Downs / Northern Saddle", band="28-38", theme="downs", colors=[("Pale ochre", "#d7cba6"), ("Exposed grass", "#a5a17a"), ("Ridge stone", "#918b7d")],
         story="A buried pass route and dangerous weather make shortcuts risky. A refuge needs supplies, and stones carry incompatible accounts of the Wardens without resolving them.",
         settlement="Keep Greyfold as a narrower saddle after the magenta boundary is drawn. Greyfold Steading serves travelers; a roaming camp and small shelters support the pass, not another city.",
         build="Turf-and-stone steading, wind screens, cairns, a watch keep, pack animal pens, and trail shelters. Ore, pale grasses, stone, and highland herbs support smithing and supplies.",
         clue="Standing stones present different accounts; compare them with the heath's water marks and the city's records.",
         pois=[("camp","Ridge Camp","28-31",13,68,-4,19),("town","Greyfold Steading","30-34",37,53,-99,-15),("landmark","Standing Stones","31-35",58,32,-97,-17),("cave","Barrow Cave","33-36",73,60,12,18),("ruin","Greyfold Keep","35-38",86,31,-91,-16)],
         roads=[("main",[(13,68),(26,60),(37,53),(47,42),(58,32),(71,42),(86,31)]),("side",[(37,53),(46,73),(61,78),(73,60)]),("side",[(58,32),(72,23),(86,31)])]),
    dict(slug="frostspine", name="Frostspine Crown", band="30-45", theme="mountain", colors=[("Snow cream", "#edf0e8"), ("Glacial blue", "#b7d0d2"), ("Slate", "#768991")],
         story="Out-of-season cold and changing meltwater threaten winter stores and close the pass. The player secures a route and reaches the final Warden chapter at level 42.",
         settlement="Pilgrim's Rest is the main refuge around a hot spring; Rimewatch is the fortified pass outpost. Isolated shelters and miners' camps link them.",
         build="Slate roofs, stone windbreaks, rope lifts, avalanche gates, hot-spring sheds, and insulated storehouses. Ore, mountain herbs, spring water, and monster parts feed high-tier smithing and potions.",
         clue="Snow and melt lines change across old boundary markers. The Warden, human activity, and the failing Ember all remain plausible causes.",
         pois=[("camp","Foothill Shelter","30-34",12,72,-5,19),("town","Pilgrim's Rest","32-36",35,61,-77,-15),("camp","Miner Camp","34-38",56,42,14,-15),("fort","Rimewatch","37-40",72,32,-85,-16),("cave","Rimecrypt","39-41",84,56,-79,20),("boss","Summit Warden","41-42",78,80,-104,21),("landmark","Highland Quests","43-45",91,52,-105,-16)],
         roads=[("main",[(12,72),(24,68),(35,61),(47,53),(56,42),(72,32),(84,56),(78,80)]),("side",[(35,61),(45,78),(61,78),(72,65),(84,56)]),("side",[(56,42),(71,18),(84,23),(72,32)])]),
    dict(slug="deep_runs", name="Deep Runs / Endgame Dungeons", band="45 · ENDGAME", theme="cavern", colors=[("Deep stone", "#555c5b"), ("Mineral seam", "#8d826e"), ("Ember crystal", "#76aaa0")],
         story="At combat level 45, players unlock a hard-mode dungeon tier: upgraded familiar dungeons with changed mechanics plus brand-new dungeons. These are endgame challenges, not leveling content.",
         settlement="A proposed expedition board and staging hub links existing dungeon hard modes with new endgame entrances. Each dungeon keeps its own entry, preparation area, route, and boss room.",
         build="Rework familiar layouts with new hazards, enemy combinations, and boss phases; build some new layouts from the ground up. Rare ore, herbs, hides, and boss parts support endgame gear and professions.",
         clue="Found records add evidence and contradictions; no endgame journal declares one final explanation.",
         pois=[("camp","Expedition Board","45",15,65,-6,20),("cave","Hard: Burrow","45",37,37,-59,-16),("cave","Hard: Spider Den","45",54,70,-66,20),("ruin","New Dungeon A","45",72,34,-86,-16),("ruin","New Dungeon B","45",86,64,-92,20)],
         roads=[("main",[(15,65),(27,51),(37,37),(50,48),(54,70),(66,63),(72,34),(86,64)]),("side",[(37,37),(47,20),(60,25),(72,34)]),("side",[(54,70),(71,82),(86,64)])]),
]

# SVG helpers

def txt(x, y, text, size=13, color="#243231", weight="400", anchor="start", extra=""):
    return f'<text x="{x}" y="{y}" font-family="Avenir Next, Arial, sans-serif" font-size="{size}" font-weight="{weight}" fill="{color}" text-anchor="{anchor}" {extra}>{escape(str(text))}</text>'

def wrap(text, limit):
    words = text.split()
    lines, line = [], ""
    for word in words:
        trial = (line + " " + word).strip()
        if len(trial) > limit and line:
            lines.append(line)
            line = word
        else:
            line = trial
    if line:
        lines.append(line)
    return lines

def multi(x, y, text, limit=52, line_h=17, size=12, color="#33403b"):
    lines = wrap(text, limit)
    parts = []
    for i, line in enumerate(lines):
        parts.append(txt(x, y+i*line_h, line, size, color))
    return "".join(parts), y + len(lines)*line_h

def map_xy(pt):
    x0, y0, w, h = 24, 74, 620, 500
    x, y = pt
    return x0 + 32 + x*w/100, y0 + 35 + y*h/100

def path_d(points):
    coords = [map_xy(p) for p in points]
    return "M " + " L ".join(f"{x:.1f} {y:.1f}" for x,y in coords)

BOUNDARY = "M 49 108 L 595 98 L 624 187 L 601 504 L 548 558 L 112 559 L 45 493 L 30 280 Z"

def terrain_art(theme):
    a=[]
    if theme == "meadow":
        for i in range(10):
            y=170+i*31
            a.append(f'<path d="M {65+i*4} {y} Q 210 {y-32} 340 {y+4} T 625 {y-7}" fill="none" stroke="#d8c58e" stroke-width="2" opacity=".5"/>')
        for x,y in [(150,260),(230,385),(500,230),(530,465)]:
            a.append(f'<path d="M{x} {y} l34 -17 l40 4 l-28 21 z" fill="#cdb67a" opacity=".55"/>')
    elif theme == "coast":
        a.append('<path d="M 26 447 Q 175 408 279 455 T 646 425 L 646 574 L 24 574 Z" fill="#72aab4" opacity=".88"/>')
        a.append('<path d="M 24 427 Q 175 391 285 440 T 646 407" fill="none" stroke="#e3d3aa" stroke-width="24" opacity=".9"/>')
        for x,y,r in [(220,244,32),(396,323,22),(504,197,16)]:
            a.append(f'<ellipse cx="{x}" cy="{y}" rx="{r}" ry="{r*.62}" fill="#72aab4" opacity=".75"/>')
    elif theme == "basin":
        a.append('<path d="M 32 356 C 170 287 253 434 353 346 S 501 315 644 244" fill="none" stroke="#6ea6ad" stroke-width="34" opacity=".75"/>')
        a.append('<path d="M 32 356 C 170 287 253 434 353 346 S 501 315 644 244" fill="none" stroke="#90c0c0" stroke-width="15"/>')
        for x,y in [(115,205),(525,208),(488,467)]: a.append(f'<path d="M{x} {y} q40 -22 80 0" stroke="#9b8b6c" stroke-width="7" fill="none"/>')
    elif theme in ("forest", "oldforest"):
        spacing=34 if theme=="forest" else 27
        dark="#42654e" if theme=="forest" else "#315340"
        for row,y in enumerate(range(145,540,spacing)):
            for col,x in enumerate(range(70+(row%2)*12,625,spacing)):
                if (x+row*13)%5 != 1:
                    rr=10 if theme=="forest" else 12
                    a.append(f'<circle cx="{x}" cy="{y}" r="{rr}" fill="{dark}" opacity=".78"/>')
                    a.append(f'<circle cx="{x-3}" cy="{y-4}" r="{rr*.48}" fill="#6d8b5e" opacity=".55"/>')
        if theme == "oldforest":
            a.append('<path d="M 372 123 Q 346 245 403 309 T 369 563" fill="none" stroke="#514734" stroke-width="46" opacity=".8"/>')
            a.append('<path d="M 370 122 Q 346 245 403 309 T 369 563" fill="none" stroke="#76654a" stroke-width="13" opacity=".7"/>')
    elif theme == "heath":
        a.append('<path d="M 58 430 Q 205 395 320 426 T 625 390" fill="none" stroke="#ab9c77" stroke-width="14" opacity=".45"/>')
        for row,y in enumerate(range(160,540,46)):
            for col,x in enumerate(range(80+(row%2)*18,620,48)):
                if (x*3+y)%7 not in (0,1):
                    a.append(f'<circle cx="{x}" cy="{y}" r="5" fill="#929b76" opacity=".85"/>')
                    a.append(f'<circle cx="{x+7}" cy="{y+3}" r="2" fill="#756c58"/>')
        for x,y in [(185,294),(477,198),(540,438)]:
            a.append(f'<path d="M{x} {y+12} l13 -25 l16 25 z" fill="#9e9782" opacity=".76"/>')
    elif theme == "floodplain":
        for d,w in [("M 54 225 C 164 180 160 291 285 263 S 411 278 645 194",27),("M 90 455 C 193 396 247 503 353 442 S 493 442 624 354",23),("M 251 135 C 312 204 243 280 343 334 S 421 420 402 555",13)]:
            a.append(f'<path d="{d}" fill="none" stroke="#70aab7" stroke-width="{w}" opacity=".9"/>')
        for x,y in [(123,198),(207,288),(481,229),(337,471),(559,384)]:
            a.append(f'<path d="M{x} {y+18} q-10 -15 0 -27 q12 12 0 27" fill="#527a62" opacity=".86"/>')
    elif theme == "fen":
        for x,y,rx,ry in [(140,180,54,22),(275,252,37,25),(457,180,55,30),(184,401,45,21),(365,467,66,28),(541,347,40,24)]:
            a.append(f'<ellipse cx="{x}" cy="{y}" rx="{rx}" ry="{ry}" fill="#5b91a0" opacity=".86"/>')
        for x,y in [(90,300),(266,167),(400,326),(564,253),(470,510)]:
            for dx in [-7,0,7]: a.append(f'<path d="M{x+dx} {y+13} q-2 -12 1 -22" stroke="#b2aa73" stroke-width="2"/>')
    elif theme == "delta":
        for d,w in [("M 95 120 C 157 219 294 190 333 290 S 459 411 639 470",26),("M 315 112 C 285 211 409 222 437 302 S 555 358 620 401",17),("M 80 390 C 192 337 252 396 310 474",16)]:
            a.append(f'<path d="{d}" fill="none" stroke="#6093a3" stroke-width="{w}" opacity=".95"/>')
        for x,y in [(181,254),(493,222),(257,434),(539,482)]:
            a.append(f'<path d="M{x-22} {y} q24 -15 46 0 l-9 17 h-32 z" fill="#b5a27c"/>')
    elif theme == "downs":
        for i in range(7):
            y=180+i*48
            a.append(f'<path d="M 53 {y+25} Q 186 {y-25} 305 {y+20} T 620 {y-4}" fill="none" stroke="#a59b7e" stroke-width="2" opacity=".55"/>')
        for x,y in [(154,250),(157,239),(166,254),(442,326),(451,310),(463,330),(532,202),(540,188)]:
            a.append(f'<rect x="{x}" y="{y}" width="7" height="20" fill="#8f8b7a"/>')
    elif theme == "mountain":
        for x,y,w,h in [(90,286,100,155),(217,194,130,196),(384,272,107,164),(500,167,144,220),(555,374,102,142)]:
            a.append(f'<path d="M{x} {y+h} L{x+w/2} {y} L{x+w} {y+h} Z" fill="#778990" opacity=".8"/>')
            a.append(f'<path d="M{x+w*.32} {y+h*.36} L{x+w/2} {y} L{x+w*.69} {y+h*.38} L{x+w*.54} {y+h*.31} L{x+w*.47} {y+h*.43} Z" fill="#edf0e8" opacity=".95"/>')
        a.append('<path d="M 42 485 Q 209 408 351 447 T 638 379" fill="none" stroke="#9db3b7" stroke-width="22" opacity=".8"/>')
    elif theme == "cavern":
        for d in ["M 72 220 Q 180 112 293 214 T 570 198", "M 62 420 Q 185 500 302 402 T 600 462", "M 246 128 Q 210 300 345 370 T 474 542"]:
            a.append(f'<path d="{d}" fill="none" stroke="#87816f" stroke-width="22" opacity=".55"/>')
        for x,y in [(161,238),(371,190),(514,382),(280,460)]:
            a.append(f'<path d="M{x-18} {y+8} Q{x} {y-23} {x+18} {y+8}" fill="none" stroke="#76aaa0" stroke-width="4"/>')
    return "".join(a)

def draw_icon(kind, x, y):
    if kind in ("town", "city", "fort"):
        color = "#eadfc2" if kind != "fort" else "#aab8b2"
        border = "#443e33"
        return f'<rect x="{x-8}" y="{y-8}" width="16" height="16" rx="2" fill="{color}" stroke="{border}" stroke-width="2"/><path d="M{x-4} {y+1} v-5 h3 v5 M{x+1} {y+4} v-7 h3 v7" stroke="#5e5242" stroke-width="1.5"/>'
    if kind == "village":
        return f'<circle cx="{x}" cy="{y}" r="7" fill="#f0e4c8" stroke="#514838" stroke-width="2"/><circle cx="{x}" cy="{y}" r="2" fill="#514838"/>'
    if kind == "camp":
        return f'<path d="M{x-9} {y+7} L{x} {y-9} L{x+9} {y+7} Z" fill="#d5b879" stroke="#514838" stroke-width="2"/><path d="M{x} {y-7} v14" stroke="#514838" stroke-width="1.5"/>'
    if kind == "cave":
        return f'<path d="M{x-10} {y+8} v-5 a10 10 0 0 1 20 0 v5 z" fill="#343a37" stroke="#ddd1af" stroke-width="2"/>'
    if kind in ("ruin", "landmark"):
        color = "#96876d" if kind == "ruin" else "#a8a18b"
        return f'<path d="M{x} {y-9} L{x+9} {y} L{x} {y+9} L{x-9} {y} Z" fill="{color}" stroke="#4b463c" stroke-width="1.8"/>'
    if kind == "shrine":
        return f'<circle cx="{x}" cy="{y}" r="9" fill="#d5c891" stroke="#514838" stroke-width="2"/><path d="M{x} {y-6} v12 M{x-5} {y-1} h10" stroke="#564e3e" stroke-width="2"/>'
    if kind == "boss":
        return f'<path d="M{x} {y-12} L{x+11} {y+9} L{x-11} {y+9} Z" fill="#bd684f" stroke="#49362f" stroke-width="2"/><circle cx="{x}" cy="{y+3}" r="2" fill="#fff1d2"/>'
    return f'<circle cx="{x}" cy="{y}" r="7" fill="#eee0bb" stroke="#514838" stroke-width="2"/>'

def make_zone_svg(z):
    x0,y0,w,h=24,74,620,500
    local_clip = BOUNDARY
    bg = "#b9d0ca" if z["theme"] in ("coast","floodplain","fen","delta") else "#dfe3d3"
    p=[f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1200 700" role="img">',
       '<rect width="1200" height="700" fill="#e8e4d8"/>',
       '<rect x="0" y="0" width="1200" height="66" fill="#203431"/>',
       txt(30,32,z["name"],23,"#f4eddb","700"),
       txt(1165,32,f"LEVEL BAND  {z['band']}",15,"#d4d5b9","700","end"),
       txt(32,58,"TOP-DOWN ZONE PLAN  ·  PATHS, PLACES, LEVELS, AND TERRAIN TEXTURE",10,"#61716a","600"),
       f'<rect x="{x0}" y="{y0}" width="620" height="500" rx="14" fill="{bg}" stroke="#263d37" stroke-width="3"/>',
       f'<defs><clipPath id="land"><path d="{local_clip}"/></clipPath></defs>',
       f'<path d="{local_clip}" fill="{z["colors"][0][1]}" stroke="#364940" stroke-width="4"/>',
       f'<g clip-path="url(#land)">{terrain_art(z["theme"])}</g>']
    # Major/minor paths, rendered before map labels.
    for typ,points in z["roads"]:
        d=path_d(points)
        if typ=="main":
            p.append(f'<path d="{d}" fill="none" stroke="#594b37" stroke-width="9" stroke-linecap="round" stroke-linejoin="round"/>')
            p.append(f'<path d="{d}" fill="none" stroke="#dfd0a6" stroke-width="5" stroke-linecap="round" stroke-linejoin="round"/>')
        else:
            p.append(f'<path d="{d}" fill="none" stroke="#73694e" stroke-width="3" stroke-dasharray="8 8" stroke-linecap="round"/>')
    # Place nodes and labels.
    for kind,label,level,x,y,dx,dy in z["pois"]:
        X,Y=map_xy((x,y))
        p.append(draw_icon(kind,X,Y))
        lx,ly=X+dx,Y+dy
        labeltext=f"{label} · {level}"
        width=max(86,min(210,6.1*len(labeltext)+16))
        rectx=max(x0+10,min(x0+620-width-10,lx-width/2))
        recty=max(y0+12,min(y0+500-35,ly-13))
        p.append(f'<rect x="{rectx:.1f}" y="{recty:.1f}" width="{width:.1f}" height="21" rx="4" fill="#f6f0df" fill-opacity=".94" stroke="#6b6659" stroke-width=".8"/>')
        p.append(txt(rectx+width/2,recty+14,labeltext,9,"#263630","600","middle"))
    # map title, north arrow, scale-like index, legend
    p.append(txt(42,94,"N",12,"#263a34","700"))
    p.append('<path d="M48 101 l-5 12 h10 z" fill="#263a34"/>')
    # Sidebar panels
    p.append('<rect x="666" y="74" width="510" height="500" rx="14" fill="#f7f2e4" stroke="#a29b84" stroke-width="2"/>')
    sy=101
    sections=[("STORY HOOK",z["story"]),("SETTLEMENTS",z["settlement"]),("BUILDING + SKILLS",z["build"]),("OPTIONAL CLUES",z["clue"])]
    for title,body in sections:
        p.append(txt(690,sy,title,12,"#526255","700")); sy+=19
        lines=wrap(body,64)
        for line in lines:
            p.append(txt(690,sy,line,12,"#303a34")); sy+=17
        sy+=11
    # Shared footer keeps legend and illustrative ground palette out of the story text.
    p.append('<rect x="24" y="590" width="1152" height="74" rx="12" fill="#f7f2e4" stroke="#c2baa5" stroke-width="1.5"/>')
    p.append(txt(42,614,"PATH KEY",10,"#526255","700"))
    p.append('<line x1="42" y1="637" x2="77" y2="637" stroke="#594b37" stroke-width="7"/><line x1="42" y1="637" x2="77" y2="637" stroke="#dfd0a6" stroke-width="4"/>')
    p.append(txt(84,641,"main route",9,"#303a34","600"))
    p.append('<line x1="168" y1="637" x2="203" y2="637" stroke="#73694e" stroke-width="3" stroke-dasharray="7 6"/>')
    p.append(txt(210,641,"optional trail",9,"#303a34","600"))
    p.append(txt(42,657,"Levels are recommended encounter / quest bands.",8,"#526255","600"))
    p.append(txt(365,614,"TERRAIN COLOR EXAMPLES · ADJUSTABLE",10,"#526255","700"))
    sx=365
    for label,color in z["colors"]:
        p.append(f'<rect x="{sx}" y="626" width="18" height="16" rx="3" fill="{color}" stroke="#68675b" stroke-width=".8"/>')
        p.append(txt(sx+24,639,label,9,"#303a34","600"))
        sx += 145
    p.append(txt(805,614,"MAP SYMBOLS",10,"#526255","700"))
    p.append(txt(805,639,"Town square · village circle · camp tent · cave arch · ruin diamond · Warden triangle",9,"#303a34","600"))
    p.append('</svg>')
    (OUT/f"{z['slug']}.svg").write_text("\n".join(p),encoding="utf-8")

for z in ZONES:
    make_zone_svg(z)

# World route overview. This schematic follows the current map's southwest-to-northeast orientation.
regions = [
    ("Tallowfields / Meadow", "1-12", "#9bb87a", "73,543 218,520 270,570 239,664 119,690 62,620"),
    ("Campwater Vale", "2-11", "#91b29d", "375,658 478,630 536,678 520,765 389,779 326,726"),
    ("Hearthmoor Basin", "6-15", "#b1bc9a", "322,416 467,402 535,466 511,548 384,571 296,510"),
    ("Wooded Floodplain", "23-31", "#78a8a5", "367,555 505,546 574,588 550,649 425,658 335,617"),
    ("Saltfen Reach", "21-31", "#788e82", "69,352 216,332 295,380 276,485 153,531 61,455"),
    ("Bellwater Delta", "27-34", "#6b9aaa", "224,675 324,649 379,691 360,758 255,767 198,724"),
    ("Brackenwood Fringe", "9-18", "#5d805f", "535,421 656,407 718,465 699,541 579,563 516,499"),
    ("Blackbriar Wilds", "12-22", "#42634a", "614,295 720,282 781,345 747,413 649,419 601,358"),
    ("Magenta Heath", "19-28", "#e4d9b6", "290,183 420,154 557,176 602,246 548,331 415,363 307,297"),
    ("Greyfold Saddle", "28-38", "#d3c59e", "565,164 692,150 750,201 731,265 635,293 578,244"),
    ("Frostspine Crown", "30-45", "#c7d9d8", "738,124 842,131 878,245 837,378 760,353 731,260 756,205"),
]
route_main=[(115,635),(192,584),(451,720),(412,493),(624,487),(700,348),(442,257),(468,606),(170,430),(292,709),(657,220),(808,274)]
route_side=[[(192,584),(315,550),(412,493)],[(412,493),(444,608),(468,606)],[(624,487),(700,348),(748,347)],[(442,257),(628,208),(657,220)],[(292,709),(427,522),(657,220)]]
wardens=[("12",(244,654)),("22",(735,390)),("32",(345,718)),("42",(851,184))]

def make_overview():
    p=['<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1300 850" role="img">','<rect width="1300" height="850" fill="#e8e4d8"/>','<rect width="1300" height="66" fill="#203431"/>',txt(30,32,"THORNVALE · WORLD ROUTE + LEVEL BANDS",24,"#f4eddb","700"),txt(30,58,"SCHEMATIC ONLY  ·  USE THE PAINTED MAP FOR FINAL COORDINATES",11,"#61716a","600")]
    p.append('<rect x="26" y="82" width="875" height="740" rx="16" fill="#82b4bf" stroke="#263d37" stroke-width="3"/>')
    p.append('<path d="M 65 174 Q 195 120 332 152 T 584 123 Q 720 106 855 159 L 860 374 Q 819 506 876 639 L 821 786 Q 658 752 512 797 Q 323 789 118 780 Q 54 683 58 498 Z" fill="#ded9c5" stroke="#32473f" stroke-width="5"/>')
    # Region shapes
    for label,band,color,pts in regions:
        p.append(f'<polygon points="{pts}" fill="{color}" fill-opacity=".92" stroke="#45584a" stroke-width="2.5"/>')
    # river system
    p.append('<path d="M 425 201 Q 454 295 456 388 T 467 551 Q 432 610 350 685" fill="none" stroke="#6fa9b6" stroke-width="16" opacity=".95"/>')
    p.append('<path d="M 458 437 Q 376 470 305 511 T 254 622" fill="none" stroke="#6fa9b6" stroke-width="11" opacity=".9"/>')
    p.append('<path d="M 475 515 Q 574 495 624 446 T 671 382" fill="none" stroke="#6fa9b6" stroke-width="9" opacity=".9"/>')
    # Route overlays
    d="M "+" L ".join(f"{x} {y}" for x,y in route_main)
    p.append(f'<path d="{d}" fill="none" stroke="#fff2ce" stroke-width="13" stroke-linecap="round" stroke-linejoin="round" opacity=".85"/>')
    p.append(f'<path d="{d}" fill="none" stroke="#7b5138" stroke-width="4" stroke-dasharray="10 8" stroke-linecap="round" stroke-linejoin="round"/>')
    for pts in route_side:
        d2="M "+" L ".join(f"{x} {y}" for x,y in pts)
        p.append(f'<path d="{d2}" fill="none" stroke="#f5edda" stroke-width="8" stroke-dasharray="10 9" stroke-linecap="round"/>')
        p.append(f'<path d="{d2}" fill="none" stroke="#74664c" stroke-width="2.5" stroke-dasharray="7 8" stroke-linecap="round"/>')
    # region labels as two-line boxes; manual anchor positions
    labels=[("Tallowfields / Meadow","1-12",160,599),("Campwater Vale","2-11",452,718),("Hearthmoor Basin","6-15",418,497),("Wooded Floodplain","23-31",461,615),("Saltfen Reach","21-31",167,433),("Bellwater Delta","27-34",291,728),("Brackenwood Fringe","9-18",626,490),("Blackbriar Wilds","12-22",691,352),("Magenta Heath","19-28",444,255),("Greyfold Saddle","28-38",654,208),("Frostspine Crown","30-45",803,300)]
    for label,band,x,y in labels:
        width=max(110,len(label)*6.4+25)
        p.append(f'<rect x="{x-width/2:.1f}" y="{y-19}" width="{width:.1f}" height="36" rx="7" fill="#f7f1df" fill-opacity=".94" stroke="#667266" stroke-width="1"/>')
        p.append(txt(x,y-4,label,11,"#24352f","700","middle"))
        p.append(txt(x,y+10,f"LEVELS {band}",9,"#57635a","600","middle"))
    # chapter markers
    for n,(x,y) in wardens:
        p.append(f'<circle cx="{x}" cy="{y}" r="14" fill="#b95c46" stroke="#fff1d2" stroke-width="3"/>')
        p.append(txt(x,y+4,n,10,"#fff7e3","700","middle"))
    # numbered path beats, positioned away from chapter markers
    nums=[("1",(105,639)),("2",(451,746)),("3",(422,490)),("4",(628,520)),("5",(716,378)),("6",(473,275)),("7",(478,624)),("8",(166,444)),("9",(292,738)),("10",(657,218)),("11",(825,319))]
    for n,(x,y) in nums:
        p.append(f'<circle cx="{x}" cy="{y}" r="11" fill="#f4d98b" stroke="#4d493c" stroke-width="1.5"/>')
        p.append(txt(x,y+4,n,9,"#302f29","700","middle"))
    # Sidebar
    p.append('<rect x="922" y="82" width="350" height="740" rx="16" fill="#f7f2e4" stroke="#a29b84" stroke-width="2"/>')
    p.append(txt(950,117,"LEVEL 1 → 45 ROUTE",17,"#30443b","700"))
    y=148
    beats=[("1 · START / MEADOW","1-12  ·  camp, farms, first Warden"),("2 · VALE + CITY","3-15  ·  shore loop, Hearthmoor services"),("3 · FOREST CHAPTER","9-22  ·  Ashford → Blackbriar"),("4 · HEADWATERS","19-28  ·  heath villages and springs"),("5 · FOLLOW THE RIVER","23-31  ·  cyan floodplain → Saltfen"),("6 · WATER CHAPTER","27-34  ·  Bellwater Warden at 32"),("7 · NORTHERN PASS","28-45  ·  Frostspine story carries to cap"),("8 · ENDGAME","45 CAP  ·  heroic modes + new dungeons")]
    for head,sub in beats:
        p.append(txt(950,y,head,10,"#526255","700"))
        p.append(txt(950,y+13,sub,9,"#303a34"))
        y+=28
    p.append('<line x1="950" y1="382" x2="1244" y2="382" stroke="#d1c9b4" stroke-width="1.5"/>')
    p.append(txt(950,404,"HOW TO READ THIS ROUTE",11,"#526255","700"))
    notes=["Numbered gold dots show the suggested main progression.","Dashed trails are optional loops; regions are not hard-gated.","Red circles mark Warden chapters at 12, 22, 32, and 42.","Reach combat level 45 through the guided zone questline."]
    y=427
    for note in notes:
        lines=wrap(note,42)
        p.append('<circle cx="955" cy="'+str(y-4)+'" r="3" fill="#947342"/>')
        for i,line in enumerate(lines):
            p.append(txt(966,y+i*16,line,10,"#303a34"))
        y += 15*len(lines)+5
    p.append('<line x1="950" y1="585" x2="1244" y2="585" stroke="#d1c9b4" stroke-width="1.5"/>')
    p.append(txt(950,608,"GROUND COLOR EXAMPLES · ADJUSTABLE",10,"#526255","700"))
    palette=[("Red Meadow", "#9bb87a"),("Magenta high heath", "#e4d9b6"),("Cyan lowland", "#70aab7"),("Forest", "#42654e"),("Peat fen", "#756b58"),("Frostspine", "#c7d9d8")]
    y=630
    for i,(name,color) in enumerate(palette):
        col=i%2; row=i//2
        x=950+col*145; yy=y+row*24
        p.append(f'<rect x="{x}" y="{yy-13}" width="19" height="16" rx="3" fill="{color}" stroke="#5b6158" stroke-width=".8"/>')
        p.append(txt(x+25,yy,name,9,"#303a34","600"))
    p.append('</svg>')
    (OUT/"world_route.svg").write_text("\n".join(p),encoding="utf-8")

make_overview()
print(f"Wrote {len(ZONES)} zone sheets and world route to {OUT}")
