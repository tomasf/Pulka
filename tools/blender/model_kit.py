"""Shared tools for the Blender model scripts: smooth bodies grown from
stick skeletons, rounded parts, rigging, looping animations and glTF export.

Coordinates passed in are Godot's (x right, y up, -z forward); ModelKit.g
turns them into Blender's, and the exporter turns them back.
"""

import math

import bpy
from mathutils import Matrix, Quaternion, Vector


class ModelKit:
    """Builds a model in the current (empty) Blender scene."""

    #: Material name -> sRGB colour; each script fills it in.
    colors = {}

    @staticmethod
    def g(x, y, z):
        """Godot coordinates to Blender's."""
        return Vector((x, -z, y))

    @staticmethod
    def clear():
        bpy.ops.wm.read_factory_settings(use_empty=True)

    @staticmethod
    def material(name):
        if name in bpy.data.materials:
            return bpy.data.materials[name]
        mat = bpy.data.materials.new(name)
        mat.use_nodes = True
        bsdf = mat.node_tree.nodes.get("Principled BSDF")
        linear = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in ModelKit.colors[name]]
        bsdf.inputs["Base Color"].default_value = (linear[0], linear[1], linear[2], 1.0)
        bsdf.inputs["Roughness"].default_value = 0.85
        return mat

    @staticmethod
    def link(obj):
        bpy.context.scene.collection.objects.link(obj)
        return obj

    @staticmethod
    def skin(name, joints, edges, radii, mat, subdivisions=2):
        """A smooth body grown along `edges` between `joints` (Godot
        coordinates), `radii` per joint (across, front to back)."""
        mesh = bpy.data.meshes.new(name)
        mesh.from_pydata([ModelKit.g(*j) for j in joints], edges, [])
        obj = ModelKit.link(bpy.data.objects.new(name, mesh))
        skin = obj.modifiers.new("skin", "SKIN")
        skin.use_smooth_shade = True
        skin.branch_smoothing = 0.6
        for i, radius in enumerate(radii):
            obj.data.skin_vertices[0].data[i].radius = radius
        obj.data.skin_vertices[0].data[0].use_root = True
        sub = obj.modifiers.new("smooth", "SUBSURF")
        sub.levels = subdivisions
        sub.render_levels = subdivisions
        ModelKit._apply_modifiers(obj)
        obj.data.materials.append(ModelKit.material(mat))
        bpy.ops.object.shade_smooth()
        return obj

    @staticmethod
    def _apply_modifiers(obj):
        bpy.ops.object.select_all(action="DESELECT")
        bpy.context.view_layer.objects.active = obj
        obj.select_set(True)
        for modifier in list(obj.modifiers):
            bpy.ops.object.modifier_apply(modifier=modifier.name)

    @staticmethod
    def ellipsoid(name, center, radii, mat, rotation=(0, 0, 0), segments=16, rings=10):
        """A rounded part; `center` in Godot coordinates, `radii` along
        Godot x, y and z, `rotation` in radians about Godot x, y and z."""
        bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, radius=1.0, location=ModelKit.g(*center))
        obj = bpy.context.active_object
        obj.name = name
        obj.scale = (radii[0], radii[2], radii[1])
        obj.rotation_euler = (rotation[0], -rotation[2], rotation[1])
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
        bpy.ops.object.shade_smooth()
        obj.data.materials.append(ModelKit.material(mat))
        return obj

    @staticmethod
    def tube(name, a, b, radius, mat, end_radius=None, vertices=12):
        """A tapered round rod from a to b (Godot coordinates)."""
        start = ModelKit.g(*a)
        end = ModelKit.g(*b)
        span = end - start
        bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=radius, radius2=radius if end_radius is None else end_radius, depth=span.length, location=(start + end) * 0.5)
        obj = bpy.context.active_object
        obj.name = name
        obj.rotation_mode = "QUATERNION"
        obj.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(span.normalized())
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
        bpy.ops.object.shade_smooth()
        obj.data.materials.append(ModelKit.material(mat))
        return obj

    @staticmethod
    def torus(name, center, major, minor, mat, rotation=(0, 0, 0), scale=(1, 1, 1)):
        """A ring lying flat (around Godot y) unless rotated."""
        bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, major_segments=24, minor_segments=8, location=ModelKit.g(*center), rotation=(rotation[0], -rotation[2], rotation[1]))
        obj = bpy.context.active_object
        obj.name = name
        obj.scale = (scale[0], scale[2], scale[1])
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
        bpy.ops.object.shade_smooth()
        obj.data.materials.append(ModelKit.material(mat))
        return obj

    @staticmethod
    def keep(obj, test):
        """Deletes the vertices whose Godot position fails `test`."""
        for item in list(obj.data.polygons) + list(obj.data.edges):
            item.select = False
        for v in obj.data.vertices:
            world = obj.matrix_world @ v.co
            v.select = not test(Vector((world.x, world.z, -world.y)))
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.delete(type="VERT")
        bpy.ops.object.mode_set(mode="OBJECT")
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
    def face(center, radius, hat, hair="hair"):
        """A friendly cartoon head: eyes with a glint, brows, nose, cheeks,
        a smile, ears, hair at the back and a beanie with a pom-pom.
        `center` and `radius` in Godot units; returns the joined object."""
        h = Vector(center)
        r = radius / 0.15
        parts = [ModelKit.ellipsoid("head", h, (0.15 * r, 0.148 * r, 0.155 * r), "skin", segments=24, rings=16)]
        parts.append(ModelKit.ellipsoid("hair", h + Vector((0, 0.015, 0.045)) * r, (0.153 * r, 0.124 * r, 0.128 * r), hair, segments=20, rings=12))
        for side in (-1, 1):
            eye = h + Vector((0.055 * side, 0.004, -0.133)) * r
            parts.append(ModelKit.ellipsoid("eye", eye, (0.019 * r, 0.026 * r, 0.012 * r), "ink", segments=12, rings=8))
            parts.append(ModelKit.ellipsoid("glint", eye + Vector((0.006, 0.01, -0.01)) * r, (0.006 * r,) * 3, "white", segments=8, rings=4))
            parts.append(ModelKit.ellipsoid("brow", h + Vector((0.058 * side, 0.046, -0.13)) * r, (0.024 * r, 0.007 * r, 0.005 * r), hair, rotation=(0, 0, math.radians(8 * side)), segments=10, rings=4))
            parts.append(ModelKit.ellipsoid("cheek", h + Vector((0.09 * side, -0.04, -0.105)) * r, (0.03 * r, 0.02 * r, 0.009 * r), "cheek", rotation=(0, math.radians(-30 * side), 0), segments=12, rings=6))
            parts.append(ModelKit.ellipsoid("ear", h + Vector((0.148 * side, -0.015, 0.01)) * r, (0.018 * r, 0.028 * r, 0.032 * r), "skin", segments=10, rings=6))
        parts.append(ModelKit.ellipsoid("nose", h + Vector((0, -0.02, -0.152)) * r, (0.02 * r, 0.017 * r, 0.022 * r), "cheek", segments=12, rings=8))
        smile_at = h + Vector((0, -0.045, -0.132)) * r
        smile = ModelKit.torus("smile", smile_at, 0.032 * r, 0.0055 * r, "ink", rotation=(math.radians(90 - 8), 0, 0))
        parts.append(ModelKit.keep(smile, lambda p: p.y < smile_at.y - 0.004 * r))
        dome_at = h + Vector((0, 0.075, 0.004)) * r
        dome = ModelKit.ellipsoid("beanie", dome_at, (0.155 * r, 0.16 * r, 0.16 * r), hat, segments=24, rings=14)
        parts.append(ModelKit.keep(dome, lambda p: p.y > h.y + 0.06 * r))
        parts.append(ModelKit.torus("cuff", h + Vector((0, 0.085, 0.004)) * r, 0.15 * r, 0.032 * r, hat + "_cuff", scale=(1, 1.15, 1)))
        for offset in ((0, 0, 0), (0.025, -0.01, 0.0), (-0.022, 0.0, 0.018), (0, 0.018, -0.02), (0.01, 0.01, 0.02)):
            parts.append(ModelKit.ellipsoid("pom", h + (Vector((0, 0.27, 0.01)) + Vector(offset)) * r, (0.045 * r,) * 3, "white", segments=10, rings=6))
        return ModelKit.join(parts, "face")

    @staticmethod
    def sculpt(objects, name, voxel=0.02, smoothing=6, roughness=0.0, keep=0.25):
        """Melts overlapping shapes into one smooth body, like clay: a voxel
        remesh joins them, smoothing rounds off the joins, a little noise
        (`roughness`, in metres) roughs up the surface like fur, and
        decimation (`keep`, the share of faces kept) thins it out."""
        obj = ModelKit.join(objects, name)
        remesh = obj.modifiers.new("remesh", "REMESH")
        remesh.mode = "VOXEL"
        remesh.voxel_size = voxel
        smooth = obj.modifiers.new("smooth", "SMOOTH")
        smooth.iterations = smoothing
        smooth.factor = 0.6
        if roughness > 0.0:
            texture = bpy.data.textures.new(name + "_fur", "CLOUDS")
            texture.noise_scale = 0.06
            displace = obj.modifiers.new("fur", "DISPLACE")
            displace.texture = texture
            displace.strength = roughness
            displace.mid_level = 0.5
        decimate = obj.modifiers.new("decimate", "DECIMATE")
        decimate.ratio = keep
        ModelKit._apply_modifiers(obj)
        obj.data.materials.clear()
        bpy.ops.object.shade_smooth()
        return obj

    @staticmethod
    def paint(obj, name, shade):
        """Colours a body vertex by vertex: `shade(position)` gives the sRGB
        colour at each Godot-space position. The body gets a material
        `name` that shows those colours."""
        mesh = obj.data
        layer = mesh.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
        for v in mesh.vertices:
            world = obj.matrix_world @ v.co
            r, gg, b = shade(Vector((world.x, world.z, -world.y)))
            linear = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in (r, gg, b)]
            layer.data[v.index].color = (linear[0], linear[1], linear[2], 1.0)
        mat = bpy.data.materials.new(name)
        mat.use_nodes = True
        nodes = mat.node_tree.nodes
        bsdf = nodes.get("Principled BSDF")
        colour = nodes.new("ShaderNodeVertexColor")
        colour.layer_name = "Col"
        mat.node_tree.links.new(colour.outputs["Color"], bsdf.inputs["Base Color"])
        bsdf.inputs["Roughness"].default_value = 0.9
        mesh.materials.append(mat)
        return obj

    # --- Rigging ---

    @staticmethod
    def armature(name, bones):
        """An armature from (name, head, tail, parent, connected) entries,
        heads and tails in Godot coordinates."""
        data = bpy.data.armatures.new(name)
        rig = ModelKit.link(bpy.data.objects.new(name, data))
        bpy.context.view_layer.objects.active = rig
        bpy.ops.object.mode_set(mode="EDIT")
        for bone_name, head, tail, parent, connected in bones:
            bone = data.edit_bones.new(bone_name)
            bone.head = ModelKit.g(*head)
            bone.tail = ModelKit.g(*tail)
            if parent:
                bone.parent = data.edit_bones[parent]
                bone.use_connect = connected
        bpy.ops.object.mode_set(mode="OBJECT")
        return rig

    @staticmethod
    def weigh(rig, soft, rigid):
        """Binds `soft` objects to the rig by automatic weights and each
        (object, bone) in `rigid` wholly to that bone."""
        for obj in soft:
            bpy.ops.object.select_all(action="DESELECT")
            obj.select_set(True)
            rig.select_set(True)
            bpy.context.view_layer.objects.active = rig
            bpy.ops.object.parent_set(type="ARMATURE_AUTO")
        for obj, bone_name in rigid:
            group = obj.vertex_groups.new(name=bone_name)
            group.add(range(len(obj.data.vertices)), 1.0, "REPLACE")
            modifier = obj.modifiers.new("rig", "ARMATURE")
            modifier.object = rig
            obj.parent = rig

    @staticmethod
    def animate(rig, name, frames, pose, loop=True):
        """Records an action: `pose(rig, t)` sets the pose bones for t in
        0..1 across `frames` frames; a loop repeats its first frame last."""
        bpy.context.view_layer.objects.active = rig
        bpy.ops.object.mode_set(mode="POSE")
        if rig.animation_data is None:
            rig.animation_data_create()
        action = bpy.data.actions.new(name)
        action.use_fake_user = True
        rig.animation_data.action = action
        count = frames + 1 if loop else frames
        for frame in range(count):
            for pb in rig.pose.bones:
                pb.rotation_mode = "QUATERNION"
                pb.rotation_quaternion = Quaternion()
                pb.location = Vector()
            pose(rig, (frame % frames) / frames if loop else frame / max(frames - 1, 1))
            for pb in rig.pose.bones:
                pb.keyframe_insert("rotation_quaternion", frame=frame + 1)
                pb.keyframe_insert("location", frame=frame + 1)
        track = rig.animation_data.nla_tracks.new()
        track.name = name
        track.strips.new(name, 1, action)
        rig.animation_data.action = None
        bpy.ops.object.mode_set(mode="OBJECT")

    @staticmethod
    def turn(rig, bone, axis, angle):
        """Turns a pose bone by `angle` about a Godot-space axis given as
        "x", "y" or "z" (applied in the bone's own frame)."""
        pb = rig.pose.bones[bone]
        vector = {"x": Vector((1, 0, 0)), "y": Vector((0, 0, 1)), "z": Vector((0, -1, 0))}[axis]
        local = pb.bone.matrix_local.to_3x3().inverted() @ vector
        pb.rotation_quaternion = Quaternion(local, angle) @ pb.rotation_quaternion

    @staticmethod
    def shift(rig, bone, offset):
        """Moves a pose bone by a Godot-space offset."""
        pb = rig.pose.bones[bone]
        local = pb.bone.matrix_local.to_3x3().inverted() @ ModelKit.g(*offset)
        pb.location = pb.location + local

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
