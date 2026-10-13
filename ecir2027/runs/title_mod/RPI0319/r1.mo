model StewartTraceA
  "Closed-chain Stewart platform tracing a circle with IK control, closure stabilization, force limits, and obstacle clearance"

  // --- Physical parameters ---
  parameter Real Rb = 0.45 "Base anchor circle radius [m]";
  parameter Real Rp = 0.32 "Platform anchor circle radius [m]";
  parameter Real m_platform = 36.0 "Platform mass [kg]";
  parameter Real h_nom = 0.65 "Nominal platform height [m]";
  parameter Real r_circle = 0.10 "Trace circle radius [m]";
  parameter Real L_min = 0.55 "Minimum strut length [m]";
  parameter Real L_max = 0.85 "Maximum strut length [m]";
  parameter Real F_max = 3024.0 "Maximum strut force magnitude per strut [N]";
  parameter Real g = 9.81 "Gravitational acceleration [m/s2]";

  // --- Control parameters ---
  parameter Real kp = 50000.0 "Strut position gain [N/m]";
  parameter Real kd = 2000.0 "Strut velocity gain [N.s/m]";
  parameter Real kc = 3000.0 "Closure stabilization gain [N/m]";

  // --- Obstacle ---
  parameter Real obs_x = 0.60 "Obstacle x position [m]";
  parameter Real obs_z = 0.65 "Obstacle z position [m]";
  parameter Real obs_r = 0.05 "Obstacle radius [m]";

  // --- Scenario ---
  parameter Real T_end = 8.0 "Scenario duration [s]";
  parameter Real Ts = 1.0 / 80.0 "Sample period [s]";
  parameter Real F_dist_mag = 5.0 "Disturbance force magnitude [N]";

  // --- Anchor angles (radians) ---
  parameter Real base_ang[6] = {
    0.0,
    Modelica.Constants.pi / 3.0,
    2.0 * Modelica.Constants.pi / 3.0,
    Modelica.Constants.pi,
    4.0 * Modelica.Constants.pi / 3.0,
    5.0 * Modelica.Constants.pi / 3.0
  } "Base anchor angles [rad]";

  parameter Real plat_ang[6] = {
    Modelica.Constants.pi / 12.0,
    5.0 * Modelica.Constants.pi / 12.0,
    3.0 * Modelica.Constants.pi / 4.0,
    13.0 * Modelica.Constants.pi / 12.0,
    17.0 * Modelica.Constants.pi / 12.0,
    7.0 * Modelica.Constants.pi / 4.0
  } "Platform anchor angles [rad]";

  // --- Platform state ---
  Real x(start = 0.0, fixed = true) "Platform center x [m]";
  Real y(start = 0.0, fixed = true) "Platform center y [m]";
  Real z(start = h_nom, fixed = true) "Platform center z [m]";
  Real vx(start = 0.0, fixed = true) "Platform center x velocity [m/s]";
  Real vy(start = 0.0, fixed = true) "Platform center y velocity [m/s]";
  Real vz(start = 0.0, fixed = true) "Platform center z velocity [m/s]";

  // --- Desired trajectory ---
  Real x_des "Desired platform x [m]";
  Real y_des "Desired platform y [m]";
  Real z_des "Desired platform z [m]";

  // --- Strut geometry ---
  Real bx[6] "Base anchor x [m]";
  Real by[6] "Base anchor y [m]";
  Real px[6] "Platform anchor x [m]";
  Real py[6] "Platform anchor y [m]";
  Real L_actual[6] "Actual strut lengths [m]";
  Real L_cmd[6] "Commanded strut lengths from IK [m]";
  Real L_enc[6] "Encoder sensed strut lengths [m]";
  Real dL[6] "Strut length rates [m/s]";
  Real ux[6] "Strut unit vector x (platform to base) [1]";
  Real uy[6] "Strut unit vector y (platform to base) [1]";
  Real uz[6] "Strut unit vector z (platform to base) [1]";

  // --- Forces ---
  Real F_cmd[6] "Unlimited force command [N]";
  Real F_strut[6] "Saturated strut force [N]";
  Real F_net_x "Net strut force x on platform [N]";
  Real F_net_y "Net strut force y on platform [N]";
  Real F_net_z "Net strut force z on platform [N]";
  Real F_dist "Disturbance force in z [N]";

  // --- Sensors ---
  Real x_meas "Measured platform x [m]";
  Real y_meas "Measured platform y [m]";
  Real z_meas "Measured platform z [m]";

  // --- Discrete sampled traces at 80 Hz ---
  discrete Real x_s "Sampled platform x [m]";
  discrete Real y_s "Sampled platform y [m]";
  discrete Real z_s "Sampled platform z [m]";
  discrete Real L_enc_s[6] "Sampled encoder lengths [m]";
  discrete Real F_cmd_s[6] "Sampled force commands [N]";
  discrete Real path_err_s "Sampled path error [m]";
  discrete Real closure_err_s "Sampled closure error [m]";
  discrete Real clearance_s "Sampled clearance [m]";

  // --- Metrics ---
  Real path_error "Path tracking error [m]";
  Real closure_error "Closure error [m]";
  Real singularity_margin "Singularity margin [1]";
  Real clearance "Obstacle clearance [m]";
  Real max_effort "Max effort fraction [1]";
  Real strut_margin "Min strut length margin [m]";

  // --- Scalar reductions for FMU compatibility ---
  Real L_act_min "Minimum actual strut length [m]";
  Real L_act_max "Maximum actual strut length [m]";
  Real F_abs_max "Maximum absolute strut force [N]";
  Real closure_sum "Sum of squared strut length errors [m2]";

  // --- Functions ---
  function safeNorm3
    "Safe 3D Euclidean norm with zero-error branch"
    input Real a;
    input Real b;
    input Real c;
    output Real y;
  algorithm
    y := sqrt(a * a + b * b + c * c);
    if y < 1.0e-9 then
      y := 1.0e-9;
    end if;
  end safeNorm3;

  function satForce
    "Saturate force to symmetric magnitude limit"
    input Real f;
    input Real fmax;
    output Real y;
  algorithm
    if f > fmax then
      y := fmax;
    elseif f < -fmax then
      y := -fmax;
    else
      y := f;
    end if;
  end satForce;

equation
  // --- Base and platform anchor positions, strut geometry ---
  for i in 1:6 loop
    bx[i] = Rb * cos(base_ang[i]);
    by[i] = Rb * sin(base_ang[i]);
    px[i] = x + Rp * cos(plat_ang[i]);
    py[i] = y + Rp * sin(plat_ang[i]);
    L_actual[i] = safeNorm3(bx[i] - px[i], by[i] - py[i], -z);
    ux[i] = (bx[i] - px[i]) / L_actual[i];
    uy[i] = (by[i] - py[i]) / L_actual[i];
    uz[i] = (-z) / L_actual[i];
    dL[i] = -ux[i] * vx - uy[i] * vy - uz[i] * vz;
  end for;

  // --- Desired trajectory: circle in x-z plane ---
  x_des = r_circle * cos(2.0 * Modelica.Constants.pi * time / T_end);
  y_des = 0.0;
  z_des = h_nom + r_circle * sin(2.0 * Modelica.Constants.pi * time / T_end);

  // --- Inverse kinematics: desired strut lengths ---
  for i in 1:6 loop
    L_cmd[i] = safeNorm3(
      bx[i] - (x_des + Rp * cos(plat_ang[i])),
      by[i] - (y_des + Rp * sin(plat_ang[i])),
      -z_des
    );
  end for;

  // --- Encoder measurement ---
  for i in 1:6 loop
    L_enc[i] = L_actual[i];
  end for;

  // --- Force control with saturation ---
  for i in 1:6 loop
    F_cmd[i] = kp * (L_cmd[i] - L_actual[i]) - kd * dL[i];
    F_strut[i] = satForce(F_cmd[i], F_max);
  end for;

  // --- Net strut forces on platform (compression pushes away from base) ---
  F_net_x = F_strut[1] * (-ux[1]) + F_strut[2] * (-ux[2]) + F_strut[3] * (-ux[3]) +
            F_strut[4] * (-ux[4]) + F_strut[5] * (-ux[5]) + F_strut[6] * (-ux[6]);
  F_net_y = F_strut[1] * (-uy[1]) + F_strut[2] * (-uy[2]) + F_strut[3] * (-uy[3]) +
            F_strut[4] * (-uy[4]) + F_strut[5] * (-uy[5]) + F_strut[6] * (-uy[6]);
  F_net_z = F_strut[1] * (-uz[1]) + F_strut[2] * (-uz[2]) + F_strut[3] * (-uz[3]) +
            F_strut[4] * (-uz[4]) + F_strut[5] * (-uz[5]) + F_strut[6] * (-uz[6]);

  // --- Disturbance: 5 N during middle third of scenario ---
  if time >= T_end / 3.0 and time <= 2.0 * T_end / 3.0 then
    F_dist = F_dist_mag;
  else
    F_dist = 0.0;
  end if;

  // --- Platform dynamics with closure stabilization ---
  der(x) = vx;
  der(y) = vy;
  der(z) = vz;
  m_platform * der(vx) = F_net_x + kc * (x_des - x);
  m_platform * der(vy) = F_net_y + kc * (y_des - y);
  m_platform * der(vz) = F_net_z + kc * (z_des - z) - m_platform * g + F_dist;

  // --- Direct pose measurement ---
  x_meas = x;
  y_meas = y;
  z_meas = z;

  // --- Error metrics ---
  path_error = sqrt((x - x_des) * (x - x_des) + (z - z_des) * (z - z_des));

  closure_sum = (L_cmd[1] - L_actual[1]) * (L_cmd[1] - L_actual[1]) +
                (L_cmd[2] - L_actual[2]) * (L_cmd[2] - L_actual[2]) +
                (L_cmd[3] - L_actual[3]) * (L_cmd[3] - L_actual[3]) +
                (L_cmd[4] - L_actual[4]) * (L_cmd[4] - L_actual[4]) +
                (L_cmd[5] - L_actual[5]) * (L_cmd[5] - L_actual[5]) +
                (L_cmd[6] - L_actual[6]) * (L_cmd[6] - L_actual[6]);
  closure_error = sqrt(closure_sum);

  // --- Explicit scalar array reductions ---
  L_act_min = min({L_actual[1], L_actual[2], L_actual[3], L_actual[4], L_actual[5], L_actual[6]});
  L_act_max = max({L_actual[1], L_actual[2], L_actual[3], L_actual[4], L_actual[5], L_actual[6]});
  F_abs_max = max({abs(F_strut[1]), abs(F_strut[2]), abs(F_strut[3]), abs(F_strut[4]), abs(F_strut[5]), abs(F_strut[6])});

  singularity_margin = L_act_min / L_max;
  strut_margin = min({L_act_min - L_min, L_max - L_act_max});
  max_effort = F_abs_max / F_max;
  clearance = sqrt((x - obs_x) * (x - obs_x) + (z - obs_z) * (z - obs_z)) - obs_r;

  // --- Requirement assertions ---
  assert(strut_margin >= 0.0, "Strut length bounds violated");
  assert(max_effort <= 1.0, "Strut effort bounds violated");
  assert(clearance > 0.0, "Obstacle clearance violated");
  assert(time <= 5.2 or path_error < 0.011, "Path error exceeds 0.011 m after 5.2 s");

  // --- Sampled traces at 80 Hz ---
  when sample(0, Ts) then
    x_s = x;
    y_s = y;
    z_s = z;
    L_enc_s[1] = L_enc[1];
    L_enc_s[2] = L_enc[2];
    L_enc_s[3] = L_enc[3];
    L_enc_s[4] = L_enc[4];
    L_enc_s[5] = L_enc[5];
    L_enc_s[6] = L_enc[6];
    F_cmd_s[1] = F_cmd[1];
    F_cmd_s[2] = F_cmd[2];
    F_cmd_s[3] = F_cmd[3];
    F_cmd_s[4] = F_cmd[4];
    F_cmd_s[5] = F_cmd[5];
    F_cmd_s[6] = F_cmd[6];
    path_err_s = path_error;
    closure_err_s = closure_error;
    clearance_s = clearance;
  end when;

  annotation(
    experiment(StartTime = 0.0, StopTime = 8.0, Tolerance = 1e-6, Interval = 0.001),
    Documentation(info = "StewartTraceA: 6-strut closed-chain platform tracing a 0.10 m radius circle. "
                         "Base radius 0.45 m, platform 36 kg / 0.32 m radius, struts 0.55-0.85 m, "
                         "force limited 3024 N/strut. IK trajectory control with closure stabilization. "
                         "5 N disturbance in middle third. 80 Hz sampled traces. Obstacle at (0.60, 0.65) m.")
  );

end StewartTraceA;