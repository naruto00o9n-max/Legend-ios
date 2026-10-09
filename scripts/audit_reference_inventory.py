#!/usr/bin/env python3
"""Offline evidence inventory. Resource existence never certifies a reachable feature."""
import argparse,collections,csv,json,pathlib,re,xml.etree.ElementTree as ET
parser=argparse.ArgumentParser();parser.add_argument('reference');parser.add_argument('--output',default='docs/audit');args=parser.parse_args()
ref=pathlib.Path(args.reference);out=pathlib.Path(args.output);out.mkdir(parents=True,exist_ok=True)
android='{http://schemas.android.com/apk/res/android}'
strings={}
for folder in ['values','values-ar']:
 file=ref/'decoded/res'/folder/'strings.xml'
 if file.exists():
  for item in ET.parse(file).getroot():
   if item.tag=='string':strings[item.get('name')]=''.join(item.itertext()).strip()
def resolve(value):
 if value.startswith('@string/'):return strings.get(value[8:],value)
 return value
source=ref/'decompiled/sources/com/oneguystudio/ytyper'
java=list(source.rglob('*.java'));text_by_file={str(f.relative_to(ref)):f.read_text(errors='replace') for f in java}
layout_refs=collections.defaultdict(set);id_refs=collections.defaultdict(set)
for path,text in text_by_file.items():
 for value in set(re.findall(r'R\.layout\.([a-zA-Z0-9_]+)',text)):layout_refs[value].add(path)
 for value in set(re.findall(r'R\.id\.([a-zA-Z0-9_]+)',text)):id_refs[value].add(path)
rows=[];layouts=[]
for file in sorted((ref/'decoded/res/layout').glob('*.xml')):
 if not file.name.startswith(('activity_','dialog_','layout_','item_','sheet_','bottom_')):continue
 root=ET.parse(file).getroot();nodes=[]
 for node in root.iter():
  attrs=node.attrib;rid=attrs.get(android+'id','').split('/')[-1];tag=node.tag.split('.')[-1]
  if not rid:continue
  kind='زر محتمل' if ('Button' in tag or attrs.get(android+'clickable')=='true' or rid.lower().startswith(('btn','button'))) else 'إدخال/اختيار' if any(v in tag for v in ['EditText','Slider','SeekBar','Switch','CheckBox','Radio']) else 'عنصر عرض/حاوية'
  row={'layout':file.stem,'id':rid,'type':tag,'classification':kind,'text':resolve(attrs.get(android+'text','')),'hint':resolve(attrs.get(android+'hint','')),'description':resolve(attrs.get(android+'contentDescription','')),'width':attrs.get(android+'layout_width',''),'height':attrs.get(android+'layout_height',''),'visibility':attrs.get(android+'visibility','visible'),'source':str(file.relative_to(ref)),'direct_id_references':';'.join(sorted(id_refs[rid])),'runtime_status':'مورد موجود؛ الوصول والسلوك يحتاجان تحققًا عند غياب لقطة أو اختبار'}
  rows.append(row);nodes.append(rid)
 layouts.append({'layout':file.stem,'source':str(file.relative_to(ref)),'ids':nodes,'direct_layout_references':sorted(layout_refs[file.stem]),'runtime_status':'ليس كل Layout شاشة مستقلة أو ميزة نشطة'})
manifest=ET.parse(ref/'decoded/AndroidManifest.xml').getroot();activities=[];services=[]
for tag,dest in [('activity',activities),('service',services)]:
 for node in manifest.find('application').findall(tag):
  name=node.get(android+'name','')
  if name.startswith('com.oneguystudio.ytyper.'):
   dest.append({'name':name,'exported':node.get(android+'exported','unspecified'),'parent':node.get(android+'parentActivityName',''),'orientation':node.get(android+'screenOrientation',''),'source':'decoded/AndroidManifest.xml'})
compose=sorted({f.name.split('$')[0].removesuffix('.java') for f in java if any(x in f.name for x in ['ScreenKt','DialogKt','DashboardKt'])})
prefs=source/'data/Prefs.java';text=prefs.read_text();preferences=[]
for match in re.finditer(r'public final ([^\n{]+?) ((?:get|is)[A-Z]\w*)\([^\n]*\)\s*\{',text):
 start=match.end();depth=1;end=start
 while end<len(text) and depth:
  if text[end]=='{':depth+=1
  elif text[end]=='}':depth-=1
  end+=1
 body=text[start:end-1]
 keys=re.findall(r'(?:preferences|sharedPreferences)\.(?:get|contains)\w*\("([^\"]+)"',body)
 if not keys:continue
 preferences.append({'method':match.group(2),'type':match.group(1),'keys':';'.join(keys),'line':text[:match.start()].count('\n')+1,'source':'decompiled/sources/com/oneguystudio/ytyper/data/Prefs.java','meaning':'راجع طريقة الاستخدام؛ ليست كل قيمة إعدادًا ظاهرًا للمستخدم'})
def write_csv(name,data):
 with (out/name).open('w',encoding='utf-8-sig',newline='') as f:
  w=csv.DictWriter(f,fieldnames=list(data[0]));w.writeheader();w.writerows(data)
write_csv('original-ui-elements.csv',rows);write_csv('original-buttons-and-inputs.csv',[r for r in rows if r['classification']!='عنصر عرض/حاوية']);write_csv('original-preferences.csv',preferences)
report={'reference_version':'YTyper 4.5','apk_sha256':'a3758bcdf50c802c25d9023c90456f6bdde922a94cda08fc3ce737c2a9b29789','all_layout_xml_files':len(list((ref/'decoded/res/layout').glob('*.xml'))),'app_prefixed_layouts':len(layouts),'identified_ui_elements':len(rows),'candidate_buttons':sum(r['classification']=='زر محتمل' for r in rows),'inputs_and_choices':sum(r['classification']=='إدخال/اختيار' for r in rows),'original_activity_count':len(activities),'original_service_count':len(services),'preference_accessors':len(preferences),'activities':activities,'services':services,'compose_screen_families':compose,'layouts':layouts,'limits':['Resource IDs are exhaustive for selected app-prefixed layouts, not exhaustive for Compose-generated or programmatic UI.','A resource or decompiled class may be unused or entitlement-dependent.','JADX reported 305 errors; behavior inventory requires subsequent runtime validation.','No authenticated original Google account was available in this audit.']}
(out/'original-resource-inventory.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({k:v for k,v in report.items() if isinstance(v,(str,int))},ensure_ascii=False))
