@echo off
for %%f in (*.a51) do a51 %%f DEBUG
TS *.lst "error #"
if exist prj.lib del prj.lib
lib51 create prj.lib
for %%f in (kep*.obj) do lib51 add %%f to PRJ.LIB
for %%f in (kep*.obj) do del %%f
for %%f in (*.obj) do lib51 add %%f to PRJ.LIB
lib51 delete prj.lib(mutama)
l51 mutama.obj, prj.lib -ixref
;del *.obj
;del *.lst
ohs51 mutama
