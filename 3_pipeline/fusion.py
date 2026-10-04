"""Fusion : tycoon (thomas.rbxl) + stations (jeux.rbxl) + scripts modifies -> jeu_integre.rbxl"""
import struct, math, sys
import rbxcodec as C
from cframe_ext import ROT

OUT = sys.argv[1] if len(sys.argv) > 1 else "jeu_integre.rbxl"
SCRIPTS = "/mnt/user-data/outputs/Integration_Stations/"

# ---------------------------------------------------------------- float / cframe helpers (binary "rotated" f32)
def f32_dec(b):
    u = struct.unpack(">I", b)[0]
    u = ((u >> 1) | ((u & 1) << 31)) & 0xFFFFFFFF
    return struct.unpack("<f", struct.pack("<I", u))[0]

def f32_enc(f):
    u = struct.unpack("<I", struct.pack("<f", f))[0]
    r = ((u << 1) & 0xFFFFFFFF) | (u >> 31)
    return struct.pack(">I", r)

def cf_dec(e):
    rot, xb, yb, zb = e
    if rot[0] == 0:
        R = struct.unpack("<9f", rot[1:])
    else:
        R = ROT[rot[0]]
    return (f32_dec(xb), f32_dec(yb), f32_dec(zb)), tuple(R)

def cf_enc(p, R):
    return (b"\x00" + struct.pack("<9f", *R), f32_enc(p[0]), f32_enc(p[1]), f32_enc(p[2]))

def v3_dec(e):
    return (f32_dec(e[0]), f32_dec(e[1]), f32_dec(e[2]))

def mat_mul_vec(R, v):
    return (R[0]*v[0] + R[1]*v[1] + R[2]*v[2], R[3]*v[0] + R[4]*v[1] + R[5]*v[2], R[6]*v[0] + R[7]*v[1] + R[8]*v[2])

def mat_T(R):
    return (R[0], R[3], R[6], R[1], R[4], R[7], R[2], R[5], R[8])

def mat_mul(A, B):
    return tuple(sum(A[i*3+k] * B[k*3+j] for k in range(3)) for i in range(3) for j in range(3))

def cross(a, b):
    return (a[1]*b[2] - a[2]*b[1], a[2]*b[0] - a[0]*b[2], a[0]*b[1] - a[1]*b[0])

def norm(a):
    l = math.sqrt(sum(x*x for x in a)); return (a[0]/l, a[1]/l, a[2]/l)

def from_columns(vx, vy, vz):  # R00 R01 R02 = first row = (vx.x, vy.x, vz.x)
    return (vx[0], vy[0], vz[0], vx[1], vy[1], vz[1], vx[2], vy[2], vz[2])

# ---------------------------------------------------------------- load
A = C.read("thomas.rbxl"); IA = C.index(A)
B = C.read("jeux.rbxl");   IB = C.index(B)
print("A:", sum(len(c['refs']) for c in A.classes.values()), "instances ; B:", sum(len(c['refs']) for c in B.classes.values()))

def one(inst, path):
    r = C.find(inst, path); assert len(r) == 1, f"{path}: {len(r)} resultats"; return r[0]

def descendants(inst, r):
    out, stack = [], [r]
    while stack:
        x = stack.pop(); out.append(x); stack.extend(inst[x]["children"])
    return out

def prop_type(f, cid, name):
    for pr in f.props:
        if pr["cid"] == cid and pr["name"] == name: return pr["typ"]
    return None

# ---------------------------------------------------------------- 0) duplications dans A (boutons 7/8/9 des menus Stock et Supply, apercus Products)
import os
def clone_subtree(f, inst, root, new_name, new_parent):
    nodes = descendants(inst, root)
    maxref = max(max(c["refs"]) for c in f.classes.values())
    m = {r: maxref + 1 + i for i, r in enumerate(nodes)}
    for r in nodes:
        i = inst[r]; cid, idx = i["cid"], i["idx"]
        c = f.classes[cid]
        c["refs"].append(m[r])
        if c["markers"] is not None: c["markers"] += bytes([c["markers"][idx]])
        for pr in f.props:
            if pr["cid"] != cid: continue
            v = pr["elems"][idx]
            if pr["typ"] == 0x13: v = m.get(v, v)
            elif pr["typ"] == 0x22 and v[0] == 2: v = (2, m.get(v[1], v[1]))
            elif pr["typ"] == 0x1F and pr["name"] == "UniqueId": v = os.urandom(16)
            elif pr["name"] == "Name" and pr["typ"] == 0x01 and r == root: v = new_name.encode()
            pr["elems"].append(v)
        f.parent[m[r]] = new_parent if r == root else m[inst[r]["parent"]]
        f.prnt_order.append(m[r])
    return m[root]

for menu in ("Stock", "Supply"):
    centre = one(IA, f"StarterGui/Main/MENUS/{menu}/Center")
    src = one(IA, f"StarterGui/Main/MENUS/{menu}/Center/6")
    for n in ("7", "8", "9"):
        clone_subtree(A, IA, src, n, centre); print(f"A: bouton {menu}/Center/{n} cree (copie de 6)")
prod = one(IA, "ReplicatedStorage/Products")
for src_name, n in (("3", "7"), ("1", "8"), ("2", "9")):
    clone_subtree(A, IA, one(IA, f"ReplicatedStorage/Products/{src_name}"), n, prod); print(f"A: Products/{n} cree (apercu provisoire = copie de {src_name})")
# nouveau module ClientCamera (copie vide d'ActionManager, source remplacee plus bas)
clone_subtree(A, IA, one(IA, "StarterPlayer/StarterPlayerScripts/ActionManager"), "ClientCamera", one(IA, "StarterPlayer/StarterPlayerScripts"))
print("A: ModuleScript ClientCamera cree")
IA = C.index(A)

# ---------------------------------------------------------------- 1) suppressions dans A
a_rs_furn = one(IA, "ReplicatedStorage/Furniture")
delete = set()
for n in ("5", "6", "7", "8"):
    for r in C.find(IA, f"ReplicatedStorage/Furniture/{n}"):
        delete.update(descendants(IA, r)); print("A: suppression Furniture/" + n)
for r in C.find(IA, "Workspace/Stations_8"):
    delete.update(descendants(IA, r)); print("A: suppression Workspace/Stations_8 (%d instances)" % len(descendants(IA, r)))

# ---------------------------------------------------------------- 2) selection dans B
a_rs = one(IA, "ReplicatedStorage")
a_sps = one(IA, "StarterPlayer/StarterPlayerScripts")
moves = []   # (root ref in B, new parent ref in A)
for p in ("ReplicatedStorage/Stations", "ReplicatedStorage/AnimationsTest_ASupprimer", "ReplicatedStorage/VoituresModeles"):
    moves.append((one(IB, p), a_rs))
moves.append((one(IB, "StarterPlayer/StarterPlayerScripts/StationsClient"), a_sps))
station_roots = []
for r in IB[one(IB, "Workspace/Toutes_Stations_Alignees")]["children"]:
    if IB[r]["cls"] == "Model":
        moves.append((r, a_rs_furn)); station_roots.append(r)
print("B: stations :", [IB[r]["name"] for r in station_roots])
keepB = set()
for r, _ in moves: keepB.update(descendants(IB, r))
print("B: instances conservees :", len(keepB))

# ---------------------------------------------------------------- 3) modifications dans B avant fusion : pivots des stations
def prop_elems(f, cid, name):
    for pr in f.props:
        if pr["cid"] == cid and pr["name"] == name: return pr["elems"]
    return None

def get(f, inst, r, name):
    i = inst[r]; el = prop_elems(f, i["cid"], name)
    return el[i["idx"]] if el is not None else None

def setp(f, inst, r, name, value):
    ok = C.set_prop(f, inst, r, name, value); assert ok, f"propriete {name} absente sur {inst[r]['cls']}"

for m in station_roots:
    mi = IB[m]
    socle = [c for c in mi["children"] if IB[c]["name"] == "Socle"]
    assert len(socle) == 1, mi["name"] + " : Socle introuvable"; socle = socle[0]
    # emprise des pieces visibles
    lo = [1e9]*3; hi = [-1e9]*3
    for d in descendants(IB, m):
        di = IB[d]
        if di["cls"] not in ("Part", "MeshPart", "UnionOperation", "WedgePart"): continue
        if di["name"] in ("Socle", "Voiture") or di["name"].startswith("Roue_"): continue
        tr = f32_dec(get(B, IB, d, "Transparency"))
        if tr >= 1: continue
        p, R = cf_dec(get(B, IB, d, "CFrame")); s = v3_dec(get(B, IB, d, "size"))
        h = (s[0]/2, s[1]/2, s[2]/2)
        for k in range(3):
            e = abs(R[k*3]*h[0]) + abs(R[k*3+1]*h[1]) + abs(R[k*3+2]*h[2])
            lo[k] = min(lo[k], p[k]-e); hi[k] = max(hi[k], p[k]+e)
    taille = (hi[0]-lo[0], hi[1]-lo[1], hi[2]-lo[2])
    ps, Rs = cf_dec(get(B, IB, socle, "CFrame"))
    droite = norm((Rs[0], 0.0, Rs[6]))                         # RightVector = colonne 0, projete a l'horizontale
    up = (0.0, 1.0, 0.0)
    Rb = from_columns(droite, up, cross(droite, up))
    centre = ((lo[0]+hi[0])/2, lo[1] + 0.1, (lo[2]+hi[2])/2)
    off = (0.0, 0.0, 0.0)                                      # pivot AU CENTRE de l'emprise (Furniture.Pivot = "centre")
    ppiv = (centre[0]+off[0], centre[1]+off[1], centre[2]+off[2])
    # PivotOffset = Socle.CFrame^-1 * Pivot
    RsT = mat_T(Rs)
    Roff = mat_mul(RsT, Rb)
    poff = mat_mul_vec(RsT, (ppiv[0]-ps[0], ppiv[1]-ps[1], ppiv[2]-ps[2]))
    setp(B, IB, socle, "PivotOffset", cf_enc(poff, Roff))
    # PrimaryPart = Socle, streaming atomique
    setp(B, IB, m, "PrimaryPart", socle)
    if prop_elems(B, mi["cid"], "ModelStreamingMode") is not None:
        setp(B, IB, m, "ModelStreamingMode", struct.pack(">I", 1))
    print(f"  {mi['name']:12s} emprise {taille[0]:.1f} x {taille[2]:.1f} (h {taille[1]:.1f})  pivot=({ppiv[0]:.1f},{ppiv[1]:.2f},{ppiv[2]:.1f})")

# ---------------------------------------------------------------- 4) sources des scripts
def set_source(f, inst, path, file):
    r = one(inst, path)
    assert prop_type(f, inst[r]["cid"], "Source") == 0x01
    src = open(SCRIPTS + file, "rb").read().replace(b"\r\n", b"\n")
    setp(f, inst, r, "Source", src); print("Source remplacee :", path, f"({len(src)} octets)")

set_source(A, IA, "ReplicatedStorage/Catalogue/Furniture", "Furniture.lua")
set_source(A, IA, "ServerScriptService/CarManager", "CarManager.lua")
set_source(A, IA, "ServerScriptService/DataManager", "DataManager.lua")
set_source(A, IA, "ServerScriptService/AdminCommands", "AdminCommands.lua")
set_source(A, IA, "ServerScriptService/PlotManager", "PlotManager.lua")
set_source(A, IA, "ServerScriptService/FunctionScript", "FunctionScript.lua")
set_source(A, IA, "ReplicatedStorage/Catalogue/Consommable", "Consommable.lua")
set_source(A, IA, "StarterGui/Main/MENUS/Supply/Supply", "Supply.lua")
set_source(A, IA, "StarterPlayer/StarterPlayerScripts/ClientSupply", "ClientSupply.lua")
set_source(A, IA, "StarterPlayer/StarterPlayerScripts/ClientStaff", "ClientStaff.lua")
set_source(A, IA, "StarterPlayer/StarterPlayerScripts/ClientCamera", "ClientCamera.lua")
set_source(A, IA, "StarterGui/Main/MENUS/Build/Build", "Build.lua")
set_source(A, IA, "ReplicatedStorage/Catalogue/Extension", "Extension.lua")
set_source(A, IA, "StarterPlayer/StarterPlayerScripts/ClientBuild", "ClientBuild.lua")
set_source(B, IB, "ReplicatedStorage/Stations/Client", "Client.lua")
set_source(B, IB, "ReplicatedStorage/Stations/Voiture", "Voiture.lua")

# ---------------------------------------------------------------- 5) fusion
M = C.RbxFile()
M.meta = list(A.meta)
M.sstr = list(A.sstr) + list(B.sstr)
sstr_off = len(A.sstr)
maxA = max(max(c["refs"]) for c in A.classes.values())
offB = maxA + 1
refmap = {r: r + offB for r in keepB}
new_parent = {r: np for r, np in moves}

def remap_elems(pr, keep_idx, src, is_b):
    typ = pr["typ"]; els = [pr["elems"][i] for i in keep_idx]
    if typ == 0x13:
        def m(x):
            if is_b: return refmap.get(x, -1)
            return -1 if x in delete else x
        els = [m(x) if x != -1 else -1 for x in els]
    elif typ == 0x1C and is_b:
        els = [x + sstr_off for x in els]
    elif typ == 0x22:
        def mc(e):
            if e[0] == 2:
                x = e[1]; nx = (refmap.get(x, -1) if is_b else (-1 if x in delete else x)) if x != -1 else -1
                return (2, nx)
            return e
        els = [mc(e) for e in els]
    return els

# A : classes filtrees
next_cid = 0
by_name = {}
for cid in A.class_order:
    c = A.classes[cid]
    keep_idx = [i for i, r in enumerate(c["refs"]) if r not in delete]
    if not keep_idx: print("A: classe vide supprimee :", c["name"]); continue
    nc = dict(name=c["name"], fmt=c["fmt"], refs=[c["refs"][i] for i in keep_idx],
              markers=(bytes(c["markers"][i] for i in keep_idx) if c["markers"] is not None else None))
    M.classes[next_cid] = nc; M.class_order.append(next_cid)
    props = [pr for pr in A.props if pr["cid"] == cid]
    for pr in props:
        M.props.append(dict(cid=next_cid, name=pr["name"], typ=pr["typ"], elems=remap_elems(pr, keep_idx, A, False)))
    by_name.setdefault(c["name"], []).append((next_cid, frozenset((pr["name"], pr["typ"]) for pr in props)))
    next_cid += 1

# B : classes ajoutees ou fusionnees
merged, separate = 0, 0
for cid in B.class_order:
    c = B.classes[cid]
    keep_idx = [i for i, r in enumerate(c["refs"]) if r in keepB]
    if not keep_idx: continue
    props = [pr for pr in B.props if pr["cid"] == cid]
    sig = frozenset((pr["name"], pr["typ"]) for pr in props)
    target = None
    for tcid, tsig in by_name.get(c["name"], []):
        if tsig == sig and M.classes[tcid]["fmt"] == c["fmt"]: target = tcid; break
    refs = [refmap[c["refs"][i]] for i in keep_idx]
    if target is not None:
        M.classes[target]["refs"].extend(refs)
        if c["markers"] is not None:
            M.classes[target]["markers"] += bytes(c["markers"][i] for i in keep_idx)
        for pr in props:
            for mp in M.props:
                if mp["cid"] == target and mp["name"] == pr["name"]:
                    mp["elems"].extend(remap_elems(pr, keep_idx, B, True)); break
        merged += 1
    else:
        if c["name"] in by_name: print("B: classe", c["name"], "gardee separee (proprietes differentes)"); separate += 1
        M.classes[next_cid] = dict(name=c["name"], fmt=c["fmt"], refs=refs,
                                   markers=(bytes(c["markers"][i] for i in keep_idx) if c["markers"] is not None else None))
        M.class_order.append(next_cid)
        for pr in props:
            M.props.append(dict(cid=next_cid, name=pr["name"], typ=pr["typ"], elems=remap_elems(pr, keep_idx, B, True)))
        by_name.setdefault(c["name"], []).append((next_cid, sig))
        next_cid += 1
print(f"B: classes fusionnees dans A : {merged}, separees : {separate}, nouvelles : {len(M.class_order) - len([1 for _ in A.class_order]) + 0}")

# parents
for k in A.prnt_order:
    if k in delete: continue
    M.prnt_order.append(k); M.parent[k] = A.parent[k]
for k in B.prnt_order:
    if k not in keepB: continue
    nk = refmap[k]
    if k in new_parent: M.parent[nk] = new_parent[k]
    else: M.parent[nk] = refmap[B.parent[k]]
    M.prnt_order.append(nk)

# ---------------------------------------------------------------- 5b) renumerotation compacte : Roblox exige 0 <= id < nombre d'instances
compact = {}
for cid in M.class_order:
    for r in M.classes[cid]["refs"]:
        compact[r] = len(compact)
for cid in M.class_order:
    M.classes[cid]["refs"] = [compact[r] for r in M.classes[cid]["refs"]]
for pr in M.props:
    if pr["typ"] == 0x13:
        pr["elems"] = [compact.get(x, -1) if x != -1 else -1 for x in pr["elems"]]
    elif pr["typ"] == 0x22:
        pr["elems"] = [(2, compact.get(e[1], -1) if e[1] != -1 else -1) if e[0] == 2 else e for e in pr["elems"]]
M.prnt_order = [compact[k] for k in M.prnt_order]
M.parent = {compact[k]: (compact[p] if p != -1 else -1) for k, p in M.parent.items()}
print("Renumerotation : identifiants 0 ..", len(compact) - 1)

# ---------------------------------------------------------------- 6) verification interne puis ecriture
allrefs = set()
for c in M.classes.values(): allrefs.update(c["refs"])
assert len(allrefs) == sum(len(c["refs"]) for c in M.classes.values()), "referents dupliques"
assert set(M.prnt_order) == allrefs, "PRNT incomplet"
assert allrefs == set(range(len(allrefs))), "identifiants non compacts"
for k, p in M.parent.items():
    assert p == -1 or p in allrefs, f"parent inconnu {p} pour {k}"
bad = 0
for pr in M.props:
    if pr["typ"] == 0x13:
        for x in pr["elems"]:
            if x != -1 and x not in allrefs: bad += 1
    assert len(pr["elems"]) == len(M.classes[pr["cid"]]["refs"]), pr["name"]
assert bad == 0, f"{bad} references cassees"
C.write(M, OUT)
print("ECRIT :", OUT, "instances :", len(allrefs), "classes :", len(M.class_order))
