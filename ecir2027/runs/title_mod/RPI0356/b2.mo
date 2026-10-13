model DeltaPressB
  "Closed-chain Delta parallel robot pressing compliant workpiece, hybrid position-force control"

  // ===== Physical parameters from requirement =====
  parameter Modelica.SIunits.Length L_upper = 0.32 "Upper arm length (m)";
  parameter Modelica.SIunits.Length L_fore  = 0.60 "Forearm length (m)";
  parameter Modelica.SIunits.Mass   m_platform = 3.00 "Moving platform mass (kg)";
  parameter Modelica.SIunits.Torque tau_max = 36.9 "Max actuator torque per actuator (N.m)";
  parameter Real k_contact  = 200000.0 "Contact stiffness (N/m)";
  parameter Real c_contact  = 2000.0   "Contact damping (N.s/m)";
  parameter Real mu_contact = 0.70     "Friction coefficient";
  parameter Real F_dist_amp = 12.6     "Disturbance force change (N)";
  parameter Real T_total    = 10.0     "Mission duration (s)";
  parameter Real f_ctrl     = 100.0    "Control loop frequency (Hz)";

  // ===== Assumed parameters (not stated; reasonable values for compilation) =====
  parameter Real J_z    = 0.35  "Linearized forward Jacobian dz/dtheta (m/rad, assumed)";
  parameter Real J_arm  = 0.015 "Single arm reflected inertia (kg.m2, assumed)";
  parameter Real b_arm  = 0.10  "Single arm viscous damping (N.m.s/rad, assumed)";
  parameter Real g      = 9.81  "Gravity (m/s2, assumed)";
  parameter Real z_wp   = 0.050 "Workpiece contact height from start (m, assumed)";
  parameter Real z_app  = 0.055 "Pre-contact approach target (m, assumed)";
  parameter Real F_set  = 50.0  "Target contact force setpoint (N, assumed)";
  parameter Real Kp_pos = 1500.0 "Position proportional gain (assumed)";
  parameter Real Kd_pos = 60.0   "Position derivative gain (assumed)";
  parameter Real Kp_f   = 1.5    "Force proportional gain (assumed)";
  parameter Real Ki_f   = 15.0   "Force integral gain (assumed)";
  parameter Real k_cl   = 800.0  "Closure restoring stiffness (N.m/rad, assumed)";
  parameter Real b_cl   = 4.0    "Closure damping (N.m.s/rad, assumed)";
  parameter Real Ts     = 1.0 / f_ctrl "Sample period (s)";

  // ===== Platform dynamic states =====
  Real z(start=0.0, fixed=true)    "Platform vertical position (m, downward positive)";
  Real vz(start=0.0, fixed=true)   "Platform vertical velocity (m/s)";

  // ===== Closure-deviation states (asymmetric arm modes) =====
  Real d1(start=0.0, fixed=true)  "Closure deviation arm 1 (rad)";
  Real d2(start=0.0, fixed=true)  "Closure deviation arm 2 (rad)";
  Real d3(start=0.0, fixed=true)  "Closure deviation arm 3 (rad)";
  Real dd1(start=0.0, fixed=true) "Closure deviation rate 1 (rad/s)";
  Real dd2(start=0.0, fixed=true) "Closure deviation rate 2 (rad/s)";
  Real dd3(start=0.0, fixed=true) "Closure deviation rate 3 (rad/s)";

  // ===== Discrete control variables (100 Hz) =====
  discrete Real z_d(start=0.0)    "Sampled position";
  discrete Real vz_d(start=0.0)   "Sampled velocity";
  discrete Real F_d(start=0.0)    "Sampled contact force";
  discrete Real fint_d(start=0.0) "Force integral term";
  discrete Real blend_d(start=1.0) "Position-force blend (1=pos, 0=force)";
  discrete Real Fcmd_d(start=0.0)  "Force command from controller (N)";
  discrete Real tau1_d(start=0.0)  "Torque command actuator 1 (N.m)";
  discrete Real tau2_d(start=0.0)  "Torque command actuator 2 (N.m)";
  discrete Real tau3_d(start=0.0)  "Torque command actuator 3 (N.m)";

  // ===== Continuous algebraic variables =====
  Real m_eff      "Effective platform mass including reflected arm inertia (kg)";
  Real z_target   "Target position trajectory (m)";
  Real F_target   "Target contact force (N)";
  Real F_dist     "Disturbance force (N)";
  Real pen        "Contact penetration depth (m)";
  Real F_n        "Normal contact force (N)";
  Real tau1       "Actuator 1 torque (N.m)";
  Real tau2       "Actuator 2 torque (N.m)";
  Real tau3       "Actuator 3 torque (N.m)";
  Real tau_comm   "Common-mode torque (N.m)";
  Real td1        "Differential torque 1 (N.m)";
  Real td2        "Differential torque 2 (N.m)";
  Real td3        "Differential torque 3 (N.m)";

  // ===== Sensors =====
  Real z_sensed     "Output pose position sensor (m)";
  Real F_sensed     "Normal contact force sensor (N)";
  Real tau1_sensed  "Actuator 1 torque sensor (N.m)";
  Real tau2_sensed  "Actuator 2 torque sensor (N.m)";
  Real tau3_sensed  "Actuator 3 torque sensor (N.m)";

  // ===== Monitoring =====
  Real closure_error       "Kinematic closure error (m)";
  Real primary_track_error "Primary tracking error (m)";
  Real F_fric_max          "Maximum friction force (N)";
  Real tangential_slip     "Tangential slip force (N)";
  Boolean in_contact       "Contact detected flag";
  Boolean locked_contact   "Locked contact (no slip) flag";
  Boolean torque_bounded   "All torques within bounds flag";
  Boolean valid_state      "No NaN or infinite values flag";

equation
  // ===== Effective mass =====
  m_eff = m_platform + 3.0 * J_arm / (J_z * J_z);

  // ===== Trajectory generation =====
  if time < T_total / 3.0 then
    z_target = z_app * time / (T_total / 3.0);
  elseif time < 2.0 * T_total / 3.0 then
    z_target = z_app;
  else
    z_target = z_app;
  end if;

  if time < T_total / 3.0 then
    F_target = 0.0;
  else
    F_target = F_set;
  end if;

  // ===== Disturbance injection (controlled 12.6 N during middle third) =====
  if time >= T_total / 3.0 and time < 2.0 * T_total / 3.0 then
    F_dist = F_dist_amp;
  else
    F_dist = 0.0;
  end if;

  // ===== Contact model =====
  pen = z - z_wp;
  in_contact = pen > 0.0;
  F_n = if in_contact then k_contact * pen + c_contact * max(vz, 0.0) else 0.0;

  // ===== Torque zero-order hold from discrete commands =====
  tau1 = tau1_d;
  tau2 = tau2_d;
  tau3 = tau3_d;

  // ===== Torque decomposition into common and differential modes =====
  tau_comm = (tau1 + tau2 + tau3) / 3.0;
  td1 = tau1 - tau_comm;
  td2 = tau2 - tau_comm;
  td3 = tau3 - tau_comm;

  // ===== Platform vertical dynamics =====
  m_eff * der(vz) = (tau1 + tau2 + tau3) / J_z - m_platform * g - F_n - F_dist;
  der(z) = vz;

  // ===== Closure deviation dynamics (asymmetric modes) =====
  J_arm * der(dd1) = td1 - b_arm * dd1 - k_cl * d1;
  J_arm * der(dd2) = td2 - b_arm * dd2 - k_cl * d2;
  J_arm * der(dd3) = td3 - b_arm * dd3 - k_cl * d3;
  der(d1) = dd1;
  der(d2) = dd2;
  der(d3) = dd3;

  // ===== Sensors =====
  z_sensed = z;
  F_sensed = F_n;
  tau1_sensed = tau1;
  tau2_sensed = tau2;
  tau3_sensed = tau3;

  // ===== Monitoring =====
  closure_error = J_z * (abs(d1) + abs(d2) + abs(d3));
  primary_track_error = abs(z - z_target);
  F_fric_max = mu_contact * F_n;
  tangential_slip = max(0.0, abs(F_dist) - F_fric_max);
  locked_contact = in_contact and (tangential_slip < 0.001);
  torque_bounded = (abs(tau1) <= tau_max + 0.001)
                   and (abs(tau2) <= tau_max + 0.001)
                   and (abs(tau3) <= tau_max + 0.001);
  valid_state = (z > -1.0e6) and (z < 1.0e6)
                and (vz > -1.0e6) and (vz < 1.0e6)
                and (F_n >= 0.0) and (F_n < 1.0e6);

  // ===== Discrete hybrid controller at 100 Hz =====
  when sample(0.0, Ts) then
    // Sample sensor feedback
    z_d = z;
    vz_d = vz;
    F_d = F_n;

    // Blend: position control in free space, force control in contact
    blend_d = if F_d > 1.0 or z_d > z_wp - 0.002 then 0.0 else 1.0;

    // Force integral (accumulate only in force-control mode)
    fint_d = if pre(blend_d) < 0.5
             then pre(fint_d) + (F_target - F_d) * Ts
             else 0.0;

    // Hybrid force command with gravity feedforward
    Fcmd_d = blend_d * (Kp_pos * (z_target - z_d) - Kd_pos * vz_d + m_platform * g)
           + (1.0 - blend_d) * (Kp_f * (F_target - F_d) + Ki_f * fint_d + m_platform * g);

    // Convert total force to per-actuator torque with saturation
    tau1_d = max(-tau_max, min(tau_max, Fcmd_d * J_z / 3.0));
    tau2_d = max(-tau_max, min(tau_max, Fcmd_d * J_z / 3.0));
    tau3_d = max(-tau_max, min(tau_max, Fcmd_d * J_z / 3.0));
  end when;

end DeltaPressB;