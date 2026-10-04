"""Trace des voies sur la map V17 a partir du raster du bitume (map/bitume.png, 1 px = 1 stud, centre (1360,1360)).
Convention du jeu : conduite A GAUCHE (comme le trace de Thomas) ; voie de gauche = centre de chaussee + gauche(h)*7.5.
Repere Roblox : x = colonne - 1360, z = ligne - 1360 (Y vers le haut ; haut du plan = -Z).
"""
import json, math, os
import numpy as np
from PIL import Image

ICI = os.path.dirname(os.path.abspath(__file__))
MAPV = os.environ.get('MAPV', '17')
if MAPV == '21':
    # map V21 : chaussee de 50 studs (2 x 25, une file par sens a 12,5 de l'axe), demi-cote 1184,7, raster centre (1200, 1200)
    BITUME = np.array(Image.open(os.path.join(ICI, os.environ.get('MAPDIR', 'V21'), 'bitume57.png'))) > 0
    OFF = 1200
    DEMI = 1184.7
    VOIE = 12.5
    LARGEUR = 50.0
else:
    BITUME = np.array(Image.open(os.path.join(ICI, 'bitume57.png'))) > 0
    OFF = 1360
    DEMI = 1348.3
    VOIE = 7.5            # demi-largeur d'une voie (voie de 15)
    LARGEUR = 30.0

def bitume(x, z):
    i, j = int(round(z + OFF)), int(round(x + OFF))
    if 0 <= i < BITUME.shape[0] and 0 <= j < BITUME.shape[1]: return BITUME[i, j]
    return False

def gauche(h):  # vecteur unitaire a gauche du cap h (x, z)
    return np.array([h[1], -h[0]])
def droite(h):
    return -gauche(h)

def bords(p, n, maxd=60):
    """distances au bord du bitume depuis p le long de +n et -n"""
    dp = None; dm = None
    for d in np.arange(0.5, maxd, 0.5):
        q = p + n * d
        if dp is None and not bitume(q[0], q[1]): dp = d
        q = p - n * d
        if dm is None and not bitume(q[0], q[1]): dm = d
        if dp is not None and dm is not None: break
    return dp, dm

def tracer(depart, cap, pas=4.0, longueur_max=2500, largeur_attendue=None, tol=6):
    if largeur_attendue is None: largeur_attendue = LARGEUR
    """suit le centre d'une chaussee (largeur ~30) depuis 'depart' dans la direction 'cap' ; s'arrete au bord de la map
    ou quand la chaussee change de largeur (carrefour). Renvoie la liste des points centraux et le cap final."""
    p = np.array(depart, float); h = np.array(cap, float); h /= np.linalg.norm(h)
    pts = [p.copy()]
    parcouru = 0
    while parcouru < longueur_max:
        q = p + h * pas
        n = gauche(h)
        dp, dm = bords(q, n)
        if dp is None or dm is None: break
        larg = dp + dm
        if abs(larg - largeur_attendue) > tol: break
        c = q + n * (dp - dm) / 2      # recentre
        h2 = c - p; nh = np.linalg.norm(h2)
        if nh < 1e-6: break
        h = h2 / nh
        p = c; pts.append(p.copy()); parcouru += pas
        if abs(p[0]) > DEMI - 2 or abs(p[1]) > DEMI - 2: break
    return np.array(pts), h

def decaler(pts, cote=+1, d=VOIE):
    """decale une polyligne centrale vers la voie : cote=+1 gauche, -1 droite"""
    out = []
    for k in range(len(pts)):
        a = pts[max(k - 1, 0)]; b = pts[min(k + 1, len(pts) - 1)]
        h = b - a; h /= max(np.linalg.norm(h), 1e-9)
        out.append(pts[k] + gauche(h) * d * cote)
    return np.array(out)

def echantillonner(pts, espacement=35.0, courbure_max=0.12):
    """noeuds espaces de ~'espacement' studs, plus denses dans les virages ; chaque noeud = (x, z, cap)"""
    if len(pts) < 2: return []
    # longueur cumulee
    seg = np.linalg.norm(np.diff(pts, axis=0), axis=1); cum = np.concatenate([[0], np.cumsum(seg)])
    noeuds = []
    def cap_a(k):
        a = pts[max(k - 2, 0)]; b = pts[min(k + 2, len(pts) - 1)]; h = b - a; return h / max(np.linalg.norm(h), 1e-9)
    k = 0; noeuds.append((pts[0], cap_a(0))); dernier = 0
    while k < len(pts) - 1:
        k += 1
        # variation de cap depuis le dernier noeud
        h0 = noeuds[-1][1]; h1 = cap_a(k)
        ang = math.acos(max(-1, min(1, float(np.dot(h0, h1)))))
        if cum[k] - dernier >= espacement or (ang > courbure_max and cum[k] - dernier >= 10):
            noeuds.append((pts[k], h1)); dernier = cum[k]
    if cum[-1] - dernier > 8: noeuds.append((pts[-1], cap_a(len(pts) - 1)))
    return noeuds

def arc(centre, rayon, a0, a1, pas_deg=15):
    """points d'un arc de cercle (angles en degres, sens croissant = de +X vers +Z = horaire vu du dessus)"""
    n = max(2, int(abs(a1 - a0) / pas_deg) + 1)
    return np.array([[centre[0] + rayon * math.cos(math.radians(a)), centre[1] + rayon * math.sin(math.radians(a))] for a in np.linspace(a0, a1, n)])

def cap_arc(centre, p, sens=+1):
    """cap tangent a un cercle au point p, dans le sens des angles croissants (sens=+1)"""
    r = p - np.array(centre); t = np.array([-r[1], r[0]]) * sens
    return t / np.linalg.norm(t)

def tracer_bord_droit(depart, cap, pas=4.0, longueur_max=3000, voie=None, lissage=6):
    """suit la VOIE DE DROITE d'une chaussee en longeant son bord droit (bord du bitume - voie) : marche aussi quand la
    chaussee s'elargit (4 voies, terre-plein). depart = point sur la voie de droite ; renvoie les points de la voie."""
    voie = voie or VOIE
    p = np.array(depart, float); h = np.array(cap, float); h /= np.linalg.norm(h)
    pts = [p.copy()]; parcouru = 0
    while parcouru < longueur_max:
        q = p + h * pas
        n = droite(h)
        # distance au bord droit du bitume depuis q (vers la droite) ; si q est hors bitume, on revient vers la gauche
        d = None
        if bitume(q[0], q[1]):
            for k in np.arange(0.5, 60, 0.5):
                r = q + n * k
                if not bitume(r[0], r[1]): d = k; break
        else:
            for k in np.arange(0.5, 60, 0.5):
                r = q - n * k
                if bitume(r[0], r[1]): d = -k; break
        if d is None: break
        c = q + n * (d - voie)
        # lissage : on ne corrige qu'une fraction, pour eviter les zigzags du raster
        c = q + (c - q) / lissage
        h2 = c - p; nh = np.linalg.norm(h2)
        if nh < 1e-6: break
        h = h2 / nh
        p = c; pts.append(p.copy()); parcouru += pas
        if abs(p[0]) > DEMI - 2 or abs(p[1]) > DEMI - 2: break
    return np.array(pts), h
