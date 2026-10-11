#!/usr/bin/env python3
"""Restrict this retry to the reviewed style presentation and test fixture fix.

Item-based initial values and selected-layer snapshots make style saving stable;
its form owns state/dismissal and displays errors. The test harness now installs
this revision and requires a real Files fixture before test-without-building.
Engine, storage, services, resources and native/local tests remain unchanged.
Full native, seven connected UI and complete local/Photos gates still run.
"""
import hashlib,pathlib,subprocess
root=pathlib.Path(__file__).resolve().parents[1]
checks={'App/UI/StyleLibraryView.swift': ('440971700f09cb35868ff2c16624cb74b0ee1b44634726d204528813285feccd', '08ce33dc1b6b6467bb2e7bc7a962d0ba1f1f096cd0a2608bd63b86c65bee9e37'), 'scripts/test_simulators.sh': ('7e651f3abf39dfab9b75386a1528a62c1f3a4429199096d4eaac183419c2f0c4', '4a27eb985d4772841bdf1e0ec20638949c8d1d2959528834a2a40de2bbea2ca6')}
for path,(old,new) in checks.items():
 before=subprocess.check_output(["git","show","HEAD^:"+path],cwd=root)
 after=(root/path).read_bytes()
 if hashlib.sha256(before).hexdigest()!=old or hashlib.sha256(after).hexdigest()!=new:raise SystemExit("Unreviewed retry change: "+path)
subprocess.run(["git","diff","--exit-code","HEAD^","HEAD","--","App",":!App/UI/StyleLibraryView.swift","ServicesTests","ServicesUITests","Tests","LocalUITests","project.yml","scripts",":!scripts/verify_style_form_retry.py",":!scripts/test_simulators.sh"],cwd=root,check=True)
print("Only the sealed style presentation and real Files fixture ordering changed; all other product/build/native sources identical.")
