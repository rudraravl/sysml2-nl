model DeltaPressB
  /* DeltaPressB: Closed-chain Delta parallel robot pressing against
     compliant workpiece with position-to-force hybrid control.
     Mission: approach, contact, regulate force, tolerate disturbance.
     Unknown geometric parameters (base radius, platform radius, arm
     inertia, joint damping, workpiece location, target trajectory,
     controller gains) are marked with comment "(assumed)" and given
     reasonable values so the model compiles and simulates. */

  // ===== Physical parameters from requirement =====
  parameter Modelica.SIunits.Length L_upper = 0.32 "Upper arm length";
  parameter Modelica.SIunits.Length L_fore  = 0.60 "Forearm length";
  parameter Modelica.SIunits.Mass   m_platform = 3.00 "Moving platform mass";
  parameter Modelica.SIunits.Torque tau_max = 36.9 "Max actuator torque per actuator";
  parameter Real k_contact = 200000.0 "Contact stiffness (N/m)";
  parameter Real c_contact = 2000.0   "Contact damping (N.s/m)";
  parameter Real mu_contact = 0.70     "Friction coefficient";
  parameter Real F_dist_amp = 12.6     "Disturbance force change (N)";
  parameter Real T_total = 10.0        "Mission duration (s)";
  parameter Real f_ctrl = 100.0        "Control loop frequency (Hz)";

  // ===== Assumed parameters (not stated in requirement) =====
  parameter Real J_z_lin = 0.35       "Linearized forward Jacobian dz/dtheta (m/rad, assumed)";
  parameter Real J_arm = 0.015        "Single arm reflected inertia (kg.m2, assumed)";
  parameter Real b_arm = 0.10         "Single arm viscous damping (N.m.s/rad, assumed)";
  parameter Real g_const = 9.81       "Gravity (m/s2)";
  parameter Real z_workpiece = -0.060 "Workpiece contact height relative to start (m, assumed)";
  parameter Real z_approach = -0.050  "Pre-contact approach target (m, assumed)";
  parameter Real F_setpoint = 50.0    "Target contact force (N, assumed)";
  parameter Real Kp_pos = 3000.0      "Position P gain (assumed)";
  parameter Real Kd_pos = 120.0       "Position D gain (assumed)";
  parameter Real Kp_force = 12.0      "Force P gain (assumed)";
  parameter Real Ki_force = 120.0     "Force I gain (assumed)";
  parameter Real k_closure = 800.0    "Closure restoring stiffness (N.m/rad, assumed)";
  parameter Real b_closure = 4.0      "Closure damping (N.m.s/rad, assumed)";
  parameter Real J_z_safe = 0.05      "Jacobian lower bound for division safety";

  // ===== Platform states =====
  Real z(start = 0.0, fixed = true)    "Platform vertical position";
  Real vz(start = 0.0, fixed = true)   "Platform vertical velocity";

  // ===== Closure-deviation states (asymmetric arm modes) =====
  Real delta1(start = 0.0, fixed = true)  "Arm 1 closure deviation";
  Real delta2(start = 0.0, fixed = true)  "Arm 2 closure deviation";
  Real delta3(start = 0.0, fixed = true)  "Arm 3 closure deviation";
  Real ddelta1(start = 0.0, fixed = true) "Arm 1 deviation rate";
  Real ddelta2(start = 0.0, fixed = true) "Arm 2 deviation rate";
  Real ddelta3(start = 0.0, fixed = true) "Arm 3 deviation rate";

  // ===== Arm angles (algebraic) =====
  Real theta1 "Arm 1 angle";
  Real theta2 "Arm 2 angle";
  Real theta3 "Arm 3 angle";
  Real theta_avg "Symmetric arm angle";

  // ===== Effective inertia =====
  Real m_eff "Effective mass including reflected arm inertia";

  // ===== Torques =====
  Real tau1 "Actuator 1 actual torque";
  Real tau2 "Actuator 2 actual torque";
  Real tau3 "Actuator 3 actual torque";
  Real tau1_cmd "Actuator 1 commanded torque";
  Real tau2_cmd "Actuator 2 commanded torque";
  Real tau3_cmd "Actuator 3 commanded torque";
  Real tau_common "Common-mode torque command";
  Real tau_diff1 "Differential torque 1";
  Real tau_diff2 "Differential torque 2";
  Real tau_diff3 "Differential torque 3";

  // ===== Contact =====
  Real penetration "Contact penetration depth";
  Real F_normal "Normal contact force (>=0)";
  Real F_friction "Friction force (tangential)";
  Real F_friction_max "Maximum static friction force";
  Real F_tangent_demanded "Demanded tangential force";
  Boolean in_contact "Contact flag";

  // ===== Control =====
  Real z_target "Target position trajectory";
  Real F_target "Target contact force";
  Real pos_error "Position tracking error";
  Real force_error "Force tracking error";
  Real force_integral "Force integral term";
  Real blend "Position-force blend factor (1=pos, 0=force)";
  Real F_pos_ctrl "Position controller force output";
  Real F_force_ctrl "Force controller force output";
  Real F_cmd_total "Total commanded force from controller";

  // ===== Disturbance =====
  Real F_dist "Disturbance force";

  // ===== Sensors =====
  Real z_sensed "Sensed platform position";
  Real F_sensed "Sensed normal contact force";
  Real tau1_sensed "Sensed torque actuator 1";
  Real tau2_sensed "Sensed torque actuator 2";
  Real tau3_sensed "Sensed torque actuator 3";

  // ===== Monitoring =====
  Real closure_error "Kinematic closure error (m)";
  Real tangential_slip "Tangential slip force (N)";
  Boolean locked_contact "Locked contact flag";
  Boolean torque_bounded "All torques within bounds";
  Real primary_track_error "Primary tracking error (m)";
  Boolean valid_state "No NaN or infinite values flag";

  // ===== Discrete control at 100 Hz =====
  parameter Real T_s = 1.0 / f_ctrl "Sample period";
  discrete Real z_s_d(start = 0.0);
  discrete Real vz_s_d(start = 0.0);
  discrete Real F_s_d(start = 0.0);
  discrete Real pos_err_d(start = 0.0);
  discrete Real force_err_d(start = 0.0);
  discrete Real force_int_d(start = 0.0);
  discrete Real blend_d(start = 1.0);
  discrete Real z_target_d(start = 0.0);
  discrete Real F_target_d(start = 0.0);
  discrete Real F_dist_d(start = 0.0);
  discrete Real tau1_cmd_d(start = 0.0);
  discrete Real tau2_cmd_d(start = 0.0);
  discrete Real tau3_cmd_d(start = 0.0);
  discrete Real F_cmd_total_d(start = 0.0);

initial equation
  force_integral = 0.0;

equation
  // ===== Jacobian and effective mass =====
  m_eff = m_platform + 3.0 * J_arm / max(J_z_lin * J_z_lin, J_z_safe * J_z_safe);

  // ===== Forward kinematics (linearized) =====
  theta_avg = z / max(abs(J_z_lin), J_z_safe) * sign(J_z_lin);
  theta1 = theta_avg + delta1;
  theta2 = theta_avg + delta2;
  theta3 = theta_avg + delta3;

  // ===== Trajectory generation =====
  // Phase 1 (0 to T/3): approach workpiece
  // Phase 2 (T/3 to 2T/3): contact and regulate force with disturbance
  // Phase 3 (2T/3 to T): continue force regulation
  if time < T_total / 3.0 then
    z_target = z_approach * (time / (T_total / 3.0));
    F_target = 0.0;
  elseif time < 2.0 * T_total / 3.0 then
    z_target = z_approach;
    F_target = F_setpoint;
  else
    z_target = z_approach;
    F_target = F_setpoint;
  end if;

  // ===== Disturbance injection (controlled 12.6 N during middle third) =====
  if time >= T_total / 3.0 and time < 2.0 * T_total / 3.0 then
    F_dist = F_dist_amp * Modelica.Math.sin(2.0 * Modelica.Constants.pi * (time - T_total / 3.0) / (T_total / 3.0));
  else
    F_dist = 0.0;
  end if;

  // ===== Contact model =====
  penetration = z_workpiece - z;
  in_contact = penetration > 0.0;
  F_normal = if in_contact then
      k_contact * penetration + c_contact * (-vz) * (if (-vz) > 0.0 then 1.0 else 0.0)
    else
      0.0;
  // Ensure non-negative normal force
  F_normal = max(F_normal_raw, 0.0);
  // Actually, compute properly:
  // Redefine: use a smooth formulation

  // ===== Platform dynamics =====
  // m_eff * z_dd = F_arms - m*g - F_normal - F_dist
  // F_arms = (tau1 + tau2 + tau3) / |J_z|
  m_eff * der(vz) = (tau1 + tau2 + tau3) / max(abs(J_z_lin), J_z_safe) * sign(J_z_lin)
                    - m_platform * g_const
                    - F_normal
                    - F_dist;
  der(z) = vz;

  // ===== Closure deviation dynamics =====
  // Each arm deviation is driven by differential torque and restored
  J_arm * der(ddelta1) = tau_diff1 - b_arm * ddelta1 - k_closure * delta1;
  J_arm * der(ddelta2) = tau_diff2 - b_arm * ddelta2 - k_closure * delta2;
  J_arm * der(ddelta3) = tau_diff3 - b_arm * ddelta3 - k_closure * delta3;
  der(delta1) = ddelta1;
  der(delta2) = ddelta2;
  der(delta3) = ddelta3;

  // ===== Torque decomposition =====
  tau_common = (tau1_cmd + tau2_cmd + tau3_cmd) / 3.0;
  tau_diff1 = tau1_cmd - tau_common;
  tau_diff2 = tau2_cmd - tau_common;
  tau_diff3 = tau3_cmd - tau_common;

  // Apply common-mode torque to all actuators for vertical force
  tau1 = tau_common + tau_diff1;
  tau2 = tau_common + tau_diff2;
  tau3 = tau_common + tau_diff3;

  // ===== Discrete controller at 100 Hz =====
  when sample(0.0, T_s) then
    // Sample sensors
    z_s_d = z;
    vz_s_d = vz;
    F_s_d = F_normal;
    // Sample targets
    z_target_d = z_target;
    F_target_d = F_target;
    F_dist_d = F_dist;
    // Position error
    pos_err_d = z_target_d - z_s_d;
    // Force error
    force_err_d = F_target_d - F_s_d;
    // Blend: 1 when no contact (position control), 0 when in contact (force control)
    blend_d = if F_s_d > 1.0 or (z_s_d < z_workpiece + 0.002) then 0.0 else 1.0;
    // Force integral (anti-windup)
    force_int_d = if blend_d < 0.5 then
        force_int_d + force_err_d * T_s
      else
        0.0;
    // Position controller (PD)
    F_pos_ctrl = Kp_pos * pos_err_d + Kd_pos * (-vz_s_d);
    // Force controller (PI)
    F_force_ctrl = Kp_force * force_err_d + Ki_force * force_int_d;
    // Hybrid blend
    F_cmd_total_d = blend_d * F_pos_ctrl + (1.0 - blend_d) * F_force_ctrl;
    // Distribute equally among three actuators, map force to torque via Jacobian
    tau_common_cmd_d = F_cmd_total_d * abs(J_z_lin) / 3.0;
    // Torque saturation
    tau1_cmd_d = max(-tau_max, min(tau_max, tau_common_cmd_d));
    tau2_cmd_d = max(-tau_max, min(tau_max, tau_common_cmd_d));
    tau3_cmd_d = max(-tau_max, min(tau_max, tau_common_cmd_d));
  end when;

  // Continuous command signals (zero-order hold from discrete)
  tau1_cmd = tau1_cmd_d;
  tau2_cmd = tau2_cmd_d;
  tau3_cmd = tau3_cmd_d;

  // ===== Sensors (with small noise-free model) =====
  z_sensed = z;
  F_sensed = F_normal;
  tau1_sensed = tau1;
  tau2_sensed = tau2;
  tau3_sensed = tau3;

  // ===== Monitoring =====
  // Closure error: deviation of arm angles causes effective position mismatch
  closure_error = abs(delta1 * J_z_lin) + abs(delta2 * J_z_lin) + abs(delta3 * J_z_lin);
  // Tangential slip force (friction limit vs demanded)
  F_friction_max = mu_contact * F_normal;
  F_tangent_demanded = abs(F_dist);
  tangential_slip = max(0.0, F_tangent_demanded - F_friction_max);
  // Locked contact: in contact and no slip
  locked_contact = in_contact and (tangential_slip < 0.001);
  // Torque bounds check
  torque_bounded = (abs(tau1) <= tau_max + 0.001) and (abs(tau2) <= tau_max + 0.001) and (abs(tau3) <= tau_max + 0.001);
  // Primary tracking error
  primary_track_error = abs(z - z_target);
  // Valid state check (no NaN or infinite)
  valid_state = (z > -1e6) and (z < 1e6) and (vz > -1e6) and (vz < 1e6)
                and (F_normal >= 0.0) and (F_normal < 1e6)
                and (tau1 > -1e6) and (tau1 < 1e6)
                and (tau2 > -1e6) and (tau2 < 1e6)
                and (tau3 > -1e6) and (tau3 < 1e6)
                and (force_integral > -1e6) and (force_integral < 1e6);

  // ===== Friction force computation (for monitoring) =====
  F_friction = if in_contact then
      max(-F_friction_max, min(F_friction_max, F_dist))
    else
      0.0;

  // Internal raw contact force variable (helper)
  Real F_normal_raw;
  F_normal_raw = if in_contact then
      k_contact * penetration + c_contact * max(-vz, 0.0)
    else
      0.0;

  // Override F_normal with guaranteed non-negative
  F_normal = if F_normal_raw > 0.0 then F_normal_raw else 0.0;

  // Unused torque common command discrete variable
  discrete Real tau_common_cmd_d(start = 0.0);
end DeltaPressB;