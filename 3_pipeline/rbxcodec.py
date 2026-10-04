"""Lossless codec for the Roblox binary place/model format (.rbxl / .rbxm).

Every PROP chunk is decoded into a list of per-instance *elements* (raw bytes or small tuples) so that
instances can be filtered / concatenated / remapped, then re-encoded byte-for-byte identically.
"""
import struct
import lz4.block
import zstandard

MAGIC = b"<roblox!\x89\xff\r\n\x1a\n"


# ----------------------------------------------------------------------------------------------------------------
# low level helpers
# ----------------------------------------------------------------------------------------------------------------
def deinterleave(buf, count, width):
    if count == 0:
        return []
    out = [bytearray(width) for _ in range(count)]
    for j in range(width):
        base = j * count
        for i in range(count):
            out[i][j] = buf[base + i]
    return [bytes(o) for o in out]


def interleave(elems, width):
    count = len(elems)
    out = bytearray(count * width)
    for i, e in enumerate(elems):
        for j in range(width):
            out[j * count + i] = e[j]
    return bytes(out)


def zz_dec(v):
    return (v >> 1) ^ -(v & 1)


def zz_enc(v):
    return (v << 1) ^ (v >> 63) if v < 0 else (v << 1)


def read_str(buf, pos):
    (n,) = struct.unpack_from("<I", buf, pos)
    pos += 4
    return buf[pos:pos + n], pos + n


def write_str(s):
    return struct.pack("<I", len(s)) + s


def read_refs(buf, pos, count):
    elems = deinterleave(buf[pos:pos + 4 * count], count, 4)
    acc, out = 0, []
    for e in elems:
        acc += zz_dec(struct.unpack(">I", e)[0])
        out.append(acc)
    return out, pos + 4 * count


def write_refs(refs):
    elems, prev = [], 0
    for r in refs:
        d = r - prev
        prev = r
        elems.append(struct.pack(">I", zz_enc(d) & 0xFFFFFFFF))
    return interleave(elems, 4)


# ----------------------------------------------------------------------------------------------------------------
# property value codecs : decode(buf, pos, count) -> (elements, pos) ; encode(elements) -> bytes
# elements are opaque per-instance payloads except for types we must interpret (Referent, SharedString, String, CFrame)
# ----------------------------------------------------------------------------------------------------------------
def _dec_interleaved(width):
    def dec(buf, pos, count):
        return deinterleave(buf[pos:pos + width * count], count, width), pos + width * count
    def enc(elems):
        return interleave(elems, width)
    return dec, enc


def _dec_plain(width):
    def dec(buf, pos, count):
        return [buf[pos + i * width:pos + (i + 1) * width] for i in range(count)], pos + width * count
    def enc(elems):
        return b"".join(elems)
    return dec, enc


def _dec_multi_interleaved(n_arrays, width):
    """n separate interleaved arrays (e.g. Vector3 = 3 x f32) -> element = tuple of n raw chunks"""
    def dec(buf, pos, count):
        arrays = []
        for _ in range(n_arrays):
            arrays.append(deinterleave(buf[pos:pos + width * count], count, width))
            pos += width * count
        return [tuple(a[i] for a in arrays) for i in range(count)], pos
    def enc(elems):
        return b"".join(interleave([e[k] for e in elems], width) for k in range(n_arrays))
    return dec, enc


def dec_string(buf, pos, count):
    out = []
    for _ in range(count):
        s, pos = read_str(buf, pos)
        out.append(s)
    return out, pos


def enc_string(elems):
    return b"".join(write_str(s) for s in elems)


def dec_bool(buf, pos, count):
    return [buf[pos + i:pos + i + 1] for i in range(count)], pos + count


def enc_bool(elems):
    return b"".join(elems)


def dec_udim(buf, pos, count):  # scale f32 interleaved, offset i32 interleaved
    a = deinterleave(buf[pos:pos + 4 * count], count, 4); pos += 4 * count
    b = deinterleave(buf[pos:pos + 4 * count], count, 4); pos += 4 * count
    return list(zip(a, b)), pos


def enc_udim(elems):
    return interleave([e[0] for e in elems], 4) + interleave([e[1] for e in elems], 4)


def dec_cframe_array(buf, pos, count):
    rots = []
    for _ in range(count):
        rid = buf[pos]; pos += 1
        if rid == 0:
            rots.append(buf[pos - 1:pos + 36]); pos += 36
        else:
            rots.append(buf[pos - 1:pos])
    xs = deinterleave(buf[pos:pos + 4 * count], count, 4); pos += 4 * count
    ys = deinterleave(buf[pos:pos + 4 * count], count, 4); pos += 4 * count
    zs = deinterleave(buf[pos:pos + 4 * count], count, 4); pos += 4 * count
    return [(rots[i], xs[i], ys[i], zs[i]) for i in range(count)], pos


def enc_cframe_array(elems):
    return (b"".join(e[0] for e in elems) + interleave([e[1] for e in elems], 4)
            + interleave([e[2] for e in elems], 4) + interleave([e[3] for e in elems], 4))


def dec_optional_cframe(buf, pos, count):
    assert buf[pos] == 0x10, "OptionalCFrame: expected CFrame marker"
    pos += 1
    cfs, pos = dec_cframe_array(buf, pos, count)
    assert buf[pos] == 0x02, "OptionalCFrame: expected Bool marker"
    pos += 1
    flags = [buf[pos + i:pos + i + 1] for i in range(count)]
    pos += count
    return [(cfs[i], flags[i]) for i in range(count)], pos


def enc_optional_cframe(elems):
    return b"\x10" + enc_cframe_array([e[0] for e in elems]) + b"\x02" + b"".join(e[1] for e in elems)


def dec_refs_prop(buf, pos, count):
    refs, pos = read_refs(buf, pos, count)
    return refs, pos  # elements are ints (absolute referents, -1 = null)


def enc_refs_prop(elems):
    return write_refs(elems)


def dec_number_sequence(buf, pos, count):
    out = []
    for _ in range(count):
        (n,) = struct.unpack_from("<I", buf, pos)
        end = pos + 4 + 12 * n
        out.append(buf[pos:end]); pos = end
    return out, pos


def dec_color_sequence(buf, pos, count):
    out = []
    for _ in range(count):
        (n,) = struct.unpack_from("<I", buf, pos)
        end = pos + 4 + 20 * n
        out.append(buf[pos:end]); pos = end
    return out, pos


def dec_physical(buf, pos, count):
    out = []
    for _ in range(count):
        kind = buf[pos]                       # 0 / 2 : proprietes par defaut (pas de charge utile) ; 1 : 5 f32 ; 3 : 6 f32 (observe : 0x02)
        end = pos + 1 + ({1: 20, 3: 24}.get(kind, 0))
        out.append(buf[pos:end]); pos = end
    return out, pos


def dec_color3u8(buf, pos, count):
    r = buf[pos:pos + count]; g = buf[pos + count:pos + 2 * count]; b = buf[pos + 2 * count:pos + 3 * count]
    return [(r[i:i + 1], g[i:i + 1], b[i:i + 1]) for i in range(count)], pos + 3 * count


def enc_color3u8(elems):
    return b"".join(e[0] for e in elems) + b"".join(e[1] for e in elems) + b"".join(e[2] for e in elems)


def dec_sharedstring(buf, pos, count):
    elems = deinterleave(buf[pos:pos + 4 * count], count, 4)
    return [struct.unpack(">I", e)[0] for e in elems], pos + 4 * count  # ints (indices into SSTR)


def enc_sharedstring(elems):
    return interleave([struct.pack(">I", i) for i in elems], 4)


def dec_font(buf, pos, count):
    out = []
    for _ in range(count):
        start = pos
        _, pos = read_str(buf, pos)      # family
        pos += 2 + 1                     # weight u16, style u8
        _, pos = read_str(buf, pos)      # cached face id
        out.append(buf[start:pos])
    return out, pos


def dec_content(buf, pos, count):
    """Content (0x22) as observed : one interleaved i32 source type per instance (0 = None, 1 = Uri, 2 = Object,
    3 = External), then u32 uriCount + Strings, u32 objectCount + interleaved referents, u32 externalCount + u32s.
    Element = (sourceType int, payload)."""
    types_ = [zz_dec(struct.unpack(">I", e)[0]) for e in deinterleave(buf[pos:pos + 4 * count], count, 4)]; pos += 4 * count   # i32 entrelaces zigzag
    (n_uri,) = struct.unpack_from("<I", buf, pos); pos += 4
    uris = []
    for _ in range(n_uri):
        s, pos = read_str(buf, pos); uris.append(s)
    (n_obj,) = struct.unpack_from("<I", buf, pos); pos += 4
    objs, pos = read_refs(buf, pos, n_obj)
    (n_ext,) = struct.unpack_from("<I", buf, pos); pos += 4
    exts = deinterleave(buf[pos:pos + 4 * n_ext], n_ext, 4); pos += 4 * n_ext
    out, iu, io, ie = [], 0, 0, 0
    for t in types_:
        if t == 1:
            out.append((1, uris[iu])); iu += 1
        elif t == 2:
            out.append((2, objs[io])); io += 1
        elif t == 3:
            out.append((3, exts[ie])); ie += 1
        else:
            out.append((t, None))
    assert iu == n_uri and io == n_obj and ie == n_ext, "Content: counts mismatch"
    return out, pos


def enc_content(elems):
    types_ = interleave([struct.pack(">I", zz_enc(e[0]) & 0xFFFFFFFF) for e in elems], 4)
    uris = [e[1] for e in elems if e[0] == 1]
    objs = [e[1] for e in elems if e[0] == 2]
    exts = [e[1] for e in elems if e[0] == 3]
    return (types_ + struct.pack("<I", len(uris)) + b"".join(write_str(u) for u in uris)
            + struct.pack("<I", len(objs)) + write_refs(objs)
            + struct.pack("<I", len(exts)) + interleave(exts, 4))


def _plain_join(elems):
    return b"".join(elems)


CODECS = {
    0x01: (dec_string, enc_string),
    0x02: (dec_bool, enc_bool),
    0x03: _dec_interleaved(4),
    0x04: _dec_interleaved(4),
    0x05: _dec_plain(8),
    0x06: (dec_udim, enc_udim),
    0x07: _dec_multi_interleaved(4, 4),
    0x08: _dec_plain(24),
    0x09: _dec_plain(1),
    0x0A: _dec_plain(1),
    0x0B: _dec_interleaved(4),
    0x0C: _dec_multi_interleaved(3, 4),
    0x0D: _dec_multi_interleaved(2, 4),
    0x0E: _dec_multi_interleaved(3, 4),
    0x10: (dec_cframe_array, enc_cframe_array),
    0x12: _dec_interleaved(4),
    0x13: (dec_refs_prop, enc_refs_prop),
    0x14: _dec_plain(6),
    0x15: (dec_number_sequence, _plain_join),
    0x16: (dec_color_sequence, _plain_join),
    0x17: _dec_plain(8),
    0x18: _dec_multi_interleaved(4, 4),
    0x19: (dec_physical, _plain_join),
    0x1A: (dec_color3u8, enc_color3u8),
    0x1B: _dec_interleaved(8),
    0x1C: (dec_sharedstring, enc_sharedstring),
    0x1E: (dec_optional_cframe, enc_optional_cframe),
    0x1F: _dec_interleaved(16),
    0x20: (dec_font, _plain_join),
    0x21: _dec_interleaved(8),
    0x22: (dec_content, enc_content),
}


# ----------------------------------------------------------------------------------------------------------------
# file model
# ----------------------------------------------------------------------------------------------------------------
class RbxFile:
    def __init__(self):
        self.meta = []          # list of (key, value) bytes
        self.sstr = []          # list of (md5 bytes(16), payload bytes)
        self.classes = {}       # cid -> dict(name, fmt, refs[list], markers[bytes or None])
        self.class_order = []   # cids in file order
        self.props = []         # list of dict(cid, name, typ, elems[list])
        self.parent = {}        # child ref -> parent ref
        self.prnt_order = []    # child refs in PRNT order


def read(path):
    data = open(path, "rb").read()
    assert data[:14] == MAGIC, "not a Roblox binary file"
    version, nclasses, ninst = struct.unpack_from("<HII", data, 14)
    pos = 14 + 2 + 8 + 8
    f = RbxFile()
    while pos < len(data):
        name = data[pos:pos + 4]; pos += 4
        clen, ulen, _ = struct.unpack_from("<III", data, pos); pos += 12
        if clen == 0:
            payload = data[pos:pos + ulen]; pos += ulen
        else:
            raw = data[pos:pos + clen]; pos += clen
            if raw[:4] == b"\x28\xb5\x2f\xfd":
                payload = zstandard.ZstdDecompressor().decompress(raw, max_output_size=ulen)
            else:
                payload = lz4.block.decompress(raw, uncompressed_size=ulen)
        p = payload
        if name == b"META":
            q = 0
            (cnt,) = struct.unpack_from("<I", p, q); q += 4
            for _ in range(cnt):
                k, q = read_str(p, q); v, q = read_str(p, q)
                f.meta.append((k, v))
        elif name == b"SSTR":
            q = 4
            (cnt,) = struct.unpack_from("<I", p, q); q += 4
            for _ in range(cnt):
                md5 = p[q:q + 16]; q += 16
                s, q = read_str(p, q)
                f.sstr.append((md5, s))
        elif name == b"INST":
            q = 0
            (cid,) = struct.unpack_from("<i", p, q); q += 4
            cname, q = read_str(p, q)
            fmt = p[q]; q += 1
            (cnt,) = struct.unpack_from("<I", p, q); q += 4
            refs, q = read_refs(p, q, cnt)
            markers = None
            if fmt == 1:
                markers = p[q:q + cnt]; q += cnt
            assert q == len(p), f"INST {cname}: trailing bytes"
            f.classes[cid] = dict(name=cname.decode(), fmt=fmt, refs=refs, markers=markers)
            f.class_order.append(cid)
        elif name == b"PROP":
            q = 0
            (cid,) = struct.unpack_from("<i", p, q); q += 4
            pname, q = read_str(p, q)
            typ = p[q]; q += 1
            cnt = len(f.classes[cid]["refs"])
            if typ not in CODECS:
                raise ValueError(f"unsupported property type 0x{typ:02x} ({f.classes[cid]['name']}.{pname.decode()})")
            dec, enc = CODECS[typ]
            elems, q2 = dec(p, q, cnt)
            if q2 != len(p):
                raise ValueError(f"PROP {f.classes[cid]['name']}.{pname.decode()} type 0x{typ:02x}: consumed {q2 - q} of {len(p) - q}")
            # lossless check
            if enc(elems) != p[q:]:
                raise ValueError(f"PROP {f.classes[cid]['name']}.{pname.decode()} type 0x{typ:02x}: re-encode mismatch")
            f.props.append(dict(cid=cid, name=pname.decode(), typ=typ, elems=elems))
        elif name == b"PRNT":
            q = 1
            (cnt,) = struct.unpack_from("<I", p, q); q += 4
            kids, q = read_refs(p, q, cnt)
            pars, q = read_refs(p, q, cnt)
            for k, pa in zip(kids, pars):
                f.parent[k] = pa
            f.prnt_order = kids
        elif name == b"END\x00":
            break
    total = sum(len(c["refs"]) for c in f.classes.values())
    assert total == ninst, f"instance count {total} != header {ninst}"
    return f


def _chunk(name, payload, compress=True):
    if compress and len(payload) > 0:
        comp = lz4.block.compress(payload, mode="high_compression", store_size=False)
        return name + struct.pack("<III", len(comp), len(payload), 0) + comp
    return name + struct.pack("<III", 0, len(payload), 0) + payload


def write(f, path, compress=True):
    out = bytearray()
    ninst = sum(len(f.classes[c]["refs"]) for c in f.class_order)
    out += MAGIC + struct.pack("<HII", 0, len(f.class_order), ninst) + b"\x00" * 8
    if f.meta:
        p = struct.pack("<I", len(f.meta)) + b"".join(write_str(k) + write_str(v) for k, v in f.meta)
        out += _chunk(b"META", p, compress)
    if f.sstr:
        p = struct.pack("<II", 0, len(f.sstr)) + b"".join(md5 + write_str(s) for md5, s in f.sstr)
        out += _chunk(b"SSTR", p, compress)
    for cid in f.class_order:
        c = f.classes[cid]
        p = struct.pack("<i", cid) + write_str(c["name"].encode()) + bytes([c["fmt"]]) + struct.pack("<I", len(c["refs"])) + write_refs(c["refs"])
        if c["fmt"] == 1:
            p += c["markers"]
        out += _chunk(b"INST", p, compress)
    for pr in f.props:
        dec, enc = CODECS[pr["typ"]]
        assert len(pr["elems"]) == len(f.classes[pr["cid"]]["refs"]), f"PROP {pr['name']} count mismatch"
        p = struct.pack("<i", pr["cid"]) + write_str(pr["name"].encode()) + bytes([pr["typ"]]) + enc(pr["elems"])
        out += _chunk(b"PROP", p, compress)
    kids = list(f.prnt_order)
    pars = [f.parent[k] for k in kids]
    p = b"\x00" + struct.pack("<I", len(kids)) + write_refs(kids) + write_refs(pars)
    out += _chunk(b"PRNT", p, compress)
    out += b"END\x00" + struct.pack("<III", 0, 9, 0) + b"</roblox>"
    open(path, "wb").write(out)


# ----------------------------------------------------------------------------------------------------------------
# convenience : instance view
# ----------------------------------------------------------------------------------------------------------------
def index(f):
    """ref -> dict(cid, idx, cls, name, parent, children)"""
    inst = {}
    for cid, c in f.classes.items():
        for i, r in enumerate(c["refs"]):
            inst[r] = dict(cid=cid, idx=i, cls=c["name"], name=None, parent=f.parent.get(r, -1), children=[])
    for pr in f.props:
        if pr["name"] == "Name" and pr["typ"] == 0x01:
            refs = f.classes[pr["cid"]]["refs"]
            for r, v in zip(refs, pr["elems"]):
                inst[r]["name"] = v.decode("utf-8", "replace")
    for r, i in inst.items():
        if i["parent"] in inst:
            inst[i["parent"]]["children"].append(r)
    return inst


def path_of(inst, r):
    parts = []
    while r in inst:
        parts.append(inst[r]["name"] or "?")
        r = inst[r]["parent"]
    return "/".join(reversed(parts))


def find(inst, path):
    """find by slash path from a DataModel child (e.g. 'ReplicatedStorage/Stations')"""
    parts = path.split("/")
    roots = [r for r, i in inst.items() if i["parent"] not in inst or inst[i["parent"]]["cls"] == "DataModel"]
    cur = [r for r in roots if inst[r]["name"] == parts[0]]
    for p in parts[1:]:
        nxt = []
        for r in cur:
            nxt += [c for c in inst[r]["children"] if inst[c]["name"] == p]
        cur = nxt
    return cur


def prop_of(f, inst, r, name):
    i = inst[r]
    for pr in f.props:
        if pr["cid"] == i["cid"] and pr["name"] == name:
            return pr["elems"][i["idx"]]
    return None


def set_prop(f, inst, r, name, value):
    i = inst[r]
    for pr in f.props:
        if pr["cid"] == i["cid"] and pr["name"] == name:
            pr["elems"][i["idx"]] = value
            return True
    return False
