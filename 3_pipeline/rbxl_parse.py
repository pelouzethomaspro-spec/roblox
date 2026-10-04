#!/usr/bin/env python3
"""Minimal Roblox binary place (.rbxl) decoder: hierarchy + string/scalar props."""
import struct, sys, os, json, re
import lz4.block, zstandard

MAGIC = b"<roblox!\x89\xff\r\n\x1a\n"

def read_chunks(data):
    assert data[:14] == MAGIC, "not a binary rbxl"
    version, nclasses, ninst = struct.unpack_from("<HII", data, 14)
    pos = 14 + 2 + 4 + 4 + 8
    chunks = []
    while pos < len(data):
        name = data[pos:pos+4]; pos += 4
        clen, ulen, _res = struct.unpack_from("<III", data, pos); pos += 12
        if clen == 0:
            payload = data[pos:pos+ulen]; pos += ulen
        else:
            raw = data[pos:pos+clen]; pos += clen
            if raw[:4] == b"\x28\xb5\x2f\xfd":
                payload = zstandard.ZstdDecompressor().decompress(raw, max_output_size=ulen)
            else:
                payload = lz4.block.decompress(raw, uncompressed_size=ulen)
        chunks.append((name, payload))
        if name == b"END\x00":
            break
    return nclasses, ninst, chunks

def deinterleave(buf, count, width):
    out = bytearray(count*width)
    for i in range(count):
        for j in range(width):
            out[i*width+j] = buf[j*count+i]
    return bytes(out)

def read_interleaved_i32(buf, count):
    b = deinterleave(buf, count, 4)
    vals = struct.unpack(f">{count}i", b)
    # zigzag decode
    return [ (v >> 1) ^ -(v & 1) for v in vals ]

def read_interleaved_u32(buf, count):
    b = deinterleave(buf, count, 4)
    return list(struct.unpack(f">{count}I", b))

def read_referents(buf, count):
    vals = read_interleaved_i32(buf, count)
    acc = 0; out = []
    for v in vals:
        acc += v; out.append(acc)
    return out

def read_string(buf, pos):
    (n,) = struct.unpack_from("<I", buf, pos); pos += 4
    return buf[pos:pos+n], pos+n

def read_interleaved_f32(buf, count):
    b = deinterleave(buf, count, 4)
    out = []
    for i in range(count):
        u = struct.unpack_from(">I", b, i*4)[0]
        u = ((u >> 1) | ((u & 1) << 31)) & 0xffffffff
        out.append(struct.unpack("<f", struct.pack("<I", u))[0])
    return out

def parse(path):
    data = open(path, "rb").read()
    nclasses, ninst, chunks = read_chunks(data)
    classes = {}   # classId -> (name, [referents], isService)
    inst = {}      # referent -> dict
    sstr = []
    for name, p in chunks:
        if name == b"SSTR":
            pos = 4
            (cnt,) = struct.unpack_from("<I", p, pos); pos += 4
            for _ in range(cnt):
                pos += 16  # md5
                s, pos = read_string(p, pos)
                sstr.append(s)
        elif name == b"INST":
            pos = 0
            (cid,) = struct.unpack_from("<i", p, pos); pos += 4
            cname, pos = read_string(p, pos)
            fmt = p[pos]; pos += 1
            (cnt,) = struct.unpack_from("<I", p, pos); pos += 4
            refs = read_referents(p[pos:pos+4*cnt], cnt); pos += 4*cnt
            classes[cid] = (cname.decode(), refs)
            for r in refs:
                inst[r] = {"ClassName": cname.decode(), "ref": r, "props": {}, "children": [], "parent": -1}
    for name, p in chunks:
        if name != b"PROP":
            continue
        pos = 0
        (cid,) = struct.unpack_from("<i", p, pos); pos += 4
        pname, pos = read_string(p, pos)
        pname = pname.decode()
        typ = p[pos]; pos += 1
        cname, refs = classes[cid]
        cnt = len(refs)
        vals = None
        try:
            if typ == 0x01:  # String
                vals = []
                for _ in range(cnt):
                    s, pos = read_string(p, pos); vals.append(s)
            elif typ == 0x02:
                vals = [bool(b) for b in p[pos:pos+cnt]]
            elif typ == 0x03:
                vals = read_interleaved_i32(p[pos:pos+4*cnt], cnt)
            elif typ == 0x04:
                vals = read_interleaved_f32(p[pos:pos+4*cnt], cnt)
            elif typ == 0x05:
                vals = list(struct.unpack_from(f"<{cnt}d", p, pos))
            elif typ == 0x12:
                vals = read_interleaved_u32(p[pos:pos+4*cnt], cnt)
            elif typ == 0x13:
                vals = read_referents(p[pos:pos+4*cnt], cnt)
            elif typ == 0x1B:
                b = deinterleave(p[pos:pos+8*cnt], cnt, 8)
                raw = struct.unpack(f">{cnt}q", b)
                vals = [ (v >> 1) ^ -(v & 1) for v in raw ]
            elif typ == 0x1C:
                idx = read_interleaved_u32(p[pos:pos+4*cnt], cnt)
                vals = [sstr[i] for i in idx]
            elif typ == 0x0E:  # Vector3
                x = read_interleaved_f32(p[pos:pos+4*cnt], cnt); pos += 4*cnt
                y = read_interleaved_f32(p[pos:pos+4*cnt], cnt); pos += 4*cnt
                z = read_interleaved_f32(p[pos:pos+4*cnt], cnt)
                vals = [(round(a,2),round(b,2),round(c,2)) for a,b,c in zip(x,y,z)]
            else:
                vals = [f"<type 0x{typ:02x}>"] * cnt
        except Exception as e:
            vals = [f"<err {e}>"] * cnt
        for r, v in zip(refs, vals):
            inst[r]["props"][pname] = v
    for name, p in chunks:
        if name != b"PRNT":
            continue
        pos = 1
        (cnt,) = struct.unpack_from("<I", p, pos); pos += 4
        kids = read_referents(p[pos:pos+4*cnt], cnt); pos += 4*cnt
        pars = read_referents(p[pos:pos+4*cnt], cnt)
        for k, pa in zip(kids, pars):
            inst[k]["parent"] = pa
            if pa in inst:
                inst[pa]["children"].append(k)
    return inst

def name_of(i):
    n = i["props"].get("Name", b"?")
    return n.decode("utf-8", "replace") if isinstance(n, bytes) else str(n)

def path_of(inst, r):
    parts = []
    while r in inst:
        parts.append(name_of(inst[r])); r = inst[r]["parent"]
    return "/".join(reversed(parts))

SCRIPT_CLASSES = {"Script", "LocalScript", "ModuleScript"}

def dump(inst, outdir):
    os.makedirs(outdir, exist_ok=True)
    roots = [r for r, i in inst.items() if i["parent"] not in inst]
    lines = []
    def walk(r, depth):
        i = inst[r]
        extra = ""
        if i["ClassName"] in SCRIPT_CLASSES:
            src = i["props"].get("Source", b"")
            n = len(src.splitlines()) if isinstance(src, bytes) else 0
            flags = []
            if i["props"].get("Disabled"): flags.append("DISABLED")
            if i["props"].get("Enabled") is False: flags.append("DISABLED")
            rc = i["props"].get("RunContext")
            if rc is not None and i["ClassName"] == "Script":
                flags.append({0:"Legacy",1:"Server",2:"Client",3:"Plugin"}.get(rc, str(rc)))
            extra = f"  [{n} lines{' ' + ' '.join(flags) if flags else ''}]"
        elif i["ClassName"] in ("StringValue","IntValue","NumberValue","BoolValue","ObjectValue"):
            v = i["props"].get("Value")
            if isinstance(v, bytes): v = v.decode("utf-8","replace")
            elif i["ClassName"]=="ObjectValue" and v in inst: v = "-> " + path_of(inst, v)
            extra = f"  = {v!r}"
        attrs = i["props"].get("AttributesSerialize")
        if isinstance(attrs, bytes) and len(attrs) > 4:
            extra += f"  {{attrs:{len(attrs)}B}}"
        lines.append("  "*depth + f"{name_of(i)} ({i['ClassName']}){extra}")
        for c in sorted(i["children"], key=lambda c: (inst[c]["ClassName"] not in SCRIPT_CLASSES, name_of(inst[c]))):
            walk(c, depth+1)
    for r in roots:
        for c in inst[r]["children"] if inst[r]["ClassName"]=="DataModel" else [r]:
            walk(c, 0)
    open(os.path.join(outdir, "TREE.txt"), "w").write("\n".join(lines))
    # scripts
    count = 0
    for r, i in inst.items():
        if i["ClassName"] in SCRIPT_CLASSES:
            src = i["props"].get("Source", b"")
            if not isinstance(src, bytes): src = b""
            p = path_of(inst, r)
            safe = re.sub(r"[^A-Za-z0-9_./-]", "_", p)
            ext = {"Script": ".server.lua", "LocalScript": ".client.lua", "ModuleScript": ".lua"}[i["ClassName"]]
            fp = os.path.join(outdir, "scripts", safe + ext)
            os.makedirs(os.path.dirname(fp), exist_ok=True)
            open(fp, "wb").write(src)
            count += 1
    return len(lines), count

if __name__ == "__main__":
    inst = parse(sys.argv[1])
    n, c = dump(inst, sys.argv[2])
    print(f"{len(inst)} instances, {n} tree lines, {c} scripts")
