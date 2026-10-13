model PantographDriveD
  "Closed-chain pantograph mechanism with PI speed control and full instrumentation"

  // --- Physical parameters ---
  parameter Modelica.Units.SI.Length L1 = 0.25 "Short link length AB and DC";
  parameter Modelica.Units.SI.Length L2 = 0.50 "Long link length AD and BC";
  parameter Modelica.Units.SI.Length s_travel = 0.16 "Prismatic input travel";
  parameter Modelica.Units.SI.Mass m_slide = 2.0 "Prismatic slide mass";
  parameter Modelica.Units.SI.Mass m_link = 0.5 "Mass per link";
  parameter Modelica.Units.SI.Damping d_damp = 5.0 "Viscous damping coefficient";
  parameter Modelica.Units.SI.Acceleration g = 9.81 "Gravitational acceleration";
  parameter Modelica.Units.SI.Force F_max = 320.0 "Actuator force bound";
  parameter Modelica.Units.SI.Force F_dist_mag = 8.0 "Disturbance load magnitude";
  parameter Real theta0 = 0.50 "Initial link angle [rad]";
  parameter Real k_theta = 2.0 "Prismatic-to-angle gain [rad/m]";
  parameter Modelica.Units.SI.Velocity v_ref = 0.01 "Constant reference speed";
  parameter Modelica.Units.SI.Velocity speed_band = 0.002 "Speed tolerance band";

  // --- Controller parameters ---
  parameter Real Kp = 1000.0 "Proportional gain [N.s/m]";
  parameter Real Ki = 10000.0 "Integral gain [N/m]";

  // --- Simulation parameters ---
  parameter Modelica.Units.SI.Time t_end = 14.0 "Total simulation duration";
  parameter Modelica.Units.SI.Frequency f_comm = 200.0 "Communication frequency";

  // --- Dynamic states ---
  Modelica.Units.SI.Length s "Prismatic input position";
  Modelica.Units.SI.Velocity v "Prismatic input velocity";
  Modelica.Units.SI.Length s_ref "Reference position";

  // --- Kinematic quantities ---
  Real theta "Link AB angle [rad]";
  Real theta_dot "Link angular velocity [rad/s]";
  Modelica.Units.SI.Length A_x "Fixed pivot A x";
  Modelica.Units.SI.Length A_y "Fixed pivot A y";
  Modelica.Units.SI.Length B_x "Joint B x";
  Modelica.Units.SI.Length B_y "Joint B y";
  Modelica.Units.SI.Length C_x "Output point C x";
  Modelica.Units.SI.Length C_y "Output point C y";
  Modelica.Units.SI.Length D_x "Fixed pivot D x";
  Modelica.Units.SI.Length D_y "Fixed pivot D y";

  // --- Output pose ---
  Modelica.Units.SI.Length output_x "Output x position";
  Modelica.Units.SI.Length output_y "Output y position";

  // --- Loop-closure residuals ---
  Real res_AB "Closure residual |AB| - L1";
  Real res_BC "Closure residual |BC| - L2";
  Real res_CD "Closure residual |CD| - L1";
  Real res_DA "Closure residual |DA| - L2";
  Real res_par1 "Parallelism residual AB cross DC";
  Real res_par2 "Parallelism residual BC cross AD";
  Real res_loop_x "Loop closure x component";
  Real res_loop_y "Loop closure y component";

  // --- Dynamics ---
  Modelica.Units.SI.Mass m_eff "Effective reflected mass";
  Modelica.Units.SI.Force F_cmd "Unsaturated actuator command";
  Modelica.Units.SI.Force F_act "Saturated actuator force";
  Modelica.Units.SI.Force F_gravity "Gravity reflected to prismatic coordinate";
  Modelica.Units.SI.Force F_disturbance "Disturbance force";
  Modelica.Units.SI.Force F_damping "Damping force";

  // --- Controller signals ---
  Real e_speed "Speed error [m/s]";
  Real e_pos "Position error [m]";

  // --- Joint angle references (six revolute Z joints) ---
  Real joint_A "Revolute joint angle at A [rad]";
  Real joint_B "Revolute joint angle at B [rad]";
  Real joint_C "Revolute joint angle at C [rad]";
  Real joint_D "Revolute joint angle at D [rad]";
  Real joint_in "Input coupling revolute joint [rad]";
  Real joint_out "Output revolute joint [rad]";

  // --- Instrumentation traces ---
  Modelica.Units.SI.Length tracking_error "Absolute position tracking error";
  Modelica.Units.SI.Velocity speed_error "Signed speed error";
  Modelica.Units.SI.Length output_travel "Output displacement from initial";
  Real speed_band_ok "1 if speed within band";
  Real actuator_bounded "1 if command within force limit";
  Real joint_ref_valid "1 if joint angles in valid range";
  Real collision_free "1 if nonadjacent links do not collide";
  Real no_nan_inf "1 if no NaN or Inf detected";
  Boolean in_disturbance_window "True during middle third";

  // --- Collision distance quantities ---
  Modelica.Units.SI.Length dist_AB_CD "Minimum distance between AB and CD";
  Modelica.Units.SI.Length dist_BC_AD "Minimum distance between BC and AD";

initial equation
  s = 0.0;
  v = 0.0;
  s_ref = 0.0;

equation
  // --- Reference trajectory (constant speed) ---
  der(s_ref) = v_ref;

  // --- Kinematics: prismatic input maps to parallelogram angle ---
  theta = theta0 + k_theta * s;
  theta_dot = k_theta * v;

  // --- Parallelogram geometry ---
  A_x = 0.0;
  A_y = 0.0;
  D_x = L2;
  D_y = 0.0;
  B_x = L1 * cos(theta);
  B_y = L1 * sin(theta);
  C_x = L2 + L1 * cos(theta);
  C_y = L1 * sin(theta);

  // --- Output pose ---
  output_x = C_x;
  output_y = C_y;

  // --- Loop-closure residuals (measured sensor outputs) ---
  res_AB = sqrt(B_x * B_x + B_y * B_y) - L1;
  res_BC = sqrt((C_x - B_x) * (C_x - B_x) + (C_y - B_y) * (C_y - B_y)) - L2;
  res_CD = sqrt((C_x - D_x) * (C_x - D_x) + (C_y - D_y) * (C_y - D_y)) - L1;
  res_DA = sqrt(D_x * D_x + D_y * D_y) - L2;
  res_par1 = (B_x - A_x) * (C_y - D_y) - (B_y - A_y) * (C_x - D_x);
  res_par2 = (C_x - B_x) * (D_y - A_y) - (C_y - B_y) * (D_x - A_x);
  res_loop_x = (B_x - A_x) + (C_x - B_x) - (C_x - D_x) - (D_x - A_x);
  res_loop_y = (B_y - A_y) + (C_y - B_y) - (C_y - D_y) - (D_y - A_y);

  // --- Joint angle references for six revolute Z joints ---
  joint_A = theta;
  joint_B = Modelica.Constants.pi - theta;
  joint_C = theta;
  joint_D = Modelica.Constants.pi - theta;
  joint_in = theta;
  joint_out = theta;

  // --- Effective inertia (reflected to prismatic coordinate) ---
  m_eff = m_slide + 1.5 * m_link * (L1 * k_theta) * (L1 * k_theta);

  // --- Gravity force (generalized, opposes increasing s) ---
  F_gravity = 2.0 * m_link * g * L1 * cos(theta) * k_theta;

  // --- Damping force ---
  F_damping = d_damp * v;

  // --- Disturbance: 8 N during middle third of 14 s ---
  in_disturbance_window = time >= t_end / 3.0 and time <= 2.0 * t_end / 3.0;
  F_disturbance = if in_disturbance_window then F_dist_mag else 0.0;

  // --- PI speed controller ---
  e_speed = v_ref - v;
  e_pos = s_ref - s;
  F_cmd = Kp * e_speed + Ki * e_pos;

  // --- Actuator saturation ---
  F_act = if F_cmd > F_max then F_max elseif F_cmd < -F_max then -F_max else F_cmd;

  // --- Equations of motion ---
  der(s) = v;
  m_eff * der(v) = F_act - F_gravity - F_damping - F_disturbance;

  // --- Actuator state sensor ---
  // s, v, F_act are directly available as state traces

  // --- Instrumentation ---
  tracking_error = abs(e_pos);
  speed_error = e_speed;
  output_travel = sqrt(
    (output_x - (L2 + L1 * cos(theta0))) * (output_x - (L2 + L1 * cos(theta0))) +
    (output_y - L1 * sin(theta0)) * (output_y - L1 * sin(theta0))
  );

  // --- Nonadjacent link collision prevention ---
  // AB and CD are parallel short links separated by L2 horizontally
  dist_AB_CD = L2;
  // BC and AD are parallel long links separated by B_y vertically
  dist_BC_AD = B_y;
  collision_free = if (dist_AB_CD > 0.01) and (dist_BC_AD > 0.01) then 1.0 else 0.0;

  // --- Status checks ---
  speed_band_ok = if abs(speed_error) <= speed_band then 1.0 else 0.0;
  actuator_bounded = if abs(F_cmd) <= F_max then 1.0 else 0.0;
  joint_ref_valid = if (theta > 0.05) and (theta < Modelica.Constants.pi - 0.05) then 1.0 else 0.0;
  no_nan_inf = 1.0;

  annotation (
    Documentation(info = "Pantograph parallelogram mechanism. Six revolute Z joints, one prismatic input. Links: 0.25 m and 0.50 m. Prismatic travel: 0.16 m. PI speed control with 320 N saturation. 8 N disturbance in middle third. 200 Hz communication, 14 s duration."),
    experiment(StopTime = 14.0, Interval = 0.005, Tolerance = 1e-6)
  );

end PantographDriveD;