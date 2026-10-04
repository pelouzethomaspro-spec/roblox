#!/usr/bin/env python3
"""gen/Patch_vNN.rbxmx : "patch a chaud" de la place cloud (Team Create) quand la publication par fichier est bloquee.
   Contient tout ce que build_place2.sh applique a la base : les sources (--source, instances remplacees), les modeles
   inseres (--insert), le StarterGui v23 cable et les PlotSpawns. A inserer dans Workspace (Explorateur > Inserer depuis
   un fichier), puis appliquer avec la commande de appliquer_patch.lua (barre de commande), puis Publier (Alt+P).
   Usage : python3 gen_patch.py 40"""
import sys, os, re, html, xml.etree.ElementTree as ET
VER = sys.argv[1] if len(sys.argv) > 1 else "40"
ICI = os.path.dirname(os.path.abspath(__file__))
O = "/mnt/user-data/outputs/Integration_Stations"; G = os.path.join(ICI, "gen")
build = open(os.path.join(ICI, "build_place2.sh")).read()
sources = [s[len("--source="):] for s in re.findall(r'"(--source=[^"]*)"', build)]
inserts = [s[len("--insert="):] for s in re.findall(r'"(--insert=[^"]*)"', build)]
def chemin(p): return p.replace("$O", O).replace("$G", G)

# classes des cibles : lues dans la base (rbxlx)
print("lecture de la base…")
root = ET.parse(os.path.join(ICI, "base_v8.rbxlx")).getroot()
def nom(it):
    pr = it.find("Properties")
    if pr is None: return None
    for c in pr:
        if c.get("name") == "Name": return c.text
    return None
classes = {}
def walk(it, path):
    p = path + "/" + (nom(it) or "?")
    classes[p.strip("/")] = it.get("class")
    for c in it.findall("Item"): walk(c, p)
for it in root.findall("Item"): walk(it, "")

def esc(s): return html.escape(s, quote=False)
def script_item(classe, nom_, src, desactive=False):
    dis = '<bool name="Disabled">true</bool>' if desactive else ''
    return f'<Item class="{classe}"><Properties><string name="Name">{esc(nom_)}</string>{dis}<ProtectedString name="Source">{esc(src)}</ProtectedString></Properties></Item>'

parts = ['<roblox version="4">', '<Item class="Folder"><Properties><string name="Name">Patch_v%s</string></Properties>' % VER]
# 1. sources (hors StarterGui : remplace en bloc)
parts.append('<Item class="Folder"><Properties><string name="Name">Sources</string></Properties>')
n_src = 0
for s in sources:
    path, fichier = s.split("=", 1)
    if path.startswith("StarterGui/"): continue
    classe = classes.get(path)
    if not classe:
        print("ATTENTION : cible absente de la base :", path); continue
    src = open(chemin(fichier), encoding="utf-8").read()
    parts.append(script_item(classe, path, src, desactive=(classe == "Script")))
    n_src += 1
parts.append('</Item>')
# 2. inserts (modeles rbxmx) : sous-dossier par cible ; les Items sont recopies tels quels
parts.append('<Item class="Folder"><Properties><string name="Name">Inserts</string></Properties>')
par_cible = {}
for s in inserts:
    path, fichier = s.split("=", 1)
    par_cible.setdefault(path, []).append(chemin(fichier))
n_ins = 0
for path, fichiers in par_cible.items():
    parts.append('<Item class="Folder"><Properties><string name="Name">%s</string></Properties>' % esc(path))
    for f in fichiers:
        txt = open(f, encoding="utf-8").read()
        m = re.search(r'<roblox[^>]*>(.*)</roblox>', txt, re.S)
        parts.append(m.group(1)); n_ins += 1
    parts.append('</Item>')
parts.append('</Item>')
# 3. StarterGui v23 cable (v23_images.rbxlx) avec mes sources UIController / Sounds
parts.append('<Item class="Folder"><Properties><string name="Name">StarterGui</string></Properties>')
ui = ET.parse(os.path.join(ICI, "v23_images.rbxlx")).getroot()
sg = [it for it in ui.findall("Item") if nom(it) == "StarterGui"][0]
def set_source(it, src):
    for c in it.find("Properties"):
        if c.get("name") == "Source": c.text = src
for it in sg.findall("Item"):
    if nom(it) == "UIController":
        set_source(it, open(os.path.join(O, "UIController.lua"), encoding="utf-8").read())
        for c in it.findall("Item"):
            if nom(c) == "Sounds": set_source(c, open(os.path.join(O, "Sounds.lua"), encoding="utf-8").read())
    parts.append(ET.tostring(it, encoding="unicode"))
parts.append('</Item>')
parts.append('</Item></roblox>')
out = os.path.join(G, f"Patch_v{VER}.rbxmx")
open(out, "w", encoding="utf-8").write("\n".join(parts))
print(f"{out} : {n_src} sources, {n_ins} modeles inseres ({len(par_cible)} cibles), StarterGui v23 ; {os.path.getsize(out)//1024} Ko")
