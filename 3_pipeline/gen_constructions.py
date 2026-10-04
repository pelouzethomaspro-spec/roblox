"""Genere, a partir du FBX PACK_10_3, tout ce que le jeu doit connaitre des constructions :
  gen/constructions.json      : inventaire (categorie, famille, matiere, label, bbox, pivot, sous-pieces, couleurs)
  gen/Sol.rbxmx, Mur.rbxmx, Plafond.rbxmx, Furniture_decor.rbxmx : modeles provisoires (boites colorees aux vraies
                                dimensions, pivot definitif) a inserer dans ReplicatedStorage/<categorie>
  gen/Catalogue_Sol.lua, Catalogue_Mur.lua, Catalogue_Plafond.lua, Furniture_decor.lua : entrees de catalogue
  gen/Cartes.lua              : table CARTES pour l'interface (cartes du menu Build -> variantes)
  gen/Installer_Constructions.lua : script barre de commande Studio remplacant les boites par les vrais meshes importes
Convention d'unite : 1 unite FBX = 1 stud (sols 10 x 10, murs 10 x 16 x 1).
"""
import json, io, os, re, math
import numpy as np
from PIL import Image
import fbxread, fbxscene

FBX = '/root/.claude/uploads/c725c065-cb20-5868-b02f-9a238e45d840/8f15f63b-PACK_10_3_1.fbx'
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'gen')
os.makedirs(OUT, exist_ok=True)

# hauteurs du jeu (plot-local) : dessus du sol a +0.5 ; meubles poses a +0.616 ; plafond = sommet des murs
SOL_DESSUS = 0.5
MUR_HAUTEUR = 16.0
PLAFOND_Y = SOL_DESSUS + MUR_HAUTEUR          # 16.5 : les toits se posent au sommet des murs
MEUBLE_Y = 0.616

IGNORES = {"CaisseAuto", "CaisseTapis", "pile_cartons", "rayonnage_plein",   # deja dans le jeu (Furniture 1-4)
           "toit_boutique",                                                  # assemblage de demonstration (34 studs)
           "rebord", "rebord_angle"}                                         # garnitures de toit, pas des cases

MATIERES = {"brique": "Brique", "clin": "Bardage", "crepi": "Crépi", "enduit": "Enduit", "pierre": "Pierre"}

FAMILLES_MUR = {   # prefixe FBX -> (label, prix)
    "mur_plein": ("Mur plein", 15), "mur_muret": ("Muret", 8), "mur_vitrine": ("Vitrine", 45),
    "mur_fenetre_simple": ("Fenêtre simple", 30), "mur_fenetre_haute": ("Fenêtre haute", 30),
    "mur_fenetre_grille": ("Fenêtre grillagée", 32), "mur_fenetre_arche_croix": ("Fenêtre arche à croisillons", 38),
    "mur_fenetre_arche_pleine": ("Fenêtre arche pleine", 36), "mur_fenetre_arche_vitrine": ("Fenêtre arche vitrine", 42),
    "mur_baie_arche": ("Baie en arche", 40), "mur_baie_arche_nue": ("Baie en arche nue", 34),
    "mur_baie_barreaudee": ("Baie barreaudée", 36), "mur_baie_croisee": ("Baie croisée", 36),
    "mur_baie_grille": ("Baie grillagée", 36), "mur_baie_simple": ("Baie simple", 34), "mur_deux_baies": ("Deux baies", 44),
    "mur_porte": ("Ouverture", 20), "mur_porte_blanche": ("Porte blanche", 50), "mur_porte_bois": ("Porte bois", 50),
    "mur_porte_deco": ("Porte décorée", 60), "mur_porte_double_bois": ("Double porte bois", 65),
    "mur_porte_double_verte": ("Double porte verte", 65), "mur_porte_double_vitree": ("Double porte vitrée", 70),
    "mur_porte_garage": ("Porte de garage", 80), "mur_porte_imposte": ("Porte à imposte", 55),
    "mur_porte_pleine": ("Porte pleine", 50), "mur_porte_service_bois": ("Porte de service bois", 45),
    "mur_porte_service_verte": ("Porte de service verte", 45), "mur_porte_service_vitree": ("Porte de service vitrée", 50),
    "mur_porte_simple_blanche": ("Porte simple blanche", 40), "mur_porte_simple_bois": ("Porte simple bois", 40),
    "mur_porte_simple_deco": ("Porte simple décorée", 48), "mur_porte_simple_pleine": ("Porte simple pleine", 40),
    "mur_porte_simple_verre_sombre": ("Porte simple verre sombre", 48), "mur_porte_verre_sombre": ("Porte verre sombre", 58),
}
SOLS = {  # nom -> (label, prix, famille)
    "sol_parquet_clair": ("Parquet clair", 10, "parquets"), "sol_chene_dore": ("Chêne doré", 12, "parquets"),
    "sol_chevron": ("Chevron", 14, "parquets"), "sol_parquet_fonce": ("Parquet foncé", 12, "parquets"),
    "sol_planches_larges": ("Planches larges", 12, "parquets"), "sol_chene_rustique": ("Chêne rustique", 12, "parquets"),
    "sol_chevron_pale": ("Chevron pâle", 14, "parquets"), "sol_parquet_chevron": ("Parquet chevron", 14, "parquets"),
    "sol_parquet_larges": ("Parquet lames larges", 12, "parquets"), "sol_parquet_rouge": ("Parquet rouge", 12, "parquets"),
    "sol_parquet_vieilli": ("Parquet vieilli", 10, "parquets"), "sol_planches_fines": ("Planches fines", 10, "parquets"),
    "sol_batons_rompus": ("Bâtons rompus", 16, "parquets"), "sol_echelle": ("Parquet à l'anglaise", 12, "parquets"),
    "sol_carrelage_gris": ("Carrelage gris", 15, "carrelages"), "sol_damier": ("Damier", 18, "carrelages"),
    "sol_marbre": ("Marbre", 30, "carrelages"), "sol_terrazzo": ("Terrazzo", 22, "carrelages"),
    "sol_mosaique": ("Mosaïque", 24, "carrelages"), "sol_ardoise": ("Ardoise", 20, "carrelages"), "sol_moquette": ("Moquette", 12, "carrelages"),
    "sol_beton": ("Béton", 5, "exterieur"), "sol_paves": ("Pavés", 8, "exterieur"), "sol_goudron": ("Goudron", 5, "exterieur"),
    "sol_graviers": ("Graviers", 6, "exterieur"), "sol_galets": ("Galets", 8, "exterieur"), "sol_briques": ("Briques", 9, "exterieur"),
    "sol_route": ("Route", 6, "exterieur"),
}
TOITS = {  # nom -> (label, prix, famille)
    "toit_plat": ("Toit plat", 10, "toits"), "toit_membrane": ("Membrane", 12, "toits"), "toit_clair": ("Toit clair", 14, "toits"),
    "toit_bac": ("Bac acier", 18, "toits"), "toit": ("Tuiles", 25, "toits"),
    "toit_bord": ("Bord gravier", 16, "toits_bords"), "toit_clair_bord": ("Bord clair", 18, "toits_bords"),
    "toit_bac_bord_x": ("Bord bac acier", 22, "toits_bords"), "toit_bac_bord_y": ("Bord bac acier (travers)", 22, "toits_bords"),
    "toit_angle": ("Angle gravier", 18, "toits_angles"), "toit_clair_angle": ("Angle clair", 20, "toits_angles"),
    "toit_bac_angle": ("Angle bac acier", 24, "toits_angles"), "toit_bac_angle2": ("Angle bac acier 2", 24, "toits_angles"),
}
DECOR = {  # nom -> (label, prix, famille)
    "barriere_arceau": ("Barrière arceau", 25, "barrieres"), "barriere_grille": ("Barrière grille", 20, "barrieres"),
    "barriere_potelets": ("Potelets", 20, "barrieres"), "barriere_rails": ("Barrière rails", 20, "barrieres"),
    "barriere_verre": ("Barrière verre", 35, "barrieres"),
    "buisson_boule": ("Buisson boule", 15, "plantes"), "haie_bloc": ("Haie", 20, "plantes"), "colonne_taillee": ("Colonne taillée", 45, "plantes"),
    "jardiniere_fleurs": ("Jardinière fleurie", 40, "plantes"), "jardiniere_longue": ("Jardinière longue", 45, "plantes"),
    "pot_buisson": ("Pot buisson", 25, "plantes"), "pot_cactus": ("Pot cactus", 25, "plantes"),
    "topiaire_boule": ("Topiaire boule", 35, "plantes"), "topiaire_cone": ("Topiaire cône", 35, "plantes"),
    "carton_petit": ("Petit carton", 30, "cartons"), "carton_moyen": ("Carton moyen", 45, "cartons"), "carton_grand": ("Grand carton", 60, "cartons"),
    "rayonnage_vide": ("Rayonnage vide", 600, "etagere"),
}
STOCKAGE = {"carton_petit": 10, "carton_moyen": 20, "carton_grand": 30, "rayonnage_vide": 250}

# ----------------------------------------------------------------------------------------------------------------------
scene = fbxscene.Scene(FBX)
racine = scene.racine
objs = racine.un('Objects')
mats = {e.props[0]: e for e in objs.enfants if e.nom == 'Material'}
texs = {e.props[0]: e for e in objs.enfants if e.nom == 'Texture'}
vids = {e.props[0]: e for e in objs.enfants if e.nom == 'Video'}
tex2vid, mat2tex = {}, {}
for c in racine.un('Connections').enfants:
    if c.props[0] == 'OO' and c.props[1] in vids and c.props[2] in texs: tex2vid[c.props[2]] = c.props[1]
    if c.props[0] == 'OP' and c.props[1] in texs and c.props[2] in mats: mat2tex.setdefault(c.props[2], []).append((c.props[3], c.props[1]))

_cache = {}
def couleur_materiau(uid):
    """couleur moyenne de la texture diffuse (0-255) et transparence (0-1)"""
    if uid in _cache: return _cache[uid]
    rgb, transp = (200, 200, 200), 0.0
    for prop, tuid in mat2tex.get(uid, []):
        vid = vids.get(tex2vid.get(tuid))
        cont = vid.un('Content') if vid else None
        if prop == 'DiffuseColor' and cont and cont.props:
            try:
                im = Image.open(io.BytesIO(cont.props[0])).convert('RGBA').resize((32, 32))
                a = np.asarray(im, dtype=np.float64)
                w = a[..., 3:4] / 255.0
                moy = (a[..., :3] * w).sum((0, 1)) / max(w.sum(), 1e-6)
                rgb = tuple(int(round(v)) for v in moy)
                if w.mean() < 0.9: transp = float(1 - w.mean())
            except Exception as e:
                print('texture illisible', e)
        elif prop == 'TransparencyFactor':
            transp = max(transp, 0.55)
    _cache[uid] = (rgb, transp); return _cache[uid]

nom_mat = {uid: e.props[1].split('\x00')[0] for uid, e in mats.items()}
mat_uid_of = {}
for m in scene.modeles.values():
    pass

def categorie_de(nom):
    if nom in IGNORES: return None
    if nom.startswith('sol_'): return 'Sol'
    if nom.startswith('mur_'): return 'Mur'
    if nom.startswith('toit'): return 'Plafond'
    return 'Furniture'

def famille_mur(nom):
    """prefixe de famille et matiere : 'mur_porte_bois_brique' -> ('mur_porte_bois', 'brique')"""
    for mat in MATIERES:
        if nom.endswith('_' + mat):
            return nom[:-len(mat) - 1], mat
    return nom, None

inventaire = []
for m in sorted(scene.racines, key=lambda m: m.nom):
    cat = categorie_de(m.nom)
    if cat is None: continue
    T = np.array(m.lcl_t)
    pieces = []
    for e in m.enfants:
        if e.geometrie is None: continue
        v = scene.sommets_monde(e) - T
        lo, hi = v.min(0), v.max(0)
        muid = None
        # retrouve l'uid du materiau via la connexion (les objets Modele portent la liste des dicts materiaux)
        for c in racine.un('Connections').enfants:
            if c.props[0] == 'OO' and c.props[2] == e.uid and c.props[1] in mats: muid = c.props[1]; break
        rgb, transp = couleur_materiau(muid) if muid is not None else ((200, 200, 200), 0.0)
        suffixe = e.nom[len(m.nom) + 1:] if e.nom.startswith(m.nom + '_') else e.nom
        pieces.append(dict(nom=e.nom, suffixe=suffixe, min=lo.round(4).tolist(), max=hi.round(4).tolist(), tris=int(len(e.geometrie.triangles)),
                           materiau=nom_mat.get(muid, '?'), rgb=rgb, transparence=round(transp, 2)))
    if not pieces: continue
    allmin = np.min([p['min'] for p in pieces], 0); allmax = np.max([p['max'] for p in pieces], 0)
    taille = allmax - allmin
    # piece principale : la plus grande empreinte au sol (dalle / pan de mur)
    def aire(p): d = np.array(p['max']) - np.array(p['min']); return d[0] * d[2] + d[0] * d[1] + d[1] * d[2]
    def aire_sol(p): d = np.array(p['max']) - np.array(p['min']); return d[0] * d[2]
    if cat in ('Sol', 'Plafond'):
        # dalle = la piece la plus basse parmi celles qui couvrent l'essentiel de la case (les acroteres sont au-dessus)
        maxi = max(aire_sol(p) for p in pieces)
        principale = min((p for p in pieces if aire_sol(p) >= 0.5 * maxi), key=lambda p: p['min'][1])
    else:
        principale = max(pieces, key=aire)
    pmin, pmax = np.array(principale['min']), np.array(principale['max'])
    entree = dict(nom=m.nom, categorie=cat, pieces=pieces, min=allmin.round(4).tolist(), max=allmax.round(4).tolist(), taille=taille.round(4).tolist(), principale=principale['nom'])
    if cat == 'Sol':
        label, prix, fam = SOLS[m.nom]
        entree.update(label=label, prix=prix, famille=fam, matiere=None)
        cx, cz = (pmin[0] + pmax[0]) / 2, (pmin[2] + pmax[2]) / 2
        entree['pivot'] = dict(pos=[cx, float(pmax[1]) - SOL_DESSUS, cz], rot='identite')    # dessus du sol a +0.5
        entree['masque'] = [[1]]
    elif cat == 'Mur':
        fam, mat = famille_mur(m.nom)
        label, prix = FAMILLES_MUR[fam]
        entree.update(label=label, prix=prix, famille=fam, matiere=mat, matiere_label=MATIERES.get(mat))
        # pan de mur : x 0..10 (longueur), z -0.5..0.5 (epaisseur), y 0..h ; face avant = -Z (poignees, decor)
        cx, cz = (pmin[0] + pmax[0]) / 2, (pmin[2] + pmax[2]) / 2
        # pivot 5 studs derriere le mur (cote +Z), au ras du sol ; axe X local = vers l'avant (-Z), Z local = longueur (+X)
        entree['pivot'] = dict(pos=[cx, float(pmin[1]) - SOL_DESSUS, cz + 5.0], rot='mur')
        entree['hauteur'] = float(pmax[1] - pmin[1])
    elif cat == 'Plafond':
        label, prix, fam = TOITS[m.nom]
        entree.update(label=label, prix=prix, famille=fam, matiere=None)
        cx, cz = (pmin[0] + pmax[0]) / 2, (pmin[2] + pmax[2]) / 2
        entree['pivot'] = dict(pos=[cx, float(allmin[1]), cz], rot='identite')
        entree['masque'] = [[1]]
    else:
        label, prix, fam = DECOR[m.nom]
        entree.update(label=label, prix=prix, famille=fam, matiere=None)
        nx, nz = max(1, int(round(taille[0] / 10))), max(1, int(round(taille[2] / 10)))
        # 1 case : pivot au centre de l'empreinte ; plusieurs cases : centre de la premiere case (x min, z min), le
        # modele s'etend vers +X / +Z (convention des caisses : masque tourne par le serveur)
        if nx == 1 and nz == 1:
            cx, cz = (allmin[0] + allmax[0]) / 2, (allmin[2] + allmax[2]) / 2
        else:
            cx = allmin[0] + 5.0 if nx > 1 else (allmin[0] + allmax[0]) / 2
            cz = allmin[2] + 5.0 if nz > 1 else (allmin[2] + allmax[2]) / 2
        entree['pivot'] = dict(pos=[cx, float(allmin[1]) + (MEUBLE_Y - SOL_DESSUS), cz], rot='identite')   # bas du meuble sur le sol
        entree['masque'] = [[1] * nx for _ in range(nz)]
        if m.nom in STOCKAGE: entree['stockage'] = STOCKAGE[m.nom]
    inventaire.append(entree)

json.dump(inventaire, open(os.path.join(OUT, 'constructions.json'), 'w'), indent=1, ensure_ascii=False)
from collections import Counter
print('constructions :', Counter(e['categorie'] for e in inventaire))

# ----------------------------------------------------------------------------------------------------------------------
# modeles provisoires (.rbxmx) : une boite par sous-piece, aux dimensions exactes, couleur moyenne de la texture
# ----------------------------------------------------------------------------------------------------------------------
def esc(s): return s.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')

def cframe_xml(nom, pos, R):
    r = R.flatten()
    ouvre = f'<CoordinateFrame name="{nom}">' if nom else '<CFrame>'
    ferme = '</CoordinateFrame>' if nom else '</CFrame>'
    return (f'{ouvre}<X>{pos[0]:.5f}</X><Y>{pos[1]:.5f}</Y><Z>{pos[2]:.5f}</Z>'
            + ''.join(f'<R{i//3}{i%3}>{r[i]:.6f}</R{i//3}{i%3}>' for i in range(9)) + ferme)

ROT_MUR = np.array([[0, 0, 1], [0, 1, 0], [-1, 0, 0]], dtype=float)   # colonnes = axes X, Y, Z locaux : X=(0,0,-1) Y=(0,1,0) Z=(1,0,0)
def rot_de(e):
    return ROT_MUR if e['pivot']['rot'] == 'mur' else np.eye(3)

def part_xml(nom, pos, size, rgb, transp, anchored=True, collide=True):
    return f'''<Item class="Part"><Properties>
<string name="Name">{esc(nom)}</string>
{cframe_xml("CFrame", pos, np.eye(3))}
<Vector3 name="size"><X>{size[0]:.4f}</X><Y>{size[1]:.4f}</Y><Z>{size[2]:.4f}</Z></Vector3>
<Color3uint8 name="Color3uint8">{(0xFF << 24) | (rgb[0] << 16) | (rgb[1] << 8) | rgb[2]}</Color3uint8>
<token name="Material">{1568 if transp > 0 else 272}</token>
<float name="Transparency">{transp:.2f}</float>
<bool name="Anchored">{"true" if anchored else "false"}</bool>
<bool name="CanCollide">{"true" if collide else "false"}</bool>
<bool name="CanQuery">true</bool>
<bool name="CanTouch">false</bool>
<bool name="CastShadow">true</bool>
<token name="TopSurface">0</token><token name="BottomSurface">0</token>
<token name="formFactorRaw">1</token><token name="shape">1</token>
</Properties></Item>'''

def modele_xml(e):
    piv = np.array(e['pivot']['pos']); R = rot_de(e)
    parts = []
    for p in e['pieces']:
        lo, hi = np.array(p['min']), np.array(p['max'])
        c = (lo + hi) / 2; s = np.maximum(hi - lo, 0.05)
        transp = p['transparence'] if p['transparence'] > 0 else 0.0
        collide = transp == 0
        parts.append(part_xml(p['nom'], c, s, p['rgb'], transp, True, collide))
    attrs = ''
    return f'''<Item class="Model"><Properties>
<string name="Name">{esc(e['nom'])}</string>
<token name="ModelStreamingMode">1</token>
<OptionalCoordinateFrame name="WorldPivotData">{cframe_xml(None, piv, R)}</OptionalCoordinateFrame>
<bool name="Provisoire_">true</bool>
</Properties>
{''.join(parts)}
</Item>'''

# note : la propriete Provisoire_ n'existe pas -> retiree par coerce() ; on marque plutot via un attribut : plus simple,
# on ajoute une StringValue "Provisoire" dans le modele (l'installateur la cherche)
def modele_xml2(e):
    x = modele_xml(e).replace('<bool name="Provisoire_">true</bool>\n', '')
    marque = '<Item class="StringValue"><Properties><string name="Name">Provisoire</string><string name="Value">boite en attente du mesh importe</string></Properties></Item>'
    return x.replace('</Item>\n</Item>', '</Item>\n' + marque + '\n</Item>') if x.rstrip().endswith('</Item>\n</Item>') else x[:-len('</Item>')] + marque + '</Item>'

for cat, fichier in (('Sol', 'Sol.rbxmx'), ('Mur', 'Mur.rbxmx'), ('Plafond', 'Plafond.rbxmx'), ('Furniture', 'Furniture_decor.rbxmx')):
    items = [modele_xml2(e) for e in inventaire if e['categorie'] == cat]
    open(os.path.join(OUT, fichier), 'w').write('<roblox version="4">\n' + '\n'.join(items) + '\n</roblox>\n')
    print(fichier, len(items), 'modeles')

# ----------------------------------------------------------------------------------------------------------------------
# catalogues Lua
# ----------------------------------------------------------------------------------------------------------------------
def lua_str(s): return '"' + s.replace('\\', '\\\\').replace('"', '\\"') + '"'

def catalogue_lua(cat, var):
    lignes = [f'--[[ Catalogue {var} : genere depuis le pack de constructions PACK_10_3 (1 case = 10 studs).',
              '\tNom = libelle affiche ; Famille / Matiere servent au menu de construction ; Prix en $ (debite par le serveur).', ']]',
              f'local {var} = {{']
    for e in inventaire:
        if e['categorie'] != cat: continue
        extra = ''
        if e.get('matiere_label'): extra += f', Matiere = {lua_str(e["matiere_label"])}'
        if e.get('hauteur'): extra += f', Hauteur = {e["hauteur"]:.2f}'
        lignes.append(f'\t[{lua_str(e["nom"])}] = {{ Nom = {lua_str(e["label"])}, Prix = {e["prix"]}, Famille = {lua_str(e["famille"])}{extra} }},')
    lignes.append('}'); lignes.append(f'return {var}')
    return '\n'.join(lignes) + '\n'

open(os.path.join(OUT, 'Catalogue_Sol.lua'), 'w').write(catalogue_lua('Sol', 'Sol'))
open(os.path.join(OUT, 'Catalogue_Mur.lua'), 'w').write(catalogue_lua('Mur', 'Mur'))
open(os.path.join(OUT, 'Catalogue_Plafond.lua'), 'w').write(catalogue_lua('Plafond', 'Plafond'))

def masque_lua(m):
    return '{' + ', '.join('{' + ', '.join(str(v) for v in ligne) + '}' for ligne in m) + '}'
lignes = ['\t-- ------------------------------------------------------------------ decor (pack de constructions PACK_10_3)']
for e in inventaire:
    if e['categorie'] != 'Furniture': continue
    piv = 'centre' if (len(e['masque']) == 1 and len(e['masque'][0]) == 1) else None
    extra = f', Stockage = {e["stockage"]}' if e.get('stockage') else ''
    pv = ', Pivot = "centre"' if piv else ''
    lignes.append(f'\t[{lua_str(e["nom"])}] = {{ Nom = {lua_str(e["label"])}, Prix = {e["prix"]}, Famille = {lua_str(e["famille"])}, Masque = {masque_lua(e["masque"])}{pv}{extra} }},')
open(os.path.join(OUT, 'Furniture_decor.lua'), 'w').write('\n'.join(lignes) + '\n')

# ----------------------------------------------------------------------------------------------------------------------
# cartes du menu Build : famille -> liste ordonnee de variantes (les 5 matieres dans l'ordre des sprites de Thomas)
# ----------------------------------------------------------------------------------------------------------------------
ORDRE_MAT = ['brique', 'clin', 'crepi', 'enduit', 'pierre']
cartes = {}   # id carte -> (categorie, [noms])
# sols : cartes existantes (sprites) puis extras dans la meme carte
ordre_sol = {"sol_parquets": ["sol_parquet_clair", "sol_chene_dore", "sol_chevron", "sol_parquet_fonce", "sol_planches_larges"],
             "sol_carrelages": ["sol_carrelage_gris", "sol_damier", "sol_marbre", "sol_terrazzo", "sol_mosaique"],
             "sol_exterieur": ["sol_beton", "sol_paves", "sol_goudron", "sol_graviers", "sol_galets"]}
fam2carte = {"parquets": "sol_parquets", "carrelages": "sol_carrelages", "exterieur": "sol_exterieur"}
for cid, noms in ordre_sol.items():
    fam = [k for k, v in fam2carte.items() if v == cid][0]
    extras = [e['nom'] for e in inventaire if e['categorie'] == 'Sol' and e['famille'] == fam and e['nom'] not in noms]
    cartes[cid] = ('Sol', noms + sorted(extras))
# murs : cartes de Thomas
cartes_mur = {"murs_plein": "mur_plein", "murs_vitrine": "mur_vitrine", "murs_muret": "mur_muret", "fen_simple": "mur_fenetre_simple",
              "fen_arche": "mur_baie_arche", "porte_bois": "mur_porte_bois", "porte_garage": "mur_porte_garage", "porte_vitree": "mur_porte_double_vitree"}
def variantes_mur(fam): return [f'{fam}_{m}' for m in ORDRE_MAT if any(e['nom'] == f'{fam}_{m}' for e in inventaire)]
for cid, fam in cartes_mur.items(): cartes[cid] = ('Mur', variantes_mur(fam))
familles_restantes = sorted({e['famille'] for e in inventaire if e['categorie'] == 'Mur'} - set(cartes_mur.values()), key=lambda f: list(FAMILLES_MUR).index(f))
cartes_mur_extra = []
for fam in familles_restantes:
    cid = 'x_' + fam
    cartes[cid] = ('Mur', variantes_mur(fam)); cartes_mur_extra.append((cid, FAMILLES_MUR[fam][0]))
# toits
cartes["toits"] = ('Plafond', ["toit_plat", "toit_membrane", "toit_clair", "toit_bac", "toit"])
cartes["x_toits_bords"] = ('Plafond', [e['nom'] for e in inventaire if e.get('famille') == 'toits_bords'])
cartes["x_toits_angles"] = ('Plafond', [e['nom'] for e in inventaire if e.get('famille') == 'toits_angles'])
# mobilier
cartes["stations_energie"] = ('Furniture', ["E2_Barils", "E3_Pompes", "E4_Bornes"])
cartes["stations_lavage"] = ('Furniture', ["L2_Seaux", "L3_Karcher", "L4_Rouleaux"])
cartes["stations_pieces"] = ('Furniture', ["E7_Teinte", "E6_Peinture", "E5_Pneus"])
cartes["caisses"] = ('Furniture', ["2", "1"])
cartes["etagere"] = ('Furniture', ["4", "rayonnage_vide"])
cartes["carton"] = ('Furniture', ["3", "carton_petit", "carton_moyen", "carton_grand"])
cartes["x_barrieres"] = ('Furniture', [e['nom'] for e in inventaire if e.get('famille') == 'barrieres'])
cartes["x_plantes"] = ('Furniture', [e['nom'] for e in inventaire if e.get('famille') == 'plantes'])

CARTES_EXTRA = {  # cartes sans sprite : id -> (onglet, titre)
    "x_toits_bords": ("toit", "Toit · bords"), "x_toits_angles": ("toit", "Toit · angles"),
    "x_barrieres": ("mobilier", "Barrières"), "x_plantes": ("mobilier", "Plantes & décor"),
}
for cid, titre in cartes_mur_extra: CARTES_EXTRA[cid] = ("murs", titre)

lignes = ['\t-- CARTES : carte du menu Build -> {categorie du catalogue, {variante 1, variante 2, ...}}',
          '\t-- Les premieres variantes correspondent aux images (sprites) de la carte ; les suivantes sont montrees en 3D.',
          '\tlocal CARTES = {']
for cid, (cat, noms) in cartes.items():
    lignes.append(f'\t\t{cid} = {{{lua_str(cat)}, {{{", ".join(lua_str(n) for n in noms)}}}}},')
lignes.append('\t}')
lignes.append('\t-- cartes supplementaires (pas de sprite : apercu 3D) : id -> {onglet, titre}')
lignes.append('\tlocal CARTES_EXTRA = {')
for cid, (onglet, titre) in CARTES_EXTRA.items():
    lignes.append(f'\t\t{{{lua_str(cid)}, {lua_str(onglet)}, {lua_str(titre)}}},')
lignes.append('\t}')
open(os.path.join(OUT, 'Cartes.lua'), 'w').write('\n'.join(lignes) + '\n')
print('cartes :', len(cartes), 'dont extra', len(CARTES_EXTRA))
print('variantes murs sans sprite :', sum(len(cartes[c][1]) for c, _ in cartes_mur_extra))
