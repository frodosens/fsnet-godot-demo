extends RefCounted
static func beam(world,a,b,width,color):
    var node=world.box((a+b)*0.5,Vector3(width,a.distance_to(b),width),color)
    node.quaternion=Quaternion(Vector3.UP,(b-a).normalized())
    return node
static func inn_details(world):
    # Template coordinates match the original inn before its local transform.
    for z in [5.98,7.42]:
        beam(world,Vector3(-2.06,1.28,z),Vector3(-1.1,2.12,z),0.075,"694d3b")
        beam(world,Vector3(-1.1,2.12,z),Vector3(-0.14,1.28,z),0.075,"694d3b")
    for x in [-2.06,-0.14]:beam(world,Vector3(x,1.28,5.98),Vector3(x,1.28,7.42),0.09,"694d3b")
    beam(world,Vector3(-1.1,2.12,5.94),Vector3(-1.1,2.12,7.46),0.10,"73594d")
    # Separate edge tiles give the roof a real silhouette rather than a flat texture.
    for z in range(8):
        for x in [-2.07,-0.13]:world.box(Vector3(x,1.30,6.0+z*0.2),Vector3(0.12,0.07,0.18),"73594d")
    var awning=world.box(Vector3(-1.1,1.08,7.59),Vector3(0.92,0.09,0.72),"73594d");awning.rotation.x=0.12
    for x in [-1.49,-0.71]:
        beam(world,Vector3(x,-0.04,7.85),Vector3(x,1.04,7.85),0.065,"694d3b")
        beam(world,Vector3(x,0.67,7.84),Vector3(x,1.02,7.50),0.055,"694d3b")
    for i in range(2):world.box(Vector3(-1.1,-0.11+i*0.07,7.90-i*0.22),Vector3(0.84,0.14,0.25),"a08e77")
    # A hanging wooden tankard sign, no baked text or borrowed illustration.
    beam(world,Vector3(-0.42,1.35,7.27),Vector3(-0.12,1.35,7.52),0.04,"694d3b")
    for x in [-0.26,-0.04]:beam(world,Vector3(x,1.35,7.52),Vector3(x,1.17,7.52),0.015,"594633")
    world.box(Vector3(-0.15,0.96,7.52),Vector3(0.44,0.48,0.06),"694d3b")
    world.box(Vector3(-0.18,0.97,7.56),Vector3(0.16,0.22,0.02),"d7b87d")
    beam(world,Vector3(-0.09,0.90,7.57),Vector3(-0.02,0.90,7.57),0.025,"d7b87d")
    beam(world,Vector3(-0.02,0.90,7.57),Vector3(-0.02,1.04,7.57),0.025,"d7b87d")
    beam(world,Vector3(-0.02,1.04,7.57),Vector3(-0.09,1.04,7.57),0.025,"d7b87d")
    # Shutters, door planks and iron hinge strips remain separate geometry.
    for x in [-1.52,-0.65]:
        for side in [-1,1]:
            var shutter=world.box(Vector3(x+side*0.23,0.85,7.30),Vector3(0.12,0.32,0.035),"694d3b");shutter.rotation.y=side*0.35
    for x in [-1.22,-1.10,-0.98]:world.box(Vector3(x,0.31,7.25),Vector3(0.012,0.72,0.014),"594633")
    for y in [0.12,0.49]:world.box(Vector3(-1.1,y,7.27),Vector3(0.32,0.02,0.015),"594633")
static func arch_stone(world,x,z0,z1,y0,y1,side):
    var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    var points=[]
    for dx in [-0.11,0.11]:
        points.append(Vector3(x+dx,y0,z0));points.append(Vector3(x+dx,y1,z1));points.append(Vector3(x+dx,y1+0.18,z1));points.append(Vector3(x+dx,y0+0.18,z0))
    for face in [[0,1,2,3],[7,6,5,4],[0,4,5,1],[3,2,6,7],[0,3,7,4],[1,5,6,2]]:
        for index in [0,1,2,0,2,3]:surface.set_uv(Vector2(points[face[index]].z,points[face[index]].y));surface.add_vertex(points[face[index]])
    surface.generate_normals();var mesh=MeshInstance3D.new();mesh.mesh=surface.commit();mesh.material_override=world.material("a08e77");mesh.material_override.albedo_color=Color(0.80,0.83,0.78) if side else Color(0.92,0.91,0.84);world.add_child(mesh)
