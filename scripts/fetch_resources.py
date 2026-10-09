#!/usr/bin/env python3
import pathlib,zipfile,re,json,base64,hashlib,subprocess,urllib.request,shutil
from download_reference import download
p=pathlib.Path(__file__).resolve().parents[1]
revision='722718f6e8d8ff8f02337c5bf83a6455d9f4b6a1'
base='https://raw.githubusercontent.com/naruto00o9n-max/Legend/'+revision+'/'
for target,digest in json.loads((p/'scripts/vendor-hashes.json').read_text()).items():
 path=p/target
 if not path.exists():
  path.parent.mkdir(parents=True,exist_ok=True)
  urllib.request.urlretrieve(base+target.replace('App/Core/','ios/Core/'),path)
 assert hashlib.sha256(path.read_bytes()).hexdigest()==digest,'Pinned libpng source changed'
resources=p/'App/Resources';resources.mkdir(parents=True,exist_ok=True)
logo=resources/'cookies-logo.png'
if not logo.exists():urllib.request.urlretrieve(base+'branding/cookies-logo.png',logo)
assert hashlib.sha256(logo.read_bytes()).hexdigest()=='e0d291fa5db42d49c62267d27cdd9a0d7f003077957db5390943966c7a9248d0','Brand asset changed'
apk=download(p/'.work/reference.apk');fonts=resources/'Fonts';fonts.mkdir(parents=True,exist_ok=True)
with zipfile.ZipFile(apk) as z:
 for name in z.namelist():
  if name.startswith('assets/fonts/'): (fonts/pathlib.Path(name).name).write_bytes(z.read(name))
  brush_paths={'res/6Q.png':'censor','res/4z.png':'b1','res/jT.png':'b2','res/Em.png':'b3','res/sd.png':'b4','res/ZY.png':'b5','res/Q1.png':'b6','res/V6.png':'b7','res/tb.png':'b8'}
  if name in brush_paths:
   brushes=resources/'Brushes';brushes.mkdir(exist_ok=True);(brushes/(brush_paths[name]+'.png')).write_bytes(z.read(name))
  if name=='assets/ag-psd.bundle.js':(resources/'ag-psd.bundle.js').write_bytes(z.read(name))
 dex=b'\n'.join(z.read(n) for n in z.namelist() if re.match(r'classes\d*\.dex$',n))
 host='https://xbrpvumrwhbarxuksddt.supabase.co';key=None
 for token in re.findall(rb'eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+',dex):
  try:
   payload=json.loads(base64.urlsafe_b64decode(token.split(b'.')[1]+b'==='))
   if payload.get('role')=='anon' and payload.get('ref')=='xbrpvumrwhbarxuksddt':key=token.decode();break
  except Exception:pass
 assert key,'Public anonymous client configuration not found; refusing invented credentials'
 (resources/'ReferenceService.json').write_text(json.dumps({'url':host,'key':key}))
framework=p/'.work/opencv-ios.zip';expected='1e83edcd3e482228f5c2348a7ceafd72efd614b6578e68f610cd0898c6df95d1'
if not framework.exists():urllib.request.urlretrieve('https://github.com/opencv/opencv/releases/download/4.11.0/opencv-4.11.0-ios-framework.zip',framework)
assert hashlib.file_digest(framework.open('rb'),'sha256').hexdigest()==expected,'OpenCV archive changed'
subprocess.run(['ditto','-x','-k',str(framework),str(p/'.work/opencv')],check=True)
icon=resources/'Assets.xcassets/AppIcon.appiconset';icon.mkdir(parents=True,exist_ok=True)
subprocess.run(['sips','-z','1024','1024',str(resources/'cookies-logo.png'),'--out',str(icon/'icon.png')],check=True,stdout=subprocess.DEVNULL)
(icon/'Contents.json').write_text(json.dumps({'images':[{'filename':'icon.png','idiom':'universal','platform':'ios','size':'1024x1024'}],'info':{'author':'xcode','version':1}}))
brand=resources/'Assets.xcassets/CookiesLogo.imageset';brand.mkdir(parents=True,exist_ok=True)
shutil.copyfile(resources/'cookies-logo.png',brand/'logo.png')
(brand/'Contents.json').write_text(json.dumps({'images':[{'filename':'logo.png','idiom':'universal'}],'info':{'author':'xcode','version':1}}))
(resources/'Assets.xcassets/Contents.json').write_text('{"info":{"author":"xcode","version":1}}')
print('47 original fonts, pinned OpenCV and public client configuration prepared; no private/admin credential')
