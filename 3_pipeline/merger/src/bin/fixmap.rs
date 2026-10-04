// fixmap <in.rbxl> <out.rbxl>
// Repare la place enregistree par Thomas : la map V17 a ete importee par Studio a la mauvaise echelle (x2.7646) et
// tournee de 180 degres, puis InstallerMap / InstallerChaines ont construit des choses dessus. On :
//   1) retire tout ce que les installateurs ont cree (collisions, arbres poses, copies de batiments, lumieres, fontaine,
//      montage des chaines, sauvegardes d'animations, eau du terrain) ;
//   2) remet chaque piece de la map a l'echelle 1, tournee de 180 degres, Sol_Herbe_0_0 recale sur (-1011.22, 0, 1011.22) ;
//   3) remet la bibliotheque d'arbres (ServerStorage/ARBRES_V17) a l'echelle 1 (Arbre_RP_0 = 22.973 studs de large).
// Il ne reste plus qu'a relancer require(game.ServerStorage.InstallerTout)() dans Studio.
use std::fs::File;
use std::io::{BufReader, BufWriter};
use rbx_dom_weak::{WeakDom, types::{Ref, Variant, Vector3, CFrame, Matrix3}};

fn find_path(dom: &WeakDom, path: &str) -> Option<Ref> {
    let mut cur = dom.root_ref();
    for part in path.split('/') {
        let inst = dom.get_by_ref(cur)?;
        let mut next = None;
        for c in inst.children() {
            if dom.get_by_ref(*c).map(|i| i.name.as_str()) == Some(part) { next = Some(*c); break; }
        }
        cur = next?;
    }
    Some(cur)
}

fn descendants(dom: &WeakDom, r: Ref, out: &mut Vec<Ref>) {
    for c in dom.get_by_ref(r).unwrap().children() { out.push(*c); descendants(dom, *c, out); }
}

fn is_basepart(class: &str) -> bool {
    matches!(class, "Part" | "MeshPart" | "UnionOperation" | "WedgePart" | "CornerWedgePart" | "TrussPart" | "SpawnLocation" | "Seat" | "VehicleSeat" | "NegateOperation" | "IntersectOperation")
}

fn find_part_named(dom: &WeakDom, root: Ref, name: &str) -> Option<Ref> {
    let mut all = Vec::new(); descendants(dom, root, &mut all);
    all.into_iter().find(|r| { let i = dom.get_by_ref(*r).unwrap(); is_basepart(&i.class) && i.name == name })
}

fn get_cframe(dom: &WeakDom, r: Ref) -> Option<CFrame> {
    match dom.get_by_ref(r)?.properties.get(&rbx_dom_weak::ustr("CFrame")) { Some(Variant::CFrame(c)) => Some(*c), _ => None }
}
fn get_size(dom: &WeakDom, r: Ref) -> Option<Vector3> {
    match dom.get_by_ref(r)?.properties.get(&rbx_dom_weak::ustr("Size")) { Some(Variant::Vector3(v)) => Some(*v), _ => None }
}

// p' = cible + R * k * (p - pivot), avec R = rotation de 180 degres autour de Y (x -> -x, z -> -z) si demi_tour
fn transformer(dom: &mut WeakDom, r: Ref, pivot: Vector3, cible: Vector3, k: f32, demi_tour: bool) {
    let Some(cf) = get_cframe(dom, r) else { return };
    let s = if demi_tour { -1.0 } else { 1.0 };
    let p = cf.position;
    let np = Vector3::new(cible.x + s * k * (p.x - pivot.x), cible.y + k * (p.y - pivot.y), cible.z + s * k * (p.z - pivot.z));
    let o = cf.orientation;
    // R180 * M : lignes 0 et 2 negatees (R180 = diag(-1, 1, -1) a gauche)
    let no = if demi_tour {
        Matrix3::new(Vector3::new(-o.x.x, -o.x.y, -o.x.z), o.y, Vector3::new(-o.z.x, -o.z.y, -o.z.z))
    } else { o };
    let inst = dom.get_by_ref_mut(r).unwrap();
    inst.properties.insert(rbx_dom_weak::ustr("CFrame"), Variant::CFrame(CFrame::new(np, no)));
    if let Some(Variant::Vector3(sz)) = inst.properties.get(&rbx_dom_weak::ustr("Size")).cloned() {
        inst.properties.insert(rbx_dom_weak::ustr("Size"), Variant::Vector3(Vector3::new(sz.x * k, sz.y * k, sz.z * k)));
    }
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let mut dom = rbx_binary::from_reader(BufReader::new(File::open(&args[1]).expect("open in"))).expect("decode rbxl");

    let map = find_path(&dom, "Workspace/MAP_MOTIFS_V17_AVEC_CHAINES").expect("map introuvable");

    // 1) suppressions --------------------------------------------------------------------------------------------
    let mut a_supprimer: Vec<Ref> = Vec::new();
    for nom in ["Collisions", "Arbres", "Batiments/Lumieres", "Square/Fontaine"] {
        if let Some(r) = find_path(&dom, &format!("Workspace/MAP_MOTIFS_V17_AVEC_CHAINES/{}", nom)) { a_supprimer.push(r); }
    }
    for nom in ["Workspace/Depart", "Workspace/PlotZones", "Workspace/SolProvisoire", "ServerStorage/RBX_ANIMSAVES"] {
        if let Some(r) = find_path(&dom, nom) { a_supprimer.push(r); }
    }
    // copies de batiments (Bloc_NO_/SO_/SE_ : le FBX n'a que Bloc_NE_), et tout le montage des chaines
    let mut all = Vec::new(); descendants(&dom, map, &mut all);
    for r in &all {
        let i = dom.get_by_ref(*r).unwrap();
        let n = i.name.as_str();
        let dans_chaine = { let mut p = i.parent(); let mut ok = false; while let Some(pi) = dom.get_by_ref(p) { if pi.name.starts_with("ChaineProduction_") { ok = true; break; } p = pi.parent(); } ok };
        if n.starts_with("Bloc_NO_") || n.starts_with("Bloc_SO_") || n.starts_with("Bloc_SE_") { a_supprimer.push(*r); continue; }
        if i.class == "Motor6D" || i.class == "AnimationController" || i.class == "Animator" || (i.class == "ObjectValue" && n == "AnimSaves") { a_supprimer.push(*r); continue; }
        if dans_chaine && i.class == "Part" && (n == "Socle" || n.starts_with("Voiture_") || n.starts_with("Palette_") || n.starts_with("Roue_") || n == "Voiture") { a_supprimer.push(*r); continue; }
        if dans_chaine && (i.class == "Script" || i.class == "LocalScript" || i.class == "Folder") { a_supprimer.push(*r); continue; }
    }
    // copies de test des animations de la chaine (Montage.animations les recree)
    if let Some(test) = find_path(&dom, "ReplicatedStorage/AnimationsTest_ASupprimer") {
        for c in dom.get_by_ref(test).unwrap().children().to_vec() {
            if dom.get_by_ref(c).unwrap().name.starts_with("Chaine") { a_supprimer.push(c); }
        }
    }
    let n_sup = a_supprimer.len();
    for r in a_supprimer { if dom.get_by_ref(r).is_some() { dom.destroy(r); } }
    // attributs / etiquettes des modeles de chaines (Station, Boucle, Coin, tag Station) : le montage les remettra
    for coin in ["NE", "NO", "SE", "SO"] {
        if let Some(r) = find_path(&dom, &format!("Workspace/MAP_MOTIFS_V17_AVEC_CHAINES/ChaineProduction_{}", coin)) {
            let inst = dom.get_by_ref_mut(r).unwrap();
            inst.properties.remove(&rbx_dom_weak::ustr("Attributes"));
            inst.properties.remove(&rbx_dom_weak::ustr("AttributesSerialize"));
            inst.properties.remove(&rbx_dom_weak::ustr("Tags"));
            inst.properties.remove(&rbx_dom_weak::ustr("PrimaryPart"));
        }
    }
    // eau du terrain
    if let Some(t) = find_path(&dom, "Workspace/Terrain") {
        dom.get_by_ref_mut(t).unwrap().properties.insert(rbx_dom_weak::ustr("SmoothGrid"), Variant::BinaryString(rbx_dom_weak::types::BinaryString::from(Vec::new())));
    }
    println!("supprime {} instances (installateurs)", n_sup);

    // 2) echelle + recalage de la map ---------------------------------------------------------------------------
    let sol = find_part_named(&dom, map, "Sol_Herbe_0_0").expect("Sol_Herbe_0_0 introuvable");
    let sol_cf = get_cframe(&dom, sol).unwrap(); let sol_sz = get_size(&dom, sol).unwrap();
    let k = 674.15f32 / sol_sz.x;
    let cible = Vector3::new(-1011.22, 0.0, 1011.22);
    println!("Sol_Herbe_0_0 avant : pos ({:.2}, {:.2}, {:.2}) taille {:.2} -> k = {:.6}", sol_cf.position.x, sol_cf.position.y, sol_cf.position.z, sol_sz.x, k);
    let mut all = Vec::new(); descendants(&dom, map, &mut all);
    let mut n = 0usize;
    for r in &all {
        if is_basepart(&dom.get_by_ref(*r).unwrap().class) { transformer(&mut dom, *r, sol_cf.position, cible, k, true); n += 1; }
        // pivot des modeles : on le retire, Roblox le recalculera (sinon il pointe sur l'ancienne position)
        else if dom.get_by_ref(*r).unwrap().class == "Model" { dom.get_by_ref_mut(*r).unwrap().properties.remove(&rbx_dom_weak::ustr("WorldPivotData")); }
    }
    dom.get_by_ref_mut(map).unwrap().properties.remove(&rbx_dom_weak::ustr("WorldPivotData"));
    let sol_cf2 = get_cframe(&dom, sol).unwrap(); let sol_sz2 = get_size(&dom, sol).unwrap();
    println!("map : {} pieces transformees ; Sol_Herbe_0_0 apres : pos ({:.2}, {:.2}, {:.2}) taille {:.2}", n, sol_cf2.position.x, sol_cf2.position.y, sol_cf2.position.z, sol_sz2.x);
    for nom in ["Voirie_0_0_", "CP_Tapis", "Tunnel_0", "Bloc_NE_a_1_proue__M_CP_Hall"] {
        if let Some(r) = find_part_named(&dom, map, nom) { let c = get_cframe(&dom, r).unwrap(); let s = get_size(&dom, r).unwrap(); println!("  {} : pos ({:.1}, {:.2}, {:.1}) taille ({:.1}, {:.1}, {:.1})", nom, c.position.x, c.position.y, c.position.z, s.x, s.y, s.z); }
    }

    // 3) bibliotheque d'arbres ------------------------------------------------------------------------------------
    if let Some(lib) = find_path(&dom, "ServerStorage/ARBRES_V17") {
        let a0 = find_part_named(&dom, lib, "Arbre_RP_0").expect("Arbre_RP_0 introuvable");
        let a0_sz = get_size(&dom, a0).unwrap();
        let ka = 22.973f32 / a0_sz.x;
        // centre de la bibliotheque = position du premier arbre (les positions dans la bibliotheque n'ont pas d'importance)
        let pivot = get_cframe(&dom, a0).unwrap().position;
        let mut all = Vec::new(); descendants(&dom, lib, &mut all);
        let mut m = 0usize;
        for r in &all {
            if is_basepart(&dom.get_by_ref(*r).unwrap().class) { transformer(&mut dom, *r, pivot, pivot, ka, false); m += 1; }
            else if dom.get_by_ref(*r).unwrap().class == "Model" { dom.get_by_ref_mut(*r).unwrap().properties.remove(&rbx_dom_weak::ustr("WorldPivotData")); }
        }
        dom.get_by_ref_mut(lib).unwrap().properties.remove(&rbx_dom_weak::ustr("WorldPivotData"));
        let s2 = get_size(&dom, a0).unwrap();
        println!("arbres : {} pieces, ka = {:.6}, Arbre_RP_0 = {:.2} studs de large", m, ka, s2.x);
    } else { println!("ATTENTION : ServerStorage/ARBRES_V17 introuvable"); }

    let mut count = 0usize;
    fn cnt(dom: &WeakDom, r: Ref, n: &mut usize) { *n += 1; for c in dom.get_by_ref(r).unwrap().children() { cnt(dom, *c, n); } }
    for c in dom.root().children() { cnt(&dom, *c, &mut count); }
    let out = BufWriter::new(File::create(&args[2]).expect("create out"));
    let refs: Vec<Ref> = dom.root().children().to_vec();
    rbx_binary::to_writer(out, &dom, &refs).expect("encode rbxl");
    println!("ECRIT {} ({} instances)", args[2], count);
}
