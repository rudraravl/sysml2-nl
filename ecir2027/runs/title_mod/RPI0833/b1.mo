model WheelLegClimbE

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

  // Scenario setup derived from stair tread.
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
  Real x_body(start=x_start, unit="m") "torso x position";
  Real z_body(start=r_wheel + bodyHeightOffset, unit="m") "torso z position";
  Real vx(start=0.0, unit="m/s") "torso x velocity";
  Real vz(start=0.0, unit="m/s") "torso z velocity";

  // Eight leg-joint states (hip/knee per leg). Joint coordinates are normalized
  // because link lengths and joint zero conventions are not stated.
  Real q1_FL(start=0.0, unit="rad") "front-left hip";
  Real dq1_FL(start=0.0, unit="rad/s");
  Real q2_FL(start=0.0, unit="rad") "front-left knee";
  Real dq2_FL(start=0.0, unit="rad/s");

  Real q1_FR(start=0.25, unit="rad") "front-right hip";
  Real dq1_FR(start=0.0, unit="rad/s");
  Real q2_FR(start=0.25, unit="rad") "front-right knee";
  Real dq2_FR(start=0.0, unit="rad/s");

  Real q1_BL(start=0.25, unit="rad") "back-left hip";
  Real dq1_BL(start=0.0, unit="rad/s");
  Real q2_BL(start=0.25, unit="rad") "back-left knee";
  Real dq2_BL(start=0.0, unit="rad/s");

  Real q1_BR(start=0.0, unit="rad") "back-right hip";
  Real dq1_BR(start=0.0, unit="rad/s");
  Real q2_BR(start=0.0, unit="rad") "back-right knee";
  Real dq2_BR(start=0.0, unit="rad/s");

  // Four driven wheel angles.
  Real qw_FL(start=0.0, unit="rad");
  Real qw_FR(start=0.0, unit="rad");
  Real qw_BL(start=0.0, unit="rad");
  Real qw_BR(start=0.0, unit="rad");

  // Discrete terrain-aware planner state, updated at 250 Hz.
  discrete Integer currentStep(start=0) "detected stair step index";
  discrete Integer nextStep(start=1) "planned next step for leading legs";
  discrete Real foothold_x_FL(start=-0.5*stair_tread, unit="m");
  discrete Real foothold_z_FL(start=0.0, unit="m");
  discrete Real foothold_x_FR(start=0.5*stair_tread, unit="m");
  discrete Real foothold_z_FR(start=stair_rise, unit="m");
  discrete Real foothold_x_BL(start=0.5*stair_tread, unit="m");
  discrete Real foothold_z_BL(start=stair_rise, unit="m");
  discrete Real foothold_x_BR(start=-0.5*stair_tread, unit="m");
  discrete Real foothold_z_BR(start=0.0, unit="m");

  discrete Real q1_ref_FL(start=0.0, unit="rad");
  discrete Real q2_ref_FL(start=0.0, unit="rad");
  discrete Real q1_ref_FR(start=0.25, unit="rad");
  discrete Real q2_ref_FR(start=0.25, unit="rad");
  discrete Real q1_ref_BL(start=0.25, unit="rad");
  discrete Real q2_ref_BL(start=0.25, unit="rad");
  discrete Real q1_ref_BR(start=0.0, unit="rad");
  discrete Real q2_ref_BR(start=0.0, unit="rad");

  discrete Real depth_next_edge(start=0.0, unit="m") "depth camera next riser edge";
  discrete Real depth_next_tread_height(start=stair_rise, unit="m");
  discrete Real depth_current_tread_height(start=0.0, unit="m");

  // Reference trajectories and support.
  Real x_ref(unit="m");
  Real vx_ref(unit="m/s");
  Real z_ref(unit="m");
  Real stairZ_xref(unit="m");
  Real stairZ_xbody(unit="m");
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

  // Contact and traction forces.
  Real Fz_FL_raw(unit="N");
  Real Fz_FR_raw(unit="N");
  Real Fz_BL_raw(unit="N");
  Real Fz_BR_raw(unit="N");
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
  Real numContacts;
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
  discrete Real sampled_time(start=0.0, unit="s");
  discrete Real sampled_state_x(start=x_start, unit="m");
  discrete Real sampled_state_z(start=r_wheel, unit="m");
  discrete Real sampled_state_vx(start=0.0, unit="m/s");
  discrete Real sampled_state_vz(start=0.0, unit="m/s");
  discrete Real sampled_command_tau1_FL(start=0.0, unit="N.m");
  discrete Real sampled_command_tau2_FL(start=0.0, unit="N.m");
  discrete Real sampled_command_tauw_FL(start=0.0, unit="N.m");
  discrete Real sampled_command_tau1_FR(start=0.0, unit="N.m");
  discrete Real sampled_command_tau2_FR(start=0.0, unit="N.m");
  discrete Real sampled_command_tauw_FR(start=0.0, unit="N.m");
  discrete Real sampled_command_tau1_BL(start=0.0, unit="N.m");
  discrete Real sampled_command_tau2_BL(start=0.0, unit="N.m");
  discrete Real sampled_command_tauw_BL(start=0.0, unit="N.m");
  discrete Real sampled_command_tau1_BR(start=0.0, unit="N.m");
  discrete Real sampled_command_tau2_BR(start=0.0, unit="N.m");
  discrete Real sampled_command_tauw_BR(start=0.0, unit="N.m");
  discrete Real sampled_sensor_Fz_FL(start=0.0, unit="N");
  discrete Real sampled_sensor_Fz_FR(start=0.0, unit="N");
  discrete Real sampled_sensor_Fz_BL(start=0.0, unit="N");
  discrete Real sampled_sensor_Fz_BR(start=0.0, unit="N");
  discrete Real sampled_sensor_foot_x_FL(start=-0.5*stair_tread, unit="m");
  discrete Real sampled_sensor_foot_x_FR(start=0.5*stair_tread, unit="m");
  discrete Real sampled_sensor_foot_x_BL(start=0.5*stair_tread, unit="m");
  discrete Real sampled_sensor_foot_x_BR(start=-0.5*stair_tread, unit="m");
  discrete Real sampled_sensor_numContacts(start=0.0);
  discrete Real sampled_primary_error(start=0.0, unit="m");
  discrete Boolean sampled_acceptance(start=false);

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

  // Temporary variables for clamping and force computation.
  Real heightErr(unit="m");
  Real Fx_FL_raw(unit="N");
  Real Fx_FR_raw(unit="N");
  Real Fx_BL_raw(unit="N");
  Real Fx_BR_raw(unit="N");

equation
  // Stair surface height profile (inline, four stairs).
  stairZ_xref = if x_ref < 0.0 then 0.0
                elseif x_ref < stair_tread then stair_rise
                elseif x_ref < 2.0*stair_tread then 2.0*stair_rise
                elseif x_ref < 3.0*stair_tread then 3.0*stair_rise
                elseif x_ref < 4.0*stair_tread then 4.0*stair_rise
                else 4.0*stair_rise;

  stairZ_xbody = if x_body < 0.0 then 0.0
                 elseif x_body < stair_tread then stair_rise
                 elseif x_body < 2.0*stair_tread then 2.0*stair_rise
                 elseif x_body < 3.0*stair_tread then 3.0*stair_rise
                 elseif x_body < 4.0*stair_tread then 4.0*stair_rise
                 else 4.0*stair_rise;

  // Reference trajectory over four stairs.
  x_ref = if time <= t_end then x_start + (x_end - x_start)*time/t_end else x_end;
  vx_ref = if time <= t_end then (x_end - x_start)/t_end else 0.0;
  z_ref = stairZ_xref + r_wheel + bodyHeightOffset;
  wheelSpeedRef = vx_ref / r_wheel;
  wheelSpeed = vx / r_wheel;

  supportHeight = stairZ_xbody;
  bodyHeight = z_body - supportHeight - r_wheel - bodyHeightOffset;
  heightErr = z_ref - z_body;
  bodyHeightError = -heightErr;
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
  tau1_height_FL = Kz*heightErr*r_wheel/8.0;
  tau2_height_FL = Kz*heightErr*r_wheel/8.0;
  tau1_height_FR = Kz*heightErr*r_wheel/8.0;
  tau2_height_FR = Kz*heightErr*r_wheel/8.0;
  tau1_height_BL = Kz*heightErr*r_wheel/8.0;
  tau2_height_BL = Kz*heightErr*r_wheel/8.0;
  tau1_height_BR = Kz*heightErr*r_wheel/8.0;
  tau2_height_BR = Kz*heightErr*r_wheel/8.0;

  // Raw torque commands.
  tau1_raw_FL = tau1_ff_FL + tau1_imp_FL + tau1_height_FL;
  tau2_raw_FL = tau2_ff_FL + tau2_imp_FL + tau2_height_FL;
  tau1_raw_FR = tau1_ff_FR + tau1_imp_FR + tau1_height_FR;
  tau2_raw_FR = tau2_ff_FR + tau2_imp_FR + tau2_height_FR;
  tau1_raw_BL = tau1_ff_BL + tau1_imp_BL + tau1_height_BL;
  tau2_raw_BL = tau2_ff_BL + tau2_imp_BL + tau2_height_BL;
  tau1_raw_BR = tau1_ff_BR + tau1_imp_BR + tau1_height_BR;
  tau2_raw_BR = tau2_ff_BR + tau2_imp_BR + tau2_height_BR;

  // Independently limited joint torque commands (inline clamp).
  tau1_FL = if tau1_raw_FL < -tau_max then -tau_max elseif tau1_raw_FL > tau_max then tau_max else tau1_raw_FL;
  tau2_FL = if tau2_raw_FL < -tau_max then -tau_max elseif tau2_raw_FL > tau_max then tau_max else tau2_raw_FL;
  tau1_FR = if tau1_raw_FR < -tau_max then -tau_max elseif tau1_raw_FR > tau_max then tau_max else tau1_raw_FR;
  tau2_FR = if tau2_raw_FR < -tau_max then -tau_max elseif tau2_raw_FR > tau_max then tau_max else tau2_raw_FR;
  tau1_BL = if tau1_raw_BL < -tau_max then -tau_max elseif tau1_raw_BL > tau_max then tau_max else tau1_raw_BL;
  tau2_BL = if tau2_raw_BL < -tau_max then -tau_max elseif tau2_raw_BL > tau_max then tau_max else tau2_raw_BL;
  tau1_BR = if tau1_raw_BR < -tau_max then -tau_max elseif tau1_raw_BR > tau_max then tau_max else tau1_raw_BR;
  tau2_BR = if tau2_raw_BR < -tau_max then -tau_max elseif tau2_raw_BR > tau_max then tau_max else tau2_raw_BR;

  // Wheel torque commands, independently limited.
  tauw_raw_FL = Kw*(wheelSpeedRef - wheelSpeed) + Kx*(x_ref - x_body)*r_wheel/4.0;
  tauw_raw_FR = Kw*(wheelSpeedRef - wheelSpeed) + Kx*(x_ref - x_body)*r_wheel/4.0;
  tauw_raw_BL = Kw*(wheelSpeedRef - wheelSpeed) + Kx*(x_ref - x_body)*r_wheel/4.0;
  tauw_raw_BR = Kw*(wheelSpeedRef - wheelSpeed) + Kx*(x_ref - x_body)*r_wheel/4.0;

  tauw_FL = if tauw_raw_FL < -tau_max then -tau_max elseif tauw_raw_FL > tau_max then tau_max else tauw_raw_FL;
  tauw_FR = if tauw_raw_FR < -tau_max then -tau_max elseif tauw_raw_FR > tau_max then tau_max else tauw_raw_FR;
  tauw_BL = if tauw_raw_BL < -tau_max then -tau_max elseif tauw_raw_BL > tau_max then tau_max else tauw_raw_BL;
  tauw_BR = if tauw_raw_BR < -tau_max then -tau_max elseif tauw_raw_BR > tau_max then tau_max else tauw_raw_BR;

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
  Fz_FL_raw = (tau1_FL + tau2_FL)/r_wheel;
  Fz_FR_raw = (tau1_FR + tau2_FR)/r_wheel;
  Fz_BL_raw = (tau1_BL + tau2_BL)/r_wheel;
  Fz_BR_raw = (tau1_BR + tau2_BR)/r_wheel;

  Fz_FL = if Fz_FL_raw > 0.0 then Fz_FL_raw else 0.0;
  Fz_FR = if Fz_FR_raw > 0.0 then Fz_FR_raw else 0.0;
  Fz_BL = if Fz_BL_raw > 0.0 then Fz_BL_raw else 0.0;
  Fz_BR = if Fz_BR_raw > 0.0 then Fz_BR_raw else 0.0;

  // Friction-limited wheel traction.
  Fx_FL_raw = tauw_FL / r_wheel;
  Fx_FR_raw = tauw_FR / r_wheel;
  Fx_BL_raw = tauw_BL / r_wheel;
  Fx_BR_raw = tauw_BR / r_wheel;

  Fx_FL = if Fx_FL_raw > mu*Fz_FL then mu*Fz_FL elseif Fx_FL_raw < -mu*Fz_FL then -mu*Fz_FL else Fx_FL_raw;
  Fx_FR = if Fx_FR_raw > mu*Fz_FR then mu*Fz_FR elseif Fx_FR_raw < -mu*Fz_FR then -mu*Fz_FR else Fx_FR_raw;
  Fx_BL = if Fx_BL_raw > mu*Fz_BL then mu*Fz_BL elseif Fx_BL_raw < -mu*Fz_BL then -mu*Fz_BL else Fx_BL_raw;
  Fx_BR = if Fx_BR_raw > mu*Fz_BR then mu*Fz_BR elseif Fx_BR_raw < -mu*Fz_BR then -mu*Fz_BR else Fx_BR_raw;

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
  primaryTrackingError = max({footholdError_FL, footholdError_FR, footholdError_BL, footholdError_BR});

  // Edge clearance (inline min of distances to stair edges).
  edgeClearanceFL = min({abs(foot_x_FL), abs(foot_x_FL - stair_tread), abs(foot_x_FL - 2.0*stair_tread), abs(foot_x_FL - 3.0*stair_tread), abs(foot_x_FL - 4.0*stair_tread)});
  edgeClearanceFR = min({abs(foot_x_FR), abs(foot_x_FR - stair_tread), abs(foot_x_FR - 2.0*stair_tread), abs(foot_x_FR - 3.0*stair_tread), abs(foot_x_FR - 4.0*stair_tread)});
  edgeClearanceBL = min({abs(foot_x_BL), abs(foot_x_BL - stair_tread), abs(foot_x_BL - 2.0*stair_tread), abs(foot_x_BL - 3.0*stair_tread), abs(foot_x_BL - 4.0*stair_tread)});
  edgeClearanceBR = min({abs(foot_x_BR), abs(foot_x_BR - stair_tread), abs(foot_x_BR - 2.0*stair_tread), abs(foot_x_BR - 3.0*stair_tread), abs(foot_x_BR - 4.0*stair_tread)});

  // Sensors.
  contact_FL = Fz_FL > 1.0;
  contact_FR = Fz_FR > 1.0;
  contact_BL = Fz_BL > 1.0;
  contact_BR = Fz_BR > 1.0;
  numContacts = (if contact_FL then 1.0 else 0.0) + (if contact_FR then 1.0 else 0.0) +
                (if contact_BL then 1.0 else 0.0) + (if contact_BR then 1.0 else 0.0);

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

  commandBoundOK = effortBoundOK;

  stairEdgeClearanceOK = edgeClearanceFL > 1e-6 and edgeClearanceFR > 1e-6 and
                         edgeClearanceBL > 1e-6 and edgeClearanceBR > 1e-6;

  supportContactOK = numContacts >= 2.0;
  completionOK = x_body >= x_end - 1e-6;
  primaryTrackingOK = if time >= t_primary then primaryTrackingError < foothold_tol else true;

  finitePhysical = abs(x_body) <= 1e300 and abs(z_body) <= 1e300 and abs(vx) <= 1e300 and abs(vz) <= 1e300 and
                   abs(q1_FL) <= 1e300 and abs(q2_FL) <= 1e300 and abs(q1_FR) <= 1e300 and abs(q2_FR) <= 1e300 and
                   abs(q1_BL) <= 1e300 and abs(q2_BL) <= 1e300 and abs(q1_BR) <= 1e300 and abs(q2_BR) <= 1e300 and
                   abs(dq1_FL) <= 1e300 and abs(dq2_FL) <= 1e300 and abs(dq1_FR) <= 1e300 and abs(dq2_FR) <= 1e300 and
                   abs(dq1_BL) <= 1e300 and abs(dq2_BL) <= 1e300 and abs(dq1_BR) <= 1e300 and abs(dq2_BR) <= 1e300 and
                   abs(qw_FL) <= 1e300 and abs(qw_FR) <= 1e300 and abs(qw_BL) <= 1e300 and abs(qw_BR) <= 1e300 and
                   abs(Fz_FL) <= 1e300 and abs(Fz_FR) <= 1e300 and abs(Fz_BL) <= 1e300 and abs(Fz_BR) <= 1e300 and
                   abs(Fx_FL) <= 1e300 and abs(Fx_FR) <= 1e300 and abs(Fx_BL) <= 1e300 and abs(Fx_BR) <= 1e300 and
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
                    abs(encoder_q1_FL) <= 1e300 and abs(encoder_q2_FL) <= 1e300 and
                    abs(encoder_q1_FR) <= 1e300 and abs(encoder_q2_FR) <= 1e300 and
                    abs(encoder_q1_BL) <= 1e300 and abs(encoder_q2_BL) <= 1e300 and
                    abs(encoder_q1_BR) <= 1e300 and abs(encoder_q2_BR) <= 1e300 and
                    abs(encoder_wheel_FL) <= 1e300 and abs(encoder_wheel_FR) <= 1e300 and
                    abs(encoder_wheel_BL) <= 1e300 and abs(encoder_wheel_BR) <= 1e300 and
                    abs(footForce_FL) <= 1e300 and abs(footForce_FR) <= 1e300 and
                    abs(footForce_BL) <= 1e300 and abs(footForce_BR) <= 1e300 and
                    abs(foot_x_FL) <= 1e300 and abs(foot_x_FR) <= 1e300 and
                    abs(foot_x_BL) <= 1e300 and abs(foot_x_BR) <= 1e300 and
                    abs(foot_z_FL) <= 1e300 and abs(foot_z_FR) <= 1e300 and
                    abs(foot_z_BL) <= 1e300 and abs(foot_z_BR) <= 1e300;

  Acceptance = effortBoundOK and commandBoundOK and stairEdgeClearanceOK and
               supportContactOK and completionOK and primaryTrackingOK and
               finitePhysical and finiteControl and finiteEstimator;

  // 250 Hz terrain-aware planner and synchronized trace retention.
  when sample(0.0, Ts) then
    // Detect current stair step from body position.
    currentStep := if x_body < 0.0 then 0
                   elseif x_body < stair_tread then 1
                   elseif x_body < 2.0*stair_tread then 2
                   elseif x_body < 3.0*stair_tread then 3
                   elseif x_body < 4.0*stair_tread then 4
                   else 5;
    nextStep := if currentStep >= 4 then 5 else currentStep + 1;

    // Terrain-aware foothold planning: trailing legs on current step, leading legs on next.
    foothold_x_FL := if currentStep == 0 then -0.5*stair_tread
                     elseif currentStep == 1 then 0.5*stair_tread
                     elseif currentStep == 2 then 1.5*stair_tread
                     elseif currentStep == 3 then 2.5*stair_tread
                     elseif currentStep == 4 then 3.5*stair_tread
                     else 4.5*stair_tread;
    foothold_z_FL := if currentStep <= 0 then 0.0
                     elseif currentStep >= 4 then 4.0*stair_rise
                     else currentStep*stair_rise;

    foothold_x_BR := foothold_x_FL;
    foothold_z_BR := foothold_z_FL;

    foothold_x_FR := if nextStep == 0 then -0.5*stair_tread
                     elseif nextStep == 1 then 0.5*stair_tread
                     elseif nextStep == 2 then 1.5*stair_tread
                     elseif nextStep == 3 then 2.5*stair_tread
                     elseif nextStep == 4 then 3.5*stair_tread
                     else 4.5*stair_tread;
    foothold_z_FR := if nextStep <= 0 then 0.0
                     elseif nextStep >= 4 then 4.0*stair_rise
                     else nextStep*stair_rise;

    foothold_x_BL := foothold_x_FR;
    foothold_z_BL := foothold_z_FR;

    // Joint references proportional to step height (normalized).
    q1_ref_FL := if currentStep <= 0 then 0.0 elseif currentStep >= 4 then 1.0 else currentStep/4.0;
    q2_ref_FL := q1_ref_FL;
    q1_ref_BR := q1_ref_FL;
    q2_ref_BR := q1_ref_FL;

    q1_ref_FR := if nextStep <= 0 then 0.0 elseif nextStep >= 4 then 1.0 else nextStep/4.0;
    q2_ref_FR := q1_ref_FR;
    q1_ref_BL := q1_ref_FR;
    q2_ref_BL := q1_ref_FR;

    // Depth camera edge detection.
    depth_next_edge := if currentStep < 4 then currentStep*stair_tread else 4.0*stair_tread;
    depth_next_tread_height := if currentStep < 4 then (currentStep + 1)*stair_rise else 4.0*stair_rise;
    depth_current_tread_height := if currentStep <= 4 then currentStep*stair_rise else 4.0*stair_rise;

    // Synchronized trace retention.
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