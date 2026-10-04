"""Genere, pour la map V21 (paquet map/V21/MAP_V17_Transfert, chaussee 50, trottoirs 15,9, plots 270 x 480) :
  gen/PlotSpawns.rbxmx      : Workspace/PlotSpawns/Plot1..8 (PlotCenter, Annexe, PlayerSpawn, Camera, Tunnel, TypeA, AttenteAchat,
                              ExitNodesFixe, CasesInterdites). v51 : l'ENTREE (cote branche) et la SORTIE (cote route du tour) sont
                              DEPLACABLES par le joueur : les noeuds Entree / QueueNodes / AchatNodes / ExitNodes 1-2 et les tabliers
                              sont crees a l'execution par ServerScriptService/Acces d'apres le profil (data.Acces).
  gen/RoutesAmbiance.lua    : ModuleScript (ServerStorage) : trajets ambiance / achat / livraison + garages
  map/V21/routes_verif.png  : trace de toutes les voies sur le raster du bitume, pour verification visuelle
Repere : centre de la map (0,0,0), Y haut, 1 stud. Conduite a droite (sauf le camion de livraison : voie de gauche, v49).
Grille du jeu : cases de 15 studs, 18 colonnes (toute la largeur du plot, du trottoir de la branche au bord oppose) x 32 rangees
(du trottoir de la route du tour vers le tunnel) ; la grille de depart fait 18 x 11.
"""
import json, math, os, html
os.environ['MAPV'] = '21'
import numpy as np
from PIL import Image, ImageDraw
import routes as R

ICI = os.path.dirname(os.path.abspath(__file__))
GEN = os.path.join(os.path.dirname(ICI), 'gen')
# dossier de la map : V21 (defaut) ou V21j... (variable d'environnement MAPDIR, lue aussi par routes.py)
MAPDIR = os.environ.get('MAPDIR', 'V21')
PAQUET = os.path.join(ICI, MAPDIR, 'MAP_V17_Transfert')
V21 = os.path.join(ICI, MAPDIR)
os.makedirs(GEN, exist_ok=True)

Y_ROUTE = 0.57          # dessus de la chaussee (les voitures ont leur pivot au bas de la carrosserie)
Y_PLOT = 0.57           # dessus des dalles du plot = dessus de la chaussee : continuite route -> sol (a verifier en jeu)
CASE = 15.0             # quadrillage de 15 studs (le pack de 10 est agrandi x1,5 par PlotManager)
DECALAGE_U = 0.0        # v49 : la grille commence AU BORD du trottoir de la branche (plus de bande d'herbe)
Y_PLOTCENTER = Y_PLOT - 0.5 * 1.5   # dessus des dalles = pivot + 0,5 x 1,5 (dalle agrandie)
ESPACE_FILE = 30.0      # espacement des voitures dans la file (voitures de 22 studs)
TROTTOIR = 15.9         # V21 : trottoirs de 15,9 studs (bordure 2 + 2 rangs de dalles)
VOIE = 12.5             # une file par sens, a 12,5 de l'axe (chaussee 2 x 25)
NX, NZ_MAX = 18, 32     # cases de 15 : 270 / 15 = 18 colonnes le long de la route, 480 / 15 = 32 rangees
NZ_BASE = 11            # grille de depart : 18 x 11
R_CENTRE_RP = 516.0     # ronds-points exterieurs et route du tour : |coord| de l'axe

plots = json.load(open(os.path.join(PAQUET, '04_Donnees', 'plots_joueurs.json')))['plots']
TROTTOIR_PNG = np.array(Image.open(os.path.join(V21, 'trottoir127.png'))) > 0

def v3(a): return np.array([a[0], a[1], a[2]], float)
def xz(p): return np.array([p[0], p[2]], float)
def esc(s): return html.escape(s, quote=False)

def cf_xml(nom, pos, R3):
    r = R3.flatten()
    return (f'<CoordinateFrame name="{nom}"><X>{pos[0]:.4f}</X><Y>{pos[1]:.4f}</Y><Z>{pos[2]:.4f}</Z>'
            + ''.join(f'<R{i//3}{i%3}>{r[i]:.6f}</R{i//3}{i%3}>' for i in range(9)) + '</CoordinateFrame>')

def matrice(look, up=np.array([0., 1., 0.])):
    """rotation Roblox dont le LookVector (-Z) est 'look' (horizontal)"""
    look = look / np.linalg.norm(look)
    z = -look
    x = np.cross(up, z); x /= np.linalg.norm(x)
    y = np.cross(z, x)
    return np.column_stack([x, y, z])

def matrice_axes(xaxe, zaxe):
    x = xaxe / np.linalg.norm(xaxe); z = zaxe / np.linalg.norm(zaxe); y = np.cross(z, x)
    assert np.allclose(np.cross(x, y), z, atol=1e-6), "repere non direct"
    return np.column_stack([x, y, z])

def part_xml(nom, pos, R3, taille=(1, 1, 1), transparence=1.0, couleur=(255, 255, 255), attrs=None):
    return f'''<Item class="Part"><Properties>
<string name="Name">{esc(nom)}</string>
{cf_xml("CFrame", pos, R3)}
<Vector3 name="size"><X>{taille[0]}</X><Y>{taille[1]}</Y><Z>{taille[2]}</Z></Vector3>
<Color3uint8 name="Color3uint8">{(0xFF << 24) | (couleur[0] << 16) | (couleur[1] << 8) | couleur[2]}</Color3uint8>
<float name="Transparency">{transparence}</float>
<bool name="Anchored">true</bool><bool name="CanCollide">false</bool><bool name="CanQuery">false</bool><bool name="CanTouch">false</bool><bool name="CastShadow">false</bool>
<token name="TopSurface">0</token><token name="BottomSurface">0</token>
</Properties></Item>'''

def noeud_xml(nom, p2, cap2, y):
    pos = np.array([p2[0], y, p2[1]]); look = np.array([cap2[0], 0, cap2[1]])
    return part_xml(nom, pos, matrice(look))

def string_xml(nom, valeur):
    return f'<Item class="StringValue"><Properties><string name="Name">{esc(nom)}</string><string name="Value">{esc(valeur)}</string></Properties></Item>'

# ----------------------------------------------------------------------------------------------------------------------
verif = Image.fromarray((R.BITUME * 110).astype('uint8')).convert('RGB')
dv = ImageDraw.Draw(verif)
def dessiner(pts, coul, larg=2):
    q = [(p[0] + R.OFF, p[1] + R.OFF) for p in pts]
    if len(q) > 1: dv.line(q, fill=coul, width=larg)
def point(p, coul, r=4):
    dv.ellipse([p[0] + R.OFF - r, p[1] + R.OFF - r, p[0] + R.OFF + r, p[1] + R.OFF + r], fill=coul)

# ----------------------------------------------------------------------------------------------------------------------
# ROND-POINTS ET GARAGES (conduite a droite)
# ----------------------------------------------------------------------------------------------------------------------
R_RING = 177.9 - VOIE   # 165.4 : voie exterieure de l'anneau central (chaussee 127.9..177.9)
R_RING_INT = 127.9 + VOIE
R_EXT = 110.5 - VOIE    # 98.0 : voie exterieure des ronds-points exterieurs (chaussee 60.5..110.5), centres a 516
R_EXT_INT = 60.5 + VOIE # 73.0 : voie interieure
R_BORD_RP = 110.5       # bord exterieur de la chaussee des ronds-points exterieurs
routes_livraison = {}

def ang(v):
    return math.degrees(math.atan2(v[1], v[0])) % 360

def arc_rond_point(C, cap_in, cap_out, pas=14.0, rayon=None, sens=-1, marge=6.0):
    """points (monde) du tour d'un rond-point exterieur de centre C (Vector3) : sens -1 = antihoraire vu de dessus (angles
    decroissants, sens normal), +1 = horaire (sens interdit). Entree avec le cap cap_in (xz), sortie avec le cap cap_out."""
    rayon = rayon or R_EXT
    C2 = np.array([C[0], C[2]])
    a_in = (ang(-cap_in) + sens * marge) % 360                # point d'entree : du cote d'ou l'on vient
    a_out = ang(cap_out) - sens * marge                       # point de sortie : du cote ou l'on va
    if sens < 0:
        while a_out >= a_in: a_out -= 360
    else:
        while a_out <= a_in: a_out += 360
    out = []
    for a in np.arange(a_in, a_out + sens * 1e-6, sens * pas):
        p = C2 + rayon * np.array([math.cos(math.radians(a)), math.sin(math.radians(a))])
        c = R.cap_arc((C2[0], C2[1]), p, sens)
        out.append((np.array([p[0], Y_ROUTE, p[1]]), np.array([c[0], 0, c[1]])))
    return out

# --- garages (cours de livraison) : donnees de DonneesArbres.vehicules (Van gare dans chaque garage ouvert, avant = vers la
#     porte). Porte = van + avant * 19.6 (linteau de la porte de 20 x 19 : boite "mur" a 19,6 du centre du garage).
def lire_vehicules():
    src = open(os.path.join(PAQUET, '02_Scripts_Roblox', 'DonneesArbres.lua'), encoding='utf-8').read()
    import re
    vans = {}
    for m in re.finditer(r'\{modele = "Van", coin = "(\w+)", pos = Vector3\.new\(([-\d.]+), ([-\d.]+), ([-\d.]+)\), avant = Vector3\.new\(([-\d.]+), ([-\d.]+), ([-\d.]+)\)\}', src):
        coin = m.group(1)
        vans[coin] = dict(van=np.array([float(m.group(2)), float(m.group(4))]), avant=np.array([float(m.group(5)), float(m.group(7))]))
    assert len(vans) == 8, vans.keys()
    return vans
VANS = lire_vehicules()

def garage_infos(coin):
    g = VANS[coin]
    a = g['avant'] / np.linalg.norm(g['avant'])
    porte = g['van'] + a * 19.6
    return dict(nom=coin, porte=porte, dedans=-a, van=g['van'], avant=a)

def cour_du_plot(E, s_cote):
    """cour de livraison du cote du plot : rond-point exterieur du cote s_cote ; la cour est du meme cote de l'avenue que le
    plot (signe de E le long de la direction perpendiculaire a l'avenue)"""
    C = s_cote * R_CENTRE_RP
    perp = np.array([-s_cote[2], 0.0, s_cote[0]])
    signe = np.sign(float(np.dot(E - C, perp)))
    meilleur = None
    for coin, g in VANS.items():
        p = np.array([g['van'][0], 0.0, g['van'][1]])
        d = float(np.linalg.norm(p - C))
        if d < 260 and np.sign(float(np.dot(p - C, perp))) == signe:
            if meilleur is None or d < meilleur[0]: meilleur = (d, coin)
    assert meilleur, (E, s_cote)
    return meilleur[1]

def trajet_cour(coin, C_RP):
    """du bord de l'anneau (coupure du trottoir, au niveau de la chaussee) jusqu'a l'interieur du garage.
    La coupure : entre 26 et 45 deg de l'axe de l'avenue, cote cour (angle mesure depuis le centre du rond-point)."""
    g = garage_infos(coin)
    a = g['avant']
    porte = g['porte']; devant = porte + a * 30.0           # arret devant la porte, dos a la cour : les cartons tombent ici
    C2 = np.array([C_RP[0], C_RP[2]])
    # angle (depuis le centre du rond-point) du milieu de la coupure : direction du garage, ramenee entre 26 et 45 deg de l'avenue
    axe_av = -np.array([C_RP[0], C_RP[2]]) / R_CENTRE_RP          # direction du rond-point vers le centre de la map
    vg = devant - C2
    a_g = ang(vg); a_av = ang(axe_av)
    d = ((a_g - a_av + 180) % 360) - 180                          # ecart signe
    a_coupe = a_av + np.sign(d) * 36.0                            # milieu de la coupure (26..45 deg)
    sortie = C2 + R_BORD_RP * np.array([math.cos(math.radians(a_coupe)), math.sin(math.radians(a_coupe))])
    radial = (sortie - C2) / np.linalg.norm(sortie - C2)
    out = [(np.array([sortie[0], Y_ROUTE, sortie[1]]), np.array([radial[0], 0, radial[1]]))]
    # vers "devant" : un point intermediaire pour arriver dans l'axe de la porte
    inter = devant + a * 28.0
    for p, c in ((inter, -a), (devant, -a), (porte, -a), (g['van'] + a * 3.0, -a)):
        y = 1.27 if p is porte or np.allclose(p, g['van'] + a * 3.0) else Y_ROUTE
        out.append((np.array([p[0], y, p[1]]), np.array([c[0], 0, c[1]])))
    return out, a_coupe

# ----------------------------------------------------------------------------------------------------------------------
# PLOTS
# ----------------------------------------------------------------------------------------------------------------------
items = []
resume = []
votes_interdites = {}      # cases interdites en coordonnees canoniques (type A) : vote des 8 plots (symetrie, arrondis du raster)
types_plots = {}
infos_achat = {}
garages_plots = {}
for pl in plots:
    O = v3(pl['origine_coin_tunnel_branche']); U = v3(pl['axe_U_vers_angle_de_la_map']); V = v3(pl['axe_V_du_tunnel_vers_le_centre'])
    T = v3(pl['bouche_du_tunnel']); A = v3(pl['angle_droit_branche_route_du_tour'])
    def monde(u, v, y): return T + U * u + V * v + np.array([0, y, 0])
    u_bord = float(np.dot(O - T, U))            # 40.9 : bord du plot cote branche (demi-chaussee 25 + trottoir 15,9)
    v_route = float(np.dot(A - T, V))           # 480 : bord du plot cote route du tour
    assert abs(u_bord - 40.9) < 1e-6 and abs(v_route - 480) < 1e-6, (u_bord, v_route)
    # V21d/V21j : plus d'acces creuses dans la map (acces_entree_sortie vide) : E = milieu du bord route du plot (sert
    # seulement a choisir le cote de la map et la cour de livraison)
    E = O + U * 135.0 + V * v_route
    # cases de l'entree / de la sortie (depuis le bord du plot, cases de 15 a partir de DECALAGE_U) : 2 cases chacune,
    # centrees au mieux dans la traversee de 50 : entree cases 30..60 (centre 45), sortie 135..165 (centre 150)
    uE0, uS0 = 30.0, 135.0
    u_Ec, u_Sc = uE0 + CASE, uS0 + CASE                              # centres des tabliers (45 / 150)
    Ucross = np.cross(U, np.array([0., 1., 0.]))
    typeA = np.allclose(Ucross, -V)
    u_voie_branche = (VOIE if typeA else -VOIE)                               # voie de droite de la branche (cap V), depuis l'axe T
    V_EXT, V_INT = v_route + TROTTOIR + VOIE, v_route + TROTTOIR + 3 * VOIE   # 508.4 (exterieure) / 533.4 (interieure)
    V_AXE = v_route + TROTTOIR + 2 * VOIE                                     # 520.9 : axe de la route du tour (|coord| = 516)
    assert abs((1036.9 - V_AXE) - R_CENTRE_RP) < 1e-6
    v_voie_route = V_EXT if typeA else V_INT
    LARGEUR_BASE = NX * CASE                                                  # 270 : toute la largeur du plot
    # repere du plot : la route du tour est le bord Z = -DEMI de la grille (rangee 1 au bord du plot), X le long de la route.
    # type B : X pointe vers la branche (miroir), ancre a u = LARGEUR_BASE.
    if typeA:
        Xaxe, Zaxe = U, -V; P = O + U * DECALAGE_U + V * (v_route - CASE / 2)
    else:
        Xaxe, Zaxe = -U, -V; P = O + U * (DECALAGE_U + LARGEUR_BASE) + V * (v_route - CASE / 2)
    Rplot = matrice_axes(Xaxe, Zaxe)
    P = P + np.array([0, Y_PLOTCENTER, 0])
    def uO(u): return u + u_bord                                              # u depuis le bord du plot -> u depuis l'axe du tunnel
    # --- noeuds ---
    tunnel = (monde(u_voie_branche, -60, Y_ROUTE), V)                       # apparition dans le tunnel
    file_ = []                                                              # QueueNodes N..1 (1 = devant l'entree)
    file_.append((monde(uO(u_Ec), v_voie_route, Y_ROUTE), U))               # 1 : sur la route, devant l'entree
    diag = (U + V) / np.linalg.norm(U + V)
    if typeA:
        file_.append((monde(u_voie_branche, v_voie_route, Y_ROUTE), diag))  # 2 : au milieu du carrefour (virage a droite)
    else:
        file_.append((monde(0.0, v_voie_route - 3, Y_ROUTE), diag))         # 2 : au milieu du carrefour (virage a gauche)
    file_.append((monde(u_voie_branche, v_voie_route - 55, Y_ROUTE), V))    # 3 : sur la branche, avant le virage
    v = v_voie_route - 55 - ESPACE_FILE
    while v > -20:
        file_.append((monde(u_voie_branche, v, Y_ROUTE), V)); v -= ESPACE_FILE
    entree = (monde(uO(u_Ec), v_route - CASE, Y_PLOT), -V)                  # dans le plot, centre du 1er bloc (rangees 1-2 = le tablier) : une station peut etre posee des la rangee 3
    s_cote = np.array([np.sign(E[0]), 0.0, 0.0]) if abs(E[0]) > abs(E[2]) else np.array([0.0, 0.0, np.sign(E[2])])
    C_RP = s_cote * R_CENTRE_RP
    u_C = float(np.dot(C_RP - T, U))                                        # < 0 : le rond-point est du cote -U
    attente_achat = (monde(-u_bord - 36.0, v_voie_route, Y_ROUTE), U)      # v51 : place d'attente des voitures achetees (avant le carrefour)
    infos_achat[pl['nom']] = dict(E=xz(monde(uO(u_Ec), v_route, 0)), U=xz(U), noeud1=xz(file_[0][0]), attente=xz(attente_achat[0]))
    coin = cour_du_plot(E, s_cote)
    garages_plots[pl['nom']] = garage_infos(coin)
    # --- sortie : dans le plot, puis sur la route, puis trace jusqu'au bord de la map ---
    # v51 : la partie FIXE du trajet de sortie commence a X local = X_QUEUE_SORTIE (300 : 30 studs apres le bord oppose du
    # plot pour le type A ; dans le carrefour de la branche pour le type B) ; la partie variable (dans le plot, puis sur la
    # voie exterieure de la route du tour jusqu'ici) est faite a l'execution par Acces d'apres la position de la sortie.
    # type A : la route du tour entre dans le ROND-POINT EXTERIEUR juste apres le plot (axe a u = 341,3 ; chaussee des u = 230,8 :
    # d'ou les cases interdites) : la partie fixe part de X = 180 (u = 220,9), avant l'anneau ; la sortie est limitee a x <= 10.
    X_QUEUE_SORTIE = 180.0 if typeA else 300.0
    if typeA:
        u0 = uO(X_QUEUE_SORTIE)
        sortie = [(monde(u0, V_EXT, Y_ROUTE), U)]
        voie, _ = R.tracer_bord_droit(xz(monde(u0 + 20, V_EXT, 0)), xz(U))
    else:
        u0 = uO(LARGEUR_BASE - X_QUEUE_SORTIE)                              # X local 300 = u 10.9 (type B : X = 270 + 40.9 - u)
        sortie = [(monde(u0, V_EXT, Y_ROUTE), -U)]
        u = u0 - 35
        while u > u_C + R_EXT + 12:
            sortie.append((monde(u, V_EXT, Y_ROUTE), -U)); u -= 35
        sortie += arc_rond_point(C_RP, xz(-U), xz(-U))
        u = u_C - R_EXT - 12 - 20
        while u > -(R_CENTRE_RP + 20):
            sortie.append((monde(u, V_EXT, Y_ROUTE), -U)); u -= 35
        voie, _ = R.tracer_bord_droit(xz(monde(-(R_CENTRE_RP + 20), V_EXT, 0)), xz(-U))
    for p2, c2 in R.echantillonner(voie, 35.0):
        if np.linalg.norm(p2 - xz(sortie[-1][0])) < 20: continue
        if max(abs(p2[0]), abs(p2[1])) > R.DEMI - 40: break          # fin de map (tete de tunnel) : la voiture disparait la
        sortie.append((np.array([p2[0], Y_ROUTE, p2[1]]), np.array([c2[0], 0, c2[1]])))
    # --- camion de livraison (v49, demande de Thomas) : il SORT DU TUNNEL SUR LA VOIE DE GAUCHE, fonce sur la branche puis
    #     sur la route du tour (toujours a gauche), coupe le rond-point par le plus court (sens interdit quand la cour est du
    #     mauvais cote) et sort par la coupure du trottoir vers la cour de livraison, puis s'arrete devant le garage ouvert.
    u_gauche = -u_voie_branche
    livr = [(monde(u_gauche, -60, Y_ROUTE), V)]
    v = 0.0
    while v < V_EXT - 70:
        livr.append((monde(u_gauche, v, Y_ROUTE), V)); v += 45
    v_lane_gauche = V_EXT if typeA else V_INT                               # voie de GAUCHE en roulant vers -U
    livr.append((monde(u_gauche - 30, v_lane_gauche, Y_ROUTE), -U))
    u = u_gauche - 30 - 45
    while u > u_C + R_EXT + 15:
        livr.append((monde(u, v_lane_gauche, Y_ROUTE), -U)); u -= 45
    cour, a_coupe = trajet_cour(coin, C_RP)
    # sens du tour : le plus court entre l'entree (angle de -U vu du centre) et la coupure
    a_in = ang(xz(U))                                                        # on arrive par le cote +U du rond-point
    d = ((a_coupe - a_in + 180) % 360) - 180
    sens = +1 if d > 0 else -1
    C2 = xz(C_RP)
    cap_out = np.array([math.cos(math.radians(a_coupe)), math.sin(math.radians(a_coupe))])
    arc = arc_rond_point(C_RP, xz(-U), cap_out, pas=12.0, rayon=R_EXT_INT if sens > 0 else R_EXT, sens=sens, marge=8.0)
    livr += arc
    livr += cour
    routes_livraison[pl['nom']] = (livr, sens, len(livr) - len(cour) - len(arc))   # (noeuds, sens du rond-point, indice du 1er noeud de l'anneau)
    # --- camera du choix de plot et apparition du joueur ---
    Cc = O + U * (LARGEUR_BASE / 2) + V * (v_route / 2)
    oeil = Cc + V * 330 + np.array([0, 55, 0])     # vue basse comme la maquette (horizon au tiers)
    Cc = Cc + np.array([0, 10, 0])
    look = (Cc - oeil); look /= np.linalg.norm(look)
    zc = -look; xc = np.cross(np.array([0., 1., 0.]), zc); xc /= np.linalg.norm(xc); yc = np.cross(zc, xc)
    cam_R = np.column_stack([xc, yc, zc])
    spawn = monde(uO(u_Ec) + 20, v_route - 30, 1.0)
    # --- annexe (de l'autre cote de la branche) : Part "Annexe" 30 x 30 (2 x 2 cases de 15), meme orientation que le plot
    an = pl['annexe_3x3']; ao = v3(an['origine']); aI = v3(an['axe_I']); aJ = v3(an['axe_J']); n = an['n'] * an['case_studs']
    coins = [ao + aI * i + aJ * j for i in (0, n) for j in (0, n)]
    locaux = [(float(np.dot(c - P, Xaxe)), float(np.dot(c - P, Zaxe))) for c in coins]
    ax0, az0 = min(l[0] for l in locaux), min(l[1] for l in locaux)
    assert abs(max(l[0] for l in locaux) - ax0 - n) < 1e-6 and abs(max(l[1] for l in locaux) - az0 - n) < 1e-6
    assert abs(n - 2 * CASE) < 1e-6, n
    annexe_pos = P + Rplot @ np.array([ax0 + n / 2, 0, az0 + n / 2])
    # --- tabliers de bitume DANS le plot (2 x 2 cases de 15) sous les cases de l'entree et de la sortie : la voiture roule
    #     sur du goudron jusqu'au noeud "Entree" ; une dalle posee par le joueur (dessus Y_PLOT) le recouvre.
    def part_solide(nom, pos, R3, taille, couleur, materiau=1376):
        x = part_xml(nom, pos, R3, taille, 0.0, couleur)
        x = x.replace('<bool name="CanCollide">false</bool><bool name="CanQuery">false</bool>', '<bool name="CanCollide">true</bool><bool name="CanQuery">true</bool>')
        return x.replace('<token name="TopSurface">0</token>', f'<token name="Material">{materiau}</token><token name="TopSurface">0</token>')
    TEXTURE_BITUME = ('<Item class="Texture"><Properties><string name="Name">Bitume</string><token name="Face">1</token>'
                      '<Content name="Texture"><url>rbxassetid://107035026496600</url></Content>'
                      '<float name="StudsPerTileU">10</float><float name="StudsPerTileV">10</float>'
                      '<Color3 name="Color3"><R>1</R><G>1</G><B>1</B></Color3></Properties></Item>')
    acces_xml = []
    for nomAcces, uc in (("AccesEntree", u_Ec), ("AccesSortie", u_Sc)):
        dedans = -V                                                          # de la route vers le plot
        tablier = monde(uO(uc), v_route - CASE, 0) + np.array([0, Y_PLOT - 0.14 - 0.02, 0])   # dessus a 0,55 : une dalle posee dessus (0,57) gagne le rayon du mode Supprimer
        Rt = matrice_axes(np.cross(np.array([0., 1., 0.]), -dedans), -dedans)
        x = part_solide(nomAcces + "_Tablier", tablier, Rt, (2 * CASE, 0.28, 2 * CASE), (53, 57, 65), 272)
        x = x.replace('</Properties></Item>', '</Properties>' + TEXTURE_BITUME + '</Item>')
        acces_xml.append(x)
    # --- cases interdites : la courbe de la route du tour (trottoir + chaussee) mord le coin interieur du plot. On teste
    #     chaque case de 15 sur les rasters (trottoir a 1,27 et bitume a 0,57) : > 3 % de pixels -> case interdite.
    interdites = []
    for gx in range(1, NX + 1):
        for gz in range(1, NZ_MAX + 1):
            c = P + Rplot @ np.array([(gx - 0.5) * CASE, 0, (gz - 1) * CASE])   # centre de la case (CentreCase de PlotManager)
            # coins / echantillonnage de la case (pas de 1 stud)
            nb, tot = 0, 0
            # on ignore une bande de 3,5 studs sur le pourtour de la case : une intrusion <= 3,5 studs du trottoir ou de la
            # chaussee (bord des acces, 1 px d'arrondi) laisse la case constructible
            for dx in np.arange(-CASE / 2 + 3.5, CASE / 2 - 3.0, 1.0):
                for dz in np.arange(-CASE / 2 + 3.5, CASE / 2 - 3.0, 1.0):
                    w = c + Rplot @ np.array([dx, 0, dz])
                    i, j = int(round(w[2] + R.OFF)), int(round(w[0] + R.OFF))
                    tot += 1
                    if 0 <= i < R.BITUME.shape[0] and 0 <= j < R.BITUME.shape[1] and (R.BITUME[i, j] or TROTTOIR_PNG[i, j]): nb += 1
            if nb > 0: interdites.append((gx, gz))
    # --- XML ---
    enfants = [part_xml("PlotCenter", P, Rplot, (4, 1, 4), 1.0),
               part_xml("Annexe", annexe_pos, Rplot, (n, 1, n), 1.0),
               part_xml("PlayerSpawn", spawn, matrice(-V), (4, 1, 4), 1.0),
               part_xml("Camera", oeil, cam_R, (1, 1, 1), 1.0),
               noeud_xml("Tunnel", xz(tunnel[0]), xz(tunnel[1]), tunnel[0][1]),
               noeud_xml("AttenteAchat", xz(attente_achat[0]), xz(attente_achat[1]), attente_achat[0][1]),
               f'<Item class="BoolValue"><Properties><string name="Name">TypeA</string><bool name="Value">{"true" if typeA else "false"}</bool></Properties></Item>',
               string_xml("CasesInterdites", f"@@INTERDITES_{pl['nom']}@@")]
    canon = set((gx if typeA else NX + 1 - gx, gz) for gx, gz in interdites)
    for c in canon: votes_interdites[c] = votes_interdites.get(c, 0) + 1
    types_plots[pl['nom']] = typeA
    e = ''.join(noeud_xml(str(i + 1), xz(p), xz(c), p[1]) for i, (p, c) in enumerate(sortie))
    enfants.append(f'<Item class="Folder"><Properties><string name="Name">ExitNodesFixe</string></Properties>{e}</Item>')
    items.append(f'''<Item class="Model"><Properties><string name="Name">{pl['nom']}</string><token name="ModelStreamingMode">2</token>
<OptionalCoordinateFrame name="WorldPivotData"><CFrame><X>{P[0]:.4f}</X><Y>{P[1]:.4f}</Y><Z>{P[2]:.4f}</Z>{''.join(f'<R{i//3}{i%3}>{Rplot.flatten()[i]:.6f}</R{i//3}{i%3}>' for i in range(9))}</CFrame></OptionalCoordinateFrame>
</Properties>{''.join(enfants)}</Item>''')
    hors = [tuple(xz(p).round(1)) for p, _ in file_ + sortie if not R.bitume(*xz(p))]
    resume.append(dict(nom=pl['nom'], type='A' if typeA else 'B', file=len(file_), sortie=len(sortie), hors_bitume=hors, P=P.round(2).tolist(),
                       annexe=(round(ax0, 1), round(az0, 1)), cour=coin, sens_rp=sens, interdites=len(interdites)))
    # verification visuelle
    dessiner([xz(tunnel[0])] + [xz(p) for p, _ in reversed(file_)] + [xz(entree[0])], (60, 120, 255), 3)
    dessiner([xz(p) for p, _ in sortie], (255, 200, 40), 3)
    point(xz(attente_achat[0]), (80, 200, 255), 5)
    point(xz(P), (255, 0, 255), 5); point(xz(spawn), (0, 255, 0), 4); point(xz(oeil), (255, 255, 0), 3)
    for (cx, cz) in [(0, -CASE / 2), (LARGEUR_BASE, -CASE / 2), (LARGEUR_BASE, NZ_BASE * CASE - CASE / 2), (0, NZ_BASE * CASE - CASE / 2)]:
        w = P + Rplot @ np.array([cx, 0, cz]); point(xz(w), (255, 120, 0), 3)
    for gx, gz in interdites:
        w = P + Rplot @ np.array([(gx - 0.5) * CASE, 0, (gz - 1) * CASE]); point(xz(w), (255, 0, 0), 3)

xml_plots = '\n'.join(items)
interdites_canon = set(c for c, n in votes_interdites.items() if n > 4)
for nom, typeA in types_plots.items():
    cases = sorted((gx if typeA else NX + 1 - gx, gz) for gx, gz in interdites_canon)
    xml_plots = xml_plots.replace(f"@@INTERDITES_{nom}@@", ";".join(f"{gx},{gz}" for gx, gz in cases))
print('cases interdites (canonique, type A) :', sorted(interdites_canon))
open(os.path.join(GEN, 'PlotSpawns.rbxmx'), 'w').write('<roblox version="4">\n' + xml_plots + '\n</roblox>\n')
for r_ in resume: print(r_)

# ----------------------------------------------------------------------------------------------------------------------
# VOITURES D'AMBIANCE : usine -> rond-point central (voie exterieure, 4 tours, ANTIHORAIRE) -> avenue (voie de droite)
# -> rond-point exterieur (antihoraire) -> route du tour -> diagonale.  Conduite a droite.
# ----------------------------------------------------------------------------------------------------------------------
TOURS = 4
AVENUE_FIN = R_CENTRE_RP - R_BORD_RP      # 405.5 : l'avenue arrive sur le rond-point exterieur

def route_NE():
    pts = []   # (x, z, capx, capz, y)
    d = np.array([1.0, -1.0]) / math.sqrt(2)            # centre -> chaine NE
    vers_centre = -d
    g = R.droite(vers_centre) * VOIE
    for r in (300.0, 262.0, 228.0, 190.0):              # dans le hall (portail a ~196 du centre), puis le troncon devant la facade
        p = d * r + g; pts.append((p, vers_centre))
    # entree sur l'anneau : angle de la diagonale NE = 315 deg, antihoraire = angles decroissants ; sortie par l'avenue
    # nord (270) apres 4 tours
    a0, a_fin = 315 - 6, 315 - 360 * TOURS - 45 + 8
    for a in np.arange(a0, a_fin - 1e-6, -15):
        p = np.array([R_RING * math.cos(math.radians(a)), R_RING * math.sin(math.radians(a))])
        pts.append((p, R.cap_arc((0, 0), p, -1), int(round(a)) % 360))    # 3e champ : angle sur l'anneau (0-359)
    # puis l'avenue nord (voie de droite x = +VOIE, cap -Z)
    for z in (-215.0, -300.0, -380.0):
        pts.append((np.array([VOIE, z]), np.array([0.0, -1.0])))
    # rond-point nord centre (0, -516) : entree par le sud (angle 90 deg), sortie a l'est (0 deg), antihoraire
    for a in np.arange(84, 6 - 1e-6, -14):
        p = np.array([R_EXT * math.cos(math.radians(a)), -R_CENTRE_RP + R_EXT * math.sin(math.radians(a))])
        pts.append((p, R.cap_arc((0, -R_CENTRE_RP), p, -1)))
    # route du tour vers l'est : voie de droite = z = -516 + 12.5 (cap +X)
    zl = -R_CENTRE_RP + VOIE
    for x in (140.0, 230.0, 320.0):
        pts.append((np.array([x, zl]), np.array([1.0, 0.0])))
    # virage + diagonale NE : trace sur le raster depuis le centre de chaussee (350, -516)
    voie, _ = R.tracer_bord_droit((350.0, zl), (1.0, 0.0))
    for p2, c2 in R.echantillonner(voie, 35.0):
        if np.linalg.norm(p2 - np.array([350, zl])) < 20: continue
        pts.append((p2, c2))
    return pts

def tourner(pts, k):
    """rotation de k quarts de tour autour du centre : (x, z) -> (-z, x) ; l'angle d'anneau tourne de 90k"""
    out = []
    for n in pts:
        p, c = n[0].copy(), n[1].copy(); a = n[2] if len(n) > 2 else None
        for _ in range(k):
            p = np.array([-p[1], p[0]]); c = np.array([-c[1], c[0]])
        if a is not None: a = (a + 90 * k) % 360
        out.append((p, c, a))
    return out

def trajet_achat(nom):
    """Voiture achetee au centre : depuis l'anneau (dernier tour) -> avenue du cote du plot (voie de droite) -> rond-point
    exterieur (antihoraire) -> route du tour, voie de droite dans le sens du plot -> place d'attente avant le noeud 1."""
    I = infos_achat[nom]
    E, U, n1 = I['E'], I['U'], I['noeud1']
    s = np.array([np.sign(E[0]), 0.0]) if abs(E[0]) > abs(E[1]) else np.array([0.0, np.sign(E[1])])   # cote de la map
    theta = math.degrees(math.atan2(s[1], s[0])) % 360                       # E 0, S 90, W 180, N 270
    a0 = int(round(theta + 9)) % 360                                          # 9 / 99 / 189 / 279 : sur la grille (9 mod 15)
    assert a0 % 15 == 9, a0
    pts = []
    p = np.array([R_RING * math.cos(math.radians(a0)), R_RING * math.sin(math.radians(a0))])
    pts.append((p, R.cap_arc((0, 0), p, -1), a0))
    droite = R.droite(s)                                                      # voie de droite de l'avenue
    for r in (215.0, 300.0, 380.0):
        pts.append((s * r + droite * VOIE, s.copy(), None))
    C = s * R_CENTRE_RP                                                       # rond-point exterieur du cote du plot
    t = droite if np.dot(E - C, droite) > 0 else -droite                      # sens de la route du tour vers le plot
    a_in = (theta + 180 - 6) % 360
    a_out = math.degrees(math.atan2(t[1], t[0])) % 360 + 6
    while a_out >= a_in: a_out -= 360
    for a in np.arange(a_in, a_out - 1e-6, -14):
        q = C + R_EXT * np.array([math.cos(math.radians(a)), math.sin(math.radians(a))])
        pts.append((q, R.cap_arc((C[0], C[1]), q, -1), None))
    # route du tour, voie de droite dans le sens t, jusqu'a la place d'attente (65 studs avant le noeud 1)
    arrivee = I['attente']                                                    # v51 : noeud AttenteAchat du PlotSpawn
    depart = C + R.droite(t) * VOIE + t * (R_EXT + 12.0)
    L = float(np.linalg.norm(arrivee - depart))
    n = max(1, int(L // 35.0))
    for i in range(1, n):
        pts.append((depart + (arrivee - depart) * (i / n), t.copy(), None))
    pts.append((arrivee, U.copy(), None))
    return pts

base = [(n[0], n[1], n[2] if len(n) > 2 else None) for n in route_NE()]
routes_amb = {"NO": base, "NE": tourner(base, 1), "SE": tourner(base, 2), "SO": tourner(base, 3)}
routes_achat = {nom: trajet_achat(nom) for nom in sorted(infos_achat)}
lignes = ['--[[ RoutesAmbiance : trajets des voitures d\'ambiance (genere depuis la map V21, gen_map_v21.py).',
          '\tUsine (chaine de production) -> anneau central, voie exterieure, ' + str(TOURS) + ' tours -> avenue -> rond-point exterieur',
          '\t-> route du tour -> diagonale jusqu\'au bord de la map. Conduite a DROITE (ronds-points antihoraires). Repere de la map (centre 0,0,0) :',
          '\tle serveur ajoute le decalage d\'import (attribut Workspace.DecalageMap). Chaque point = {x, y, z, capX, capZ[, angle]} ;',
          '\tangle (0-359) = position sur l\'anneau central, present sur les points de l\'anneau seulement.',
          '\tAchat.PlotN : trajet d\'une voiture achetee au centre, du point de l\'anneau (premier point, angle) jusqu\'a la',
          '\tplace d\'attente devant le plot N (route du tour, cote plot, 65 studs avant le noeud 1 de la file).',
          '\tLivraison.PlotN : trajet du camion de livraison (v49 : voie de GAUCHE, coupe le rond-point par le plus court, cour du',
          '\tgarage du cote du plot) ; LivraisonInfos.PlotN = {sens = +1 horaire (sens interdit) / -1, anneau = indice du 1er noeud du rond-point}. ]]',
          'return {']
def ligne_noeud(n):
    p, c, a = n
    return f'\t\t{{{p[0]:.2f}, {Y_ROUTE}, {p[1]:.2f}, {c[0]:.4f}, {c[1]:.4f}' + (f', {a}' if a is not None else '') + '},'
for nom, pts in routes_amb.items():
    lignes.append(f'\t{nom} = {{')
    for n in pts: lignes.append(ligne_noeud(n))
    lignes.append('\t},')
lignes.append('\tAchat = {')
for nom, pts in routes_achat.items():
    lignes.append(f'\t\t{nom} = {{')
    for n in pts: lignes.append('\t' + ligne_noeud(n))
    lignes.append('\t\t},')
lignes.append('\t},')
lignes.append('\tLivraison = {')
for nom in sorted(routes_livraison):
    lignes.append(f'\t\t{nom} = {{')
    for p, c in routes_livraison[nom][0]:
        lignes.append(f'\t\t\t{{{p[0]:.2f}, {p[1]:.2f}, {p[2]:.2f}, {c[0]:.4f}, {c[2]:.4f}}},')
    lignes.append('\t\t},')
lignes.append('\t},')
lignes.append('\tLivraisonInfos = {')
for nom in sorted(routes_livraison):
    _, sens, i_anneau = routes_livraison[nom]
    lignes.append(f'\t\t{nom} = {{sens = {sens}, anneau = {i_anneau + 1}}},')
lignes.append('\t},')
lignes.append('\tGarages = {')
for nom in sorted(garages_plots):
    g = garages_plots[nom]
    lignes.append(f'\t\t{nom} = {{nom = "{g["nom"]}", porte = Vector3.new({g["porte"][0]:.2f}, 1.27, {g["porte"][1]:.2f}), dedans = Vector3.new({g["dedans"][0]:.4f}, 0, {g["dedans"][1]:.4f}), van = Vector3.new({g["van"][0]:.2f}, 1.27, {g["van"][1]:.2f})}},')
lignes.append('\t},')
lignes.append('}')
open(os.path.join(GEN, 'RoutesAmbiance.lua'), 'w').write('\n'.join(lignes) + '\n')
for nom, pts in routes_amb.items():
    dessiner([n[0] for n in pts], (255, 60, 60), 2)
    hors = [tuple(n[0].round(1)) for n in pts if not R.bitume(*n[0])]
    if hors: print('AMBIANCE', nom, 'hors bitume :', hors)
for nom, pts in routes_achat.items():
    dessiner([n[0] for n in pts], (80, 200, 255), 2)
    hors = [tuple(n[0].round(1)) for n in pts if not R.bitume(*n[0])]
    if hors: print('ACHAT', nom, 'hors bitume :', hors)
for nom, (pts, sens, _) in routes_livraison.items():
    dessiner([xz(p) for p, _ in pts], (255, 120, 255), 2)
    hors = [tuple(xz(p).round(1)) for p, _ in pts[:-3] if not R.bitume(*xz(p))]
    if hors: print('LIVRAISON', nom, 'hors bitume :', hors)
print('ambiance :', {k: len(v) for k, v in routes_amb.items()}, 'achat :', {k: len(v) for k, v in routes_achat.items()})

verif.save(os.path.join(V21, 'routes_verif.png'))
verif.crop((0, 0, R.OFF, R.OFF)).save(os.path.join(V21, 'routes_verif_NO.png'))
verif.crop((R.OFF, 0, 2 * R.OFF, R.OFF)).save(os.path.join(V21, 'routes_verif_NE.png'))
print('OK')
