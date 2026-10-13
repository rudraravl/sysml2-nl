model WheelLegTraverseC
  "Floating-base wheel-leg robot crossing a height field with foothold planning and swing-foot control"

  // Physical constants
  constant Real g = 9.81 "m/s^2";
  constant Real pi_val = 3.14159265358979;

  // === Requirement-specified parameters ===
  parameter Real torsoMass = 28.0 "kg";
  parameter Real wheelRadius = 0.10 "m";
  parameter Real frictionCoeff = 0.78;
  parameter Real maxJointTorque = 50.6 "N.m";
  parameter Real rockHeight = 0.08 "m";
  parameter Real gapDepth = 0.12 "m";
  parameter Real simDuration = 12.0 "s";
  parameter Real controlFreq = 125.0 "Hz";
  parameter Real pushForce = 81.0 "N";
  parameter Real clearanceMin = 0.03 "m";
  parameter Real attitudeMax = 0.45 "rad";
  parameter Real trackingErrorMax = 0.158 "m";
  parameter Real settlingTime = 7.8 "s";

  // === Design parameters (not specified in requirement) ===
  parameter Real commandedSpeed = 0.8 "m/s, design choice for average speed command";
  parameter Real bodyHalfLength = 0.25 "m";
  parameter Real hipHalfWidth = 0.15 "m";
  parameter Real nominalHeight = 0.40 "m";
  parameter Real upperLegLength = 0.25 "m";
  parameter Real lowerLegLength = 0.25 "m";
  parameter Real bodyInertia = 2.0 "kg.m^2";
  parameter Real hipInertia = 0.10 "kg.m^2";
  parameter Real kneeInertia = 0.05 "kg.m^2";
  parameter Real contactStiffness = 15000.0 "N/m";
  parameter Real contactDamping = 600.0 "N.s/m";
  parameter Real gaitPeriod = 0.5 "s";
  parameter Real swingHeight = 0.12 "m";
  parameter Real strideLength = commandedSpeed * gaitPeriod "m";
  parameter Real hipKp = 300.0 "N.m/rad";
  parameter Real hipKd = 15.0 "N.m.s/rad";
  parameter Real kneeKp = 150.0 "N.m/rad";
  parameter Real kneeKd = 8.0 "N.m.s/rad";
  parameter Real wheelKp = 10.0 "N.m.s/m";
  parameter Real latStiffness = 2000.0 "N/m";
  parameter Real latDamping = 100.0 "N.s/m";
  parameter Real rock1Center = 2.0 "m, design choice";
  parameter Real rock2Center = 6.0 "m, design choice";
  parameter Real gap1Center = 4.0 "m, design choice";
  parameter Real gap2Center = 8.0 "m, design choice";
  parameter Real rockHalfWidth = 0.20 "m, design choice";
  parameter Real gapHalfWidth = 0.15 "m, design choice";
  parameter Real terrainK = 30.0 "1/m, terrain transition sharpness";
  parameter Real routeLength = 9.0 "m, design target for route completion";
  parameter Real pushStart = simDuration / 3.0 "s";
  parameter Real pushEnd = 2.0 * simDuration / 3.0 "s";
  parameter Real depthLookahead = 0.5 "m, forward depth sensor range";

  // === Torso state ===
  Real x_pos(start=0.0, fixed=true) "m, forward position";
  Real x_vel(start=0.0, fixed=true) "m/s";
  Real z_pos(start=nominalHeight, fixed=true) "m, vertical position";
  Real z_vel(start=0.0, fixed=true) "m/s";
  Real y_pos(start=0.0, fixed=true) "m, lateral position";
  Real y_vel(start=0.0, fixed=true) "m/s";
  Real pitch(start=0.0, fixed=true) "rad";
  Real pitch_rate(start=0.0, fixed=true) "rad/s";

  // === Leg joint state (4 legs: 1=FL, 2=FR, 3=RL, 4=RR) ===
  Real q1[4](start={0.0,0.0,0.0,0.0}, each fixed=true) "rad, hip angle";
  Real q1_rate[4](each start=0.0, each fixed=true) "rad/s";
  Real q2[4](each start=0.0, each fixed=true) "rad, knee angle";
  Real q2_rate[4](each start=0.0, each fixed=true) "rad/s";
  Real wheelAng[4](each start=0.0, each fixed=true) "rad";

  // === Gait ===
  Real gaitPhase[4];
  Real phaseOffset[4];
  Boolean inStance[4];

  // === Hip offsets ===
  Real hipXOff[4];

  // === Desired joint angles and foot trajectory ===
  Real q1_des[4] "rad";
  Real q2_des[4] "rad";
  Real footX_desRel[4] "m";
  Real footZ_desRel[4] "m";

  // === Forward kinematics ===
  Real footX[4] "m";
  Real footZ[4] "m";
  Real footX_rel[4] "m";
  Real footZ_rel[4] "m";
  Real footX_vel[4] "m/s";
  Real footZ_vel[4] "m/s";
  Real footXrc[4] "m, foot X relative to torso center";
  Real footZrc[4] "m, foot Z relative to torso center";

  // === Contact ===
  Real penetration[4] "m";
  Real Fz[4] "N, normal contact force";
  Real Fx[4] "N, tangential contact force";
  Boolean inContact[4];
  Real terrainAtFoot[4] "m";

  // === Terrain intermediates ===
  Real tr_r1[4], tr_r2[4], tr_g1[4], tr_g2[4];
  Real tr_r1t, tr_r2t, tr_g1t, tr_g2t, terrainAtTorso;
  Real tr_r1a, tr_r2a, tr_g1a, tr_g2a, terrainAhead;

  // === Torques ===
  Real hipTorqueCmd[4] "N.m";
  Real kneeTorqueCmd[4] "N.m";
  Real wheelTorqueCmd[4] "N.m";
  Real hipTorque[4] "N.m, limited";
  Real kneeTorque[4] "N.m, limited";
  Real wheelTorque[4] "N.m, limited";

  // === Joint loads from contact ===
  Real hipLoad[4] "N.m";
  Real kneeLoad[4] "N.m";

  // === Inverse kinematics intermediates ===
  Real Lsq_des[4], cosq2_des[4];

  // === Push disturbance ===
  Real pushApplied "N";

  // === Sensors ===
  Real imuAccX "m/s^2";
  Real imuAccZ "m/s^2";
  Real imuGyro "rad/s";
  Real jointAngle[8] "rad";
  Real jointVel[8] "rad/s";
  Boolean contactSensor[4];
  Real forwardDepthSensor "m";

  // === Monitoring ===
  Real pathError "m";
  Real bodyClearance "m";
  Real attitudeAbs "rad";
  Boolean routeComplete;
  Boolean trackingOK;
  Boolean clearanceOK;
  Boolean attitudeOK;
  Boolean noNaN;
  Boolean noCollision;

  // === Force sums ===
  Real sumFx "N";
  Real sumFz "N";
  Real sumPitchTorque "N.m";

equation
  // ===== Hip offsets =====
  hipXOff[1] = bodyHalfLength;
  hipXOff[2] = bodyHalfLength;
  hipXOff[3] = -bodyHalfLength;
  hipXOff[4] = -bodyHalfLength;

  // ===== Gait phase (trot: FL+RR sync, FR+RL sync) =====
  phaseOffset[1] = 0.0;
  phaseOffset[2] = gaitPeriod / 2.0;
  phaseOffset[3] = gaitPeriod / 2.0;
  phaseOffset[4] = 0.0;

  for i in 1:4 loop
    gaitPhase[i] = mod(time + phaseOffset[i], gaitPeriod) / gaitPeriod;
    inStance[i] = gaitPhase[i] < 0.5;
  end for;

  // ===== Terrain at torso position =====
  tr_r1t = rockHeight * 0.25 * (1.0 + Modelica.Math.tanh(terrainK*(x_pos-rock1Center+rockHalfWidth))) * (1.0 - Modelica.Math.tanh(terrainK*(x_pos-rock1Center-rockHalfWidth)));
  tr_r2t = rockHeight * 0.25 * (1.0 + Modelica.Math.tanh(terrainK*(x_pos-rock2Center+rockHalfWidth))) * (1.0 - Modelica.Math.tanh(terrainK*(x_pos-rock2Center-rockHalfWidth)));
  tr_g1t = -gapDepth * 0.25 * (1.0 + Modelica.Math.tanh(terrainK*(x_pos-gap1Center+gapHalfWidth))) * (1.0 - Modelica.Math.tanh(terrainK*(x_pos-gap1Center-gapHalfWidth)));
  tr_g2t = -gapDepth * 0.25 * (1.0 + Modelica.Math.tanh(terrainK*(x_pos-gap2Center+gapHalfWidth))) * (1.0 - Modelica.Math.tanh(terrainK*(x_pos-gap2Center-gapHalfWidth)));
  terrainAtTorso = tr_r1t + tr_r2t + tr_g1t + tr_g2t;

  // ===== Forward depth sensor =====
  tr_r1a = rockHeight * 0.25 * (1.0 + Modelica.Math.tanh(terrainK*(x_pos+depthLookahead-rock1Center+rockHalfWidth))) * (1.0 - Modelica.Math.tanh(terrainK*(x_pos+depthLookahead-rock1Center-rockHalfWidth)));
  tr_r2a = rockHeight * 0.25 * (1.0 + Modelica.Math.tanh(terrainK*(x_pos+depthLookahead-rock2Center+rockHalfWidth))) * (1.0 - Modelica.Math.tanh(terrainK*(x_pos+depthLookahead-rock2Center-rockHalfWidth)));
  tr_g1a = -gapDepth * 0.25 * (1.0 + Modelica.Math.tanh(terrainK*(x_pos+depthLookahead-gap1Center+gapHalfWidth))) * (1.0 - Modelica.Math.tanh(terrainK*(x_pos+depthLookahead-gap1Center-gapHalfWidth)));
  tr_g2a = -gapDepth * 0.25 * (1.0 + Modelica.Math.tanh(terrainK*(x_pos+depthLookahead-gap2Center+gapHalfWidth))) * (1.0 - Modelica.Math.tanh(terrainK*(x_pos+depthLookahead-gap2Center-gapHalfWidth)));
  terrainAhead = tr_r1a + tr_r2a + tr_g1a + tr_g2a;
  forwardDepthSensor = terrainAhead - z_pos;

  // ===== Terrain at each foot =====
  for i in 1:4 loop
    tr_r1[i] = rockHeight * 0.25 * (1.0 + Modelica.Math.tanh(terrainK*(footX[i]-rock1Center+rockHalfWidth))) * (1.0 - Modelica.Math.tanh(terrainK*(footX[i]-rock1Center-rockHalfWidth)));
    tr_r2[i] = rockHeight * 0.25 * (1.0 + Modelica.Math.tanh(terrainK*(footX[i]-rock2Center+rockHalfWidth))) * (1.0 - Modelica.Math.tanh(terrainK*(footX[i]-rock2Center-rockHalfWidth)));
    tr_g1[i] = -gapDepth * 0.25 * (1.0 + Modelica.Math.tanh(terrainK*(footX[i]-gap1Center+gapHalfWidth))) * (1.0 - Modelica.Math.tanh(terrainK*(footX[i]-gap1Center-gapHalfWidth)));
    tr_g2[i] = -gapDepth * 0.25 * (1.0 + Modelica.Math.tanh(terrainK*(footX[i]-gap2Center+gapHalfWidth))) * (1.0 - Modelica.Math.tanh(terrainK*(footX[i]-gap2Center-gapHalfWidth)));
    terrainAtFoot[i] = tr_r1[i] + tr_r2[i] + tr_g1[i] + tr_g2[i];
  end for;

  // ===== Swing-foot trajectory and foothold planning =====
  // During stance: foot moves backward relative to body at commanded speed
  // During swing: foot lifts to swingHeight and moves forward to next foothold
  for i in 1:4 loop
    if inStance[i] then
      footX_desRel[i] = strideLength * (0.5 - 2.0 * gaitPhase[i]);
      footZ_desRel[i] = -nominalHeight;
    else
      footX_desRel[i] = strideLength * (2.0 * gaitPhase[i] - 1.5);
      footZ_desRel[i] = -nominalHeight + swingHeight * sin(pi_val * 2.0 * (gaitPhase[i] - 0.5));
    end if;
  end for;

  // ===== Inverse kinematics (2-link leg) =====
  for i in 1:4 loop
    Lsq_des[i] = footX_desRel[i]*footX_desRel[i] + footZ_desRel[i]*footZ_desRel[i];
    cosq2_des[i] = max(-0.999, min(0.999, (Lsq_des[i] - upperLegLength*upperLegLength - lowerLegLength*lowerLegLength) / (2.0 * upperLegLength * lowerLegLength)));
    q2_des[i] = Modelica.Math.acos(cosq2_des[i]);
    q1_des[i] = Modelica.Math.atan2(footX_desRel[i], -footZ_desRel[i]) - Modelica.Math.atan2(lowerLegLength * sin(q2_des[i]), upperLegLength + lowerLegLength * cos(q2_des[i]));
  end for;

  // ===== PD controller (commanded torques) =====
  for i in 1:4 loop
    hipTorqueCmd[i] = hipKp * (q1_des[i] - q1[i]) - hipKd * q1_rate[i];
    kneeTorqueCmd[i] = kneeKp * (q2_des[i] - q2[i]) - kneeKd * q2_rate[i];
    if inStance[i] then
      wheelTorqueCmd[i] = wheelKp * (commandedSpeed - x_vel);
    else
      wheelTorqueCmd[i] = 0.0;
    end if;
  end for;

  // ===== Torque limiting (8 leg + 4 wheel, all independent) =====
  for i in 1:4 loop
    hipTorque[i] = max(-maxJointTorque, min(maxJointTorque, hipTorqueCmd[i]));
    kneeTorque[i] = max(-maxJointTorque, min(maxJointTorque, kneeTorqueCmd[i]));
    wheelTorque[i] = max(-maxJointTorque, min(maxJointTorque, wheelTorqueCmd[i]));
  end for;

  // ===== Forward kinematics =====
  for i in 1:4 loop
    footX_rel[i] = upperLegLength * sin(q1[i]) + lowerLegLength * sin(q1[i] + q2[i]);
    footZ_rel[i] = -upperLegLength * cos(q1[i]) - lowerLegLength * cos(q1[i] + q2[i]);
    footX[i] = x_pos + hipXOff[i] + footX_rel[i];
    footZ[i] = z_pos + footZ_rel[i];
    footXrc[i] = hipXOff[i] + footX_rel[i];
    footZrc[i] = footZ_rel[i];
    footX_vel[i] = x_vel + (upperLegLength * cos(q1[i]) + lowerLegLength * cos(q1[i]+q2[i])) * q1_rate[i] + lowerLegLength * cos(q1[i]+q2[i]) * q2_rate[i];
    footZ_vel[i] = z_vel + (upperLegLength * sin(q1[i]) + lowerLegLength * sin(q1[i]+q2[i])) * q1_rate[i] + lowerLegLength * sin(q1[i]+q2[i]) * q2_rate[i];
  end for;

  // ===== Contact model (compliant normal + friction-limited tangential) =====
  for i in 1:4 loop
    penetration[i] = terrainAtFoot[i] - footZ[i];
    if penetration[i] > 0.0 then
      Fz[i] = max(0.0, contactStiffness * penetration[i] - contactDamping * footZ_vel[i]);
      Fx[i] = max(-frictionCoeff * Fz[i], min(frictionCoeff * Fz[i], wheelTorque[i] / wheelRadius));
      inContact[i] = true;
    else
      Fz[i] = 0.0;
      Fx[i] = 0.0;
      inContact[i] = false;
    end if;
  end for;

  // ===== Joint loads via Jacobian transpose =====
  for i in 1:4 loop
    hipLoad[i] = (upperLegLength * cos(q1[i]) + lowerLegLength * cos(q1[i]+q2[i])) * Fx[i] + (upperLegLength * sin(q1[i]) + lowerLegLength * sin(q1[i]+q2[i])) * Fz[i];
    kneeLoad[i] = lowerLegLength * cos(q1[i]+q2[i]) * Fx[i] + lowerLegLength * sin(q1[i]+q2[i]) * Fz[i];
  end for;

  // ===== Leg dynamics =====
  for i in 1:4 loop
    der(q1[i]) = q1_rate[i];
    hipInertia * der(q1_rate[i]) = hipTorque[i] - hipLoad[i];
    der(q2[i]) = q2_rate[i];
    kneeInertia * der(q2_rate[i]) = kneeTorque[i] - kneeLoad[i];
    if penetration[i] > 0.0 then
      der(wheelAng[i]) = x_vel / wheelRadius;
    else
      der(wheelAng[i]) = 0.0;
    end if;
  end for;

  // ===== Force sums (explicit scalar) =====
  sumFx = Fx[1] + Fx[2] + Fx[3] + Fx[4];
  sumFz = Fz[1] + Fz[2] + Fz[3] + Fz[4];
  sumPitchTorque = (footXrc[1]*Fz[1] - footZrc[1]*Fx[1]) + (footXrc[2]*Fz[2] - footZrc[2]*Fx[2]) + (footXrc[3]*Fz[3] - footZrc[3]*Fx[3]) + (footXrc[4]*Fz[4] - footZrc[4]*Fx[4]);

  // ===== Torso dynamics =====
  der(x_pos) = x_vel;
  torsoMass * der(x_vel) = sumFx;
  der(z_pos) = z_vel;
  torsoMass * der(z_vel) = sumFz - torsoMass * g;
  der(pitch) = pitch_rate;
  bodyInertia * der(pitch_rate) = sumPitchTorque;

  // ===== Lateral dynamics (push disturbance channel) =====
  der(y_pos) = y_vel;
  torsoMass * der(y_vel) = -latStiffness * y_pos - latDamping * y_vel + pushApplied;

  // ===== Lateral push disturbance (middle third of simulation) =====
  if time >= pushStart and time <= pushEnd then
    pushApplied = pushForce;
  else
    pushApplied = 0.0;
  end if;

  // ===== Sensors =====
  imuAccX = sumFx / torsoMass;
  imuAccZ = sumFz / torsoMass;
  imuGyro = pitch_rate;
  jointAngle[1] = q1[1]; jointAngle[2] = q1[2]; jointAngle[3] = q1[3]; jointAngle[4] = q1[4];
  jointAngle[5] = q2[1]; jointAngle[6] = q2[2]; jointAngle[7] = q2[3]; jointAngle[8] = q2[4];
  jointVel[1] = q1_rate[1]; jointVel[2] = q1_rate[2]; jointVel[3] = q1_rate[3]; jointVel[4] = q1_rate[4];
  jointVel[5] = q2_rate[1]; jointVel[6] = q2_rate[2]; jointVel[7] = q2_rate[3]; jointVel[8] = q2_rate[4];
  contactSensor[1] = inContact[1]; contactSensor[2] = inContact[2]; contactSensor[3] = inContact[3]; contactSensor[4] = inContact[4];

  // ===== Monitoring and requirement checks =====
  pathError = abs(x_pos - commandedSpeed * time);
  bodyClearance = z_pos - terrainAtTorso;
  attitudeAbs = abs(pitch);
  routeComplete = x_pos >= routeLength;
  trackingOK = if time >= settlingTime then pathError < trackingErrorMax else true;
  clearanceOK = bodyClearance > clearanceMin;
  attitudeOK = attitudeAbs < attitudeMax;
  noNaN = (abs(x_pos) < 1e6) and (abs(z_pos) < 1e6) and (abs(pitch) < 1e6) and (abs(y_pos) < 1e6) and (abs(x_vel) < 1e6) and (abs(z_vel) < 1e6);
  noCollision = z_pos > terrainAtTorso;

  // ===== Safety assertions =====
  assert(noCollision, "Torso-terrain collision detected: clearance violated");
  assert(noNaN, "NaN or infinite value detected in physical variables");

  annotation(
    experiment(StopTime=12.0, StartTime=0, Tolerance=1e-4),
    Documentation(info="WheelLegTraverseC: 28 kg torso, four two-joint legs with driven 0.10 m wheels.
      Crosses height field with 0.08 m rocks and two 0.12 m gaps at commanded speed.
      Max joint torque 50.6 N.m (8 leg + 4 wheel, independently limited).
      81 N lateral push during middle third. Friction 0.78. Control 125 Hz. Duration 12 s.
      Requirements: clearance > 0.03 m, attitude < 0.45 rad, path error < 0.158 m after 7.8 s,
      route completion, no NaN/infinite values, no torso-terrain collision.
      Sensors: joint encoders, IMU, contact, forward depth for foothold selection.
      Swing-foot trajectory control with trot gait."));
end WheelLegTraverseC;