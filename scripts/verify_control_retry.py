#!/usr/bin/env python3
"""Permit a focused retry only for two exact nonvisual color-control changes.

Renderer, storage, services, build inputs and every other product source must
remain identical to the parent that ran the full UI suite. Native core and both
local-edition/Photos gates still run; the retry covers all three failed cases.
"""
import pathlib,subprocess
root=pathlib.Path(__file__).resolve().parents[1]
path="App/UI/ColorLibraryView.swift"
base=subprocess.check_output(["git","show","HEAD^:"+path],cwd=root,text=True)
changes=[
 ('foregroundStyle(Palette.secondary)}}.buttonStyle(.plain).accessibilityIdentifier("color-well-"+title)',
  'foregroundStyle(Palette.secondary)}.contentShape(Rectangle())}.buttonStyle(.plain).accessibilityIdentifier("color-well-"+title)'),
 ('frame(maxWidth:.infinity)}}.navigationTitle("الألوان")',
  'frame(maxWidth:.infinity)}.accessibilityIdentifier("color-library-scroll")}.navigationTitle("الألوان")')]
for before,after in changes:
 if base.count(before)!=1:raise SystemExit("Retry guard: parent does not contain the expected original color control")
 base=base.replace(before,after)
if (root/path).read_text()!=base:raise SystemExit("Retry guard: unexpected color-control product changes")
subprocess.run(["git","diff","--exit-code","HEAD^","HEAD","--","App",":!"+path,"ServicesTests","ServicesUITests","project.yml","scripts",":!scripts/verify_control_retry.py"],cwd=root,check=True)
print("Focused control retry allowed: exact hit shape and accessibility identifier only; all other product/build sources unchanged.")
