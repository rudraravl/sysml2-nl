"""Deterministically build the balanced, team-authored OpenUSD core corpus."""

from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).with_name("examples")
MODELS = ROOT / "models"


SCENES = [
    ("O001", "joint_drives", "Create a Z-up SI-unit robot scene with a fixed base and a two-kilogram arm connected by a Y-axis revolute shoulder joint limited to plus or minus ninety degrees and driven toward thirty degrees.",
     _kind := "revolute", {"axis": "Y", "low": -90, "high": 90, "target": 30}),
    ("O002", "joint_drives", "Create a vertical prismatic lift with a five-kilogram carriage, collision geometry, travel from zero to one meter, and a linear drive targeting 0.6 meters.",
     "prismatic", {"axis": "Z", "low": 0, "high": 1, "target": 0.6, "mass": 5}),
    ("O003", "geometry_transforms", "Represent a one-kilogram capsule link positioned 0.8 meters above the ground with explicit translation, orientation, scale, and collision geometry.",
     "body", {"shape": "Capsule", "name": "CapsuleLink", "mass": 1, "height": 0.8}),
    ("O004", "geometry_transforms", "Represent a two-kilogram cylindrical wheel rotated onto the Y axis at a height of 0.4 meters with matching collision geometry.",
     "body", {"shape": "Cylinder", "name": "Wheel", "mass": 2, "height": 0.4}),
    ("O005", "rigid_body_collision", "Create a three-kilogram spherical robot body with a collider above a static ground plane under Earth gravity.",
     "body", {"shape": "Sphere", "name": "BallRobot", "mass": 3, "height": 1.0, "ground": True}),
    ("O006", "rigid_body_collision", "Create a four-kilogram box payload with rigid-body and collision APIs positioned above a collidable static platform.",
     "body", {"shape": "Cube", "name": "Payload", "mass": 4, "height": 1.2, "ground": True}),
    ("O007", "mass_inertia", "Create a six-kilogram payload link with explicit center of mass, diagonal inertia, principal axes, and collision geometry.",
     "body", {"shape": "Cube", "name": "PayloadLink", "mass": 6, "height": 0.7, "inertia": (0.2, 0.3, 0.4)}),
    ("O008", "mass_inertia", "Create a two-kilogram flywheel with explicit center of mass and diagonal inertia and a cylindrical collider.",
     "body", {"shape": "Cylinder", "name": "Flywheel", "mass": 2, "height": 0.5, "inertia": (0.05, 0.05, 0.02)}),
    ("O009", "joint_topology", "Connect a collidable tool rigid body to a static mount using a fixed joint and declare the assembly as an articulation.",
     "fixed", {"mass": 1}),
    ("O010", "joint_topology", "Connect a two-kilogram camera gimbal to a fixed base using a spherical joint with limited swing angles.",
     "spherical", {"mass": 2}),
    ("O011", "articulations", "Create a fixed-base two-link arm articulation with shoulder and elbow revolute joints, explicit masses, collisions, and joint limits.",
     "two_link", {}),
    ("O012", "articulations", "Create a mobile-base articulation with a chassis and two collidable wheels connected by revolute axle joints.",
     "mobile", {}),
    ("O013", "materials_contact", "Create a rigid gripper pad using a high-friction physics material with static friction 1.2 and dynamic friction 1.0.",
     "material", {"name": "GripPad", "static": 1.2, "dynamic": 1.0, "restitution": 0.05}),
    ("O014", "materials_contact", "Create a rigid bumper using a low-friction bouncy physics material with restitution 0.8.",
     "material", {"name": "Bumper", "static": 0.2, "dynamic": 0.15, "restitution": 0.8}),
    ("O015", "environments", "Create a robot test scene containing a dynamic inspection body, collidable ground, and two static box obstacles.",
     "environment", {"variant": "obstacles"}),
    ("O016", "environments", "Create a robot test scene containing a dynamic probe body, collidable ground, and an inclined static ramp.",
     "environment", {"variant": "ramp"}),
    ("O017", "sensor_placement", "Attach a forward-facing camera sensor marker to a collidable mobile robot body 0.4 meters above its origin.",
     "sensor", {"sensor": "camera", "name": "FrontCamera"}),
    ("O018", "sensor_placement", "Attach an IMU sensor marker at the center of a collidable aerial robot body.",
     "sensor", {"sensor": "imu", "name": "BodyIMU"}),
    ("O019", "stage_metadata", "Create a Z-up SI-unit robotics stage sampled at 120 time codes per second with Earth gravity and one collidable calibration body.",
     "body", {"shape": "Cube", "name": "CalibrationBody", "mass": 1, "height": 0.5, "fps": 120}),
    ("O020", "stage_metadata", "Create a Z-up SI-unit lunar robotics stage sampled at 60 time codes per second with gravity magnitude 1.62 and one collidable rover body.",
     "body", {"shape": "Cube", "name": "LunarRover", "mass": 8, "height": 0.4, "gravity": 1.62}),
]


def build() -> None:
    MODELS.mkdir(parents=True, exist_ok=True)
    manifest = []
    for scene_id, category, requirement, kind, options in SCENES:
        code = _render(kind, options)
        (MODELS / f"{scene_id}.usda").write_text(code, encoding="utf-8")
        manifest.append({
            "id": scene_id,
            "split": "rag",
            "category": category,
            "difficulty": "core",
            "requirement": requirement,
            "model": f"models/{scene_id}.usda",
            "tags": _tags(kind, options),
            "provenance": "team-authored deterministic core",
        })
    (ROOT / "manifest.json").write_text(
        json.dumps(manifest, indent=2) + "\n", encoding="utf-8"
    )


def _render(kind: str, options: dict) -> str:
    if kind in {"revolute", "prismatic", "fixed", "spherical"}:
        return _joint_scene(kind, options)
    if kind == "two_link":
        return _two_link_scene()
    if kind == "mobile":
        return _mobile_scene()
    if kind == "material":
        return _material_scene(options)
    if kind == "environment":
        return _environment_scene(options["variant"])
    if kind == "sensor":
        return _sensor_scene(options)
    return _body_scene(options)


def _header(*, fps: int = 60, articulation: bool = False) -> str:
    api = ' (\n    prepend apiSchemas = ["PhysicsArticulationRootAPI"]\n)' if articulation else ""
    return f'''#usda 1.0
(
    defaultPrim = "World"
    kilogramsPerUnit = 1
    metersPerUnit = 1
    timeCodesPerSecond = {fps}
    upAxis = "Z"
)

def Xform "World"{api}
{{
'''


def _physics_scene(gravity: float = 9.81) -> str:
    return f'''    def PhysicsScene "PhysicsScene"
    {{
        vector3f physics:gravityDirection = (0, 0, -1)
        float physics:gravityMagnitude = {gravity}
    }}
'''


def _shape(name: str, shape: str = "Cube", *, scale: str = "(0.3, 0.3, 0.3)",
           collision: bool = True, indent: str = "        ",
           material: str | None = None) -> str:
    api = ' (\n' + indent + '    prepend apiSchemas = ["PhysicsCollisionAPI"]\n' + indent + ')' if collision else ""
    dimension = {
        "Cube": "double size = 1",
        "Sphere": "double radius = 0.5",
        "Capsule": 'uniform token axis = "Z"\n            double height = 1\n            double radius = 0.2',
        "Cylinder": 'uniform token axis = "Y"\n            double height = 0.3\n            double radius = 0.4',
    }[shape]
    binding = (
        f'\n{indent}    rel material:binding:physics = <{material}>'
        if material else ""
    )
    return f'''{indent}def {shape} "{name}"{api}
{indent}{{
{indent}    {dimension}{binding}
{indent}    float3 xformOp:scale = {scale}
{indent}    uniform token[] xformOpOrder = ["xformOp:scale"]
{indent}}}
'''


def _rigid_body(name: str, *, mass: float, shape: str = "Cube",
                height: float = 0.5, inertia: tuple | None = None,
                sensor: tuple[str, str] | None = None,
                material: str | None = None) -> str:
    inertia_text = ""
    if inertia:
        inertia_text = f'''        point3f physics:centerOfMass = (0, 0, 0)
        float3 physics:diagonalInertia = {inertia}
        quatf physics:principalAxes = (1, 0, 0, 0)
'''
    sensor_text = ""
    if sensor:
        sensor_name, sensor_type = sensor
        sensor_text = f'''        def Xform "{sensor_name}"
        {{
            custom token robotics:sensorType = "{sensor_type}"
            double3 xformOp:translate = (0.3, 0, 0.4)
            uniform token[] xformOpOrder = ["xformOp:translate"]
        }}
'''
    return f'''    def Xform "{name}" (
        prepend apiSchemas = ["PhysicsMassAPI", "PhysicsRigidBodyAPI"]
    )
    {{
        float physics:mass = {mass}
{inertia_text}        double3 xformOp:translate = (0, 0, {height})
        uniform token[] xformOpOrder = ["xformOp:translate"]
{_shape("Collision", shape, material=material)}{sensor_text}    }}
'''


def _ground() -> str:
    return '''    def Cube "Ground" (
        prepend apiSchemas = ["PhysicsCollisionAPI"]
    )
    {
        double size = 1
        float3 xformOp:scale = (5, 5, 0.05)
        double3 xformOp:translate = (0, 0, -0.05)
        uniform token[] xformOpOrder = ["xformOp:translate", "xformOp:scale"]
    }
'''


def _body_scene(options: dict) -> str:
    code = _header(fps=options.get("fps", 60))
    code += _physics_scene(options.get("gravity", 9.81))
    code += _rigid_body(
        options["name"], mass=options["mass"], shape=options.get("shape", "Cube"),
        height=options.get("height", 0.5), inertia=options.get("inertia"),
    )
    if options.get("ground"):
        code += _ground()
    return code + "}\n"


def _joint_scene(kind: str, options: dict) -> str:
    mass = options.get("mass", 2)
    code = _header(articulation=True) + _physics_scene()
    code += '''    def Xform "Base"
    {
''' + _shape("Collision", indent="        ") + '''    }
'''
    code += _rigid_body("Link", mass=mass, height=0.7)
    schema = {
        "revolute": "PhysicsRevoluteJoint",
        "prismatic": "PhysicsPrismaticJoint",
        "fixed": "PhysicsFixedJoint",
        "spherical": "PhysicsSphericalJoint",
    }[kind]
    drive = ""
    attrs = ""
    api = ""
    if kind == "revolute":
        api = ' (\n        prepend apiSchemas = ["PhysicsDriveAPI:angular"]\n    )'
        attrs = f'''        token physics:axis = "{options["axis"]}"
        float physics:lowerLimit = {options["low"]}
        float physics:upperLimit = {options["high"]}
'''
        drive = f'''        float drive:angular:physics:damping = 5
        float drive:angular:physics:stiffness = 25
        float drive:angular:physics:targetPosition = {options["target"]}
        uniform token drive:angular:physics:type = "force"
'''
    elif kind == "prismatic":
        api = ' (\n        prepend apiSchemas = ["PhysicsDriveAPI:linear"]\n    )'
        attrs = f'''        token physics:axis = "{options["axis"]}"
        float physics:lowerLimit = {options["low"]}
        float physics:upperLimit = {options["high"]}
'''
        drive = f'''        float drive:linear:physics:damping = 20
        float drive:linear:physics:stiffness = 100
        float drive:linear:physics:targetPosition = {options["target"]}
        uniform token drive:linear:physics:type = "force"
'''
    elif kind == "spherical":
        attrs = '''        token physics:axis = "Z"
        float physics:coneAngle0Limit = 30
        float physics:coneAngle1Limit = 20
'''
    code += f'''    def {schema} "Joint"{api}
    {{
        rel physics:body0 = </World/Base>
        rel physics:body1 = </World/Link>
{attrs}{drive}    }}
}}\n'''
    return code


def _two_link_scene() -> str:
    code = _header(articulation=True) + _physics_scene()
    code += _rigid_body("UpperArm", mass=2, height=0.8)
    code += _rigid_body("Forearm", mass=1.5, height=1.6)
    code += '''    def PhysicsRevoluteJoint "Shoulder"
    {
        rel physics:body1 = </World/UpperArm>
        token physics:axis = "Y"
        float physics:lowerLimit = -120
        float physics:upperLimit = 120
    }
    def PhysicsRevoluteJoint "Elbow"
    {
        rel physics:body0 = </World/UpperArm>
        rel physics:body1 = </World/Forearm>
        token physics:axis = "Y"
        float physics:lowerLimit = 0
        float physics:upperLimit = 150
    }
}\n'''
    return code


def _mobile_scene() -> str:
    code = _header(articulation=True) + _physics_scene()
    code += _rigid_body("Chassis", mass=10, height=0.4)
    code += _rigid_body("LeftWheel", mass=1, shape="Cylinder", height=0.25)
    code += _rigid_body("RightWheel", mass=1, shape="Cylinder", height=0.25)
    for side in ("Left", "Right"):
        code += f'''    def PhysicsRevoluteJoint "{side}Axle"
    {{
        rel physics:body0 = </World/Chassis>
        rel physics:body1 = </World/{side}Wheel>
        token physics:axis = "Y"
    }}
'''
    return code + "}\n"


def _material_scene(options: dict) -> str:
    code = _header() + _physics_scene()
    code += f'''    def Material "ContactMaterial" (
        prepend apiSchemas = ["PhysicsMaterialAPI"]
    )
    {{
        float physics:staticFriction = {options["static"]}
        float physics:dynamicFriction = {options["dynamic"]}
        float physics:restitution = {options["restitution"]}
    }}
'''
    code += _rigid_body(
        options["name"], mass=1, height=0.5,
        material="/World/ContactMaterial",
    )
    return code + "}\n"


def _environment_scene(variant: str) -> str:
    code = _header() + _physics_scene() + _rigid_body("Probe", mass=1, height=0.6)
    code += _ground()
    if variant == "obstacles":
        code += _shape("ObstacleA", scale="(0.4, 0.4, 0.8)", indent="    ")
        code += _shape("ObstacleB", scale="(0.6, 0.3, 0.5)", indent="    ")
    else:
        code += '''    def Cube "Ramp" (
        prepend apiSchemas = ["PhysicsCollisionAPI"]
    )
    {
        double size = 1
        float3 xformOp:rotateXYZ = (0, 20, 0)
        float3 xformOp:scale = (2, 1, 0.1)
        uniform token[] xformOpOrder = ["xformOp:rotateXYZ", "xformOp:scale"]
    }
'''
    return code + "}\n"


def _sensor_scene(options: dict) -> str:
    code = _header() + _physics_scene()
    code += _rigid_body(
        "Robot", mass=5, height=0.5,
        sensor=(options["name"], options["sensor"]),
    )
    return code + "}\n"


def _tags(kind: str, options: dict) -> list[str]:
    tags = [kind, "usdphysics", "si-units"]
    tags.extend(str(value).lower() for value in (
        options.get("shape"), options.get("sensor"), options.get("variant")
    ) if value)
    return tags


if __name__ == "__main__":
    build()
    from .build_retrieval_corpus import build as build_retrieval_corpus

    pairs = build_retrieval_corpus()
    print(f"wrote 100 semantic cases and {len(pairs)} retrieval pairs")
