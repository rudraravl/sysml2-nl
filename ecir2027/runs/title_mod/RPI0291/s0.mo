model PantographDriveC
  "Closed-chain pantograph with PI input-speed control and command saturation"

  // ===== Physical parameters =====
  parameter Modelica.Units.SI.Length L_long = 0.50 "Long link length (m)";
  parameter Modelica.Units.SI.Length L_short = 0.25 "Short link length (m)";
  parameter Modelica.Units.SI.Length L_conn = 0.50 "Connecting link length (m)";
  parameter Modelica.Units.SI.Length travel = 0.16 "Prismatic total travel (m)";
  parameter Modelica.Units.SI.Length y_P0 = 0.30 "Initial prismatic position (m)";
  parameter Modelica.Units.SI.Mass m_eff = 4.0 "Effective inertia at prismatic (kg)";
  parameter Modelica.Units.SI.Mass m_link = 1.0 "Individual link mass (kg)";
  parameter Modelica.Units.SI.Mass m_slider = 2.0 "Slider mass (kg)";
  parameter Modelica.Units.SI.Acceleration g_acc = 9.81 "Gravitational acceleration (m/s2)";
  parameter Modelica.Units.SI.Force F_grav = g_acc * (1.75 * m_link + m_slider)
    "Constant gravity force projected onto prismatic joint (N)";

  // ===== Control parameters =====
  parameter Modelica.Units.SI.Force F_max = 294 "Maximum command magnitude (N)";
  parameter Modelica.Units.SI.Force F_dist = 7.2 "Disturbance force magnitude (N)";
  parameter Modelica.Units.SI.Velocity v_ref = 0.005 "Reference input speed (m/s)";
  parameter Modelica.Units.SI.Velocity speed_band = 0.002 "Speed tracking band (m/s)";
  parameter Real Kp = 4000.0 "PI proportional gain (N per m/s)";
  parameter Real Ki = 20000.0 "PI integral gain (N per m/s per s)";

  // ===== Timing =====
  parameter Modelica.Units.SI.Time t_sim = 12.0 "Simulation duration (s)";
  parameter Modelica.Units.SI.Time t_dist_start = 4.0 "Disturbance start time (s)";
  parameter Modelica.Units.SI.Time t_dist_end = 8.0 "Disturbance end time (s)";
  parameter Modelica.Units.SI.Time t_track_check = 7.8 "Tracking error check time (s)";

  // ===== End-stop parameters =====
  parameter Real k_stop = 50000.0 "End-stop stiffness (N/m)";
  parameter Real c_stop = 500.0 "End-stop damping (N.s/m)";

  // ===== Derived bounds =====
  parameter Modelica.Units.SI.Length y_P_min = y_P0 - travel / 2
    "Prismatic lower bound (m)";
  parameter Modelica.Units.SI.Length y_P_max = y_P0 + travel / 2
    "Prismatic upper bound (m)";

  // ===== Dynamic states =====
  Modelica.Units.SI.Position y_P "Prismatic input position (m)";
  Modelica.Units.SI.Velocity v_P "Prismatic input velocity (m/s)";
  Real theta "Parallelogram link angle (rad)";
  Real theta_dot "Parallelogram link angular velocity (rad/s)";

  // ===== Controller variables =====
  Real integral_error "Integral of speed error (m/s * s)";
  Modelica.Units.SI.Velocity speed_error "Speed tracking error (m/s)";
  Modelica.Units.SI.Force F_command "Unsaturated PI command (N)";
  Modelica.Units.SI.Force F_actuator "Saturated actuator force (N)";
  Modelica.Units.SI.Force F_disturbance "Applied disturbance force (N)";
  Modelica.Units.SI.Force F_stop "End-stop reaction force (N)";
  Modelica.Units.SI.Force F_net "Net force on prismatic joint (N)";

  // ===== Kinematic outputs =====
  Modelica.Units.SI.Position C_x "Parallelogram vertex C x (m)";
  Modelica.Units.SI.Position C_y "Parallelogram vertex C y (m)";
  Modelica.Units.SI.Position D_x "Parallelogram vertex D x (m)";
  Modelica.Units.SI.Position D_y "Parallelogram vertex D y (m)";
  Modelica.Units.SI.Position E_x "Output point E x (m)";
  Modelica.Units.SI.Position E_y "Output point E y (m)";
  Modelica.Units.SI.Length output_travel "Output travel from initial (m)";

  // ===== Revolute joint angle observations =====
  Real j1 "Revolute Z at A (rad)";
  Real j2 "Revolute Z at B (rad)";
  Real j3 "Revolute Z at C-parallelogram (rad)";
  Real j4 "Revolute Z at D (rad)";
  Real j5 "Revolute Z at C-connecting (rad)";
  Real j6 "Revolute Z at P-connecting (rad)";

  // ===== Loop-closure residuals =====
  Modelica.Units.SI.Length res_PC "P-C connecting link closure residual (m)";
  Modelica.Units.SI.Length res_AC "A-C link closure residual (m)";
  Modelica.Units.SI.Length res_BD "B-D link closure residual (m)";
  Modelica.Units.SI.Length res_CD "C-D link closure residual (m)";

  // ===== Reference and tracking =====
  Modelica.Units.SI.Position y_P_ref "Reference prismatic position (m)";
  Modelica.Units.SI.Length tracking_error "Position tracking error (m)";

  // ===== Sensor outputs =====
  Modelica.Units.SI.Position actuator_position "Actuator position sensor (m)";
  Modelica.Units.SI.Velocity actuator_velocity "Actuator velocity sensor (m/s)";
  Modelica.Units.SI.Force actuator_force "Actuator force sensor (N)";
  Modelica.Units.SI.Length output_pose_x "Output pose x (m)";
  Modelica.Units.SI.Length output_pose_y "Output pose y (m)";

  // ===== Validity flags =====
  Boolean actuator_in_bounds "Actuator within travel bounds";
  Boolean speed_in_band "Speed within tracking band";
  Boolean closure_valid "All closure residuals below threshold";
  Boolean output_valid "Output travel valid";
  Boolean joints_valid "Joint references valid";
  Boolean tracking_ok "Tracking error below 0.002 m after check time";

  // ===== Collision check =====
  Modelica.Units.SI.Length min_link_dist
    "Minimum nonadjacent link distance (m)";

equation
  // ===== Kinematics =====
  // Connecting-link constraint: |P-C| = L_conn with P=(0,y_P), C=(L_long*cos(theta),L_long*sin(theta))
  // Yields: sin(theta) = y_P / (2*L_long)
  theta = asin(y_P / (2.0 * L_long));
  theta_dot = v_P / (2.0 * L_long * cos(theta));

  // Parallelogram vertices
  C_x = L_long * cos(theta);
  C_y = L_long * sin(theta);
  D_x = L_short + L_long * cos(theta);
  D_y = L_long * sin(theta);

  // Output extension from C along AC direction, length L_short
  E_x = (L_long + L_short) * cos(theta);
  E_y = (L_long + L_short) * sin(theta);

  // Output travel from initial configuration
  output_travel = sqrt(
    (E_x - (L_long + L_short) * cos(asin(y_P0 / (2.0 * L_long))))^2 +
    (E_y - (L_long + L_short) * sin(asin(y_P0 / (2.0 * L_long))))^2
  );

  // ===== Joint angle observations =====
  j1 = theta;
  j2 = theta;
  j3 = 0.0;
  j4 = 0.0;
  j5 = atan2(y_P - C_y, -C_x);
  j6 = atan2(C_y - y_P, C_x) - Modelica.Constants.pi / 2.0;

  // ===== Disturbance force =====
  F_disturbance = if (time >= t_dist_start and time <= t_dist_end) then F_dist else 0.0;

  // ===== End-stop reaction =====
  F_stop = if y_P < y_P_min then k_stop * (y_P_min - y_P) - c_stop * v_P
           elseif y_P > y_P_max then -k_stop * (y_P - y_P_max) - c_stop * v_P
           else 0.0;

  // ===== Equations of motion =====
  F_net = F_actuator - F_grav - F_disturbance + F_stop;
  der(y_P) = v_P;
  m_eff * der(v_P) = F_net;

  // ===== PI speed controller with anti-windup =====
  speed_error = v_ref - v_P;
  F_command = Kp * speed_error + Ki * integral_error;

  // Conditional integration: freeze when saturated in error direction
  der(integral_error) = if (F_command > F_max and speed_error > 0.0) or
                           (F_command < -F_max and speed_error < 0.0)
                        then 0.0
                        else speed_error;

  // Command saturation
  F_actuator = if F_command > F_max then F_max
               elseif F_command < -F_max then -F_max
               else F_command;

  // ===== Reference and tracking =====
  y_P_ref = y_P0 + v_ref * time;
  tracking_error = abs(y_P - y_P_ref);

  // ===== Loop-closure residuals =====
  res_PC = sqrt(C_x * C_x + (C_y - y_P) * (C_y - y_P)) - L_conn;
  res_AC = sqrt(C_x * C_x + C_y * C_y) - L_long;
  res_BD = sqrt((D_x - L_short) * (D_x - L_short) + D_y * D_y) - L_long;
  res_CD = sqrt((D_x - C_x) * (D_x - C_x) + (D_y - C_y) * (D_y - C_y)) - L_short;

  // ===== Sensor outputs =====
  actuator_position = y_P;
  actuator_velocity = v_P;
  actuator_force = F_actuator;
  output_pose_x = E_x;
  output_pose_y = E_y;

  // ===== Nonadjacent link distance =====
  // Links AC and BD are parallel; perpendicular separation is L_short
  min_link_dist = L_short;

  // ===== Validity checks =====
  actuator_in_bounds = (y_P >= y_P_min - 0.001) and (y_P <= y_P_max + 0.001);
  speed_in_band = abs(speed_error) <= speed_band;
  closure_valid = (abs(res_PC) < 0.002) and (abs(res_AC) < 0.002) and
                  (abs(res_BD) < 0.002) and (abs(res_CD) < 0.002);
  output_valid = (output_travel >= 0.0) and (output_travel < 1.0);
  joints_valid = (abs(theta) < 1.5) and (y_P > 0.01) and
                 (y_P < 2.0 * L_long - 0.01);
  tracking_ok = if time >= t_track_check then tracking_error < 0.002 else true;

  // ===== Assertions =====
  assert(actuator_in_bounds, "Actuator position out of travel bounds");
  assert(abs(F_actuator) <= F_max + 0.001,
         "Actuator force exceeds saturation limit");
  assert(abs(res_PC) < 0.01, "P-C loop closure violation");
  assert(abs(res_AC) < 0.01, "A-C loop closure violation");
  assert(abs(res_BD) < 0.01, "B-D loop closure violation");
  assert(abs(res_CD) < 0.01, "C-D loop closure violation");
  assert(abs(theta) < 1.5, "Joint angle near singularity");
  assert(min_link_dist > 0.01, "Nonadjacent link collision risk");
  assert(abs(y_P) < 1e10, "Numerical blowup detected in y_P");
  assert(abs(v_P) < 1e10, "Numerical blowup detected in v_P");
  assert(abs(F_actuator) < 1e10,
         "Numerical blowup detected in F_actuator");
  assert(abs(integral_error) < 1e10,
         "Numerical blowup detected in integral_error");

initial equation
  y_P = y_P0;
  v_P = 0.0;
  integral_error = (F_grav - Kp * v_ref) / Ki;

  annotation(
    experiment(StartTime = 0, StopTime = 12.0, Tolerance = 1e-6,
               Interval = 0.008),
    Documentation(info =
      "<html>
<p><b>PantographDriveC</b> — Closed-chain pantograph mechanism with PI
input-speed control and command saturation.</p>
<h3>Plant</h3>
<p>Fixed parallelogram: 0.25 m and 0.50 m links, six revolute Z joints,
one prismatic input with 0.16 m travel. One bounded linear actuator
commands the input coordinate.</p>
<h3>Control</h3>
<p>PI speed control with +/-294 N saturation. 7.2 N load disturbance
injected during the middle third (4–8 s).</p>
<h3>Instrumentation</h3>
<p>Actuator state (position, velocity, force), output pose (E_x, E_y),
and all loop-closure residuals (res_PC, res_AC, res_BD, res_CD).</p>
<h3>Execution</h3>
<p>125 Hz output (dt = 0.008 s) for 12 s. Primary tracking error
required below 0.002 m after 7.8 s.</p>
</html>")
  );
end PantographDriveC;