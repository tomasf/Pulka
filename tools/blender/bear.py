"""Sculpted, plantigrade brown bear, in ModelKit's Godot coordinates.

Run through creatures.py. The coat, feet and tail form one surface; only
eyes, nose, ear cups, pads and claws are rigid details. Fur is baked into
an embedded normal map, so the game needs no procedural Blender shaders.
"""

import math
import random

import bpy
from mathutils import Vector, noise

from model_kit import ModelKit as K


class Bear:
    COLORS = {
        "fur": (0.32, 0.225, 0.145), "ear": (0.16, 0.105, 0.065),
        "lid": (0.24, 0.16, 0.10), "eye": (0.075, 0.045, 0.023),
        "ink": (0.028, 0.024, 0.020), "pad": (0.105, 0.085, 0.07),
        "claw": (0.39, 0.32, 0.23), "nostril": (0.008, 0.007, 0.006),
    }
    LEGS = (("fl", -1, True), ("fr", 1, True),
            ("bl", -1, False), ("br", 1, False))

    @staticmethod
    def smooth(a, b, value):
        t = max(0.0, min(1.0, (value - a) / (b - a)))
        return t * t * (3.0 - 2.0 * t)

    @staticmethod
    def joints(side, front):
        if front:
            return [Vector((0.30 * side, y, z)) for y, z in
                    ((0.99, -0.55), (0.54, -0.45), (0.16, -0.64), (0.08, -0.84))]
        return [Vector((0.30 * side, y, z)) for y, z in
                ((0.94, 0.61), (0.52, 0.41), (0.22, 0.70), (0.08, 0.48))]

    @staticmethod
    def build():
        K.clear()
        bpy.context.scene.render.fps = 24
        K.colors = Bear.COLORS
        bones = [
            ("hips", (0, 0.94, 0.61), (0, 0.97, 0.05), None, False),
            ("spine", (0, 0.97, 0.05), (0, 1.06, -0.55), "hips", True),
            ("neck", (0, 1.06, -0.55), (0, 1.04, -0.94), "spine", True),
            ("head", (0, 1.04, -0.94), (0, 0.96, -1.48), "neck", True),
        ]
        for tag, side, front in Bear.LEGS:
            hip, knee, ankle, toe = Bear.joints(side, front)
            upper, lower, foot = ["leg_%s_%s" % (tag, part) for part in ("upper", "lower", "foot")]
            bones += [(upper, hip, knee, "spine" if front else "hips", False),
                      (lower, knee, ankle, upper, True), (foot, ankle, toe, lower, True)]
        rig = K.armature("bear", bones)
        coat = Bear.sculpt()
        Bear.fur_normals(coat)
        Bear.bind(rig, coat)
        rigid = [(Bear.face(), "head")]
        for tag, side, front in Bear.LEGS:
            rigid.append((Bear.paw_details(side, front), "leg_%s_foot" % tag))
        K.weigh(rig, [], rigid)
        for material, roughness in (("eye", 0.18), ("ink", 0.38), ("nostril", 0.32)):
            K.material(material).node_tree.nodes.get("Principled BSDF").inputs["Roughness"].default_value = roughness
        # Same clip names as the other creatures; the walk has four footfalls
        # instead of the diagonal trot used by the deer.
        K.animate(rig, "walk", 40, Bear.walk)
        K.animate(rig, "idle", 80, Bear.idle)
        K.animate(rig, "flail", 20, Bear.flail)
        return rig

    @staticmethod
    def sculpt():
        parts = []

        def mass(name, center, radii, rotation=(0, 0, 0)):
            parts.append(K.ellipsoid(name, center, radii, "fur", rotation=rotation, segments=24, rings=16))

        # One continuous cross-section surface from rump to nose. Top and
        # underside are independent: the reference has a long hanging belly,
        # a shallow saddle and a wedge-shaped neck, not stacked round masses.
        sections = [
            # z, width, underside, back
            (1.055, .035, .87, .98), (.98, .21, .66, 1.20),
            (.80, .355, .51, 1.33), (.55, .405, .46, 1.36),
            (.25, .425, .445, 1.33), (-.05, .425, .45, 1.30),
            (-.28, .405, .47, 1.35), (-.47, .37, .49, 1.46),
            (-.62, .335, .52, 1.43), (-.80, .295, .62, 1.31),
            (-.98, .255, .72, 1.20), (-1.12, .225, .68, 1.15),
            (-1.24, .185, .68, 1.08), (-1.33, .16, .70, 1.00),
            (-1.40, .145, .725, .945), (-1.465, .121, .755, .910),
            (-1.49, .098, .78, .89),
        ]
        vertices, faces = [], []
        count = 32
        for z, width, bottom, top in sections:
            center = (top + bottom) * .5
            height = (top - bottom) * .5
            for k in range(count):
                angle = k * math.tau / count
                # Broad flanks, slightly flattened underside under the fur.
                x = width * math.copysign(abs(math.cos(angle)) ** .88, math.cos(angle))
                y = center + height * math.sin(angle)
                vertices.append(K.g(x, y, z))
        for ring in range(len(sections) - 1):
            for k in range(count):
                a, b = ring * count + k, ring * count + (k + 1) % count
                faces.append((a, a + count, b + count, b))
        faces.extend((tuple(range(count)), tuple(reversed(range((len(sections)-1)*count, len(sections)*count)))))
        mesh = bpy.data.meshes.new("continuous anatomy")
        mesh.from_pydata(vertices, [], faces)
        torso = K.link(bpy.data.objects.new("continuous anatomy", mesh))
        modifier = torso.modifiers.new("anatomical continuity", "SUBSURF")
        modifier.levels = 2
        K._apply_modifiers(torso)
        parts.append(torso)
        for side in (-1, 1):
            mass("ear", (.17 * side, 1.155, -1.045), (.067, .09, .060), (0, 0, -.18 * side))
        # Tail is mostly buried in the long rump coat.
        mass("tail", (0, .91, 1.015), (.052, .065, .07))

        for tag, side, front in Bear.LEGS:
            hip, knee, ankle, toe = Bear.joints(side, front)
            x = hip.x
            if front:
                mass("upper foreleg", (x, 0.70, -0.49), (0.15, 0.29, 0.185), (-0.10, 0, 0))
                mass("forearm", (x, 0.375, -0.535), (0.12, 0.25, 0.14), (0.30, 0, 0))
                mass("wrist", (x, 0.18, -0.635), (0.115, 0.145, 0.125))
            else:
                mass("thigh", (x, 0.69, 0.52), (0.175, 0.28, 0.215), (0.32, 0, 0))
                mass("hind shin", (x, 0.365, 0.55), (0.108, 0.235, 0.135), (-0.49, 0, 0))
                mass("heel", (x, 0.18, 0.675), (0.105, 0.14, 0.125))
            # Long, flat hind soles and broader forefeet, with five toe
            # knuckles melted into the foot rather than a separate shoe.
            z = -0.735 if front else 0.555
            mass("foot", (x, 0.095, z), (0.135 if front else 0.12, 0.082, 0.19 if front else 0.205))
            for k in range(5):
                across = (k - 2) * 0.047
                tip = z - (0.145 if front else 0.155) + abs(k - 2) * 0.012
                mass("toe", (x + across, 0.073, tip), (0.034, 0.047, 0.068))

        body = K.sculpt(parts, "coat", voxel=0.012, smoothing=14, roughness=0.008, keep=0.12)
        body = Bear.guard_fur(body)
        return K.paint(body, "fur_shaded", Bear.shade)

    @staticmethod
    def guard_fur(body):
        """Short overlapping locks, laid along the coat, soften the outline.

        Roots intersect the sculpt. These are closed low-poly locks, with
        no transparency or hair simulation on mobile and web renderers.
        """
        rng = random.Random(6201)
        vertices, faces, normals, occupied = [], [], [], set()
        candidates = list(body.data.vertices)
        rng.shuffle(candidates)
        for vertex in candidates:
            if len(occupied) >= 400:
                break
            world = body.matrix_world @ vertex.co
            p = Vector((world.x, world.z, -world.y))
            n = Vector((vertex.normal.x, vertex.normal.z, -vertex.normal.y)).normalized()
            if p.y < 0.28 or p.z < -1.24 or n.y > 0.82:
                continue
            cell = tuple(round(value / 0.085) for value in p)
            if cell in occupied:
                continue
            occupied.add(cell)
            if rng.random() > 0.55:
                continue
            flow = Vector((0, -1, 0.3 if p.z > -0.8 else 0.9))
            flow = (flow - n * flow.dot(n)).normalized()
            across = flow.cross(n).normalized()
            length = rng.uniform(0.027, 0.047)
            width = rng.uniform(0.008, 0.015)
            root = p - n * 0.006
            middle = p + flow * length * 0.45 + n * 0.003
            tip = p + flow * length + n * 0.001
            points = [root - across * width, root + across * width,
                      middle + across * width * 0.55, tip,
                      middle - across * width * 0.55, middle + n * 0.002]
            start = len(vertices)
            vertices.extend(K.g(*point) for point in points)
            normals.extend([tuple(K.g(*n))] * len(points))
            faces.extend(tuple(start + i for i in face) for face in
                         ((0, 1, 5), (1, 2, 5), (2, 3, 5), (3, 4, 5), (4, 0, 5),
                          (4, 3, 2, 1, 0)))
        mesh = bpy.data.meshes.new("guard fur")
        mesh.from_pydata(vertices, [], faces)
        # Smooth locks in the direction of the underlying coat rather than
        # averaging their top and underside into sharp dark triangles.
        for polygon in mesh.polygons:
            polygon.use_smooth = True
        mesh.normals_split_custom_set_from_vertices(normals)
        fur = K.link(bpy.data.objects.new("guard fur", mesh))
        body = K.join([body, fur], "coat")
        bpy.ops.object.shade_smooth()
        return body

    @staticmethod
    def shade(p):
        smooth = Bear.smooth
        # Break up the colour with correlated clumps and fine guard hairs;
        # keep the pale muzzle local, away from the throat and forelegs.
        clumps = noise.noise_vector(Vector((p.x * 14, p.y * 9, p.z * 14)))[0]
        hair = noise.noise_vector(Vector((p.x * 115, p.y * 18, p.z * 115)))[1]
        colour = Vector((0.26, 0.195, 0.145))
        legs = (1.0 - smooth(0.25, 0.80, p.y)) * smooth(-1.1, -0.85, p.z)
        colour = colour.lerp(Vector((0.16, 0.105, 0.067)), legs * 0.92)
        shoulder = math.exp(-((p.z + 0.48) / 0.55) ** 2) * smooth(0.85, 1.40, p.y)
        colour = colour.lerp(Vector((0.37, 0.29, 0.215)), shoulder * 0.4)
        muzzle = smooth(1.25, 1.52, -p.z)
        colour = colour.lerp(Vector((0.36, 0.285, 0.215)), muzzle * 0.65)
        # Subtle darker tear line above the cheek, behind each inset eye.
        eye_patch = math.exp(-(((abs(p.x) - 0.18) / 0.055) ** 2 + ((p.y - 1.055) / 0.05) ** 2 + ((p.z + 1.305) / 0.08) ** 2))
        colour *= 1.0 - eye_patch * 0.25
        colour *= 1.0 + clumps * 0.065 + hair * 0.045
        return colour

    @staticmethod
    def fur_normals(coat):
        """Bake short, mostly downward fur grooves to portable glTF normals."""
        bpy.ops.object.select_all(action="DESELECT")
        coat.select_set(True)
        bpy.context.view_layer.objects.active = coat
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.012)
        bpy.ops.object.mode_set(mode="OBJECT")
        mat = coat.data.materials[0]
        nodes, links = mat.node_tree.nodes, mat.node_tree.links
        bsdf = nodes.get("Principled BSDF")
        coords = nodes.new("ShaderNodeTexCoord")
        stretch = nodes.new("ShaderNodeVectorMath")
        stretch.operation = "MULTIPLY"
        stretch.inputs[1].default_value = (1, 1, 0.12)
        links.new(coords.outputs["Object"], stretch.inputs[0])
        grain = nodes.new("ShaderNodeTexNoise")
        grain.inputs["Scale"].default_value = 155
        grain.inputs["Detail"].default_value = 2
        grain.inputs["Roughness"].default_value = 0.7
        links.new(stretch.outputs["Vector"], grain.inputs["Vector"])
        bump = nodes.new("ShaderNodeBump")
        bump.inputs["Strength"].default_value = 0.28
        bump.inputs["Distance"].default_value = 0.007
        links.new(grain.outputs["Fac"], bump.inputs["Height"])
        links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
        image = bpy.data.images.new("Brown bear fur normals", width=1024, height=1024)
        image.colorspace_settings.name = "Non-Color"
        texture = nodes.new("ShaderNodeTexImage")
        texture.image = image
        nodes.active = texture
        bpy.context.scene.render.engine = "CYCLES"
        bpy.context.scene.cycles.samples = 1
        bpy.ops.object.bake(type="NORMAL", normal_space="TANGENT", margin=8)
        image.pack()
        normal = nodes.new("ShaderNodeNormalMap")
        links.new(texture.outputs["Color"], normal.inputs["Color"])
        links.new(normal.outputs["Normal"], bsdf.inputs["Normal"])
        for node in (coords, stretch, grain, bump):
            nodes.remove(node)

    @staticmethod
    def face():
        parts = [K.ellipsoid("nose leather", (0, 0.849, -1.485), (0.098, 0.059, 0.044), "ink", segments=20, rings=12)]
        for side in (-1, 1):
            parts.append(K.ellipsoid("nostril", (0.057 * side, 0.849, -1.522), (0.017, 0.011, 0.008), "nostril", rotation=(0, 0.28 * side, 0), segments=12, rings=8))
            # Small laterally placed eyes, with a dark lid and wet cornea.
            # The eye points obliquely forward, on the skull's actual surface.
            eye = Vector((0.123 * side, 0.981, -1.295))
            parts.append(K.ellipsoid("eyelid", eye, (0.025, 0.020, 0.017), "lid", rotation=(0, -0.5 * side, 0), segments=16, rings=10))
            parts.append(K.ellipsoid("eye", eye + Vector((0.006 * side, 0, -0.006)), (0.017, 0.012, 0.012), "eye", rotation=(0, -0.5 * side, 0), segments=16, rings=10))
            parts.append(K.ellipsoid("pupil", eye + Vector((0.009 * side, 0, -0.015)), (0.008, 0.010, 0.005), "ink", segments=12, rings=8))
            parts.append(K.ellipsoid("ear cup", (0.174 * side, 1.175, -1.097), (0.038, 0.048, 0.012), "ear", rotation=(0, 0, -0.18 * side), segments=16, rings=10))
            parts.append(K.tube("lip crease", (0.128 * side, 0.782, -1.435), (0.145 * side, 0.782, -1.35), 0.003, "lid", end_radius=0.001, vertices=8))
        return K.join(parts, "face details")

    @staticmethod
    def paw_details(side, front):
        x, z = 0.30 * side, -0.735 if front else 0.555
        parts = [K.ellipsoid("sole pad", (x, 0.025, z + 0.012), (0.086, 0.014, 0.115), "pad", segments=16, rings=8)]
        for k in range(5):
            across = (k - 2) * 0.047
            tip = z - (0.145 if front else 0.155) + abs(k - 2) * 0.012
            parts.append(K.ellipsoid("toe pad", (x + across, 0.024, tip), (0.024, 0.012, 0.034), "pad", segments=10, rings=6))
            length = (0.066 if front else 0.040) * (1.0 - 0.09 * abs(k - 2))
            a = (x + across, 0.079, tip - 0.043)
            b = (x + across, 0.068, tip - 0.043 - length * 0.55)
            c = (x + across, 0.039, tip - 0.043 - length)
            parts.append(K.tube("claw root", a, b, 0.011, "claw", end_radius=0.007, vertices=8))
            parts.append(K.tube("claw tip", b, c, 0.007, "claw", end_radius=0.001, vertices=8))
        return K.join(parts, "paw details")

    @staticmethod
    def bind(rig, coat):
        """Anatomical weights keep the face solid and the feet continuous.

        Heat weights on the old merged coat stretched the muzzle away from
        its eyes and pulled the belly along with the swinging legs.
        """
        groups = {bone.name: coat.vertex_groups.new(name=bone.name) for bone in rig.data.bones}
        smooth = Bear.smooth
        for vertex in coat.data.vertices:
            world = coat.matrix_world @ vertex.co
            p = Vector((world.x, world.z, -world.y))
            spine = 1.0 - smooth(-0.40, 0.45, p.z)
            weights = {"hips": 1.0 - spine, "spine": spine}
            neck = 1.0 - smooth(-0.94, -0.68, p.z)
            head = 1.0 - smooth(-1.06, -0.93, p.z)
            weights = {name: value * (1.0 - neck) for name, value in weights.items()}
            weights.update({"neck": neck * (1.0 - head), "head": neck * head})
            if p.z > -0.98:
                side = -1 if p.x < 0 else 1
                front = p.z < 0.02
                tag = ("f" if front else "b") + ("l" if side == -1 else "r")
                z = -0.55 if front else 0.59
                under = 1.0 - smooth(0.52, 0.88, p.y)
                outer = smooth(0.22, 0.37, abs(p.x)) * (1.0 - smooth(0.88, 1.16, p.y))
                influence = max(under, outer) * smooth(0.08, 0.23, abs(p.x))
                influence *= 1.0 - smooth(0.25, 0.46, abs(p.z - z))
                # Every point in the toes must follow the foot, including
                # the inner toes which lie inside the body's side threshold.
                if p.y < 0.20 and abs(p.x) > 0.13:
                    influence = 1.0
                foot = 1.0 - smooth(0.14 if front else 0.16, 0.29, p.y)
                lower = (1.0 - foot) * (1.0 - smooth(0.44, 0.65, p.y))
                upper = 1.0 - foot - lower
                weights = {name: value * (1.0 - influence) for name, value in weights.items()}
                for part, value in (("upper", upper), ("lower", lower), ("foot", foot)):
                    weights["leg_%s_%s" % (tag, part)] = value * influence
            # glTF permits four influences; normalize after discarding tiny
            # ones so Godot and Blender deform the same way.
            strongest = sorted(weights.items(), key=lambda item: item[1], reverse=True)[:4]
            total = sum(value for _, value in strongest)
            for name, value in strongest:
                if value > 0.00001:
                    groups[name].add([vertex.index], value / total, "REPLACE")
        coat.modifiers.new("rig", "ARMATURE").object = rig
        coat.parent = rig

    @staticmethod
    def pose_leg(rig, tag, side, front, offset, lift, bounce, toe_pitch=0.0):
        """Two-bone sagittal IK; keep the entire sole level in stance."""
        hip, knee, ankle, _ = Bear.joints(side, front)
        target = ankle + Vector((0, lift - bounce, offset))
        first, second = (knee - hip).length, (ankle - knee).length
        delta = target - hip
        distance = min(delta.length, first + second - 0.0001)
        direction = delta.normalized()
        along = (first * first - second * second + distance * distance) / (2 * distance)
        height = math.sqrt(max(first * first - along * along, 0.0))
        middle = hip + direction * along
        perpendicular = Vector((0, -direction.z, direction.y))
        candidates = (middle + perpendicular * height, middle - perpendicular * height)
        # Keep the elbow behind the foreleg and the hind knee in front.
        # Choosing whichever solution is nearest the rest knee can flip
        # the pole during swing, making interpolation kick through snow.
        solved = candidates[1 if front else 0]

        def angle(vector):
            return math.atan2(-vector.z, -vector.y)

        upper = angle(solved - hip) - angle(knee - hip)
        lower = angle(target - solved) - angle(ankle - knee) - upper
        K.turn(rig, "leg_%s_upper" % tag, "x", upper)
        K.turn(rig, "leg_%s_lower" % tag, "x", lower)
        K.turn(rig, "leg_%s_foot" % tag, "x", -upper - lower + toe_pitch)

    @staticmethod
    def walk(rig, t):
        # Lower the shoulders a little to allow a full reaching step.
        # 0.6 / 0.62 metres per 40-frame cycle at 24 fps: 0.581 m/s at
        # playback speed 1, matching Props.bear's pace in Godot.
        bounce = -0.055 + math.cos(t * math.tau * 2) * 0.006
        K.shift(rig, "hips", (0, bounce, 0))
        phases = {"bl": 0.0, "fl": 0.25, "br": 0.5, "fr": 0.75}
        for tag, side, front in Bear.LEGS:
            phase = (t + phases[tag]) % 1.0
            stride = 0.30
            stance = 0.62
            if phase < stance:
                offset, lift, pitch = -stride + 2 * stride * phase / stance, 0.0, 0.0
            else:
                swing = (phase - stance) / (1.0 - stance)
                offset = stride * (1.0 - 2.0 * Bear.smooth(0, 1, swing))
                lift = math.sin(swing * math.pi) * 0.13
                pitch = -math.sin(swing * math.pi) * 0.18
            Bear.pose_leg(rig, tag, side, front, offset, lift, bounce, pitch)
        K.turn(rig, "neck", "x", math.sin(t * math.tau * 2) * 0.018)
        K.turn(rig, "head", "y", math.sin(t * math.tau) * 0.025)

    @staticmethod
    def idle(rig, t):
        phase = t * math.tau
        K.turn(rig, "neck", "x", math.sin(phase) * 0.026)
        K.turn(rig, "neck", "y", math.sin(phase) * 0.055)
        K.turn(rig, "head", "y", math.sin(phase) * 0.11)
        K.turn(rig, "head", "x", math.sin(phase * 2) * 0.018)

    @staticmethod
    def flail(rig, t):
        phase = t * math.tau
        for i, (tag, _, front) in enumerate(Bear.LEGS):
            K.turn(rig, "leg_%s_upper" % tag, "x", math.sin(phase + i * 1.6) * 0.75)
            K.turn(rig, "leg_%s_lower" % tag, "x", math.cos(phase * 2 + i) * 0.55)
            K.turn(rig, "leg_%s_foot" % tag, "x", math.sin(phase + i) * 0.25)
        K.turn(rig, "neck", "y", math.sin(phase) * 0.25)
