"""Inspection d'un .rbxlx (XML Roblox) : arbre, CFrame, tailles, pivots, bbox d'un modele."""
import xml.etree.ElementTree as ET, numpy as np, sys

def charger(chemin):
    return ET.parse(chemin).getroot()

def nom(item):
    p = item.find("Properties")
    if p is None: return "?"
    n = p.find("string[@name='Name']")
    return n.text if n is not None else "?"

def enfants(item):
    return item.findall("Item")

def trouver(racine, chemin):
    parts = chemin.split("/")
    cur = [i for i in racine.findall("Item") if nom(i) == parts[0]]
    for p in parts[1:]:
        cur = [c for i in cur for c in enfants(i) if nom(c) == p]
    return cur

def prop(item, name):
    p = item.find("Properties")
    if p is None: return None
    for e in p:
        if e.get("name") == name: return e
    return None

def cframe(item, name="CFrame"):
    e = prop(item, name)
    if e is None: return None
    v = {c.tag: float(c.text) for c in e}
    pos = np.array([v["X"], v["Y"], v["Z"]])
    R = np.array([[v["R00"], v["R01"], v["R02"]], [v["R10"], v["R11"], v["R12"]], [v["R20"], v["R21"], v["R22"]]])
    return pos, R

def vec3(item, name):
    e = prop(item, name)
    if e is None: return None
    v = {c.tag: float(c.text) for c in e}
    return np.array([v["X"], v["Y"], v["Z"]])

def pivot(item):
    e = prop(item, "WorldPivotData")
    if e is None: return None
    cf = e.find("CFrame")
    if cf is None: return None
    v = {c.tag: float(c.text) for c in cf}
    return np.array([v["X"], v["Y"], v["Z"]]), np.array([[v["R00"], v["R01"], v["R02"]], [v["R10"], v["R11"], v["R12"]], [v["R20"], v["R21"], v["R22"]]])

def descendants(item):
    out = [item]
    for c in enfants(item): out += descendants(c)
    return out

PARTS = {"Part", "MeshPart", "UnionOperation", "WedgePart", "CornerWedgePart", "TrussPart"}

def bbox(item):
    pts = []
    for d in descendants(item):
        if d.get("class") in PARTS:
            cf = cframe(d); sz = vec3(d, "size")
            if cf is None or sz is None: continue
            pos, R = cf; half = np.abs(R) @ (sz / 2)
            pts.append(pos - half); pts.append(pos + half)
    if not pts: return None
    P = np.vstack(pts); return P.min(0), P.max(0)

def decrire(item, indent="  "):
    for d in descendants(item):
        if d.get("class") in PARTS:
            pos, R = cframe(d); sz = vec3(d, "size")
            m = prop(d, "MeshId"); mid = (m.text if m is not None else "")
            print(f"{indent}{nom(d):24s} {d.get('class'):14s} pos={pos.round(2)} size={sz.round(2)} rotId={'I' if np.allclose(R, np.eye(3)) else R.round(2).tolist()} {mid}")
    bb = bbox(item)
    if bb: print(f"{indent}bbox min={bb[0].round(2)} max={bb[1].round(2)} taille={(bb[1]-bb[0]).round(2)}")
    pv = pivot(item)
    if pv: print(f"{indent}pivot={pv[0].round(2)} rot={'I' if np.allclose(pv[1], np.eye(3)) else pv[1].round(2).tolist()}")

if __name__ == "__main__":
    r = charger(sys.argv[1])
    for ch in sys.argv[2:]:
        for it in trouver(r, ch):
            print("=====", ch, it.get("class")); decrire(it)
