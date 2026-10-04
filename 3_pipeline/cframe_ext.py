import struct, rbxl_parse as R
ROT = {0x02:(1,0,0,0,1,0,0,0,1),0x03:(1,0,0,0,0,-1,0,1,0),0x05:(1,0,0,0,-1,0,0,0,-1),0x06:(1,0,0,0,0,1,0,-1,0),
0x07:(0,1,0,1,0,0,0,0,-1),0x09:(0,0,1,1,0,0,0,1,0),0x0a:(0,-1,0,1,0,0,0,0,1),0x0c:(0,0,-1,1,0,0,0,-1,0),
0x0d:(0,1,0,0,0,1,1,0,0),0x0e:(0,0,-1,0,1,0,1,0,0),0x10:(0,-1,0,0,0,-1,1,0,0),0x11:(0,0,1,0,-1,0,1,0,0),
0x14:(-1,0,0,0,1,0,0,0,-1),0x15:(-1,0,0,0,0,1,0,1,0),0x17:(-1,0,0,0,-1,0,0,0,1),0x18:(-1,0,0,0,0,-1,0,-1,0),
0x19:(0,1,0,-1,0,0,0,0,1),0x1b:(0,0,-1,-1,0,0,0,1,0),0x1c:(0,-1,0,-1,0,0,0,0,-1),0x1e:(0,0,1,-1,0,0,0,-1,0),
0x1f:(0,1,0,0,0,-1,-1,0,0),0x20:(0,0,1,0,1,0,-1,0,0),0x22:(0,-1,0,0,0,1,-1,0,0),0x23:(0,0,-1,0,-1,0,-1,0,0)}
def parse_cframes(path):
    data=open(path,'rb').read()
    _,_,chunks=R.read_chunks(data)
    classes={}
    for name,p in chunks:
        if name==b'INST':
            pos=0;(cid,)=struct.unpack_from('<i',p,pos);pos+=4
            cname,pos=R.read_string(p,pos);pos+=1;(cnt,)=struct.unpack_from('<I',p,pos);pos+=4
            classes[cid]=R.read_referents(p[pos:pos+4*cnt],cnt)
    out={}
    for name,p in chunks:
        if name!=b'PROP': continue
        pos=0;(cid,)=struct.unpack_from('<i',p,pos);pos+=4
        pname,pos=R.read_string(p,pos); typ=p[pos]; pos+=1
        if typ!=0x10 or pname!=b'CFrame': continue
        refs=classes[cid]; cnt=len(refs); rots=[]
        for _ in range(cnt):
            rid=p[pos]; pos+=1
            if rid==0: rots.append(struct.unpack_from('<9f',p,pos)); pos+=36
            else: rots.append(ROT[rid])
        x=R.read_interleaved_f32(p[pos:pos+4*cnt],cnt);pos+=4*cnt
        y=R.read_interleaved_f32(p[pos:pos+4*cnt],cnt);pos+=4*cnt
        z=R.read_interleaved_f32(p[pos:pos+4*cnt],cnt)
        for r,rot,a,b,c in zip(refs,rots,x,y,z): out[r]=((a,b,c),rot)
    return out
