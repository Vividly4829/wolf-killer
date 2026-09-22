import math,random,wave,struct
from pathlib import Path
random.seed(958)
# Original vocal foley: jittered pulse trains, resonant harmonics and breath.
# Short envelopes avoid the sweeping, sustained tone of a siren.
settings={'duck':(180,.45,3),'goose':(260,.65,2),'deer':(110,.60,1),'moose':(72,.85,1),'mink':(1100,.25,2)}
for species,(pitch,duration,pulses) in settings.items():
 rate=24000; data=[]; phase=0; noise=0
 for n in range(int(rate*duration)):
  t=n/rate; u=t/duration; pulse=(u*pulses)%1
  env=(min(1,pulse*20)*max(0,1-pulse)**1.4)
  f=pitch*(1-.18*pulse+.025*math.sin(t*93)+random.uniform(-.013,.013))
  phase+=2*math.pi*f/rate; noise=.6*noise+.4*random.uniform(-1,1)
  vocal=sum(math.sin(phase*h)*math.exp(-((h*f-(1100 if species in ['duck','goose'] else 550))/900)**2)/h**.65 for h in range(1,18))
  value=math.tanh((vocal*.65+noise*.6)*2)*env*.65
  data.append(int(value*32767))
 with wave.open(str(Path('assets/audio')/(species+'_hurt.wav')),'wb') as out:
  out.setparams((1,2,rate,0,'NONE','not compressed'));out.writeframes(struct.pack('<%dh'%len(data),*data))
p=Path('scripts/soundscape.gd');s=p.read_text(encoding='utf-8').replace('samples["bear_growl"]=','for species in ["duck","goose","deer","moose","mink"]: samples[species+"_hurt"]=load("res://assets/audio/"+species+"_hurt.wav")\n\tsamples["bear_growl"]=');p.write_text(s,encoding='utf-8')
