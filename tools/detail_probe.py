exec(open('tools/scene_probe.py').read().split('out=[]')[0])
for obj in env.objects:
    if obj.type.name=='Transform' and obj.assets_file.name=='level2' and obj.path_id==14213:
        for p in obj.read().m_Children:
            t=p.read(); g=t.m_GameObject.read()
            print(g.m_Name,g.m_IsActive,str(t.m_LocalPosition),len(t.m_Children))
for obj in env.objects:
    if obj.type.name=='Camera' and obj.assets_file.name=='level2':
        print('CAMERA',obj.read_typetree())
    if obj.type.name=='MonoScript':
        d=obj.read()
        if d.m_Name=='PlayerController':print('PLAYER SCRIPT',obj.read_typetree())
