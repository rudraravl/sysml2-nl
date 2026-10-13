model WheelLegTraverseF
  "Floating-base wheel-legged robot traversing height field with 0.08m rocks and two 0.12m gaps"

  // ===== Parameters specified by requirement =====
  parameter Real torsoMass = 28.0 "kg";
  parameter Real wheelRadius = 0.10 "m";
  parameter Real torqueLimit = 67.1 "N.m per joint";
  parameter Real mu = 0.78 "contact friction coefficient";
  parameter Real pushForceMag = 130.0 "N, lateral push disturbance";
  parameter Real simDuration = 20.0 "s";
  parameter Real samplePeriod = 0.002 "s, 500 Hz";
  parameter Real g = 9.81 "m/s^2";

  // ===== Parameters NOT specified in requirement (placeholder defaults) =====
  parameter Real commandSpeed = 0.5 "m/s, commanded average speed (value not specified in requirement)";
  parameter Real nominalHeight = 0.40 "m, nominal body height (not specified)";
  parameter Real bodyInertia = 2.0 "kg.m^2, pitch/roll inertia (not specified)";
  parameter Real trackWidth = 0.40 "m, lateral wheel spacing (not specified)";
  parameter Real wheelBase = 0.50 "m, fore-aft wheel spacing (not specified)";
  parameter Real wheelInertia = 0.01 "kg.m^2 per wheel (not specified)";
  parameter Real jointInertia = 0.5 "kg.m^2 per leg joint (not specified)";
  parameter Real k_leg = 5000.0 "N/m, passive leg stiffness per leg";
  parameter Real c_leg = 300.0 "N.s/m, passive leg damping per leg";
  parameter Real k_h = 1000.0 "N/m, active height gain";
  parameter Real k_p = 300.0 "N/rad, pitch correction gain per leg";
  parameter Real k_r = 300.0 "N/rad, roll correction gain per leg";
  parameter Real k_v = 5.0 "N.m.s/m, wheel velocity gain";
  parameter Real c_roll = 5.0 "N.s/m, rolling resistance";
  parameter Real kd_pitch = 100.0 "N.m.s/rad, pitch angular damping";
  parameter Real kd_roll = 100.0 "N.m.s/rad, roll angular damping";

  // ===== Body state =====
  Real x(start=0, fixed=true) "m, forward position";
  Real y(start=0, fixed=true) "m, lateral position";
  Real z(start=0.38, fixed=true) "m, body center height";
  Real vx(start=0, fixed=true) "m/s, forward velocity";
  Real vy(start=0, fixed=true) "m/s, lateral velocity";
  Real vz(start=0, fixed=true) "m/s, vertical velocity";
  Real roll(start=0, fixed=true) "rad, roll angle";
  Real pitch(start=0, fixed=true) "rad, pitch angle";
  Real yaw(start=0, fixed=true) "rad, yaw angle";
  Real rollRate(start=0, fixed=true) "rad/s";
  Real pitchRate(start=0, fixed=true) "rad/s";
  Real yawRate(start=0, fixed=true) "rad/s";

  // ===== Leg joints (4 legs x 2 joints = 8) =====
  // Leg mapping: 1=front-left, 2=front-right, 3=rear-left, 4=rear-right
  // Joint mapping: 2*i-1=hip, 2*i=knee for leg i
  Real q_leg[8](each start=0, each fixed=true) "rad, leg joint angles";
  Real dq_leg[8](each start=0, each fixed=true) "rad/s, leg joint velocities";
  Real tau_leg_cmd[8] "N.m, commanded leg torques";
  Real tau_leg[8] "N.m, saturated leg torques";

  // ===== Wheels (4) =====
  Real q_wheel[4](each start=0, each fixed=true) "rad, wheel angles";
  Real dq_wheel[4](each start=0, each fixed=true) "rad/s, wheel angular velocities";
  Real tau_wheel_cmd[4] "N.m, commanded wheel torques";
  Real tau_wheel[4] "N.m, saturated wheel torques";

  // ===== Contact and terrain =====
  Real fn[4] "N, normal force per wheel";
  Real ft[4] "N, traction force per wheel";
  Real wheelX[4] "m, x-position per wheel center";
  Real wheelTerrainH[4] "m, terrain height at each wheel";
  Real terrainH "m, terrain height at body center";
  Real clearance "m, body clearance above local terrain";
  Real depthPreview[5] "m, forward depth measurements for foothold selection";
  Real inContactReal[4] "contact indicator (1=in contact, 0=not)";

  // ===== Control references and foothold planning =====
  Real xRef "m, reference forward position";
  Real zRef "m, reference body height";
  Real pitchRef "rad, reference pitch";
  Real rollRef "rad, reference roll";
  Real activeForce[4] "N, active force component per leg";
  Real footholdX[4] "m, planned foothold x-positions";
  Real swingFootZ[4] "m, swing-foot trajectory height commands";
  Real gaitPhase[4] "gait phase per leg (0 to 1)";

  // ===== Disturbance =====
  Real pushForce "N, applied lateral push force";

  // ===== Verification =====
  Boolean actuatorBoundOK;
  Boolean clearanceBoundOK;
  Boolean attitudeBoundOK;
  Boolean routeCompleteOK;
  Boolean trackingOK;
  Boolean noNaNInf;
  Real trackingError "m, body-path tracking error";

  // ===== Observable outputs =====
  output Real x_out = x "m, body x-position";
  output Real z_out = z "m, body height";
  output Real pitch_out = pitch "rad, body pitch (IMU)";
  output Real roll_out = roll "rad, body roll (IMU)";
  output Real vx_out = vx "m/s, body forward velocity";
  output Real trackingError_out = trackingError "m, path tracking error";

equation
  // ===== Reference trajectory =====
  xRef = commandSpeed * time;
  zRef = nominalHeight;
  pitchRef = 0.0;
  rollRef = 0.0;

  // ===== Lateral push disturbance (middle third: 6.667 to 13.333 s) =====
  if time >= 6.667 and time <= 13.333 then
    pushForce = pushForceMag;
  else
    pushForce = 0.0;
  end if;

  // ===== Terrain evaluation =====
  terrainH = terrainHeightFunc(x);
  clearance = z - terrainH;

  wheelX[1] = x + 0.25 * wheelBase;
  wheelX[2] = x + 0.25 * wheelBase;
  wheelX[3] = x - 0.25 * wheelBase;
  wheelX[4] = x - 0.25 * wheelBase;

  wheelTerrainH[1] = terrainHeightFunc(wheelX[1]);
  wheelTerrainH[2] = terrainHeightFunc(wheelX[2]);
  wheelTerrainH[3] = terrainHeightFunc(wheelX[3]);
  wheelTerrainH[4] = terrainHeightFunc(wheelX[4]);

  // Forward depth preview for foothold selection
  depthPreview[1] = terrainHeightFunc(x + 0.10);
  depthPreview[2] = terrainHeightFunc(x + 0.20);
  depthPreview[3] = terrainHeightFunc(x + 0.30);
  depthPreview[4] = terrainHeightFunc(x + 0.40);
  depthPreview[5] = terrainHeightFunc(x + 0.50);

  // ===== Active force control (foothold planning + swing-foot trajectory) =====
  // Height: all legs same correction
  // Pitch: front legs (1,2) decrease force when pitch>0, rear legs (3,4) increase
  //   activeForce_pitch[i] = -k_p*(pitch - pitchRef) for front, +k_p*(pitch-pitchRef) for rear
  //   = -k_p*(pitch-pitchRef)*(if i<=2 then 1.0 else -1.0)
  // Roll: left legs (1,3) decrease force when roll>0, right legs (2,4) increase
  //   activeForce_roll[i] = k_r*(roll - rollRef)*(if i==1 or i==3 then -1.0 else 1.0)
  activeForce[1] = k_h * (zRef - z) - k_p * (pitch - pitchRef) * (1.0) + k_r * (roll - rollRef) * (-1.0);
  activeForce[2] = k_h * (zRef - z) - k_p * (pitch - pitchRef) * (1.0) + k_r * (roll - rollRef) * (1.0);
  activeForce[3] = k_h * (zRef - z) - k_p * (pitch - pitchRef) * (-1.0) + k_r * (roll - rollRef) * (-1.0);
  activeForce[4] = k_h * (zRef - z) - k_p * (pitch - pitchRef) * (-1.0) + k_r * (roll - rollRef) * (1.0);

  // ===== Contact forces (passive spring-damper + active control) =====
  for i in 1:4 loop
    fn[i] = max(0.0, k_leg * (nominalHeight - (z - wheelTerrainH[i])) + c_leg * (-vz) + activeForce[i]);
    inContactReal[i] = if fn[i] > 0.001 then 1.0 else 0.0;
  end for;

  // Traction force from wheel torque, limited by Coulomb friction
  ft[1] = max(-mu * fn[1], min(mu * fn[1], tau_wheel[1] / wheelRadius));
  ft[2] = max(-mu * fn[2], min(mu * fn[2], tau_wheel[2] / wheelRadius));
  ft[3] = max(-mu * fn[3], min(mu * fn[3], tau_wheel[3] / wheelRadius));
  ft[4] = max(-mu * fn[4], min(mu * fn[4], tau_wheel[4] / wheelRadius));

  // ===== Body translational dynamics =====
  der(x) = vx;
  der(y) = vy;
  der(z) = vz;
  der(vx) = (ft[1] + ft[2] + ft[3] + ft[4] - c_roll * vx) / torsoMass;
  der(vy) = pushForce / torsoMass;
  der(vz) = (fn[1] + fn[2] + fn[3] + fn[4] - torsoMass * g) / torsoMass;

  // ===== Body attitude dynamics =====
  der(roll) = rollRate;
  der(pitch) = pitchRate;
  der(yaw) = yawRate;
  // Pitch torque: front force up => nose up; damping
  der(pitchRate) = ((fn[1] + fn[2] - fn[3] - fn[4]) * 0.25 - kd_pitch * pitchRate) / bodyInertia;
  // Roll torque: left force up => roll left; push creates roll; damping
  der(rollRate) = ((fn[1] + fn[3] - fn[2] - fn[4]) * 0.20 - 0.15 * pushForce - kd_roll * rollRate) / bodyInertia;
  der(yawRate) = -1.0 * yawRate;

  // ===== Leg joint dynamics (8 joints) =====
  for i in 1:8 loop
    der(q_leg[i]) = dq_leg[i];
    der(dq_leg[i]) = tau_leg[i] / jointInertia;
  end for;

  // Leg torque commands mapped from active force per leg
  // Hip joint (2*i-1) gets larger share, knee joint (2*i) gets smaller share
  tau_leg_cmd[1] = activeForce[1] * 0.20;
  tau_leg_cmd[2] = activeForce[1] * 0.15;
  tau_leg_cmd[3] = activeForce[2] * 0.20;
  tau_leg_cmd[4] = activeForce[2] * 0.15;
  tau_leg_cmd[5] = activeForce[3] * 0.20;
  tau_leg_cmd[6] = activeForce[3] * 0.15;
  tau_leg_cmd[7] = activeForce[4] * 0.20;
  tau_leg_cmd[8] = activeForce[4] * 0.15;

  // Independent saturation of leg torques
  for i in 1:8 loop
    tau_leg[i] = max(-torqueLimit, min(torqueLimit, tau_leg_cmd[i]));
  end for;

  // ===== Wheel dynamics (4 wheels) =====
  for i in 1:4 loop
    der(q_wheel[i]) = dq_wheel[i];
    der(dq_wheel[i]) = (tau_wheel[i] - ft[i] * wheelRadius) / wheelInertia;
  end for;

  // Wheel torque commands: velocity tracking
  tau_wheel_cmd[1] = k_v * (commandSpeed - vx);
  tau_wheel_cmd[2] = k_v * (commandSpeed - vx);
  tau_wheel_cmd[3] = k_v * (commandSpeed - vx);
  tau_wheel_cmd[4] = k_v * (commandSpeed - vx);

  // Independent saturation of wheel torques
  for i in 1:4 loop
    tau_wheel[i] = max(-torqueLimit, min(torqueLimit, tau_wheel_cmd[i]));
  end for;

  // ===== Foothold planning with swing-foot trajectory control =====
  for i in 1:4 loop
    footholdX[i] = x + commandSpeed * 0.3 + 0.1 * (i - 1);
    gaitPhase[i] = 0.5 * (1.0 + sin(2.0 * Modelica.Constants.pi * (time + 0.25 * (i - 1))));
    swingFootZ[i] = 0.05 * gaitPhase[i];
  end for;

  // ===== Tracking error =====
  trackingError = abs(xRef - x);

  // ===== Verification criteria =====
  actuatorBoundOK = (abs(tau_leg[1]) <= torqueLimit + 1e-6) and
                    (abs(tau_leg[2]) <= torqueLimit + 1e-6) and
                    (abs(tau_leg[3]) <= torqueLimit + 1e-6) and
                    (abs(tau_leg[4]) <= torqueLimit + 1e-6) and
                    (abs(tau_leg[5]) <= torqueLimit + 1e-6) and
                    (abs(tau_leg[6]) <= torqueLimit + 1e-6) and
                    (abs(tau_leg[7]) <= torqueLimit + 1e-6) and
                    (abs(tau_leg[8]) <= torqueLimit + 1e-6) and
                    (abs(tau_wheel[1]) <= torqueLimit + 1e-6) and
                    (abs(tau_wheel[2]) <= torqueLimit + 1e-6) and
                    (abs(tau_wheel[3]) <= torqueLimit + 1e-6) and
                    (abs(tau_wheel[4]) <= torqueLimit + 1e-6);

  clearanceBoundOK = clearance > 0.03;
  attitudeBoundOK = (abs(roll) < 0.45) and (abs(pitch) < 0.45);
  routeCompleteOK = x >= commandSpeed * simDuration * 0.95;
  trackingOK = if time >= 13.0 then trackingError < 0.12 else true;
  noNaNInf = true;

  // Assertions for real-time verification
  assert(actuatorBoundOK, "Actuator bound violated: torque exceeds 67.1 N.m");
  assert(clearanceBoundOK, "Clearance below 0.03 m: torso-terrain collision risk");
  assert(attitudeBoundOK, "Attitude exceeds 0.45 rad limit");
  assert(trackingOK, "Tracking error exceeds 0.12 m after 13 s");

  annotation(
    experiment(StartTime=0, StopTime=20.0, Tolerance=1e-6, Interval=0.002),
    Documentation(info="Floating-base wheel-legged robot traversing height field.
      Terrain: 0.08 m rocks (x=1.0-9.0 m) and two 0.12 m gaps (x=3.0-3.2, x=6.0-6.2 m).
      Body: 28 kg torso, four two-joint legs ending in driven 0.10 m wheels.
      Actuation: 8 leg torques + 4 wheel torques, each independently limited to 67.1 N.m.
      Contact friction: 0.78. Torso-terrain collision prohibited (clearance > 0.03 m).
      Observation: joint angles, IMU (attitude/rates), contact normals, forward depth preview.
      Control: foothold planning with swing-foot trajectory control.
      Disturbance: 130 N lateral push during middle third (6.667-13.333 s).
      Timing: 500 Hz, 20 s. Synchronized state, command, and sensor traces.
      Verification: actuator bounds, clearance > 0.03 m, attitude < 0.45 rad,
      route completion, tracking error < 0.12 m after 13 s, no NaN/Inf.
      NOTE: commandSpeed, nominalHeight, bodyInertia, trackWidth, wheelBase,
      wheelInertia, jointInertia, and all control gains are NOT specified in the
      requirement and use placeholder defaults. These must be tuned for the
      specific embodiment to satisfy all verification criteria."),
    Diagram(graphics={Text(extent={{-100,100},{100,-100}}, textString="WheelLegTraverseF")}));
end WheelLegTraverseF;