#!/usr/bin/env python3
"""v23_images.rbxlx : l'UI v23 de Thomas (StationTycoon_v23.rbxlx : Player + PlotView + News sur le menu, HUD argent/XP,
   Stock/Supply par familles avec cartes Sel/Src, Build Move/Delete, Delivery) avec les 73 images v23 importees sur son
   compte (Station_Tycoon_v23_IDs.json) + les images v22 conservees (planches Drive, Index...).
   Usage : python3 gen_ui_v23.py -> v23_images.rbxlx (2e argument du merger dans build_place2.sh)"""
import json, xml.etree.ElementTree as ET
SRC_V23 = "/root/.claude/uploads/c725c065-cb20-5868-b02f-9a238e45d840/52738af5-StationTycoon_v23.rbxlx"
IDS = {k.replace(".png", "").replace(".ogg", ""): v for k, v in json.load(open("/mnt/user-data/outputs/Station_Tycoon_v23_IDs.json")).items()}
# images v22 deja sur le compte (voir gen_ui_v22.py)
IDS.update({"Drive_0": 101929553782212, "Drive_1": 137610413804119, "Drive_2": 87504937988729,
            "Drive_3": 113691141843349, "Drive_4": 90357405635169, "Drive_5": 119908296211917})
# chemin (sous StarterGui) -> nom du PNG (Image + StringValue Src) ; (chemin, "Sel") -> PNG de l'etat selectionne
SRC = {
    "Loading/Root/Title/T0": "LoadTitle_00", "Loading/Root/Title/T1": "LoadTitle_01",
    "Menu/Choose/Tiles/T0": "Menu_00", "Menu/Choose/Tiles/T2": "Menu_10",
    "Menu/Choose/NewsDrop/T0": "MenuNews_00",
    "Menu/Choose/Hero/Car": "Drive_3",
    "Main/Root/HUD/HUD1/BarArt/Bar0": "HUD_00", "Main/Root/HUD/HUD1/BarArt/Bar1": "HUD_01",
    "Main/Root/MENUS/Build/Art/Base/T0": "Build_00", "Main/Root/MENUS/Build/Art/Base/T1": "Build_01",
    "Main/Root/MENUS/Build/Top/Active_move": "BuildMode_move", "Main/Root/MENUS/Build/Top/Active_del": "BuildMode_del",
    "Main/Root/MENUS/Staff/Art/Base/T0": "Staff_00", "Main/Root/MENUS/Staff/Art/Assign/T0": "StaffAssign_00",
    "Main/Root/MENUS/Stock/Art/Base/T0": "Stock_00", "Main/Root/MENUS/Stock/Art/Base/T1": "Stock_01",
    "Main/Root/MENUS/Supply/Art/Base/T0": "Supply_00",
}
for c in ("sol", "murs", "stations", "utilitaires", "deco", "toit"):
    SRC[f"Main/Root/MENUS/Build/Art/Variants/V_{c}/T0"] = f"BuildStrip_{c}_00"
for i in range(1, 10):
    SRC[f"Main/Root/MENUS/Stock/Art/Variants/V{i}/T0"] = f"StockR{i}_00"
    SRC[f"Main/Root/MENUS/Stock/Art/Center/{i}"] = f"StockRow_{i}"
    SRC[f"Main/Root/MENUS/Supply/Art/Center/{i}"] = f"SupplyCard_{i}"
for k in range(3):
    SRC[f"Main/Root/MENUS/Stock/Fams/F{k}/T0"] = f"StockFam{k}_00"
    SRC[f"Main/Root/MENUS/Supply/Fams/F{k}/T0"] = f"SupplyFam{k}_00"
SEL = {f"Main/Root/MENUS/Stock/Art/Center/{i}": f"StockRowSel_{i}" for i in range(1, 10)}
SEL.update({f"Main/Root/MENUS/Supply/Art/Center/{i}": f"SupplyCardSel_{i}" for i in range(1, 10)})

tree = ET.parse(SRC_V23); root = tree.getroot()
def name(it):
    for q in it.find("Properties"):
        if q.get("name") == "Name": return q.text
def find(it, path):
    for p in path.split("/"):
        it = [c for c in it.findall("Item") if name(c) == p][0]
    return it
def prop(it, n):
    for q in it.find("Properties"):
        if q.get("name") == n: return q
sg = find(root, "StarterGui")
n = 0
utilises = set()
for path, png in SRC.items():
    lab = find(sg, path)
    for c in lab.findall("Item"):
        if c.get("class") == "StringValue" and name(c) == "Src":
            prop(c, "Value").text = f"rbxassetid://{IDS[png]}"
    img = prop(lab, "Image")
    url = img.find("url")
    if url is not None: url.text = f"rbxassetid://{IDS[png]}"
    else: img.text = f"rbxassetid://{IDS[png]}"
    n += 1; utilises.add(png)
for path, png in SEL.items():
    lab = find(sg, path)
    for c in lab.findall("Item"):
        if c.get("class") == "StringValue" and name(c) == "Sel":
            prop(c, "Value").text = f"rbxassetid://{IDS[png]}"; n += 1; utilises.add(png)
# planches de l'animation de la voiture (DriveData : JSON dans un ModuleScript)
dd = find(sg, "Menu/Choose/Hero/Car/DriveData"); src = prop(dd, "Source")
zero = '"sheets": ["rbxassetid://0", "rbxassetid://0", "rbxassetid://0", "rbxassetid://0", "rbxassetid://0", "rbxassetid://0"]'
assert zero in src.text
src.text = src.text.replace(zero, '"sheets": [' + ", ".join(f'"rbxassetid://{IDS[f"Drive_{i}"]}"' for i in range(6)) + ']')
# verification : plus aucun rbxassetid://0 sur une image (sauf la voiture du menu = planche animee)
restants = []
def walk(it, path):
    p = path + "/" + (name(it) or "?")
    if it.get("class") in ("ImageLabel", "ImageButton"):
        img = prop(it, "Image"); u = img.find("url") if img is not None else None
        v = (u.text if u is not None else (img.text if img is not None else ""))
        if v in ("rbxassetid://0", None, ""): restants.append(p)
    for c in it.findall("Item"): walk(c, p)
walk(sg, "")
manquantes = sorted(k for k in IDS if k not in utilises and not k.startswith("Drive_") and k not in ("klaxon", "moteur", "schling"))
tree.write("v23_images.rbxlx", encoding="utf-8", xml_declaration=True)
print(f"v23_images.rbxlx : {n} images/sel renseignees + 6 planches Drive ; images v23 non utilisees : {manquantes} ; encore a 0 : {restants}")
