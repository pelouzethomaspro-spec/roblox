import sys; sys.path.insert(0,'.')
import fbxscene, numpy as np
sc = fbxscene.Scene(sys.argv[1])
print("unite", sc.unite, "racines", len(sc.racines), "modeles", len(sc.modeles))
rows=[]
for m in sorted(sc.racines, key=lambda m: m.nom):
    bb = sc.bbox(m)
    if bb is None: 
        rows.append(f"{m.nom:45s} (vide) enfants={len(m.enfants)}"); continue
    mn, mx = bb[0]/sc.unite*100/100, bb[1]/sc.unite*100/100
    # unite: si 100 => cm ; on veut studs = metres? Dans ce projet 1 unite blender = 1 stud
    mn, mx = bb[0]/sc.unite, bb[1]/sc.unite
    sz = mx-mn
    ntri = sum(len(x.geometrie.triangles) for x in [m]+m.enfants if x.geometrie is not None)
    rows.append(f"{m.nom:45s} enf={len(m.enfants):3d} tris={ntri:7d} taille=({sz[0]:8.2f},{sz[1]:8.2f},{sz[2]:8.2f}) min=({mn[0]:8.2f},{mn[1]:8.2f},{mn[2]:8.2f}) max=({mx[0]:8.2f},{mx[1]:8.2f},{mx[2]:8.2f})")
print("\n".join(rows))
