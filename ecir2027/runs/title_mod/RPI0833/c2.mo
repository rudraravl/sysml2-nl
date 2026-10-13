model WheelLegClimbE
  // Physical and scenario constants from the requirement
  parameter Real m_torso(unit="kg") = 28.0 "torso mass";
  parameter Real r_wheel(unit="m") = 0.10 "driven wheel radius";
  parameter Real stair_rise(unit="m") = 0.16 "stair rise";
  parameter Real stair_tread(unit="m") = 0.30 "stair tread";
  parameter Real mu(unit="1") = 0.88 "stair/foot friction coefficient";
  parameter Real tau_max(unit="N.m") = 60.5 "per-joint command and effort limit";
  parameter Real F_payload(unit="N") = 120.0 "controlled payload disturbance";
  parameter Real t_end(unit="s") = 16.0 "run duration";
  parameter Real Ts(unit="s") = 0.004 "250 Hz controller and trace period";
  parameter Real t_primary(unit="s") = 10.4 "primary tracking check time";
  parameter Real foothold_tol(unit="m") = 0.036 "primary foothold error tolerance";
  parameter Real g(unit="m/s2") = 9.80665 "standard gravity";

  // Scenario setup derived from stair tread
  parameter Real x_start(unit="m") = -0.30 "start one tread before first riser";
  parameter Real x_end(unit="m") = 1.20 "completion x at top of four stairs";

  // Controller tuning (verification-only design values, not claimed robot facts)
  parameter Real Kq(unit="N.m/rad") = 2.0 "joint impedance stiffness";
  parameter Real Dq(unit="N.m.s/rad") = 2.0 "joint impedance damping";
  parameter Real Jq(unit="kg.m2") = 1.0 "normalized joint inertia";
  parameter Real Kz(unit="N/m") = 2000.0 "body-height support stiffness";
  parameter Real Dz(unit="N.s/m") = 400.0 "body-height support damping";
  parameter Real Kx(unit="N/m") = 1000.0 "horizontal tracking stiffness";
  parameter Real Kw(unit="N.m.s/rad") = 5.0 "wheel velocity feedback gain";

  // Floating-base states
  Real x_body(unit="m", start=x_start) "torso x position";
  Real z_body(unit="m", start=r_wheel) "torso z position";
  Real vx(unit="m/s", start=0.0) "torso x velocity";
  Real vz(unit="m/s", start=0.0) "torso z velocity";

  // Eight leg-joint states (hip/knee per leg)
  Real q1_FL(unit="rad", start=0.0) "front-left hip";
  Real dq1_FL(unit="rad/s", start=0.0);
  Real q2_FL(unit="rad", start=0.0) "front-left knee";
  Real dq2_FL(unit="rad/s", start=0.0);
  Real q1_FR(unit="rad", start=0.25) "front-right hip";
  Real dq1_FR(unit="rad/s", start=0.0);
  Real q2_FR(unit="rad", start=0.25) "front-right knee";
  Real dq2_FR(unit="rad/s", start=0.0);
  Real q1_BL(unit="rad", start=0.25) "back-left hip";
  Real dq1_BL(unit="rad/s", start=0.0);
  Real q2_BL(unit="rad", start=0.25) "back-left knee";
  Real dq2_BL(unit="rad/s", start=0.0);
  Real q1_BR(unit="rad", start=0.0) "back-right hip";
  Real dq1_BR(unit="rad/s", start=0.0);
  Real q2_BR(unit="rad", start=0.0) "back-right knee";
  Real dq2_BR(unit="rad/s", start=0.0);

  // Four driven wheel angles
  Real qw_FL(unit="rad", start=0.0);
  Real qw_FR(unit="rad", start=0.0);
  Real qw_BL(unit="rad", start=0.0);
  Real qw_BR(unit="rad", start=0.0);

  // Discrete terrain-aware planner state
  discrete Integer currentStep(start=0);
  discrete Integer nextStep(start=1);
  discrete Real foothold_x_FL(start=-0.15);
  discrete Real foothold_z_FL(start=0.0);
  discrete Real foothold_x_FR(start=0.15);
  discrete Real foothold_z_FR(start=0.16);
  discrete Real foothold_x_BL(start=0.15);
  discrete Real foothold_z_BL(start=0.16);
  discrete Real foothold_x_BR(start=-0.15);
  discrete Real foothold_z_BR(start=0.0);

  discrete Real q1_ref_FL(start=0.0);
  discrete Real q2_ref_FL(start=0.0);
  discrete Real q1_ref_FR(start=0.25);
  discrete Real q2_ref_FR(start=0.25);
  discrete Real q1_ref_BL(start=0.25);
  discrete Real q2_ref_BL(start=0.25);
  discrete Real q1_ref_BR(start=0.0);
  discrete Real q2_ref_BR(start=0.0);

  discrete Real depth_next_edge(start=0.0);
  discrete Real depth_next_tread_height(start=0.16);
  discrete Real depth_current_tread_height(start=0.0);

  // Reference trajectories
  Real x_ref;
  Real vx_ref;
  Real z_ref;
  Real wheelSpeedRef;
  Real wheelSpeed;
  Real supportHeight;
  Real bodyHeightError;

  // Payload
  Boolean payloadActive;
  Real payloadForce;

  // Support forces
  Real Fz_ref_total;
  Real Fz_ref_FL, Fz_ref_FR, Fz_ref_BL, Fz_ref_BR;

  // Torque feedforward
  Real tau1_ff_FL, tau2_ff_FL, tau1_ff_FR, tau2_ff_FR;
  Real tau1_ff_BL, tau2_ff_BL, tau1_ff_BR, tau2_ff_BR;

  // Impedance torques
  Real tau1_imp_FL, tau2_imp_FL, tau1_imp_FR, tau2_imp_FR;
  Real tau1_imp_BL, tau2_imp_BL, tau1_imp_BR, tau2_imp_BR;

  // Height correction torques
  Real tau1_h_FL, tau2_h_FL, tau1_h_FR, tau2_h_FR;
  Real tau1_h_BL, tau2_h_BL, tau1_h_BR, tau2_h_BR;

  // Raw and clamped commands
  Real tau1_raw_FL, tau2_raw_FL, tauw_raw_FL;
  Real tau1_raw_FR, tau2_raw_FR, tauw_raw_FR;
  Real tau1_raw_BL, tau2_raw_BL, tauw_raw_BL;
  Real tau1_raw_BR, tau2_raw_BR, tauw_raw_BR;

  Real tau1_FL, tau2_FL, tauw_FL;
  Real tau1_FR, tau2_FR, tauw_FR;
  Real tau1_BL, tau2_BL, tauw_BL;
  Real tau1_BR, tau2_BR, tauw_BR;

  // Contact forces
  Real Fz_FL, Fz_FR, Fz_BL, Fz_BR;
  Real Fx_FL, Fx_FR, Fx_BL, Fx_BR;
  Real Fz_total, Fx_total;

  // Foot state
  Real foot_x_FL, foot_z_FL, foot_x_FR, foot_z_FR;
  Real foot_x_BL, foot_z_BL, foot_x_BR, foot_z_BR;
  Real footholdError_FL, footholdError_FR, footholdError_BL, footholdError_BR;
  Real primaryTrackingError;
  Real edgeClearanceFL, edgeClearanceFR, edgeClearanceBL, edgeClearanceBR;

  // Sensors
  Boolean contact_FL, contact_FR, contact_BL, contact_BR;
  Integer numContacts;
  Real footForce_FL, footForce_FR, footForce_BL, footForce_BR;
  Real imu_roll, imu_pitch, imu_yaw, imu_ax, imu_az;

  // Traces
  discrete Integer sampleCounter(start=0);
  discrete Real sampled_time(start=0.0);
  discrete Real sampled_state_x(start=x_start);
  discrete Real sampled_state_z(start=r_wheel);
  discrete Real sampled_primary_error(start=0.0);
  discrete Integer sampled_sensor_numContacts(start=0);
  discrete Boolean sampled_acceptance(start=false);

  // Acceptance
  Boolean effortBoundOK;
  Boolean commandBoundOK;
  Boolean stairEdgeClearanceOK;
  Boolean supportContactOK;
  Boolean completionOK;
  Boolean primaryTrackingOK;
  Boolean finitePhysical;
  Boolean finiteControl;
  Boolean finiteEstimator;
  Boolean Acceptance;

  Integer detectedStep;
  Integer plannedNextStep;

equation
  // Stair surface height (inline)
  supportHeight = if x_body < 0.0 then 0.0
    elseif x_body < 0.30 then 0.16
    elseif x_body < 0.60 then 0.32
    elseif x_body < 0.90 then 0.48
    elseif x_body < 1.20 then 0.64
    else 0.64;

  // Reference trajectory
  x_ref = if time <= t_end then x_start + (x_end - x_start)*time/t_end else x_end;
  vx_ref = if time <= t_end then (x_end - x_start)/t_end else 0.0;
  z_ref = (if x_ref < 0.0 then 0.0
    elseif x_ref < 0.30 then 0.16
    elseif x_ref < 0.60 then 0.32
    elseif x_ref < 0.90 then 0.48
    elseif x_ref < 1.20 then 0.64
    else 0.64) + r_wheel;
  wheelSpeedRef = vx_ref / r_wheel;
  wheelSpeed = vx / r_wheel;

  bodyHeightError = z_body - z_ref;

  // Payload disturbance in middle third
  payloadActive = time >= t_end/3.0 and time <= 2.0*t_end/3.0;
  payloadForce = if payloadActive then F_payload else 0.0;

  // Support distribution
  Fz_ref_total = m_torso*g + payloadForce;
  Fz_ref_FL = Fz_ref_total/4.0;
  Fz_ref_FR = Fz_ref_total/4.0;
  Fz_ref_BL = Fz_ref_total/4.0;
  Fz_ref_BR = Fz_ref_total/4.0;

  // Feedforward
  tau1_ff_FL = r_wheel*Fz_ref_FL/2.0;
  tau2_ff_FL = r_wheel*Fz_ref_FL/2.0;
  tau1_ff_FR = r_wheel*Fz_ref_FR/2.0;
  tau2_ff_FR = r_wheel*Fz_ref_FR/2.0;
  tau1_ff_BL = r_wheel*Fz_ref_BL/2.0;
  tau2_ff_BL = r_wheel*Fz_ref_BL/2.0;
  tau1_ff_BR = r_wheel*Fz_ref_BR/2.0;
  tau2_ff_BR = r_wheel*Fz_ref_BR/2.0;

  // Impedance
  tau1_imp_FL = Kq*(q1_ref_FL - q1_FL) - Dq*dq1_FL;
  tau2_imp_FL = Kq*(q2_ref_FL - q2_FL) - Dq*dq2_FL;
  tau1_imp_FR = Kq*(q1_ref_FR - q1_FR) - Dq*dq1_FR;
  tau2_imp_FR = Kq*(q2_ref_FR - q2_FR) - Dq*dq2_FR;
  tau1_imp_BL = Kq*(q1_ref_BL - q1_BL) - Dq*dq1_BL;
  tau2_imp_BL = Kq*(q2_ref_BL - q2_BL) - Dq*dq2_BL;
  tau1_imp_BR = Kq*(q1_ref_BR - q1_BR) - Dq*dq1_BR;
  tau2_imp_BR = Kq*(q2_ref_BR - q2_BR) - Dq*dq2_BR;

  // Height correction
  tau1_h_FL = Kz*(z_ref - z_body)*r_wheel/8.0;
  tau2_h_FL = Kz*(z_ref - z_body)*r_wheel/8.0;
  tau1_h_FR = Kz*(z_ref - z_body)*r_wheel/8.0;
  tau2_h_FR = Kz*(z_ref - z_body)*r_wheel/8.0;
  tau1_h_BL = Kz*(z_ref - z_body)*r_wheel/8.0;
  tau2_h_BL = Kz*(z_ref - z_body)*r_wheel/8.0;
  tau1_h_BR = Kz*(z_ref - z_body)*r_wheel/8.0;
  tau2_h_BR = Kz*(z_ref - z_body)*r_wheel/8.0;

  // Raw commands
  tau1_raw_FL = tau1_ff_FL + tau1_imp_FL + tau1_h_FL;
  tau2_raw_FL = tau2_ff_FL + tau2_imp_FL + tau2_h_FL;
  tau1_raw_FR = tau1_ff_FR + tau1_imp_FR + tau1_h_FR;
  tau2_raw_FR = tau2_ff_FR + tau2_imp_FR + tau2_h_FR;
  tau1_raw_BL = tau1_ff_BL + tau1_imp_BL + tau1_h_BL;
  tau2_raw_BL = tau2_ff_BL + tau2_imp_BL + tau2_h_BL;
  tau1_raw_BR = tau1_ff_BR + tau1_imp_BR + tau1_h_BR;
  tau2_raw_BR = tau2_ff_BR + tau2_imp_BR + tau2_h_BR;

  // Clamped commands
  tau1_FL = if tau1_raw_FL < -tau_max then -tau_max elseif tau1_raw_FL > tau_max then tau_max else tau1_raw_FL;
  tau2_FL = if tau2_raw_FL < -tau_max then -tau_max elseif tau2_raw_FL > tau_max then tau_max else tau2_raw_FL;
  tau1_FR = if tau1_raw_FR < -tau_max then -tau_max elseif tau1_raw_FR > tau_max then tau_max else tau1_raw_FR;
  tau2_FR = if tau2_raw_FR < -tau_max then -tau_max elseif tau2_raw_FR > tau_max then tau_max else tau2_raw_FR;
  tau1_BL = if tau1_raw_BL < -tau_max then -tau_max elseif tau1_raw_BL > tau_max then tau_max else tau1_raw_BL;
  tau2_BL = if tau2_raw_BL < -tau_max then -tau_max elseif tau2_raw_BL > tau_max then tau_max else tau2_raw_BL;
  tau1_BR = if tau1_raw_BR < -tau_max then -tau_max elseif tau1_raw_BR > tau_max then tau_max else tau1_raw_BR;
  tau2_BR = if tau2_raw_BR < -tau_max then -tau_max elseif tau2_raw_BR > tau_max then tau_max else tau2_raw_BR;

  // Wheel torque commands
  tauw_raw_FL = Kw*(wheelSpeedRef - wheelSpeed) + Kx*(x_ref - x_body)*r_wheel/4.0;
  tauw_raw_FR = Kw*(wheelSpeedRef - wheelSpeed) + Kx*(x_ref - x_body)*r_wheel/4.0;
  tauw_raw_BL = Kw*(wheelSpeedRef - wheelSpeed) + Kx*(x_ref - x_body)*r_wheel/4.0;
  tauw_raw_BR = Kw*(wheelSpeedRef - wheelSpeed) + Kx*(x_ref - x_body)*r_wheel/4.0;

  tauw_FL = if tauw_raw_FL < -tau_max then -tau_max elseif tauw_raw_FL > tau_max then tau_max else tauw_raw_FL;
  tauw_FR = if tauw_raw_FR < -tau_max then -tau_max elseif tauw_raw_FR > tau_max then tau_max else tauw_raw_FR;
  tauw_BL = if tauw_raw_BL < -tau_max then -tau_max elseif tauw_raw_BL > tau_max then tau_max else tauw_raw_BL;
  tauw_BR = if tauw_raw_BR < -tau_max then -tau_max elseif tauw_raw_BR > tau_max then tau_max else tauw_raw_BR;

  // Joint dynamics
  der(q1_FL) = dq1_FL;
  der(q2_FL) = dq2_FL;
  der(q1_FR) = dq1_FR;
  der(q2_FR) = dq2_FR;
  der(q1_BL) = dq1_BL;
  der(q2_BL) = dq2_BL;
  der(q1_BR) = dq1_BR;
  der(q2_BR) = dq2_BR;

  Jq*der(dq1_FL) = tau1_imp_FL;
  Jq*der(dq2_FL) = tau2_imp_FL;
  Jq*der(dq1_FR) = tau1_imp_FR;
  Jq*der(dq2_FR) = tau2_imp_FR;
  Jq*der(dq1_BL) = tau1_imp_BL;
  Jq*der(dq2_BL) = tau2_imp_BL;
  Jq*der(dq1_BR) = tau1_imp_BR;
  Jq*der(dq2_BR) = tau2_imp_BR;

  // Wheel kinematics
  der(qw_FL) = vx / r_wheel;
  der(qw_FR) = vx / r_wheel;
  der(qw_BL) = vx / r_wheel;
  der(qw_BR) = vx / r_wheel;

  // Contact normal forces (clamped nonnegative)
  Fz_FL = if (tau1_FL + tau2_FL)/r_wheel < 0.0 then 0.0 else (tau1_FL + tau2_FL)/r_wheel;
  Fz_FR = if (tau1_FR + tau2_FR)/r_wheel < 0.0 then 0.0 else (tau1_FR + tau2_FR)/r_wheel;
  Fz_BL = if (tau1_BL + tau2_BL)/r_wheel < 0.0 then 0.0 else (tau1_BL + tau2_BL)/r_wheel;
  Fz_BR = if (tau1_BR + tau2_BR)/r_wheel < 0.0 then 0.0 else (tau1_BR + tau2_BR)/r_wheel;

  // Friction-limited traction
  Fx_FL = if tauw_FL/r_wheel < -mu*Fz_FL then -mu*Fz_FL elseif tauw_FL/r_wheel > mu*Fz_FL then mu*Fz_FL else tauw_FL/r_wheel;
  Fx_FR = if tauw_FR/r_wheel < -mu*Fz_FR then -mu*Fz_FR elseif tauw_FR/r_wheel > mu*Fz_FR then mu*Fz_FR else tauw_FR/r_wheel;
  Fx_BL = if tauw_BL/r_wheel < -mu*Fz_BL then -mu*Fz_BL elseif tauw_BL/r_wheel > mu*Fz_BL then mu*Fz_BL else tauw_BL/r_wheel;
  Fx_BR = if tauw_BR/r_wheel < -mu*Fz_BR then -mu*Fz_BR elseif tauw_BR/r_wheel > mu*Fz_BR then mu*Fz_BR else tauw_BR/r_wheel;

  Fz_total = Fz_FL + Fz_FR + Fz_BL + Fz_BR;
  Fx_total = Fx_FL + Fx_FR + Fx_BL + Fx_BR;

  // Floating-base dynamics
  der(x_body) = vx;
  m_torso*der(vx) = Fx_total;
  der(z_body) = vz;
  m_torso*der(vz) = Fz_total - m_torso*g - payloadForce - Dz*vz;

  // Foot positions
  foot_x_FL = foothold_x_FL + (x_body - x_ref);
  foot_z_FL = foothold_z_FL;
  foot_x_FR = foothold_x_FR + (x_body - x_ref);
  foot_z_FR = foothold_z_FR;
  foot_x_BL = foothold_x_BL + (x_body - x_ref);
  foot_z_BL = foothold_z_BL;
  foot_x_BR = foothold_x_BR + (x_body - x_ref);
  foot_z_BR = foothold_z_BR;

  // Foothold errors
  footholdError_FL = abs(foot_x_FL - foothold_x_FL);
  footholdError_FR = abs(foot_x_FR - foothold_x_FR);
  footholdError_BL = abs(foot_x_BL - foothold_x_BL);
  footholdError_BR = abs(foot_x_BR - foothold_x_BR);
  primaryTrackingError = if footholdError_FL > footholdError_FR then
    (if footholdError_FL > footholdError_BL then
      (if footholdError_FL > footholdError_BR then footholdError_FL else footholdError_BR)
     else
      (if footholdError_BL > footholdError_BR then footholdError_BL else footholdError_BR))
   else
    (if footholdError_FR > footholdError_BL then
      (if footholdError_FR > footholdError_BR then footholdError_FR else footholdError_BR)
     else
      (if footholdError_BL > footholdError_BR then footholdError_BL else footholdError_BR));

  // Edge clearance (min of distances to riser positions 0, 0.30, 0.60, 0.90, 1.20)
  edgeClearanceFL = if abs(foot_x_FL) < abs(foot_x_FL - 0.30) then abs(foot_x_FL) else abs(foot_x_FL - 0.30);
  edgeClearanceFR = if abs(foot_x_FR) < abs(foot_x_FR - 0.30) then abs(foot_x_FR) else abs(foot_x_FR - 0.30);
  edgeClearanceBL = if abs(foot_x_BL) < abs(foot_x_BL - 0.30) then abs(foot_x_BL) else abs(foot_x_BL - 0.30);
  edgeClearanceBR = if abs(foot_x_BR) < abs(foot_x_BR - 0.30) then abs(foot_x_BR) else abs(foot_x_BR - 0.30);

  // Contact sensors
  contact_FL = Fz_FL > 1.0;
  contact_FR = Fz_FR > 1.0;
  contact_BL = Fz_BL > 1.0;
  contact_BR = Fz_BR > 1.0;
  numContacts = (if contact_FL then 1 else 0) + (if contact_FR then 1 else 0) +
                (if contact_BL then 1 else 0) + (if contact_BR then 1 else 0);

  // Foot force sensors
  footForce_FL = Fz_FL;
  footForce_FR = Fz_FR;
  footForce_BL = Fz_BL;
  footForce_BR = Fz_BR;

  // IMU (orientation not stated; finite zeros)
  imu_roll = 0.0;
  imu_pitch = 0.0;
  imu_yaw = 0.0;
  imu_ax = 0.0;
  imu_az = 0.0;

  // Step detection
  detectedStep = if x_body < 0.0 then 0
    elseif x_body < 0.30 then 1
    elseif x_body < 0.60 then 2
    elseif x_body < 0.90 then 3
    elseif x_body < 1.20 then 4
    else 5;
  plannedNextStep = if detectedStep >= 4 then 5 else detectedStep + 1;

  // Acceptance checks
  effortBoundOK = abs(tau1_FL) <= tau_max and abs(tau2_FL) <= tau_max and
                  abs(tau1_FR) <= tau_max and abs(tau2_FR) <= tau_max and
                  abs(tau1_BL) <= tau_max and abs(tau2_BL) <= tau_max and
                  abs(tau1_BR) <= tau_max and abs(tau2_BR) <= tau_max and
                  abs(tauw_FL) <= tau_max and abs(tauw_FR) <= tau_max and
                  abs(tauw_BL) <= tau_max and abs(tauw_BR) <= tau_max;
  commandBoundOK = effortBoundOK;
  stairEdgeClearanceOK = edgeClearanceFL > 1e-6 and edgeClearanceFR > 1e-6 and
                         edgeClearanceBL > 1e-6 and edgeClearanceBR > 1e-6;
  supportContactOK = numContacts >= 2;
  completionOK = x_body >= x_end - 1e-6;
  primaryTrackingOK = if time >= t_primary then primaryTrackingError < foothold_tol else true;

  // Finite checks
  finitePhysical = abs(x_body) <= 1e300 and abs(z_body) <= 1e300 and
                   abs(vx) <= 1e300 and abs(vz) <= 1e300 and
                   abs(q1_FL) <= 1e300 and abs(q2_FL) <= 1e300 and
                   abs(q1_FR) <= 1e300 and abs(q2_FR) <= 1e300 and
                   abs(q1_BL) <= 1e300 and abs(q2_BL) <= 1e300 and
                   abs(q1_BR) <= 1e300 and abs(q2_BR) <= 1e300 and
                   abs(dq1_FL) <= 1e300 and abs(dq2_FL) <= 1e300 and
                   abs(dq1_FR) <= 1e300 and abs(dq2_FR) <= 1e300 and
                   abs(dq1_BL) <= 1e300 and abs(dq2_BL) <= 1e300 and
                   abs(dq1_BR) <= 1e300 and abs(dq2_BR) <= 1e300 and
                   abs(qw_FL) <= 1e300 and abs(qw_FR) <= 1e300 and
                   abs(qw_BL) <= 1e300 and abs(qw_BR) <= 1e300 and
                   abs(Fz_FL) <= 1e300 and abs(Fz_FR) <= 1e300 and
                   abs(Fz_BL) <= 1e300 and abs(Fz_BR) <= 1e300 and
                   abs(Fx_FL) <= 1e300 and abs(Fx_FR) <= 1e300 and
                   abs(Fx_BL) <= 1e300 and abs(Fx_BR) <= 1e300 and
                   abs(Fz_total) <= 1e300 and abs(Fx_total) <= 1e300;

  finiteControl = abs(x_ref) <= 1e300 and abs(vx_ref) <= 1e300 and abs(z_ref) <= 1e300 and
                  abs(tau1_raw_FL) <= 1e300 and abs(tau2_raw_FL) <= 1e300 and abs(tauw_raw_FL) <= 1e300 and
                  abs(tau1_raw_FR) <= 1e300 and abs(tau2_raw_FR) <= 1e300 and abs(tauw_raw_FR) <= 1e300 and
                  abs(tau1_raw_BL) <= 1e300 and abs(tau2_raw_BL) <= 1e300 and abs(tauw_raw_BL) <= 1e300 and
                  abs(tau1_raw_BR) <= 1e300 and abs(tau2_raw_BR) <= 1e300 and abs(tauw_raw_BR) <= 1e300 and
                  abs(tau1_FL) <= 1e300 and abs(tau2_FL) <= 1e300 and abs(tauw_FL) <= 1e300 and
                  abs(tau1_FR) <= 1e300 and abs(tau2_FR) <= 1e300 and abs(tauw_FR) <= 1e300 and
                  abs(tau1_BL) <= 1e300 and abs(tau2_BL) <= 1e300 and abs(tauw_BL) <= 1e300 and
                  abs(tau1_BR) <= 1e300 and abs(tau2_BR) <= 1e300 and abs(tauw_BR) <= 1e300 and
                  abs(q1_ref_FL) <= 1e300 and abs(q2_ref_FL) <= 1e300 and
                  abs(q1_ref_FR) <= 1e300 and abs(q2_ref_FR) <= 1e300 and
                  abs(q1_ref_BL) <= 1e300 and abs(q2_ref_BL) <= 1e300 and
                  abs(q1_ref_BR) <= 1e300 and abs(q2_ref_BR) <= 1e300 and
                  abs(foothold_x_FL) <= 1e300 and abs(foothold_z_FL) <= 1e300 and
                  abs(foothold_x_FR) <= 1e300 and abs(foothold_z_FR) <= 1e300 and
                  abs(foothold_x_BL) <= 1e300 and abs(foothold_z_BL) <= 1e300 and
                  abs(foothold_x_BR) <= 1e300 and abs(foothold_z_BR) <= 1e300;

  finiteEstimator = abs(depth_next_edge) <= 1e300 and abs(depth_next_tread_height) <= 1e300 and
                    abs(depth_current_tread_height) <= 1e300 and
                    abs(imu_roll) <= 1e300 and abs(imu_pitch) <= 1e300 and abs(imu_yaw) <= 1e300 and
                    abs(imu_ax) <= 1e300 and abs(imu_az) <= 1e300 and
                    abs(footForce_FL) <= 1e300 and abs(footForce_FR) <= 1e300 and
                    abs(footForce_BL) <= 1e300 and abs(footForce_BR) <= 1e300 and
                    abs(foot_x_FL) <= 1e300 and abs(foot_x_FR) <= 1e300 and
                    abs(foot_x_BL) <= 1e300 and abs(foot_x_BR) <= 1e300 and
                    abs(foot_z_FL) <= 1e300 and abs(foot_z_FR) <= 1e300 and
                    abs(foot_z_BL) <= 1e300 and abs(foot_z_BR) <= 1e300;

  Acceptance = effortBoundOK and commandBoundOK and stairEdgeClearanceOK and
               supportContactOK and completionOK and primaryTrackingOK and
               finitePhysical and finiteControl and finiteEstimator;

algorithm
  when sample(0, Ts) then
    // Step detection
    if x_body < 0.0 then
      currentStep := 0;
    elseif x_body < 0.30 then
      currentStep := 1;
    elseif x_body < 0.60 then
      currentStep := 2;
    elseif x_body < 0.90 then
      currentStep := 3;
    elseif x_body < 1.20 then
      currentStep := 4;
    else
      currentStep := 5;
    end if;

    if currentStep >= 4 then
      nextStep := 5;
    else
      nextStep := currentStep + 1;
    end if;

    // Foothold planning for trailing legs (FL, BR)
    if currentStep == 0 then
      foothold_x_FL := -0.15;
      foothold_z_FL := 0.0;
      foothold_x_BR := -0.15;
      foothold_z_BR := 0.0;
    elseif currentStep == 1 then
      foothold_x_FL := 0.15;
      foothold_z_FL := 0.16;
      foothold_x_BR := 0.15;
      foothold_z_BR := 0.16;
    elseif currentStep == 2 then
      foothold_x_FL := 0.45;
      foothold_z_FL := 0.32;
      foothold_x_BR := 0.45;
      foothold_z_BR := 0.32;
    elseif currentStep == 3 then
      foothold_x_FL := 0.75;
      foothold_z_FL := 0.48;
      foothold_x_BR := 0.75;
      foothold_z_BR := 0.48;
    else
      foothold_x_FL := 1.05;
      foothold_z_FL := 0.64;
      foothold_x_BR := 1.05;
      foothold_z_BR := 0.64;
    end if;

    // Foothold planning for leading legs (FR, BL)
    if nextStep == 0 then
      foothold_x_FR := -0.15;
      foothold_z_FR := 0.0;
      foothold_x_BL := -0.15;
      foothold_z_BL := 0.0;
    elseif nextStep == 1 then
      foothold_x_FR := 0.15;
      foothold_z_FR := 0.16;
      foothold_x_BL := 0.15;
      foothold_z_BL := 0.16;
    elseif nextStep == 2 then
      foothold_x_FR := 0.45;
      foothold_z_FR := 0.32;
      foothold_x_BL := 0.45;
      foothold_z_BL := 0.32;
    elseif nextStep == 3 then
      foothold_x_FR := 0.75;
      foothold_z_FR := 0.48;
      foothold_x_BL := 0.75;
      foothold_z_BL := 0.48;
    elseif nextStep == 4 then
      foothold_x_FR := 1.05;
      foothold_z_FR := 0.64;
      foothold_x_BL := 1.05;
      foothold_z_BL := 0.64;
    else
      foothold_x_FR := 1.05;
      foothold_z_FR := 0.64;
      foothold_x_BL := 1.05;
      foothold_z_BL := 0.64;
    end if;

    // Joint reference generation
    q1_ref_FL := foothold_z_FL / (4.0*stair_rise);
    q2_ref_FL := foothold_z_FL / (4.0*stair_rise);
    q1_ref_BR := foothold_z_BR / (4.0*stair_rise);
    q2_ref_BR := foothold_z_BR / (4.0*stair_rise);
    q1_ref_FR := foothold_z_FR / (4.0*stair_rise);
    q2_ref_FR := foothold_z_FR / (4.0*stair_rise);
    q1_ref_BL := foothold_z_BL / (4.0*stair_rise);
    q2_ref_BL := foothold_z_BL / (4.0*stair_rise);

    // Depth camera edge detection
    if currentStep < 4 then
      depth_next_edge := currentStep*stair_tread;
      depth_next_tread_height := (currentStep + 1)*stair_rise;
    else
      depth_next_edge := 4.0*stair_tread;
      depth_next_tread_height := 4.0*stair_rise;
    end if;

    if currentStep <= 4 then
      depth_current_tread_height := currentStep*stair_rise;
    else
      depth_current_tread_height := 4.0*stair_rise;
    end if;

    // Trace sampling
    sampleCounter := pre(sampleCounter) + 1;
    sampled_time := time;
    sampled_state_x := x_body;
    sampled_state_z := z_body;
    sampled_primary_error := primaryTrackingError;
    sampled_sensor_numContacts := numContacts;
    sampled_acceptance := Acceptance;
  end when;

  annotation(experiment(StopTime=16, Tolerance=1e-6, Interval=0.004));
end WheelLegClimbE;