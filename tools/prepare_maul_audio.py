from pathlib import Path
import soundfile as sf, numpy as np, zipfile, io
from scipy.signal import resample_poly, butter,sosfilt
out=Path('godot/assets/audio');rate=22050

def mono(y):return y.mean(axis=1) if y.ndim>1 else y

def save(name,y,r):
 y=mono(y);y=resample_poly(y,rate,r);y-=y.mean()
 active=np.flatnonzero(np.abs(y)>.018*np.max(np.abs(y)))
 if len(active):y=y[max(0,active[0]-220):min(len(y),active[-1]+440)]
 y=y/max(.001,np.max(np.abs(y)))*.84
 n=min(220,len(y)//8);y[:n]*=np.linspace(0,1,n);y[-n:]*=np.linspace(1,0,n)
 sf.write(out/name,y,rate,subtype='PCM_16');print(name,round(len(y)/rate,2))
for i,name in enumerate(['dog-growl','dog-snarl','dog-grumble']):
 y,r=sf.read(Path('reference/audio/dog_snarl/dog')/(name+'.flac'));save('wolf_snarl_%d.wav'%(i+1),y,r)
y,r=sf.read('reference/audio/dog-growl.ogg');save('wolf_snarl_4.wav',y,r)
with zipfile.ZipFile('reference/audio/haeldb-yelling.zip') as z:
 for i,name in enumerate(['yell1.wav','3yell16.wav','3yell13.wav']):
  y,r=sf.read(io.BytesIO(z.read('yelling sounds/'+name)));save('maul_scream_%d.wav'%(i+1),y,r)
y,r=sf.read('reference/audio/cloth_0013.mp3');y=mono(y)
# Detect separate foley gestures by 30ms RMS, merge gaps below 250ms.
step=int(r*.03);env=np.array([np.sqrt(np.mean(y[i:i+step]**2)) for i in range(0,len(y),step)])
ids=np.flatnonzero(env>max(env)*.10);groups=[]
for i in ids:
 if not groups or i-groups[-1][-1]>8:groups.append([i])
 else:groups[-1].append(i)
for i,(start,end) in enumerate([(0.48,.96),(2.22,2.64),(3.18,4.35),(7.2,8.45)]):save('cloth_tear_%d.wav'%(i+1),y[int(start*r):int(end*r)],r)
print('tear groups',[(round(g[0]*.03,2),round(g[-1]*.03,2)) for g in groups])
