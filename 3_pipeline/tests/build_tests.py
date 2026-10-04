#!/usr/bin/env python3
"""Assemble stubs + module(s) + tests en un seul fichier luau (les globals d'un module require ne sont pas partages)."""
import sys, re
def lire(p): return open(p, encoding="utf-8").read()
stubs = lire("stubs_roblox.lua").replace("return {Inst = Inst, modules = modules, services = services, v3 = v3, cf = cf}",
                                          "local S = {Inst = Inst, modules = modules, services = services, v3 = v3, cf = cf}")
def module(nom, chemin):
    src = lire(chemin)
    return f"local {nom} = (function()\n{src}\nend)()\n"
test = lire(sys.argv[1])
test = re.sub(r'local S = require\("./stubs_roblox"\)\n', "", test)
mods = ""
for m in re.findall(r'local (\w+) = require\("./(\w+)"\)\n', test):
    nom, fichier = m
    mods_src = lire(fichier + ".lua")
    test = test.replace(f'local {nom} = require("./{fichier}")\n', f"__MODULE_{nom}__\n")
    mods += f"{nom}|{fichier}\n"
for ligne in mods.strip().split("\n") if mods.strip() else []:
    nom, fichier = ligne.split("|")
    test = test.replace(f"__MODULE_{nom}__\n", module(nom, fichier + ".lua"))
open(sys.argv[2], "w", encoding="utf-8").write(stubs + "\n" + test)
print("ecrit", sys.argv[2])
