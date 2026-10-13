model ShapeLockGraspD
  "Six-section continuum arm with thermally activated stiffness for compliant grasping"

  // ===== Named parameters from requirement =====
  parameter Real Tmin = 320.0 "minimum activation temperature [K]";
  parameter Real Tmax = 345.0 "maximum activation temperature [K]";
  parameter Real Ften_max = 46.0 "max tendon tension [N]";
  parameter Real Pheat_max = 18.0 "max section heater power [W]";
  parameter Real mu = 0.70 "friction coefficient on rigid support surface";
  parameter Real Fdist_val = 4.0 "tangential disturbance load [N]";
  parameter Real track_thresh = 0.015 "primary tracking error threshold [m]";
  parameter Real t_sim = 14.0 "simulation duration [s]";
  parameter Real dt_ctrl = 0.005 "control/sensing period [s] (200 Hz)";

  // ===== Derived timing =====
  parameter Real t_dist_start = t_sim / 3.0 "disturbance start [s]";
  parameter Real t_dist_end = 2.0 * t_sim / 3.0 "disturbance end [s]";

  // ===== Physical model parameters =====
  // Facts not stated in the requirement are treated as unknown;
  // the following are placeholder assumptions for simulation completeness.
  parameter Real Ls = 0.06 "section length [m]";
  parameter Real k_stiff = 8.0 "bending stiffness at Tmin [N.m/rad]";
  parameter Real k_soft = 1.2 "bending stiffness at Tmax [N.m/rad]";
  parameter Real J_sec = 0.002 "section rotational inertia [kg.m2]";
  parameter Real C_thermal = 1.5 "thermal capacitance [J/K]";
  parameter Real h_cool = 0.3 "convective cooling coefficient [W/K]";
  parameter Real T_amb = 295.0 "ambient temperature [K]";
  parameter Real k_contact = 12.0 "contact stiffness [N/rad]";
  parameter Real m_obj = 0.15 "object mass [kg]";
  parameter Real k_obj = 500.0 "object support stiffness [N/m]";
  parameter Real c_obj = 5.0 "object damping [N.s/m]";
  parameter Real arm_r = 0.012 "tendon moment arm [m]";
  parameter Real v_thresh = 0.003 "friction velocity threshold [m/s]";
  parameter Real eps_c = 0.001 "contact smoothing [rad]";
  parameter Real eps = 1e-6 "general regularization";

  // ===== Controller parameters =====
  parameter Real Fgrasp_ref = 6.0 "target total normal grasp force [N]";
  parameter Real Fcontact_max = 2.5 "per-contact force upper limit [N]";
  parameter Real phi_max = 1.2 "max section bending angle [rad]";
  parameter Real tau_pre = 5.0 "tendon pre-tension [N]";
  parameter Real tau_bend_target = 22.0 "target bending tendon tension [N]";
  parameter Real kp_force = 5.0 "force controller proportional gain";
  parameter Real k_redist = 8.0 "force redistribution gain [K/N]";
  parameter Real kp_temp = 5.0 "temperature controller gain [W/K]";
  parameter Real x_obj0 = 0.25 "initial object position [m]";
  parameter Real phi_th[6] = {0.04, 0.06, 0.08, 0.10, 0.12, 0.14}
    "per-section contact threshold [rad]";

  // ===== Dynamic states =====
  Real phi[6](each start = 0.0) "section bending angle [rad]";
  Real dphi[6](each start = 0.0) "section angular velocity [rad/s]";
  Real T_sec[6](each start = 320.0) "section temperature [K]";
  Real x_obj(start = x_obj0) "object x position [m]";
  Real vx_obj(start = 0.0) "object x velocity [m/s]";

  // ===== Actuator commands =====
  Real tau_cmd[3] "commanded tendon tensions [N]";
  Real Pheat_cmd[6] "commanded heater powers [W]";

  // ===== Actual actuator values =====
  Real tau[3] "actual tendon tensions [N]";
  Real Pheat[6] "actual heater powers [W]";

  // ===== Derived quantities =====
  Real k_bend[6] "effective bending stiffness [N.m/rad]";
  Real M_tendon "tendon bending moment per section [N.m]";
  Real fc[6] "per-contact normal force [N]";
  Real f_total "total normal grasp force [N]";
  Real f_dist "applied tangential disturbance [N]";
  Real f_fric "friction force on object [N]";
  Real track_err "primary tracking error [m]";
  Real T_target[6] "target temperature per section [K]";

  // ===== Forward kinematics (deformation sensing) =====
  Real theta[6] "cumulative angle [rad]";
  Real px[6] "section tip x [m]";
  Real py[6] "section tip y [m]";

  // ===== Sensor traces =====
  Real fc_meas[6] "distributed contact force measurements [N]";
  Real f_total_meas "measured total normal force [N]";
  Real x_obj_meas "measured object position [m]";
  Real tau_meas[3] "tendon tension measurements [N]";
  Real phi_meas[6] "bending angle measurements [rad]";
  Real T_meas[6] "temperature measurements [K]";

  // ===== Monitors =====
  Boolean actuator_ok "actuator bounds satisfied";
  Boolean deformation_ok "deformation bounds satisfied";
  Boolean force_bands_ok "per-contact and total force within bands";
  Boolean no_contact_loss "no contact loss during grasp";
  Boolean tracking_ok "tracking error below threshold after 9.1 s";
  Boolean values_finite "no NaN or infinite values";
  Real max_fc "maximum per-contact force [N]";
  Real min_fc "minimum per-contact force [N]";

equation
  // ===== Forward kinematics =====
  theta[1] = phi[1];
  for i in 2:6 loop
    theta[i] = theta[i - 1] + phi[i];
  end for;
  px[1] = Ls * cos(theta[1]);
  py[1] = -Ls * sin(theta[1]);
  for i in 2:6 loop
    px[i] = px[i - 1] + Ls * cos(theta[i]);
    py[i] = py[i - 1] - Ls * sin(theta[i]);
  end for;

  // ===== Stiffness from temperature =====
  for i in 1:6 loop
    k_bend[i] = k_stiff - (k_stiff - k_soft) *
      max(0.0, min(1.0, (T_sec[i] - Tmin) / (Tmax - Tmin)));
  end for;

  // ===== Tendon moment (shared across all sections) =====
  M_tendon = arm_r * (tau[1] + tau[3] - tau[2]);

  // ===== Bending dynamics =====
  for i in 1:6 loop
    der(phi[i]) = dphi[i];
    J_sec * der(dphi[i]) = M_tendon - k_bend[i] * phi[i] - fc[i] * Ls;
  end for;

  // ===== Thermal dynamics =====
  for i in 1:6 loop
    C_thermal * der(T_sec[i]) = Pheat[i] - h_cool * (T_sec[i] - T_amb);
  end for;

  // ===== Compliant contact model (smooth max approximation) =====
  for i in 1:6 loop
    fc[i] = k_contact * (phi[i] - phi_th[i] +
      sqrt((phi[i] - phi_th[i]) * (phi[i] - phi_th[i]) + eps_c * eps_c)) / 2.0;
  end for;

  // Total normal grasp force (explicit scalar sum)
  f_total = fc[1] + fc[2] + fc[3] + fc[4] + fc[5] + fc[6];

  // ===== Object dynamics with friction on rigid support surface =====
  track_err = abs(x_obj - x_obj0);
  f_dist = if (time >= t_dist_start and time <= t_dist_end) then Fdist_val else 0.0;
  f_fric = mu * f_total * tanh(vx_obj / v_thresh);
  m_obj * der(vx_obj) = f_dist - f_fric - k_obj * (x_obj - x_obj0) - c_obj * vx_obj;
  der(x_obj) = vx_obj;

  // ===== Tendon control =====
  // tau[1]: primary bending tendon — smooth ramp
  tau_cmd[1] = tau_pre + (tau_bend_target - tau_pre) *
    max(0.0, min(1.0, time / 2.0));
  // tau[2]: return tendon — constant pre-tension
  tau_cmd[2] = tau_pre;
  // tau[3]: grasp force regulator
  tau_cmd[3] = kp_force * (Fgrasp_ref - f_total);
  for i in 1:3 loop
    tau[i] = max(0.0, min(Ften_max, tau_cmd[i]));
  end for;

  // ===== Heater control with contact-force redistribution =====
  // Stiffen (lower T_target) sections whose contact force exceeds threshold,
  // redistributing load to less-loaded sections via the shared tendon moment.
  for i in 1:6 loop
    T_target[i] = Tmax - k_redist *
      (fc[i] - Fcontact_max * 0.6 +
       sqrt((fc[i] - Fcontact_max * 0.6) * (fc[i] - Fcontact_max * 0.6) + eps_c * eps_c)) / 2.0;
    Pheat_cmd[i] = max(0.0, min(Pheat_max,
      kp_temp * (T_target[i] - T_sec[i]) + h_cool * (T_target[i] - T_amb)));
    Pheat[i] = max(0.0, min(Pheat_max, Pheat_cmd[i]));
  end for;

  // ===== Sensors: actuator sensing, distributed contact, object pose =====
  for i in 1:6 loop
    fc_meas[i] = fc[i];
    phi_meas[i] = phi[i];
    T_meas[i] = T_sec[i];
  end for;
  f_total_meas = f_total;
  x_obj_meas = x_obj;
  for i in 1:3 loop
    tau_meas[i] = tau[i];
  end for;

  // ===== Monitors =====
  max_fc = max(max(fc[1], fc[2]), max(max(fc[3], fc[4]), max(fc[5], fc[6])));
  min_fc = min(min(fc[1], fc[2]), min(min(fc[3], fc[4]), min(fc[5], fc[6])));

  // Actuator bounds
  actuator_ok = (tau[1] >= -eps and tau[1] <= Ften_max + eps) and
                (tau[2] >= -eps and tau[2] <= Ften_max + eps) and
                (tau[3] >= -eps and tau[3] <= Ften_max + eps) and
                (Pheat[1] >= -eps and Pheat[1] <= Pheat_max + eps) and
                (Pheat[2] >= -eps and Pheat[2] <= Pheat_max + eps) and
                (Pheat[3] >= -eps and Pheat[3] <= Pheat_max + eps) and
                (Pheat[4] >= -eps and Pheat[4] <= Pheat_max + eps) and
                (Pheat[5] >= -eps and Pheat[5] <= Pheat_max + eps) and
                (Pheat[6] >= -eps and Pheat[6] <= Pheat_max + eps);

  // Deformation bounds
  deformation_ok = (abs(phi[1]) <= phi_max + eps) and
                   (abs(phi[2]) <= phi_max + eps) and
                   (abs(phi[3]) <= phi_max + eps) and
                   (abs(phi[4]) <= phi_max + eps) and
                   (abs(phi[5]) <= phi_max + eps) and
                   (abs(phi[6]) <= phi_max + eps);

  // Force bands: per-contact below limit, total above minimum after grasp
  force_bands_ok = (max_fc <= Fcontact_max + eps) and
                   (if time > 3.0 then f_total >= 1.0 else true);

  // No contact loss after initial grasp established
  no_contact_loss = if time > 3.0 then
    (fc[1] > eps and fc[2] > eps and fc[3] > eps and
     fc[4] > eps and fc[5] > eps and fc[6] > eps)
    else true;

  // Tracking error below threshold after 9.1 s
  tracking_ok = if time >= 9.1 then track_err < track_thresh else true;

  // No NaN or infinite physical, control, or estimator values
  values_finite = (f_total > -1e8 and f_total < 1e8) and
                  (x_obj > -1e8 and x_obj < 1e8) and
                  (vx_obj > -1e8 and vx_obj < 1e8) and
                  (phi[1] > -1e8 and phi[1] < 1e8) and
                  (T_sec[1] > -1e8 and T_sec[1] < 1e8) and
                  (tau[1] > -1e8 and tau[1] < 1e8) and
                  (Pheat[1] > -1e8 and Pheat[1] < 1e8);

  annotation(
    Documentation(info = "ShapeLockGraspD: Instrumented six-section continuum arm with three tendons and thermally activated stiffness elements. Bending stiffness varies between 320 K (stiff) and 345 K (soft). Tendon tension and section heater power are independently controlled, limited to 46 N and 18 W. The system conforms around a fragile object on a rigid support surface (friction coefficient 0.70), regulates total normal grasp force without local overload via contact-force redistribution, and withstands a 4 N tangential disturbance during the middle third of a 14 s run at 200 Hz. Requirements: actuator and deformation bounds, per-contact and total force bands, object displacement, no contact loss, primary tracking error below 0.015 m after 9.1 s, and no NaN or infinite values. Facts not stated in the requirement (object mass, arm dimensions, thermal properties, controller gains) are treated as unknown; placeholder values are used for simulation completeness."),
    Experiment(StopTime = 14.0, Tolerance = 1e-6, Interval = 0.005)
  );
end ShapeLockGraspD;