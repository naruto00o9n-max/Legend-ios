#!/usr/bin/env python3
"""Read actual failed XCUI activities; never infer product state from a timeout."""
import json,pathlib,subprocess
out=pathlib.Path('build/failure-review');out.mkdir(parents=True,exist_ok=True)
def get(path,ident=None):
 cmd=['xcrun','xcresulttool','get','object','--legacy','--path',str(path),'--format','json']
 if ident:cmd+=['--id',ident]
 return json.loads(subprocess.check_output(cmd))
def walk(node):
 if isinstance(node,dict):
  yield node
  for value in node.values():yield from walk(value)
 elif isinstance(node,list):
  for value in node:yield from walk(value)
def value(node):return node.get('_value','') if isinstance(node,dict) else node
for bundle,case in [('ipad.xcresult','testManualSniperKeepsIndependentWhiteningMethodPerBubble'),('ipad-local.xcresult','testLocalPhotosEditingAndOriginalSizeExport')]:
 path=pathlib.Path('.work/evidence')/bundle
 if not path.exists():raise RuntimeError('Missing original result bundle: '+bundle)
 root=get(path);refs=[n['testsRef']['id']['_value'] for n in walk(root) if 'testsRef' in n]
 for ref in dict.fromkeys(refs):
  tests=get(path,ref)
  for node in walk(tests):
   if case not in str(value(node.get('identifier',{})))+str(value(node.get('name',{}))) or 'summaryRef' not in node:continue
   summary=get(path,node['summaryRef']['id']['_value']);(out/(case+'.json')).write_text(json.dumps(summary,indent=2))
   attachments=[a for a in walk(summary) if 'payloadRef' in a and 'uniformTypeIdentifier' in a]
   print(bundle,case,'attachments',len(attachments),flush=True)
   seen=set()
   for i,a in enumerate(reversed(attachments)):
    ident=a['payloadRef']['id']['_value']
    if ident in seen:continue
    seen.add(ident)
    if len(seen)>20:break
    uti=value(a['uniformTypeIdentifier']);name=value(a.get('name',{}));ext='.png' if 'png' in uti else '.jpg' if 'jpeg' in uti else '.txt'
    dest=out/(case+'-'+str(i)+ext)
    cmd=['xcrun','xcresulttool','export','object','--type','file','--path',str(path),'--id',ident,'--output-path',str(dest)]
    done=subprocess.run(cmd,capture_output=True,text=True)
    if done.returncode:done=subprocess.run(cmd[:4]+['--legacy']+cmd[4:],capture_output=True,text=True)
    print(name,uti,dest.name,done.returncode,done.stderr[-250:],flush=True)
