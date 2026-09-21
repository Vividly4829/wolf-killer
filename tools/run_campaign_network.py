import subprocess,time,pathlib,socket,sys,os,shutil
with socket.socket(socket.AF_INET,socket.SOCK_DGRAM) as probe:
 probe.bind(("127.0.0.1",0)); port=probe.getsockname()[1]
failed=False
root=pathlib.Path(__file__).resolve().parents[1]
bundled=root/'tools/Godot_v4.6.2-stable_win64_console.exe'
exe=str(bundled) if bundled.exists() else os.environ.get('GODOT_BIN') or shutil.which('godot') or shutil.which('godot4')
if not exe: raise SystemExit('Install Godot 4.6.2 and set GODOT_BIN or add godot to PATH.')
logs=[]; processes=[]
for label in ['host','a','b']:
 log=open(root/'qa'/('campaign-net-'+label+'.log'),'w',encoding='utf-8');logs.append(log)
 args=[exe,'--headless','--path',str(root),'--script','res://tests/test_campaign_coop.gd','--',f'--test-port={port}']
 if label=='host': args+=['--host']
 processes.append(subprocess.Popen(args,stdout=log,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW if os.name=='nt' else 0))
 time.sleep(2 if label=='host' else .2)
for proc in processes:
 try:
  code=proc.wait(timeout=85); print('exit',code); failed=failed or code!=0
 except subprocess.TimeoutExpired: proc.kill(); proc.wait(); failed=True; print('timeout')
for log in logs: log.close()

sys.exit(1 if failed else 0)
