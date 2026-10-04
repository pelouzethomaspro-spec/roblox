// merger <in.rbxl> <ui.rbxlx> <out.rbxl> [--delete=Path/To/Inst]... [--source=Path/To/Script=file.lua]...
// Remplace le contenu de StarterGui de la place par celui du fichier XML, puis applique suppressions et sources.
use std::fs::File;
use std::io::{BufReader, BufWriter};
use rbx_dom_weak::{WeakDom, types::{Ref, Variant}};

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


// harmonise les types de proprietes du XML avec la base de reflexion (le generateur d'UI ecrit par ex. des float
// pour BorderSizePixel qui est un Int32) ; les proprietes inconnues sont retirees pour que l'ecriture binaire passe
fn coerce(dom: &mut WeakDom, r: Ref, fixed: &mut usize, dropped: &mut usize) {
    use rbx_reflection::{DataType, PropertyKind};
    let db = rbx_reflection_database::get().expect("base de reflexion");
    let kids: Vec<Ref> = dom.get_by_ref(r).unwrap().children().to_vec();
    {
        let inst = dom.get_by_ref_mut(r).unwrap();
        let class = inst.class.clone();
        let mut edits: Vec<(rbx_dom_weak::Ustr, Option<Variant>)> = Vec::new();
        for (name, value) in inst.properties.iter() {
            // recherche du descripteur en remontant les superclasses
            let mut cls = db.classes.get(class.as_str());
            let mut desc = None;
            while let Some(c) = cls {
                if let Some(d) = c.properties.get(name.as_str()) { desc = Some(d); break; }
                let sup: Option<String> = c.superclass.as_ref().map(|s| s.to_string());
                cls = match sup { Some(n) => db.classes.get(n.as_str()), None => None };
            }
            let Some(d) = desc else { edits.push((*name, None)); continue; };
            let PropertyKind::Canonical { serialization: _ } = &d.kind else { continue; };
            let DataType::Value(expected) = &d.data_type else { continue; };
            if &value.ty() == expected { continue; }
            let conv = match (value, expected) {
                (Variant::Float32(f), rbx_dom_weak::types::VariantType::Int32) => Some(Variant::Int32(f.round() as i32)),
                (Variant::Float64(f), rbx_dom_weak::types::VariantType::Int32) => Some(Variant::Int32(f.round() as i32)),
                (Variant::Int32(i), rbx_dom_weak::types::VariantType::Float32) => Some(Variant::Float32(*i as f32)),
                (Variant::Float64(f), rbx_dom_weak::types::VariantType::Float32) => Some(Variant::Float32(*f as f32)),
                (Variant::Int32(i), rbx_dom_weak::types::VariantType::Int64) => Some(Variant::Int64(*i as i64)),
                (Variant::Int32(i), rbx_dom_weak::types::VariantType::Float64) => Some(Variant::Float64(*i as f64)),
                (Variant::Float32(f), rbx_dom_weak::types::VariantType::Float64) => Some(Variant::Float64(*f as f64)),
                (Variant::Color3uint8(c), rbx_dom_weak::types::VariantType::Color3) => Some(Variant::Color3(rbx_dom_weak::types::Color3::new(c.r as f32 / 255.0, c.g as f32 / 255.0, c.b as f32 / 255.0))),
                _ => None,
            };
            match conv { Some(v) => edits.push((*name, Some(v))), None => { println!("ATTENTION: {}.{} type {:?} attendu {:?} : retire", class, name, value.ty(), expected); edits.push((*name, None)); } }
        }
        for (k, v) in edits {
            match v { Some(v) => { inst.properties.insert(k, v); *fixed += 1; } None => { inst.properties.remove(&k); *dropped += 1; } }
        }
    }
    for c in kids { coerce(dom, c, fixed, dropped); }
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let mut dom = rbx_binary::from_reader(BufReader::new(File::open(&args[1]).expect("open in"))).expect("decode rbxl");
    let mut ui = rbx_xml::from_reader_default(BufReader::new(File::open(&args[2]).expect("open xml"))).expect("decode rbxlx");
    // --keep=Nom : enfant de StarterGui de la place a conserver (et a ne pas prendre du XML)
    let keep: Vec<String> = args[4..].iter().filter_map(|a| a.strip_prefix("--keep=").map(|s| s.to_string())).collect();
    let sg = find_path(&dom, "StarterGui").expect("StarterGui absent de la place");
    let old: Vec<Ref> = dom.get_by_ref(sg).unwrap().children().to_vec();
    for c in old {
        let n = dom.get_by_ref(c).unwrap().name.clone();
        if keep.contains(&n) { println!("conserve StarterGui/{}", n); continue; }
        println!("supprime StarterGui/{}", n); dom.destroy(c);
    }
    let sg2 = find_path(&ui, "StarterGui").expect("StarterGui absent du XML");
    let (mut fixed, mut dropped) = (0usize, 0usize);
    coerce(&mut ui, sg2, &mut fixed, &mut dropped);
    println!("XML : {} proprietes converties, {} retirees", fixed, dropped);
    let kids: Vec<Ref> = ui.get_by_ref(sg2).unwrap().children().to_vec();
    for c in kids {
        let n = ui.get_by_ref(c).unwrap().name.clone();
        if keep.contains(&n) { println!("ignore (XML) StarterGui/{}", n); continue; }
        ui.transfer(c, &mut dom, sg); println!("ajoute StarterGui/{}", n);
    }
    for a in &args[4..] {
        if a.starts_with("--keep=") { continue; }
        if let Some(p) = a.strip_prefix("--delete=") {
            match find_path(&dom, p) { Some(r) => { dom.destroy(r); println!("supprime {}", p); } None => println!("ATTENTION: introuvable {}", p) }
        } else if let Some(rest) = a.strip_prefix("--delete-sans=") {
            // --delete-sans=Parent/Path/Name=Enfant : supprime tous les enfants nommes Name du parent qui n'ont PAS d'enfant Enfant
            let (p, enfant) = rest.split_once('=').expect("--delete-sans=Path=Enfant");
            let (parent_path, name) = p.rsplit_once('/').expect("--delete-sans : Parent/Name");
            let parent = find_path(&dom, parent_path).unwrap_or_else(|| panic!("parent introuvable {}", parent_path));
            let kids: Vec<Ref> = dom.get_by_ref(parent).unwrap().children().to_vec();
            let mut n = 0usize;
            for c in kids {
                let inst = dom.get_by_ref(c).unwrap();
                if inst.name == name {
                    let a_enfant = inst.children().iter().any(|k| dom.get_by_ref(*k).map(|i| i.name == enfant).unwrap_or(false));
                    if !a_enfant { dom.destroy(c); n += 1; }
                }
            }
            println!("supprime {} instance(s) {} sans enfant {}", n, p, enfant);
        } else if let Some(p) = a.strip_prefix("--vider=") {
            // supprime tous les enfants d'un dossier (ex. ReplicatedStorage/Sol) avant d'y inserer les nouveaux modeles
            let r = find_path(&dom, p).unwrap_or_else(|| panic!("dossier introuvable {}", p));
            let kids: Vec<Ref> = dom.get_by_ref(r).unwrap().children().to_vec();
            let n = kids.len();
            for c in kids { dom.destroy(c); }
            println!("vide {} ({} enfants)", p, n);
        } else if let Some(rest) = a.strip_prefix("--insert=") {
            // --insert=Path/To/Parent=file.rbxmx : ajoute chaque Item racine du XML dans le parent (remplace un enfant de meme nom)
            let (p, f) = rest.split_once('=').expect("--insert=Path=file");
            let parent = find_path(&dom, p).unwrap_or_else(|| panic!("parent introuvable {}", p));
            let mut modele = rbx_xml::from_reader_default(BufReader::new(File::open(f).expect("open rbxmx"))).expect("decode rbxmx");
            let (mut fx, mut dr) = (0usize, 0usize);
            let roots: Vec<Ref> = modele.root().children().to_vec();
            for r in &roots { coerce(&mut modele, *r, &mut fx, &mut dr); }
            let mut n = 0usize;
            for r in roots {
                let name = modele.get_by_ref(r).unwrap().name.clone();
                let existing: Vec<Ref> = dom.get_by_ref(parent).unwrap().children().iter().copied()
                    .filter(|c| dom.get_by_ref(*c).map(|i| i.name == name).unwrap_or(false)).collect();
                for e in existing { dom.destroy(e); }
                modele.transfer(r, &mut dom, parent); n += 1;
            }
            println!("insere {} modeles dans {} depuis {} ({} proprietes converties, {} retirees)", n, p, f, fx, dr);
        } else if let Some(rest) = a.strip_prefix("--prop=") {
            // --prop=Path/To/Inst.Prop=type:value  (types : bool, float, int, string, binary (vide autorise), enum)
            let (cible, val) = rest.split_once('=').expect("--prop=Path.Prop=type:value");
            let (p, prop) = cible.rsplit_once('.').expect("--prop : Path.Prop");
            let (ty, v) = val.split_once(':').expect("--prop : type:value");
            let r = find_path(&dom, p).unwrap_or_else(|| panic!("instance introuvable {}", p));
            let variant = match ty {
                "bool" => Variant::Bool(v == "true"),
                "float" => Variant::Float32(v.parse().expect("float")),
                "int" => Variant::Int32(v.parse().expect("int")),
                "string" => Variant::String(v.to_string()),
                "binary" => Variant::BinaryString(rbx_dom_weak::types::BinaryString::from(v.as_bytes().to_vec())),
                "enum" => Variant::Enum(rbx_dom_weak::types::Enum::from_u32(v.parse().expect("enum"))),
                _ => panic!("type de --prop inconnu {}", ty),
            };
            dom.get_by_ref_mut(r).unwrap().properties.insert(rbx_dom_weak::ustr(prop), variant);
            println!("propriete {}.{} = {}:{}", p, prop, ty, if v.len() > 40 { "..." } else { v });
        } else if let Some(rest) = a.strip_prefix("--source=") {
            let (p, f) = rest.split_once('=').expect("--source=Path=file");
            let r = find_path(&dom, p).unwrap_or_else(|| panic!("script introuvable {}", p));
            let src = std::fs::read_to_string(f).expect("lecture source").replace("\r\n", "\n");
            let inst = dom.get_by_ref_mut(r).unwrap();
            let key = rbx_dom_weak::ustr("Source");
            let v = match inst.properties.get(&key) {
                Some(Variant::String(_)) => Variant::String(src.clone()),
                _ => Variant::String(src.clone()),
            };
            inst.properties.insert(key, v);
            println!("source {} <- {} ({} octets)", p, f, src.len());
        }
    }
    let mut count = 0usize;
    fn cnt(dom: &WeakDom, r: Ref, n: &mut usize) { *n += 1; for c in dom.get_by_ref(r).unwrap().children() { cnt(dom, *c, n); } }
    for c in dom.root().children() { cnt(&dom, *c, &mut count); }
    let out = BufWriter::new(File::create(&args[3]).expect("create out"));
    let refs: Vec<Ref> = dom.root().children().to_vec();
    rbx_binary::to_writer(out, &dom, &refs).expect("encode rbxl");
    println!("ECRIT {} ({} instances)", args[3], count);
}
