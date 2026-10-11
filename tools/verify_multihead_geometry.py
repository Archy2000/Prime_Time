"""Validate generated skin connectivity and closed surfaces, excluding detail eyes/teeth."""
from pathlib import Path
import struct,json
import numpy as np
from scipy.sparse import coo_matrix
from scipy.sparse.csgraph import connected_components

root=Path(__file__).resolve().parents[1]
assets=root/'assets/characters/mutations'
anatomy=json.loads((assets/'anatomy.json').read_text())
results={}
for count,info in anatomy.items():
    data=(assets/f'hydra_{count}.glb').read_bytes()
    length=struct.unpack_from('<I',data,12)[0]
    doc=json.loads(data[20:20+length]);blob=data[28+length:]
    primitive=doc['meshes'][0]['primitives'][0]
    accessor=doc['accessors'][primitive['indices']];view=doc['bufferViews'][accessor['bufferView']]
    faces=np.frombuffer(blob,dtype='<u4',count=accessor['count'],offset=view['byteOffset']).reshape(-1,3)[:info['body_triangles']]
    edges=np.sort(np.concatenate([faces[:,[0,1]],faces[:,[1,2]],faces[:,[2,0]]]),axis=1)
    unique,incidence=np.unique(edges,axis=0,return_counts=True)
    graph=coo_matrix((np.ones(len(unique)),(unique[:,0],unique[:,1])),shape=(info['body_vertices'],)*2)
    components,_=connected_components(graph,directed=False)
    results[count]=dict(connected_components=components,closed_skin=bool(np.all(incidence==2)),mouth_count=len(info['mouths']),triangles=info['total_triangles'])
passed=all(x['connected_components']==1 and x['closed_skin'] and x['mouth_count']==int(k) for k,x in results.items())
results['passed']=passed
(root/'research/multihead_geometry_tests.json').write_text(json.dumps(results,indent=2))
print(json.dumps(results,indent=2));raise SystemExit(0 if passed else 1)
