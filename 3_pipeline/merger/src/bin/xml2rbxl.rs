// xml2rbxl in.rbxlx out.rbxl : convertit une place XML en binaire
use std::fs::File; use std::io::{BufReader, BufWriter};
fn main() {
    let a: Vec<String> = std::env::args().collect();
    let dom = rbx_xml::from_reader_default(BufReader::new(File::open(&a[1]).expect("open"))).expect("decode rbxlx");
    let refs: Vec<_> = dom.root().children().to_vec();
    rbx_binary::to_writer(BufWriter::new(File::create(&a[2]).expect("create")), &dom, &refs).expect("encode");
    println!("OK {} instances", dom.descendants_of(dom.root_ref()).count());
}
