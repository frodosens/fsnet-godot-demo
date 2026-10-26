from pathlib import Path
from PIL import Image
from scipy import ndimage
import numpy as np,json,hashlib
R=Path(__file__).resolve().parent
M={'frame_size':[192,160],'foot_anchor':[96,144],'filter':'nearest','method':'alpha component isolation, common nearest scale per source, foot-center anchor; no painted pixels','characters':{}}
for name in ['oren','tessa','bram','finn_hit','neri_hit','mara_hit','tessa_hit','bram_hit']:
 a=np.array(Image.open(R/'sources'/f'{name}.png').convert('RGBA'));lab,n=ndimage.label(a[:,:,3]>=16);obs=ndimage.find_objects(lab)
 objs=[(i+1,s) for i,s in enumerate(obs) if (lab[s]==i+1).sum()>5000];objs.sort(key=lambda z:(0 if z[1][0].start<a.shape[0]/2 else 1,z[1][1].start))
 hit=name.endswith('_hit'); assert len(objs)==(2 if hit else 8)
 scale=.148 if hit else .28
 states=['hit','recover'] if hit else ['idle','anticipation','windup','contact','followthrough','recover','return_step','settle']
 frames=[];entries=[];out=R/'runtime'/name;out.mkdir(parents=True,exist_ok=True)
 for k,((label,(sy,sx)),state) in enumerate(zip(objs,states)):
  p=a[sy,sx].copy();p[:,:,3]=np.where(lab[sy,sx]==label,p[:,:,3],0)
  # Grounded foot-center comes from the bottom 12 source pixel rows, not weapon or cape extent.
  ys,xs=np.where(p[-12:,:,3]>=16);ax=sx.start+(int(xs.min())+int(xs.max()))/2
  im=Image.fromarray(p).resize((round(p.shape[1]*scale),round(p.shape[0]*scale)),Image.Resampling.NEAREST)
  x=round(96-(ax-sx.start)*scale);y=144-im.height
  assert min(x,y)>=0 and x+im.width<=192,(name,k,x,im.size)
  f=Image.new('RGBA',(192,160));f.paste(im,(x,y));fn=f'{k:02}_{state}.png';f.save(out/fn);frames.append(f)
  entries.append({'index':k,'state':state,'path':f'runtime/{name}/{fn}','source_component':label,'source_crop':[sx.start,sy.start,sx.stop,sy.stop],'source_foot_x':ax,'placement':[x,y],'sha256':hashlib.sha256((out/fn).read_bytes()).hexdigest()})
 timeline=[0]*4+[1]*6 if hit else [0]*2+[1]*4+[2]*3+[3]*2+[4]*3+[5]*4+[6]*3+[7]*3
 M['characters'][name]={'unique_keyframes':len(frames),'facing':'right','scale':scale,'frames':entries,'tick_ms':60,'timeline':timeline,'contact_tick':None if hit else 9,'note':'Held ticks are not additional drawings. Hit begins on contact, return to existing idle after recover.' if hit else 'Sparse keyframes, engine playback not yet accepted.'}
 sheet=Image.new('RGBA',(192*(2 if hit else 4),160*(1 if hit else 2)),'#292b2b')
 for i,f in enumerate(frames):sheet.alpha_composite(f,(i%(2 if hit else 4)*192,i//(2 if hit else 4)*160))
 sheet.save(R/'qa'/f'{name}-contact.png')
 ims=[]
 for i in timeline:
  bg=Image.new('RGBA',(192,160),'#292b2b');bg.alpha_composite(frames[i]);ims.append(bg.convert('RGB'))
 ims[0].save(R/'qa'/f'{name}-timing.gif',save_all=True,append_images=ims[1:],duration=60,loop=0)
(R/'manifest.json').write_text(json.dumps(M,indent=2))
print('Validated 34 unique RGBA frames, transparent, 192x160, weapon bounds and anchor')
