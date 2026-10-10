import numpy as np, zlib, base64
d=np.load('layout.npz')
def u8(a): return np.ascontiguousarray(a.astype(np.uint8)).tobytes()
raw=b''.join([u8(d['sea']),u8(d['inland']),u8(d['snow']),u8(d['rock']),u8(d['zid']),u8(d['P'])])
z=zlib.compress(raw,9)
b64=base64.b64encode(z).decode()
print(len(raw),len(z),len(b64))
X0,Y0,XW,YH=50.0,82.0,1508.0,1006.0
def uv(x,y): return [round((x-X0)/XW,4),round((y-Y0)/YH,4)]
pins={
 "wanderers_rest":uv(325,964),"tallowmere":uv(358,810),"hearthmoor":uv(793,599),"ashford":uv(1188,638),
 "sunkettle":uv(286,568),"blackbriar_lodge":uv(1128,465),"pilgrims_rest":uv(932,261),"rimewatch":uv(1443,187),
 "quiet_cart":uv(988,540),"drowned_bell":uv(675,908),"crossing_camp":uv(852,701),"southshore_camp":uv(900,880),
 "warden0":uv(887,515),"warden1":uv(1148,541),"warden2":uv(427,608),"warden3":uv(1343,244),
 "cave_burrow":uv(1435,946),"cave_roots":uv(1109,618),"cave_grotto":uv(459,261),"cave_rime":uv(1427,328),"cave_spider":uv(961,562),
 "stones":uv(745,372),"keep_ruin":uv(960,150),"chapel_isle":uv(565,515),"campwater_towers":uv(740,830),"campwater_arch":uv(990,915),
 "windmill":uv(330,770),"campwater_landing":uv(1100,905),"bellwharf":uv(640,880),"greyfold_steading":uv(800,330),"hotspring":uv(1240,210),"cave_barrow":uv(700,250),
}
out=["# Generated from the Thornvale map images by tools/layout/export.py. Do not edit by hand.","class_name LayoutData","","const GX := 300","const GY := 200","const PX := 600","const PY := 400",
"const ZONE_NAMES := [\"campwater\",\"tallowfields\",\"hearthmoor\",\"brackenwood\",\"blackbriar\",\"saltfen\",\"bellwater\",\"greyfold\",\"frostspine\"]",
"const PINS := {"]
for k,v in pins.items(): out.append('\t"%s": Vector2(%s, %s),'%(k,v[0],v[1]))
out.append("}")
out.append('const BLOB := "%s"'%b64)
open('layout_data.gd','w').write("\n".join(out)+"\n")
