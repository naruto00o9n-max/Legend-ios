"""Observe the unmodified reference on a disposable emulator; never patch it."""
import json, pathlib, subprocess, time
root=pathlib.Path('.work/ibis/package'); output=pathlib.Path('build/ibis');output.mkdir(parents=True,exist_ok=True)

def adb(*args,timeout=90,raw=False):
    return subprocess.run(['adb',*args],check=True,stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=timeout).stdout if raw else subprocess.check_output(['adb',*args],timeout=timeout,text=True)

adb('shell','wm','size','800x1280');adb('shell','wm','density','160')
adb('install-multiple','-r',*[str(root/x) for x in ['jp.ne.ibis.ibispaintx.app.apk','config.x86_64.apk','config.hdpi.apk','config.en.apk']],timeout=300)
(output/'package.txt').write_text(adb('shell','dumpsys','package','jp.ne.ibis.ibispaintx.app'))
adb('logcat','-c')
adb('shell','am','start','-a','android.intent.action.MAIN','-c','android.intent.category.LAUNCHER','-n','jp.ne.ibis.ibispaintx.app/.InitializeCheckActivity')
time.sleep(15)
steps=json.loads(pathlib.Path('scripts/ibis-reference-steps.json').read_text())
for index,step in enumerate(steps):
    name=f'{index:02d}-'+step['name']
    if 'tap' in step:adb('shell','input','tap',*[str(x) for x in step['tap']])
    if 'swipe' in step:adb('shell','input','swipe',*[str(x) for x in step['swipe']])
    if step.get('back'):adb('shell','input','keyevent','4')
    time.sleep(step.get('wait',2))
    (output/(name+'.png')).write_bytes(adb('exec-out','screencap','-p',raw=True))
    try:
        adb('shell','uiautomator','dump','/sdcard/ibis-window.xml',timeout=20)
        (output/(name+'.xml')).write_text(adb('shell','cat','/sdcard/ibis-window.xml'))
    except Exception as error:(output/(name+'-accessibility.txt')).write_text(str(error))
(output/'logcat.txt').write_text(adb('logcat','-d'))
activity=adb('shell','dumpsys','activity','activities')
(output/'activity.txt').write_text(activity)
assert any('jp.ne.ibis.ibispaintx.app' in line for line in activity.splitlines() if 'mResumedActivity' in line or 'topResumedActivity' in line),'Reference is not in the foreground; screenshots alone are not a passing interaction test'
print('Saved real reference screenshots:',len(steps))
