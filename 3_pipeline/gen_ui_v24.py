#!/usr/bin/env python3
"""v24_images.rbxlx : l'UI v24 de Thomas (StationTycoon_v24.rbxlx : onglets Station + Shop, fenetre Rangs 8 rangs, modes
   Trajectoire / Decoration du menu Construction, 4 metiers, voiture du menu a 30 i/s) avec les numeros d'actif :
     1. Station_Tycoon_v24_IDs.json (outputs) : les 116 images v24 une fois importees sur le compte de Thomas (a creer)
     2. sinon ids.txt du dossier de transfert (images deja en ligne, inchangees depuis la v23)
     3. sinon, provisoirement, l'image v23 du meme nom (Station_Tycoon_v23_IDs.json) : l'ancien visuel plutot que rien
     4. sinon rbxassetid://0 (invisible)
   Usage : python3 gen_ui_v24.py -> v24_images.rbxlx (2e argument du merger dans build_place2.sh)"""
import json, os, re, xml.etree.ElementTree as ET
D = "ui_v24/StationTycoon_transfert_v24"
SRC_V24 = f"{D}/1_fichier_roblox/StationTycoon_v24.rbxlx"
IDS = {}
# 3. v23
IDS.update({k.replace(".png", "").replace(".ogg", ""): v for k, v in json.load(open("/mnt/user-data/outputs/Station_Tycoon_v23_IDs.json")).items()})
provisoires = set(IDS)
# 2. ids.txt
for line in open(f"{D}/3_toutes_les_images/ids.txt"):
    m = re.match(r"(\S+)\.png\s*=\s*(\d+)", line.strip())
    if m and int(m.group(2)) > 0: IDS[m.group(1)] = int(m.group(2)); provisoires.discard(m.group(1))
# 1. v24 importees
J24 = "/mnt/user-data/outputs/Station_Tycoon_v24_IDs.json"
if os.path.exists(J24):
    for k, v in json.load(open(J24)).items():
        k = k.replace(".png", "").replace(".ogg", "")
        if int(v) > 0: IDS[k] = int(v); provisoires.discard(k)

# chemin (sous StarterGui) -> PNG pour les emplacements encore a 0 dans le fichier v24
SRC = {
    "Loading/Root/Title/T0": "LoadTitle_00", "Loading/Root/Title/T1": "LoadTitle_01",
    "Menu/Choose/Tiles/T0": "Menu_00", "Menu/Choose/Tiles/T2": "Menu_10",
    "Menu/Choose/NewsDrop/T0": "MenuNews_00",
    "Menu/Choose/Hero/Car": "Drive30_3",
    "Main/Root/HUD/HUD1/BarArt/Bar0": "HUD_00", "Main/Root/HUD/HUD1/BarArt/Bar1": "HUD_01",
    "Main/Root/HUD/HUD1/BarArt/Inactive_Supply": "TabInactive_Supply",
    "Main/Root/MENUS/Build/Art/Base/T0": "Build_00", "Main/Root/MENUS/Build/Art/Base/T1": "Build_01",
    "Main/Root/MENUS/Staff/Art/Base/T0": "Staff_00", "Main/Root/MENUS/Staff/Art/Base/T1": "Staff_01",
    "Main/Root/MENUS/Staff/Art/Assign/T0": "StaffAssign_00",
    "Main/Root/MENUS/Stock/Art/Base/T0": "Stock_00",
    "Main/Root/MENUS/Supply/Art/Base/T0": "Supply_00", "Main/Root/MENUS/Supply/Art/Base/T1": "Supply_01",
    "Main/Root/MENUS/Station/Art/Base/T0": "Station_00",
}
for t in ("Build", "Stock", "Supply", "Staff", "Index", "Station"):
    SRC[f"Main/Root/HUD/HUD1/BarArt/Active_{t}"] = f"TabActive_{t}"
for c in ("sol", "murs", "stations", "utilitaires", "deco", "toit"):
    SRC[f"Main/Root/MENUS/Build/Art/Variants/V_{c}/T0"] = f"BuildStrip_{c}_00"
for m in ("move", "del", "path", "deco"):
    SRC[f"Main/Root/MENUS/Build/Top/Active_{m}"] = f"BuildMode_{m}"
for i in range(1, 10):
    SRC[f"Main/Root/MENUS/Stock/Art/Variants/V{i}/T0"] = f"StockR{i}_00"
    SRC[f"Main/Root/MENUS/Stock/Art/Center/{i}"] = f"StockRow_{i}"
    SRC[f"Main/Root/MENUS/Supply/Art/Center/{i}"] = f"SupplyCard_{i}"
for k in range(3):
    SRC[f"Main/Root/MENUS/Stock/Fams/F{k}/T0"] = f"StockFam{k}_00"
    SRC[f"Main/Root/MENUS/Supply/Fams/F{k}/T0"] = f"SupplyFam{k}_00"
    SRC[f"Main/Root/MENUS/Shop/Tabs/T{k}/T0"] = f"Shop{k}_00"; SRC[f"Main/Root/MENUS/Shop/Tabs/T{k}/T1"] = f"Shop{k}_01"
for k in range(8):
    SRC[f"Main/Root/MENUS/Ranks/Sel/S{k}/T0"] = f"Rangs{k}_00"; SRC[f"Main/Root/MENUS/Ranks/Sel/S{k}/T1"] = f"Rangs{k}_01"
SEL = {f"Main/Root/MENUS/Stock/Art/Center/{i}": f"StockRowSel_{i}" for i in range(1, 10)}
SEL.update({f"Main/Root/MENUS/Supply/Art/Center/{i}": f"SupplyCardSel_{i}" for i in range(1, 10)})

tree = ET.parse(SRC_V24); root = tree.getroot()
def name(it):
    pr = it.find("Properties")
    if pr is None: return None
    for q in pr:
        if q.get("name") == "Name": return q.text
def find(it, path):
    for p in path.split("/"):
        it = [c for c in it.findall("Item") if name(c) == p][0]
    return it
def prop(it, n):
    for q in it.find("Properties"):
        if q.get("name") == n: return q
def rbx(png): return f"rbxassetid://{IDS.get(png, 0)}"
sg = find(root, "StarterGui")
n = 0; manquants = set(); prov = set()
for path, png in SRC.items():
    lab = find(sg, path)
    for c in lab.findall("Item"):
        if c.get("class") == "StringValue" and name(c) == "Src":
            if prop(c, "Value").text in ("rbxassetid://0", "", None): prop(c, "Value").text = rbx(png)
    img = prop(lab, "Image")
    if img is not None:
        url = img.find("url")
        cur = url.text if url is not None else img.text
        if cur in ("rbxassetid://0", "", None):
            if url is not None: url.text = rbx(png)
            else: img.text = rbx(png)
    n += 1
    if png not in IDS: manquants.add(png)
    elif png in provisoires: prov.add(png)
for path, png in SEL.items():
    lab = find(sg, path)
    for c in lab.findall("Item"):
        if c.get("class") == "StringValue" and name(c) == "Sel":
            if prop(c, "Value").text in ("rbxassetid://0", "", None): prop(c, "Value").text = rbx(png)
    if png not in IDS: manquants.add(png)
    elif png in provisoires: prov.add(png)
# planches de l'animation de la voiture du menu (8 planches Drive30_*)
dd = find(sg, "Menu/Choose/Hero/Car/DriveData"); src = prop(dd, "Source")
zero = '"sheets": [' + ", ".join(['"rbxassetid://0"'] * 8) + ']'
assert zero in src.text, "DriveData : planches deja renseignees ?"
if all(f"Drive30_{i}" in IDS for i in range(8)):
    src.text = src.text.replace(zero, '"sheets": [' + ", ".join(f'"rbxassetid://{IDS[f"Drive30_{i}"]}"' for i in range(8)) + ']')
else:
    manquants.update(f"Drive30_{i}" for i in range(8) if f"Drive30_{i}" not in IDS)
# sons : moteur / schling dans UIController/Sounds
snd = find(sg, "UIController/Sounds"); s = prop(snd, "Source")
for cle, fichier in (("engine", "moteur"), ("schling", "schling")):
    if fichier in IDS:
        s.text = re.sub(r'(%s\s*=\s*\{\s*id\s*=\s*")rbxassetid://\d+' % cle, r'\g<1>rbxassetid://%d' % IDS[fichier], s.text)
tree.write("v24_images.rbxlx", encoding="utf-8", xml_declaration=True)
print(f"v24_images.rbxlx : {n} emplacements ; {len(prov)} images provisoires (visuel v23) ; {len(manquants)} sans numero :", ", ".join(sorted(manquants)))
