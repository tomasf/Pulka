"""Winter red fox: continuous body, pointed ears and a full tapered brush.

Reference photographs and proportions are recorded in REFERENCES.md.
Uses the existing quadruped skeleton; geometry is welded before skinning.
"""
import math

import bpy
import bmesh
from mathutils import Vector, noise

from model_kit import ModelKit as K


class Fox:
    @staticmethod
    def spec():
        return {
            "name": "fox",
            "colors": {"fur": (.73, .34, .14), "dark": (.16, .11, .08),
                       "ink": (.035, .029, .025), "amber": (.67, .40, .12),
                       "glint": (.88, .84, .70), "hoof": (.10, .075, .055)},
            "sculpt": Fox.sculpt, "extras": Fox.extras, "feet": Fox.foot,
            "bind": Fox.bind, "walk_animation": Fox.walk, "idle_animation": Fox.idle,
            "front_z": -.25, "back_z": .27, "hip_y": .43, "knee_y": .235,
            "hoof_height": .028, "leg_width": .095, "hock": .075, "knee": .005,
            "body": [((0, .48, .37), (.12, .13)), ((0, .48, .18), (.16, .17)),
                     ((0, .49, -.10), (.17, .18)), ((0, .55, -.27), (.14, .17)),
                     ((0, .63, -.40), (.10, .12)), ((0, .69, -.55), (.09, .09)),
                     ((0, .59, -.76), (.03, .025))],
            "neck_joint": 4,
            "tail": ((0, .48, .36), (0, .20, 1.0), .09, .005),
        }

    @staticmethod
    def smooth(a, b, value):
        t = max(0.0, min(1.0, (value - a) / (b - a)))
        return t * t * (3 - 2 * t)

    @staticmethod
    def ear(side):
        vertices, faces = [], []
        root, tip = Vector((side * .082, .70, -.50)), Vector((side * .14, .86, -.46))
        rings, count = 9, 16
        for j in range(rings):
            t = j / (rings - 1)
            center = root.lerp(tip, t)
            width = max(.001, .064 * max(0, 1 - t) ** .85)
            depth = .020 * (1 - t) + .002
            for k in range(count):
                angle = k * math.tau / count
                vertices.append(K.g(*(center + Vector((math.cos(angle) * width, 0, math.sin(angle) * depth)))))
        for j in range(rings - 1):
            for k in range(count):
                a, b = j * count + k, j * count + (k + 1) % count
                faces.append((a, b, b + count, a + count))
        faces += [tuple(reversed(range(count))), tuple(range((rings - 1) * count, rings * count))]
        mesh = bpy.data.meshes.new("fox ear")
        mesh.from_pydata(vertices, [], faces)
        obj = K.link(bpy.data.objects.new("fox ear", mesh))
        bm = bmesh.new()
        bm.from_mesh(mesh)
        bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
        bm.to_mesh(mesh)
        bm.free()
        mesh.materials.append(K.material("fur"))
        return obj

    @staticmethod
    def sculpt(spec):
        sections = [(.45, .025, .42, .54), (.35, .12, .30, .60), (.18, .16, .27, .62),
                    (-.03, .17, .25, .61), (-.21, .15, .24, .62), (-.32, .13, .31, .67),
                    (-.40, .11, .46, .73), (-.49, .11, .56, .76), (-.58, .095, .55, .73),
                    (-.64, .065, .54, .66), (-.71, .040, .55, .62), (-.75, .014, .565, .595)]
        parts = [K.profile_body("fox contours", sections), Fox.ear(-1), Fox.ear(1)]
        for side in (-1, 1):
            x = spec["leg_width"] * side
            for front in (True, False):
                z = spec["front_z"] if front else spec["back_z"]
                if front:
                    chain = [(x * .7, .53, z), (x, .40, z), (x, .235, z - .005), (x, .045, z - .02)]
                    radii = [(.058, .075), (.044, .060), (.030, .040), (.023, .027)]
                else:
                    chain = [(x * .7, .49, z - .03), (x, .38, z + .03), (x, .235, z + .075), (x, .045, z)]
                    radii = [(.085, .100), (.074, .088), (.030, .039), (.022, .028)]
                parts.append(K.skin("fox leg", chain, [(0, 1), (1, 2), (2, 3)], radii, "fur"))
                parts.append(K.ellipsoid("fox paw", (x, .032, z - .032), (.033, .030, .050), "fur", segments=16, rings=10))
        brush = [(.30, .055, .42, .54), (.42, .080, .34, .55), (.57, .105, .22, .46),
                 (.73, .100, .14, .37), (.88, .065, .10, .26), (1.01, .020, .115, .18), (1.04, .003, .14, .15)]
        parts.append(K.profile_body("fox brush", list(reversed(brush))))
        coat = K.sculpt(parts, "coat", voxel=.006, smoothing=6, roughness=.002, keep=.12)
        coat.data.validate()
        return K.paint(coat, "fox winter coat", Fox.shade)

    @staticmethod
    def shade(p):
        smooth = Fox.smooth
        c = Vector((.73, .34, .14))
        c = c.lerp(Vector((.48, .25, .13)), smooth(.53, .65, p.y) * .23)
        cream = Vector((.88, .84, .73))
        chest = smooth(.17, .35, -p.z) * (1 - smooth(.58, .70, p.y))
        muzzle = smooth(.48, .67, -p.z) * (1 - smooth(.60, .66, p.y))
        belly = (1 - smooth(.29, .38, p.y)) * (1 - smooth(.20, .37, abs(p.z)))
        pale = max(chest, muzzle, belly * .7) * (1 - smooth(.105, .155, abs(p.x)))
        c = c.lerp(cream, pale)
        stockings = (1 - smooth(.16, .29, p.y)) * smooth(.045, .075, abs(p.x))
        c = c.lerp(Vector((.14, .10, .075)), stockings)
        if p.z > .42:
            c = c.lerp(Vector((.32, .24, .18)), smooth(.48, .78, p.z) * .35)
            c = c.lerp(cream, smooth(.86, .96, p.z))
        if p.y > .77 and -.56 < p.z < -.40:
            t = (p.y - .70) / .16
            center_z = -.50 + t * .04
            center_x = .082 + t * .058
            width = max(.001, .064 * max(0, 1 - t) ** .85)
            c = Vector((.15, .105, .075))
            if p.z < center_z - .003 and abs(abs(p.x) - center_x) < width * .70:
                c = Vector((.82, .70, .53))
        c *= 1 + noise.noise_vector(Vector((p.x * 90, p.y * 60, p.z * 70)))[0] * .045
        return c

    @staticmethod
    def extras():
        parts = [K.ellipsoid("fox nose", (0, .58, -.751), (.027, .019, .016), "ink", segments=16, rings=10)]
        for side in (-1, 1):
            parts.append(K.ellipsoid("fox eye socket", (side * .070, .693, -.564), (.014, .020, .025), "dark", segments=16, rings=10))
            parts.append(K.ellipsoid("fox iris", (side * .079, .694, -.566), (.006, .011, .014), "amber", segments=16, rings=10))
            parts.append(K.ellipsoid("fox pupil", (side * .084, .694, -.567), (.0025, .010, .004), "ink", segments=12, rings=8))
            parts.append(K.ellipsoid("fox eye glint", (side * .086, .699, -.569), (.0015, .002, .002), "glint", segments=8, rings=4))
        return parts

    @staticmethod
    def foot(x, z):
        return K.ellipsoid("fox paw pad", (x, .019, z - .026), (.020, .005, .025), "hoof", segments=12, rings=6)

    @staticmethod
    def bind(rig, coat):
        spec = Fox.spec()
        groups = {bone.name: coat.vertex_groups.get(bone.name) or coat.vertex_groups.new(name=bone.name) for bone in rig.data.bones}
        for vertex in coat.data.vertices:
            world = coat.matrix_world @ vertex.co
            p = Vector((world.x, world.z, -world.y))
            head = max(Fox.smooth(.37, .49, -p.z), Fox.smooth(.70, .76, p.y) if p.z < -.36 else 0)
            neck = (1 - head) * Fox.smooth(.24, .37, -p.z)
            tail = Fox.smooth(.35, .52, p.z)
            rear = Fox.smooth(-.10, .20, p.z)
            weights = {"head": head, "neck": neck, "tail": tail}
            body = max(0, 1 - head - neck - tail)
            weights.update(hips=body * rear, spine=body * (1 - rear))
            if p.y < .52 and abs(p.x) > .04 and p.z < .45:
                front = p.z < 0
                z = spec["front_z"] if front else spec["back_z"]
                limb = (1 - Fox.smooth(.33, .52, p.y)) * Fox.smooth(.04, .085, abs(p.x)) * (1 - Fox.smooth(.12, .21, abs(p.z - z)))
                for key in weights: weights[key] *= 1 - limb
                lower = 1 - Fox.smooth(.17, .31, p.y)
                tag = ("f" if front else "b") + ("l" if p.x < 0 else "r")
                weights["leg_" + tag + "_upper"] = limb * (1 - lower)
                weights["leg_" + tag + "_lower"] = limb * lower
            strongest = sorted(((key, value) for key, value in weights.items() if value > 1e-6), key=lambda pair: pair[1], reverse=True)[:4]
            total = sum(value for _, value in strongest)
            for group in coat.vertex_groups: group.remove([vertex.index])
            for key, value in strongest: groups[key].add([vertex.index], value / total, "REPLACE")

    @staticmethod
    def idle(rig, t):
        phase = t * math.tau
        K.turn(rig, "neck", "x", math.sin(phase) * .035)
        K.turn(rig, "head", "y", math.sin(phase) * .16)
        K.turn(rig, "tail", "y", math.sin(phase) * .065)

    @staticmethod
    def walk(rig, t):
        phase = t * math.tau
        for tag, offset in (("fl", 0), ("br", 0), ("fr", math.pi), ("bl", math.pi)):
            K.turn(rig, "leg_" + tag + "_upper", "x", math.sin(phase + offset) * .42)
            fold = max(math.cos(phase + offset), 0) * .60
            K.turn(rig, "leg_" + tag + "_lower", "x", -fold if tag[0] == "f" else fold * .65)
        K.shift(rig, "hips", (0, abs(math.sin(phase)) * .012, 0))
        K.turn(rig, "neck", "x", math.sin(phase * 2) * .025)
        K.turn(rig, "tail", "y", math.sin(phase) * .10)
