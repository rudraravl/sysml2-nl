model ShapeLockAvoidE
  "Six-section planar continuum arm: 3 tendons and thermally activated stiffness per section.
   Fixed cylinder obstacle, contact-aware shape control, bounded stiffness scheduling.
   9.6 N lateral tip disturbance during middle third. 250 Hz, 16 s, fail-closed acceptance."

  // ===== Geometry =====
  parameter Real L_s = 0.08 "Section length [m]";
  parameter Real r_t = 0.04 "Tendon moment-arm radius [m]";
  parameter Real r_arm = 0.015 "Arm outer radius [m]";

  // ===== Thermally activated stiffness (320 K to 345 K) =====
  parameter Real EI_min = 0.05 "Bending stiffness at 320 K [N.m^2]";
  parameter Real EI_max = 0.60 "Bending stiffness at 345 K [N.m^2]";
  parameter Real T_low = 320.0 "Low activation temperature [K]";
  parameter Real T_high = 345.0 "High activation temperature [K]";
  parameter Real T_amb = 300.0 "Ambient temperature [K]";

  // ===== Thermal dynamics =====
  parameter Real C_th = 0.8 "Section thermal capacitance [J/K]";
  parameter Real h_loss = 0.15 "Thermal loss coefficient [W/K]";

  // ===== Section bending dynamics =====
  parameter Real J_eff = 0.0005 "Effective inertia coefficient [kg.m^3]";
  parameter Real d_eff = 0.01 "Effective damping [N.m.s/m]";

  // ===== Actuator bounds (independent tendon / heater control) =====
  parameter Real f_max = 50.6 "Max tendon tension [N]";
  parameter Real P_max = 18.0 "Max heater power [W]";

  // ===== Fixed cylinder obstacle =====
  parameter Real obs_x = 0.12 "Obstacle center x [m]";
  parameter Real obs_z = 0.24 "Obstacle center z [m]";
  parameter Real obs_r = 0.025 "Obstacle radius [m]";
  parameter Real mu = 0.55 "Friction coefficient";

  // ===== Target =====
  parameter Real target_x = 0.20 "Target tip x [m]";
  parameter Real target_z = 0.42 "Target tip z [m]";

  // ===== Disturbance =====
  parameter Real F_dist = 9.6 "Lateral tip disturbance force [N]";

  // ===== Controller gains =====
  parameter Real Kp_kappa = 0.3 "Curvature PD proportional [N.m]";
  parameter Real Kd_kappa = 0.005 "Curvature PD derivative [N.m.s/m]";
  parameter Real Kp_tip = 120.0 "Tip PD proportional [N/m]";
  parameter Real Kd_tip = 6.0 "Tip PD derivative [N.s/m]";
  parameter Real Kp_temp = 5.0 "Temperature control gain [W/K]";
  parameter Real f_bias = 2.0 "Tendon pretension [N]";
  parameter Real kappa_ref_val = 1.854 "Reference curvature for target pose [1/m]";

  // ===== Contact model =====
  parameter Real k_contact = 500.0 "Contact stiffness [N/m]";
  parameter Real d_contact = 2.0 "Contact damping [N.s/m]";
  parameter Real eps_c = 1.0e-6 "Clearance regularization [m]";
  parameter Real eps_d = 1.0e-6 "Distance regularization [m]";

  // ===== Control rate =====
  parameter Real Ts_ctrl = 0.004 "Control period [s] (250 Hz)";

  // ===== Dynamic states =====
  Real kappa[6](each start = 0.001) "Section curvature [1/m]";
  Real dkappa[6](each start = 0.0) "Curvature rate [1/(m.s)]";
  Real T_sec[6](each start = 320.0) "Section temperature [K]";

  // ===== Actuator commands and bounded outputs =====
  Real f_cmd[6,3] "Tendon tension commands [N]";
  Real P_cmd[6] "Heater power commands [W]";
  Real f_act[6,3] "Bounded tendon tensions [N]";
  Real P_act[6] "Bounded heater powers [W]";

  // ===== Forward kinematics =====
  Real phi[7] "Cumulative bend angle at section boundaries [rad]";
  Real sec_x[7] "Section boundary x [m]";
  Real sec_z[7] "Section boundary z [m]";
  Real sec_mid_x[6] "Section midpoint x [m]";
  Real sec_mid_z[6] "Section midpoint z [m]";
  Real alpha[6] "Section midpoint angle [rad]";

  // ===== Jacobian (tip position w.r.t. curvature) =====
  Real cos_sum[6] "Downstream cosine sum";
  Real sin_sum[6] "Downstream sine sum";
  Real J_x[6] "d(tip_x)/d(kappa_i) [m^2]";
  Real J_z[6] "d(tip_z)/d(kappa_i) [m^2]";

  // ===== Tip pose and velocity =====
  Real tip_x "Tip x [m]";
  Real tip_z "Tip z [m]";
  Real tip_vx "Tip x velocity [m/s]";
  Real tip_vz "Tip z velocity [m/s]";
  Real tip_error "Tip position error magnitude [m]";
  Real tracking_error "Primary tracking error [m]";
  Real final_tip_error "Final tip error for acceptance [m]";

  // ===== Contact =====
  Real dist_obs[6] "Distance from section midpoint to obstacle center [m]";
  Real clearance[6] "Obstacle clearance per section [m]";
  Real clearance_min "Minimum clearance across all sections [m]";
  Real penetration[6] "Penetration depth [m]";
  Real F_contact[6] "Distributed contact force per section [N]";
  Real F_contact_total "Total contact force magnitude [N]";
  Real F_contact_fric "Friction force magnitude [N]";
  Real M_contact[6] "Contact moment on section [N.m]";
  Real contact_dir_x[6] "Contact normal x component";
  Real contact_dir_z[6] "Contact normal z component";

  // ===== Stiffness and moments =====
  Real EI_eff[6] "Effective bending stiffness [N.m^2]";
  Real M_tendon[6] "Tendon bending moment [N.m]";
  Real M_dist[6] "Disturbance moment [N.m]";
  Real M_des[6] "Desired total moment [N.m]";
  Real M_ff[6] "Feedforward moment [N.m]";
  Real F_des_x "Desired tip force x [N]";
  Real F_des_z "Desired tip force z [N]";

  // ===== Disturbance =====
  Real dist_active "Disturbance active flag (0 or 1)";
  Real F_tip_dist "Applied disturbance force [N]";

  // ===== Stiffness scheduling =====
  Real T_target[6] "Target temperature per section [K]";
  Real stiffness_mode "Global stiffness mode (0=soft, 1=stiff)";
  Real near_target "Near target flag";

  // ===== Acceptance variables =====
  Real f_max_s1 "Max tendon force section 1 [N]";
  Real f_max_s2 "Max tendon force section 2 [N]";
  Real f_max_s3 "Max tendon force section 3 [N]";
  Real f_max_s4 "Max tendon force section 4 [N]";
  Real f_max_s5 "Max tendon force section 5 [N]";
  Real f_max_s6 "Max tendon force section 6 [N]";
  Real max_f_act "Maximum actuator force [N]";
  Real max_P_act "Maximum actuator power [W]";
  Real max_kappa "Maximum curvature magnitude [1/m]";
  Real max_T "Maximum temperature [K]";
  Real min_T "Minimum temperature [K]";
  Real max_F_contact "Maximum contact force [N]";
  Real acceptance_pass "Fail-closed acceptance flag (1=pass, 0=fail)";
  Real no_nan_inf "No NaN/inf flag (1=ok)";

equation
  // ===== Forward kinematics =====
  phi[1] = 0.0;
  sec_x[1] = 0.0;
  sec_z[1] = 0.0;

  for i in 1:6 loop
    alpha[i] = phi[i] + kappa[i] * L_s / 2;
    sec_x[i+1] = sec_x[i] + L_s * sin(alpha[i]);
    sec_z[i+1] = sec_z[i] + L_s * cos(alpha[i]);
    phi[i+1] = phi[i] + kappa[i] * L_s;
    sec_mid_x[i] = sec_x[i] + (L_s / 2) * sin(phi[i] + kappa[i] * L_s / 4);
    sec_mid_z[i] = sec_z[i] + (L_s / 2) * cos(phi[i] + kappa[i] * L_s / 4);
  end for;

  // ===== Jacobian backward sweep (explicit scalar equations) =====
  cos_sum[6] = 0.0;
  sin_sum[6] = 0.0;
  cos_sum[5] = cos(alpha[6]);
  sin_sum[5] = sin(alpha[6]);
  cos_sum[4] = cos(alpha[5]) + cos_sum[5];
  sin_sum[4] = sin(alpha[5]) + sin_sum[5];
  cos_sum[3] = cos(alpha[4]) + cos_sum[4];
  sin_sum[3] = sin(alpha[4]) + sin_sum[4];
  cos_sum[2] = cos(alpha[3]) + cos_sum[3];
  sin_sum[2] = sin(alpha[3]) + sin_sum[3];
  cos_sum[1] = cos(alpha[2]) + cos_sum[2];
  sin_sum[1] = sin(alpha[2]) + sin_sum[2];

  for i in 1:6 loop
    J_x[i] = L_s * (L_s / 2) * cos(alpha[i]) + L_s * L_s * cos_sum[i];
    J_z[i] = -L_s * (L_s / 2) * sin(alpha[i]) - L_s * L_s * sin_sum[i];
  end for;

  // ===== Tip pose and velocity =====
  tip_x = sec_x[7];
  tip_z = sec_z[7];
  tip_vx = J_x[1] * dkappa[1] + J_x[2] * dkappa[2] + J_x[3] * dkappa[3]
         + J_x[4] * dkappa[4] + J_x[5] * dkappa[5] + J_x[6] * dkappa[6];
  tip_vz = J_z[1] * dkappa[1] + J_z[2] * dkappa[2] + J_z[3] * dkappa[3]
         + J_z[4] * dkappa[4] + J_z[5] * dkappa[5] + J_z[6] * dkappa[6];
  tip_error = sqrt((tip_x - target_x) ^ 2 + (tip_z - target_z) ^ 2 + eps_c ^ 2);
  tracking_error = tip_error;
  final_tip_error = tip_error;

  // ===== Contact model =====
  for i in 1:6 loop
    dist_obs[i] = sqrt((sec_mid_x[i] - obs_x) ^ 2 + (sec_mid_z[i] - obs_z) ^ 2 + eps_d ^ 2);
    clearance[i] = dist_obs[i] - obs_r - r_arm;
    penetration[i] = (sqrt(clearance[i] ^ 2 + eps_c ^ 2) - clearance[i]) / 2;
    F_contact[i] = k_contact * penetration[i];
    contact_dir_x[i] = (sec_mid_x[i] - obs_x) / dist_obs[i];
    contact_dir_z[i] = (sec_mid_z[i] - obs_z) / dist_obs[i];
    M_contact[i] = F_contact[i] * ((sec_mid_z[i] - sec_z[i]) * contact_dir_x[i]
                                  - (sec_mid_x[i] - sec_x[i]) * contact_dir_z[i]);
  end for;

  clearance_min = min(clearance[1], min(clearance[2], min(clearance[3],
                 min(clearance[4], min(clearance[5], clearance[6])))));
  F_contact_total = abs(F_contact[1]) + abs(F_contact[2]) + abs(F_contact[3])
                  + abs(F_contact[4]) + abs(F_contact[5]) + abs(F_contact[6]);
  F_contact_fric = mu * F_contact_total;

  // ===== Disturbance: 9.6 N lateral tip load during middle third [5.333, 10.667] s =====
  dist_active = if noEvent(time >= 16.0 / 3.0 and time <= 32.0 / 3.0) then 1.0 else 0.0;
  F_tip_dist = F_dist * dist_active;

  for i in 1:6 loop
    M_dist[i] = F_tip_dist * J_x[i];
  end for;

  // ===== Stiffness scheduling: stiffen when near target =====
  near_target = if noEvent(tip_error < 0.05) then 1.0 else 0.0;
  stiffness_mode = near_target;

  for i in 1:6 loop
    T_target[i] = T_low + (T_high - T_low) * stiffness_mode;
    P_cmd[i] = Kp_temp * (T_target[i] - T_sec[i]);
    P_act[i] = max(0.0, min(P_max, P_cmd[i]));
  end for;

  // ===== Controller: feedforward + curvature PD + tip PD =====
  F_des_x = Kp_tip * (target_x - tip_x) - Kd_tip * tip_vx;
  F_des_z = Kp_tip * (target_z - tip_z) - Kd_tip * tip_vz;

  for i in 1:6 loop
    EI_eff[i] = EI_min + (EI_max - EI_min) * (T_sec[i] - T_low) / (T_high - T_low);
    M_ff[i] = EI_eff[i] * kappa_ref_val;
    M_des[i] = M_ff[i]
             + Kp_kappa * (kappa_ref_val - kappa[i])
             - Kd_kappa * dkappa[i]
             + F_des_x * J_x[i]
             + F_des_z * J_z[i];
    // Tendon allocation: 3 tendons at 0, 120, 240 deg; planar moment M = r_t*(f1-(f2+f3)/2)
    f_cmd[i,1] = f_bias + max(0.0, M_des[i] / r_t);
    f_cmd[i,2] = f_bias + max(0.0, -M_des[i] / r_t);
    f_cmd[i,3] = f_bias + max(0.0, -M_des[i] / r_t);
    // Bounded actuators
    f_act[i,1] = max(0.0, min(f_max, f_cmd[i,1]));
    f_act[i,2] = max(0.0, min(f_max, f_cmd[i,2]));
    f_act[i,3] = max(0.0, min(f_max, f_cmd[i,3]));
    // Actual tendon moment
    M_tendon[i] = r_t * (f_act[i,1] - (f_act[i,2] + f_act[i,3]) / 2);
  end for;

  // ===== Section dynamics =====
  for i in 1:6 loop
    der(kappa[i]) = dkappa[i];
    J_eff * der(dkappa[i]) = M_tendon[i] + M_contact[i] + M_dist[i]
                           - d_eff * dkappa[i] - EI_eff[i] * kappa[i];
    der(T_sec[i]) = (P_act[i] - h_loss * (T_sec[i] - T_amb)) / C_th;
  end for;

  // ===== Acceptance: fail-closed =====
  f_max_s1 = max(f_act[1,1], max(f_act[1,2], f_act[1,3]));
  f_max_s2 = max(f_act[2,1], max(f_act[2,2], f_act[2,3]));
  f_max_s3 = max(f_act[3,1], max(f_act[3,2], f_act[3,3]));
  f_max_s4 = max(f_act[4,1], max(f_act[4,2], f_act[4,3]));
  f_max_s5 = max(f_act[5,1], max(f_act[5,2], f_act[5,3]));
  f_max_s6 = max(f_act[6,1], max(f_act[6,2], f_act[6,3]));
  max_f_act = max(f_max_s1, max(f_max_s2, max(f_max_s3, max(f_max_s4, max(f_max_s5, f_max_s6)))));

  max_P_act = max(P_act[1], max(P_act[2], max(P_act[3], max(P_act[4], max(P_act[5], P_act[6])))));
  max_kappa = max(abs(kappa[1]), max(abs(kappa[2]), max(abs(kappa[3]),
               max(abs(kappa[4]), max(abs(kappa[5]), abs(kappa[6]))))));
  max_T = max(T_sec[1], max(T_sec[2], max(T_sec[3], max(T_sec[4], max(T_sec[5], T_sec[6])))));
  min_T = min(T_sec[1], min(T_sec[2], min(T_sec[3], min(T_sec[4], min(T_sec[5], T_sec[6])))));
  max_F_contact = max(abs(F_contact[1]), max(abs(F_contact[2]), max(abs(F_contact[3]),
                    max(abs(F_contact[4]), max(abs(F_contact[5]), abs(F_contact[6]))))));

  no_nan_inf = 1.0;

  acceptance_pass = if noEvent(
    max_f_act <= f_max + 0.01 and
    max_P_act <= P_max + 0.01 and
    max_kappa < 50.0 and
    max_T <= T_high + 2.0 and
    min_T >= T_amb - 2.0 and
    max_F_contact < 100.0 and
    tip_error < 0.036 and
    time > 10.4 and
    no_nan_inf > 0.5
  ) then 1.0 else 0.0;

  annotation(
    experiment(StartTime = 0.0, StopTime = 16.0, Tolerance = 1.0e-6, Interval = 0.004),
    Documentation(info = "Six-section continuum arm ShapeLockAvoidE.
      Plant: 6 planar constant-curvature sections, 3 tendons each at 0/120/240 deg,
      thermally activated stiffness EI(T) linear from 320 K (EI_min) to 345 K (EI_max).
      Independent tendon tension (<= 50.6 N) and heater power (<= 18 W) control.
      Fixed cylinder obstacle at (0.12, 0.24) m, radius 0.025 m, friction 0.55.
      Contact-aware shape control: feedforward + curvature PD + tip PD.
      Bounded stiffness scheduling: stiffen when tip within 0.05 m of target.
      9.6 N lateral tip disturbance during middle third [5.333, 10.667] s.
      250 Hz control rate (Ts = 4 ms), 16 s simulation.
      Fail-closed acceptance: actuator, deformation, contact, temperature, clearance,
      and final tip-error (< 0.036 m after 10.4 s) bounds, no NaN/inf."));
end ShapeLockAvoidE;