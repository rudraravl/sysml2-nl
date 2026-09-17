"""Build and audit the balanced natural-language robotics input corpus.

The corpus is a design-space catalog, not a held-out benchmark.  It contains
260 semantic scenarios (five embodiments by four missions in each of thirteen
families) and six controlled operating configurations per scenario.  Lineage
metadata prevents those configurations from being counted as independent
experimental tasks.
"""

from __future__ import annotations

from collections import Counter
import argparse
import hashlib
import json
from pathlib import Path
import re

from nl2robotics.studies.capability_matrix import REQUIRED_FAMILIES
from nl2robotics.studies.paper_evaluation import (
    FAMILY_PROFILE,
    MANIFEST as EVALUATION_MANIFEST,
)


ROOT = Path(__file__).resolve().parents[1]
MANIFEST = Path(__file__).with_name("pipeline_prompt_manifest.json")
DEVELOPMENT_MANIFEST = ROOT / "studies" / "capability_manifest.json"
MODELICA_MANIFEST = ROOT / "modelica" / "examples" / "manifest.json"
OPENUSD_MANIFEST = ROOT / "openusd" / "examples" / "manifest.json"

VARIANTS = (
    {"suffix": "A", "rate": 80, "duration": 8, "effort": 0.72,
     "disturbance": 0.50, "tolerance": 1.35, "difficulty": "foundational",
     "style": "plant_first"},
    {"suffix": "B", "rate": 100, "duration": 10, "effort": 0.82,
     "disturbance": 0.70, "tolerance": 1.20, "difficulty": "foundational",
     "style": "scenario_first"},
    {"suffix": "C", "rate": 125, "duration": 12, "effort": 0.92,
     "disturbance": 0.90, "tolerance": 1.05, "difficulty": "intermediate",
     "style": "control_first"},
    {"suffix": "D", "rate": 200, "duration": 14, "effort": 1.00,
     "disturbance": 1.00, "tolerance": 1.00, "difficulty": "intermediate",
     "style": "sensing_first"},
    {"suffix": "E", "rate": 250, "duration": 16, "effort": 1.10,
     "disturbance": 1.20, "tolerance": 0.90, "difficulty": "advanced",
     "style": "verification_first"},
    {"suffix": "F", "rate": 500, "duration": 20, "effort": 1.22,
     "disturbance": 1.45, "tolerance": 0.80, "difficulty": "advanced",
     "style": "integration_brief"},
)


def _platform(slug: str, stem: str, description: str,
              actuation: str, effort: float, effort_unit: str) -> dict:
    return {"slug": slug, "stem": stem, "description": description,
            "actuation": actuation, "effort": effort,
            "effort_unit": effort_unit}


def _mission(slug: str, stem: str, task: str, sensing: str, environment: str,
             controller: str, properties: str, disturbance: float,
             disturbance_unit: str, tolerance: float,
             tolerance_unit: str) -> dict:
    return {"slug": slug, "stem": stem, "task": task, "sensing": sensing,
            "environment": environment, "controller": controller,
            "properties": properties, "disturbance": disturbance,
            "disturbance_unit": disturbance_unit, "tolerance": tolerance,
            "tolerance_unit": tolerance_unit}


FAMILIES = {
    "articulated_manipulation": {
        "label": "fixed-base articulated manipulator",
        "platforms": [
            _platform("two_link", "DuoArm", "A 20 kg box pedestal supports 0.55 m and 0.38 m capsule links of 5 kg and 3 kg through revolute Y joints limited to plus or minus 1.6 rad.", "Independent joint effort actuators drive both axes", 70, "N.m"),
            _platform("scara", "SCARA", "A 28 kg cylindrical base supports two revolute Z links of 0.48 m and 0.34 m followed by a prismatic Z carriage with 0.30 m travel; moving masses are 6 kg, 4 kg, and 2 kg.", "Three saturated joint-space actuators command the two rotations and vertical slide", 95, "N.m-or-900-N"),
            _platform("branching", "ForkArm", "A 24 kg pedestal carries a revolute Z mast that branches into a revolute X camera boom and a prismatic Y tool slide; the three moving bodies weigh 7 kg, 3 kg, and 2 kg.", "Encoder-feedback effort actuators independently drive the three branches", 80, "N.m-or-700-N"),
            _platform("gantry_arm", "RailArm", "A fixed 1.4 m X rail carries an 18 kg carriage supporting a two-revolute-joint planar arm with 0.46 m and 0.31 m links and joint limits of plus or minus 1.5 rad.", "One linear force actuator and two rotary torque actuators provide motion", 85, "N.m-or-800-N"),
            _platform("four_axis", "AssemblyArm", "A fixed base supports four serial revolute joints with Z, Y, Y, and X axes, capsule-link lengths 0.50 m, 0.40 m, 0.28 m, and 0.16 m, and masses 7 kg, 5 kg, 3 kg, and 1 kg.", "Saturated effort drives use position and velocity feedback on all four axes", 110, "N.m"),
        ],
        "missions": [
            _mission("pointing", "Point", "Move from zero joint state to a declared reachable target and hold it for the final third of the run.", "Joint encoders report position and velocity on every axis.", "Use gravity 9.81 m/s2 and collision geometry matching every rigid link.", "joint-space PD control with gravity compensation", "all joint limits, command saturation, and final target bounds", 8, "N tip load", 0.04, "rad-or-m"),
            _mission("trajectory", "Trace", "Follow a time-indexed cubic joint trajectory through three reachable states and stop at the last state.", "Encoders provide synchronized joint position and velocity samples.", "Place one fixed cylindrical keep-out obstacle beside, but not on, the nominal motion path.", "PID plus velocity-feedforward trajectory control", "joint limits, obstacle clearance above 0.05 m, overshoot below 12 percent, and terminal settling", 10, "N lateral disturbance", 0.05, "rad-or-m"),
            _mission("payload", "Carry", "Lift and reposition a rigid tool payload while preserving the requested end-effector orientation.", "Joint encoders and a six-axis wrist wrench sensor provide feedback.", "Use a rigid workcell floor and a fixed table represented with collision enabled.", "computed-torque control with bounded wrist-force correction", "joint and effort bounds, wrist force below 60 N, payload retention, and pose tracking", 12, "kg payload", 0.045, "rad-or-m"),
            _mission("disturbance", "Reject", "Hold a nonzero joint target while rejecting a finite-duration lateral load at the distal link.", "Encoders and the wrist wrench sensor record the response before, during, and after the load.", "Model gravity and self-collision between nonadjacent links.", "saturated state-feedback control with integral disturbance rejection", "finite states, no self-collision, peak deviation below 0.18 rad, and recovery to the target band", 18, "N disturbance", 0.035, "rad-or-m"),
        ],
    },
    "mobile_robotics": {
        "label": "floating-base mobile robot",
        "platforms": [
            _platform("differential", "DiffRover", "A 19 kg box chassis measuring 0.65 m by 0.44 m by 0.22 m uses two 0.10 m-radius driven wheels separated by 0.46 m and one passive caster.", "Independent wheel motors drive continuous Y-axis joints", 13, "N.m"),
            _platform("ackermann", "AckermannRover", "A 34 kg chassis is 1.05 m long and 0.64 m wide with 0.74 m wheelbase, rear-wheel drive, and front steering joints limited to plus or minus 0.52 rad.", "Rear traction and front steering actuators are independently bounded", 28, "N.m"),
            _platform("mecanum", "OmniCart", "A 25 kg box platform carries four 0.095 m-radius mecanum wheels at 45 degree roller angle on a 0.58 m by 0.46 m footprint.", "Four wheel-torque actuators produce holonomic body motion", 12, "N.m"),
            _platform("tracked", "TrackCrawler", "A 52 kg capsule hull 1.1 m long uses left and right continuous tracks with effective sprocket radius 0.14 m and track separation 0.50 m.", "Two bounded track drives command skid-steer motion", 42, "N.m"),
            _platform("tricycle", "TriTug", "A 38 kg logistics chassis with 20 kg payload uses one 0.15 m-radius front drive-and-steer wheel and two passive rear wheels; steering travel is plus or minus 0.60 rad.", "The front traction and steering axes are effort controlled", 34, "N.m"),
        ],
        "missions": [
            _mission("waypoints", "Route", "Follow planar waypoints [0,0], [4,0], [7,2], and [10,2] m at a commanded speed below 1.5 m/s.", "Wheel encoders, planar odometry, and a chassis IMU provide state feedback.", "Use a rigid floor with friction 0.82 and fixed obstacles outside the reference path.", "bounded path-following and wheel-speed control", "wheel-speed and actuator bounds, cross-track error, chassis attitude, and no collision", 120, "N lateral push", 0.25, "m"),
            _mission("slope", "Climb", "Ascend a 12 degree ramp, traverse a 2 m plateau, and stop before the descending edge.", "Encoders, an IMU, and a forward depth sensor measure speed, attitude, and edge distance.", "Use friction 0.76 and add two 0.05 m-height surface ridges.", "slip-aware traction control with bounded braking", "actuator limits, slip ratio below 0.35, roll and pitch below 0.40 rad, and stopping margin", 150, "N payload force", 0.18, "m/s"),
            _mission("corridor", "Inspect", "Traverse an S-shaped corridor while maintaining a centered path and a speed of 0.8 m/s.", "Fuse wheel odometry, IMU, and 15 m planar lidar measurements for planar pose.", "Build the corridor from fixed walls 1.8 m apart with two recessed alcoves.", "localization-aware path tracking with obstacle avoidance", "finite covariance, wall clearance above 0.18 m, heading error, and route completion", 90, "N side load", 0.20, "m"),
            _mission("stop", "Brake", "Accelerate to 1.2 m/s and perform emergency braking when a forward obstacle enters a 1.4 m safety range.", "Encoders, IMU acceleration, and a 30 Hz depth camera record the stop.", "Place a fixed barrier 7 m ahead on a rigid floor with friction 0.70.", "speed control with a deterministic emergency-stop state machine", "speed and effort limits, monotonic braking, no barrier collision, and residual speed below 0.05 m/s", 180, "N payload disturbance", 0.22, "m stopping margin"),
        ],
    },
    "aerial_robotics": {
        "label": "free-base aerial robot",
        "platforms": [
            _platform("quadrotor", "QuadScout", "A 1.8 kg box fuselage has four rotors at 0.22 m arm length, each producing thrust along body Z and a signed yaw moment.", "Four thrust actuators are independently commanded", 12, "N-per-rotor"),
            _platform("hexacopter", "HexaSurvey", "A 3.2 kg cylindrical fuselage has six equally spaced rotors on a 0.35 m radius and a 0.4 kg downward camera payload.", "Six bounded rotor-thrust channels control the vehicle wrench", 11, "N-per-rotor"),
            _platform("tiltrotor", "TiltWing", "A 6.2 kg capsule fuselage carries two tilting rotors 0.62 m from center and a 1.8 m-span wing; rotor tilt joints travel from 0 rad to 1.57 rad.", "Two thrust channels and two tilt-joint actuators support hover-to-flight transition", 52, "N-per-rotor"),
            _platform("ducted", "DuctInspect", "A 2.7 kg cylindrical body carries four protected ducted fans and a compliant 0.18 m inspection probe along body X.", "Four fan thrust channels and one probe-force actuator are bounded", 18, "N-per-fan"),
            _platform("coaxial", "CoaxLift", "A 4.4 kg cargo platform uses four arms with coaxial counter-rotating rotor pairs and carries a 1.2 kg payload on a 0.70 m massless cable.", "Eight rotor thrust channels provide lift and attitude control", 10, "N-per-rotor"),
        ],
        "missions": [
            _mission("hover", "Hover", "Take off vertically, settle at 2.5 m altitude, and hold level attitude and zero yaw.", "An IMU, altimeter, and 10 Hz position sensor provide feedback.", "Model gravity 9.81 m/s2, air density 1.225 kg/m3, and linear translational drag.", "cascaded position and attitude control with thrust allocation", "rotor bounds, altitude settling, roll and pitch below 0.40 rad, and positive altitude", 4, "N wind force", 0.15, "m"),
            _mission("waypoints", "Survey", "Track 3D waypoints [0,0,1.5], [4,0,2.5], [4,3,2.5], and [1,4,2] m at declared deadlines.", "Fuse IMU, GPS, altimeter, and camera timestamps into pose and velocity estimates.", "Place three fixed cylindrical obstacles outside the reference polyline.", "bounded waypoint tracking with feedforward acceleration", "thrust and attitude bounds, waypoint error, estimator finiteness, and no collision", 6, "N crosswind", 0.35, "m"),
            _mission("payload", "Deliver", "Lift a suspended payload, translate 5 m horizontally, and lower it into a 0.8 m-radius target zone.", "Use IMU and GPS feedback plus cable-angle and tension measurements.", "Apply gravity, aerodynamic drag, and a finite lateral gust during cruise.", "input-shaped position control with cable-swing damping", "thrust and tension bounds, swing below 0.45 rad, target-zone placement, and no ground strike", 8, "N gust", 0.30, "m"),
            _mission("contact", "Touch", "Approach a vertical inspection surface, establish a bounded normal probe force, and hold contact for the last quarter of the run.", "IMU, lidar, optical flow, and probe force sensing estimate pose and contact.", "Represent the wall as a fixed collidable box with friction coefficient 0.55.", "position-to-impedance hybrid control", "thrust and attitude bounds, approach speed, contact force between 5 N and 14 N, and no fan collision", 3, "N tangential wind", 0.04, "m stand-off"),
        ],
    },
    "legged_robotics": {
        "label": "floating-base legged robot",
        "platforms": [
            _platform("quadruped", "QuadPaw", "A 22 kg box torso has four identical three-joint legs with 0.32 m capsule thighs, 0.30 m shanks, spherical feet, and revolute hip and knee limits.", "Joint effort actuators drive twelve leg axes", 48, "N.m-per-joint"),
            _platform("biped", "BipedTwo", "A 36 kg pelvis supports two legs with spherical hips, 0.42 m thighs, 0.40 m shanks, revolute knees, two-axis ankles, and flat feet.", "Bounded joint-torque actuators control both legs", 125, "N.m-per-joint"),
            _platform("hexapod", "HexaWalk", "A 15 kg capsule body has six three-revolute-joint legs with 0.12 m coxa, 0.22 m femur, and 0.26 m tibia links.", "Eighteen saturated joint actuators execute coordinated gaits", 20, "N.m-per-joint"),
            _platform("monopod", "MonoHop", "A 10 kg cylindrical body rides on one telescoping 0.30 m-to-0.60 m leg containing a 15 kN/m spring, 170 N.s/m damper, and spherical foot.", "A bounded linear leg actuator injects hopping energy", 950, "N"),
            _platform("wheeled_leg", "WheelLeg", "A 28 kg torso has four two-joint legs ending in driven 0.10 m wheels, combining adjustable body height with rolling locomotion.", "Eight leg torques and four wheel torques are independently limited", 55, "N.m-per-joint"),
        ],
        "missions": [
            _mission("level_walk", "Walk", "Track a periodic forward gait at 0.4 m/s while holding nominal body height.", "Joint encoders, torso IMU, and foot contact-force sensors provide feedback.", "Use a rigid plane with friction 0.85 and gravity 9.81 m/s2.", "phase-based joint impedance and body-attitude control", "joint and torque bounds, supporting-contact count, body attitude, and forward progress", 70, "N body push", 0.10, "m/s"),
            _mission("rough", "Traverse", "Cross a height field containing 0.08 m rocks and two 0.12 m gaps at a commanded average speed.", "Use joint, IMU, contact, and forward depth measurements for foothold selection.", "Set contact friction to 0.78 and prohibit torso-terrain collision.", "foothold planning with swing-foot trajectory control", "actuator bounds, clearance above 0.03 m, attitude below 0.45 rad, and route completion", 90, "N lateral push", 0.15, "m body-path error"),
            _mission("stairs", "Climb", "Climb four stairs of 0.16 m rise and 0.30 m tread while maintaining body height.", "A depth camera, IMU, encoders, and foot-force sensors identify edges and contacts.", "Use rigid stair collision geometry with friction coefficient 0.88.", "terrain-aware foothold planning and joint-space impedance", "joint and effort bounds, stair-edge clearance, at least two support contacts, and completion", 100, "N payload load", 0.04, "m foothold error"),
            _mission("recovery", "Recover", "Stand or step in place and recover from a finite-duration lateral body impulse.", "Estimate base pose from IMU, kinematics, and force-qualified stance contacts.", "Use level rigid ground with friction 0.90 and no external support.", "whole-body balance control with contact switching", "torque bounds, no foot slip above 0.03 m, positive body height, and attitude recovery", 140, "N push", 0.12, "rad"),
        ],
    },
    "marine_robotics": {
        "label": "free-base marine robot",
        "platforms": [
            _platform("auv", "AUV", "An 85 kg capsule hull 1.5 m long displaces 0.083 m3 in seawater and carries two surge and two heave thrusters.", "Four bidirectional thrusters provide body forces", 110, "N-per-thruster"),
            _platform("rov", "ROV", "A 115 kg box frame measuring 1.1 m by 0.78 m by 0.58 m is slightly positively buoyant and carries six body-wrench thrusters.", "Six bidirectional thrusters control all rigid-body axes", 165, "N-per-thruster"),
            _platform("surface", "Catamaran", "Two 46 kg capsule hulls separated by 1.1 m support an 18 kg rigid deck with port and starboard propellers.", "Differential propeller forces control surge and heading", 430, "N-per-propeller"),
            _platform("glider", "Glider", "A streamlined 60 kg, 1.8 m capsule hull with 0.42 m2 wing area uses a variable-buoyancy unit and a translating 6 kg internal pitch mass.", "Buoyancy-volume and pitch-mass actuators are travel and energy limited", 0.0013, "m3-buoyancy-change"),
            _platform("snake", "SeaSnake", "A 32 kg articulated underwater robot uses six 0.30 m capsule modules connected by alternating yaw and pitch joints and a passive tail fin.", "Twelve bounded joint actuators generate undulatory propulsion", 32, "N.m-per-joint"),
        ],
        "missions": [
            _mission("depth", "Dive", "Descend to 8 m depth, hold depth and zero heading, then return to 3 m.", "Pressure depth, IMU, and Doppler velocity measurements provide feedback.", "Model gravity, buoyancy, seawater density 1025 kg/m3, and quadratic drag.", "cascaded depth and attitude control with bounded allocation", "actuator bounds, depth settling, roll and pitch below 0.35 rad, and finite velocity", 80, "N current force", 0.45, "m"),
            _mission("survey", "Survey", "Follow a 60 m lawnmower path at 1.0 m/s while maintaining constant depth.", "Fuse IMU, pressure, DVL, acoustic range, and compass observations.", "Apply a steady 0.18 m/s lateral water current and model seabed clearance.", "path-following control with current compensation", "actuator bounds, cross-track error, depth error, estimator covariance, and route completion", 100, "N current load", 0.80, "m"),
            _mission("station", "Hold", "Maintain a fixed six-degree-of-freedom pose beside an offshore structure.", "Use pressure, IMU, DVL, and forward sonar feedback.", "Represent the structure as a fixed collidable cylinder and include tether load where applicable.", "bounded body-wrench station keeping", "thruster or joint bounds, position and attitude error, structure clearance, and tether limits", 120, "N tether/current load", 0.30, "m"),
            _mission("dock", "Dock", "Approach a fixed docking funnel from 8 m away, reduce speed inside 1 m, align, and establish compliant capture.", "Sonar, pressure, IMU, and short-range optical pose measurements guide the approach.", "Use rigid station geometry, a compliant capture ring, and a cross-current.", "speed-scheduled pose control with contact transition", "actuator and speed bounds, lateral and yaw alignment, contact force below 500 N, and capture", 140, "N current force", 0.10, "m"),
        ],
    },
    "contact_manipulation": {
        "label": "contact-rich manipulation system",
        "platforms": [
            _platform("parallel_gripper", "ParallelGrip", "A fixed 6 kg palm supports two 0.5 kg opposing box fingers on prismatic joints with 0.05 m travel and compliant pads.", "Two bounded linear finger actuators regulate closure", 45, "N-per-finger"),
            _platform("cartesian", "CartesianTool", "Three orthogonal prismatic axes move a 2.5 kg tool carriage over plus or minus 0.10 m in X and Y and 0.30 m in Z.", "Three force-limited linear actuators provide Cartesian motion", 350, "N-per-axis"),
            _platform("planar_arm", "PlanarPusher", "A fixed base supports 0.46 m and 0.35 m capsule links on revolute Z joints with a rounded contact tool.", "Two joint-torque drives command planar motion", 50, "N.m-per-joint"),
            _platform("six_axis", "ContactArm", "A fixed six-revolute-joint arm has Z-Y-Y-X-Y-X axes, capsule links, a six-axis wrist sensor, and a replaceable rigid tool.", "Six saturated joint effort actuators drive the arm", 120, "N.m-maximum"),
            _platform("suction", "VacuumTool", "A vertical prismatic carriage carries a 0.8 kg compliant suction cup of radius 0.038 m with pressure command from 0 kPa to -70 kPa gauge.", "One linear actuator and one vacuum-pressure actuator are bounded", 320, "N-linear"),
        ],
        "missions": [
            _mission("grasp", "Grasp", "Acquire a rigid object, establish a stable grasp, and hold it without excessive displacement.", "Measure actuator state, normal contact forces, and object pose.", "Use a rigid support table, friction coefficient 0.78, restitution 0.03, and collision enabled.", "impedance motion followed by force regulation", "travel and effort bounds, stable contact, bounded object displacement, and no grasp loss", 8, "N tangential load", 0.015, "m"),
            _mission("insertion", "Insert", "Align a cylindrical peg with a hole having 1 mm radial clearance and insert at least 0.06 m without jamming.", "Use joint or carriage sensing plus a six-axis contact wrench measurement.", "Set contact friction to 0.35 and represent both peg and fixture with rigid collision.", "Cartesian impedance control with bounded insertion speed", "actuator bounds, lateral and axial force limits, peg tilt, and insertion depth", 10, "N lateral fixture load", 0.002, "m alignment"),
            _mission("push", "Push", "Move a rigid box along a two-segment planar reference while regulating normal pushing force.", "Measure robot state, contact force, and object planar pose.", "Use a rigid table with box-table friction 0.42 and tool-box friction 0.65.", "hybrid position-force control", "actuator bounds, contact force between 5 N and 25 N, object yaw, and final pose", 6, "N friction change", 0.04, "m"),
            _mission("surface", "Polish", "Follow a 0.50 m surface path while maintaining a constant normal tool force.", "Joint encoders, wrist wrench, and tool-tip pose provide feedback.", "Represent a fixed curved workpiece with friction coefficient 0.50 and compliant normal contact.", "tangential trajectory control with normal-force regulation", "joint and effort bounds, force between 12 N and 30 N, path error, and continuous contact", 7, "N surface-force disturbance", 0.02, "m"),
        ],
    },
    "trajectory_control": {
        "label": "trajectory-controlled robotic mechanism",
        "platforms": [
            _platform("joint_arm", "JointPath", "A fixed three-revolute-joint arm has Z-Y-Y axes, 0.50 m, 0.38 m, and 0.24 m links, and encoder feedback.", "Three joint-torque actuators follow time-indexed commands", 85, "N.m-per-joint"),
            _platform("gantry", "GantryPath", "A fixed Cartesian gantry has X, Y, and Z travels of 1.8 m, 1.2 m, and 0.55 m and moving masses of 18 kg, 12 kg, and 7 kg.", "Three force actuators drive synchronized prismatic axes", 900, "N-maximum"),
            _platform("gimbal", "GimbalPath", "A fixed yaw-pitch-roll gimbal carries a 4 kg camera and has joint limits of plus or minus 2.8 rad, -1.2 rad to 1.0 rad, and plus or minus 0.8 rad.", "Three bounded torque actuators orient the camera", 20, "N.m-maximum"),
            _platform("redundant", "SevenPath", "A fixed seven-revolute-joint arm uses alternating Z and Y axes, capsule links from 0.34 m to 0.12 m, and full joint-state sensing.", "Seven effort actuators support operational-space and null-space control", 115, "N.m-maximum"),
            _platform("mobile_arm", "MobilePath", "A differential-drive base with 0.10 m wheels carries a three-joint arm with 0.45 m, 0.35 m, and 0.22 m links.", "Wheel torques and three arm-joint torques are jointly commanded", 70, "N.m-maximum"),
        ],
        "missions": [
            _mission("point_to_point", "Move", "Execute a synchronized point-to-point move from zero state through one midpoint to a declared final state.", "Encoders report every controlled coordinate and velocity.", "Use gravity and collision geometry matching the mechanism.", "cubic interpolation with PID and velocity feedforward", "position, velocity, acceleration, and effort bounds plus terminal settling", 5, "percent payload change", 0.03, "rad-or-m"),
            _mission("s_curve", "Smooth", "Follow a jerk-limited S-curve between two states and hold the terminal state.", "Record position, velocity, acceleration, and command at the controller rate.", "Add one fixed keep-out object outside the nominal path.", "feedforward inverse dynamics with bounded feedback correction", "state and command bounds, peak jerk, overshoot below 10 percent, and no collision", 8, "percent inertia change", 0.025, "rad-or-m"),
            _mission("cartesian", "Spline", "Track a Cartesian spline through four timestamped poses while preserving tool orientation.", "Use joint sensing and end-effector pose feedback; include wrist wrench when available.", "Place a fixed cylindrical obstacle beside the path with required clearance 0.06 m.", "operational-space tracking with joint-limit avoidance", "joint and effort bounds, Cartesian error, orientation error, obstacle clearance, and finite commands", 10, "N tool disturbance", 0.035, "m"),
            _mission("periodic", "Cycle", "Repeat a periodic pick-transfer-return cycle for at least four complete periods.", "Record synchronized mechanism state and cycle phase.", "Use a fixed workcell with two stations and collision enabled.", "phase-indexed trajectory control with bounded transition smoothing", "state and effort bounds, cycle-time error, station pose error, no collision, and completed cycles", 12, "percent payload variation", 0.04, "rad-or-m"),
        ],
    },
    "closed_chain_mechanisms": {
        "label": "closed-chain robotic mechanism",
        "platforms": [
            _platform("four_bar", "FourBar", "Two fixed pivots 0.50 m apart connect a 0.20 m crank, 0.44 m coupler, and 0.35 m rocker through four revolute Z joints.", "A bounded crank torque drives the loop", 25, "N.m"),
            _platform("five_bar", "FiveBar", "Two base pivots at plus or minus 0.25 m support two 0.30 m actuated links and two 0.42 m passive links meeting at one planar end point.", "Two base-joint torque actuators drive the parallel mechanism", 38, "N.m-per-actuator"),
            _platform("pantograph", "Pantograph", "A fixed parallelogram uses 0.25 m and 0.50 m links, six revolute Z joints, and one prismatic input with 0.16 m travel.", "One bounded linear actuator commands the input coordinate", 320, "N"),
            _platform("stewart", "Stewart", "A fixed 0.45 m-radius base supports a 36 kg, 0.32 m-radius moving platform through six 0.55 m-to-0.85 m variable-length struts.", "Six linear strut actuators are force limited", 4200, "N-per-strut"),
            _platform("delta", "Delta", "A fixed triangular base carries three actuated 0.32 m upper arms and paired 0.60 m forearms connected to a 3 kg moving platform by revolute and spherical joints.", "Three base-joint torque actuators position the platform", 45, "N.m-per-actuator"),
        ],
        "missions": [
            _mission("speed", "Drive", "Drive the designated input at constant speed and observe the coupled output motion.", "Measure actuator state, output pose, and every loop-closure residual.", "Use gravity where applicable and prevent nonadjacent link collision.", "PI input-speed control with command saturation", "actuator bounds, speed band, every closure error, output travel, and valid joint references", 8, "N-or-N.m load", 0.0015, "m closure"),
            _mission("circle", "Trace", "Trace a planar or spatial circle of radius 0.10 m with the mechanism output.", "Use actuator encoders and direct output-pose measurement.", "Place one fixed obstacle outside the circle and require explicit clearance.", "inverse-kinematic trajectory control with closure stabilization", "joint and effort bounds, closure error, path error, singularity margin, and clearance", 10, "N output load", 0.008, "m path error"),
            _mission("pose", "Position", "Move the output platform to a nonzero pose and hold it against a bounded load.", "Measure all actuator coordinates, output pose, and reaction forces.", "Use rigid base geometry and enable self-collision checks between struts or links.", "pose feedback through constrained inverse kinematics", "actuator travel and force bounds, all closure residuals, pose error, and no self-collision", 14, "N platform load", 0.006, "m pose error"),
            _mission("contact", "Press", "Move the output against a fixed compliant workpiece and regulate contact force.", "Actuator sensors, output pose, and normal contact force provide feedback.", "Use contact stiffness 200 kN/m, damping 2 kN.s/m, and friction coefficient 0.70.", "position-to-force hybrid control under loop constraints", "actuator bounds, closure error, contact force band, tangential slip, and locked contact", 18, "N force change", 0.001, "m closure"),
        ],
    },
    "sensor_estimation": {
        "label": "robotic sensing and estimation system",
        "platforms": [
            _platform("wheel_imu", "WheelIMU", "A 16 kg differential-drive chassis carries wheel encoders and a center-mounted six-axis IMU with declared noise and bias parameters.", "Two wheel-torque actuators produce the observed motion", 10, "N.m-per-wheel"),
            _platform("lidar_camera", "MapRig", "A 22 kg mobile base carries a 20 m planar lidar, forward RGB-D camera, wheel encoders, and IMU at explicitly different rates and transforms.", "Bounded wheel drives follow the mapping route", 12, "N.m-per-wheel"),
            _platform("joint_observer", "TorqueObserver", "A fixed 0.58 m, 8 kg capsule link is driven through a 70:1 electric gearbox and instrumented with motor current and joint encoders.", "The motor drive is voltage and current limited", 75, "N.m-output"),
            _platform("contact_aided", "ContactState", "A 24 kg quadruped torso has four three-joint legs, joint encoders, foot contact and normal-force sensors, and a body IMU.", "Twelve joint effort actuators generate the estimation trajectory", 55, "N.m-per-joint"),
            _platform("marine_nav", "MarineNav", "An underwater vehicle carries IMU, pressure depth, Doppler velocity, compass, and 1 Hz acoustic range sensors with declared extrinsic transforms.", "Four bounded thrusters generate the survey motion", 105, "N-per-thruster"),
        ],
        "missions": [
            _mission("localization", "Localize", "Estimate pose, velocity, and relevant sensor biases while following a bounded route.", "Preserve every sensor rate, timestamp, frame, standard deviation, and bias state.", "Provide fixed landmarks or external references without giving ground truth to the estimator.", "an extended or invariant Kalman filter with asynchronous updates", "finite positive covariance, position and attitude error bands, bias convergence, and actuator limits", 0.04, "sensor-bias step", 0.20, "m-or-rad"),
            _mission("dropout", "Bridge", "Maintain a usable state estimate through a finite outage of the slow absolute-position sensor.", "Continue inertial and proprioceptive updates during the declared dropout window.", "Use a trajectory with both translation and rotation so drift is observable.", "multi-rate filtering with innovation gating", "timestamp order, covariance growth, bounded outage error, and recovery after measurements return", 8, "s dropout", 0.35, "m-or-rad"),
            _mission("disturbance", "Observe", "Estimate an external force or torque applied for a finite interval while holding a commanded state.", "Use actuator current or pressure plus position, velocity, and wrench-related measurements.", "Apply a deterministic load at a declared body location and retain a no-load baseline.", "model-based disturbance observation with low-pass residual filtering", "finite observer state, pre-load residual, in-load estimation error, and post-load recovery", 14, "N-or-N.m load", 2.5, "N-or-N.m error"),
            _mission("mapping", "Map", "Traverse a closed route and produce a consistent pose estimate while retaining raw exteroceptive observations.", "Fuse odometry, IMU, and range updates while preserving camera or sonar data separately.", "Place at least six fixed landmarks and two obstacles in a shared world frame.", "pose filtering with loop-closure correction", "finite covariance, loop-closure position and heading error, declared output rate, and no collision", 0.20, "m landmark perturbation", 0.25, "m"),
        ],
    },
    "fluid_power": {
        "label": "fluid-power robotic actuator system",
        "platforms": [
            _platform("hydraulic_cylinder", "HydCylinder", "A double-acting cylinder has 0.0040 m2 piston area, 0.0032 m2 rod area, 0.50 m stroke, 110 kg moving mass, and two compressible chambers.", "A four-way proportional valve meters supply and tank flow", 0.0012, "m3/s"),
            _platform("hydraulic_motor", "HydMotor", "A bidirectional 48 cm3/rev hydraulic motor with volumetric efficiency 0.92 drives a 130 kg rotary table through a 12:1 gearbox.", "A pressure-compensated proportional valve commands motor flow", 0.0016, "m3/s"),
            _platform("pneumatic_gripper", "PneuGrip", "Two pneumatic cylinders with 0.035 m travel and 0.0012 m2 piston area drive opposing 0.8 kg gripper fingers.", "Two proportional air valves command the compressible chambers", 0.0008, "kg/s"),
            _platform("loader", "HydBoom", "A fixed base supports a 2.0 m boom and 1.4 m stick driven by two geometrically grounded double-acting cylinders carrying a 300 kg payload.", "Two valve sections share a load-sensing pump and relief valve", 0.0035, "m3/s-pump"),
            _platform("pneumatic_stage", "AirStage", "A 42 kg vertical carriage moves through 0.70 m using a double-acting pneumatic cylinder with unequal chamber areas and explicit dead volumes.", "Independent fill and exhaust proportional valves regulate both chambers", 0.015, "kg/s"),
        ],
        "missions": [
            _mission("position", "Position", "Move from the initial coordinate to 70 percent of available travel and hold.", "Measure actuator position, velocity, both chamber pressures, and valve command.", "Use declared supply and return pressure, fluid compressibility, leakage, and mechanical end stops.", "pressure-aware PID or nonlinear position control", "travel, valve, pressure, velocity, and final-position bounds", 100, "N external load", 0.012, "m"),
            _mission("force", "Force", "Establish a commanded output force against a compliant mechanical load.", "Measure chamber pressures, actuator state, and external contact force.", "Use a fixed support, compliant contact, supply limitation, and relief protection.", "cascaded pressure and force regulation", "pressure and flow bounds, contact-force band, no end-stop impact, and stable hold", 150, "N load change", 20, "N force error"),
            _mission("trajectory", "Track", "Follow a smooth two-segment position trajectory under a changing payload.", "Record position, velocity, chamber pressure, pump or supply flow, and command.", "Include viscous friction, leakage, and a finite-duration payload disturbance.", "feedforward flow control with pressure-position feedback", "travel, pressure, flow, acceleration, trajectory-error, and relief-valve bounds", 220, "N payload step", 0.018, "m"),
            _mission("energy", "Conserve", "Complete a repeated actuation cycle while limiting hydraulic or pneumatic energy use.", "Measure supply flow, pressure, actuator state, and accumulated energy or air mass.", "Include realistic return pressure, valve saturation, and thermal or compressibility effects.", "energy-aware motion control with bounded performance degradation", "all physical bounds, cycle completion, terminal error, and declared energy or air-use cap", 180, "N load variation", 0.02, "m"),
        ],
    },
    "electromechanical_actuation": {
        "label": "electromechanical robotic actuator system",
        "platforms": [
            _platform("dc_servo", "DCServo", "A 48 V permanent-magnet DC motor with explicit resistance, inductance, torque constant, rotor inertia, and thermal state drives a revolute link through a 100:1 gearbox.", "Voltage and current are independently saturated", 48, "V"),
            _platform("bldc_wheel", "BLDCWheel", "A 48 V three-phase permanent-magnet motor with four pole pairs drives a 0.12 m wheel through a 9:1 gearbox and is supplied by a battery with internal resistance.", "A field-oriented inverter controls phase current", 48, "V-DC-bus"),
            _platform("ball_screw", "BallScrew", "A 24 V motor drives an 18 kg linear carriage through a 5 mm-pitch ball screw with belt reduction, backlash, Coulomb friction, and 0.65 m travel.", "Cascaded current and position loops command the motor voltage", 24, "V"),
            _platform("series_elastic", "SeriesElastic", "A 48 V brushless motor and 100:1 gearbox drive a revolute output through an 850 N.m/rad torsional spring instrumented on both sides.", "Inner current and outer spring-torque control command the actuator", 48, "V"),
            _platform("winch", "CableWinch", "A 72 V motor and 45:1 gearbox drive a 0.09 m-radius drum lifting a 140 kg payload on a massless cable over 12 m travel.", "Cascaded motor-speed and cable-tension loops command voltage", 72, "V"),
        ],
        "missions": [
            _mission("position", "Position", "Move the mechanical output to a nonzero target and hold against gravity or load.", "Measure electrical current, output position and velocity, and winding temperature.", "Represent the driven rigid body and joint or carriage with collision and physical limits.", "cascaded current and position control with anti-windup", "voltage, current, travel, final-error, and temperature bounds", 8, "N-or-N.m output load", 0.03, "rad-or-m"),
            _mission("speed", "Speed", "Accelerate to a declared output speed, hold it, and decelerate to rest.", "Use phase or armature current, rotor position, output speed, and DC-bus sensing.", "Include gearbox efficiency, mechanical friction, battery droop, and rotating inertia.", "field-oriented or current-limited speed regulation", "voltage, current, speed, acceleration, state-of-charge, and thermal bounds", 12, "N-or-N.m load torque", 0.25, "rad/s-or-m/s"),
            _mission("torque", "Torque", "Track a mechanical output-force or torque command while contacting a compliant load.", "Measure motor current, both sides of any compliant transmission, output state, contact force, and temperature.", "Use rigid support geometry with explicit contact stiffness and damping.", "inner current control with outer force or spring-torque feedback", "electrical, thermal, joint, transmission-deflection, and contact-force bounds", 15, "N-or-N.m load change", 2.0, "N-or-N.m"),
            _mission("disturbance", "Recover", "Follow a smooth motion command and reject a finite mechanical disturbance without tripping protection.", "Record voltage, current, mechanical state, disturbance estimate, and winding temperature.", "Apply the load at a declared time while preserving actuator saturation and thermal dynamics.", "feedforward motion control with disturbance observation", "all electrical and mechanical limits, peak deviation, recovery time, and terminal error", 20, "N-or-N.m disturbance", 0.04, "rad-or-m"),
        ],
    },
    "soft_robotics": {
        "label": "soft robotic system",
        "platforms": [
            _platform("tendon_continuum", "TendonSoft", "A 0.55 m cylindrical continuum body is represented by six constant-curvature sections and three tendons spaced 120 degrees apart.", "Three measured tendon tensions control body curvature", 42, "N-per-tendon"),
            _platform("pneumatic_gripper", "SoftGrip", "Three 0.13 m silicone fingers surround a rigid palm and each contains one pressure chamber represented by four bending sections.", "Three chamber-pressure commands bend the fingers", 95, "kPa-gauge"),
            _platform("soft_crawler", "SoftCrawl", "A 0.48 m compliant body is divided into six serial pneumatic bending chambers with anisotropic ground friction.", "Six bounded chamber pressures create traveling-wave deformation", 75, "kPa-gauge"),
            _platform("variable_stiffness", "ShapeLock", "A six-section continuum arm combines three tendons with thermally activated stiffness elements whose bending stiffness changes between 320 K and 345 K.", "Tendon tension and section heater power are independently controlled", 46, "N-or-18-W"),
            _platform("dielectric", "ElectroSoft", "A 0.20 m by 0.05 m dielectric-elastomer membrane has 0.8 mm thickness, explicit permittivity, viscoelasticity, leakage, and thermal state.", "A slew-limited high-voltage channel controls elongation", 5, "kV"),
        ],
        "missions": [
            _mission("shape", "Shape", "Move the soft body or tip to a declared target shape and hold it.", "Measure tendon force or pressure, section curvature or strain, tip pose, and temperature where applicable.", "Use gravity and preserve the undeformed and actuated geometry in a shared frame.", "shape feedback using a reduced-order deformation model", "actuator, curvature or strain, temperature, finite-state, and final shape-error bounds", 6, "N tip load", 0.045, "m"),
            _mission("grasp", "Grasp", "Conform around a fragile object and regulate total normal grasp force without local overload.", "Use actuator sensing, distributed contact sensing, and object pose measurement.", "Enable compliant collision with friction coefficient 0.70 on a rigid support surface.", "pressure or tendon control with contact-force redistribution", "actuator and deformation bounds, per-contact and total force bands, object displacement, and no contact loss", 4, "N tangential load", 0.015, "m"),
            _mission("locomotion", "Crawl", "Execute a periodic deformation gait and produce net forward progress over multiple cycles.", "Embedded strain sensing estimates section deformation and odometry measures body displacement.", "Use a rigid plane with directional friction and two low ridges.", "phase-shifted pressure or tension gait control", "actuator and curvature bounds, per-cycle slip, average speed, completed cycles, and progress", 5, "N drag load", 0.04, "m-per-cycle"),
            _mission("obstacle", "Avoid", "Reach a target around a fixed obstacle, establish only bounded incidental contact, and then stiffen or hold shape.", "Measure actuator state, distributed contact force, section deformation, and tip pose.", "Represent a fixed cylinder with friction coefficient 0.55 and collision enabled.", "contact-aware shape control with bounded stiffness scheduling", "actuator, deformation, contact-force, temperature, obstacle-clearance, and final tip-error bounds", 8, "N lateral tip load", 0.04, "m"),
        ],
    },
    "multi_robot_systems": {
        "label": "multi-robot system",
        "platforms": [
            _platform("two_ground", "GroundPair", "Two 14 kg differential-drive robots each have 0.09 m wheels, wheel encoders, IMU, lidar, and bounded wheel torques in one shared scene.", "Four wheel-torque channels control the pair", 10, "N.m-per-wheel"),
            _platform("three_ground", "GroundTrio", "Three 18 kg differential-drive warehouse robots share a rigid floor, odometry, lidar, and delayed peer messages.", "Six bounded wheel drives control the fleet", 12, "N.m-per-wheel"),
            _platform("three_aerial", "AirTrio", "Three 1.8 kg quadrotors each have four rotors, IMU, GPS, and peer-relative range sensing.", "Twelve independent rotor-thrust groups control the formation", 12, "N-per-rotor"),
            _platform("ground_air", "MixedTeam", "A 24 kg lidar-equipped ground robot and a 2.1 kg camera quadrotor exchange timestamped pose and map updates.", "Wheel torques and four rotor thrusts are independently bounded", 14, "N.m-or-N"),
            _platform("two_marine", "MarinePair", "Two 80 kg AUVs each carry surge and heave thrusters, IMU, pressure depth, DVL, and a delayed acoustic modem.", "Eight bidirectional thruster channels control the pair", 105, "N-per-thruster"),
        ],
        "missions": [
            _mission("formation", "Form", "Follow a leader trajectory while maintaining declared relative offsets and minimum separation.", "Use onboard state estimation plus peer-relative range and delayed pose messages.", "Place fixed obstacles outside the nominal formation path in one shared environment.", "distributed formation control with bounded local commands", "actuator limits, pairwise separation, formation error, communication age, and no collision", 0.08, "s message delay", 0.30, "m"),
            _mission("intersection", "Coordinate", "Traverse routes that cross at one shared intersection without simultaneous occupancy.", "Each robot uses onboard localization, obstacle sensing, and delayed peer messages.", "Build fixed corridor or lane geometry around the central conflict region.", "decentralized reservation and bounded braking", "actuator bounds, minimum distance, mutual exclusion, waiting time, no collision, and route completion", 0.12, "s message delay", 0.65, "m separation"),
            _mission("handoff", "Handoff", "Divide an inspection task, exchange a timestamped result, and replan one robot using the received data.", "Preserve each robot's local sensors and record communication send, receive, and data age.", "Use walls, markers, or survey features in a common world frame.", "task allocation with local motion control and explicit handoff state", "actuator and separation bounds, bounded data age, successful handoff, no collision, and task completion", 0.10, "s communication delay", 0.40, "m"),
            _mission("dropout", "Resilient", "Maintain coordinated motion through a finite communication dropout and recover the requested relationship afterward.", "Use local proprioception, exteroception, and last-received peer state with timestamps.", "Apply one shared environmental disturbance while communication is unavailable.", "distributed control with prediction during dropout", "actuator bounds, collision avoidance, degraded and recovered formation errors, finite estimates, and completed route", 1.0, "s dropout", 0.60, "m"),
        ],
    },
}


def _fmt(value: float) -> str:
    if abs(value) >= 100:
        return f"{value:.0f}"
    if abs(value) >= 10:
        return f"{value:.1f}".rstrip("0").rstrip(".")
    return f"{value:.3f}".rstrip("0").rstrip(".")


def _prompt(family: str, platform: dict, mission: dict,
            variant: dict, case_number: int) -> str:
    effort = _fmt(platform["effort"] * variant["effort"])
    disturbance = _fmt(mission["disturbance"] * variant["disturbance"])
    tolerance = _fmt(mission["tolerance"] * variant["tolerance"])
    name = f"{platform['stem']}{mission['stem']}{variant['suffix']}"
    settle = _fmt(variant["duration"] * 0.65)
    label = FAMILIES[family]["label"]
    limit = f"{effort} {platform['effort_unit']}"
    load = f"{disturbance} {mission['disturbance_unit']}"
    timing = (f"Run at {variant['rate']} Hz for {variant['duration']} s and "
              "retain synchronized state, command, and sensor traces.")
    acceptance = (
        f"Require {mission['properties']}, primary tracking error below "
        f"{tolerance} {mission['tolerance_unit']} after {settle} s, and no NaN "
        "or infinite physical, control, or estimator values. Treat facts not "
        "stated in this request as unknown rather than inventing them."
    )
    styles = {
        "plant_first": (
            f"Generate a {label} named {name}. {platform['description']} "
            f"{platform['actuation']}, with a command magnitude limit of {limit}. "
            f"{mission['task']} {mission['sensing']} {mission['environment']} "
            f"Use {mission['controller']}. Apply a controlled {load} disturbance "
            f"during the middle third of the scenario. {timing} {acceptance}"
        ),
        "scenario_first": (
            f"Model this mission for a {label} named {name}: {mission['task']} "
            f"The physical system is as follows. {platform['description']} "
            f"{platform['actuation']} and the allowed command magnitude is "
            f"{limit}. {mission['environment']} Instrument the scenario as "
            f"follows: {mission['sensing']} Control it using "
            f"{mission['controller']}. During the middle third, inject a "
            f"controlled {load} disturbance. {timing} {acceptance}"
        ),
        "control_first": (
            f"Specify a {label} called {name} around {mission['controller']}. "
            f"Its objective is to {mission['task'][0].lower() + mission['task'][1:]} "
            f"Use a maximum command magnitude of {limit}, and inject a controlled "
            f"{load} disturbance during the middle third. The plant must be "
            f"represented explicitly: {platform['description']} "
            f"{platform['actuation']}. Feedback and evidence come from the "
            f"following instrumentation: {mission['sensing']} "
            f"{mission['environment']} {timing} {acceptance}"
        ),
        "sensing_first": (
            f"Create an instrumented {label} named {name}. Preserve these "
            f"measurements and their roles: {mission['sensing']} The measured "
            f"plant is defined by this embodiment: {platform['description']} "
            f"{platform['actuation']}, limited to {limit}. The requested behavior "
            f"is to {mission['task'][0].lower() + mission['task'][1:]} "
            f"{mission['environment']} Use {mission['controller']} and apply a "
            f"controlled {load} disturbance during the middle third. {timing} "
            f"{acceptance}"
        ),
        "verification_first": (
            f"Build a verifiable {label} named {name}. The resulting scenario "
            f"must make the following behavior testable: {mission['task']} "
            f"Represent the plant without omitting its structure. "
            f"{platform['description']} {platform['actuation']}, with command "
            f"magnitude bounded by {limit}. {mission['sensing']} "
            f"{mission['environment']} Apply {mission['controller']} and a "
            f"controlled {load} middle-third disturbance. {timing} Acceptance "
            f"is fail-closed. {acceptance}"
        ),
        "integration_brief": (
            f"Define one complete robotics scenario named {name} for the "
            f"{label} domain. Mission: {mission['task']} Embodiment: "
            f"{platform['description']} Actuation: {platform['actuation']}, and "
            f"do not exceed {limit}. Observation: {mission['sensing']} Operating "
            f"context: {mission['environment']} Control: use "
            f"{mission['controller']}. Robustness case: apply a controlled "
            f"{load} disturbance during the middle third. Timing and evidence: "
            f"{timing} Verification criteria: {acceptance}"
        ),
    }
    return styles[variant["style"]]


def build_cases() -> list[dict]:
    cases: list[dict] = []
    case_number = 0
    prompt_number = 0
    for family in sorted(FAMILIES):
        config = FAMILIES[family]
        for platform in config["platforms"]:
            for mission in config["missions"]:
                case_number += 1
                semantic_id = f"RPS{case_number:03d}"
                lineage_id = f"{family}:{platform['slug']}:{mission['slug']}"
                for variant_index, variant in enumerate(VARIANTS, 1):
                    prompt_number += 1
                    cases.append({
                        "id": f"RPI{prompt_number:04d}",
                        "family": family,
                        "split": "corpus",
                        "difficulty": variant["difficulty"],
                        "semantic_case_id": semantic_id,
                        "lineage_id": lineage_id,
                        "configuration_variant": f"controlled_config_{variant_index}",
                        "expected_profiles": ["general_modelica_openusd",
                                              FAMILY_PROFILE[family]],
                        "target_tier": 4,
                        "runtime_candidate": True,
                        "provenance": "systematic-authored-robotics-design-space-v1",
                        "design_axes": {
                            "embodiment": platform["slug"],
                            "mission": mission["slug"],
                            "control_rate_hz": variant["rate"],
                            "duration_s": variant["duration"],
                            "prompt_style": variant["style"],
                        },
                        "request": _prompt(family, platform, mission, variant,
                                           case_number),
                    })
    return cases


def build_manifest() -> dict:
    routes = json.loads(DEVELOPMENT_MANIFEST.read_text(encoding="utf-8"))[
        "rag_family_routes"
    ]
    return {
        "schema_version": "1.0",
        "benchmark_id": "robotics-pipeline-execution-corpus-v2",
        "status": "candidate_execution_inputs_not_yet_run",
        "execution_mode": "capability_tiered",
        "design": {
            "family_count": 13,
            "embodiments_per_family": 5,
            "missions_per_embodiment": 4,
            "semantic_cases_per_family": 20,
            "controlled_configurations_per_semantic_case": 6,
            "prompt_count_per_family": 120,
            "semantic_case_count": 260,
            "prompt_count": 1560,
            "independence_policy": (
                "Only semantic_case_id units are independent; controlled "
                "configurations within a lineage are repeated configurations."
            ),
        },
        "rag_family_routes": routes,
        "cases": build_cases(),
    }


def _normalize(text: str) -> str:
    return " ".join(re.findall(r"[a-z0-9]+", text.lower()))


def _five_grams(text: str) -> set[tuple[str, ...]]:
    tokens = _normalize(text).split()
    return {tuple(tokens[index:index + 5])
            for index in range(max(0, len(tokens) - 4))}


def _maximum_overlap(left: list[dict], right: list[dict],
                     right_field: str = "request") -> dict:
    right_grams = [(str(row.get("id", "")), _five_grams(str(row[right_field])))
                   for row in right]
    best = {"score": 0.0, "case_id": None, "reference_id": None}
    for case in left:
        grams = _five_grams(case["request"])
        for reference_id, reference in right_grams:
            union = grams | reference
            score = len(grams & reference) / len(union) if union else 0.0
            if score > best["score"]:
                best = {"score": score, "case_id": case["id"],
                        "reference_id": reference_id}
    return best


def audit_manifest(path: Path = MANIFEST) -> dict:
    data = json.loads(path.read_text(encoding="utf-8"))
    cases = data.get("cases", [])
    expected = build_manifest()
    issues: list[dict] = []

    def require(condition: bool, code: str, location: str, **detail: object) -> None:
        if not condition:
            issues.append({"code": code, "path": location, **detail})

    require(data == expected, "materialized_corpus_drift", "$" )
    require(len(cases) == 1560, "wrong_prompt_count", "$.cases",
            actual=len(cases))
    ids = [case.get("id") for case in cases]
    requests = [_normalize(str(case.get("request", ""))) for case in cases]
    semantic_ids = [case.get("semantic_case_id") for case in cases]
    require(ids == [f"RPI{index:04d}" for index in range(1, 1561)],
            "noncanonical_ids", "$.cases")
    require(len(ids) == len(set(ids)), "duplicate_id", "$.cases")
    require(len(requests) == len(set(requests)), "duplicate_request", "$.cases")
    require(len(set(semantic_ids)) == 260, "wrong_semantic_case_count", "$.cases")
    family_counts = Counter(case.get("family") for case in cases)
    semantic_by_family = {
        family: len({case["semantic_case_id"] for case in cases
                     if case.get("family") == family})
        for family in REQUIRED_FAMILIES
    }
    require(set(family_counts) == set(REQUIRED_FAMILIES), "wrong_families",
            "$.cases")
    for family in sorted(REQUIRED_FAMILIES):
        require(family_counts[family] == 120, "unbalanced_family", "$.cases",
                family=family, actual=family_counts[family])
        require(semantic_by_family[family] == 20, "unbalanced_semantic_family",
                "$.cases", family=family, actual=semantic_by_family[family])
    lineage_counts = Counter(case.get("lineage_id") for case in cases)
    require(set(lineage_counts.values()) == {6}, "unbalanced_lineage", "$.cases")
    style_counts = Counter(case.get("design_axes", {}).get("prompt_style")
                           for case in cases)
    require(set(style_counts.values()) == {260} and len(style_counts) == 6,
            "unbalanced_prompt_styles", "$.cases", actual=dict(style_counts))
    for index, case in enumerate(cases):
        request = str(case.get("request", ""))
        prefix = f"$.cases[{index}]"
        require(len(request.split()) >= 100, "under_grounded_prompt",
                f"{prefix}.request", word_count=len(request.split()))
        require("Hz" in request and "Require" in request,
                "missing_timing_or_properties", f"{prefix}.request")
        require(case.get("expected_profiles") == [
            "general_modelica_openusd", FAMILY_PROFILE[case["family"]]
        ], "wrong_profiles", f"{prefix}.expected_profiles")
        require(case.get("target_tier") == 4,
                "wrong_target_tier", f"{prefix}.target_tier")
        require(case.get("runtime_candidate") is True,
                "runtime_not_required", f"{prefix}.runtime_candidate")

    evaluation = json.loads(EVALUATION_MANIFEST.read_text(encoding="utf-8"))["cases"]
    development = json.loads(DEVELOPMENT_MANIFEST.read_text(encoding="utf-8"))["cases"]
    modelica = json.loads(MODELICA_MANIFEST.read_text(encoding="utf-8"))
    openusd = json.loads(OPENUSD_MANIFEST.read_text(encoding="utf-8"))
    reference_sets = {
        "held_out_evaluation": (evaluation, "request"),
        "development": (development, "request"),
        "modelica_rag": (modelica, "requirement"),
        "openusd_rag": (openusd, "requirement"),
    }
    leakage = {}
    request_set = set(requests)
    for name, (rows, field) in reference_sets.items():
        exact = request_set & {_normalize(str(row[field])) for row in rows}
        maximum = _maximum_overlap(cases, rows, field)
        leakage[name] = {"reference_count": len(rows),
                         "exact_match_count": len(exact),
                         "maximum_five_gram_jaccard": maximum}
        require(not exact, "exact_prompt_leakage", f"$.leakage.{name}")
        require(maximum["score"] < 0.35, "high_prompt_overlap",
                f"$.leakage.{name}", **maximum)

    return {
        "stage": "pipeline_prompt_corpus_audit",
        "schema_version": "1.0",
        "success": not issues,
        "prompt_count": len(cases),
        "semantic_case_count": len(set(semantic_ids)),
        "family_counts": dict(sorted(family_counts.items())),
        "semantic_case_counts": dict(sorted(semantic_by_family.items())),
        "lineage_count": len(lineage_counts),
        "configurations_per_lineage": sorted(set(lineage_counts.values())),
        "difficulty_counts": dict(sorted(Counter(
            case.get("difficulty") for case in cases
        ).items())),
        "prompt_style_counts": dict(sorted(style_counts.items())),
        "manifest_sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
        "leakage": leakage,
        "issues": issues,
    }


def _write(path: Path) -> None:
    path.write_text(
        json.dumps(build_manifest(), indent=2, ensure_ascii=False,
                   allow_nan=False) + "\n",
        encoding="utf-8",
    )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--write", action="store_true",
                        help="materialize the deterministic corpus manifest")
    parser.add_argument("--output", type=Path, default=MANIFEST)
    args = parser.parse_args()
    if args.write:
        _write(args.output)
    report = audit_manifest(args.output)
    print(json.dumps(report, indent=2, sort_keys=True))
    return 0 if report["success"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
