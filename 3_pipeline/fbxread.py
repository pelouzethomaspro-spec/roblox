"""Lecteur FBX binaire minimal (v7.x) : arbre de noeuds + proprietes, tableaux zlib.
Usage : import fbxread ; racine = fbxread.lire(chemin) ; racine est un Noeud (nom, props, enfants).
"""
import struct, zlib
import numpy as np

class Noeud:
    __slots__ = ("nom", "props", "enfants")
    def __init__(self, nom, props, enfants):
        self.nom, self.props, self.enfants = nom, props, enfants
    def trouver(self, nom):
        return [e for e in self.enfants if e.nom == nom]
    def un(self, nom):
        for e in self.enfants:
            if e.nom == nom: return e
        return None
    def __repr__(self):
        return f"Noeud({self.nom!r}, {self.props!r}, {len(self.enfants)} enfants)"

_TYPES = {b"Y": ("<h", 2), b"C": ("<?", 1), b"I": ("<i", 4), b"F": ("<f", 4), b"D": ("<d", 8), b"L": ("<q", 8)}
_TABLEAUX = {b"f": np.float32, b"d": np.float64, b"l": np.int64, b"i": np.int32, b"b": np.bool_}

def _prop(d, o):
    t = d[o:o+1]; o += 1
    if t in _TYPES:
        fmt, n = _TYPES[t]
        return struct.unpack_from(fmt, d, o)[0], o + n
    if t in _TABLEAUX:
        n, enc, taille = struct.unpack_from("<III", d, o); o += 12
        brut = d[o:o+taille]; o += taille
        if enc == 1: brut = zlib.decompress(brut)
        return np.frombuffer(brut, dtype=_TABLEAUX[t], count=n), o
    if t in (b"S", b"R"):
        n = struct.unpack_from("<I", d, o)[0]; o += 4
        v = d[o:o+n]; o += n
        return (v.decode("utf-8", "replace") if t == b"S" else v), o
    raise ValueError(f"type de propriete inconnu {t!r} a {o}")

def _noeud(d, o, v):
    if v >= 7500:
        fin, nprops, lprops = struct.unpack_from("<QQQ", d, o); o += 24
    else:
        fin, nprops, lprops = struct.unpack_from("<III", d, o); o += 12
    lnom = d[o]; o += 1
    nom = d[o:o+lnom].decode("utf-8", "replace"); o += lnom
    if fin == 0:
        return None, o
    props = []
    for _ in range(nprops):
        p, o = _prop(d, o); props.append(p)
    enfants = []
    while o < fin:
        e, o = _noeud(d, o, v)
        if e is None: break
        enfants.append(e)
    return Noeud(nom, props, enfants), fin

def lire(chemin):
    d = open(chemin, "rb").read()
    assert d[:20] == b"Kaydara FBX Binary  "
    v = struct.unpack_from("<I", d, 23)[0]
    o = 27
    racine = Noeud("", [], [])
    while o < len(d):
        n, o = _noeud(d, o, v)
        if n is None: break
        racine.enfants.append(n)
    return racine
