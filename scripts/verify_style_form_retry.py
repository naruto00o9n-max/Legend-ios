#!/usr/bin/env python3
"""Permit a targeted style-form retry only for this reviewed presentation repair.

The only product change is a scrollable, large style-details presentation with
its own state/dismissal, a captured selected text layer and visible save errors.
Engine, storage, services, resources, build inputs and native tests stay exact.
The complete native, relevant connected UI and local/Photos gates still run.
"""
import hashlib,pathlib,subprocess
root=pathlib.Path(__file__).resolve().parents[1]
path="App/UI/StyleLibraryView.swift"
before=subprocess.check_output(["git","show","HEAD^:"+path],cwd=root)
after=(root/path).read_bytes()
if hashlib.sha256(before).hexdigest()!="536e0454108e956e77d41e2b3e3d95d5b951910b8cc293861bd10ac40b66faf5":raise SystemExit("Unexpected parent style form")
if hashlib.sha256(after).hexdigest()!="440971700f09cb35868ff2c16624cb74b0ee1b44634726d204528813285feccd":raise SystemExit("Unreviewed style-form changes")
subprocess.run(["git","diff","--exit-code","HEAD^","HEAD","--","App",":!"+path,"ServicesTests","ServicesUITests","Tests","LocalUITests","project.yml","scripts",":!scripts/verify_style_form_retry.py"],cwd=root,check=True)
print("Only the reviewed style form changed; engine, storage and all other product/build sources are identical.")
