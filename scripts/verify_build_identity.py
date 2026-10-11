#!/usr/bin/env python3
"""Verify what is actually bundled in each app, not only target configuration."""
import json,pathlib,plistlib,sys
app,bundle,revision,scheme,record=sys.argv[1:]
app=pathlib.Path(app)
info=plistlib.loads((app/'Info.plist').read_bytes())
local=scheme=='CookiesLocal'
assert info['CFBundleIdentifier']==bundle,info.get('CFBundleIdentifier')
assert info['CFBundleDisplayName']=='Cookies Editor'
assert info['CookiesSourceRevision']==revision
assert info['CookiesServicesEnabled'] is (not local)
configs=list(app.rglob('ReferenceService.json'))
assert len(configs)==(0 if local else 1),'Unexpected service configuration in '+scheme
schemes=[s for row in info.get('CFBundleURLTypes',[]) for s in row.get('CFBundleURLSchemes',[])]
assert ('cookies-editor' not in schemes) if local else ('cookies-editor' in schemes)
assert not (app/'embedded.mobileprovision').exists()
assert not list(app.rglob('_CodeSignature'))
pathlib.Path(record).write_text(json.dumps({'scheme':scheme,'bundle_id':bundle,'display_name':info['CFBundleDisplayName'],'source_commit':revision,'service_enabled':info['CookiesServicesEnabled'],'service_configuration_bundled':bool(configs),'url_schemes':schemes,'provisioning_profile':False,'code_signature_directory':False},indent=2)+'\n')
print(scheme+': identity, service isolation and unsigned bundle checks passed')
