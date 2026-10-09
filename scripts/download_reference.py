#!/usr/bin/env python3
"""Download the exact user-provided reference. Never silently upgrade it."""
import argparse, hashlib, html.parser, pathlib, urllib.parse, urllib.request, zipfile
FILE_ID = '1b_s5rb0UiZFFg-qdzZERvDgmkxpvwOvB'
SHA256 = '56ed425f56d0d8614c39ad3e0a50f4eb3528e35676b1f4dc49bbfced4b033e3b'
class Confirmation(html.parser.HTMLParser):
    def __init__(self):
        super().__init__(); self.action = None; self.fields = {}
    def handle_starttag(self, tag, attributes):
        a = dict(attributes)
        if tag == 'form' and a.get('id') == 'download-form': self.action = a.get('action')
        if tag == 'input' and a.get('name'): self.fields[a['name']] = a.get('value', '')
def download(destination):
    destination = pathlib.Path(destination); destination.parent.mkdir(parents=True, exist_ok=True)
    if destination.exists() and hashlib.file_digest(destination.open('rb'), 'sha256').hexdigest() == SHA256:
        return destination
    url = 'https://drive.google.com/uc?' + urllib.parse.urlencode({'export':'download','id':FILE_ID})
    request = urllib.request.Request(url, headers={'User-Agent':'CookiesEditor-Reference/0.1'})
    response = urllib.request.urlopen(request, timeout=120)
    if 'text/html' in response.headers.get('Content-Type',''):
        form = Confirmation(); form.feed(response.read().decode('utf-8')); response.close()
        if not form.action or urllib.parse.urlparse(form.action).hostname != 'drive.usercontent.google.com':
            raise RuntimeError('The public Drive file is unavailable or needs permission.')
        response = urllib.request.urlopen(form.action + '?' + urllib.parse.urlencode(form.fields), timeout=180)
    temporary = destination.with_suffix('.partial')
    try:
        digest = hashlib.sha256()
        with response, temporary.open('wb') as output:
            while block := response.read(1024*1024): digest.update(block); output.write(block)
        if digest.hexdigest() != SHA256: raise RuntimeError('Reference APK hash mismatch; refusing to build.')
        with zipfile.ZipFile(temporary) as archive:
            if archive.testzip(): raise RuntimeError('Reference APK has corrupt entries.')
        temporary.replace(destination)
    finally: temporary.unlink(missing_ok=True)
    return destination
if __name__ == '__main__':
    parser=argparse.ArgumentParser();parser.add_argument('output');args=parser.parse_args()
    print(download(args.output))
