"""Scene FBX : graphe modeles / geometries / materiaux, transformations monde, bounding boxes.
Convention : on renvoie des coordonnees dans le repere FBX (Y haut, unite = cm si UnitScaleFactor 100 -> on divise par
UNITE pour passer en metres)."""
import numpy as np, math
import fbxread

def _p70(noeud):
    d = {}
    p70 = noeud.un("Properties70")
    if p70:
        for p in p70.enfants:
            if p.nom == "P" and p.props:
                d[p.props[0]] = p.props[4:]
    return d

def rot_euler_xyz(rx, ry, rz):
    """rotation FBX (degres, ordre XYZ : R = Rz * Ry * Rx) -> matrice 3x3"""
    cx, sx = math.cos(math.radians(rx)), math.sin(math.radians(rx))
    cy, sy = math.cos(math.radians(ry)), math.sin(math.radians(ry))
    cz, sz = math.cos(math.radians(rz)), math.sin(math.radians(rz))
    Rx = np.array([[1,0,0],[0,cx,-sx],[0,sx,cx]])
    Ry = np.array([[cy,0,sy],[0,1,0],[-sy,0,cy]])
    Rz = np.array([[cz,-sz,0],[sz,cz,0],[0,0,1]])
    return Rz @ Ry @ Rx

def mat4(R=np.eye(3), t=(0,0,0), s=(1,1,1)):
    M = np.eye(4)
    M[:3,:3] = R @ np.diag(s)
    M[:3,3] = t
    return M

class Modele:
    def __init__(self, uid, nom, type_):
        self.uid, self.nom, self.type = uid, nom, type_
        self.parent = None; self.enfants = []; self.geometrie = None; self.materiaux = []
        self.local = np.eye(4); self.geom_local = np.eye(4)
        self.lcl_t = (0,0,0); self.lcl_r = (0,0,0); self.lcl_s = (1,1,1)
    def monde(self):
        M = self.local
        p = self.parent
        while p is not None:
            M = p.local @ M; p = p.parent
        return M
    def chemin(self):
        n = [self.nom]; p = self.parent
        while p is not None: n.append(p.nom); p = p.parent
        return "/".join(reversed(n))

class Geometrie:
    def __init__(self, uid, nom, noeud):
        self.uid, self.nom = uid, nom
        v = noeud.un("Vertices").props[0]
        self.sommets = np.asarray(v, dtype=np.float64).reshape(-1, 3)
        idx = np.asarray(noeud.un("PolygonVertexIndex").props[0], dtype=np.int64)
        self.indices = idx
        # triangles (fan) : les polygones se terminent par un indice negatif (~i)
        tris = []; poly = []
        for i in idx:
            if i < 0:
                poly.append(~i)
                for k in range(1, len(poly)-1): tris.append((poly[0], poly[k], poly[k+1]))
                poly = []
            else: poly.append(i)
        self.triangles = np.array(tris, dtype=np.int64).reshape(-1, 3)
        # materiau par polygone
        self.mat_par_poly = None
        lm = noeud.un("LayerElementMaterial")
        if lm:
            mm = lm.un("MappingInformationType").props[0]
            if mm == "ByPolygon": self.mat_par_poly = np.asarray(lm.un("Materials").props[0])
            else: self.mat_par_poly = ("AllSame", int(np.asarray(lm.un("Materials").props[0])[0]))

class Scene:
    def __init__(self, chemin):
        r = fbxread.lire(chemin)
        self.racine = r
        gs = _p70(r.un("GlobalSettings"))
        self.unite = float(gs.get("UnitScaleFactor", [1.0])[0])   # 100 -> cm
        self.modeles = {}; self.geometries = {}; self.materiaux = {}; self.textures = {}
        objs = r.un("Objects")
        for e in objs.enfants:
            uid = e.props[0]; nom = e.props[1].split("\x00")[0] if isinstance(e.props[1], str) else str(e.props[1])
            if e.nom == "Model":
                m = Modele(uid, nom, e.props[2]); p = _p70(e)
                m.lcl_t = tuple(p.get("Lcl Translation", [0,0,0])[:3]); m.lcl_r = tuple(p.get("Lcl Rotation", [0,0,0])[:3]); m.lcl_s = tuple(p.get("Lcl Scaling", [1,1,1])[:3])
                pre = p.get("PreRotation"); post = p.get("PostRotation")
                rp = p.get("RotationPivot", [0,0,0])[:3]; sp = p.get("ScalingPivot", [0,0,0])[:3]
                ro = p.get("RotationOffset", [0,0,0])[:3]; so = p.get("ScalingOffset", [0,0,0])[:3]
                R = rot_euler_xyz(*m.lcl_r)
                if pre is not None: R = rot_euler_xyz(*pre[:3]) @ R
                if post is not None: R = R @ np.linalg.inv(rot_euler_xyz(*post[:3]))
                T = mat4(t=m.lcl_t); Roff = mat4(t=ro); Rp = mat4(t=rp); Rpi = mat4(t=-np.array(rp))
                Soff = mat4(t=so); Sp = mat4(t=sp); Spi = mat4(t=-np.array(sp))
                m.local = T @ Roff @ Rp @ mat4(R=R) @ Rpi @ Soff @ Sp @ mat4(s=m.lcl_s) @ Spi
                gt = p.get("GeometricTranslation", [0,0,0])[:3]; gr = p.get("GeometricRotation", [0,0,0])[:3]; gsc = p.get("GeometricScaling", [1,1,1])[:3]
                m.geom_local = mat4(rot_euler_xyz(*gr), gt, gsc)
                self.modeles[uid] = m
            elif e.nom == "Geometry" and e.props[2] == "Mesh":
                self.geometries[uid] = Geometrie(uid, nom, e)
            elif e.nom == "Material":
                p = _p70(e); self.materiaux[uid] = {"nom": nom, "diffuse": tuple(p.get("DiffuseColor", [0.8,0.8,0.8])[:3]), "textures": []}
            elif e.nom == "Texture":
                p = e.un("RelativeFilename"); self.textures[uid] = (nom, p.props[0] if p else "")
        for c in r.un("Connections").enfants:
            if c.props[0] == "OO":
                a, b = c.props[1], c.props[2]
                if a in self.modeles and b in self.modeles:
                    self.modeles[a].parent = self.modeles[b]; self.modeles[b].enfants.append(self.modeles[a])
                elif a in self.geometries and b in self.modeles:
                    self.modeles[b].geometrie = self.geometries[a]
                elif a in self.materiaux and b in self.modeles:
                    self.modeles[b].materiaux.append(self.materiaux[a])
            elif c.props[0] == "OP" and c.props[1] in self.textures and c.props[2] in self.materiaux:
                self.materiaux[c.props[2]]["textures"].append((c.props[3], self.textures[c.props[1]]))
        self.racines = [m for m in self.modeles.values() if m.parent is None]

    def sommets_monde(self, m):
        """sommets du mesh de m dans le repere monde FBX, en unites FBX natives"""
        if m.geometrie is None: return None
        M = m.monde() @ m.geom_local
        v = m.geometrie.sommets
        return (M[:3,:3] @ v.T).T + M[:3,3]

    def bbox(self, m):
        """bbox monde de m et de toute sa descendance"""
        pts = []
        pile = [m]
        while pile:
            x = pile.pop(); pile.extend(x.enfants)
            s = self.sommets_monde(x)
            if s is not None and len(s): pts.append(s)
        if not pts: return None
        p = np.vstack(pts)
        return p.min(0), p.max(0)
