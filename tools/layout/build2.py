from PIL import Image
import numpy as np, scipy.ndimage as ndi, zlib, base64, json
im=Image.open('/mnt/user-data/uploads/Embers/assets/thornvale_world_topdown.png').convert('RGB')
a=np.asarray(im).astype(float)
H,W=a.shape[:2]
r,g,b=a[...,0],a[...,1],a[...,2]
mx=a.max(-1); mn=a.min(-1); sat=(mx-mn)/(mx+1)
water=(b>r+30)&(b>=g-25)
er=ndi.binary_erosion(water,iterations=8,border_value=1)
lab,n=ndi.label(er)
bd=set(np.unique(np.r_[lab[0],lab[-1],lab[:,0],lab[:,-1]]))-{0}
core=np.isin(lab,list(bd))
sea=ndi.binary_dilation(core,iterations=11)&water
# cap propagation: limit to within 10px of core growth is skipped; check inland
inland=water&~sea
snow=(mn>165)&(sat<0.18)
rock=(sat<0.16)&(mx>70)&(mx<190)&~snow
forest=(g>r+8)&(g>b+8)&(mx<125)
sandy=(r>190)&(g>160)&(b>100)&(b<180)&(r-b>40)&(r-g<45)&~water
blob=ndi.binary_opening(sandy,structure=np.ones((3,3)),iterations=4)
blob=ndi.binary_dilation(blob,iterations=3)
sand=blob&sandy
path=sandy&~blob
path=ndi.binary_closing(path,iterations=1)
l2,n2=ndi.label(path,structure=np.ones((3,3)))
sz=ndi.sum(path,l2,range(1,n2+1))
keep=np.isin(l2,[i+1 for i,s in enumerate(sz) if s>60])
path=keep
dens=ndi.gaussian_filter(sandy.astype(float),10)
path=path&(dens<0.26)
snow_d=ndi.gaussian_filter(snow.astype(float),12)
inland=inland&~(snow_d>0.25)
def down(m,gx,gy):
    return np.asarray(Image.fromarray((m*255).astype(np.uint8)).resize((gx,gy),Image.BOX)).astype(np.uint8)
GX,GY=300,200
F=dict(sea=down(sea,GX,GY),inland=down(inland,GX,GY),snow=down(snow,GX,GY),rock=down(rock,GX,GY),forest=down(forest,GX,GY),sand=down(sand,GX,GY))
P=down(path,600,400)
P=(P>40).astype(np.uint8)*255
# ---- zones
Z=["campwater","tallowfields","hearthmoor","brackenwood","blackbriar","saltfen","bellwater","greyfold","frostspine"]
seeds={
 "campwater":[(0.60,0.76),(0.70,0.78),(0.55,0.68),(0.66,0.70)],
 "tallowfields":[(0.14,0.68),(0.22,0.76),(0.12,0.80),(0.27,0.68),(0.16,0.89),(0.25,0.86)],
 "hearthmoor":[(0.47,0.55),(0.40,0.61),(0.36,0.68),(0.50,0.62)],
 "brackenwood":[(0.70,0.57),(0.80,0.63),(0.63,0.50),(0.90,0.55)],
 "blackbriar":[(0.77,0.33),(0.72,0.43),(0.64,0.34),(0.84,0.42)],
 "saltfen":[(0.20,0.47),(0.28,0.42),(0.12,0.40),(0.22,0.28),(0.30,0.52)],
 "bellwater":[(0.40,0.91),(0.50,0.93)],
 "greyfold":[(0.50,0.24),(0.58,0.10),(0.38,0.20),(0.47,0.36),(0.62,0.20)],
 "frostspine":[(0.88,0.16),(0.80,0.08),(0.93,0.30),(0.74,0.18)],
}
rng=np.random.default_rng(3)
yy,xx=np.mgrid[0:GY,0:GX]
U=(xx+0.5)/GX; V=(yy+0.5)/GY
# domain warp
def noise(seed,f):
    r=np.random.default_rng(seed); g=r.standard_normal((int(GY*f)+3,int(GX*f)+3))
    return np.asarray(Image.fromarray(g.astype(np.float32),mode='F').resize((GX,GY),Image.BICUBIC))
wu=U+0.03*noise(1,0.05); wv=V+0.045*noise(2,0.05)
best=np.full((GY,GX),9.0); zid=np.zeros((GY,GX),np.uint8)
for zi,z in enumerate(Z):
    for (su,sv) in seeds[z]:
        d=np.hypot((wu-su)*1.5,(wv-sv))
        if z=="frostspine": d=d*0.85
        m=d<best; best[m]=d[m]; zid[m]=zi
snow_s=ndi.gaussian_filter(F['snow']/255.0,3)
zid[(snow_s>0.35)]=Z.index("frostspine")
# the fen: where inland water is dense in the west
fen=ndi.gaussian_filter(F['inland']/255.0,4)
zid[(fen>0.12)&(U<0.5)&(V<0.62)]=Z.index("saltfen")
zid=ndi.median_filter(zid,size=5)
np.save('zid.npy',zid)
cols=np.array([(230,200,80),(240,150,60),(200,200,200),(40,120,40),(10,70,10),(60,150,200),(200,100,200),(150,150,90),(255,255,255)])
rgb=cols[zid]
base=np.asarray(im.resize((GX,GY)))
ov=(0.5*base+0.5*rgb).astype(np.uint8)
from PIL import ImageDraw
sea_s=ndi.gaussian_filter(F['sea']/255.0,1)>0.5
ov[sea_s]=(0.5*ov[sea_s]).astype(np.uint8)
img=Image.fromarray(ov).resize((1200,800),Image.NEAREST)
dr=ImageDraw.Draw(img)
for zi,z in enumerate(Z):
    ys,xs=np.where((zid==zi)&~sea_s)
    if len(xs): dr.text((xs.mean()*4-30,ys.mean()*4),z,fill=(255,255,255))
img.save('zones.png')
np.savez('layout.npz',zid=zid,P=P,**F)
print({k:int(v.mean()) for k,v in F.items()}, P.mean()/255)
