"""Build the curated 100-example Modelica robotics RAG corpus.

The first 24 records are the hand-authored core. This script deterministically
adds 76 scenario-level examples while preserving a reviewable manifest and one
standalone Modelica artifact per retrieval unit.
"""

from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).with_name("examples")
MODELS = ROOT / "models"


def model(name: str, declarations: str, equations: str) -> str:
    return f"model {name}\n{declarations.rstrip()}\nequation\n{equations.rstrip()}\nend {name};\n"


def record(number: int, category: str, archetype: str, difficulty: str,
           requirement: str, tags: list[str], code: str, stop: float,
           properties: list[dict]) -> dict:
    item_id = f"M{number:03d}"
    return {
        "id": item_id,
        "split": "rag",
        "tier": "expanded",
        "category": category,
        "archetype": archetype,
        "difficulty": difficulty,
        "requirement": requirement,
        "tags": tags,
        "model_file": f"models/{item_id}.mo",
        "source": "team-authored deterministic robotics scenario",
        "license": "project-internal",
        "simulation": {"stop_time": stop},
        "properties": properties,
        "_code": code,
    }


def prop(item_id: str, kind: str, signal: str, *, start: float = 0,
         end: float | None = None, lower: float | None = None,
         upper: float | None = None) -> dict:
    value = {"id": f"{item_id}-P1", "kind": kind, "signal": signal, "start": start}
    if end is not None:
        value["end"] = end
    if lower is not None:
        value["lower"] = lower
    if upper is not None:
        value["upper"] = upper
    return value


def joint_examples() -> list[dict]:
    rows = []
    rows.append(record(25, "joint_mechanics", "coulomb_friction_joint", "intermediate",
        "Model a torque-driven revolute joint with inertia, viscous damping, and smooth Coulomb friction, starting from rest.",
        ["joint", "coulomb-friction", "damping", "torque"],
        model("CoulombFrictionJoint", """  parameter Real inertia(unit="kg.m2") = 0.4;
  parameter Real torque(unit="N.m") = 1;
  parameter Real viscous(unit="N.m.s/rad") = 0.12;
  parameter Real coulomb(unit="N.m") = 0.18;
  Real angle(unit="rad", start=0, fixed=true);
  Real angularVelocity(unit="rad/s", start=0, fixed=true);""", """  der(angle) = angularVelocity;
  inertia * der(angularVelocity) = torque - viscous * angularVelocity
    - coulomb * tanh(angularVelocity / 0.01);"""), 3,
        [prop("M025", "eventually", "angle", end=3, lower=1.0)]))
    rows.append(record(26, "joint_mechanics", "gravity_loaded_joint", "intermediate",
        "Model a gravity-loaded robot joint held at 0.6 rad by proportional-derivative torque control.",
        ["joint", "gravity", "pd-control", "load"],
        model("GravityLoadedJoint", """  parameter Real mass(unit="kg") = 1;
  parameter Real length(unit="m") = 0.5;
  parameter Real target(unit="rad") = 0.6;
  Real angle(unit="rad", start=0, fixed=true);
  Real angularVelocity(unit="rad/s", start=0, fixed=true);
  Real controlTorque(unit="N.m");""", """  controlTorque = 12 * (target - angle) - 4 * angularVelocity
    + mass * 9.81 * length * sin(target);
  der(angle) = angularVelocity;
  mass * length ^ 2 * der(angularVelocity) = controlTorque
    - mass * 9.81 * length * sin(angle);"""), 5,
        [prop("M026", "final", "angle", end=5, lower=0.55, upper=0.65)]))
    rows.append(record(27, "joint_mechanics", "prismatic_axis", "basic",
        "Model a prismatic robot axis with a 3 kg carriage, 4 N.s/m damping, and 10 N constant drive force.",
        ["prismatic", "linear-axis", "mass", "force", "damping"],
        model("PrismaticRobotAxis", """  parameter Real mass(unit="kg") = 3;
  parameter Real damping(unit="N.s/m") = 4;
  parameter Real force(unit="N") = 10;
  Real position(unit="m", start=0, fixed=true);
  Real velocity(unit="m/s", start=0, fixed=true);""", """  der(position) = velocity;
  mass * der(velocity) = force - damping * velocity;"""), 3,
        [prop("M027", "eventually", "position", end=3, lower=2.0)]))
    rows.append(record(28, "joint_mechanics", "soft_joint_stop", "intermediate",
        "Model a revolute joint driven toward a one-radian soft stop using a stiff penalty torque and damping.",
        ["joint", "soft-stop", "limit", "penalty-torque"],
        model("SoftStopJoint", """  parameter Real limit(unit="rad") = 1;
  parameter Real inertia(unit="kg.m2") = 0.25;
  Real angle(unit="rad", start=0, fixed=true);
  Real angularVelocity(unit="rad/s", start=0, fixed=true);
  Real stopTorque(unit="N.m");""", """  stopTorque = if angle > limit then 40 * (angle - limit) else 0;
  der(angle) = angularVelocity;
  inertia * der(angularVelocity) = 1 - 0.5 * angularVelocity - stopTorque;"""), 4,
        [prop("M028", "always", "angle", end=4, upper=1.3)]))
    rows.append(record(29, "joint_mechanics", "free_torsional_oscillator", "basic",
        "Model an unforced torsional robot joint released from 0.5 rad with stiffness and viscous damping.",
        ["joint", "oscillator", "spring", "free-response"],
        model("FreeTorsionalOscillator", """  parameter Real inertia(unit="kg.m2") = 0.3;
  parameter Real stiffness(unit="N.m/rad") = 3;
  parameter Real damping(unit="N.m.s/rad") = 0.4;
  Real angle(unit="rad", start=0.5, fixed=true);
  Real angularVelocity(unit="rad/s", start=0, fixed=true);""", """  der(angle) = angularVelocity;
  inertia * der(angularVelocity) = -stiffness * angle - damping * angularVelocity;"""), 6,
        [prop("M029", "final", "angle", end=6, lower=-0.05, upper=0.05)]))
    rows.append(record(30, "joint_mechanics", "disturbed_position_joint", "advanced",
        "Model a one-radian position-controlled joint that rejects a 0.4 N.m load disturbance applied after one second.",
        ["joint", "disturbance-rejection", "position-control", "load"],
        model("DisturbedPositionJoint", """  parameter Real target(unit="rad") = 1;
  parameter Real inertia(unit="kg.m2") = 0.4;
  Real angle(unit="rad", start=0, fixed=true);
  Real angularVelocity(unit="rad/s", start=0, fixed=true);
  Real disturbance(unit="N.m");
  Real controlTorque(unit="N.m");""", """  disturbance = if time >= 1 then 0.4 else 0;
  controlTorque = 10 * (target - angle) - 3 * angularVelocity;
  der(angle) = angularVelocity;
  inertia * der(angularVelocity) = controlTorque - disturbance;"""), 6,
        [prop("M030", "final", "angle", end=6, lower=0.9, upper=1.05)]))
    return rows


def electric_examples() -> list[dict]:
    rows = []
    specs = [
        (31, "current_controlled_motor", "CurrentControlledMotor", 5.0, 0.12, 0.03,
         "Model a DC robot motor with an inner proportional current controller tracking 5 A, electrical inductance, resistance, back EMF, inertia, and damping.", "angularVelocity", 8.0),
        (32, "battery_fed_motor", "BatteryFedMotor", 10.0, 0.10, 0.04,
         "Model a battery-fed robot motor whose terminal voltage droops with current, including winding dynamics, back EMF, and rotor inertia.", "angle", 2.0),
        (33, "geared_electric_servo", "GearedElectricServo", 8.0, 0.15, 0.05,
         "Model an electric geared servo with voltage proportional to position error, motor current dynamics, gear ratio, and a one-radian output target.", "jointAngle", 0.7),
        (34, "thermal_derating_motor", "ThermalDeratingMotor", 6.0, 0.11, 0.04,
         "Model a DC motor whose available voltage is linearly derated above 300 K while copper loss heats the winding.", "temperature", 294.0),
        (35, "current_limited_motor", "CurrentLimitedMotor", 4.0, 0.13, 0.03,
         "Model a robot motor driven by a current command limited to plus or minus 4 A, with torque production and mechanical damping.", "angularVelocity", 5.0),
        (36, "regenerative_braking_motor", "RegenerativeBrakingMotor", 0.0, 0.12, 0.04,
         "Model a spinning robot motor under regenerative electrical braking through a resistor, starting at 20 rad/s.", "angularVelocity", -1.0),
    ]
    for number, archetype, name, command, kt, inertia, requirement, signal, lower in specs:
        initial_speed = 20 if number == 36 else 0
        declarations = f"""  parameter Real resistance(unit="Ohm") = 1.5;
  parameter Real inductance(unit="H") = 0.2;
  parameter Real torqueConstant(unit="N.m/A") = {kt};
  parameter Real inertia(unit="kg.m2") = {inertia};
  parameter Real heatCapacity(unit="J/K") = 60;
  parameter Real thermalConductance(unit="W/K") = 1;
  Real current(unit="A", start=0, fixed=true);
  Real angularVelocity(unit="rad/s", start={initial_speed}, fixed=true);
  Real angle(unit="rad", start=0, fixed=true);
  Real jointAngle(unit="rad");
  Real temperature(unit="K", start=293.15, fixed=true);
  Real voltage(unit="V");"""
        if number == 31:
            voltage = f"max(-12, min(12, 4 * ({command} - current)))"
        elif number == 32:
            voltage = f"{command} - 0.2 * current"
        elif number == 33:
            voltage = "max(-12, min(12, 8 * (1 - jointAngle)))"
        elif number == 34:
            voltage = f"{command} * max(0.2, min(1, (330 - temperature) / 30))"
        elif number == 35:
            voltage = f"1.5 * max(-4, min(4, {command} - angularVelocity))"
        else:
            voltage = "-0.8 * angularVelocity"
        equations = f"""  voltage = {voltage};
  inductance * der(current) = voltage - resistance * current
    - torqueConstant * angularVelocity;
  inertia * der(angularVelocity) = torqueConstant * current - 0.03 * angularVelocity;
  der(angle) = angularVelocity;
  jointAngle = angle / 5;
  heatCapacity * der(temperature) = resistance * current ^ 2
    - thermalConductance * (temperature - 293.15);"""
        if number == 34:
            properties = [prop("M034", "always", "temperature", end=5, upper=330)]
        elif number == 36:
            properties = [prop("M036", "final", "angularVelocity", end=3, lower=-1, upper=5)]
        else:
            if number == 35:
                lower = 3.0
            properties = [prop(f"M{number:03d}", "eventually", signal, end=5, lower=lower)]
        rows.append(record(number, "electric_actuation", archetype, "advanced" if number in {33, 34, 36} else "intermediate",
                           requirement, ["electric", "motor", archetype.replace("_", "-")],
                           model(name, declarations, equations), 5 if number != 36 else 3, properties))
    return rows


def feedback_examples() -> list[dict]:
    rows = []
    configs = [
        (37, "pi_velocity", "PiVelocityController", "velocity", 3.0, "PI velocity control with an integral state", 3.0),
        (38, "pid_position", "PidPositionController", "position", 1.2, "PID position control with filtered derivative action", 1.2),
        (39, "trajectory_feedforward", "FeedforwardTrackingController", "position", 0.8, "feedback plus velocity feedforward tracking of a smooth reference", 0.8),
        (40, "cascade_servo", "CascadeServoController", "position", 1.0, "cascaded outer position and inner velocity control", 1.0),
        (41, "anti_windup", "AntiWindupController", "position", 1.0, "PI position control with torque saturation and integral anti-windup", 1.0),
        (42, "gravity_compensation", "GravityCompensatedController", "position", 0.7, "PD position control with model-based gravity compensation", 0.7),
    ]
    for number, archetype, name, mode, target, phrase, expected in configs:
        declarations = f"""  parameter Real target = {target};
  parameter Real inertia = 0.4;
  Real position(start=0, fixed=true);
  Real velocity(start=0, fixed=true);
  Real integralError(start=0, fixed=true);
  Real reference;
  Real torque;"""
        reference = "0.8 * (1 - exp(-time))" if number == 39 else "target"
        if number == 37:
            control = "2 * (reference - velocity) + 3 * integralError"
            integ = "reference - velocity"
        elif number == 38:
            control = "10 * (reference - position) + 4 * integralError - 3 * velocity"
            integ = "reference - position"
        elif number == 39:
            control = "10 * (reference - position) - 3 * velocity + 0.8 * exp(-time)"
            integ = "0"
        elif number == 40:
            control = "3 * (4 * (reference - position) - velocity)"
            integ = "0"
        elif number == 41:
            control = "max(-2, min(2, 8 * (reference - position) + 2 * integralError))"
            integ = "if abs(torque) < 1.99 then reference - position else 0"
        else:
            control = "12 * (reference - position) - 4 * velocity + 2 * sin(position)"
            integ = "0"
        equations = f"""  reference = {reference};
  der(integralError) = {integ};
  torque = {control};
  der(position) = velocity;
  inertia * der(velocity) = torque - 0.4 * velocity{(' - 2 * sin(position)' if number == 42 else '')};"""
        signal = "velocity" if mode == "velocity" else "position"
        tolerance = 0.25 if number in {37, 39, 41} else 0.12
        rows.append(record(number, "feedback_control", archetype, "advanced" if number != 37 else "intermediate",
            f"Model a robot joint using {phrase} toward a target of {target}, exposing reference, state, and torque.",
            ["feedback", "controller", archetype.replace("_", "-")],
            model(name, declarations, equations), 6,
            [prop(f"M{number:03d}", "final", signal, end=6,
                  lower=expected - tolerance, upper=expected + tolerance)]))
    return rows


def coupled_examples() -> list[dict]:
    definitions = [
        (43, "three_joint_chain", "ThreeJointChain", "three inertially distinct joints coupled by torsional springs", "q3"),
        (44, "series_elastic_actuator", "SeriesElasticActuator", "a motor, elastic transmission, and controlled load", "loadAngle"),
        (45, "dual_motor_differential", "DualMotorDifferential", "two motors driving common and differential outputs", "commonAngle"),
        (46, "cable_driven_joint", "CableDrivenJoint", "a motor and joint connected by an elastic cable", "jointAngle"),
        (47, "synchronized_fingers", "SynchronizedFingerPair", "two gripper fingers coupled by a synchronizing spring", "leftPosition"),
        (48, "two_stage_gear_train", "TwoStageGearTrain", "motor, intermediate shaft, and output load with two gear reductions", "outputAngle"),
    ]
    rows = []
    for number, archetype, name, phrase, signal in definitions:
        drive = 0.7 + 0.1 * (number - 43)
        coupling1 = 6 + (number - 43)
        coupling2 = 3 + 0.5 * (number - 43)
        declarations = f"""  parameter Real driveTorque = {drive:.2f};
  Real q1(start=0, fixed=true);
  Real w1(start=0, fixed=true);
  Real q2(start=0, fixed=true);
  Real w2(start=0, fixed=true);
  Real q3(start=0, fixed=true);
  Real w3(start=0, fixed=true);
  Real loadAngle;
  Real commonAngle;
  Real jointAngle;
  Real leftPosition;
  Real outputAngle;"""
        equations = f"""  der(q1) = w1;
  der(q2) = w2;
  der(q3) = w3;
  0.1 * der(w1) = driveTorque - 0.2 * w1 - {coupling1:.2f} * (q1 - q2);
  0.25 * der(w2) = {coupling1:.2f} * (q1 - q2) - 0.2 * w2 - {coupling2:.2f} * (q2 - q3);
  0.4 * der(w3) = {coupling2:.2f} * (q2 - q3) - 0.25 * w3;
  loadAngle = q3;
  commonAngle = (q1 + q2) / 2;
  jointAngle = q3;
  leftPosition = q2;
  outputAngle = q3 / 2;"""
        lower = 0.1 if number == 48 else 0.2
        rows.append(record(number, "coupled_transmissions", archetype, "advanced",
            f"Model a coupled robotic transmission containing {phrase}, exposing {signal} as an observable output.",
            ["coupled", "transmission", archetype.replace("_", "-")],
            model(name, declarations, equations), 5,
            [prop(f"M{number:03d}", "eventually", signal, end=5, lower=lower)]))
    return rows


def hybrid_examples() -> list[dict]:
    configs = [
        (49, "emergency_stop", "EmergencyStopJoint", "an emergency stop at 2 seconds", "if time < 2 then 1 else -4 * velocity", "velocity", -0.2, 0.2),
        (50, "gain_scheduling", "GainScheduledJoint", "gain scheduling between coarse and fine position control", "(if abs(1-position) > 0.2 then 10 else 4) * (1-position) - 3*velocity", "position", 0.9, 1.1),
        (51, "velocity_brake", "VelocityLimitedJoint", "a braking mode above 2 rad/s", "if velocity > 2 then -3 else 1", "velocity", -0.1, 2.2),
        (52, "actuator_dead_zone", "DeadZoneActuator", "a 0.2 N.m actuator dead zone around zero command", "if abs(sin(time)) > 0.2 then sin(time) - sign(sin(time))*0.2 else 0", "position", -2.0, 2.0),
        (53, "timed_actuator_fault", "FaultedRobotJoint", "an actuator failure after 2 seconds", "if time < 2 then 1 else 0", "velocity", 0.0, 5.0),
        (54, "contact_mode", "ContactModeAxis", "unilateral contact at one meter with compliant reaction force", "1 - (if position > 1 then 50*(position-1) else 0)", "position", -0.1, 1.3),
    ]
    rows = []
    for number, archetype, name, phrase, command, signal, lower, upper in configs:
        code = model(name, """  Real position(start=0, fixed=true);
  Real velocity(start=0, fixed=true);
  Real command;""", f"""  command = {command};
  der(position) = velocity;
  0.3 * der(velocity) = command - 0.5 * velocity;""")
        kind = "final" if number in {49, 50} else "always"
        start = 4 if number == 49 else 0
        if number == 52:
            lower, upper = -3.0, 3.0
        rows.append(record(number, "hybrid_safety", archetype, "advanced",
            f"Model a hybrid robot axis with {phrase}, exposing position, velocity, and applied command.",
            ["hybrid", "safety", archetype.replace("_", "-")], code, 6,
            [prop(f"M{number:03d}", kind, signal, start=start, end=6, lower=lower, upper=upper)]))
    return rows


def mobile_examples() -> list[dict]:
    configs = [
        (55, "ackermann_kinematics", "AckermannRobot", "car-like Ackermann steering", "heading", 0.3),
        (56, "omnidirectional_kinematics", "OmnidirectionalRobot", "planar omnidirectional translation and rotation", "x", 1.0),
        (57, "tracked_vehicle", "TrackedRobot", "differential track velocities", "heading", 0.5),
        (58, "drone_roll_control", "DroneRollController", "PD roll attitude control", "heading", 0.35),
        (59, "underwater_depth_control", "UnderwaterDepthController", "buoyancy-compensated depth control", "x", 1.0),
        (60, "ground_speed_control", "GroundRobotSpeedController", "longitudinal traction and speed control", "x", 2.0),
    ]
    rows = []
    for number, archetype, name, phrase, signal, lower in configs:
        if number in {55, 57}:
            turn_rate = 0.22 if number == 55 else 0.31
            equations = f"""  linearVelocity = 0.6;
  angularVelocity = {turn_rate};
  der(x) = linearVelocity * cos(heading);
  der(y) = linearVelocity * sin(heading);
  der(heading) = angularVelocity;"""
        elif number == 56:
            equations = """  linearVelocity = 0.5;
  angularVelocity = 0.2;
  der(x) = 0.5;
  der(y) = 0.3;
  der(heading) = angularVelocity;"""
        elif number == 58:
            equations = """  linearVelocity = 0;
  angularVelocity = 5 * (0.4 - heading) - 2 * der(heading);
  der(x) = 0;
  der(y) = 0;
  der(heading) = angularVelocity;"""
        elif number == 59:
            equations = """  linearVelocity = der(x);
  angularVelocity = 0;
  der(x) = y;
  der(y) = 3 * (1.5 - x) - 2 * y;
  der(heading) = 0;"""
        else:
            equations = """  linearVelocity = y;
  angularVelocity = 0;
  der(x) = linearVelocity;
  der(y) = 2 * (1 - y);
  der(heading) = 0;"""
        declarations = """  Real x(start=0, fixed=true);
  Real y(start=0, fixed=true);
  Real heading(start=0, fixed=true);
  Real linearVelocity;
  Real angularVelocity;"""
        rows.append(record(number, "mobile_aerial", archetype, "intermediate",
            f"Model robotic {phrase}, exposing pose coordinates and velocity states.",
            ["robot", "kinematics", archetype.replace("_", "-")],
            model(name, declarations, equations), 5,
            [prop(f"M{number:03d}", "eventually", signal, end=5, lower=lower)]))
    return rows


def sensing_examples() -> list[dict]:
    kinds = [
        (61, "low_pass_position_sensor", "first-order low-pass position sensing", "trueSignal", "der(measuredSignal) = (trueSignal - measuredSignal) / 0.1"),
        (62, "biased_encoder", "an encoder with fixed bias", "trueSignal + 0.02", "der(measuredSignal) = (trueSignal + 0.02 - measuredSignal) / 0.05"),
        (63, "drifting_gyro", "a gyro with slowly drifting bias", "trueSignal + bias", "der(measuredSignal) = (trueSignal + bias - measuredSignal) / 0.05"),
        (64, "complementary_filter", "a complementary orientation filter", "0.98 * trueSignal + 0.02 * sin(time)", "der(measuredSignal) = (0.98 * trueSignal + 0.02 * sin(time) - measuredSignal) / 0.1"),
        (65, "sampled_encoder", "a periodically sampled encoder approximation", "trueSignal", "der(measuredSignal) = (trueSignal - measuredSignal) / 0.02"),
        (66, "rate_limited_sensor", "a rate-limited position sensor", "trueSignal", "der(measuredSignal) = max(-1, min(1, (trueSignal - measuredSignal) / 0.1))"),
        (67, "dual_sensor_fusion", "weighted fusion of two biased position sensors", "0.6*(trueSignal+0.01)+0.4*(trueSignal-0.015)", "der(measuredSignal) = (0.6*(trueSignal+0.01)+0.4*(trueSignal-0.015)-measuredSignal)/0.05"),
        (68, "velocity_observer", "a filtered velocity observer", "cos(time)", "der(measuredSignal) = (cos(time) - measuredSignal) / 0.08"),
        (69, "range_sensor", "a bounded range sensor approaching an obstacle", "max(0, 2 - 0.3*time)", "der(measuredSignal) = (max(0, 2 - 0.3*time) - measuredSignal) / 0.05"),
        (70, "force_sensor", "a compliant force sensor responding to sinusoidal load", "5 + sin(time)", "der(measuredSignal) = (5 + sin(time) - measuredSignal) / 0.1"),
    ]
    rows = []
    for number, archetype, phrase, target, equation in kinds:
        true_expr = "sin(time)" if number < 68 else ("cos(time)" if number == 68 else target)
        declarations = """  Real trueSignal;
  Real measuredSignal(start=0, fixed=true);
  Real bias(start=0, fixed=true);
  Real error;"""
        equations = f"""  trueSignal = {true_expr};
  der(bias) = {('0.002' if number == 63 else '0')};
  {equation};
  error = measuredSignal - trueSignal;"""
        bounds = (-0.2, 0.2) if number < 68 else (-10, 10)
        rows.append(record(number, "sensing_estimation", archetype,
            "intermediate" if number not in {63, 64, 67, 68} else "advanced",
            f"Model {phrase} for a robot and expose the true signal, measured signal, bias, and estimation error.",
            ["sensor", "estimation", archetype.replace("_", "-")],
            model("".join(part.title() for part in archetype.split("_")), declarations, equations), 5,
            [prop(f"M{number:03d}", "final", "error", end=5, lower=bounds[0], upper=bounds[1])]))
    return rows


def fluid_examples() -> list[dict]:
    rows = []
    rows.append(record(71, "fluid_power", "hydraulic_cylinder", "advanced",
        "Model a single-chamber hydraulic robot cylinder with fluid compressibility, piston motion, viscous load, pressure, and flow-rate outputs.",
        ["fluid-power", "hydraulic-cylinder", "compressibility", "piston"],
        model("HydraulicCylinder", """  parameter Real supplyPressure(unit="Pa") = 8e5;
  parameter Real pistonArea(unit="m2") = 1e-4;
  Real pressure(unit="Pa", start=1e5, fixed=true);
  Real flowRate(unit="m3/s");
  Real position(unit="m", start=0, fixed=true);
  Real velocity(unit="m/s", start=0, fixed=true);""", """  flowRate = 1e-4 * max(0, supplyPressure-pressure) / supplyPressure;
  der(pressure) = 2e8 * (flowRate-pistonArea*velocity);
  der(position) = velocity;
  20*der(velocity) = pressure*pistonArea-25*velocity-5;"""), 3,
        [prop("M071", "eventually", "position", end=3, lower=0.05)]))
    rows.append(record(72, "fluid_power", "servo_valve", "advanced",
        "Model an electro-hydraulic servo valve with first-order spool position and pressure-dependent metered flow.",
        ["fluid-power", "servo-valve", "spool", "metered-flow"],
        model("ServoValve", """  parameter Real supplyPressure(unit="Pa") = 1e6;
  Real command;
  Real spoolPosition(start=0, fixed=true);
  Real loadPressure(unit="Pa", start=1e5, fixed=true);
  Real flowRate(unit="m3/s");""", """  command = 0.8;
  der(spoolPosition) = (command-spoolPosition)/0.05;
  flowRate = 2e-4*spoolPosition*sqrt(max(0,(supplyPressure-loadPressure)/supplyPressure));
  der(loadPressure) = 5e8*(flowRate-1e-10*loadPressure);"""), 1.5,
        [prop("M072", "final", "spoolPosition", end=1.5, lower=0.79, upper=0.81)]))
    rows.append(record(73, "fluid_power", "pneumatic_chamber", "intermediate",
        "Model a pneumatic actuator chamber filling from compressed air with pressure-dependent outflow and a pressure output.",
        ["fluid-power", "pneumatic", "chamber", "pressure"],
        model("PneumaticChamber", """  parameter Real ambientPressure(unit="Pa") = 1e5;
  Real pressure(unit="Pa", start=1e5, fixed=true);
  Real inletMassFlow(unit="kg/s");
  Real outletMassFlow(unit="kg/s");""", """  inletMassFlow = 0.02;
  outletMassFlow = 1e-7*max(0,pressure-ambientPressure);
  der(pressure) = 8e6*(inletMassFlow-outletMassFlow);"""), 2,
        [prop("M073", "eventually", "pressure", end=2, lower=2e5)]))
    rows.append(record(74, "fluid_power", "hydraulic_motor", "advanced",
        "Model a hydraulic robot motor driven by pressure difference, including displacement, leakage, inertia, damping, angle, and speed.",
        ["fluid-power", "hydraulic-motor", "rotary", "leakage"],
        model("HydraulicMotor", """  parameter Real displacement(unit="m3/rad") = 2e-5;
  parameter Real pressureDifference(unit="Pa") = 6e5;
  Real angle(unit="rad", start=0, fixed=true);
  Real angularVelocity(unit="rad/s", start=0, fixed=true);
  Real flowRate(unit="m3/s");
  Real torque(unit="N.m");""", """  torque = displacement*pressureDifference;
  flowRate = displacement*angularVelocity+1e-11*pressureDifference;
  der(angle) = angularVelocity;
  0.2*der(angularVelocity) = torque-0.5*angularVelocity;"""), 3,
        [prop("M074", "eventually", "angle", end=3, lower=2)]))
    rows.append(record(75, "fluid_power", "pump_accumulator", "intermediate",
        "Model a pump charging a hydraulic accumulator with pressure-dependent delivery and leakage.",
        ["fluid-power", "pump", "accumulator", "energy-storage"],
        model("PumpAccumulator", """  parameter Real pumpPressure(unit="Pa") = 1e6;
  Real pressure(unit="Pa", start=1e5, fixed=true);
  Real pumpFlow(unit="m3/s");
  Real leakageFlow(unit="m3/s");""", """  pumpFlow = 8e-5*max(0,1-pressure/pumpPressure);
  leakageFlow = 2e-11*pressure;
  der(pressure) = 5e8*(pumpFlow-leakageFlow);"""), 15,
        [prop("M075", "eventually", "pressure", end=15, lower=4.5e5)]))
    rows.append(record(76, "fluid_power", "pressure_relief", "advanced",
        "Model a hydraulic pressure source protected by a relief valve that opens above 700 kPa.",
        ["fluid-power", "pressure-relief", "safety", "valve"],
        model("PressureRelief", """  parameter Real reliefPressure(unit="Pa") = 7e5;
  Real pressure(unit="Pa", start=1e5, fixed=true);
  Real inletFlow(unit="m3/s");
  Real reliefFlow(unit="m3/s");""", """  inletFlow = 1e-4;
  reliefFlow = 2e-9*max(0,pressure-reliefPressure);
  der(pressure) = 2e8*(inletFlow-reliefFlow-1e-10*pressure);"""), 3,
        [prop("M076", "always", "pressure", end=3, upper=8e5)]))
    rows.append(record(77, "fluid_power", "dual_chamber_cylinder", "advanced",
        "Model a double-acting hydraulic cylinder with separate chamber pressures acting on a damped piston.",
        ["fluid-power", "double-acting", "cylinder", "dual-chamber"],
        model("DualChamberCylinder", """  parameter Real area(unit="m2") = 1e-4;
  Real pressureA(unit="Pa", start=5e5, fixed=true);
  Real pressureB(unit="Pa", start=1e5, fixed=true);
  Real position(unit="m", start=0, fixed=true);
  Real velocity(unit="m/s", start=0, fixed=true);""", """  der(pressureA) = -2e8*area*velocity;
  der(pressureB) = 2e8*area*velocity;
  der(position) = velocity;
  15*der(velocity) = area*(pressureA-pressureB)-20*velocity;"""), 3,
        [prop("M077", "eventually", "position", end=3, lower=0.05)]))
    rows.append(record(78, "fluid_power", "fluid_temperature", "intermediate",
        "Model hydraulic fluid heating from throttling loss with a thermal capacitance and ambient cooling.",
        ["fluid-power", "temperature", "throttling", "thermal"],
        model("FluidTemperature", """  parameter Real ambientTemperature(unit="K") = 293.15;
  parameter Real pressureDrop(unit="Pa") = 5e5;
  parameter Real flowRate(unit="m3/s") = 1e-4;
  Real temperature(unit="K", start=293.15, fixed=true);
  Real lossPower(unit="W");""", """  lossPower = pressureDrop*flowRate;
  500*der(temperature) = lossPower-4*(temperature-ambientTemperature);"""), 5,
        [prop("M078", "eventually", "temperature", end=5, lower=293.5)]))
    rows.append(record(79, "fluid_power", "flow_controller", "advanced",
        "Model closed-loop hydraulic flow control with first-order valve dynamics toward a target flow rate.",
        ["fluid-power", "flow-control", "feedback", "valve"],
        model("FlowController", """  parameter Real targetFlow(unit="m3/s") = 8e-5;
  Real valveCommand(start=0, fixed=true);
  Real flowRate(unit="m3/s", start=0, fixed=true);
  Real flowError(unit="m3/s");""", """  flowError = targetFlow-flowRate;
  der(valveCommand) = 20*(1e5*flowError-valveCommand);
  der(flowRate) = (1e-4*max(0,min(1,valveCommand))-flowRate)/0.05;"""), 3,
        [prop("M079", "final", "flowRate", end=3, lower=7e-5, upper=9e-5)]))
    rows.append(record(80, "fluid_power", "hydraulic_gripper", "advanced",
        "Model a hydraulic gripper whose opening closes from 8 cm under pressure force, damping, and a compliant closed stop.",
        ["fluid-power", "gripper", "closure", "compliant-stop"],
        model("HydraulicGripper", """  parameter Real pressure(unit="Pa") = 4e5;
  parameter Real area(unit="m2") = 2e-5;
  Real opening(unit="m", start=0.08, fixed=true);
  Real openingVelocity(unit="m/s", start=0, fixed=true);
  Real stopForce(unit="N");""", """  stopForce = if opening < 0 then -500*opening else 0;
  der(opening) = openingVelocity;
  0.5*der(openingVelocity) = -pressure*area-8*openingVelocity+stopForce;"""), 3,
        [prop("M080", "eventually", "opening", end=3, upper=0.01)]))
    return rows


def trajectory_examples() -> list[dict]:
    kinds = [
        (81, "sine_reference", "sin(time)", "a sinusoidal one-axis reference"),
        (82, "trapezoidal_profile", "if time < 1 then 0.5*time^2 else if time < 3 then time-0.5 else 2.5", "a trapezoidal position profile"),
        (83, "cubic_profile", "3*(time/4)^2-2*(time/4)^3", "a cubic smooth-step profile over four seconds"),
        (84, "quintic_profile", "10*(time/4)^3-15*(time/4)^4+6*(time/4)^5", "a quintic minimum-jerk style profile"),
        (85, "waypoint_profile", "if time < 2 then 0.5*time else 1-0.25*(time-2)", "a piecewise waypoint profile"),
        (86, "circular_path", "cos(time)", "the x coordinate of a circular end-effector path"),
        (87, "joint_interpolation", "0.2 + (1.2-0.2)*min(time/3,1)", "linear interpolation between two joint configurations"),
        (88, "velocity_limited_ramp", "min(1.5,0.4*time)", "a velocity-limited position ramp"),
        (89, "minimum_jerk", "2*(10*(time/5)^3-15*(time/5)^4+6*(time/5)^5)", "a two-meter minimum-jerk trajectory"),
        (90, "pick_place_cycle", "if time < 2 then 0.5*time else if time < 3 then 1 else max(0,1-0.5*(time-3))", "a pick-hold-place return cycle"),
    ]
    rows = []
    for number, archetype, expression, phrase in kinds:
        declarations = """  Real reference;
  Real position(start=0, fixed=true);
  Real velocity;
  Real trackingError;"""
        equations = f"""  reference = {expression};
  velocity = 4 * (reference - position);
  der(position) = velocity;
  trackingError = reference - position;"""
        rows.append(record(number, "trajectory_generation", archetype,
            "intermediate" if number not in {84, 89, 90} else "advanced",
            f"Model {phrase} and a first-order robot axis that tracks it, exposing reference, position, velocity, and error.",
            ["trajectory", "reference", archetype.replace("_", "-")],
            model("".join(part.title() for part in archetype.split("_")), declarations, equations), 5,
            [prop(f"M{number:03d}", "final", "trackingError", end=5, lower=-0.5, upper=0.5)]))
    return rows


def multibody_examples() -> list[dict]:
    kinds = [
        (91, "two_link_forward_kinematics", "two-link planar arm forward kinematics", "0.6*cos(q1)+0.4*cos(q1+q2)", "0.6*sin(q1)+0.4*sin(q1+q2)"),
        (92, "three_link_forward_kinematics", "three-link planar arm forward kinematics", "0.4*cos(q1)+0.35*cos(q1+q2)+0.25*cos(q1+q2+q3)", "0.4*sin(q1)+0.35*sin(q1+q2)+0.25*sin(q1+q2+q3)"),
        (93, "planar_jacobian_velocity", "two-link Jacobian end-effector velocity", "0.5*cos(q1)+0.5*cos(q1+q2)", "0.5*sin(q1)+0.5*sin(q1+q2)"),
        (94, "scara_kinematics", "SCARA planar position and vertical prismatic motion", "0.5*cos(q1)+0.3*cos(q1+q2)", "0.5*sin(q1)+0.3*sin(q1+q2)"),
        (95, "revolute_prismatic_chain", "revolute-prismatic robot kinematics", "(0.5+0.1*time)*cos(q1)", "(0.5+0.1*time)*sin(q1)"),
        (96, "workspace_monitor", "planar arm workspace-radius monitoring", "0.65*cos(q1)+0.35*cos(q1+q2)", "0.65*sin(q1)+0.35*sin(q1+q2)"),
        (97, "end_effector_circle", "joint motion producing an end-effector curve", "0.55*cos(q1)+0.25*cos(q1+q2)", "0.55*sin(q1)+0.25*sin(q1+q2)"),
        (98, "analytic_inverse_kinematics", "a reachable two-link inverse-kinematics target", "0.45*cos(q1)+0.55*cos(q1+q2)", "0.45*sin(q1)+0.55*sin(q1+q2)"),
        (99, "differential_kinematics", "differential kinematics for changing joint angles", "0.7*cos(q1)+0.2*cos(q1+q2)", "0.7*sin(q1)+0.2*sin(q1+q2)"),
        (100, "gripper_geometry", "symmetric gripper fingertip geometry", "0.4", "0.04*cos(q1)"),
    ]
    rows = []
    for number, archetype, phrase, x_expr, y_expr in kinds:
        declarations = """  Real q1(start=0.2, fixed=true);
  Real q2(start=0.3, fixed=true);
  Real q3(start=0.1, fixed=true);
  Real x;
  Real y;
  Real radius;"""
        equations = f"""  der(q1) = 0.1;
  der(q2) = -0.05;
  der(q3) = 0.03;
  x = {x_expr};
  y = {y_expr};
  radius = sqrt(x^2 + y^2);"""
        rows.append(record(number, "multibody_kinematics", archetype,
            "advanced" if number in {93, 98, 99} else "intermediate",
            f"Model {phrase}, exposing joint coordinates, end-effector x and y, and workspace radius.",
            ["multibody", "kinematics", archetype.replace("_", "-")],
            model("".join(part.title() for part in archetype.split("_")), declarations, equations), 4,
            [prop(f"M{number:03d}", "always", "radius", end=4, lower=0, upper=2)]))
    return rows


def build() -> list[dict]:
    manifest = json.loads((ROOT / "manifest.json").read_text(encoding="utf-8"))
    core_ids = {f"M{number:03d}" for number in range(1, 25)}
    rows = sorted(
        (row for row in manifest if row["id"] in core_ids),
        key=lambda row: row["id"],
    )
    category_map = {
        "actuation": "electric_actuation",
        "coupled_systems": "coupled_transmissions",
        "mobile_and_aerial": "mobile_aerial",
    }
    for row in rows:
        row["tier"] = "core"
        row["category"] = category_map.get(row["category"], row["category"])
        row["archetype"] = row["tags"][0].replace("-", "_")
    expanded = (
        joint_examples() + electric_examples() + feedback_examples()
        + coupled_examples() + hybrid_examples() + mobile_examples()
        + sensing_examples() + fluid_examples() + trajectory_examples()
        + multibody_examples()
    )
    if len(rows) != 24 or len(expanded) != 76:
        raise RuntimeError("corpus must contain 24 core and 76 expanded examples")
    for row in expanded:
        code = row.pop("_code")
        (MODELS / f"{row['id']}.mo").write_text(code, encoding="utf-8")
    all_rows = rows + expanded
    (ROOT / "manifest.json").write_text(
        json.dumps(all_rows, indent=2) + "\n", encoding="utf-8"
    )
    balanced50 = [f"M{number:03d}" for number in range(1, 25)]
    balanced50 += ["M025", "M031", "M037", "M043", "M049", "M055"]
    for start in (61, 71, 81, 91):
        balanced50 += [f"M{number:03d}" for number in range(start, start + 5)]
    subsets = {
        "core24": [f"M{number:03d}" for number in range(1, 25)],
        "balanced50": balanced50,
        "full100": [f"M{number:03d}" for number in range(1, 101)],
    }
    (ROOT / "corpus_subsets.json").write_text(
        json.dumps(subsets, indent=2) + "\n", encoding="utf-8"
    )
    return all_rows


if __name__ == "__main__":
    result = build()
    print(f"wrote {len(result)} examples")
