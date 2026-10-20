"""Make an original smooth vortex mesh and seamless sand tile. No downloaded art."""
import argparse
import json
import math
import struct
import uuid
from pathlib import Path

import numpy as np
from PIL import Image


def build_funnel(path):
    rings, segments, height = 48, 72, 13.5
    positions, normals, uvs, indices = [], [], [], []
    for ring in range(rings+1):
        v = ring/rings
        radius = .28 + 3.85*v**1.38
        cx = 1.15*math.sin(v*5.2)*v
        cz = .85*math.cos(v*4.7)*v
        slope = 3.85*1.38*max(v, .001)**.38/height
        for segment in range(segments+1):
            u = segment/segments
            angle = u*math.tau
            c,s = math.cos(angle),math.sin(angle)
            r = radius * (1 + .065*math.sin(angle*3+v*13))
            positions.extend((cx+r*c,v*height,cz+r*s))
            n = math.sqrt(1+slope*slope)
            normals.extend((c/n,-slope/n,s/n))
            uvs.extend((u,v))
    for ring in range(rings):
        for segment in range(segments):
            a = ring*(segments+1)+segment
            b = a+segments+1
            indices.extend((a,b,a+1,a+1,b,b+1))
    write_mesh(path, positions, normals, uvs, indices, 'ThunderFunnel')


def build_dune(path):
    steps, width, depth = 40, 20, 22
    def elevation(x, z):
        edge = max(0, 1 - (x*x + z*z))**1.35
        ridge = 5.6 + 1.25*math.sin(x*2.6-z*1.1) + .45*math.sin(z*5+x)
        return edge * ridge
    positions, normals, uvs, indices = [], [], [], []
    for row in range(steps+1):
        z = row/steps*2-1
        for col in range(steps+1):
            x = col/steps*2-1
            y = elevation(x,z)
            dx = (elevation(x+.001,z)-elevation(x-.001,z))/.002/(width*.5)
            dz = (elevation(x,z+.001)-elevation(x,z-.001))/.002/(depth*.5)
            length = math.sqrt(dx*dx+1+dz*dz)
            positions.extend((x*width*.5,y,z*depth*.5))
            normals.extend((-dx/length,1/length,-dz/length))
            uvs.extend((x*2.5,z*2.75))
    for row in range(steps):
        for col in range(steps):
            a=row*(steps+1)+col;b=a+steps+1
            indices.extend((a,b,a+1,a+1,b,b+1))
    write_mesh(path, positions, normals, uvs, indices, 'ThunderDune')


def write_mesh(path, positions, normals, uvs, indices, name):
    blobs = [struct.pack(f'<{len(x)}f',*x) for x in (positions,normals,uvs)]
    blobs.append(struct.pack(f'<{len(indices)}H',*indices))
    views, binary = [], bytearray()
    for i,blob in enumerate(blobs):
        views.append({'buffer':0,'byteOffset':len(binary),'byteLength':len(blob),'target':34963 if i==3 else 34962})
        binary.extend(blob)
        binary.extend(b'\0'*((-len(binary))%4))
    p = np.array(positions).reshape(-1,3)
    count = len(p)
    gltf = {
        'asset':{'version':'2.0','generator':'Original Thunder vortex'},
        'scene':0,'scenes':[{'nodes':[0]}],
        'nodes':[{'name':name,'mesh':0}],
        'meshes':[{'name':name,'primitives':[{'attributes':{'POSITION':0,'NORMAL':1,'TEXCOORD_0':2},'indices':3,'material':0}]}],
        'materials':[{'name':'ThunderSand','doubleSided':True,'alphaMode':'BLEND','pbrMetallicRoughness':{'baseColorFactor':[.7,.5,.25,.6],'metallicFactor':0,'roughnessFactor':1}}],
        'buffers':[{'byteLength':len(binary)}],'bufferViews':views,
        'accessors':[
            {'bufferView':0,'componentType':5126,'count':count,'type':'VEC3','min':p.min(axis=0).tolist(),'max':p.max(axis=0).tolist()},
            {'bufferView':1,'componentType':5126,'count':count,'type':'VEC3'},
            {'bufferView':2,'componentType':5126,'count':count,'type':'VEC2'},
            {'bufferView':3,'componentType':5123,'count':len(indices),'type':'SCALAR'},
        ],
    }
    data=json.dumps(gltf,separators=(',',':')).encode();data+=b' '*((-len(data))%4)
    result=struct.pack('<4sII',b'glTF',2,12+8+len(data)+8+len(binary))
    result+=struct.pack('<I4s',len(data),b'JSON')+data+struct.pack('<I4s',len(binary),b'BIN\0')+binary
    path.write_bytes(result)


def metadata(path, kind, options=''):
    sidecar=Path(str(path)+'.meta')
    if not sidecar.exists():
        sidecar.write_text(f'guid:t="{uuid.uuid4()}"\nassetType:i={kind}\n'+options,encoding='utf-8')


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--project',type=Path,required=True);args=parser.parse_args()
    out=args.project/'assets/vfx';out.mkdir(parents=True,exist_ok=True)
    funnel=out/'thunder_funnel.glb';build_funnel(funnel)
    build_dune(out/'thunder_dune.glb')
    metadata(funnel,3,'sceneScale:r=1\nimportMeshes:b=yes\nimportMaterials:b=yes\nflipUvs:b=no\nphysicsShapeImport{\ndefaultAlgorithm:t="Disabled"\n}\n')
    size=256
    y,x=np.mgrid[0:size,0:size]/size
    rng=np.random.default_rng(12030)
    grain=rng.normal(0,2.4,(size,size))
    ripple=np.sin(math.tau*(x*9+y*2+np.sin(y*math.tau)*.55))*2.2
    sand=np.clip(np.array([208,177,123])[None,None,:]+(grain+ripple)[:,:,None],0,255).astype('uint8')
    tile=out/'sand.png';Image.fromarray(sand).save(tile)
    metadata(tile,0,'filter:t="Bilinear"\naddressing:t="Wrap"\ngenerateMipLevels:b=yes\nanisotropicLevel:i=4\nusage:t="Color"\ncompressTexture:b=no\n')
    for name in ('thunder_funnel','thunder_dust','thunder_grain'):
        metadata(args.project/f'assets/shaders/{name}.shader',12)
    print(json.dumps({'mesh_vertices':(48+1)*(72+1),'triangles':48*72*2,'height':13.5,'directory':str(out)}))


if __name__=='__main__':
    main()
