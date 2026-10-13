model HydMotorTrackA
  "Bidirectional hydraulic motor driving rotary table through 12:1 gearbox
   with feedforward flow control and pressure-position feedback, sampled at 80 Hz"

  // ===== Given parameters =====
  parameter Real D_motor   = 48e-6    "Motor displacement [m3/rev]";
  parameter Real eta_v     = 0.92     "Volumetric efficiency [-]";
  parameter Real m_table   = 130.0    "Table mass [kg]";
  parameter Real N_gear    = 12.0     "Gearbox ratio [-]";
  parameter Real Q_cmd_max = 0.001    "Command magnitude limit [m3/s]";
  parameter Real F_dist    = 110.0    "Payload disturbance force [N]";
  parameter Real t_end     = 8.0      "Scenario duration [s]";
  parameter Real f_sample  = 80.0     "Control sample rate [Hz]";

  final parameter Real t_dist_start = t_end / 3.0      "Disturbance start [s]";
  final parameter Real t_dist_end   = 2.0 * t_end / 3.0 "Disturbance end [s]";
  final parameter Real dt_sample    = 1.0 / f_sample    "Sample period [s]";

  // ===== Unknown parameters (placeholder values — not specified in request) =====
  parameter Real p_supply  = 200.0e5  "Supply pressure [Pa] — unspecified";
  parameter Real p_return  = 5.0e5   "Return line pressure [Pa] — unspecified";
  parameter Real p_relief  = 210.0e5 "Relief valve crack pressure [Pa] — unspecified";
  parameter Real B_oil     = 1.6e9   "Oil bulk modulus [Pa] — unspecified";
  parameter Real V_line    = 5.0e-4  "Line volume per chamber [m3] — unspecified";
  parameter Real b_visc    = 1.5     "Viscous friction at motor [Nms/rad] — unspecified";
  parameter Real r_table   = 0.30    "Table effective radius [m] — unspecified";
  parameter Real k_leak    = 1.0e-13 "Internal leakage coeff [m3/(s.Pa)] — unspecified";
  parameter Real k_relief  = 5.0e-11 "Relief valve conductance [m3/(s.Pa)] — unspecified";
  parameter Real k_return  = 1.0e-10 "Return line conductance [m3/(s.Pa)] — unspecified";
  parameter Real J_motor   = 1.0e-3  "Motor rotor inertia [kg.m2] — unspecified";
  parameter Real x_target1 = 0.25    "Segment-1 target position [m] — unspecified";
  parameter Real x_target2 = 0.50    "Segment-2 target position [m] — unspecified";
  parameter Real t_seg1_end = 3.5    "End of first trajectory segment [s] — unspecified";
  parameter Real Kp_pos    = 0.008   "Position feedback gain [(m3/s)/m] — unspecified";
  parameter Real Kd_pos    = 0.001   "Velocity feedback gain [(m3/s)/(m/s)] — unspecified";
  parameter Real Kp_pres   = 1.0e-10 "Pressure feedback gain [(m3/s)/Pa] — unspecified";

  // ===== Derived constants (all denominators guaranteed nonzero) =====
  final parameter Real D_motor_rad = D_motor / (2.0 * Modelica.Constants.pi)
    "Displacement [m3/rad]";
  final parameter Real J_table = 0.5 * m_table * r_table * r_table
    "Table inertia (uniform disk) [kg.m2]";
  final parameter Real J_total = J_motor + J_table / (N_gear * N_gear)
    "Total reflected inertia at motor shaft [kg.m2]";
  final parameter Real T_dist_motor = F_dist * r_table / N_gear
    "Disturbance torque reflected to motor [N.m]";

  // ===== Dynamic states =====
  Real theta_motor(start = 0.0) "Motor angular position [rad]";
  Real omega_motor(start = 0.0) "Motor angular velocity [rad/s]";
  Real pA(start = 5.0e5)        "Chamber A pressure [Pa]";
  Real pB(start = 5.0e5)        "Chamber B pressure [Pa]";

  // ===== Discrete controller output =====
  discrete Real Q_cmd(start = 0.0) "Sampled and limited flow command [m3/s]";

  // ===== Outputs (FMI export) =====
  output Real x_pos          "Table linear position [m]";
  output Real x_vel          "Table linear velocity [m/s]";
  output Real x_acc          "Table linear acceleration [m/s2]";
  output Real p_chamber      "Motor differential pressure pA-pB [Pa]";
  output Real pA_out         "Chamber A pressure [Pa]";
  output Real pB_out         "Chamber B pressure [Pa]";
  output Real Q_supply_flow  "Supply (pump) flow [m3/s]";
  output Real Q_cmd_out      "Flow command [m3/s]";
  output Real x_traj         "Trajectory reference [m]";
  output Real x_err          "Tracking error [m]";
  output Real F_payload      "Active payload disturbance force [N]";
  output Real Q_relief       "Relief valve flow [m3/s]";
  output Real T_motor_out    "Motor torque [N.m]";
  output Real omega_motor_out "Motor angular velocity [rad/s]";

  // ===== Intermediate variables =====
  Real Q_leak      "Leakage flow [m3/s]";
  Real Q_A         "Flow consumed from chamber A [m3/s]";
  Real Q_B         "Flow produced into chamber B [m3/s]";
  Real T_motor     "Motor torque [N.m]";
  Real Q_ff        "Feedforward flow [m3/s]";
  Real Q_fb        "Feedback flow (position + velocity + pressure) [m3/s]";
  Real Q_cmd_raw   "Continuous unlimited command [m3/s]";
  Real omega_des   "Desired motor speed [rad/s]";
  Real x_vel_des   "Desired linear velocity [m/s]";
  Real alpha_motor "Motor angular acceleration [rad/s2]";
  Real dist_active "Disturbance active flag [0 or 1]";

  // ===== Bound monitors =====
  output Real bound_travel   "Travel magnitude [m]";
  output Real bound_pressure "Peak chamber pressure [Pa]";
  output Real bound_flow     "Flow magnitude [m3/s]";
  output Real bound_accel    "Acceleration magnitude [m/s2]";
  output Real bound_traj_err "Trajectory error magnitude [m]";
  output Real bound_relief_q "Relief valve flow magnitude [m3/s]";

equation

  // ===== Kinematic relations: motor angle -> linear table position =====
  x_pos = r_table * theta_motor / N_gear;
  x_vel = r_table * omega_motor / N_gear;
  x_acc = r_table * alpha_motor / N_gear;

  // ===== Two-segment smooth trajectory (cosine blend) =====
  x_traj = if time <= 0.0 then
             0.0
           elseif time <= t_seg1_end then
             0.5 * x_target1 * (1.0 - Modelica.Math.cos(Modelica.Constants.pi * time / t_seg1_end))
           else
             x_target1 + 0.5 * (x_target2 - x_target1) *
               (1.0 - Modelica.Math.cos(Modelica.Constants.pi * (time - t_seg1_end) / (t_end - t_seg1_end)));

  x_vel_des = if time <= 0.0 then
                0.0
              elseif time <= t_seg1_end then
                0.5 * x_target1 * Modelica.Constants.pi / t_seg1_end *
                  Modelica.Math.sin(Modelica.Constants.pi * time / t_seg1_end)
              else
                0.5 * (x_target2 - x_target1) * Modelica.Constants.pi / (t_end - t_seg1_end) *
                  Modelica.Math.sin(Modelica.Constants.pi * (time - t_seg1_end) / (t_end - t_seg1_end));

  omega_des = N_gear * x_vel_des / r_table;

  // ===== Tracking error =====
  x_err = x_traj - x_pos;

  // ===== Feedforward flow control + pressure-position feedback =====
  Q_ff = D_motor_rad * omega_des / eta_v;
  Q_fb = Kp_pos * x_err + Kd_pos * (x_vel_des - x_vel) - Kp_pres * (pA - pB);
  Q_cmd_raw = Q_ff + Q_fb;

  // ===== Sampled and limited command at 80 Hz (zero-order hold) =====
  when sample(0, dt_sample) then
    Q_cmd = if (Q_cmd_raw > Q_cmd_max) then Q_cmd_max
            elseif (Q_cmd_raw < -Q_cmd_max) then -Q_cmd_max
            else Q_cmd_raw;
  end when;

  // ===== Supply flow =====
  Q_supply_flow = Q_cmd;

  // ===== Relief valve (supply-side pressure limiting) =====
  Q_relief = if (pA > p_relief) then k_relief * (pA - p_relief) else 0.0;

  // ===== Internal leakage =====
  Q_leak = k_leak * (pA - pB);

  // ===== Motor internal flows with volumetric efficiency =====
  Q_A = D_motor_rad * omega_motor / eta_v + Q_leak;
  Q_B = D_motor_rad * omega_motor / eta_v - Q_leak;

  // ===== Chamber pressure dynamics (fluid compressibility) =====
  der(pA) = B_oil / V_line * (Q_cmd - Q_relief - Q_A);
  der(pB) = B_oil / V_line * (Q_B - Q_cmd + k_return * (p_return - pB));

  // ===== Motor torque =====
  T_motor = D_motor_rad * (pA - pB);

  // ===== Finite-duration payload disturbance (middle third of scenario) =====
  dist_active = if (time >= t_dist_start and time <= t_dist_end) then 1.0 else 0.0;
  F_payload = F_dist * dist_active;

  // ===== Equation of motion =====
  alpha_motor = (T_motor - b_visc * omega_motor - T_dist_motor * dist_active) / J_total;
  der(omega_motor) = alpha_motor;
  der(theta_motor) = omega_motor;

  // ===== Output aliases =====
  p_chamber      = pA - pB;
  pA_out         = pA;
  pB_out         = pB;
  Q_cmd_out      = Q_cmd;
  T_motor_out    = T_motor;
  omega_motor_out = omega_motor;

  // ===== Bound monitors =====
  bound_travel   = abs(x_pos);
  bound_pressure = if pA > pB then pA else pB;
  bound_flow     = abs(Q_cmd);
  bound_accel    = abs(x_acc);
  bound_traj_err = abs(x_err);
  bound_relief_q = abs(Q_relief);

  // ===== Requirement enforcement: tracking error below 0.024 m after 5.2 s =====
  assert(time < 5.2 or abs(x_err) < 0.024,
    "Tracking error exceeds 0.024 m after 5.2 s",
    level = AssertionLevel.warning);

  annotation (
    experiment(StartTime = 0, StopTime = 8, Tolerance = 1e-6, Interval = 0.0125),
    Documentation(info = "Hydraulic motor actuator with 48 cm3/rev displacement, 0.92 volumetric
      efficiency, 12:1 gearbox, 130 kg rotary table, 80 Hz sampled feedforward flow control with
      pressure-position feedback. Two-segment cosine trajectory with 110 N payload disturbance
      during middle third (2.667 s to 5.333 s). All parameters not specified in the original
      requirement are marked as unspecified."));
end HydMotorTrackA;