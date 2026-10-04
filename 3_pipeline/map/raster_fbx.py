"""Raster du bitume (dessus de chaussee a Y = 0.57) et des trottoirs (Y = 1.27) depuis le FBX de la map.
Usage : python3 raster_fbx.py <fbx> <dossier_sortie> <OFF>  -> bitume57.png, trottoir127.png (1 px = 1 stud, centre (OFF, OFF))."""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import fbxscene, numpy as np
from PIL import Image, ImageDraw

fbx, out, OFF = sys.argv[1], sys.argv[2], int(sys.argv[3])
sc = fbxscene.Scene(fbx)
ECH = 100.0 if any(abs(v) > 5000 for m in sc.racines[:50] for v in (sc.bbox(m) or (np.zeros(3), np.zeros(3)))[1]) else 1.0
print("echelle", ECH)
N = 2 * OFF
def raster(y0, y1, exclure=()):
    im = Image.new('L', (N, N), 0); d = ImageDraw.Draw(im); n = 0
    for m in sc.modeles.values():
        if m.geometrie is None or any(m.nom.startswith(e) for e in exclure): continue
        v0 = sc.sommets_monde(m) / ECH
        # batiments / cours du coin NE : copies tournees de 90/180/270 deg autour du centre (InstallerMap, CFrame.Angles(0, a, 0))
        angles = (0, 90, 180, 270) if m.nom.startswith("Bloc_NE_") else (0,)
        for a in angles:
            v = v0.copy()
            if a:
                c, s_ = np.cos(np.radians(a)), np.sin(np.radians(a))
                x, z = v0[:, 0], v0[:, 2]
                v[:, 0] = x * c + z * s_; v[:, 2] = -x * s_ + z * c
            y = v[:, 1]
            ok = (y >= y0) & (y <= y1)
            for t in m.geometrie.triangles:
                if ok[t[0]] and ok[t[1]] and ok[t[2]]:
                    d.polygon([(v[i, 0] + OFF, v[i, 2] + OFF) for i in t], fill=255); n += 1
    print("triangles", y0, y1, n)
    return im
raster(0.55, 0.60, exclure=("Horizon", "Brume")).save(os.path.join(out, 'bitume57.png'))
raster(1.25, 1.29, exclure=("Horizon", "Brume")).save(os.path.join(out, 'trottoir127.png'))
