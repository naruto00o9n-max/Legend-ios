#!/usr/bin/env python3
"""Record the original APK's visible UI. Never modify its binary or invent a session."""
import os,pathlib,subprocess,time,xml.etree.ElementTree as ET,json,re,struct,zlib
ROOT=pathlib.Path('build/reference');ROOT.mkdir(parents=True,exist_ok=True)
ADB=os.environ.get('REFERENCE_ADB','adb');events=[]
def adb(*args,timeout=60):
 return subprocess.run([ADB,*args],capture_output=True,timeout=timeout)
def capture(name):
 time.sleep(2)
 shot=adb('exec-out','screencap','-p');(ROOT/(name+'.png')).write_bytes(shot.stdout)
 tree=adb('shell','uiautomator','dump','--compressed','/sdcard/reference-ui.xml',timeout=30)
 data=adb('exec-out','cat','/sdcard/reference-ui.xml').stdout
 if b'<hierarchy' in data:(ROOT/(name+'.xml')).write_bytes(data)
 events.append({'screen':name,'screenshot_bytes':len(shot.stdout),'hierarchy':b'<hierarchy' in data})
 return ET.fromstring(data) if b'<hierarchy' in data else None
current=None
def tap(pattern):
 if current is None:return False
 for node in current.iter('node'):
  values=' '.join(node.get(k,'') for k in ['text','content-desc','resource-id']).strip()
  if re.search(pattern,values,re.I) and node.get('enabled')=='true':
   bounds=list(map(int,re.findall(r'\d+',node.get('bounds',''))))
   if len(bounds)==4 and bounds[2]>bounds[0] and bounds[3]>bounds[1]:
    adb('shell','input','tap',str((bounds[0]+bounds[2])//2),str((bounds[1]+bounds[3])//2));events.append({'tap':values});return True
 return False
def visit(name,pattern):
 global current
 if tap(pattern):current=capture(name);return True
 return False
# Exact unsigned? Original publisher-signed APK installed unchanged.
r=adb('install','-r','.work/reference.apk',timeout=180)
(ROOT/'install.txt').write_bytes(r.stdout+r.stderr)
if r.returncode:raise SystemExit('Original APK installation failed; inspect install.txt')
(ROOT/'package.txt').write_bytes(adb('shell','dumpsys','package','com.oneguystudio.ytyper').stdout)
adb('shell','settings','put','system','system_locales','ar');adb('shell','input','keyevent','82')
adb('shell','am','start','-n','com.oneguystudio.ytyper/.ui.dashboard.SplashActivity');time.sleep(10)
current=capture('01-original-launch')
visit('02-launch-next',r'(?i)skip|guest|later|بدون|تخطي|زائر|لاحق|استمرار|ابدأ|start')
# Public exported project entry, explicitly unauthenticated. No backend privilege bypass.
r=adb('shell','am','start','-n','com.oneguystudio.ytyper/.ui.dashboard.ProjectsActivity')
(ROOT/'public-project-entry.txt').write_bytes(r.stdout+r.stderr)
time.sleep(5);current=capture('03-projects-unauthenticated')
for name,pattern in [('04-permission',r'permission_allow_button|السماح|Allow'),('05-intro',r'التالي|Next|حسنًا|OK|Got it')]:visit(name,pattern)
# First shortcut is Rewards Protocol (verified on the unmodified APK).
adb('shell','input','tap','468','160');current=capture('05-rewards-header')
adb('shell','am','start','-n','com.oneguystudio.ytyper/.ui.dashboard.ProjectsActivity');current=capture('05-dashboard-return')
# Header settings icon has no accessibility label in the original Compose UI.
adb('shell','input','tap','990','160');events.append({'tap':'Original header settings icon at captured bounds [926,94][1058,226]'})
current=capture('06-settings')
visit('07-profile',r'profile|الملف الشخصي|حسابي|My Profile')
adb('shell','input','keyevent','4');current=capture('08-settings-return')
if 'Settings' in ' '.join(n.get('text','') for n in current.iter('node')):
 adb('shell','input','keyevent','4');current=capture('09-projects-return')
adb('shell','am','start','-n','com.oneguystudio.ytyper/.ui.dashboard.ProjectsActivity');current=capture('09-projects-return')
adb('shell','input','swipe','530','1850','530','700','400');current=capture('10-workspace')
visit('11-community',r'community|المجتمع|Community')
visit('12-community-post',r'itemPost|postCard|التفاصيل|Comments|تعليقات')
adb('shell','am','start','-n','com.oneguystudio.ytyper/.ui.dashboard.ProjectsActivity');current=capture('13-projects-return')
# Make a real, original-size gallery asset using only PNG's documented format.
w,h=800,15000
chunk=lambda name,data:struct.pack('>I',len(data))+name+data+struct.pack('>I',zlib.crc32(name+data)&0xffffffff)
rows=b''.join(b'\0'+bytes((245,245,245))*w for _ in range(h))
png=b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',w,h,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(rows))+chunk(b'IEND',b'')
fixture=ROOT/'reference-800x15000.png';fixture.write_bytes(png)
adb('push',str(fixture),'/sdcard/Pictures/reference-800x15000.png')
scan=adb('shell','am','broadcast','-a','android.intent.action.MEDIA_SCANNER_SCAN_FILE','-d','file:///sdcard/Pictures/reference-800x15000.png');(ROOT/'media-scan.txt').write_bytes(scan.stdout+scan.stderr)
insert=adb('shell','content','insert','--uri','content://media/external/images/media','--bind','_display_name:s:reference-800x15000.png','--bind','mime_type:s:image/png','--bind','_data:s:/storage/emulated/0/Pictures/reference-800x15000.png');(ROOT/'media-insert.txt').write_bytes(insert.stdout+insert.stderr)
time.sleep(5)
visit('14-image-import',r'Import Images|استيراد الصور')
if tap(r'sub_menu_list'):
 current=capture('15-picker-list')
visit('16-picker-asset',r'reference-800x15000')
visit('16-picker-done',r'button_add|button_done|تم|Done|إضافة|Add|Open|Select')
current=capture('17-after-import')
def app_ui():
 return current is not None and any(n.get('package')=='com.oneguystudio.ytyper' for n in current.iter('node'))
if app_ui():visit('18-gallery-page',r'pageThumbnail|imagePreview|reference-800x15000|itemPage')
# Restore the exported dashboard, even when a filename in DocumentsUI matched.
# A blank document provides editor evidence independently of the picker outcome.
adb('shell','input','keyevent','4')
adb('shell','am','start','-n','com.oneguystudio.ytyper/.ui.dashboard.ProjectsActivity')
current=capture('18-projects-for-blank')
if visit('19-new-canvas',r'New Canvas|لوحة جديدة'):
 for index,value in enumerate(['800','15000']):
  edits=[n for n in current.iter('node') if n.get('class')=='android.widget.EditText']
  if len(edits)>=2:
   node=edits[index]
   bounds=list(map(int,re.findall(r'\d+',node.get('bounds',''))))
   adb('shell','input','tap',str((bounds[0]+bounds[2])//2),str((bounds[1]+bounds[3])//2))
   adb('shell','input','keyevent','123',*(['67']*30));adb('shell','input','text',value)
   adb('shell','input','keyevent','4');current=capture('20-new-canvas-dimension-'+str(index))
 visit('21-canvas-created',r'\bCreate\b|إنشاء|Confirm|OK')
 time.sleep(8);current=capture('22-created-project')
 visit('22-open-page',r'blank_[0-9]+\.png|reference-800x15000\.png')
current=capture('23-editor-before-text')
visit('24-text-tool',r'btnAddText|btnToolText|Add Text|إضافة نص|أضف نص')
if tap(r'etInlineInput'):
 adb('shell','input','text','Cookies%stest');current=capture('24-original-text-input')
 adb('shell','input','keyevent','4');current=capture('24-keyboard-hidden')
 adb('shell','input','tap','540','800');current=capture('24-text-handles')
visit('25-text-format',r'btnToolFormat|التنسيق|Format')
visit('26-format-close',r'btnCloseFormat|btnFormatClose|btnClosePanel')
visit('27-font-tool',r'btnToolFont|الخط|Font')
visit('28-font-close',r'btnCloseFont|btnFontClose|btnClosePanel')
adb('shell','input','swipe','920','160','250','160','450');current=capture('28-editor-header-tools')
visit('29-layers',r'btnLayers|الطبقات|Layers')
(ROOT/'events.json').write_text(json.dumps(events,ensure_ascii=False,indent=2))
(ROOT/'logcat.txt').write_bytes(adb('logcat','-d','-t','3000').stdout)
print(json.dumps(events,ensure_ascii=False))
