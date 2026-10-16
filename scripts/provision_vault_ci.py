"""Short-lived ordinary test sessions, authenticated with GitHub's OIDC identity.
No production credential is stored in GitHub or written into the app target.
"""
import json, os, pathlib, sys, urllib.request, urllib.parse, urllib.error
endpoint='https://ilagswvocznnrrreiswq.supabase.co/functions/v1/vault-native-ci/'
fixture=pathlib.Path('Tests/TransientVaultSession.json')
action=sys.argv[1]
if action=='verify-log':
    text=pathlib.Path(sys.argv[2]).read_text(errors='replace')
    assert any('testLivePrivateVaultRoundTripEvictionAndReopen' in line and "' passed (" in line for line in text.splitlines()),'The live native vault test must run and pass, not skip'
    print('Live native account/archive/upload/readback/eviction/reopen check passed')
    sys.exit()
if action=='cleanup' and not fixture.exists():
    print('No provisioned test account to clean');sys.exit()
url=os.environ['ACTIONS_ID_TOKEN_REQUEST_URL']+'&audience='+urllib.parse.quote('cookies-vault-native-tests')
req=urllib.request.Request(url,headers={'Authorization':'Bearer '+os.environ['ACTIONS_ID_TOKEN_REQUEST_TOKEN']})
with urllib.request.urlopen(req,timeout=30) as response:token=json.load(response)['value']
body={}
if action=='cleanup':body={'users':[json.loads(fixture.read_text())['session']['user']['id']]}
req=urllib.request.Request(endpoint+action,data=json.dumps(body).encode(),headers={'Authorization':'Bearer '+token,'Content-Type':'application/json'})
try:
    with urllib.request.urlopen(req,timeout=45) as response:data=json.load(response)
except urllib.error.HTTPError as error:
    print('CI provisioner rejected the request:',error.code,error.read().decode()[:800])
    raise SystemExit(1)
if action=='provision':
    assert data['configuration']['key'].startswith('sb_publishable_') or data['configuration']['key'].startswith('eyJ')
    fixture.write_text(json.dumps(data));fixture.chmod(0o600)
    print('Provisioned a temporary ordinary vault test account; credentials are confined to the XCTest bundle')
else:
    assert data.get('cleaned') is True
    fixture.unlink(missing_ok=True)
    print('Temporary vault account, project rows and image objects removed')
