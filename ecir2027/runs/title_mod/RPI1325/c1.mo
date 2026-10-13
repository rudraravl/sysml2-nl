model TendonSoftShapeE
  parameter Real L_total = 0.55 "Total body length [m]";
  parameter Real L_sec = L_total / 6.0 "Per-section length [m]";
  parameter Real T_max_cmd = 46.2 "Max command magnitude per tendon [N]";
  parameter Real F_tip_load = 7.2 "Tip load disturbance [N]";
  parameter Real t_sim = 16.0 "Simulation duration [s]";
  parameter Real t_settle = 10.4 "Tracking error acceptance time [s]";
  parameter Real e_bound = 0.041 "Primary tracking error bound [m]";

  parameter Real r_tendon = 0.03 "Tendon moment arm radius [m]";
  parameter Real EI_stiff = 0.05 "Flexural rigidity [N.m^2]";
  parameter Real tau_sec = 0.2 "Section curvature time constant [s]";
  parameter Real tau_act = 0.05 "Actuator time constant [s]";
  parameter Real rho_l = 0.05 "Linear mass density [kg/m]";
  parameter Real g = 9.81 "Gravitational acceleration [m/s^2]";
  parameter Real T_amb = 293.15 "Ambient temperature [K]";
  parameter Real k_heat = 0.0001 "Heating coefficient [K/(N^2.s)]";
  parameter Real k_cool = 0.02 "Cooling coefficient [1/s]";
  parameter Real T_max_safe = 343.15 "Max safe temperature [K]";
  parameter Real kappa_safe = 8.0 "Max safe curvature [1/m]";
  parameter Real Kp_ctrl = 10.0 "Controller proportional gain [N/m]";
  parameter Real T_bias = 23.1 "Tendon bias tension [N]";
  parameter Real kappa_tgt[6] = {0.3, 0.25, 0.2, 0.15, 0.1, 0.05}
    "Target section curvatures [1/m]";

  Real kappa[6] "Section curvatures [1/m]";
  Real T_act[3] "Actuated tendon tensions [N]";
  Real temp "Body temperature [K]";

  Real theta_a[7] "Actual cumulative tangent angle [rad]";
  Real x_a[7] "Actual joint x [m]";
  Real z_a[7] "Actual joint z [m]";

  Real theta_t[7] "Target cumulative tangent angle [rad]";
  Real x_t[7] "Target joint x [m]";
  Real z_t[7] "Target joint z [m]";

  Real x_u[7] "Undeformed joint x [m]";
  Real z_u[7] "Undeformed joint z [m]";

  Real fsm "0=INIT, 1=CONTROL, 2=HOLD";
  Real T_cmd[3] "Commanded tendon tensions [N]";
  Real T_raw[3] "Unsaturated tendon commands [N]";
  Real T_meas[3] "Measured tendon tensions [N]";
  Real kappa_meas[6] "Measured curvatures [1/m]";
  Real M_tendon "Net tendon bending moment [N.m]";
  Real M_grav[6] "Gravity moment per section [N.m]";
  Real M_dist[6] "Disturbance moment per section [N.m]";
  Real M_total[6] "Total moment per section [N.m]";
  Real kappa_eq[6] "Equilibrium curvature [1/m]";
  Real M_ff "Feedforward moment [N.m]";
  Real M_fb "Feedback moment [N.m]";
  Real M_cmd "Commanded moment [N.m]";

  Real x_tip "Measured tip x [m]";
  Real z_tip "Measured tip z [m]";
  Real theta_tip "Measured tip angle [rad]";
  Real x_tip_des "Desired tip x [m]";
  Real z_tip_des "Desired tip z [m]";
  Real tip_err_x "Tip error x [m]";
  Real tip_err_z "Tip error z [m]";
  Real tip_error "Tip tracking error magnitude [m]";
  Real F_dist_active "Active disturbance force [N]";

  Boolean actuator_ok;
  Boolean curvature_ok;
  Boolean temperature_ok;
  Boolean fsm_ok;
  Boolean shape_ok;
  Boolean no_nan_inf;
  Boolean fail_closed;

initial equation
  for i in 1:6 loop
    kappa[i] = 0.0;
  end for;
  for j in 1:3 loop
    T_act[j] = 0.0;
  end for;
  temp = T_amb;

equation
  fsm = if time < 1.0 then 0.0 else if time < t_settle then 1.0 else 2.0;

  x_u[1] = 0.0;
  z_u[1] = 0.0;
  for i in 2:7 loop
    x_u[i] = 0.0;
    z_u[i] = z_u[i-1] + L_sec;
  end for;

  theta_a[1] = 0.0;
  x_a[1] = 0.0;
  z_a[1] = 0.0;
  for i in 1:6 loop
    theta_a[i+1] = theta_a[i] + kappa[i] * L_sec;
    x_a[i+1] = x_a[i] + (if abs(kappa[i]) < 1.0e-8 then
                L_sec * sin(theta_a[i])
              else
                (cos(theta_a[i]) - cos(theta_a[i+1])) / kappa[i]);
    z_a[i+1] = z_a[i] + (if abs(kappa[i]) < 1.0e-8 then
                L_sec * cos(theta_a[i])
              else
                (sin(theta_a[i+1]) - sin(theta_a[i])) / kappa[i]);
  end for;

  theta_t[1] = 0.0;
  x_t[1] = 0.0;
  z_t[1] = 0.0;
  for i in 1:6 loop
    theta_t[i+1] = theta_t[i] + kappa_tgt[i] * L_sec;
    x_t[i+1] = x_t[i] + (if abs(kappa_tgt[i]) < 1.0e-8 then
                L_sec * sin(theta_t[i])
              else
                (cos(theta_t[i]) - cos(theta_t[i+1])) / kappa_tgt[i]);
    z_t[i+1] = z_t[i] + (if abs(kappa_tgt[i]) < 1.0e-8 then
                L_sec * cos(theta_t[i])
              else
                (sin(theta_t[i+1]) - sin(theta_t[i])) / kappa_tgt[i]);
  end for;

  x_tip = x_a[7];
  z_tip = z_a[7];
  theta_tip = theta_a[7];
  x_tip_des = x_t[7];
  z_tip_des = z_t[7];

  F_dist_active = if (time >= t_sim / 3.0 and time <= 2.0 * t_sim / 3.0) then F_tip_load else 0.0;

  M_grav[1] = g * rho_l * L_sec * ((x_a[1]+x_a[2])/2.0 + (x_a[2]+x_a[3])/2.0 + (x_a[3]+x_a[4])/2.0 + (x_a[4]+x_a[5])/2.0 + (x_a[5]+x_a[6])/2.0 + (x_a[6]+x_a[7])/2.0 - 6.0*x_a[1]);
  M_grav[2] = g * rho_l * L_sec * ((x_a[2]+x_a[3])/2.0 + (x_a[3]+x_a[4])/2.0 + (x_a[4]+x_a[5])/2.0 + (x_a[5]+x_a[6])/2.0 + (x_a[6]+x_a[7])/2.0 - 5.0*x_a[2]);
  M_grav[3] = g * rho_l * L_sec * ((x_a[3]+x_a[4])/2.0 + (x_a[4]+x_a[5])/2.0 + (x_a[5]+x_a[6])/2.0 + (x_a[6]+x_a[7])/2.0 - 4.0*x_a[3]);
  M_grav[4] = g * rho_l * L_sec * ((x_a[4]+x_a[5])/2.0 + (x_a[5]+x_a[6])/2.0 + (x_a[6]+x_a[7])/2.0 - 3.0*x_a[4]);
  M_grav[5] = g * rho_l * L_sec * ((x_a[5]+x_a[6])/2.0 + (x_a[6]+x_a[7])/2.0 - 2.0*x_a[5]);
  M_grav[6] = g * rho_l * L_sec * ((x_a[6]+x_a[7])/2.0 - x_a[6]);

  for i in 1:6 loop
    M_dist[i] = F_dist_active * (x_a[7] - x_a[i]);
  end for;

  M_tendon = r_tendon * (T_act[1] - 0.5 * T_act[2] - 0.5 * T_act[3]);

  for i in 1:6 loop
    M_total[i] = M_tendon + M_grav[i] + M_dist[i];
    kappa_eq[i] = M_total[i] / EI_stiff;
  end for;

  for i in 1:6 loop
    tau_sec * der(kappa[i]) = kappa_eq[i] - kappa[i];
  end for;

  for j in 1:3 loop
    tau_act * der(T_act[j]) = T_cmd[j] - T_act[j];
  end for;

  der(temp) = k_heat * (T_act[1]*T_act[1] + T_act[2]*T_act[2] + T_act[3]*T_act[3]) - k_cool * (temp - T_amb);

  for j in 1:3 loop
    T_meas[j] = T_act[j];
  end for;
  for i in 1:6 loop
    kappa_meas[i] = kappa[i];
  end for;

  tip_err_x = x_tip_des - x_tip;
  tip_err_z = z_tip_des - z_tip;
  tip_error = sqrt(tip_err_x * tip_err_x + tip_err_z * tip_err_z);

  M_ff = (EI_stiff * (kappa_tgt[1] + kappa_tgt[2] + kappa_tgt[3] + kappa_tgt[4] + kappa_tgt[5] + kappa_tgt[6])
          - (M_grav[1] + M_grav[2] + M_grav[3] + M_grav[4] + M_grav[5] + M_grav[6])
          - (M_dist[1] + M_dist[2] + M_dist[3] + M_dist[4] + M_dist[5] + M_dist[6])) / 6.0;

  M_fb = Kp_ctrl * tip_err_x;
  M_cmd = M_ff + M_fb;

  T_raw[1] = T_bias + M_cmd / (2.0 * r_tendon);
  T_raw[2] = T_bias - M_cmd / (2.0 * r_tendon);
  T_raw[3] = T_bias - M_cmd / (2.0 * r_tendon);

  T_cmd[1] = if fsm < 0.5 then 0.0
             else if T_raw[1] < 0.0 then 0.0
             else if T_raw[1] > T_max_cmd then T_max_cmd
             else T_raw[1];
  T_cmd[2] = if fsm < 0.5 then 0.0
             else if T_raw[2] < 0.0 then 0.0
             else if T_raw[2] > T_max_cmd then T_max_cmd
             else T_raw[2];
  T_cmd[3] = if fsm < 0.5 then 0.0
             else if T_raw[3] < 0.0 then 0.0
             else if T_raw[3] > T_max_cmd then T_max_cmd
             else T_raw[3];

  actuator_ok = (T_cmd[1] >= 0.0 and T_cmd[1] <= T_max_cmd) and
                (T_cmd[2] >= 0.0 and T_cmd[2] <= T_max_cmd) and
                (T_cmd[3] >= 0.0 and T_cmd[3] <= T_max_cmd);

  curvature_ok = (abs(kappa[1]) <= kappa_safe) and (abs(kappa[2]) <= kappa_safe) and
                 (abs(kappa[3]) <= kappa_safe) and (abs(kappa[4]) <= kappa_safe) and
                 (abs(kappa[5]) <= kappa_safe) and (abs(kappa[6]) <= kappa_safe);

  temperature_ok = temp <= T_max_safe;
  fsm_ok = (fsm >= 0.0) and (fsm <= 2.0);
  shape_ok = if time >= t_settle then (tip_error < e_bound) else true;

  no_nan_inf = (abs(x_tip) < 1.0e6) and (abs(z_tip) < 1.0e6) and
               (temp > 0.0) and (temp < 1.0e6) and
               (abs(kappa[1]) < 1.0e6) and (abs(kappa[2]) < 1.0e6) and
               (abs(kappa[3]) < 1.0e6) and (abs(kappa[4]) < 1.0e6) and
               (abs(kappa[5]) < 1.0e6) and (abs(kappa[6]) < 1.0e6) and
               (abs(T_act[1]) < 1.0e6) and (abs(T_act[2]) < 1.0e6) and (abs(T_act[3]) < 1.0e6);

  fail_closed = actuator_ok and curvature_ok and temperature_ok and fsm_ok and shape_ok and no_nan_inf;

  annotation(experiment(StopTime = 16.0, StartTime = 0.0, Tolerance = 1.0e-6, Interval = 0.004));
end TendonSoftShapeE;