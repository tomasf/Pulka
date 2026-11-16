"""Builds the rider in Blender and exports it as glTF for Godot.

The body is one smooth surface grown from a stick skeleton with the Skin
modifier (no seams at neck, shoulders or hips), rigged to a named armature.
Head, hat, face, mittens and boots are smooth shapes riding on their bones.
One single-frame action per ride poses the rider sitting on it; Godot picks
the pose by the ride's name. Materials are named after what they are
(jacket, hat, pants...) so the game can dress each rider in its colours.

Run: blender -b -P tools/blender/rider.py -- models/rider.glb
"""

import math
import sys

import bpy
from mathutils import Matrix, Quaternion, Vector


# Where the joints are, in Godot space with the seat at the origin, for each
# ride (pulka, stjärtlapp, snowracer, tefat, wok): hands on the rope, strap,
# wheel or rim, knees and feet the way that ride makes you sit. Mirrored for
# the right side (+x).
POSES = {
    "pulka": {"hand": (0.30, 0.24, -0.34), "knee": (0.11, 0.26, -0.27), "foot": (0.09, 0.08, -0.46)},
    "stjartlapp": {"hand": (0.09, 0.07, -0.36), "knee": (0.12, 0.3, -0.24), "foot": (0.12, 0.02, -0.5)},
    "snowracer": {"hand": (0.14, 0.32, -0.58), "knee": (0.16, 0.13, -0.32), "foot": (0.2, -0.26, -0.62)},
    "tefat": {"hand": (0.48, 0.07, 0.0), "knee": (0.3, 0.17, -0.18), "foot": (0.1, 0.03, -0.34)},
    "wok": {"hand": (0.43, 0.13, 0.0), "knee": (0.28, 0.21, -0.16), "foot": (0.1, 0.06, -0.32)},
}

HIP = (0.105, 0.1, 0.0)
SHOULDER = (0.2, 0.57, 0.03)
NECK = (0.0, 0.69, 0.02)
HEAD = (0.0, 0.86, 0.0)

COLORS = {
    "jacket": (0.9, 0.3, 0.6),
    "jacket_trim": (0.95, 0.6, 0.8),
    "pants": (0.14, 0.17, 0.3),
    "boots": (0.28, 0.17, 0.1),
    "sole": (0.08, 0.07, 0.07),
    "skin": (0.96, 0.78, 0.66),
    "cheek": (0.97, 0.62, 0.58),
    "hair": (0.42, 0.26, 0.14),
    "hat": (0.95, 0.8, 0.1),
    "hat_cuff": (0.8, 0.65, 0.05),
    "scarf": (0.2, 0.5, 0.9),
    "white": (1.0, 1.0, 1.0),
    "ink": (0.06, 0.05, 0.05),
}


class RiderModel:
    """Builds and exports the rider (see the module docstring)."""

    @staticmethod
    def g(x, y, z):
        """Godot coordinates (x right, y up, -z forward) to Blender's (x
        right, y forward, z up); the glTF exporter turns them back."""
        return Vector((x, -z, y))

    @staticmethod
    def srgb_to_linear(c):
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4

    @staticmethod
    def material(name):
        if name in bpy.data.materials:
            return bpy.data.materials[name]
        mat = bpy.data.materials.new(name)
        mat.use_nodes = True
        bsdf = mat.node_tree.nodes.get("Principled BSDF")
        r, gg, b = COLORS[name]
        bsdf.inputs["Base Color"].default_value = (RiderModel.srgb_to_linear(r), RiderModel.srgb_to_linear(gg), RiderModel.srgb_to_linear(b), 1.0)
        bsdf.inputs["Roughness"].default_value = 0.8
        return mat

    @staticmethod
    def clear():
        bpy.ops.wm.read_factory_settings(use_empty=True)

    @staticmethod
    def link(obj):
        bpy.context.scene.collection.objects.link(obj)
        return obj

    @staticmethod
    def skin_object(name, joints, edges, radii, mat, subdivisions=2):
        """A smooth tube body grown along `edges` between `joints` (Blender
        space), `radii` per joint (x, y) giving its thickness."""
        mesh = bpy.data.meshes.new(name)
        mesh.from_pydata(joints, edges, [])
        obj = RiderModel.link(bpy.data.objects.new(name, mesh))
        skin = obj.modifiers.new("skin", "SKIN")
        skin.use_smooth_shade = True
        skin.branch_smoothing = 0.6
        for i, radius in enumerate(radii):
            obj.data.skin_vertices[0].data[i].radius = radius
        obj.data.skin_vertices[0].data[0].use_root = True
        sub = obj.modifiers.new("smooth", "SUBSURF")
        sub.levels = subdivisions
        sub.render_levels = subdivisions
        bpy.context.view_layer.objects.active = obj
        obj.select_set(True)
        for modifier in list(obj.modifiers):
            bpy.ops.object.modifier_apply(modifier=modifier.name)
        obj.select_set(False)
        obj.data.materials.append(RiderModel.material(mat))
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.shade_smooth()
        return obj

    @staticmethod
    def ellipsoid(name, center, radii, mat, rotation=(0, 0, 0), segments=16, rings=10):
        bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, radius=1.0, location=center)
        obj = bpy.context.active_object
        obj.name = name
        obj.scale = radii
        obj.rotation_euler = rotation
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
        bpy.ops.object.shade_smooth()
        obj.data.materials.append(RiderModel.material(mat))
        return obj

    @staticmethod
    def torus(name, center, major, minor, mat, rotation=(0, 0, 0), scale=(1, 1, 1)):
        bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, major_segments=24, minor_segments=8, location=center, rotation=rotation)
        obj = bpy.context.active_object
        obj.name = name
        obj.scale = scale
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
        bpy.ops.object.shade_smooth()
        obj.data.materials.append(RiderModel.material(mat))
        return obj

    @staticmethod
    def cylinder(name, center, radius, depth, mat, rotation=(0, 0, 0), vertices=16):
        bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=center, rotation=rotation)
        obj = bpy.context.active_object
        obj.name = name
        obj.data.materials.append(RiderModel.material(mat))
        return obj

    @staticmethod
    def join(objects, name):
        bpy.ops.object.select_all(action="DESELECT")
        for obj in objects:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = objects[0]
        bpy.ops.object.join()
        obj = bpy.context.active_object
        obj.name = name
        return obj

    @staticmethod
    def mirror(v, side):
        return (v[0] * side, v[1], v[2])

    @staticmethod
    def build():
        RiderModel.clear()
        rest = POSES["pulka"]
        joints = {}
        for side, tag in ((-1, "L"), (1, "R")):
            hand = Vector(RiderModel.mirror(rest["hand"], side))
            shoulder = Vector(RiderModel.mirror(SHOULDER, side))
            elbow = shoulder.lerp(hand, 0.5) + Vector((0.07 * side, -0.07, 0.04))
            joints["shoulder." + tag] = shoulder
            joints["elbow." + tag] = elbow
            joints["hand." + tag] = hand
            joints["hip." + tag] = Vector(RiderModel.mirror(HIP, side))
            joints["knee." + tag] = Vector(RiderModel.mirror(rest["knee"], side))
            joints["foot." + tag] = Vector(RiderModel.mirror(rest["foot"], side))

        # --- Armature ---
        arm_data = bpy.data.armatures.new("rig")
        rig = RiderModel.link(bpy.data.objects.new("rider", arm_data))
        bpy.context.view_layer.objects.active = rig
        bpy.ops.object.mode_set(mode="EDIT")

        def bone(name, head, tail, parent=None, connect=False):
            b = arm_data.edit_bones.new(name)
            b.head = RiderModel.g(*head)
            b.tail = RiderModel.g(*tail)
            if parent:
                b.parent = arm_data.edit_bones[parent]
                b.use_connect = connect
            return b

        bone("hips", (0, 0.02, 0.05), (0, 0.22, 0.05))
        bone("spine", (0, 0.22, 0.05), (0, 0.5, 0.04), "hips", True)
        bone("neck", (0, 0.5, 0.04), NECK, "spine", True)
        bone("head", NECK, (0, 1.05, 0.0), "neck", True)
        for tag in ("L", "R"):
            j = {k: joints[k + "." + tag] for k in ("shoulder", "elbow", "hand", "hip", "knee", "foot")}
            bone("upper_arm." + tag, j["shoulder"], j["elbow"], "spine")
            bone("forearm." + tag, j["elbow"], j["hand"], "upper_arm." + tag, True)
            bone("thigh." + tag, j["hip"], j["knee"], "hips")
            bone("shin." + tag, j["knee"], j["foot"], "thigh." + tag, True)
        bpy.ops.object.mode_set(mode="OBJECT")

        # --- Body: jacket (torso and arms) and trousers, each one skin ---
        # The torso is a column of joints whose thickness swells and pinches
        # in turn: the quilted bands of a puffer jacket.
        body_joints = []
        body_radii = []
        body_edges = []
        for k in range(9):
            t = k / 8.0
            y = 0.04 + t * 0.54
            width = (0.17 + 0.05 * math.sin(t * math.pi * 0.9)) * (0.82 if t > 0.92 else 1.0)
            puff = 0.012 if k % 2 == 1 else -0.004
            body_joints.append(RiderModel.g(0, y, 0.06 - t * 0.03))
            body_radii.append((width + puff, width * 0.8 + puff))
            if k > 0:
                body_edges.append((k - 1, k))
        top = len(body_joints) - 1
        body_joints.append(RiderModel.g(0, 0.66, 0.02))
        body_radii.append((0.1, 0.09))
        body_edges.append((top, top + 1))
        for tag in ("L", "R"):
            shoulder = joints["shoulder." + tag]
            elbow = joints["elbow." + tag]
            wrist = joints["hand." + tag] * 0.92 + elbow * 0.08
            chain = [shoulder, shoulder.lerp(elbow, 0.5), elbow, elbow.lerp(wrist, 0.5), wrist]
            sizes = [0.082, 0.076, 0.07, 0.066, 0.058]
            previous = top - 1
            for i, point in enumerate(chain):
                body_joints.append(RiderModel.g(*point))
                radius = sizes[i] + (0.007 if i % 2 == 1 else 0.0)
                body_radii.append((radius, radius))
                body_edges.append((previous, len(body_joints) - 1))
                previous = len(body_joints) - 1
        jacket = RiderModel.skin_object("jacket", body_joints, body_edges, body_radii, "jacket")

        leg_joints = [RiderModel.g(0, 0.08, 0.03)]
        leg_radii = [(0.15, 0.13)]
        leg_edges = []
        for tag in ("L", "R"):
            base = len(leg_joints)
            leg_joints += [RiderModel.g(*joints["hip." + tag]), RiderModel.g(*joints["knee." + tag]), RiderModel.g(*(joints["foot." + tag] + Vector((0, 0.07, 0.02))))]
            leg_radii += [(0.095, 0.095), (0.082, 0.082), (0.07, 0.07)]
            leg_edges += [(0, base), (base, base + 1), (base + 1, base + 2)]
        pants = RiderModel.skin_object("pants", leg_joints, leg_edges, leg_radii, "pants")

        # A zip down the front, knitted cuffs at the wrists and a hood folded
        # down at the back of the neck.
        seams = [RiderModel.ellipsoid("hood", RiderModel.g(0, 0.64, 0.12), (0.14, 0.07, 0.09), "jacket", rotation=(math.radians(25), 0, 0), segments=16, rings=8)]
        seams += [RiderModel.cylinder("zip", RiderModel.g(0, 0.43, -0.135), 0.01, 0.24, "jacket_trim", rotation=(math.radians(-8), 0, 0), vertices=8)]
        for tag, side in (("L", -1), ("R", 1)):
            cuff_at = joints["hand." + tag] * 0.85 + joints["elbow." + tag] * 0.15
            seams.append(RiderModel.ellipsoid("cuff", RiderModel.g(*cuff_at), (0.064, 0.064, 0.064), "jacket_trim", segments=12, rings=6))
        trim = RiderModel.join(seams, "jacket_trim")

        # Scarf: a wrap round the neck and a tail fluttering behind.
        scarf = [RiderModel.torus("scarf", RiderModel.g(0, 0.66, 0.01), 0.11, 0.045, "scarf")]
        scarf.append(RiderModel.torus("scarf2", RiderModel.g(0, 0.71, 0.01), 0.1, 0.035, "white"))
        tail = RiderModel.cylinder("tail", RiderModel.g(0.08, 0.55, 0.22), 0.04, 0.3, "scarf", rotation=(math.radians(-55), math.radians(10), 0), vertices=10)
        scarf.append(tail)
        neck_wrap = RiderModel.join(scarf, "scarf")

        # --- Head: a round face with eyes, nose, smile, cheeks; hair; beanie ---
        h = Vector(HEAD)
        parts = [RiderModel.ellipsoid("head", RiderModel.g(*h), (0.15, 0.148, 0.155), "skin", segments=24, rings=16)]
        parts.append(RiderModel.ellipsoid("hair", RiderModel.g(*(h + Vector((0, 0.015, 0.045)))), (0.153, 0.124, 0.128), "hair", segments=20, rings=12))
        for side in (-1, 1):
            eye = h + Vector((0.055 * side, 0.004, -0.133))
            parts.append(RiderModel.ellipsoid("eye", RiderModel.g(*eye), (0.019, 0.012, 0.026), "ink", segments=12, rings=8))
            parts.append(RiderModel.ellipsoid("glint", RiderModel.g(*(eye + Vector((0.006, 0.01, -0.01)))), (0.006, 0.006, 0.006), "white", segments=8, rings=4))
            parts.append(RiderModel.ellipsoid("brow", RiderModel.g(*(h + Vector((0.058 * side, 0.046, -0.13)))), (0.024, 0.005, 0.007), "hair", rotation=(0, math.radians(-8 * side), 0), segments=10, rings=4))
            parts.append(RiderModel.ellipsoid("cheek", RiderModel.g(*(h + Vector((0.09 * side, -0.04, -0.105)))), (0.03, 0.009, 0.02), "cheek", rotation=(0, math.radians(30 * side), 0), segments=12, rings=6))
            parts.append(RiderModel.ellipsoid("ear", RiderModel.g(*(h + Vector((0.148 * side, -0.015, 0.01)))), (0.018, 0.032, 0.028), "skin", segments=10, rings=6))
        parts.append(RiderModel.ellipsoid("nose", RiderModel.g(*(h + Vector((0, -0.02, -0.152)))), (0.02, 0.022, 0.017), "cheek", segments=12, rings=8))
        smile = RiderModel.torus("smile", RiderModel.g(*(h + Vector((0, -0.045, -0.132)))), 0.032, 0.0055, "ink", rotation=(math.radians(-8), 0, 0))
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="DESELECT")
        bpy.ops.object.mode_set(mode="OBJECT")
        # Keep only the lower arc of the ring: a smile.
        for item in list(smile.data.polygons) + list(smile.data.edges):
            item.select = False
        for v in smile.data.vertices:
            v.select = (smile.matrix_world @ v.co).z > RiderModel.g(*(h + Vector((0, -0.05, 0)))).z
        bpy.context.view_layer.objects.active = smile
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.delete(type="VERT")
        bpy.ops.object.mode_set(mode="OBJECT")
        parts.append(smile)
        # Beanie: a dome over the top, a folded ribbed cuff, a fluffy pom-pom.
        dome = RiderModel.ellipsoid("beanie", RiderModel.g(*(h + Vector((0, 0.075, 0.004)))), (0.155, 0.16, 0.16), "hat", segments=24, rings=14)
        bpy.context.view_layer.objects.active = dome
        for item in list(dome.data.polygons) + list(dome.data.edges):
            item.select = False
        for v in dome.data.vertices:
            v.select = (dome.matrix_world @ v.co).z < RiderModel.g(*(h + Vector((0, 0.06, 0)))).z
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.delete(type="VERT")
        bpy.ops.object.mode_set(mode="OBJECT")
        parts.append(dome)
        parts.append(RiderModel.torus("cuff", RiderModel.g(*(h + Vector((0, 0.085, 0.004)))), 0.15, 0.032, "hat_cuff", scale=(1, 1, 1.15)))
        for k, offset in enumerate(((0, 0, 0), (0.025, -0.01, 0.0), (-0.022, 0.0, 0.018), (0, 0.018, -0.02), (0.01, 0.01, 0.02))):
            parts.append(RiderModel.ellipsoid("pom", RiderModel.g(*(h + Vector((0, 0.27, 0.01)) + Vector(offset))), (0.045, 0.045, 0.045), "white", segments=10, rings=6))
        head = RiderModel.join(parts, "face")

        # --- Mittens and boots ---
        hands = {}
        feet = {}
        for tag, side in (("L", -1), ("R", 1)):
            hand = joints["hand." + tag]
            mitt = [RiderModel.ellipsoid("mitten", RiderModel.g(*hand), (0.06, 0.07, 0.085), "hat", segments=14, rings=8)]
            mitt.append(RiderModel.ellipsoid("thumb", RiderModel.g(*(hand + Vector((-0.045 * side, 0.03, -0.02)))), (0.025, 0.025, 0.035), "hat", segments=10, rings=6))
            mitt.append(RiderModel.torus("band", RiderModel.g(*(hand + Vector((0, 0.0, 0.05)))), 0.05, 0.012, "white", rotation=(math.radians(90), 0, 0)))
            hands[tag] = RiderModel.join(mitt, "mitten." + tag)
            foot = joints["foot." + tag]
            boot = [RiderModel.ellipsoid("boot", RiderModel.g(*(foot + Vector((0, 0.03, -0.03)))), (0.075, 0.075, 0.125), "boots", segments=16, rings=10)]
            boot.append(RiderModel.cylinder("shaft", RiderModel.g(*(foot + Vector((0, 0.08, 0.01)))), 0.078, 0.11, "boots", vertices=16))
            boot.append(RiderModel.ellipsoid("sole", RiderModel.g(*(foot + Vector((0, -0.035, -0.03)))), (0.078, 0.02, 0.13), "sole", segments=16, rings=6))
            feet[tag] = RiderModel.join(boot, "boot." + tag)

        # --- Rigging: the soft body by weights, the rest rigidly on a bone ---
        for obj in (jacket, pants, trim, neck_wrap):
            bpy.ops.object.select_all(action="DESELECT")
            obj.select_set(True)
            rig.select_set(True)
            bpy.context.view_layer.objects.active = rig
            bpy.ops.object.parent_set(type="ARMATURE_AUTO")
        rigid = [(head, "head")]
        for tag in ("L", "R"):
            rigid += [(hands[tag], "forearm." + tag), (feet[tag], "shin." + tag)]
        for obj, bone_name in rigid:
            # Weighted wholly to its bone, so glTF skins it like the body.
            group = obj.vertex_groups.new(name=bone_name)
            group.add(range(len(obj.data.vertices)), 1.0, "REPLACE")
            modifier = obj.modifiers.new("rig", "ARMATURE")
            modifier.object = rig
            obj.parent = rig

        # --- One pose per ride, as a single-frame action ---
        bpy.context.view_layer.objects.active = rig
        bpy.ops.object.mode_set(mode="POSE")
        rig.animation_data_create()
        for ride, pose in POSES.items():
            for pb in rig.pose.bones:
                pb.rotation_mode = "QUATERNION"
                pb.rotation_quaternion = Quaternion()
                pb.location = Vector()
            bpy.context.view_layer.update()
            for tag, side in (("L", -1), ("R", 1)):
                hand = Vector(RiderModel.mirror(pose["hand"], side))
                shoulder = Vector(RiderModel.mirror(SHOULDER, side))
                elbow = shoulder.lerp(hand, 0.5) + Vector((0.07 * side, -0.07, 0.04))
                RiderModel.aim(rig, "upper_arm." + tag, RiderModel.g(*elbow))
                RiderModel.aim(rig, "forearm." + tag, RiderModel.g(*hand))
                RiderModel.aim(rig, "thigh." + tag, RiderModel.g(*RiderModel.mirror(pose["knee"], side)))
                RiderModel.aim(rig, "shin." + tag, RiderModel.g(*RiderModel.mirror(pose["foot"], side)))
            action = bpy.data.actions.new(ride)
            action.use_fake_user = True
            rig.animation_data.action = action
            for pb in rig.pose.bones:
                pb.keyframe_insert("rotation_quaternion", frame=1)
                pb.keyframe_insert("location", frame=1)
            track = rig.animation_data.nla_tracks.new()
            track.name = ride
            track.strips.new(ride, 1, action)
            rig.animation_data.action = None
        bpy.ops.object.mode_set(mode="OBJECT")
        return rig

    @staticmethod
    def aim(rig, bone_name, target):
        """Turns a pose bone so it points from where its head now is to target."""
        bpy.context.view_layer.update()
        pb = rig.pose.bones[bone_name]
        head = rig.matrix_world @ pb.head
        tail = rig.matrix_world @ pb.tail
        current = (tail - head).normalized()
        wanted = (target - head).normalized()
        turn = current.rotation_difference(wanted)
        world = Matrix.Translation(head) @ turn.to_matrix().to_4x4() @ Matrix.Translation(-head) @ (rig.matrix_world @ pb.matrix)
        pb.matrix = rig.matrix_world.inverted() @ world
        bpy.context.view_layer.update()

    @staticmethod
    def export(path):
        bpy.ops.export_scene.gltf(
            filepath=path,
            export_format="GLB",
            export_yup=True,
            export_apply=False,
            export_skins=True,
            export_animations=True,
            export_animation_mode="NLA_TRACKS",
            export_force_sampling=True,
            export_nla_strips=True,
        )


if __name__ == "__main__":
    out = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "rider.glb"
    RiderModel.build()
    RiderModel.export(out)
    print("Wrote", out)
