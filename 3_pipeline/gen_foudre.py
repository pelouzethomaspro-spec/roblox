#!/usr/bin/env python3
"""Genere les .rbxmx du pack Foudre a inserer dans la place :
   gen/Foudre.rbxmx         -> ReplicatedStorage/Foudre (Folder : Reglages, Effet, RemoteEvent FoudreSol)
   gen/FoudreServeur.rbxmx  -> ServerScriptService (ModuleScript)
   gen/FoudreHasard.rbxmx   -> ServerScriptService (Script, version adaptee au jeu)
   gen/FoudreClient.rbxmx   -> StarterPlayer/StarterPlayerScripts (LocalScript)
"""
import os
from xml.sax.saxutils import escape

O = "/mnt/user-data/outputs/Integration_Stations"
G = os.path.join(os.path.dirname(os.path.abspath(__file__)), "gen")


def src(path):
    with open(path, encoding="utf-8") as f:
        return f.read()


def script(cls, name, source):
    return ('<Item class="%s"><Properties><string name="Name">%s</string>'
            '<ProtectedString name="Source">%s</ProtectedString></Properties></Item>' % (cls, name, escape(source)))


def ecrire(nom, corps):
    with open(os.path.join(G, nom), "w", encoding="utf-8") as f:
        f.write('<roblox version="4">\n' + corps + '\n</roblox>\n')


ecrire("Foudre.rbxmx",
       '<Item class="Folder"><Properties><string name="Name">Foudre</string></Properties>'
       + script("ModuleScript", "Reglages", src(f"{O}/Foudre/Reglages.lua"))
       + script("ModuleScript", "Effet", src(f"{O}/Foudre/Effet.lua"))
       + '<Item class="RemoteEvent"><Properties><string name="Name">FoudreSol</string></Properties></Item>'
       + '</Item>')
ecrire("FoudreServeur.rbxmx", script("ModuleScript", "FoudreServeur", src(f"{O}/Foudre/FoudreServeur.lua")))
ecrire("Mutations.rbxmx", script("Script", "Mutations", src(f"{O}/Mutations.lua")))
# pack Metal (or / argent)
ecrire("Metal.rbxmx",
       '<Item class="Folder"><Properties><string name="Name">Metal</string></Properties>'
       + script("ModuleScript", "Reglages", src(f"{O}/Metal/Reglages.lua"))
       + script("ModuleScript", "Effet", src(f"{O}/Metal/Effet.lua"))
       + '</Item>')
ecrire("MetalServeur.rbxmx", script("ModuleScript", "MetalServeur", src(f"{O}/Metal/MetalServeur.lua")))
ecrire("MetalClient.rbxmx", script("LocalScript", "MetalClient", src(f"{O}/Metal/MetalClient.lua")))
ecrire("FoudreClient.rbxmx", script("LocalScript", "FoudreClient", src(f"{O}/Foudre/FoudreClient.lua")))
# camion de livraison (Stock) : module serveur + RemoteEvent
ecrire("Circulation.rbxmx", script("ModuleScript", "Circulation", src(f"{O}/Circulation.lua")))
ecrire("Livraison.rbxmx", script("ModuleScript", "Livraison", src(f"{O}/Livraison.lua")))
MAPSRC = os.environ.get("MAPSRC", f"{O}/Map")
ecrire("PortesSas.rbxmx", script("Script", "PortesSas", src(f"{MAPSRC}/PortesSas.lua")))      # V21 : portes coulissantes des sas des chaines
if os.path.exists(f"{MAPSRC}/RobotStock.lua"):
    ecrire("RobotStock.rbxmx", script("Script", "RobotStock", src(f"{MAPSRC}/RobotStock.lua")))   # V21i : robots de stock des hangars
ecrire("InstallerHerbe.rbxmx", script("ModuleScript", "InstallerHerbe", src(f"{O}/Map/InstallerHerbe.lua")))
ecrire("CamionCartons.rbxmx", ('<Item class="Script"><Properties><string name="Name">CamionCartons</string><bool name="Disabled">true</bool>'
    '<ProtectedString name="Source">%s</ProtectedString></Properties>'
    '<Item class="BindableEvent"><Properties><string name="Name">Declencher</string></Properties></Item>'
    '<Item class="BindableEvent"><Properties><string name="Name">Termine</string></Properties></Item></Item>' % escape(src(f"{O}/Camion/CamionCartons.lua"))))
ecrire("ClientLivraison.rbxmx", script("LocalScript", "ClientLivraison", src(f"{O}/ClientLivraison.lua")))
ecrire("ClientCinematique.rbxmx", script("LocalScript", "ClientCinematique", src(f"{O}/ClientCinematique.lua")))   # v50 : cinematique de decouverte
ecrire("Acces.rbxmx", script("ModuleScript", "Acces", src(f"{O}/Acces.lua")))   # v51 : entree / sortie deplacables
ecrire("Tutoriel.rbxmx", script("ModuleScript", "Tutoriel", src(f"{O}/Tutoriel.lua")))   # v53 : tutoriel ItsCirly
ecrire("ClientTutoriel.rbxmx", script("LocalScript", "ClientTutoriel", src(f"{O}/ClientTutoriel.lua")))
ecrire("ClientService.rbxmx", script("LocalScript", "ClientService", src(f"{O}/ClientService.lua")))   # v53 : service manuel (touche E)
ecrire("Demi.rbxmx", script("ModuleScript", "Demi", src(f"{O}/Demi.lua")))   # v54 : demi-grille 7,5
ecrire("Diagnostic.rbxmx", script("ModuleScript", "Diagnostic", src(f"{O}/Diagnostic.lua")))   # v55 : modes Circulation / Decoration (serveur)
ecrire("ClientDiagnostic.rbxmx", script("ModuleScript", "ClientDiagnostic", src(f"{O}/ClientDiagnostic.lua")))   # v55 : plaques au sol (client)
ecrire("ClientRang.rbxmx", script("LocalScript", "ClientRang", src(f"{O}/ClientRang.lua")))   # v55 : badge de rang + panneau des taux du tunnel
ecrire("Enchere.rbxmx", script("ModuleScript", "Enchere", src(f"{O}/Enchere.lua")))   # v55 : encheres des voitures du centre
ecrire("Monetisation.rbxmx", script("ModuleScript", "Monetisation", src(f"{O}/Monetisation.lua")))   # v55 : produits Robux / Game Pass
ecrire("LivraisonEvent.rbxmx", '<Item class="RemoteEvent"><Properties><string name="Name">LivraisonEvent</string></Properties></Item>')
print("Foudre : 4 rbxmx generes ; Livraison : 2")
