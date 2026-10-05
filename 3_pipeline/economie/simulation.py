# -*- coding: utf-8 -*-
"""Simulation de l'economie de Station Tycoon (v56).
Modele : un joueur passe par des "phases" (stations qu'il possede), les clients arrivent a la cadence du rang
(Rank.Spawn x 1,05 en moyenne, divisee par pub x deco x note), chaque station sert 1 voiture a la fois (CYCLE s).
Gain net par voiture = (Sell - Buy) x Mult(rarete) x Mult(station) x pourboire(note). XP = XP_PAR_VOITURE x Mult(rarete).
Les salaires sont debites chaque minute. On mesure : $/min net par phase, temps pour atteindre chaque rang, temps pour
payer chaque station. Lancer : python3 simulation.py [v55|v56]
"""
import sys, json, math

RARETES = ["Common","Uncommon","Rare","Epic","Legendary","Mythic","Divine"]
MULT = {"Common":1.0,"Uncommon":1.4,"Rare":2.0,"Epic":3.0,"Legendary":5.0,"Mythic":10.0,"Divine":25.0}

def charger(version):
    if version == "v55":
        rangs = [
            dict(Nom="Bronze",  Xp=0,        Spawn=19.0, Requis={}, Probas=[0.700,0.250,0.0450,0.0050,0,0,0]),
            dict(Nom="Argent",  Xp=5000,     Spawn=16.0, Requis=dict(Common=25,Uncommon=10,Rare=2), Probas=[0.550,0.300,0.1200,0.0280,0.0020,0,0]),
            dict(Nom="Or",      Xp=25000,    Spawn=13.0, Requis=dict(Common=100,Uncommon=50,Rare=20,Epic=3), Probas=[0.420,0.320,0.1900,0.0600,0.0090,0.001,0]),
            dict(Nom="Platine", Xp=100000,   Spawn=10.5, Requis=dict(Common=300,Uncommon=200,Rare=100,Epic=30,Legendary=2), Probas=[0.300,0.310,0.2600,0.1050,0.0220,0.003,0]),
            dict(Nom="Diamant", Xp=500000,   Spawn=8.5,  Requis=dict(Common=800,Uncommon=600,Rare=400,Epic=150,Legendary=15,Mythic=1), Probas=[0.200,0.270,0.3200,0.1650,0.0380,0.0068,0.0002]),
            dict(Nom="Maitre",  Xp=3000000,  Spawn=7.0,  Requis=dict(Rare=1500,Epic=800,Legendary=80,Mythic=8,Divine=1), Probas=[0.130,0.220,0.3400,0.2300,0.0700,0.0094,0.0006]),
            dict(Nom="Legende", Xp=20000000, Spawn=6.0,  Requis=dict(Epic=4000,Legendary=400,Mythic=40,Divine=5), Probas=[0.080,0.170,0.3300,0.2900,0.1100,0.0185,0.0015]),
        ]
        # stations : prix, cycle (s), produit (net = Sell-Buy), Mult station, automatique
        stations = {
            "L1_Vide":    dict(Prix=600,  Cycle=19.0,  Net=15,  Mult=1.0,  Auto=False),
            "L2_Seaux":   dict(Prix=900,  Cycle=19.0,  Net=15,  Mult=1.0,  Auto=False),
            "L3_Karcher": dict(Prix=2500, Cycle=34.7,  Net=15,  Mult=1.0,  Auto=True),
            "L4_Rouleaux":dict(Prix=4000, Cycle=36.2,  Net=15,  Mult=1.0,  Auto=True),
            "E1_Base":    dict(Prix=800,  Cycle=19.0,  Net=25,  Mult=1.0,  Auto=False),
            "E2_Barils":  dict(Prix=1200, Cycle=19.0,  Net=25,  Mult=1.0,  Auto=False),
            "E3_Pompes":  dict(Prix=2000, Cycle=19.0,  Net=30,  Mult=1.0,  Auto=False),
            "E4_Bornes":  dict(Prix=3500, Cycle=43.0,  Net=30,  Mult=1.0,  Auto=True),
            "E5_Pneus":   dict(Prix=5000, Cycle=45.2,  Net=100, Mult=1.0,  Auto=True),
            "E6_Peinture":dict(Prix=8000, Cycle=69.27, Net=55,  Mult=1.0,  Auto=True),
            "E7_Teinte":  dict(Prix=6000, Cycle=30.5,  Net=45,  Mult=1.0,  Auto=True),
        }
        return dict(rangs=rangs, stations=stations, XP_PAR_VOITURE=50, SALAIRE_ATTENDANT=12, SALAIRE_CAISSIER=7,
                    PRIX_EMBAUCHE=0, POURBOIRE=lambda note: 1.0, NOTE_CADENCE=lambda note: 1.0, ARGENT_DEPART=3000,
                    PUB_MAX=2.0, DECO_MAX=1.5)
    else:
        with open(__file__.replace("simulation.py", "valeurs_v56.json"), encoding="utf-8") as f:
            v = json.load(f)
        v["POURBOIRE"] = lambda note, v=v: v["POURBOIRE_MIN"] + (v["POURBOIRE_MAX"] - v["POURBOIRE_MIN"]) * note
        v["NOTE_CADENCE"] = lambda note, v=v: v["NOTE_CADENCE_MIN"] + (v["NOTE_CADENCE_MAX"] - v["NOTE_CADENCE_MIN"]) * note
        return v

def mult_moyen(probas):
    return sum(p * MULT[r] for p, r in zip(probas, RARETES))

def simuler(V, strategie, pub=1.0, deco=1.0, note=0.5, duree_max_h=400, verbose=True):
    """strategie : liste de (nom_station, nb) dans l'ordre d'achat ; le joueur achete la suivante des qu'il a l'argent
    (en gardant une reserve de 300 $). Les stations non automatiques ont un employe (salaire), 1 caissier pour 3 stations."""
    rangs = V["rangs"]; S = V["stations"]
    argent = V["ARGENT_DEPART"] - 800 - 200 - 150   # caisse, cartons, sols
    xp = 0.0; index = {r: 0.0 for r in RARETES}
    possede = []            # stations achetees
    a_acheter = list(strategie)
    t = 0.0                 # minutes
    dt = 0.5
    rang_i = 0
    journal = []            # (minute, evenement)
    passages = {}
    def rang_courant():
        i = 0
        for k in range(1, len(rangs)):
            r = rangs[k]
            if xp < r["Xp"]: break
            if any(index[tier] < n for tier, n in r["Requis"].items()): break
            i = k
        return i
    # premiere station
    while a_acheter and argent >= S[a_acheter[0]]["Prix"] + 300:
        nom = a_acheter.pop(0); argent -= S[nom]["Prix"] + V["PRIX_EMBAUCHE"] * (0 if S[nom]["Auto"] else 1); possede.append(nom)
    while t < duree_max_h * 60:
        r = rangs[rang_i]
        attrait = min(V.get("ATTRACTIVITE_MAX", 1.0), 1 + V.get("ATTRACTIVITE_PAR_STATION", 0.0) * max(0, len(possede) - 1))
        cadence = max(4.0, r["Spawn"] * 1.05 / (pub * deco * V["NOTE_CADENCE"](note) * attrait))   # s entre deux clients
        arrivees = 60.0 / cadence                                                 # voitures / min offertes
        capacite = sum(60.0 / S[n]["Cycle"] for n in possede)                     # voitures / min servables
        servies = min(arrivees, capacite)
        if not possede: servies = 0
        # repartition des voitures servies sur les stations au prorata de leur capacite
        gain = 0.0
        mm = mult_moyen(r["Probas"])
        for n in possede:
            part = (60.0 / S[n]["Cycle"]) / capacite if capacite > 0 else 0
            gain += servies * part * S[n]["Net"] * S[n]["Mult"] * mm * V["POURBOIRE"](note)
        salaires = sum(V["SALAIRE_ATTENDANT"] for n in possede if not S[n]["Auto"]) + V["SALAIRE_CAISSIER"] * max(1, math.ceil(len(possede) / 3))
        argent += (gain - salaires) * dt
        xp += servies * V["XP_PAR_VOITURE"] * mm * dt
        for p, rr in zip(r["Probas"], RARETES): index[rr] += servies * p * dt
        t += dt
        nouveau = rang_courant()
        if nouveau != rang_i:
            rang_i = nouveau
            journal.append((t, "RANG %s" % rangs[rang_i]["Nom"]))
            passages[rangs[rang_i]["Nom"]] = t
        while a_acheter and argent >= S[a_acheter[0]]["Prix"] + 300:
            nom = a_acheter.pop(0); argent -= S[nom]["Prix"] + V["PRIX_EMBAUCHE"] * (0 if S[nom]["Auto"] else 1); possede.append(nom)
            journal.append((t, "ACHAT %s (reste %d $, %.0f $/min net)" % (nom, argent, gain - salaires)))
        if rang_i == len(rangs) - 1 and not a_acheter: break
    if verbose:
        for m, e in journal:
            h = m / 60
            print("  %7.1f min (%5.1f h)  %s" % (m, h, e))
    return passages, journal

def tableau_rangs(V, pub=1.0, deco=1.0, note=0.5):
    print("\nRang      cadence  voit/min  Mult moy  $/voiture(L1,net)  XP/min(L1 sature)")
    for r in V["rangs"]:
        cad = r["Spawn"] * 1.05 / (pub * deco * V["NOTE_CADENCE"](note))
        vpm = 60 / cad
        mm = mult_moyen(r["Probas"])
        print("%-9s %6.1fs  %7.2f   %6.3f    %8.1f $            %7.0f" % (r["Nom"], cad, vpm, mm, 15 * mm * V["POURBOIRE"](note), vpm * V["XP_PAR_VOITURE"] * mm))

if __name__ == "__main__":
    version = sys.argv[1] if len(sys.argv) > 1 else "v55"
    V = charger(version)
    print("=== %s ===" % version)
    tableau_rangs(V)
    strat = ["L1_Vide", "L2_Seaux", "E1_Base", "L3_Karcher", "E3_Pompes", "L4_Rouleaux", "E4_Bornes", "E7_Teinte", "E5_Pneus", "E6_Peinture"]
    for pub, deco, note, lib in [(1.0, 1.0, 0.5, "sans pub, deco neutre, note moyenne"), (2.0, 1.5, 1.0, "pub max, deco max, note parfaite")]:
        print("\n--- Progression (%s) ---" % lib)
        passages, _ = simuler(V, strat, pub, deco, note)
        print("  Passages de rang (heures de jeu) :", {k: round(v / 60, 1) for k, v in passages.items()})
