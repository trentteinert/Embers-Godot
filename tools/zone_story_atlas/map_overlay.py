"""Draw proposed zone and POI overlays directly on the original Thornvale map."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "assets" / "thornvale_world_topdown.png"
OUT = ROOT / "assets" / "zone_story_atlas"
OUT.mkdir(parents=True, exist_ok=True)

# Coordinates are traced against the original concept map (1536 x 1024).
# These are proposed footprints, not a claim that boundaries are already in-game.
ZONES = [
    ("tallowfields", "Meadow & Uplands Region", "1–38", "#e95343", [(55,610),(260,610),(515,620),(515,810),(515,995),(365,1008),(140,975),(55,825)]),
    ("campwater", "Campwater Vale", "2–11", "#17b7c4", [(970,640),(1210,650),(1440,730),(1535,825),(1535,965),(1430,1000),(1190,960),(970,900)]),
    ("hearthmoor", "Hearthmoor Basin", "6–15", "#f0bd32", [(515,360),(690,360),(870,365),(870,500),(870,620),(690,620),(515,620)]),
    ("brackenwood", "Brackenwood & Blackbriar Region", "9–22", "#27754f", [(870,460),(1000,455),(1160,460),(1320,490),(1400,550),(1350,620),(1150,620),(1000,620),(870,620)]),
    ("blackbriar", "Brackenwood & Blackbriar Region", "9–22", "#27754f", [(880,360),(1010,360),(1160,360),(1160,410),(1130,460),(1000,460),(880,460)]),
    ("magenta_heath", "Meadow & Uplands Region", "1–38", "#e95343", [(460,155),(610,150),(750,155),(880,160),(880,255),(880,360),(730,360),(590,360),(460,360),(475,285)]),
    ("cyan_floodplain", "Floodplain & Delta Region", "24–34", "#16b8d0", [(515,620),(690,620),(870,620),(970,640),(970,725),(970,810),(820,810),(670,810),(515,810)]),
    ("saltfen", "Saltfen Reach", "24–31", "#987457", [(45,300),(190,290),(350,300),(460,300),(460,360),(475,420),(495,510),(515,610),(360,610),(200,610),(55,600)]),
    ("bellwater", "Floodplain & Delta Region", "24–34", "#16b8d0", [(515,810),(650,810),(820,810),(970,810),(970,900),(930,965),(820,1000),(680,980),(515,995)]),
    ("greyfold", "Meadow & Uplands Region", "1–38", "#e95343", [(460,0),(650,0),(820,0),(880,0),(880,80),(880,155),(720,155),(590,155),(460,155)]),
    ("frostspine", "Frostspine Crown", "35–45", "#78c2df", [(880,0),(1170,0),(1535,0),(1535,360),(1370,360),(1160,360),(1100,330),(1040,300),(980,260),(930,220),(880,180)]),
]

# kind, label, level, x, y
POIS = [
    ("camp","Wanderer's Rest","1–3",280,898,"tallowfields"),
    ("village","Tallowmere","4–8",314,741,"tallowfields"),
    ("boss","Hornstag Warden","10–12",575,680,"tallowfields"),
    ("camp","Southshore Camp","2–5",867,812,"campwater"),
    ("town","Campwater Landing","4–8",1070,837,"campwater"),
    ("city","Hearthmoor","6–15",757,526,"hearthmoor"),
    ("camp","Crossing Camp","5–9",817,630,"hearthmoor"),
    ("town","Ashford","10–15",1159,566,"brackenwood"),
    ("landmark","Quiet Cart · hidden merchant","optional",955,466,"brackenwood"),
    ("town","Blackbriar Lodge","12–17",1099,390,"blackbriar"),
    ("cave","Root Cavern","17–20",1079,546,"blackbriar"),
    ("boss","Rootbound Ring","20–22",1119,467,"blackbriar"),
    ("village","North Well","20–23",599,234,"magenta_heath"),
    ("town","Heath Gathering Town","21–27",801,279,"magenta_heath"),
    ("shrine","Headwater Spring","25–28",944,302,"magenta_heath"),
    ("village","Willowbank","23–27",671,670,"cyan_floodplain"),
    ("town","River Junction","24–30",819,693,"cyan_floodplain"),
    ("shrine","Old Sluice","29–31",928,738,"cyan_floodplain"),
    ("town","Sunkettle","24–30",240,495,"saltfen"),
    ("cave","Weeping Grotto","26–30",417,182,"saltfen"),
    ("town","Bellwharf","27–31",602,812,"bellwater"),
    ("shrine","Drowned Chapel","29–32",742,886,"bellwater"),
    ("boss","Water Warden","31–34",855,922,"bellwater"),
    ("town","Greyfold Steading","30–34",760,82,"greyfold"),
    ("landmark","Standing Stones","31–35",690,112,"greyfold"),
    ("town","Pilgrim's Rest","32–36",1005,175,"frostspine"),
    ("fort","Rimewatch","37–40",1419,107,"frostspine"),
    ("cave","Rimecrypt","39–41",1403,250,"frostspine"),
    ("boss","Frost Warden","41–42",1317,165,"frostspine"),
]

ROUTES = [
    # Separate road-following legs prevent the overlay from inventing shortcuts
    # when a route leaves one region and resumes elsewhere.
    ("main",[(280,898),(286,848),(300,799),(314,741),(414,700),(518,650),(632,594),(694,554),(757,526)]),
    ("side",[(314,741),(384,714),(470,700),(575,680)]),
    ("main",[(757,526),(855,535),(946,542),(1030,550),(1090,558),(1159,566),(1130,500),(1110,438),(1099,390)]),
    ("main",[(1099,390),(1040,355),(984,322),(925,296),(867,280),(801,279),(812,355),(819,430),(820,500),(817,570),(817,630)]),
    ("main",[(817,630),(710,640),(615,658),(520,656),(428,625),(340,565),(240,495),(310,504),(384,536)]),
    ("main",[(384,536),(440,600),(492,675),(542,744),(602,812),(680,782),(740,708),(757,620),(757,526)]),
    ("main",[(757,526),(760,455),(762,385),(764,318),(764,252),(810,222),(852,202),(899,182),(1008,159),(1115,142),(1230,131),(1419,107),(1365,138),(1317,165)]),
    ("side",[(314,741),(384,694),(465,653),(539,627),(615,620)]),
    ("side",[(793,599),(760,528),(729,447),(700,366),(654,292),(599,234),(681,221),(755,241),(801,279),(877,299),(944,302)]),
    ("side",[(852,701),(930,692),(1003,663),(1080,622),(1188,638)]),
    ("side",[(900,880),(973,897),(1050,905),(1110,905)]),
]

LOCAL_ROUTES = {
    "tallowfields":[("main",[(280,898),(286,848),(300,799),(314,741),(414,700),(518,650),(632,594),(694,554)]),("side",[(314,741),(384,714),(470,700),(575,680)])],
    "campwater":[("main",[(867,812),(921,808),(976,817),(1026,829),(1070,837)])],
    "hearthmoor":[("main",[(314,741),(414,700),(518,650),(632,594),(694,554),(757,526),(855,535),(946,542),(1030,550),(1090,558),(1159,566)]),("side",[(757,526),(760,455),(762,385),(764,318)])],
    "brackenwood":[("main",[(1030,550),(1090,558),(1159,566),(1130,500),(1110,438),(1099,390)])],
    "blackbriar":[("main",[(1099,390),(1110,438),(1099,490),(1079,546)]),("side",[(1099,390),(1040,355),(984,322),(925,296)])],
    "magenta_heath":[("main",[(600,234),(660,244),(724,260),(801,279),(866,292),(944,302)]),("side",[(660,244),(690,206),(735,178),(790,173)])],
    "cyan_floodplain":[("main",[(852,701),(785,690),(733,672),(671,670),(745,680),(819,693),(872,713),(928,738)]),("side",[(671,670),(630,716),(594,755),(560,777)])],
    "saltfen":[("main",[(240,495),(290,477),(340,448),(378,407),(400,346),(417,285),(417,182)]),("side",[(240,495),(300,505),(350,522),(384,536)])],
    "bellwater":[("main",[(602,812),(637,842),(670,830),(704,817),(762,784),(810,850),(855,922)]),("side",[(602,812),(550,784),(504,750),(470,712)])],
    "greyfold":[("main",[(757,526),(760,455),(762,385),(764,318),(764,252),(810,222),(852,202),(899,182)]),("side",[(764,252),(708,295),(670,338)])],
    "frostspine":[("main",[(899,182),(1008,159),(1115,142),(1230,131),(1320,115),(1419,107),(1380,137),(1317,165)]),("side",[(899,182),(1005,207),(1110,228),(1220,245),(1310,250),(1403,250)])],
}

FONT_PATHS = ["/System/Library/Fonts/Supplemental/Arial.ttf", "/Library/Fonts/Arial.ttf"]
def font(size):
    for path in FONT_PATHS:
        if Path(path).exists():
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()

def rounded_label(draw, xy, text, fill=(20,30,28,218), fg=(255,250,231,255), size=18, outline=(255,255,255,230)):
    f=font(size)
    x,y=xy
    box=draw.textbbox((0,0),text,font=f,stroke_width=0)
    w=box[2]-box[0]+20; h=box[3]-box[1]+12
    draw.rounded_rectangle((x-w/2,y-h/2,x+w/2,y+h/2),radius=8,fill=fill,outline=outline,width=2)
    draw.text((x-w/2+10,y-h/2+5),text,font=f,fill=fg,stroke_width=1,stroke_fill=(0,0,0,100))

def draw_icon(draw, kind, x,y,scale=1):
    r=int(11*scale)
    colors={"camp":"#f6bb57","village":"#f5e1aa","town":"#fff0c2","city":"#f8eed1","fort":"#b9c8cd","cave":"#353a39","shrine":"#f2d475","landmark":"#e8e2ce","boss":"#dd634a"}
    color=colors.get(kind,"#f3e7c5")
    if kind in ("camp","boss"):
        pts=[(x,y-r),(x+r,y+r),(x-r,y+r)]
        draw.polygon(pts,fill=color,outline="#262b28")
        draw.line(pts+[pts[0]],fill="#262b28",width=max(2,int(3*scale)))
    elif kind in ("cave","fort"):
        draw.rounded_rectangle((x-r,y-r//2,x+r,y+r),radius=3,fill=color,outline="#262b28",width=max(2,int(3*scale)))
        draw.arc((x-r//2,y-r,x+r//2,y+r//2),180,360,fill="#262b28",width=max(2,int(3*scale)))
    elif kind in ("landmark","shrine"):
        draw.polygon([(x,y-r-2),(x+r+2,y),(x,y+r+2),(x-r-2,y)],fill=color,outline="#262b28")
    else:
        draw.ellipse((x-r,y-r,x+r,y+r),fill=color,outline="#262b28",width=max(2,int(3*scale)))
    if kind in ("town","city","village","fort"):
        draw.rectangle((x-r//2,y-r//2,x+r//2,y+r//2),fill="#514a3e")

def draw_world():
    im=Image.open(SRC).convert("RGBA")
    overlay=Image.new("RGBA",im.size,(0,0,0,0)); d=ImageDraw.Draw(overlay)
    centers={"tallowfields":(190,870),"campwater":(1280,750),"hearthmoor":(680,585),"brackenwood":(1270,590),"blackbriar":(1010,436),"magenta_heath":(650,332),"cyan_floodplain":(735,770),"saltfen":(145,425),"bellwater":(785,965),"greyfold":(555,55),"frostspine":(1392,330)}
    merged_slugs={"tallowfields","magenta_heath","greyfold","brackenwood","blackbriar","cyan_floodplain","bellwater"}
    for slug,name,band,color,poly in ZONES:
        if slug in merged_slugs:
            continue
        # Small tint distinguishes adjoining footprints; a dark keyline and
        # saturated inner stroke keep borders visible over every terrain.
        d.polygon(poly,fill=tuple(bytes.fromhex(color[1:]))+(12,))
        d.line(poly+[poly[0]],fill=(27,37,33,240),width=13,joint="curve")
        d.line(poly+[poly[0]],fill=tuple(bytes.fromhex(color[1:]))+(255,),width=8,joint="curve")
        cx,cy=centers[slug]
        label=f"{name}  ·  {band}"
        rounded_label(d,(int(cx),int(cy)),label,fill=(24,35,31,230),size=16)
    def region_outline(poly,color):
        rgb=tuple(bytes.fromhex(color[1:]))
        d.polygon(poly,fill=rgb+(12,))
        d.line(poly+[poly[0]],fill=(27,37,33,240),width=13,joint="curve")
        d.line(poly+[poly[0]],fill=rgb+(255,),width=8,joint="curve")
    meadow=next(z[4] for z in ZONES if z[0]=="tallowfields")
    region_outline(meadow,"#e95343")
    rounded_label(d,(190,870),"Meadow & Uplands Region  ·  1–38",fill=(24,35,31,230),size=16)
    heath_downs=[(460,0),(880,0),(880,255),(880,360),(730,360),(590,360),(460,360),(475,285),(460,155)]
    region_outline(heath_downs,"#e95343")
    rounded_label(d,(655,332),"Heath 19–28  ·  Greyfold 31–38",fill=(24,35,31,230),size=14)
    forest=[(880,360),(1160,360),(1160,410),(1130,460),(1320,490),(1400,550),(1350,620),(1150,620),(1000,620),(870,620),(870,460)]
    region_outline(forest,"#27754f")
    rounded_label(d,(1140,596),"Brackenwood + Blackbriar  ·  9–22",fill=(24,35,31,230),size=15)
    river=[(515,620),(690,620),(870,620),(970,640),(970,725),(970,810),(970,900),(930,965),(820,1000),(680,980),(515,995),(515,810)]
    region_outline(river,"#16b8d0")
    rounded_label(d,(735,770),"Floodplain & Delta Region  ·  24–34",fill=(24,35,31,230),size=16)
    offsets={"Tallowmere":(-35,-26),"Campwater Landing":(30,-22),"Hearthmoor":(-26,-35),"Ashford":(30,-24),"Blackbriar Lodge":(27,-25),"Heath Gathering Town":(-20,-37),"River Junction":(32,21),"Sunkettle":(0,-32),"Bellwharf":(6,29),"Greyfold Steading":(-30,25),"Pilgrim's Rest":(36,-24),"Rimewatch":(-48,31)}
    settlements=[p for p in POIS if p[0] in ("town","city","fort")]
    for typ,label,level,x,y,zone in settlements:
        d.ellipse((x-10,y-10,x+10,y+10),fill=(255,246,220,255),outline=(31,40,35,255),width=4)
        dx,dy=offsets.get(label,(22,-22))
        rounded_label(d,(x+dx,y+dy),f"{label}  ·  {level}",fill=(250,246,232,242),fg=(27,39,34,255),size=13,outline=(36,48,41,235))
    im=Image.alpha_composite(im,overlay).convert("RGB")
    d=ImageDraw.Draw(im,"RGBA")
    d.rounded_rectangle((18,18,365,80),radius=12,fill=(24,39,35,220),outline=(244,235,210,235),width=2)
    d.text((34,25),"THORNVALE · ZONE + SETTLEMENT PLAN",font=font(16),fill=(255,248,228,255))
    d.text((34,51),"Zone name and estimated levels are shown inside each outline.",font=font(12),fill=(237,233,219,255))
    im.save(OUT/"world_route_overlay.png",quality=95)

def draw_zone_sheet(zone):
    slug,name,band,color,poly=zone
    sheet_titles={
        "tallowfields":("Tallowfields Meadow Subarea","1–12"),
        "brackenwood":("Brackenwood Fringe Subarea","9–18"),
        "blackbriar":("Blackbriar Wilds Subarea","16–22"),
        "magenta_heath":("Magenta Heath Subarea","19–28"),
        "cyan_floodplain":("Wooded Floodplain Subarea","24–30"),
        "bellwater":("Bellwater Delta Subarea","29–34"),
        "greyfold":("Greyfold Downs Subarea","31–38"),
    }
    sheet_name,sheet_band=sheet_titles.get(slug,(name,band))
    pad=70
    x0=max(0,min(x for x,y in poly)-pad); y0=max(0,min(y for x,y in poly)-pad)
    x1=min(1536,max(x for x,y in poly)+pad); y1=min(1024,max(y for x,y in poly)+pad)
    # Include enough surrounding terrain to make this region legible in context.
    crop=Image.open(SRC).convert("RGBA").crop((x0,y0,x1,y1))
    # High-resolution sheet target with map occupying most of the canvas.
    target=(1400,890)
    s=min(target[0]/crop.width,target[1]/crop.height)
    nw,nh=int(crop.width*s),int(crop.height*s)
    mapim=crop.resize((nw,nh),Image.Resampling.LANCZOS)
    canvas=Image.new("RGBA",(1440,1020),(241,237,222,255))
    canvas.alpha_composite(mapim,((1440-nw)//2,130+(890-nh)//2))
    # Coordinate transform into map placement.
    ox=(1440-nw)//2; oy=130+(890-nh)//2
    def tr(p): return (ox+(p[0]-x0)*s,oy+(p[1]-y0)*s)
    over=Image.new("RGBA",canvas.size,(0,0,0,0)); d=ImageDraw.Draw(over)
    local=[tr(p) for p in poly]
    d.polygon(local,fill=tuple(bytes.fromhex(color[1:]))+(15,))
    d.line(local+[local[0]],fill=(27,37,33,245),width=14,joint="curve")
    d.line(local+[local[0]],fill=tuple(bytes.fromhex(color[1:]))+(255,),width=9,joint="curve")
    items=[p for p in POIS if p[-1]==slug and p[0] in ("town","city","fort")]
    label_positions=[]
    for index,(typ,label,level,x,y,z) in enumerate(items,1):
        X,Y=tr((x,y))
        d.ellipse((X-10,Y-10,X+10,Y+10),fill=(255,246,220,255),outline=(31,40,35,255),width=4)
        bx,by=X+22,Y-22
        text=f"{label}  ·  {level}"
        bounds=d.textbbox((0,0),text,font=font(16))
        tw=bounds[2]-bounds[0]+18; th=bounds[3]-bounds[1]+12
        d.rounded_rectangle((bx,by,bx+tw,by+th),radius=7,fill=(250,246,232,244),outline=(36,48,41,235),width=2)
        d.text((bx+9,by+5),text,font=font(16),fill=(27,39,34,255))
        label_positions.append((index,label,level,int(X),int(Y)))
    canvas=Image.alpha_composite(canvas,over)
    d=ImageDraw.Draw(canvas)
    d.rectangle((0,0,1440,112),fill=(30,51,46,255))
    d.text((35,23),f"{sheet_name.upper()}  ·  LEVELS {sheet_band}",font=font(34),fill=(250,244,224,255))
    d.text((37,72),"PROPOSED ZONE OUTLINE  ·  SETTLEMENT NAMES + ESTIMATED LEVELS",font=font(15),fill=(206,216,197,255))
    canvas.convert("RGB").save(OUT/f"{slug}_overlay.png",quality=95)

draw_world()
for item in ZONES:
    draw_zone_sheet(item)
print(f"Wrote original-map overlays for {len(ZONES)} zones and the world route to {OUT}")
