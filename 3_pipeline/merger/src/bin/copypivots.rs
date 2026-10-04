// copypivots <source.rbxl> <destination.rbxl> <sortie.rbxl>
// Copie les pivots des constructions (ReplicatedStorage/Sol, Mur, Plafond, Furniture) calcules dans Studio
// (PivotOffset de la piece principale, PrimaryPart, WorldPivotData) de la place source vers la place destination,
// pour obtenir une base propre sans repasser par Studio.
use std::fs::File;
use std::io::{BufReader, BufWriter};
use rbx_dom_weak::{WeakDom, types::{Ref, Variant}};

fn child_named(dom: &WeakDom, parent: Ref, name: &str) -> Option<Ref> {
    dom.get_by_ref(parent)?.children().iter().copied().find(|c| dom.get_by_ref(*c).map(|i| i.name.as_str()) == Some(name))
}
fn find_path(dom: &WeakDom, path: &str) -> Option<Ref> {
    let mut cur = dom.root_ref();
    for part in path.split('/') { cur = child_named(dom, cur, part)?; }
    Some(cur)
}
fn descendants(dom: &WeakDom, r: Ref, out: &mut Vec<Ref>) {
    for c in dom.get_by_ref(r).unwrap().children() { out.push(*c); descendants(dom, *c, out); }
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let src = rbx_binary::from_reader(BufReader::new(File::open(&args[1]).expect("open src"))).expect("decode src");
    let mut dst = rbx_binary::from_reader(BufReader::new(File::open(&args[2]).expect("open dst"))).expect("decode dst");
    let mut copies = 0usize; let mut manques = Vec::new();
    for cat in ["Sol", "Mur", "Plafond", "Furniture"] {
        let Some(s_dir) = find_path(&src, &format!("ReplicatedStorage/{cat}")) else { continue };
        let Some(d_dir) = find_path(&dst, &format!("ReplicatedStorage/{cat}")) else { continue };
        for m in src.get_by_ref(s_dir).unwrap().children().to_vec() {
            let mi = src.get_by_ref(m).unwrap();
            if mi.class != "Model" { continue }
            let Some(Variant::Ref(pp)) = mi.properties.get(&rbx_dom_weak::ustr("PrimaryPart")) else { continue };
            let Some(ppi) = src.get_by_ref(*pp) else { continue };
            let pp_name = ppi.name.clone();
            let Some(Variant::CFrame(off)) = ppi.properties.get(&rbx_dom_weak::ustr("PivotOffset")).cloned() else { continue };
            let wp = mi.properties.get(&rbx_dom_weak::ustr("WorldPivotData")).cloned();
            let Some(dm) = child_named(&dst, d_dir, &mi.name) else { manques.push(format!("{cat}/{}", mi.name)); continue };
            let mut all = Vec::new(); descendants(&dst, dm, &mut all);
            let Some(dp) = all.into_iter().find(|r| dst.get_by_ref(*r).unwrap().name == pp_name) else { manques.push(format!("{cat}/{}/{}", mi.name, pp_name)); continue };
            dst.get_by_ref_mut(dp).unwrap().properties.insert(rbx_dom_weak::ustr("PivotOffset"), Variant::CFrame(off));
            let dmi = dst.get_by_ref_mut(dm).unwrap();
            dmi.properties.insert(rbx_dom_weak::ustr("PrimaryPart"), Variant::Ref(dp));
            if let Some(w) = wp { dmi.properties.insert(rbx_dom_weak::ustr("WorldPivotData"), w); }
            copies += 1;
        }
    }
    let out = BufWriter::new(File::create(&args[3]).expect("create out"));
    let refs: Vec<Ref> = dst.root().children().to_vec();
    rbx_binary::to_writer(out, &dst, &refs).expect("encode rbxl");
    println!("pivots copies : {copies} ; introuvables : {}", manques.len());
    for m in manques { println!("  manque {m}"); }
}
