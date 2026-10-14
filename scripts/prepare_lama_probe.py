#!/usr/bin/env python3
"""Prepare attributed, checksum-verified reference crops; never bundle full chapters."""
import hashlib,json,pathlib,urllib.request
from PIL import Image,ImageDraw
root=pathlib.Path(__file__).resolve().parents[1]
out=root/'build/lama-probe-fixtures';out.mkdir(parents=True,exist_ok=True)
refs=json.loads((root/'scripts/lama-real-fixtures.json').read_text())
for item in refs:
 source=root/'.work'/('lama-reference-'+item['name'])
 if not source.exists():
  with urllib.request.urlopen(item['source'],timeout=45) as response:source.write_bytes(response.read(20000000))
 assert hashlib.sha256(source.read_bytes()).hexdigest()==item['source_sha256'],item['name']+' reference changed'
 x,y,w,h=item['crop'];image=Image.open(source).convert('RGB').crop((x,y,x+w,y+h));mask=Image.new('L',image.size);draw=ImageDraw.Draw(mask)
 for rx,ry,rw,rh in item['mask_rects']:draw.rectangle((rx,ry,rx+rw-1,ry+rh-1),fill=255)
 image.save(out/(item['name']+'.png'));mask.save(out/(item['name']+'-mask.png'))
(out/'references.json').write_text(json.dumps(refs,ensure_ascii=False,indent=2)+'\n')
print('Prepared',len(refs),'real references. Asura references are not claimed unless an accessible source is verified.')
