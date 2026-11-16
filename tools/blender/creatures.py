"""Builds the people and animals in Blender and exports one glTF each.

Every creature is a smooth body grown from a stick skeleton (the Skin
modifier), rigged to a named armature, with rounded rigid parts (heads,
hooves, antlers) riding on their bones and looping animations recorded
from code: walk, idle, and per kind a wave, a gallop or a hop, plus a
flail for when they are sent flying. Materials are named after what they
are, so the game can recolour clothes and coats.

Run: blender -b -P tools/blender/creatures.py -- models/
"""

import math
import os
import sys

sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from mathutils import Vector  # noqa: E402

from model_kit import ModelKit as K  # noqa: E402


class PersonModel:
    """A person standing about in winter clothes (recoloured in the game:
    jacket, pants, hat, scarf, boots; a bather has them all skin-coloured
    but the trunks)."""

    COLORS = {
        "jacket": (0.9, 0.2, 0.2), "jacket_trim": (0.95, 0.55, 0.55), "pants": (0.12, 0.14, 0.25),
        "trunks": (0.12, 0.14, 0.25), "boots": (0.22, 0.14, 0.1), "sole": (0.08, 0.07, 0.07),
        "skin": (0.96, 0.78, 0.66), "cheek": (0.97, 0.62, 0.58), "hair": (0.42, 0.26, 0.14),
        "hat": (0.2, 0.7, 0.35), "hat_cuff": (0.15, 0.55, 0.28), "scarf": (0.98, 0.75, 0.1),
        "white": (1.0, 1.0, 1.0), "ink": (0.06, 0.05, 0.05),
    }

    HIP = (0.1, 0.92, 0.0)
    KNEE = (0.1, 0.5, -0.02)
    ANKLE = (0.1, 0.09, 0.01)
    SHOULDER = (0.21, 1.45, 0.01)
    ELBOW = (0.25, 1.18, 0.03)
    WRIST = (0.27, 0.93, 0.0)
    HEAD = (0.0, 1.73, 0.0)

    @staticmethod
    def side(point, s):
        return (point[0] * s, point[1], point[2])

    @staticmethod
    def build():
        K.clear()
        K.colors = PersonModel.COLORS
        side = PersonModel.side
        bones = [
            ("hips", (0, 0.86, 0), (0, 1.05, 0), None, False),
            ("spine", (0, 1.05, 0), (0, 1.45, 0), "hips", True),
            ("neck", (0, 1.45, 0), (0, 1.58, 0), "spine", True),
            ("head", (0, 1.58, 0), (0, 1.92, 0), "neck", True),
        ]
        for tag, s in (("L", -1), ("R", 1)):
            bones += [
                ("upper_arm." + tag, side(PersonModel.SHOULDER, s), side(PersonModel.ELBOW, s), "spine", False),
                ("forearm." + tag, side(PersonModel.ELBOW, s), side(PersonModel.WRIST, s), "upper_arm." + tag, True),
                ("thigh." + tag, side(PersonModel.HIP, s), side(PersonModel.KNEE, s), "hips", False),
                ("shin." + tag, side(PersonModel.KNEE, s), side(PersonModel.ANKLE, s), "thigh." + tag, True),
            ]
        rig = K.armature("person", bones)

        # Jacket: a quilted column for the torso, a little flared at the hem,
        # with the arms branching off its top.
        joints, radii, edges = [], [], []
        for k in range(9):
            t = k / 8.0
            y = 0.84 + t * 0.64
            width = 0.2 + 0.03 * math.sin(t * math.pi) - (0.05 if t > 0.92 else 0.0) + (0.015 if t < 0.05 else 0.0)
            puff = 0.012 if k % 2 == 1 else -0.003
            joints.append((0, y, 0.0))
            radii.append((width + puff, width * 0.72 + puff))
            if k:
                edges.append((k - 1, k))
        top = len(joints) - 1
        joints.append((0, 1.57, 0.0))
        radii.append((0.085, 0.085))
        edges.append((top, top + 1))
        for s in (-1, 1):
            chain = [side(PersonModel.SHOULDER, s), side(PersonModel.ELBOW, s), side((0.265, 0.97, 0.005), s)]
            chain.insert(1, tuple((Vector(chain[0]) + Vector(chain[1])) * 0.5))
            chain.insert(3, tuple((Vector(chain[2]) + Vector(chain[3])) * 0.5))
            sizes = [0.08, 0.077, 0.068, 0.066, 0.058]
            previous = top - 1
            for i, point in enumerate(chain):
                joints.append(point)
                r = sizes[i] + (0.006 if i % 2 == 1 else 0.0)
                radii.append((r, r))
                edges.append((previous, len(joints) - 1))
                previous = len(joints) - 1
        jacket = K.skin("jacket", joints, edges, radii, "jacket")

        leg_joints, leg_radii, leg_edges = [(0, 0.95, 0)], [(0.17, 0.13)], []
        for s in (-1, 1):
            base = len(leg_joints)
            leg_joints += [side(PersonModel.HIP, s), side(PersonModel.KNEE, s), side((0.1, 0.16, 0.01), s)]
            leg_radii += [(0.095, 0.095), (0.078, 0.078), (0.066, 0.066)]
            leg_edges += [(0, base), (base, base + 1), (base + 1, base + 2)]
        pants = K.skin("pants", leg_joints, leg_edges, leg_radii, "pants")
        trunks = K.ellipsoid("trunks", (0, 0.9, 0.0), (0.185, 0.1, 0.145), "trunks", segments=20, rings=10)

        trim = [K.tube("zip", (0, 0.9, -0.165), (0, 1.48, -0.135), 0.011, "jacket_trim", vertices=8)]
        for s in (-1, 1):
            trim.append(K.ellipsoid("cuff", side((0.266, 0.985, 0.005), s), (0.064, 0.05, 0.064), "jacket_trim", segments=12, rings=6))
        trim.append(K.ellipsoid("hood", (0, 1.52, 0.13), (0.15, 0.09, 0.07), "jacket", rotation=(math.radians(-20), 0, 0), segments=16, rings=8))
        trim = K.join(trim, "jacket_trim")

        scarf = [K.torus("scarf", (0, 1.55, 0.0), 0.11, 0.045, "scarf")]
        scarf.append(K.torus("scarf_band", (0, 1.6, 0.0), 0.1, 0.034, "white"))
        scarf.append(K.tube("tail", (0.07, 1.52, -0.12), (0.1, 1.24, -0.17), 0.04, "scarf", end_radius=0.035, vertices=10))
        scarf = K.join(scarf, "scarf")

        head = K.face(PersonModel.HEAD, 0.15, "hat")
        rigid = [(head, "head")]
        for tag, s in (("L", -1), ("R", 1)):
            wrist = Vector(side(PersonModel.WRIST, s))
            mitt = [K.ellipsoid("mitten", wrist + Vector((0, -0.04, 0)), (0.055, 0.075, 0.06), "hat", segments=14, rings=8)]
            mitt.append(K.ellipsoid("thumb", wrist + Vector((-0.04 * s, -0.02, -0.035)), (0.024, 0.035, 0.024), "hat", segments=10, rings=6))
            rigid.append((K.join(mitt, "mitten." + tag), "forearm." + tag))
            ankle = Vector(side(PersonModel.ANKLE, s))
            boot = [K.ellipsoid("boot", ankle + Vector((0, -0.01, -0.05)), (0.075, 0.07, 0.13), "boots", segments=16, rings=10)]
            boot.append(K.tube("shaft", ankle + Vector((0, -0.02, 0)), ankle + Vector((0, 0.12, 0)), 0.076, "boots", vertices=16))
            boot.append(K.ellipsoid("sole", ankle + Vector((0, -0.075, -0.05)), (0.078, 0.02, 0.135), "sole", segments=16, rings=6))
            rigid.append((K.join(boot, "boot." + tag), "shin." + tag))
        K.weigh(rig, [jacket, pants, trunks, trim, scarf], rigid)

        K.animate(rig, "walk", 24, PersonModel.walk)
        K.animate(rig, "idle", 60, PersonModel.idle)
        K.animate(rig, "wave", 24, PersonModel.wave)
        K.animate(rig, "flail", 16, PersonModel.flail)
        return rig

    @staticmethod
    def walk(rig, t):
        phase = t * math.tau
        for tag, offset in (("L", 0.0), ("R", math.pi)):
            swing = math.sin(phase + offset)
            K.turn(rig, "thigh." + tag, "x", swing * 0.45)
            K.turn(rig, "shin." + tag, "x", -max(math.cos(phase + offset), 0.0) * 0.75 - 0.05)
            K.turn(rig, "upper_arm." + tag, "x", -swing * 0.38)
            K.turn(rig, "upper_arm." + tag, "z", 0.08 * (1 if tag == "R" else -1))
            K.turn(rig, "forearm." + tag, "x", 0.35 + max(-swing, 0.0) * 0.3)
        K.shift(rig, "hips", (0, abs(math.cos(phase)) * 0.035 - 0.02, 0))
        K.turn(rig, "hips", "z", math.sin(phase) * 0.04)
        K.turn(rig, "spine", "y", math.sin(phase) * 0.08)
        K.turn(rig, "head", "y", -math.sin(phase) * 0.06)

    @staticmethod
    def idle(rig, t):
        phase = t * math.tau
        K.turn(rig, "spine", "x", math.sin(phase) * 0.02)
        K.turn(rig, "head", "y", math.sin(phase) * 0.35)
        K.turn(rig, "head", "x", math.sin(phase * 2.0) * 0.04)
        for tag, s in (("L", -1), ("R", 1)):
            K.turn(rig, "upper_arm." + tag, "z", 0.1 * s + math.sin(phase) * 0.02)
            K.turn(rig, "forearm." + tag, "x", 0.25)
        K.turn(rig, "hips", "z", math.sin(phase) * 0.025)

    @staticmethod
    def wave(rig, t):
        phase = t * math.tau
        K.turn(rig, "upper_arm.R", "z", 2.5)
        K.turn(rig, "forearm.R", "z", 0.35 + math.sin(phase) * 0.45)
        K.turn(rig, "upper_arm.L", "z", -0.1)
        K.turn(rig, "forearm.L", "x", 0.25)
        K.turn(rig, "head", "z", math.sin(phase) * 0.05)

    @staticmethod
    def flail(rig, t):
        phase = t * math.tau
        for k, bone in enumerate(["upper_arm.L", "upper_arm.R", "forearm.L", "forearm.R", "thigh.L", "thigh.R", "shin.L", "shin.R"]):
            K.turn(rig, bone, "x", math.sin(phase + k * 1.3) * 1.1)
            K.turn(rig, bone, "z", math.cos(phase * 2 + k) * 0.6)
        K.turn(rig, "spine", "x", math.sin(phase) * 0.3)
        K.turn(rig, "head", "y", math.sin(phase * 2) * 0.4)


class QuadrupedModel:
    """A four-legged animal from a description: body joints from rump to
    nose, where the legs stand, how thick everything is, and extras (ears,
    antlers, tails) as rigid parts. Walks with a trot, or gallops."""

    LEGS = (("fl", -1, "front"), ("fr", 1, "front"), ("bl", -1, "back"), ("br", 1, "back"))

    @staticmethod
    def build(spec):
        K.clear()
        K.colors = spec["colors"]
        width = spec["leg_width"]
        front_z, back_z = spec["front_z"], spec["back_z"]
        hip_y, knee_y = spec["hip_y"], spec["knee_y"]
        body = spec["body"]
        neck_from = body[spec["neck_joint"]]
        head_at = body[-2]
        bones = [
            ("hips", (0, hip_y, back_z), (0, hip_y, (back_z + front_z) * 0.5), None, False),
            ("spine", (0, hip_y, (back_z + front_z) * 0.5), (0, hip_y, front_z), "hips", True),
            ("neck", (0, hip_y, front_z), neck_from[0], "spine", True),
            ("head", neck_from[0], head_at[0], "neck", True),
            ("tail", (0, spec["tail"][0][1], spec["tail"][0][2]), spec["tail"][1], "hips", False),
        ]
        for name, s, end in QuadrupedModel.LEGS:
            z = front_z if end == "front" else back_z
            lean = spec.get("hock", 0.0) if end == "back" else -spec.get("knee", 0.0)
            hip = (width * s, hip_y, z)
            knee = (width * s, knee_y, z + lean)
            hoof = (width * s, spec["hoof_height"], z)
            parent = "spine" if end == "front" else "hips"
            bones += [
                ("leg_%s_upper" % name, hip, knee, parent, False),
                ("leg_%s_lower" % name, knee, hoof, "leg_%s_upper" % name, True),
            ]
        rig = K.armature(spec["name"], bones)

        # The body is one smooth chain from rump to nose. Each leg and the
        # tail are their own smooth parts, starting inside the body so the
        # joins are hidden; a paler sock covers the lower leg where the
        # animal has one.
        joints = [j[0] for j in body]
        radii = [j[1] for j in body]
        edges = [(i, i + 1) for i in range(len(body) - 1)]
        coat = K.skin("coat", joints, edges, radii, "fur")
        legs = []
        for name, s, end in QuadrupedModel.LEGS:
            z = front_z if end == "front" else back_z
            lean = spec.get("hock", 0.0) if end == "back" else -spec.get("knee", 0.0)
            inside = (width * s * 0.7, hip_y + spec["upper_drop"] * 0.5, z)
            thigh = (width * s, hip_y - spec["upper_drop"], z)
            knee = (width * s, knee_y, z + lean)
            hoof = (width * s, spec["hoof_height"] + 0.03, z)
            legs.append(K.skin("leg_" + name, [inside, thigh, knee, hoof], [(0, 1), (1, 2), (2, 3)], [(spec["thigh"] * 1.1, spec["thigh"] * 1.2), (spec["thigh"], spec["thigh"] * 1.15), (spec["knee_r"], spec["knee_r"]), (spec["ankle_r"], spec["ankle_r"])], "fur"))
            if spec.get("lower", "fur") != "fur":
                sock_top = Vector(knee).lerp(Vector(hoof), 0.15)
                legs.append(K.skin("sock_" + name, [tuple(sock_top), hoof], [(0, 1)], [(spec["knee_r"] * 0.98, spec["knee_r"] * 0.98), (spec["ankle_r"] * 1.06, spec["ankle_r"] * 1.06)], spec["lower"], subdivisions=1))
        tail = spec["tail"]
        tail_root = Vector(tail[0]) + (Vector(tail[0]) - Vector(tail[1])).normalized() * tail[2] * 1.5
        legs.append(K.skin("tail", [tuple(tail_root), tail[0], tail[1]], [(0, 1), (1, 2)], [(tail[2] * 0.8, tail[2] * 0.8), (tail[2], tail[2]), (tail[3], tail[3])], spec.get("tail_material", "fur"), subdivisions=1))

        rigid = []
        for name, s, end in QuadrupedModel.LEGS:
            z = front_z if end == "front" else back_z
            hoof = K.ellipsoid("hoof", (width * s, spec["hoof_height"] * 0.5 + 0.01, z - 0.01), (spec["ankle_r"] * 1.15, spec["hoof_height"] * 0.5 + 0.01, spec["ankle_r"] * 1.4), spec.get("hoof", "hoof"), segments=10, rings=6)
            rigid.append((hoof, "leg_%s_lower" % name))
        head_parts = spec["extras"]()
        rigid.append((K.join(head_parts, "head_parts"), "head"))
        K.weigh(rig, [coat] + legs, rigid)

        K.animate(rig, "walk", 24, lambda r, t: QuadrupedModel.trot(r, t, spec))
        K.animate(rig, "idle", 60, QuadrupedModel.idle)
        if spec.get("gallop"):
            K.animate(rig, "gallop", 16, QuadrupedModel.gallop)
        if spec.get("hop"):
            K.animate(rig, "hop", 20, QuadrupedModel.hop)
        K.animate(rig, "flail", 16, QuadrupedModel.flail)
        return rig

    @staticmethod
    def trot(rig, t, spec):
        phase = t * math.tau
        swing = spec.get("swing", 0.4)
        for name, offset in (("fl", 0.0), ("br", 0.0), ("fr", math.pi), ("bl", math.pi)):
            K.turn(rig, "leg_%s_upper" % name, "x", math.sin(phase + offset) * swing)
            fold = -max(math.cos(phase + offset), 0.0) * 0.8
            K.turn(rig, "leg_%s_lower" % name, "x", fold if name[0] == "f" else -fold * 0.6)
        K.shift(rig, "hips", (0, abs(math.sin(phase)) * 0.025, 0))
        K.turn(rig, "neck", "x", math.sin(phase * 2) * 0.04)
        K.turn(rig, "tail", "y", math.sin(phase) * 0.3)

    @staticmethod
    def idle(rig, t):
        phase = t * math.tau
        K.turn(rig, "neck", "x", -0.15 + math.sin(phase) * 0.12)
        K.turn(rig, "head", "y", math.sin(phase * 2) * 0.15)
        K.turn(rig, "tail", "y", math.sin(phase * 3) * 0.35)

    @staticmethod
    def gallop(rig, t):
        phase = t * math.tau
        for name, offset in (("fl", 0.0), ("fr", 0.35), ("bl", math.pi), ("br", math.pi + 0.35)):
            K.turn(rig, "leg_%s_upper" % name, "x", math.sin(phase + offset) * 0.75)
            K.turn(rig, "leg_%s_lower" % name, "x", -max(math.cos(phase + offset), 0.0) * 1.1 if name[0] == "f" else max(math.cos(phase + offset), 0.0) * 0.6)
        K.turn(rig, "spine", "x", math.sin(phase) * 0.1)
        K.turn(rig, "neck", "x", -math.sin(phase) * 0.15)
        K.shift(rig, "hips", (0, math.sin(phase) * 0.06, 0))

    @staticmethod
    def hop(rig, t):
        lift = math.sin(t * math.pi)
        K.shift(rig, "hips", (0, lift * 0.25, -lift * 0.05))
        for name in ("bl", "br"):
            K.turn(rig, "leg_%s_upper" % name, "x", -lift * 0.9)
            K.turn(rig, "leg_%s_lower" % name, "x", lift * 0.7)
        for name in ("fl", "fr"):
            K.turn(rig, "leg_%s_upper" % name, "x", lift * 0.6)
        K.turn(rig, "spine", "x", -lift * 0.15)

    @staticmethod
    def flail(rig, t):
        phase = t * math.tau
        for k, (name, s, end) in enumerate(QuadrupedModel.LEGS):
            K.turn(rig, "leg_%s_upper" % name, "x", math.sin(phase + k * 1.6) * 0.9)
            K.turn(rig, "leg_%s_lower" % name, "x", math.cos(phase * 2 + k) * 0.7)
        K.turn(rig, "neck", "y", math.sin(phase) * 0.5)
        K.turn(rig, "tail", "x", math.sin(phase * 2) * 0.6)


class Animals:
    """Descriptions of the animals for QuadrupedModel."""

    @staticmethod
    def moose():
        colors = {"fur": (0.3, 0.2, 0.13), "dark": (0.2, 0.13, 0.08), "shin": (0.62, 0.55, 0.46), "hoof": (0.12, 0.1, 0.08), "antler": (0.86, 0.79, 0.62), "ink": (0.02, 0.02, 0.02), "nose": (0.18, 0.12, 0.08)}

        def extras():
            K.colors = colors
            parts = [K.ellipsoid("muzzle", (0, 1.98, -2.12), (0.2, 0.2, 0.26), "nose")]
            parts.append(K.ellipsoid("bell", (0, 1.62, -1.55), (0.06, 0.2, 0.08), "dark"))
            for s in (-1, 1):
                parts.append(K.ellipsoid("nostril", (0.07 * s, 1.96, -2.37), (0.035, 0.03, 0.02), "ink", segments=8, rings=4))
                parts.append(K.ellipsoid("eye", (0.19 * s, 2.24, -1.86), (0.035, 0.035, 0.035), "ink", segments=8, rings=6))
                parts.append(K.ellipsoid("ear", (0.24 * s, 2.42, -1.62), (0.07, 0.18, 0.05), "fur", rotation=(0, 0, -0.7 * s), segments=10, rings=6))
                parts.append(K.tube("beam", (0.1 * s, 2.36, -1.7), (0.34 * s, 2.5, -1.66), 0.055, "antler", end_radius=0.05))
                palm_at = Vector((0.62 * s, 2.62, -1.6))
                parts.append(K.ellipsoid("palm", palm_at, (0.42, 0.05, 0.27), "antler", rotation=(0.2, 0, 0.4 * s)))
                for k in range(6):
                    around = -1.3 + k * 0.56
                    base = palm_at + Vector((math.cos(around) * 0.36 * s, 0.13 + 0.04 * math.cos(around), math.sin(around) * 0.22))
                    parts.append(K.tube("tine", base, base + Vector((0.05 * s, 0.24, 0.03)), 0.03, "antler", end_radius=0.012, vertices=6))
            return parts

        return {
            "name": "moose", "colors": colors, "extras": extras, "lower": "shin",
            "front_z": -0.75, "back_z": 0.8, "hip_y": 1.55, "knee_y": 0.78, "hoof_height": 0.08, "leg_width": 0.28,
            "upper_drop": 0.2, "thigh": 0.2, "knee_r": 0.1, "ankle_r": 0.075, "hock": 0.12, "knee": 0.03, "swing": 0.32,
            "body": [
                ((0, 1.72, 1.0), (0.42, 0.45)), ((0, 1.78, 0.6), (0.5, 0.55)), ((0, 1.82, 0.0), (0.55, 0.6)),
                ((0, 1.92, -0.55), (0.52, 0.66)), ((0, 2.08, -1.05), (0.26, 0.3)), ((0, 2.2, -1.62), (0.22, 0.26)),
                ((0, 2.02, -2.05), (0.17, 0.19)),
            ],
            "rump_joint": 1, "chest_joint": 3, "neck_joint": 4,
            "tail": ((0, 1.85, 1.15), (0, 1.7, 1.32), 0.06, 0.03),
        }

    @staticmethod
    def deer():
        colors = {"fur": (0.64, 0.43, 0.26), "hoof": (0.1, 0.08, 0.06), "white": (0.97, 0.96, 0.93), "ink": (0.05, 0.05, 0.05), "antler": (0.45, 0.35, 0.25), "fur_dark": (0.5, 0.33, 0.2)}

        def extras():
            K.colors = colors
            parts = [K.ellipsoid("nose", (0, 1.55, -0.93), (0.045, 0.04, 0.04), "ink", segments=8, rings=6)]
            for s in (-1, 1):
                parts.append(K.ellipsoid("eye", (0.085 * s, 1.65, -0.78), (0.026, 0.026, 0.026), "ink", segments=8, rings=6))
                parts.append(K.ellipsoid("ear", (0.13 * s, 1.75, -0.65), (0.045, 0.12, 0.03), "fur_dark", rotation=(0, 0, -0.6 * s), segments=10, rings=6))
                parts.append(K.tube("antler", (0.05 * s, 1.74, -0.7), (0.08 * s, 2.02, -0.66), 0.022, "antler", end_radius=0.01, vertices=6))
                parts.append(K.tube("tine", (0.065 * s, 1.88, -0.68), (0.1 * s, 1.96, -0.78), 0.015, "antler", end_radius=0.006, vertices=6))
            parts.append(K.ellipsoid("rump", (0, 1.08, 0.5), (0.17, 0.15, 0.08), "white"))
            return parts

        return {
            "name": "deer", "colors": colors, "extras": extras, "lower": "fur",
            "front_z": -0.38, "back_z": 0.38, "hip_y": 0.98, "knee_y": 0.5, "hoof_height": 0.05, "leg_width": 0.13,
            "upper_drop": 0.12, "thigh": 0.1, "knee_r": 0.048, "ankle_r": 0.036, "hock": 0.1, "knee": 0.02, "swing": 0.45,
            "body": [
                ((0, 1.03, 0.48), (0.2, 0.2)), ((0, 1.05, 0.2), (0.24, 0.27)), ((0, 1.06, -0.2), (0.23, 0.27)),
                ((0, 1.12, -0.42), (0.17, 0.22)), ((0, 1.42, -0.58), (0.09, 0.1)), ((0, 1.63, -0.73), (0.11, 0.12)),
                ((0, 1.56, -0.9), (0.06, 0.06)),
            ],
            "rump_joint": 1, "chest_joint": 3, "neck_joint": 4,
            "tail": ((0, 1.08, 0.55), (0, 1.0, 0.62), 0.04, 0.02),
            "gallop": True,
        }

    @staticmethod
    def reindeer():
        spec = Animals.deer()
        colors = {"fur": (0.45, 0.32, 0.22), "hoof": (0.12, 0.1, 0.08), "white": (0.9, 0.86, 0.78), "ink": (0.05, 0.05, 0.05), "antler": (0.8, 0.72, 0.56), "fur_dark": (0.36, 0.25, 0.17), "pale": (0.9, 0.86, 0.78)}

        def extras():
            K.colors = colors
            parts = [K.ellipsoid("nose", (0, 1.55, -0.93), (0.05, 0.045, 0.045), "ink", segments=8, rings=6)]
            parts.append(K.ellipsoid("mane", (0, 1.32, -0.55), (0.11, 0.2, 0.1), "pale", rotation=(0.6, 0, 0)))
            for s in (-1, 1):
                parts.append(K.ellipsoid("eye", (0.09 * s, 1.66, -0.78), (0.026, 0.026, 0.026), "ink", segments=8, rings=6))
                parts.append(K.ellipsoid("ear", (0.13 * s, 1.72, -0.64), (0.035, 0.09, 0.06), "fur_dark", rotation=(0, 0, -0.9 * s), segments=10, rings=6))
                beam = [Vector((0.06 * s, 1.75, -0.68)), Vector((0.18 * s, 2.0, -0.6)), Vector((0.3 * s, 2.25, -0.45)), Vector((0.32 * s, 2.5, -0.55)), Vector((0.24 * s, 2.65, -0.7))]
                for i in range(len(beam) - 1):
                    parts.append(K.tube("beam", beam[i], beam[i + 1], 0.032, "antler", end_radius=0.026, vertices=6))
                for i in (1, 2, 3):
                    parts.append(K.tube("tine", beam[i], beam[i] + Vector((0.04 * s, 0.18, -0.2)), 0.02, "antler", end_radius=0.008, vertices=6))
            parts.append(K.ellipsoid("rump", (0, 1.08, 0.5), (0.18, 0.16, 0.08), "white"))
            return parts

        spec.update({"name": "reindeer", "colors": colors, "extras": extras, "lower": "pale", "thigh": 0.12, "knee_r": 0.058, "ankle_r": 0.045})
        spec["body"] = [((x, y + 0.02, z), (r[0] * 1.12, r[1] * 1.1)) for (x, y, z), r in spec["body"]]
        return spec

    @staticmethod
    def dog():
        colors = {"fur": (0.62, 0.42, 0.22), "dark": (0.42, 0.27, 0.14), "muzzle": (0.8, 0.65, 0.45), "hoof": (0.42, 0.27, 0.14), "ink": (0.05, 0.05, 0.05), "collar": (0.9, 0.1, 0.1), "white": (1, 1, 1)}

        def extras():
            K.colors = colors
            parts = [K.ellipsoid("muzzle", (0, 0.74, -0.62), (0.075, 0.065, 0.12), "muzzle")]
            parts.append(K.ellipsoid("nose", (0, 0.77, -0.73), (0.035, 0.03, 0.03), "ink", segments=8, rings=6))
            parts.append(K.torus("collar", (0, 0.63, -0.36), 0.1, 0.02, "collar", rotation=(-0.7, 0, 0)))
            for s in (-1, 1):
                parts.append(K.ellipsoid("eye", (0.06 * s, 0.83, -0.58), (0.022, 0.022, 0.022), "ink", segments=8, rings=6))
                parts.append(K.ellipsoid("glint", (0.064 * s, 0.84, -0.6), (0.006, 0.006, 0.006), "white", segments=6, rings=4))
                parts.append(K.ellipsoid("ear", (0.12 * s, 0.75, -0.44), (0.04, 0.12, 0.07), "dark", rotation=(0, 0, 0.35 * s), segments=10, rings=6))
            return parts

        return {
            "name": "dog", "colors": colors, "extras": extras, "lower": "fur",
            "front_z": -0.27, "back_z": 0.27, "hip_y": 0.46, "knee_y": 0.24, "hoof_height": 0.03, "leg_width": 0.1,
            "upper_drop": 0.08, "thigh": 0.075, "knee_r": 0.048, "ankle_r": 0.042, "hock": 0.05, "knee": 0.01, "swing": 0.55,
            "body": [
                ((0, 0.5, 0.38), (0.15, 0.15)), ((0, 0.52, 0.15), (0.18, 0.18)), ((0, 0.53, -0.12), (0.18, 0.2)),
                ((0, 0.56, -0.28), (0.16, 0.18)), ((0, 0.68, -0.38), (0.1, 0.1)), ((0, 0.79, -0.48), (0.14, 0.13)),
                ((0, 0.75, -0.6), (0.07, 0.07)),
            ],
            "rump_joint": 1, "chest_joint": 3, "neck_joint": 4,
            "tail": ((0, 0.58, 0.42), (0, 0.78, 0.62), 0.035, 0.02),
        }

    @staticmethod
    def hare():
        colors = {"fur": (0.94, 0.94, 0.96), "shade": (0.84, 0.85, 0.9), "hoof": (0.84, 0.85, 0.9), "ink": (0.08, 0.06, 0.05), "pink": (0.75, 0.5, 0.52), "tip": (0.1, 0.09, 0.09), "white": (1, 1, 1)}

        def extras():
            K.colors = colors
            parts = [K.ellipsoid("snout", (0, 0.37, -0.34), (0.06, 0.05, 0.05), "shade", segments=10, rings=6)]
            parts.append(K.ellipsoid("nose", (0, 0.385, -0.375), (0.016, 0.016, 0.016), "pink", segments=6, rings=4))
            for s in (-1, 1):
                parts.append(K.ellipsoid("eye", (0.065 * s, 0.43, -0.29), (0.022, 0.022, 0.022), "ink", segments=8, rings=4))
                root = Vector((0.04 * s, 0.48, -0.2))
                tip = root + Vector((0.06 * s, 0.24, 0.1))
                parts.append(K.tube("ear", root, tip, 0.036, "fur", end_radius=0.026, vertices=10))
                parts.append(K.ellipsoid("ear_tip", tip, (0.027, 0.035, 0.027), "tip", segments=8, rings=4))
            return parts

        return {
            "name": "hare", "colors": colors, "extras": extras, "lower": "fur", "hoof": "shade",
            "front_z": -0.16, "back_z": 0.14, "hip_y": 0.2, "knee_y": 0.1, "hoof_height": 0.02, "leg_width": 0.08,
            "upper_drop": 0.02, "thigh": 0.07, "knee_r": 0.035, "ankle_r": 0.03, "hock": 0.08, "swing": 0.5,
            "body": [
                ((0, 0.2, 0.2), (0.15, 0.15)), ((0, 0.25, 0.06), (0.17, 0.17)), ((0, 0.27, -0.1), (0.15, 0.16)),
                ((0, 0.3, -0.18), (0.11, 0.12)), ((0, 0.36, -0.22), (0.08, 0.08)), ((0, 0.4, -0.26), (0.1, 0.1)),
                ((0, 0.37, -0.33), (0.05, 0.05)),
            ],
            "rump_joint": 1, "chest_joint": 3, "neck_joint": 4,
            "tail": ((0, 0.26, 0.3), (0, 0.27, 0.34), 0.05, 0.04),
            "hop": True,
        }


class Creatures:
    """Builds and exports every creature into a folder."""

    @staticmethod
    def export_all(folder):
        PersonModel.build()
        K.export(os.path.join(folder, "person.glb"))
        for name in ("moose", "deer", "reindeer", "dog", "hare"):
            QuadrupedModel.build(getattr(Animals, name)())
            K.export(os.path.join(folder, name + ".glb"))
            print("Wrote", name)


if __name__ == "__main__":
    out = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "models"
    only = sys.argv[sys.argv.index("--") + 2] if "--" in sys.argv and len(sys.argv) > sys.argv.index("--") + 2 else ""
    if only == "person":
        PersonModel.build()
        K.export(os.path.join(out, "person.glb"))
    elif only:
        QuadrupedModel.build(getattr(Animals, only)())
        K.export(os.path.join(out, only + ".glb"))
    else:
        Creatures.export_all(out)
    print("Done")
