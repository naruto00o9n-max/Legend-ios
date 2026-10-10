#!/usr/bin/env python3
"""Fetch hash-pinned, attributed real comic references into the test bundle only."""
import hashlib,json,pathlib,subprocess,urllib.request
root=pathlib.Path(__file__).resolve().parents[1]
folder=root/'Tests/WhiteningFixtures';folder.mkdir(exist_ok=True)
for item in json.loads((root/'scripts/whitening-fixtures.json').read_text()):
 source=root/'.work'/('whitening-'+item['name']+'.'+item['format'])
 if not source.exists():urllib.request.urlretrieve(item['url'],source)
 assert hashlib.sha256(source.read_bytes()).hexdigest()==item['sha256'],'Whitening reference changed: '+item['name']
 target=folder/(item['name']+'.png')
 if item['format']=='png':target.write_bytes(source.read_bytes())
 else:subprocess.run(['sips','-s','format','png',str(source),'--out',str(target)],check=True,stdout=subprocess.DEVNULL)
print('Four attributed real references prepared for native whitening tests, excluded from the application bundle.')
