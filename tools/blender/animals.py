"""Species-specific continuous anatomy, feet, ears and antlers.

Reference photographs and visual comparison notes are in REFERENCES.md.
Coordinates and rig names follow ModelKit and QuadrupedModel.
"""
import math
import bpy
from mathutils import Vector, noise
from model_kit import ModelKit as K


class AnimalAnatomy:
    # z, half width, underside, top; rear to nose. These contours, rather
    # than chains of round primitives, define each animal's silhouette.
    PROFILES = {
        'deer': [(.61,.025,1.02,1.15),(.51,.18,.86,1.26),(.30,.23,.79,1.29),
                 (0,.235,.78,1.28),(-.30,.21,.78,1.28),(-.43,.15,.94,1.34),
                 (-.54,.10,1.20,1.55),(-.66,.11,1.43,1.75),(-.75,.105,1.47,1.74),
                 (-.84,.075,1.47,1.64),(-.95,.05,1.48,1.58),(-.98,.02,1.50,1.56)],
        'reindeer': [(.66,.03,.98,1.15),(.53,.23,.80,1.30),(.30,.29,.75,1.34),
                     (0,.29,.73,1.35),(-.30,.255,.75,1.37),(-.46,.21,.91,1.45),
                     (-.56,.165,1.13,1.64),(-.67,.14,1.42,1.79),(-.78,.125,1.45,1.76),
                     (-.90,.095,1.45,1.66),(-1.02,.08,1.44,1.60),(-1.05,.025,1.47,1.57)],
        'dog': [(.45,.025,.45,.60),(.34,.14,.34,.65),(.15,.175,.29,.65),
                (-.08,.185,.255,.66),(-.26,.155,.30,.68),(-.36,.115,.48,.79),
                (-.44,.12,.65,.88),(-.53,.125,.67,.89),(-.60,.085,.675,.81),
                (-.71,.075,.675,.79),(-.77,.06,.69,.775),(-.79,.025,.71,.76)],
        'hare': [(.34,.025,.22,.32),(.26,.14,.12,.43),(.12,.185,.10,.47),
                 (-.04,.155,.12,.44),(-.16,.105,.19,.43),(-.22,.09,.30,.51),
                 (-.29,.085,.32,.51),(-.36,.065,.32,.44),(-.40,.03,.34,.40)],
    }

    @staticmethod
    def configure(spec):
        kind = spec['name']
        spec.update(sculpt=AnimalAnatomy.sculpt,
                    extras=lambda: AnimalAnatomy.extras(kind),
                    feet=lambda x,z: AnimalAnatomy.feet(kind,x,z),
                    bind=lambda r,c: AnimalAnatomy.bind(r,c,spec))
        # Feet and cannons now meet; the old tiny hoof height left gaps.
        if kind in ('deer','reindeer'):
            spec['hoof_height'] = .075
        elif kind=='hare':
            spec['hip_y']=.30
            spec['knee_y']=.15
            spec['body']=[((x,y+.10,z),r) for (x,y,z),r in spec['body']]
            root,tip,a,b=spec['tail']
            spec['tail']=((root[0],root[1]+.10,root[2]),(tip[0],tip[1]+.10,tip[2]),a,b)
        return spec

    @staticmethod
    def sculpt(spec):
        kind=spec['name']
        sections=AnimalAnatomy.PROFILES[kind]
        if kind=='hare':
            sections=[(z,w,bottom+.10,top+.10) for z,w,bottom,top in sections]
        parts=[K.profile_body(kind+' anatomy',sections)]
        for side in (-1,1):
            for front in (True,False):
                z=spec['front_z'] if front else spec['back_z']
                x=spec['leg_width']*side
                hip=spec['hip_y']
                knee=spec['knee_y']
                h=spec['hoof_height']
                lean=-spec.get('knee',0) if front else spec.get('hock',0)
                if kind=='hare':
                    # Folded hind legs have substantial thighs and long feet.
                    if not front:
                        parts.append(K.ellipsoid('hind thigh',(x,.31,.15),(.105,.15,.145),'fur',segments=24,rings=16))
                    top=(x*.8,.40 if front else .34,z)
                else:
                    top=(x*.8,hip+.14,z)
                thigh=spec['thigh']*(.85 if front else 1.05)
                joints=[top,(x,hip-.06,z),(x,knee,z+lean),(x,h*.40,z)]
                radii=[(thigh,thigh*1.25),(thigh*.86,thigh*1.05),
                       (spec['knee_r'],spec['knee_r']*1.1),(spec['ankle_r'],spec['ankle_r']*1.1)]
                parts.append(K.skin('limb',joints,[(0,1),(1,2),(2,3)],radii,'fur'))
                if kind in ('dog','hare'):
                    length=(.09 if kind=='hare' and not front else .055)
                    parts.append(K.ellipsoid('foot',(x,h*.9,z-length*.45),
                                (spec['ankle_r']*1.4,h*.9,length),'fur',segments=20,rings=12))
        if kind=='dog':
            tail=[(0,.57,.35),(0,.61,.48),(0,.67,.67),(0,.70,.81)]
            parts.append(K.skin('tail',tail,[(0,1),(1,2),(2,3)],[(.05,.05),(.045,.045),(.026,.026),(.004,.004)],'fur'))
        elif kind=='hare':
            parts.append(K.ellipsoid('scut',(0,.365,.32),(.06,.065,.07),'fur',segments=20,rings=12))
        # Deer have a rump patch, not a white ball attached to the head rig.
        body=K.sculpt(parts,'coat',voxel=.008 if kind in ('deer','reindeer') else .005,
                      smoothing=8,roughness=.003,keep=.13)
        body.data.validate()
        return K.paint(body,kind+' coat',lambda p:AnimalAnatomy.shade(kind,p))

    @staticmethod
    def shade(kind,p):
        if kind=='deer':
            c=Vector((.48,.34,.22))
            belly=max(0,min(1,(.94-p.y)/.18))
            c=c.lerp(Vector((.66,.56,.42)),belly*.42)
            patch=max(0,min(1,(p.z-.43)/.11))
            c=c.lerp(Vector((.89,.87,.78)),patch)
        elif kind=='reindeer':
            c=Vector((.32,.26,.21))
            # Broad pale ruff blends into the chest and shoulders.
            ruff=math.exp(-((p.z+.46)/.22)**4)*max(0,min(1,(p.y-.85)/.22))
            c=c.lerp(Vector((.77,.75,.67)),ruff*.95)
            lower=max(0,min(1,(.30-p.y)/.15))
            c=c.lerp(Vector((.72,.70,.63)),lower*.9)
            c=c.lerp(Vector((.80,.78,.70)),max(0,min(1,(p.z-.45)/.13)))
        elif kind=='dog':
            c=Vector((.46,.30,.17))
            c=c.lerp(Vector((.38,.235,.12)),max(0,min(1,(p.y-.58)/.18))*.35)
            band=(p.y-.67)*.85-(p.z+.37)*.52
            if abs(band)<.035 and p.z<-.27 and p.y>.49:
                blend=max(0,min(1,(.035-abs(band))/.014))
                c=c.lerp(Vector((.68,.075,.055)),blend)
        else:
            c=Vector((.88,.89,.88))
            c=c.lerp(Vector((.73,.76,.77)),max(0,min(1,(.25-p.y)/.2))*.25)
        c*=1+noise.noise_vector(Vector((p.x*100,p.y*30,p.z*100)))[0]*.055
        return c

    @staticmethod
    def leaf(name,root,tip,width,depth,material):
        root,tip=Vector(root),Vector(tip)
        vertices,faces=[],[]
        rings,count=9,16
        for j in range(rings):
            t=j/(rings-1)
            center=root.lerp(tip,t)
            w=max(.001,width*math.sin(math.pi*(.08+.92*t))**.8)
            for k in range(count):
                a=k*math.tau/count
                vertices.append(K.g(*(center+Vector((w*math.cos(a),0,depth*math.sin(a))))))
        for j in range(rings-1):
            for k in range(count):
                a=j*count+k;b=j*count+(k+1)%count
                faces.append((a,b,b+count,a+count))
        faces.extend((tuple(reversed(range(count))),tuple(range((rings-1)*count,rings*count))))
        mesh=bpy.data.meshes.new(name);mesh.from_pydata(vertices,[],faces)
        obj=K.link(bpy.data.objects.new(name,mesh))
        # Recalculate the outward normals for this vertical leaf.
        import bmesh
        bm=bmesh.new();bm.from_mesh(mesh)
        bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free()
        for polygon in mesh.polygons:polygon.use_smooth=True
        mesh.materials.append(K.material(material))
        return obj

    @staticmethod
    def antlers(kind,side):
        s=side
        if kind=='deer':
            chains=[[(.055*s,1.71,-.68),(.075*s,1.83,-.65),(.10*s,1.96,-.66),(.085*s,2.06,-.70)],
                    [(.075*s,1.84,-.65),(.10*s,1.92,-.78),(.10*s,1.99,-.80)],
                    [(.095*s,1.94,-.66),(.15*s,2.02,-.57),(.16*s,2.06,-.55)]]
            radius=.023
        else:
            chains=[[(.065*s,1.74,-.67),(.16*s,1.98,-.51),(.30*s,2.21,-.25),(.35*s,2.43,-.27),(.26*s,2.65,-.48)],
                    [(.13*s,1.92,-.55),(.14*s,1.98,-.83),(.18*s,2.13,-.95)],
                    [(.25*s,2.13,-.34),(.38*s,2.26,-.53),(.43*s,2.43,-.65)],
                    [(.35*s,2.41,-.27),(.48*s,2.54,-.15),(.49*s,2.67,-.18)],
                    [(.29*s,2.58,-.43),(.19*s,2.68,-.61),(.20*s,2.75,-.67)]]
            radius=.034
        parts=[]
        for chain_index, chain in enumerate(chains):
            points=[Vector(p) for p in chain]
            if chain_index:
                points.insert(0, points[0]-(points[1]-points[0]).normalized()*.045)
            # Catmull-Rom samples preserve the branching positions but make
            # the beams sweep smoothly. Solid tubes do not retreat from a
            # branch root as Skin modifier end caps did.
            samples=[]
            for i in range(len(points)-1):
                p0=points[max(0,i-1)];p1=points[i]
                p2=points[i+1];p3=points[min(len(points)-1,i+2)]
                for j in range(5):
                    t=j/5
                    samples.append(.5*((2*p1)+(-p0+p2)*t+(2*p0-5*p1+4*p2-p3)*t*t+(-p0+3*p1-3*p2+p3)*t*t*t))
            samples.append(points[-1])
            for i in range(len(samples)-1):
                r0=radius*(1-.78*i/(len(samples)-1))
                r1=radius*(1-.78*(i+1)/(len(samples)-1))
                parts.append(K.tube('antler beam',samples[i],samples[i+1],r0,'antler',end_radius=r1,vertices=10))
        antler=K.sculpt(parts,'antler',voxel=.003,smoothing=3,keep=.14)
        antler.data.validate();antler.data.materials.append(K.material('antler'))
        return antler

    @staticmethod
    def extras(kind):
        parts=[]
        if kind in ('deer','reindeer'):
            ren=kind=='reindeer'
            for s in (-1,1):
                parts.append(AnimalAnatomy.antlers(kind,s))
                root=(.085*s,1.68,-.65);tip=((.25 if ren else .23)*s,1.85 if ren else 1.98,-.57)
                parts.append(AnimalAnatomy.leaf('ear',root,tip,.067 if ren else .064,.018,'fur'))
                parts.append(AnimalAnatomy.leaf('inner ear',Vector(root)+Vector((0,.035,-.016)),Vector(tip)+Vector((0,-.025,-.016)),.043,.006,'fur_dark'))
                eye=((.115 if ren else .077)*s,1.64,-.78)
                parts.append(K.ellipsoid('eye rim',eye,(.020,.022,.018),'fur_dark',segments=16,rings=10))
                parts.append(K.ellipsoid('eye',Vector(eye)+Vector((.008*s,0,-.004)),(.014,.017,.013),'ink',segments=16,rings=10))
            nose=(0,1.535,-1.038 if ren else -.969)
            parts.append(K.ellipsoid('nose',nose,(.067,.041,.024) if ren else (.041,.029,.021),'ink',segments=20,rings=12))
        elif kind=='dog':
            parts.append(K.ellipsoid('nose',(0,.748,-.786),(.058,.036,.021),'ink',segments=20,rings=12))
            for s in (-1,1):
                parts.append(AnimalAnatomy.leaf('drop ear',(.11*s,.845,-.48),(.16*s,.65,-.44),.048,.025,'dark'))
                parts.append(K.ellipsoid('eye rim',(.105*s,.815,-.56),(.025,.024,.022),'dark',segments=16,rings=10))
                parts.append(K.ellipsoid('eye',(.117*s,.817,-.572),(.016,.017,.014),'ink',segments=16,rings=10))
        else:
            for s in (-1,1):
                root=Vector((.044*s,.47,-.23))
                tip=Vector((.080*s,.70,-.155))
                ear=AnimalAnatomy.leaf('ear',root,tip,.035,.014,'fur')
                def ear_shade(p):
                    progress=(p.y-root.y)/(tip.y-root.y)
                    black_tip=max(0,min(1,(progress-.82)/.08))
                    c=Vector((.86,.87,.85))
                    center_z=root.z+progress*(tip.z-root.z)
                    if p.z<center_z-.009 and .1<progress<.8:
                        c=c.lerp(Vector((.69,.65,.63)),.55)
                    return c.lerp(Vector((.12,.115,.105)),black_tip)
                ear.data.materials.clear();K.paint(ear,'ear fur',ear_shade);parts.append(ear)
                parts.append(K.ellipsoid('eye rim',(.067*s,.443,-.302),(.025,.026,.021),'shade',segments=20,rings=12))
                parts.append(K.ellipsoid('eye',(.077*s,.444,-.307),(.018,.021,.018),'ink',segments=20,rings=12))
            parts.append(K.ellipsoid('nose',(0,.386,-.395),(.018,.013,.009),'pink',segments=12,rings=8))
        if kind=='hare':
            for part in parts:
                part.location.z += .10  # Blender Z is height.
        return parts

    @staticmethod
    def feet(kind,x,z):
        parts=[]
        if kind in ('deer','reindeer'):
            ren=kind=='reindeer';w=.033 if ren else .022
            for s in (-1,1):
                parts.append(K.ellipsoid('cloven hoof',(x+s*w*.85,.047,z-.015),
                             (w,.045,.073 if ren else .052),'hoof',segments=16,rings=10))
        else:
            # Soft feet are part of the coat. These small nail tips emerge
            # from them; the hare's long hind sole remains furry.
            h=.03 if kind=='dog' else .02
            length=.055 if kind=='dog' or z<0 else .09
            for k in range(4):
                across=(k-1.5)*(.019 if kind=='dog' else .015)
                parts.append(K.tube('nail',(x+across,h,z-length*1.2),(x+across,h*.5,z-length*1.48),.0035,'hoof',end_radius=.001,vertices=6))
        return K.join(parts,'foot details')

    @staticmethod
    def bind(rig,coat,spec):
        kind=spec['name']
        start,end={'deer':(.47,.66),'reindeer':(.48,.66),'dog':(.35,.48),'hare':(.19,.26)}[kind]
        for v in coat.data.vertices:
            world=coat.matrix_world@v.co
            p=Vector((world.x,world.z,-world.y))
            head=max(0,min(1,(-p.z-start)/(end-start)))
            if head>0:
                for group in coat.vertex_groups:group.remove([v.index])
                coat.vertex_groups['head'].add([v.index],head,'REPLACE')
                coat.vertex_groups['neck'].add([v.index],1-head,'REPLACE')
            if kind=='dog' and p.z>.45:
                for group in coat.vertex_groups:group.remove([v.index])
                coat.vertex_groups['tail'].add([v.index],1,'REPLACE')
            if p.y < spec['hoof_height']+.055:
                side='l' if p.x<0 else 'r';end_tag='f' if p.z<0 else 'b'
                for group in coat.vertex_groups:group.remove([v.index])
                coat.vertex_groups['leg_'+end_tag+side+'_lower'].add([v.index],1,'REPLACE')
            strongest=sorted([(g.group,g.weight) for g in v.groups],key=lambda a:a[1],reverse=True)[:4]
            total=sum(w for _,w in strongest)
            if total<.00001:strongest=[(coat.vertex_groups['spine'].index,1)];total=1
            for group in coat.vertex_groups:group.remove([v.index])
            for group,w in strongest:
                if w>.00001:coat.vertex_groups[group].add([v.index],w/total,'REPLACE')
