"""Continuous moose anatomy and palmate antlers for creatures.py."""
import math
import bpy
import bmesh
from mathutils import Vector, noise
from model_kit import ModelKit as K


class Moose:
    @staticmethod
    def surface(name, sections):
        return K.profile_body(name, sections)

    @staticmethod
    def raise_head(obj):
        """Higher head carriage, with a deeper forehead and jaw profile.

        The same deformation is applied to the coat and rigid face details
        so the eyes, ears and antler roots stay on the skull.
        """
        inverse = obj.matrix_world.inverted()
        for vertex in obj.data.vertices:
            p = obj.matrix_world @ vertex.co
            forward = p.y  # Blender +Y is Godot forward.
            t = max(0.0, min(1.0, (forward - .85) / .60))
            t = t * t * (3.0 - 2.0 * t)
            nose = max(0.0, min(1.0, (forward - 1.45) / .80))
            p.z += t * (.22 + .10 * nose + .15 * (p.z - 2.10))
            vertex.co = inverse @ p
        return obj

    @staticmethod
    def sculpt(spec):
        parts = [Moose.surface('body and head', [
            (1.20, .04, 1.73, 2.08), (1.08, .29, 1.35, 2.33),
            (.82, .39, 1.25, 2.44), (.48, .41, 1.18, 2.45),
            (.12, .42, 1.16, 2.45), (-.24, .41, 1.18, 2.46),
            (-.56, .385, 1.24, 2.49), (-.76, .33, 1.34, 2.48),
            (-.98, .26, 1.51, 2.39), (-1.18, .255, 1.74, 2.38),
            (-1.43, .245, 1.88, 2.40), (-1.63, .235, 1.84, 2.36),
            (-1.82, .215, 1.75, 2.26), (-2.02, .245, 1.64, 2.15),
            (-2.21, .255, 1.60, 2.07), (-2.33, .21, 1.63, 2.01),
            (-2.36, .10, 1.70, 1.95),
        ])]
        # The dewlap grows out of the throat, instead of floating below it.
        parts.append(K.skin('dewlap', [(0, 1.90, -1.35), (0, 1.71, -1.37), (0, 1.45, -1.32)], [(0,1),(1,2)], [(.105,.13),(.08,.10),(.025,.035)], 'fur'))
        parts.append(K.ellipsoid('tail', (0, 1.91, 1.14), (.055,.14,.085), 'fur', rotation=(-.3,0,0)))
        for side in (-1,1):
            for front in (True,False):
                z = spec['front_z'] if front else spec['back_z']
                x = spec['leg_width'] * side
                # Long cannon bones, a defined knee and full upper leg,
                # all melted into the flank. No overlapping sock meshes.
                joints = [(x*.8,1.72,z), (x,1.40,z), (x,.80,z+(-.03 if front else .12)), (x,.38,z+.03), (x,.10,z)]
                radii = [(.17,.21),(.15,.18),(.086,.095),(.058,.067),(.065,.075)]
                parts.append(K.skin('foreleg' if front else 'hindleg', joints, [(0,1),(1,2),(2,3),(3,4)], radii, 'fur'))
        for part in parts:
            Moose.raise_head(part)
        body = K.sculpt(parts, 'coat', voxel=.014, smoothing=10, roughness=.009, keep=.10)
        body.data.validate()
        return K.paint(body, 'moose coat', Moose.shade)

    @staticmethod
    def shade(p):
        t = max(0, min(1, (.95-p.y)/.36))
        colour = Vector((.265,.225,.18)).lerp(Vector((.56,.525,.46)), t*.82)
        muzzle = max(0,min(1,(-p.z-1.97)/.28))
        colour = colour.lerp(Vector((.18,.155,.13)), muzzle*.75)
        mane = math.exp(-((p.z+.57)/.42)**2)*max(0,min(1,(p.y-2.15)/.3))
        colour *= 1-.30*mane
        colour *= 1+noise.noise_vector(Vector((p.x*70,p.y*17,p.z*70)))[0]*.08
        return colour

    @staticmethod
    def hoof(x,z):
        parts=[]
        for side in (-1,1):
            parts.append(K.ellipsoid('cloven toe', (x+side*.041,.074,z-.035), (.038,.072,.112), 'hoof', segments=16,rings=10))
        for side in (-1,1):
            parts.append(K.ellipsoid('dewclaw', (x+side*.05,.17,z+.064), (.021,.033,.032), 'hoof',segments=10,rings=6))
        return K.join(parts,'cloven hoof')

    @staticmethod
    def antler(side):
        # A broad irregular hand, not a disk. Tines originate inside the
        # palm and follow its splay; remeshing welds every root to the beam.
        outline=[(.28,-1.64),(.47,-1.88),(.70,-1.94),(.93,-1.82),(1.08,-1.58),(1.04,-1.27),(.87,-1.02),(.62,-1.00),(.40,-1.24)]
        vertices=[]
        for height in (-.026,.026):
            for x,z in outline:
                vertices.append(K.g(x*side,2.42+.30*x+height,z))
        n=len(outline)
        faces=[tuple(reversed(range(n))),tuple(range(n,2*n))]
        faces += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
        mesh=bpy.data.meshes.new('palm')
        mesh.from_pydata(vertices,[],faces)
        palm=K.link(bpy.data.objects.new('palm',mesh))
        # Ensure a consistent outward orientation on both mirrored sides.
        bm=bmesh.new()
        bm.from_mesh(mesh)
        bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
        bm.to_mesh(mesh)
        bm.free()
        parts=[palm,K.tube('beam',(.10*side,2.31,-1.65),(.48*side,2.59,-1.53),.055,'antler',end_radius=.075)]
        for k in range(1,8):
            x,z=outline[k]
            outward=Vector((x-.38,0,z+1.48)).normalized()
            base=Vector((x*side,2.42+.30*x,z))
            root=base-Vector((outward.x*side,0,outward.z))*.065
            tip=base+Vector((outward.x*side*.15,.18+.07*math.sin(k*1.8),outward.z*.14))
            mid=root.lerp(tip,.65)+Vector((0,.02,0))
            parts.append(K.tube('tine root',root,mid,.035,'antler',end_radius=.019,vertices=10))
            parts.append(K.tube('tine tip',mid,tip,.019,'antler',end_radius=.002,vertices=10))
        antler=K.sculpt(parts,'antler',voxel=.009,smoothing=3,roughness=.002,keep=.14)
        antler.data.validate()
        antler.data.materials.append(K.material('antler'))
        return antler

    @staticmethod
    def extras():
        parts=[]
        for side in (-1,1):
            parts.append(Moose.antler(side))
            # Long pointed ears, with a recessed dark inner leaf.
            ear=K.skin('ear',[(.16*side,2.33,-1.46),(.34*side,2.49,-1.40),(.48*side,2.64,-1.38)],[(0,1),(1,2)],[(.065,.05),(.11,.045),(.009,.008)],'fur')
            parts.append(ear)
            parts.append(K.ellipsoid('inner ear',(.33*side,2.49,-1.447),(.065,.112,.015),'dark',rotation=(0,0,-.65*side),segments=16,rings=10))
            parts.append(K.ellipsoid('eye socket',(.194*side,2.18,-1.80),(.032,.030,.034),'dark',segments=16,rings=10))
            parts.append(K.ellipsoid('eye',(.211*side,2.18,-1.813),(.019,.021,.022),'ink',segments=16,rings=10))
            parts.append(K.ellipsoid('nostril',(.215*side,1.91,-2.285),(.037,.025,.036),'ink',rotation=(0,-.45*side,0),segments=14,rings=8))
            parts.append(K.tube('mouth',(.226*side,1.695,-2.25),(.228*side,1.715,-2.04),.004,'dark',end_radius=.002))
        for part in parts:
            Moose.raise_head(part)
        return parts

    @staticmethod
    def bind(rig,coat):
        # Head details are rigid, so the skull must share their transform.
        head=coat.vertex_groups.get('head')
        neck=coat.vertex_groups.get('neck')
        for v in coat.data.vertices:
            world=coat.matrix_world@v.co
            z=-world.y
            if z> -1.22:
                continue
            blend=max(0,min(1,(-z-1.22)/.25))
            for group in coat.vertex_groups:
                group.remove([v.index])
            head.add([v.index],blend,'REPLACE')
            neck.add([v.index],1-blend,'REPLACE')

        # Normalize the four strongest influences before export and keep the
        # cannon bone attached to its rigid hoof through the whole gait.
        for v in coat.data.vertices:
            p = coat.matrix_world @ v.co
            if p.z < .35:
                side = 'l' if p.x < 0 else 'r'
                end = 'f' if -p.y < 0 else 'b'
                for group in coat.vertex_groups:
                    group.remove([v.index])
                coat.vertex_groups['leg_' + end + side + '_lower'].add([v.index], 1, 'REPLACE')
            strongest = sorted([(g.group, g.weight) for g in v.groups], key=lambda item: item[1], reverse=True)[:4]
            total = sum(weight for _, weight in strongest)
            if total == 0:
                strongest = [(coat.vertex_groups['spine'].index, 1.0)]
                total = 1.0
            for group in coat.vertex_groups:
                group.remove([v.index])
            for index, weight in strongest:
                coat.vertex_groups[index].add([v.index], weight / total, 'REPLACE')
