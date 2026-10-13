model TorqueObserverObserveC
  "Robotic disturbance torque observer with low-pass residual filtering: estimates external torque during a finite load interval while holding commanded state"

  // ===== Link parameters (from requirement) =====
  parameter Real L_link = 0.58 "Link length [m]";
  parameter Real m_link = 8.0  "Link mass [kg]";
  parameter Real J_link = (1.0/3.0)*m_link*L_link*L_link
    "Link inertia about joint axis [kg.m2] (rod approximation; capsule radius unknown)";
  parameter Real g_acc = 9.81 "Gravitational acceleration [m/s2]";
  parameter Real N_gear = 70.0 "Gearbox ratio [-]";

  // ===== Motor parameters (assumed; not stated in requirement) =====
  parameter Real Kt = 0.1       "Motor torque constant [N.m/A]";
  parameter Real Ke = 0.1       "Back-EMF constant [V.s/rad]";
  parameter Real R_motor = 0.5  "Motor winding resistance [Ohm]";
  parameter Real L_motor = 1.0e-3 "Motor winding inductance [H]";
  parameter Real J_motor = 1.0e-4 "Motor rotor inertia [kg.m2]";
  parameter Real b_motor = 1.0e-4 "Motor viscous friction [N.m.s/rad]";
  parameter Real b_link = 1.0e-3 "Link viscous friction [N.m.s/rad]";
  parameter Real V_max = 48.0   "Motor drive voltage limit [V]";
  parameter Real i_max = 40.0   "Motor drive current limit [A]";

  // ===== Controller =====
  parameter Real Kp_pos = 500.0 "Position proportional gain";
  parameter Real Kd_vel = 50.0  "Velocity derivative gain";
  parameter Real tau_max_cmd = 69.0 "Maximum command magnitude [N.m] at gearbox output";
  parameter Real theta_cmd_val = 0.0 "Commanded joint angle (hold setpoint) [rad]";

  // ===== Disturbance profile =====
  parameter Real tau_dist_mag = 12.6 "Disturbance torque magnitude [N.m]";
  parameter Real t_dist_on = 4.0  "Disturbance onset time [s] (start of middle third of 12 s)";
  parameter Real t_dist_off = 8.0 "Disturbance removal time [s] (end of middle third)";
  parameter Real r_load = L_link/2.0 "Declared body location of deterministic load [m] (link COM)";

  // ===== Observer =====
  parameter Real w_obs = 31.4  "Observer velocity-filter bandwidth [rad/s] (~5 Hz)";
  parameter Real w_res = 62.8  "Residual low-pass filter bandwidth [rad/s] (~10 Hz)";
  parameter Real J_nom = J_link "Nominal link inertia used by observer [kg.m2]";

  // ===== Simulation =====
  parameter Real Ts = 1.0/125.0 "Sampling period [s]";
  parameter Real T_end = 12.0   "Total simulation duration [s]";

  // ===== Dynamic states =====
  Real theta(start = 0.0, fixed = true) "Joint angle [rad]";
  Real omega(start = 0.0, fixed = true) "Joint angular velocity [rad/s]";
  Real i_motor(start = 0.0, fixed = true) "Motor armature current [A]";
  Real omega_filt(start = 0.0, fixed = true) "Observer filtered velocity [rad/s]";
  Real d_hat(start = 0.0, fixed = true) "Estimated disturbance torque [N.m]";

  // ===== Algebraic / computed signals =====
  Real alpha "True joint angular acceleration [rad/s2]";
  Real alpha_hat "Observer estimated acceleration [rad/s2]";
  Real V_drive "Unsaturated motor voltage command [V]";
  Real V_sat "Saturated motor voltage [V]";
  Real i_cmd "Commanded motor current [A]";
  Real i_sat "Current-limited motor current command [A]";
  Real tau_cmd "Unsaturated commanded output torque [N.m]";
  Real tau_cmd_sat "Saturated commanded output torque [N.m]";
  Real tau_motor_out "Motor torque reflected to output side [N.m]";
  Real tau_grav "True gravity torque on link [N.m]";
  Real tau_grav_model "Model-based gravity torque [N.m]";
  Real fric_model "Model-based link friction torque [N.m]";
  Real tau_dist "Applied deterministic disturbance torque [N.m]";
  Real resid "Raw observer residual [N.m]";

  // ===== Sensor traces =====
  Real theta_meas "Joint encoder angle measurement [rad]";
  Real omega_meas "Joint encoder velocity measurement [rad/s]";
  Real i_meas "Motor current sensor reading [A]";
  Real tau_meas "Torque inferred from motor current (wrench-related) [N.m]";

  // ===== Performance / evidence =====
  Real tracking_error "Joint position tracking error [rad]";
  Real est_error "Disturbance estimation error [N.m]";
  Real primary_error "Primary estimation error magnitude [N.m]";
  Real pre_load_residual "Pre-load residual snapshot indicator [N.m]";

equation
  // ---- Disturbance profile: constant 12.6 N.m during middle third (4-8 s), zero otherwise ----
  tau_dist = if (time >= t_dist_on and time < t_dist_off) then tau_dist_mag else 0.0;

  // ---- Gravity torque on link (pivot at one end, COM at L/2) ----
  tau_grav = m_link * g_acc * (L_link / 2.0) * cos(theta);
  tau_grav_model = m_link * g_acc * (L_link / 2.0) * cos(theta_meas);
  fric_model = b_link * omega_meas;

  // ---- Controller: PD position hold with output torque saturation ----
  tracking_error = theta - theta_cmd_val;
  tau_cmd = -(Kp_pos * tracking_error + Kd_vel * omega);
  tau_cmd_sat = max(-tau_max_cmd, min(tau_max_cmd, tau_cmd));

  // ---- Motor drive: torque to current to voltage, with current and voltage limits ----
  i_cmd = tau_cmd_sat / (N_gear * Kt);
  i_sat = max(-i_max, min(i_max, i_cmd));
  V_drive = R_motor * i_sat + Ke * N_gear * omega;
  V_sat = max(-V_max, min(V_max, V_drive));

  // ---- Motor electrical dynamics ----
  L_motor * der(i_motor) = V_sat - R_motor * i_motor - Ke * N_gear * omega;

  // ---- Mechanical dynamics (reflected to output side) ----
  tau_motor_out = N_gear * Kt * i_motor;
  alpha = (tau_motor_out - tau_grav - tau_dist - b_link * omega - b_motor * N_gear * N_gear * omega)
          / (J_link + J_motor * N_gear * N_gear);
  der(theta) = omega;
  der(omega) = alpha;

  // ---- Sensors (synchronized traces) ----
  theta_meas = theta;
  omega_meas = omega;
  i_meas = i_motor;
  tau_meas = N_gear * Kt * i_meas;

  // ============================================================
  //  Model-Based Disturbance Observer with Low-Pass Residual Filter
  // ============================================================
  // Estimated acceleration: derivative of low-pass filtered velocity
  der(omega_filt) = w_obs * (omega_meas - omega_filt);
  alpha_hat = w_obs * (omega_meas - omega_filt);

  // Raw residual: measured input torque minus nominal-model predicted torque
  // resid = tau_meas - J_nom*alpha_hat - tau_grav_model - fric_model
  // If model is accurate and alpha_hat converges to alpha, resid -> tau_dist
  resid = tau_meas - J_nom * alpha_hat - tau_grav_model - fric_model;

  // Low-pass filtered residual => disturbance estimate
  der(d_hat) = w_res * (resid - d_hat);

  // ---- Estimation error and primary metric ----
  est_error = d_hat - tau_dist;
  // Well-defined zero-error branch for norm-as-divisor scenarios
  primary_error = if noEvent(abs(est_error) < 1.0e-12) then 0.0 else abs(est_error);

  // Pre-load residual evidence (residual value before disturbance onset)
  pre_load_residual = if noEvent(time < t_dist_on) then resid else 0.0;

  annotation(
    experiment(
      StartTime = 0,
      StopTime = 12.0,
      Tolerance = 1.0e-6,
      Interval = 1.0/125.0
    ),
    Documentation(info = "TorqueObserverObserveC: disturbance torque observer for a 0.58 m, 8 kg capsule link driven through a 70:1 gearbox. Motor voltage/current limited. Disturbance of 12.6 N.m applied at link COM (r=0.29 m) during middle third (4-8 s) of a 12 s run at 125 Hz. Observer uses model-based residual (current-derived torque minus nominal inertia*estimated_accel minus gravity/friction model) with low-pass filtering. Motor electrical constants assumed (not given in requirement).")
  );
end TorqueObserverObserveC;