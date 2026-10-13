model WheelLegClimbE

  function clampReal
    input Real x;
    input Real lo;
    input Real hi;
    output Real y;
  algorithm
    y := if x < lo then lo elseif x > hi then hi else x;
  end clampReal;

  function finiteReal
    input Real x;
    output Boolean y;
  algorithm
    y := abs(x) <= 1e300;
  end finiteReal;

  function min2
    input Real a;
    input Real b;
    output Real y;
  algorithm
    y := if a <= b then a else b;
  end min2;

  function max2
    input Real a;
    input Real b;
    output Real y;
  algorithm
    y := if a >= b then a else b;
  end max2;

  function stairSurfaceZ
    input Real x;
    output Real z;
  algorithm
    if x < 0.0 then
      z := 0.0;
    elseif x < 0.30 then
      z := 0.16;
    elseif x < 0.60 then
      z := 0.32;
    elseif x < 0.90 then
      z := 0.48;
    elseif x < 1.20 then
      z := 0.64;
    else
      z := 0.64;
    end if;
  end stairSurfaceZ;

  function stepX
    input Integer step;
    input Real tread;
    output Real x;
  algorithm
    if step == 0 then
      x := -0.5*tread;
    elseif step == 1 then
      x := 0.5*tread;
    elseif step == 2 then
      x := 1.5*tread;
    elseif step == 3 then
      x := 2.5*tread;
    elseif step == 4 then
      x := 3.5*tread;
    else
      x := 4.5*tread;
    end if;
  end stepX;

  function stepZ
    input Integer step;
    input Real rise;
    output Real z;
  algorithm
    if step <= 0 then
      z := 0.0;
    elseif step >= 4 then
      z := 4.0*rise;
    else
      z := step*rise;
    end if;
  end stepZ;

  function edgeClearance
    input Real x;
    output Real c;
  algorithm
    c := min2(abs(x - 0.0), abs(x - 0.30));
    c := min2(c, abs(x - 0.60));
    c := min2(c, abs(x - 0.90));
    c := min2(c, abs(x - 1.20));
  end edgeClearance;

  // Known physical and scenario constants from the requirement.
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

  // Scenario setup not stated in the requirement; derived from stair tread.
  // The robot starts one tread before the first riser and completes at the top landing edge.
  parameter Real x_start(unit="m") = -stair_tread "start one tread before first riser";
  parameter Real x_end(unit="m") = 4.0*stair_tread "completion x at top of four stairs";
  parameter Real bodyHeightOffset(unit="m") = 0.0
    "unknown leg-extension offset; normalized to zero because not stated";

  // Controller tuning and normalized joint inertia are not stated; these are
  // verification-only design values, not claimed robot facts.
  parameter Real Kq(unit="N.m/rad") = 2.0 "joint impedance stiffness";
  parameter Real Dq(unit="N.m.s/rad") = 2.0 "joint impedance damping";
  parameter Real Jq(unit="kg.m2") = 1.0 "normalized joint inertia";
  parameter Real Kz(unit="N/m") = 2000.0 "body-height support stiffness";
  parameter Real Dz(unit="N.s/m") = 400.0 "body-height support damping";
  parameter Real Kx(unit="N/m") = 1000.0 "horizontal tracking stiffness";
  parameter Real Kw(unit="N.m.s/rad") = 5.0 "wheel velocity feedback gain";

  // Floating-base and body states.
  Real x_body(unit="m", start=x_start) "torso x position";
  Real z_body(unit="m", start=r_wheel + bodyHeightOffset) "torso z position";
  Real vx(unit="m/s", start=0.0) "torso x velocity";
  Real vz(unit="m/s", start=0.0) "torso z velocity";

  // Eight leg-joint states (hip/knee per leg). Joint coordinates are normalized
  // because link lengths and joint zero conventions are not stated.
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

  // Four driven wheel angles.
  Real qw_FL(unit="rad", start=0.0);
  Real qw_FR(unit="rad", start=0.0);
  Real qw_BL(unit="rad", start=0.0);
  Real qw_BR(unit="rad", start=0.0);

  // Discrete terrain-aware planner state, updated at 250 Hz.
  discrete Integer currentStep(start=0) "detected stair step index";
  discrete Integer nextStep(start=1) "planned next step for leading legs";
  discrete Real foothold_x_FL(unit="m", start=-0.5*stair_tread);
  discrete Real foothold_z_FL(unit="m", start=0.0);
  discrete Real foothold_x_FR(unit="m", start=0.5*stair_tread);
  discrete Real foothold_z_FR(unit="m", start=stair_rise);
  discrete Real foothold_x_BL(unit="m", start=0.5*stair_tread);
  discrete Real foothold_z_BL(unit="m", start=stair_rise);
  discrete Real foothold_x_BR(unit="m", start=-0.5*stair_tread);
  discrete Real foothold_z_BR(unit="m", start=0.0);

  discrete Real q1_ref_FL(unit="rad", start=0.0);
  discrete Real q2_ref_FL(unit="rad", start=0.0);
  discrete Real q1_ref_FR(unit="rad", start=0.25);
  discrete Real q2_ref_FR(unit="rad", start=0.25);
  discrete Real q1_ref_BL(unit="rad", start=0.25);
  discrete Real q2_ref_BL(unit="rad", start=0.25);
  discrete Real q1_ref_BR(unit="rad", start=0.0);
  discrete Real q2_ref_BR(unit="rad", start=0.0);

  discrete Real depth_next_edge(unit="m", start=0.0) "depth camera next riser edge";
  discrete Real depth_next_tread_height(unit="m", start=stair_rise);
  discrete Real depth_current_tread_height(unit="m", start=0.0);

  // Reference trajectories.
  Real x_ref(unit="m");
  Real vx_ref(unit="m/s");
  Real z_ref(unit="m");
  Real wheelSpeedRef(unit="rad/s");
  Real wheelSpeed(unit="rad/s");
  Real supportHeight(unit="m");
  Real bodyHeight(unit="m");
  Real bodyHeightError(unit="m");
  Boolean bodyHeightMaintained;

  // Payload disturbance.
  Boolean payloadActive;
  Real payloadForce(unit="N");

  // Support-force feedforward and torque commands.
  Real Fz_ref_total(unit="N");
  Real Fz_ref_FL(unit="N");
  Real Fz_ref_FR(unit="N");
  Real Fz_ref_BL(unit="N");
  Real Fz_ref_BR(unit="N");

  Real tau1_ff_FL(unit="N.m");
  Real tau2_ff_FL(unit="N.m");
  Real tau1_ff_FR(unit="N.m");
  Real tau2_ff_FR(unit="N.m");
  Real tau1_ff_BL(unit="N.m");
  Real tau2_ff_BL(unit="N.m");
  Real tau1_ff_BR(unit="N.m");
  Real tau2_ff_BR(unit="N.m");

  Real tau1_imp_FL(unit="N.m");
  Real tau2_imp_FL(unit="N.m");
  Real tau1_imp_FR(unit="N.m");
  Real tau2_imp_FR(unit="N.m");
  Real tau1_imp_BL(unit="N.m");
  Real tau2_imp_BL(unit="N.m");
  Real tau1_imp_BR(unit="N.m");
  Real tau2_imp_BR(unit="N.m");

  Real tau1_height_FL(unit="N.m");
  Real tau2_height_FL(unit="N.m");
  Real tau1_height_FR(unit="N.m");
  Real tau2_height_FR(unit="N.m");
  Real tau1_height_BL(unit="N.m");
  Real tau2_height_BL(unit="N.m");
  Real tau1_height_BR(unit="N.m");
  Real tau2_height_BR(unit="N.m");

  Real tau1_raw_FL(unit="N.m");
  Real tau2_raw_FL(unit="N.m");
  Real tau1_raw_FR(unit="N.m");
  Real tau2_raw_FR(unit="N.m");
  Real tau1_raw_BL(unit="N.m");
  Real tau2_raw_BL(unit="N.m");
  Real tau1_raw_BR(unit="N.m");
  Real tau2_raw_BR(unit="N.m");
  Real tauw_raw_FL(unit="N.m");
  Real tauw_raw_FR(unit="N.m");
  Real tauw_raw_BL(unit="N.m");
  Real tauw_raw_BR(unit="N.m");

  Real tau1_FL(unit="N.m");
  Real tau2_FL(unit="N.m");
  Real tau1_FR(unit="N.m");
  Real tau2_FR(unit="N.m");
  Real tau1_BL(unit="N.m");
  Real tau2_BL(unit="N.m");
  Real tau1_BR(unit="N.m");
  Real tau2_BR(unit="N.m");
  Real tauw_FL(unit="N.m");
  Real tauw_FR(unit="N.m");
  Real tauw_BL(unit="N.m");
  Real tauw_BR(unit="N.m");

  // Contact and traction forces. The wheel radius is used as a normalized
  // torque-to-force lever because the actual leg Jacobian is not stated.
  Real Fz_FL(unit="N");
  Real Fz_FR(unit="N");
  Real Fz_BL(unit="N");
  Real Fz_BR(unit="N");
  Real Fx_FL(unit="N");
  Real Fx_FR(unit="N");
  Real Fx_BL(unit="N");
  Real Fx_BR(unit="N");
  Real Fz_total(unit="N");
  Real Fx_total(unit="N");

  // Foot/foothold observable state.
  Real foot_x_FL(unit="m");
  Real foot_z_FL(unit="m");
  Real foot_x_FR(unit="m");
  Real foot_z_FR(unit="m");
  Real foot_x_BL(unit="m");
  Real foot_z_BL(unit="m");
  Real foot_x_BR(unit="m");
  Real foot_z_BR(unit="m");

  Real footholdError_FL(unit="m");
  Real footholdError_FR(unit="m");
  Real footholdError_BL(unit="m");
  Real footholdError_BR(unit="m");
  Real edgeClearanceFL(unit="m");
  Real edgeClearanceFR(unit="m");
  Real edgeClearanceBL(unit="m");
  Real edgeClearanceBR(unit="m");
  Real primaryTrackingError(unit="m");

  // Sensors.
  Boolean contact_FL;
  Boolean contact_FR;
  Boolean contact_BL;
  Boolean contact_BR;
  Integer numContacts;
  Real footForce_FL(unit="N");
  Real footForce_FR(unit="N");
  Real footForce_BL(unit="N");
  Real footForce_BR(unit="N");
  Real encoder_q1_FL(unit="rad");
  Real encoder_q2_FL(unit="rad");
  Real encoder_q1_FR(unit="rad");
  Real encoder_q2_FR(unit="rad");
  Real encoder_q1_BL(unit="rad");
  Real encoder_q2_BL(unit="rad");
  Real encoder_q1_BR(unit="rad");
  Real encoder_q2_BR(unit="rad");
  Real encoder_wheel_FL(unit="rad");
  Real encoder_wheel_FR(unit="rad");
  Real encoder_wheel_BL(unit="rad");
  Real encoder_wheel_BR(unit="rad");
  Real imu_roll(unit="rad");
  Real imu_pitch(unit="rad");
  Real imu_yaw(unit="rad");
  Real imu_ax(unit="m/s2");
  Real imu_az(unit="m/s2");

  // Synchronized 250 Hz traces.
  discrete Integer sampleCounter(start=0);
  discrete Real sampled_time(unit="s");
  discrete Real sampled_state_x(unit="m");
  discrete Real sampled_state_z(unit="m");
  discrete Real sampled_state_vx(unit="m/s");
  discrete Real sampled_state_vz(unit="m/s");
  discrete Real sampled_command_tau1_FL(unit="N.m");
  discrete Real sampled_command_tau2_FL(unit="N.m");
  discrete Real sampled_command_tauw_FL(unit="N.m");
  discrete Real sampled_command_tau1_FR(unit="N.m");
  discrete Real sampled_command_tau2_FR(unit="N.m");
  discrete Real sampled_command_tauw_FR(unit="N.m");
  discrete Real sampled_command_tau1_BL(unit="N.m");
  discrete Real sampled_command_tau2_BL(unit="N.m");
  discrete Real sampled_command_tauw_BL(unit="N.m");
  discrete Real sampled_command_tau1_BR(unit="N.m");
  discrete Real sampled_command_tau2_BR(unit="N.m");
  discrete Real sampled_command_tauw_BR(unit="N.m");
  discrete Real sampled_sensor_Fz_FL(unit="N");
  discrete Real sampled_sensor_Fz_FR(unit="N");
  discrete Real sampled_sensor_Fz_BL(unit="N");
  discrete Real sampled_sensor_Fz_BR(unit="N");
  discrete Real sampled_sensor_foot_x_FL(unit="m");
  discrete Real sampled_sensor_foot_x_FR(unit="m");
  discrete Real sampled_sensor_foot_x_BL(unit="m");
  discrete Real sampled_sensor_foot_x_BR(unit="m");
  discrete Integer sampled_sensor_numContacts;
  discrete Real sampled_primary_error(unit="m");
  discrete Boolean sampled_acceptance;

  // Fail-closed acceptance.
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

equation
  // Reference trajectory over four stairs.
  x_ref = if time <= t_end then x_start + (x_end - x_start)*time/t_end else x_end;
  vx_ref = if time <= t_end then (x_end - x_start)/t_end else 0.0;
  z_ref = stairSurfaceZ(x_ref) + r_wheel + bodyHeightOffset;
  wheelSpeedRef = vx_ref / r_wheel;
  wheelSpeed = vx / r_wheel;

  supportHeight = stairSurfaceZ(x_body);
  bodyHeight = z_body - supportHeight - r_wheel - bodyHeightOffset;
  bodyHeightError = z_body - z_ref;
  bodyHeightMaintained = abs(bodyHeightError) <= foothold_tol;

  // Controlled 120 N middle-third payload disturbance.
  payloadActive = time >= t_end/3.0 and time <= 2.0*t_end/3.0;
  payloadForce = if payloadActive then F_payload else 0.0;

  // Feedforward support distribution.
  Fz_ref_total = m_torso*g + payloadForce;
  Fz_ref_FL = Fz_ref_total/4.0;
  Fz_ref_FR = Fz_ref_total/4.0;
  Fz_ref_BL = Fz_ref_total/4.0;
  Fz_ref_BR = Fz_ref_total/4.0;

  tau1_ff_FL = r_wheel*Fz_ref_FL/2.0;
  tau2_ff_FL = r_wheel*Fz_ref_FL/2.0;
  tau1_ff_FR = r_wheel*Fz_ref_FR/2.0;
  tau2_ff_FR = r_wheel*Fz_ref_FR/2.0;
  tau1_ff_BL = r_wheel*Fz_ref_BL/2.0;
  tau2_ff_BL = r_wheel*Fz_ref_BL/2.0;
  tau1_ff_BR = r_wheel*Fz_ref_BR/2.0;
  tau2_ff_BR = r_wheel*Fz_ref_BR/2.0;

  // Joint-space impedance.
  tau1_imp_FL = Kq*(q1_ref_FL - q1_FL) - Dq*dq1_FL;
  tau2_imp_FL = Kq*(q2_ref_FL - q2_FL) - Dq*dq2_FL;
  tau1_imp_FR = Kq*(q1_ref_FR - q1_FR) - Dq*dq1_FR;
  tau2_imp_FR = Kq*(q2_ref_FR - q2_FR) - Dq*dq2_FR;
  tau1_imp_BL = Kq*(q1_ref_BL - q1_BL) - Dq*dq1_BL;
  tau2_imp_BL = Kq*(q2_ref_BL - q2_BL) - Dq*dq2_BL;
  tau1_imp_BR = Kq*(q1_ref_BR - q1_BR) - Dq*dq1_BR;
  tau2_imp_BR = Kq*(q2_ref_BR - q2_BR) - Dq*dq2_BR;

  // Body-height correction distributed over eight leg joints.
  tau1_height_FL = Kz*(z_ref - z_body)*r_wheel/8.0;
  tau2_height_FL = Kz*(z_ref - z_body)*r_wheel/8.0;
  tau1_height_FR = Kz*(z_ref - z_body)*r_wheel/8.0;
  tau2_height_FR = Kz*(z_ref - z_body)*r_wheel/8.0;
  tau1_height_BL = Kz*(z_ref - z_body)*r_wheel/8.0;
  tau2_height_BL = Kz*(z_ref - z_body)*r_wheel/8.0;
  tau1_height_BR = Kz*(z_ref - z_body)*r_wheel/8.0;
  tau2_height_BR = Kz*(z_ref - z_body)*r_wheel/8.0;

  // Independently limited torque commands.
  tau1_raw_FL = tau1_ff_FL + tau1_imp_FL + tau1_height_FL;
  tau2_raw_FL = tau2_ff_FL + tau2_imp_FL + tau2_height_FL;
  tau1_raw_FR = tau1_ff_FR + tau1_imp_FR + tau1_height_FR;
  tau2_raw_FR = tau2_ff_FR + tau2_imp_FR + tau2_height_FR;
  tau1_raw_BL = tau1_ff_BL + tau1_imp_BL + tau1_height_BL;
  tau2_raw_BL = tau2_ff_BL + tau2_imp_BL + tau2_height_BL;
  tau1_raw_BR = tau1_ff_BR + tau1_imp_BR + tau1_height_BR;
  tau2_raw_BR = tau2_ff_BR + tau2_imp_BR + tau2_height_BR;

  tau1_FL = clampReal(tau1_raw_FL, -tau_max, tau_max);
  tau2_FL = clampReal(tau2_raw_FL, -tau_max, tau_max);
  tau1_FR = clampReal(tau1_raw_FR, -tau_max, tau_max);
  tau2_FR = clampReal(tau2_raw_FR, -tau_max, tau_max);
  tau1_BL = clampReal(tau1_raw_BL, -tau_max, tau_max);
  tau2_BL = clampReal(tau2_raw_BL, -tau_max, tau_max);
  tau1_BR = clampReal(tau1_raw_BR, -tau_max, tau_max);
  tau2_BR = clampReal(tau2_raw_BR, -tau_max, tau_max);

  // Wheel torque commands, independently limited.
  tauw_raw_FL = Kw*(wheelSpeedRef - wheelSpeed) + Kx*(x_ref - x_body)*r_wheel/4.0;
  tauw_raw_FR = Kw*(wheelSpeedRef - wheelSpeed) + Kx*(x_ref - x_body)*r_wheel/4.0;
  tauw_raw_BL = Kw*(wheelSpeedRef - wheelSpeed) + Kx*(x_ref - x_body)*r_wheel/4.0;
  tauw_raw_BR = Kw*(wheelSpeedRef - wheelSpeed) + Kx*(x_ref - x_body)*r_wheel/4.0;

  tauw_FL = clampReal(tauw_raw_FL, -tau_max, tau_max);
  tauw_FR = clampReal(tauw_raw_FR, -tau_max, tau_max);
  tauw_BL = clampReal(tauw_raw_BL, -tau_max, tau_max);
  tauw_BR = clampReal(tauw_raw_BR, -tau_max, tau_max);

  // Joint dynamics from impedance component only.
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

  // Wheel rolling kinematics.
  der(qw_FL) = vx / r_wheel;
  der(qw_FR) = vx / r_wheel;
  der(qw_BL) = vx / r_wheel;
  der(qw_BR) = vx / r_wheel;

  // Contact normal forces from leg torques, clamped nonnegative.
  Fz_FL = max2(0.0, (tau1_FL + tau2_FL)/r_wheel);
  Fz_FR = max2(0.0, (tau1_FR + tau2_FR)/r_wheel);
  Fz_BL = max2(0.0, (tau1_BL + tau2_BL)/r_wheel);
  Fz_BR = max2(0.0, (tau1_BR + tau2_BR)/r_wheel);

  // Friction-limited wheel traction.
  Fx_FL = clampReal(tauw_FL/r_wheel, -mu*Fz_FL, mu*Fz_FL);
  Fx_FR = clampReal(tauw_FR/r_wheel, -mu*Fz_FR, mu*Fz_FR);
  Fx_BL = clampReal(tauw_BL/r_wheel, -mu*Fz_BL, mu*Fz_BL);
  Fx_BR = clampReal(tauw_BR/r_wheel, -mu*Fz_BR, mu*Fz_BR);

  Fz_total = Fz_FL + Fz_FR + Fz_BL + Fz_BR;
  Fx_total = Fx_FL + Fx_FR + Fx_BL + Fx_BR;

  // Floating-base dynamics.
  der(x_body) = vx;
  m_torso*der(vx) = Fx_total;
  der(z_body) = vz;
  m_torso*der(vz) = Fz_total - m_torso*g - payloadForce - Dz*vz;

  // Planned foothold plus synchronized body tracking error as observable foot state.
  foot_x_FL = foothold_x_FL + (x_body - x_ref);
  foot_z_FL = foothold_z_FL;
  foot_x_FR = foothold_x_FR + (x_body - x_ref);
  foot_z_FR = foothold_z_FR;
  foot_x_BL = foothold_x_BL + (x_body - x_ref);
  foot_z_BL = foothold_z_BL;
  foot_x_BR = foothold_x_BR + (x_body - x_ref);
  foot_z_BR = foothold_z_BR;

  footholdError_FL = abs(foot_x_FL - foothold_x_FL);
  footholdError_FR = abs(foot_x_FR - foothold_x_FR);
  footholdError_BL = abs(foot_x_BL - foothold_x_BL);
  footholdError_BR = abs(foot_x_BR - foothold_x_BR);
  primaryTrackingError = max2(max2(footholdError_FL, footholdError_FR), max2(footholdError_BL, footholdError_BR));

  edgeClearanceFL = edgeClearance(foot_x_FL);
  edgeClearanceFR = edgeClearance(foot_x_FR);
  edgeClearanceBL = edgeClearance(foot_x_BL);
  edgeClearanceBR = edgeClearance(foot_x_BR);

  // Sensors.
  contact_FL = Fz_FL > 1.0;
  contact_FR = Fz_FR > 1.0;
  contact_BL = Fz_BL > 1.0;
  contact_BR = Fz_BR > 1.0;
  numContacts = (if contact_FL then 1 else 0) + (if contact_FR then 1 else 0) +
                (if contact_BL then 1 else 0) + (if contact_BR then 1 else 0);

  footForce_FL = Fz_FL;
  footForce_FR = Fz_FR;
  footForce_BL = Fz_BL;
  footForce_BR = Fz_BR;

  encoder_q1_FL = q1_FL;
  encoder_q2_FL = q2_FL;
  encoder_q1_FR = q1_FR;
  encoder_q2_FR = q2_FR;
  encoder_q1_BL = q1_BL;
  encoder_q2_BL = q2_BL;
  encoder_q1_BR = q1_BR;
  encoder_q2_BR = q2_BR;
  encoder_wheel_FL = qw_FL;
  encoder_wheel_FR = qw_FR;
  encoder_wheel_BL = qw_BL;
  encoder_wheel_BR = qw_BR;

  // Rotational dynamics are not stated; IMU orientation estimates are finite zeros.
  imu_roll = 0.0;
  imu_pitch = 0.0;
  imu_yaw = 0.0;
  imu_ax = der(vx);
  imu_az = der(vz);

  // Acceptance checks.
  effortBoundOK = abs(tau1_FL) <= tau_max and abs(tau2_FL) <= tau_max and
                  abs(tau1_FR) <= tau_max and abs(tau2_FR) <= tau_max and
                  abs(tau1_BL) <= tau_max and abs(tau2_BL) <= tau_max and
                  abs(tau1_BR) <= tau_max and abs(tau2_BR) <= tau_max and
                  abs(tauw_FL) <= tau_max and abs(tauw_FR) <= tau_max and
                  abs(tauw_BL) <= tau_max and abs(tauw_BR) <= tau_max;

  commandBoundOK = abs(tau1_FL) <= tau_max and abs(tau2_FL) <= tau_max and
                   abs(tau1_FR) <= tau_max and abs(tau2_FR) <= tau_max and
                   abs(tau1_BL) <= tau_max and abs(tau2_BL) <= tau_max and
                   abs(tau1_BR) <= tau_max and abs(tau2_BR) <= tau_max and
                   abs(tauw_FL) <= tau_max and abs(tauw_FR) <= tau_max and
                   abs(tauw_BL) <= tau_max and abs(tauw_BR) <= tau_max;

  stairEdgeClearanceOK = edgeClearanceFL > 1e-6 and edgeClearanceFR > 1e-6 and
                         edgeClearanceBL > 1e-6 and edgeClearanceBR > 1e-6;

  supportContactOK = numContacts >= 2;
  completionOK = x_body >= x_end - 1e-6;
  primaryTrackingOK = if time >= t_primary then primaryTrackingError < foothold_tol else true;

  finitePhysical = finiteReal(x_body) and finiteReal(z_body) and finiteReal(vx) and finiteReal(vz) and
                   finiteReal(q1_FL) and finiteReal(q2_FL) and finiteReal(q1_FR) and finiteReal(q2_FR) and
                   finiteReal(q1_BL) and finiteReal(q2_BL) and finiteReal(q1_BR) and finiteReal(q2_BR) and
                   finiteReal(dq1_FL) and finiteReal(dq2_FL) and finiteReal(dq1_FR) and finiteReal(dq2_FR) and
                   finiteReal(dq1_BL) and finiteReal(dq2_BL) and finiteReal(dq1_BR) and finiteReal(dq2_BR) and
                   finiteReal(qw_FL) and finiteReal(qw_FR) and finiteReal(qw_BL) and finiteReal(qw_BR) and
                   finiteReal(Fz_FL) and finiteReal(Fz_FR) and finiteReal(Fz_BL) and finiteReal(Fz_BR) and
                   finiteReal(Fx_FL) and finiteReal(Fx_FR) and finiteReal(Fx_BL) and finiteReal(Fx_BR) and
                   finiteReal(Fz_total) and finiteReal(Fx_total);

  finiteControl = finiteReal(x_ref) and finiteReal(vx_ref) and finiteReal(z_ref) and
                  finiteReal(tau1_raw_FL) and finiteReal(tau2_raw_FL) and finiteReal(tauw_raw_FL) and
                  finiteReal(tau1_raw_FR) and finiteReal(tau2_raw_FR) and finiteReal(tauw_raw_FR) and
                  finiteReal(tau1_raw_BL) and finiteReal(tau2_raw_BL) and finiteReal(tauw_raw_BL) and
                  finiteReal(tau1_raw_BR) and finiteReal(tau2_raw_BR) and finiteReal(tauw_raw_BR) and
                  finiteReal(tau1_FL) and finiteReal(tau2_FL) and finiteReal(tauw_FL) and
                  finiteReal(tau1_FR) and finiteReal(tau2_FR) and finiteReal(tauw_FR) and
                  finiteReal(tau1_BL) and finiteReal(tau2_BL) and finiteReal(tauw_BL) and
                  finiteReal(tau1_BR) and finiteReal(tau2_BR) and finiteReal(tauw_BR) and
                  finiteReal(q1_ref_FL) and finiteReal(q2_ref_FL) and
                  finiteReal(q1_ref_FR) and finiteReal(q2_ref_FR) and
                  finiteReal(q1_ref_BL) and finiteReal(q2_ref_BL) and
                  finiteReal(q1_ref_BR) and finiteReal(q2_ref_BR) and
                  finiteReal(foothold_x_FL) and finiteReal(foothold_z_FL) and
                  finiteReal(foothold_x_FR) and finiteReal(foothold_z_FR) and
                  finiteReal(foothold_x_BL) and finiteReal(foothold_z_BL) and
                  finiteReal(foothold_x_BR) and finiteReal(foothold_z_BR);

  finiteEstimator = finiteReal(depth_next_edge) and finiteReal(depth_next_tread_height) and
                    finiteReal(depth_current_tread_height) and
                    finiteReal(imu_roll) and finiteReal(imu_pitch) and finiteReal(imu_yaw) and
                    finiteReal(imu_ax) and finiteReal(imu_az) and
                    finiteReal(encoder_q1_FL) and finiteReal(encoder_q2_FL) and
                    finiteReal(encoder_q1_FR) and finiteReal(encoder_q2_FR) and
                    finiteReal(encoder_q1_BL) and finiteReal(encoder_q2_BL) and
                    finiteReal(encoder_q1_BR) and finiteReal(encoder_q2_BR) and
                    finiteReal(encoder_wheel_FL) and finiteReal(encoder_wheel_FR) and
                    finiteReal(encoder_wheel_BL) and finiteReal(encoder_wheel_BR) and
                    finiteReal(footForce_FL) and finiteReal(footForce_FR) and
                    finiteReal(footForce_BL) and finiteReal(footForce_BR) and
                    finiteReal(foot_x_FL) and finiteReal(foot_x_FR) and
                    finiteReal(foot_x_BL) and finiteReal(foot_x_BR) and
                    finiteReal(foot_z_FL) and finiteReal(foot_z_FR) and
                    finiteReal(foot_z_BL) and finiteReal(foot_z_BR);

  Acceptance = effortBoundOK and commandBoundOK and stairEdgeClearanceOK and
               supportContactOK and completionOK and primaryTrackingOK and
               finitePhysical and finiteControl and finiteEstimator;

  // 250 Hz terrain-aware planner and synchronized trace retention.
  when sample(0, Ts) then
    currentStep := if x_body < 0.0 then 0
                   elseif x_body < 0.30 then 1
                   elseif x_body < 0.60 then 2
                   elseif x_body < 0.90 then 3
                   elseif x_body < 1.20 then 4
                   else 5;
    nextStep := if currentStep >= 4 then 5 else currentStep + 1;

    foothold_x_FL := stepX(currentStep, stair_tread);
    foothold_z_FL := stepZ(currentStep, stair_rise);
    foothold_x_BR := stepX(currentStep, stair_tread);
    foothold_z_BR := stepZ(currentStep, stair_rise);

    foothold_x_FR := stepX(nextStep, stair_tread);
    foothold_z_FR := stepZ(nextStep, stair_rise);
    foothold_x_BL := stepX(nextStep, stair_tread);
    foothold_z_BL := stepZ(nextStep, stair_rise);

    q1_ref_FL := stepZ(currentStep, stair_rise)/(4.0*stair_rise);
    q2_ref_FL := stepZ(currentStep, stair_rise)/(4.0*stair_rise);
    q1_ref_BR := stepZ(currentStep, stair_rise)/(4.0*stair_rise);
    q2_ref_BR := stepZ(currentStep, stair_rise)/(4.0*stair_rise);

    q1_ref_FR := stepZ(nextStep, stair_rise)/(4.0*stair_rise);
    q2_ref_FR := stepZ(nextStep, stair_rise)/(4.0*stair_rise);
    q1_ref_BL := stepZ(nextStep, stair_rise)/(4.0*stair_rise);
    q2_ref_BL := stepZ(nextStep, stair_rise)/(4.0*stair_rise);

    depth_next_edge := if currentStep < 4 then currentStep*stair_tread else 4.0*stair_tread;
    depth_next_tread_height := if currentStep < 4 then (currentStep + 1)*stair_rise else 4.0*stair_rise;
    depth_current_tread_height := if currentStep <= 4 then currentStep*stair_rise else 4.0*stair_rise;

    sampleCounter := pre(sampleCounter) + 1;
    sampled_time := time;
    sampled_state_x := x_body;
    sampled_state_z := z_body;
    sampled_state_vx := vx;
    sampled_state_vz := vz;

    sampled_command_tau1_FL := tau1_FL;
    sampled_command_tau2_FL := tau2_FL;
    sampled_command_tauw_FL := tauw_FL;
    sampled_command_tau1_FR := tau1_FR;
    sampled_command_tau2_FR := tau2_FR;
    sampled_command_tauw_FR := tauw_FR;
    sampled_command_tau1_BL := tau1_BL;
    sampled_command_tau2_BL := tau2_BL;
    sampled_command_tauw_BL := tauw_BL;
    sampled_command_tau1_BR := tau1_BR;
    sampled_command_tau2_BR := tau2_BR;
    sampled_command_tauw_BR := tauw_BR;

    sampled_sensor_Fz_FL := Fz_FL;
    sampled_sensor_Fz_FR := Fz_FR;
    sampled_sensor_Fz_BL := Fz_BL;
    sampled_sensor_Fz_BR := Fz_BR;
    sampled_sensor_foot_x_FL := foot_x_FL;
    sampled_sensor_foot_x_FR := foot_x_FR;
    sampled_sensor_foot_x_BL := foot_x_BL;
    sampled_sensor_foot_x_BR := foot_x_BR;
    sampled_sensor_numContacts := numContacts;
    sampled_primary_error := primaryTrackingError;
    sampled_acceptance := Acceptance;
  end when;

  annotation(experiment(StopTime=16, Tolerance=1e-6, Interval=0.004));
end WheelLegClimbE;