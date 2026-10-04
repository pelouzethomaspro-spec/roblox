use std::fs::File;
use std::io::BufReader;
use rbx_dom_weak::WeakDom;
use rbx_dom_weak::types::Ref;

fn walk(dom: &WeakDom, r: Ref, depth: usize, max_depth: usize, count: &mut usize) {
    let inst = dom.get_by_ref(r).unwrap();
    *count += 1;
    if depth <= max_depth {
        let script = matches!(inst.class.as_str(), "Script" | "LocalScript" | "ModuleScript");
        if depth <= 1 || script || inst.class == "Folder" || inst.class == "Model" && depth <= 2 {
            println!("{}{} ({})", "  ".repeat(depth), inst.name, inst.class);
        }
    }
    for c in inst.children() { walk(dom, *c, depth + 1, max_depth, count); }
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let f = BufReader::new(File::open(&args[1]).expect("open"));
    let dom = rbx_binary::from_reader(f).expect("DECODE FAILED");
    let mut count = 0usize;
    for c in dom.root().children() { walk(&dom, *c, 0, 3, &mut count); }
    println!("INSTANCES: {}", count);
    if args.len() > 2 {
        let out = File::create(&args[2]).expect("create");
        let refs: Vec<Ref> = dom.root().children().to_vec();
        rbx_xml::to_writer_default(out, &dom, &refs).expect("XML ENCODE FAILED");
        println!("XML OK");
    }
}
