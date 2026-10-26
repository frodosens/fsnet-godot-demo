from pathlib import Path
from PIL import Image
from scipy import ndimage
import numpy as np,json,hashlib
R=Path(__file__).resolve().parent
M={'frame_size':[192,160],'foot_anchor':[96,144],'filter':'nearest','method':'alpha>=16 component isolation; common scale per role; grounded foot-center anchor; no redrawing','characters':{},'effects':[]}
S={'finn':([3,5,2,1,31,30,32,33],[183,546,897,1305,180,573,970,1331],.238,['idle','nock_anticipation','half_draw','full_draw','release','followthrough','lower_bow','settle']), 'neri':([2,3,4,1,13,12,11,10],[205,570,948,1337,224,636,1029,1358],.231,['idle','anticipation','raise_staff','charge','cast','followthrough','recover','settle'])}
for name,(order,anchors,scale,states) in S.items():
 a=np.array(Image.open(R/'sources'/f'{name}.png').convert('RGBA'));labs,n=ndimage.label(a[:,:,3]>=16);obs=ndimage.find_objects(labs);frames=[];entries=[]
 out=R/'runtime'/name;out.mkdir(parents=True,exist_ok=True)
 for k,(label,ax,state) in enumerate(zip(order,anchors,states)):
  sy,sx=obs[label-1];b=[sx.start,sy.start,sx.stop,sy.stop];p=a[sy,sx].copy();p[:,:,3]=np.where(labs[sy,sx]==label,p[:,:,3],0);im=Image.fromarray(p);im=im.resize((round(im.width*scale),round(im.height*scale)),Image.Resampling.NEAREST);x=round(96-(ax-sx.start)*scale);y=144-im.height
  assert x>=0 and y>=0 and x+im.width<=192
  f=Image.new('RGBA',(192,160));f.paste(im,(x,y));fn=f'{k:02}_{state}.png';f.save(out/fn);frames.append(f)
  entries.append({'index':k,'state':state,'path':f'runtime/{name}/{fn}','source_crop':b,'source_foot_x':ax,'placement':[x,y],'sha256':hashlib.sha256((out/fn).read_bytes()).hexdigest()})
 timeline=[0]*2+[1]*3+[2]*3+[3]*4+[4]*2+[5]*3+[6]*4+[7]*3
 M['characters'][name]={'unique_keyframes':8,'facing':'right','scale':scale,'frames':entries,'tick_ms':60,'timeline_24ticks':timeline,'release_tick':12,'note':'24 held ticks, not 24 distinct drawings; sparse first-playable keyframes, engine playback required'}
 ims=[]
 for i in timeline:
  bg=Image.new('RGBA',(192,160),'#292b2b');bg.alpha_composite(frames[i]);ims.append(bg.convert('RGB'))
 ims[0].save(R/'qa'/f'{name}-timing.gif',save_all=True,append_images=ims[1:],duration=60,loop=0)
 sheet=Image.new('RGBA',(192*4,160*2),'#292b2b')
 for i,f in enumerate(frames):sheet.alpha_composite(f,(i%4*192,i//4*160))
 sheet.save(R/'qa'/f'{name}-contact.png')
# Isolated VFX remain separate layers; crop the six source motifs, including disconnected particles.
a=np.array(Image.open(R/'sources/vfx.png').convert('RGBA'));H,W=a.shape[:2]
for i,(name,lo,hi) in enumerate([('arrow',0,.21),('gather',.21,.34),('charge',.34,.49),('bolt',.49,.67),('impact',.67,.84),('dissipate',.84,1)]):
 x0,x1=round(W*lo),round(W*hi);c=a[:,x0:x1].copy();c[:,:,3]=np.where(c[:,:,3]>=16,c[:,:,3],0);im=Image.fromarray(c);box=im.getbbox();im=im.crop(box);scale=.105;im=im.resize((max(1,round(im.width*scale)),max(1,round(im.height*scale))),Image.Resampling.NEAREST);f=Image.new('RGBA',(64,48));f.paste(im,((64-im.width)//2,(48-im.height)//2));p=R/'runtime'/f'vfx_{name}.png';f.save(p);M['effects'].append({'state':name,'path':str(p.relative_to(R)),'size':[64,48],'pivot':[32,24]})
(R/'manifest.json').write_text(json.dumps(M,indent=2))
print('DONE',len(M['characters']),'roles, 16 character frames, 6 VFX, alpha and inbounds checked')
