#!/usr/bin/env python3
"""Organize unmodified simulator captures and report real test results."""
import pathlib,json,re,shutil,html,subprocess
root=pathlib.Path(__file__).resolve().parents[1];build=root/'build';gallery=build/'ScreenGallery';gallery.mkdir(exist_ok=True)
records=[]
for manifest in (build/'screenshots').rglob('manifest.json'):
 for case in json.loads(manifest.read_text()):
  for asset in case.get('attachments',[]):
   name=asset.get('suggestedHumanReadableName','')
   if not name.endswith('.png') or not re.match(r'^(\d\d-|inspector-|cleaner-|batch-|fix-)',name):continue
   label=re.split(r'_\d+_',name)[0];device=asset.get('deviceName','iPhone');folder=gallery/device;folder.mkdir(exist_ok=True)
   source=manifest.parent/asset['exportedFileName'];target=folder/(label+'.png')
   if target.exists():continue
   shutil.copyfile(source,target);records.append({'device':device,'screen':label,'file':str(target.relative_to(gallery)),'test':case['testIdentifier']})
images=''.join('<figure><img loading="lazy" src="'+html.escape(r['file'],quote=True)+'"><figcaption>'+html.escape(r['device']+' · '+r['screen'])+'</figcaption></figure>' for r in records)
(gallery/'index.html').write_text('<!doctype html><html lang="ar" dir="rtl"><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>Cookies · لقطات المحاكي</title><style>body{margin:32px;background:#080808;color:#ffffff;font:16px system-ui}main{display:grid;grid-template-columns:repeat(auto-fit,minmax(260px,1fr));gap:24px}figure{margin:0;padding:16px;border:1px solid #68562a;border-radius:20px;background:#171614}img{display:block;max-width:100%;height:auto;margin:auto}figcaption{padding-top:16px;font-size:13px}</style><h1>Cookies Editor</h1><p>لقطات غير معدلة من الاستخدام الفعلي على محاكيات iPhone وiPad.</p><main>'+images+'</main></html>')
summary={'commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip(),'screenshots':records,'tests':[]}
for path in sorted(build.glob('test-*.log')):
 text=path.read_text(errors='replace')
 summary['tests'].append({'log':path.name,'passed':re.findall(r"Test Case '(.*?)' passed \((.*?) seconds\)",text),'failures':re.findall(r'^.*error:.*$',text,re.M),'result':'passed' if re.search(r'\*\* TEST (?:EXECUTE )?SUCCEEDED \*\*',text) else 'not-passed'})
(build/'verification.json').write_text(json.dumps(summary,indent=2,ensure_ascii=False)+'\n')
shutil.make_archive(str(build/'Cookies-Editor-Screenshots'),'zip',gallery)
print(f'{len(records)} real simulator captures collected; verification.json records pass/failure evidence')
