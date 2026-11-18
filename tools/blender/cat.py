"""Domestic shorthair, sculpted as one coat, with a relaxed upright tail.

See REFERENCES.md for full-body and head photographs. No photo textures.
"""
import math

import bpy
import bmesh
from mathutils import Vector, noise

from model_kit import ModelKit as K


class Cat:
    @staticmethod
    def spec():
        return {
            "name": "cat",
            "colors": {"fur": (.63, .62, .60), "ink": (.055, .045, .04),
                       "iris": (.62, .70, .28), "pink": (.64, .39, .38),
                       "glint": (.97, .98, .90), "hoof": (.42, .38, .36)},
            "sculpt": Cat.sculpt, "extras": Cat.extras, "feet": Cat.foot,
            "bind": Cat.bind, "walk_animation": Cat.walk, "idle_animation": Cat.idle,
            "front_z": -.18, "back_z": .20, "hip_y": .28, "knee_y": .145,
            "hoof_height": .022, "leg_width": .072, "hock": .045, "knee": .005,
            "body": [((0, .30, .27), (.10, .10)), ((0, .30, .12), (.12, .12)),
                     ((0, .30, -.10), (.10, .12)), ((0, .32, -.21), (.09, .10)),
                     ((0, .36, -.26), (.08, .08)), ((0, .38, -.33), (.09, .08)),
                     ((0, .32, -.42), (.035, .025))],
            "neck_joint": 4,
            "tail": ((0, .33, .27), (0, .72, .44), .030, .010),
        }

    @staticmethod
    def smooth(a, b, value):
        t = max(0, min(1, (value - a) / (b - a)))
        return t * t * (3 - 2 * t)

    @staticmethod
    def ear(side):
        vertices, faces = [], []
        root, tip = Vector((side * .065, .405, -.295)), Vector((side * .100, .525, -.28))
        count, rings = 16, 9
        for j in range(rings):
            t = j / (rings - 1)
            centre = root.lerp(tip, t)
            width = max(.001, .045 * (1 - t) ** .8)
            depth = .016 * (1 - t) + .002
            for k in range(count):
                angle = k * math.tau / count
                vertices.append(K.g(*(centre + Vector((math.cos(angle) * width, 0, math.sin(angle) * depth)))))
        for j in range(rings - 1):
            for k in range(count):
                a, b = j * count + k, j * count + (k + 1) % count
                faces.append((a, b, b + count, a + count))
        faces += [tuple(reversed(range(count))), tuple(range((rings - 1) * count, rings * count))]
        mesh = bpy.data.meshes.new("cat ear")
        mesh.from_pydata(vertices, [], faces)
        obj = K.link(bpy.data.objects.new("cat ear", mesh))
        bm = bmesh.new()
        bm.from_mesh(mesh)
        bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
        bm.to_mesh(mesh)
        bm.free()
        mesh.materials.append(K.material("fur"))
        return obj

    @staticmethod
    def sculpt(spec):
        sections = [(.315, .025, .26, .35), (.24, .10, .18, .38), (.10, .12, .16, .39),
                    (-.08, .11, .15, .385), (-.19, .10, .16, .39), (-.245, .085, .25, .415),
                    (-.29, .098, .28, .455), (-.345, .092, .28, .445),
                    (-.385, .070, .285, .405), (-.42, .035, .29, .35), (-.435, .008, .30, .325)]
        parts = [K.profile_body("cat contours", sections), Cat.ear(-1), Cat.ear(1)]
        for side in (-1, 1):
            x = spec["leg_width"] * side
            for front in (True, False):
                z = spec["front_z"] if front else spec["back_z"]
                chain = [(x * .75, .33, z), (x, .25, z + (0 if front else .015)),
                         (x, .145, z + (-.005 if front else .045)), (x, .032, z - .008)]
                radii = [(.044, .055), (.033, .042), (.022, .028), (.017, .020)] if front else [(.062, .073), (.052, .060), (.024, .030), (.018, .020)]
                parts.append(K.skin("cat leg", chain, [(0, 1), (1, 2), (2, 3)], radii, "fur"))
                parts.append(K.ellipsoid("cat paw", (x, .022, z - .025), (.026, .021, .037), "fur"))
        tail = [(0, .33, .255), (0, .38, .34), (0, .48, .405),
                (0, .61, .445), (0, .72, .44), (0, .755, .405), (0, .735, .37)]
        parts.append(K.skin("cat tail", tail, [(i, i + 1) for i in range(len(tail) - 1)],
                            [(.030, .030), (.028, .028), (.026, .026), (.023, .023), (.020, .020), (.016, .016), (.009, .009)], "fur"))
        coat = K.sculpt(parts, "coat", voxel=.0045, smoothing=5, roughness=.001, keep=.14)
        K.paint(coat, "cat coat", Cat.shade)
        # The white bib and socks keep their colour when the striped coat is
        # tinted in the game. Both materials use the same painted vertices.
        white = bpy.data.materials.new("cat white")
        white.use_nodes = True
        colour = white.node_tree.nodes.new("ShaderNodeVertexColor")
        colour.layer_name = "Col"
        bsdf = white.node_tree.nodes.get("Principled BSDF")
        white.node_tree.links.new(colour.outputs["Color"], bsdf.inputs["Base Color"])
        bsdf.inputs["Roughness"].default_value = .9
        coat.data.materials.append(white)
        for face in coat.data.polygons:
            world = coat.matrix_world @ face.center
            p = Vector((world.x, world.z, -world.y))
            if Cat.white(p) > .5: face.material_index = 1
        return coat

    @staticmethod
    def white(p):
        chest = Cat.smooth(.12, .22, -p.z) * (1 - Cat.smooth(.28, .34, p.y))
        muzzle = Cat.smooth(.34, .40, -p.z) * (1 - Cat.smooth(.33, .36, p.y))
        socks = (1 - Cat.smooth(.04, .065, p.y)) * Cat.smooth(.025, .06, abs(p.x))
        return max(chest, muzzle, socks)

    @staticmethod
    def shade(p):
        stripe = max(0, math.cos(p.z * 57 + p.y * 10 + math.sin(p.y * 29) * .6)) ** 6
        c = Vector((.70, .69, .67)).lerp(Vector((.30, .30, .29)), stripe * .7)
        if p.z > .30:
            rings = max(0, math.cos(p.y * 65)) ** 4
            c = Vector((.62, .61, .59)).lerp(Vector((.22, .23, .23)), rings * .65)
        c = c.lerp(Vector((.93, .91, .87)), Cat.white(p))
        if p.y > .445 and -.32 < p.z < -.25:
            t = (p.y - .405) / .12
            cx, cz = .065 + .035 * t, -.295 + .015 * t
            width = max(.001, .045 * max(0, 1 - t) ** .8)
            if p.z < cz - .003 and abs(abs(p.x) - cx) < width * .65:
                c = Vector((.69, .49, .47))
        c *= 1 + noise.noise_vector(p * 120)[0] * .035
        return c

    @staticmethod
    def extras():
        parts = [K.ellipsoid("cat nose", (0, .326, -.434), (.012, .008, .007), "pink", segments=12, rings=8)]
        for side in (-1, 1):
            eye = Vector((side * .052, .382, -.371))
            turn = (0, side * -.40, 0)
            parts.append(K.ellipsoid("cat eyelid", eye, (.022, .015, .010), "ink", rotation=turn))
            parts.append(K.ellipsoid("cat iris", eye + Vector((side * .003, 0, -.005)), (.017, .011, .006), "iris", rotation=turn))
            parts.append(K.ellipsoid("cat pupil", eye + Vector((side * .005, 0, -.010)), (.0025, .010, .002), "ink", rotation=turn))
            parts.append(K.ellipsoid("cat eye glint", eye + Vector((side * .002, .004, -.011)), (.0015, .0015, .001), "glint", segments=8, rings=6))
            # Short whiskers root inside the white muzzle rather than floating.
            for j in range(2):
                parts.append(K.tube("cat whisker", (side * .026, .317, -.411 + j * .006),
                                    (side * .104, .310 + j * .014, -.418 + j * .020), .0008, "glint", end_radius=.0003, vertices=6))
        parts.append(K.tube("cat philtrum", (0, .321, -.435), (0, .308, -.428), .0015, "ink", vertices=8))
        return parts

    @staticmethod
    def foot(x, z):
        return K.ellipsoid("cat paw pad", (x, .014, z - .020), (.014, .004, .021), "hoof", segments=12, rings=6)

    @staticmethod
    def bind(rig, coat):
        groups = {bone.name: coat.vertex_groups.get(bone.name) or coat.vertex_groups.new(name=bone.name) for bone in rig.data.bones}
        spec = Cat.spec()
        for vertex in coat.data.vertices:
            q = coat.matrix_world @ vertex.co
            p = Vector((q.x, q.z, -q.y))
            head = Cat.smooth(.24, .30, -p.z)
            neck = (1 - head) * Cat.smooth(.17, .25, -p.z)
            tail = Cat.smooth(.27, .35, p.z)
            body = max(0, 1 - head - neck - tail)
            rear = Cat.smooth(-.08, .15, p.z)
            weights = {"head": head, "neck": neck, "tail": tail, "hips": body * rear, "spine": body * (1 - rear)}
            if p.y < .32 and abs(p.x) > .03:
                front = p.z < 0
                z = spec["front_z"] if front else spec["back_z"]
                limb = (1 - Cat.smooth(.21, .32, p.y)) * Cat.smooth(.03, .06, abs(p.x)) * (1 - Cat.smooth(.08, .15, abs(p.z - z)))
                for key in weights: weights[key] *= 1 - limb
                lower = 1 - Cat.smooth(.10, .19, p.y)
                tag = ("f" if front else "b") + ("l" if p.x < 0 else "r")
                weights["leg_" + tag + "_upper"] = limb * (1 - lower)
                weights["leg_" + tag + "_lower"] = limb * lower
            strongest = sorted(((key, value) for key, value in weights.items() if value > 1e-6), key=lambda item: item[1], reverse=True)[:4]
            total = sum(value for _, value in strongest)
            for group in coat.vertex_groups: group.remove([vertex.index])
            for key, value in strongest: groups[key].add([vertex.index], value / total, "REPLACE")
        # Blender 5.2's glTF exporter fills the second painted material's
        # vertex colours with white. Separate by material after weighting:
        # both surfaces retain identical positions, normals and bone weights,
        # and each exports its own painted gradient correctly.
        bpy.ops.object.select_all(action="DESELECT")
        coat.select_set(True)
        bpy.context.view_layer.objects.active = coat
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.mesh.separate(type="MATERIAL")
        bpy.ops.object.mode_set(mode="OBJECT")

    @staticmethod
    def idle(rig, t):
        phase = t * math.tau
        K.turn(rig, "head", "y", math.sin(phase) * .22)
        K.turn(rig, "neck", "x", math.sin(phase) * .025)
        K.turn(rig, "tail", "z", math.sin(phase) * .045)

    @staticmethod
    def walk(rig, t):
        phase = t * math.tau
        for tag, offset in (("bl", 0), ("fl", math.pi / 2), ("br", math.pi), ("fr", math.pi * 1.5)):
            K.turn(rig, "leg_" + tag + "_upper", "x", math.sin(phase + offset) * .34)
            fold = max(math.cos(phase + offset), 0) * .40
            K.turn(rig, "leg_" + tag + "_lower", "x", -fold if tag[0] == "f" else fold * .65)
        K.shift(rig, "hips", (0, abs(math.sin(phase * 2)) * .004, 0))
        K.turn(rig, "tail", "z", math.sin(phase) * .055)
