import subprocess,time,pathlib,os,sys
root=pathlib.Path(__file__).resolve().parents[1]
invite=root/'qa/test-invite.txt'
invite.unlink(missing_ok=True)
engine=str(root/'tools/Godot_v4.6.2-stable_win64_console.exe')
logs=[]; processes=[]
def start(label,host=False):
 log=open(root/f'qa/internet-{label}.log','w',encoding='utf-8');logs.append(log)
 args=[engine,'--headless','--path',str(root),'--script','res://tests/test_internet_invite.gd','--']+(['--host'] if host else [])
 p=subprocess.Popen(args,stdout=log,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW);processes.append(p)
 return p
host=start('host',True)
try:
 end=time.monotonic()+190
 while not invite.exists() and time.monotonic()<end and host.poll() is None: time.sleep(.5)
 if not invite.exists(): raise RuntimeError('No invite ready; see host log')
 time.sleep(4)
 for label in ['a','b','c']: start(label);time.sleep(1)
 codes=[p.wait(timeout=180) for p in processes]
 print('Internet process exits:',codes)
 sys.exit(1 if any(codes) else 0)
finally:
 for p in processes:
  if p.poll() is None: p.terminate();p.wait()
 for log in logs:log.close()
 invite.unlink(missing_ok=True)
