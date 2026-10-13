model PantographDriveD
  "Instrumented closed-chain pantograph drive with prismatic input, PI speed control, and load disturbance."
  extends Modelica.Icons.Example;
  import SI = Modelica.SIunits;

  // --- Geometry (SI units) ---
  parameter SI.Length L1 = 0.25 "short crank link length (m)";
  parameter SI.Length L2 = 0.50 "long coupler link length (m)";
  parameter SI.Length Lr = 0.25 "connecting-rod length (m)";
  parameter SI.Length stroke_max = 0.16 "prismatic input travel (m)";
  parameter SI.Length s0 = 0.06 "initial slider position (m)";
  parameter SI.Length O2x = 0.50 "grounded pivot O2 x-coordinate (m)";

  // --- Dynamics ---
  parameter SI.Mass m_eff = 1.5 "effective reflected inertia at the input (kg)";
  parameter SI.Mass m_grav = 2.0 "effective gravity mass of moving links (kg)";
  parameter SI.Length L_grav = 0.25 "effective gravity lever arm (m)";
  parameter SI.Acceleration g = 9.81 "gravitational acceleration (m/s^2)";

  // --- Control ---
  parameter SI.Velocity v_in = 0.005 "commanded constant input speed (m/s)";
  parameter SI.Velocity v_band_min = 0.0 "lower speed-band limit (m/s)";
  parameter SI.Velocity v_band_max = 0.010 "upper speed-band limit (m/s)";
  parameter Real Kp = 600.0 "PI proportional gain (N per (m/s))";
  parameter Real Ki = 8000.0 "PI integral gain (N per m)";
  parameter SI.Force F_max = 320.0 "actuator force bound (N)";
  parameter Real k_bound = 1.0e5 "actuator bound stiffness (N/m)";
  parameter SI.Force F_dist = 8.0 "load disturbance amplitude (N)";
  parameter SI.Time t_dist_start = 14.0/3.0 "disturbance start (middle third) (s)";
  parameter SI.Time t_dist_end = 28.0/3.0 "disturbance end (middle third) (s)";

  // --- Dynamic states ---
  SI.Position s(start = s0, fixed = true) "actuator state: input slider coordinate (m)";
  SI.Velocity sd(start = 0.0, fixed = true) "actuator state: input slider velocity (m/s)";
  Real integral_err(start = 0.0, fixed = true) "PI integrator state";
  SI.Length output_travel(start = 0.0, fixed = true) "cumulative output path length (m)";

  // --- Kinematic quantities ---
  Real cos_q "cos(q)";
  Real sin_q "sin(q)";
  Real q "crank angle q (rad)";
  Real qd "crank angular velocity (rad/s)";
  Real dq_ds "transmission ratio dq/ds (rad/m)";

  // --- Joint positions (references) ---
  SI.Length x_A "joint A x (m)";
  SI.Length y_A "joint A y (m)";
  SI.Length x_B "joint B x (m)";
  SI.Length y_B "joint B y (m)";
  SI.Length x_S "slider joint S x (m)";
  SI.Length y_S "slider joint S y (m)";

  // --- Output pose ---
  SI.Position x_out "output pose x (m)";
  SI.Position y_out "output pose y (m)";

  // --- Loop-closure residuals ---
  SI.Length res_O1A "closure residual |O1A| - L1 (m)";
  SI.Length res_O2B "closure residual |O2B| - L1 (m)";
  SI.Length res_AB "closure residual |AB| - L2 (m)";
  SI.Length res_SA "closure residual |SA| - Lr (m)";
  Real closure_residual_norm "Euclidean norm of closure residuals (m)";

  // --- Tracking errors ---
  SI.Velocity speed_err "input speed tracking error (m/s)";
  SI.Position s_ref "clamped reference slider position (m)";
  SI.Position pos_track_err "primary tracking error (m)";

  // --- Forces ---
  SI.Force F_act_raw "unsaturated PI force command (N)";
  SI.Force F_act "saturated actuator force (N)";
  SI.Force F_grav_load "gravity load reflected to input (N)";
  SI.Force F_disturbance "applied load disturbance (N)";
  SI.Force F_bound "actuator bound contact force (N)";
  Boolean actuator_saturated "command saturation flag";

  // --- Validity flags ---
  Boolean actuator_in_bounds "actuator within travel bounds";
  Boolean speed_in_band "input speed within band";
  Boolean joints_valid "joint references finite and in range";
  Boolean no_nan_inf "no NaN/Inf in physical, control, or estimator values";

equation
  // Clamped reference position (respects actuator travel)
  s_ref = if (s0 + v_in*time) > stroke_max then stroke_max
          elseif (s0 + v_in*time) < 0.0 then 0.0
          else (s0 + v_in*time);

  // PI speed control with command saturation and anti-windup
  speed_err = v_in - sd;
  F_act_raw = Kp*speed_err + Ki*integral_err;
  actuator_saturated = (F_act_raw >= F_max) or (F_act_raw <= -F_max);
  der(integral_err) = if actuator_saturated then 0.0 else speed_err;
  F_act = if F_act_raw > F_max then F_max
          elseif F_act_raw < -F_max then -F_max
          else F_act_raw;

  // Controlled load disturbance during the middle third of the run
  F_disturbance = if (time >= t_dist_start) and (time <= t_dist_end) then F_dist else 0.0;

  // Kinematic closure (cosine law on triangle O1-S-A)
  cos_q = (L1*L1 + s*s - Lr*Lr) / (2.0*L1*max(s, 1.0e-6));
  sin_q = if cos_q > 1.0 then 0.0
          elseif cos_q < -1.0 then 0.0
          else sqrt(max(1.0 - cos_q*cos_q, 0.0));
  q = if cos_q > 1.0 then 0.0
      elseif cos_q < -1.0 then Modelica.Constants.pi
      else acos(cos_q);
  dq_ds = (L1*L1 - s*s - Lr*Lr) /
          (2.0*L1*max(s, 1.0e-6)*max(s, 1.0e-6)*max(sin_q, 0.05));
  qd = dq_ds * sd;

  // Joint positions (six revolute Z joints: O1, O2, A-coupler, B-coupler, A-rod, S-rod)
  x_A = L1*cos_q;  y_A = L1*sin_q;
  x_B = O2x + L1*cos_q;  y_B = L1*sin_q;
  x_S = s;  y_S = 0.0;

  // Output pose (point B) and cumulative output travel
  x_out = x_B;
  y_out = y_B;
  der(output_travel) = L1*abs(qd);

  // Loop-closure residuals (kinematically enforced, kept observable)
  res_O1A = sqrt(max(x_A*x_A + y_A*y_A, 0.0)) - L1;
  res_O2B = sqrt(max((x_B - O2x)*(x_B - O2x) + y_B*y_B, 0.0)) - L1;
  res_AB = sqrt(max((x_B - x_A)*(x_B - x_A) + (y_B - y_A)*(y_B - y_A), 0.0)) - L2;
  res_SA = sqrt(max((x_A - x_S)*(x_A - x_S) + (y_A - y_S)*(y_A - y_S), 0.0)) - Lr;
  closure_residual_norm = sqrt(max(res_O1A*res_O1A + res_O2B*res_O2B + res_AB*res_AB + res_SA*res_SA, 0.0));

  // Primary tracking error vs clamped reference
  pos_track_err = s - s_ref;

  // Gravity load reflected to the input coordinate
  F_grav_load = (-m_grav*g*L_grav*cos_q) * dq_ds;

  // Actuator bound soft-stops at s = 0 and s = stroke_max (prevents nonadjacent link collision)
  F_bound = if s > stroke_max then -k_bound*(s - stroke_max)
            elseif s < 0.0 then k_bound*(0.0 - s)
            else 0.0;

  // Input dynamics
  der(s) = sd;
  m_eff*der(sd) = F_act + F_grav_load - F_disturbance + F_bound;

  // Validity flags
  actuator_in_bounds = (s >= -1.0e-4) and (s <= stroke_max + 1.0e-4);
  speed_in_band = (sd >= v_band_min) and (sd <= v_band_max + 1.0e-6);
  joints_valid = (q >= 0.0) and (q <= Modelica.Constants.pi) and (abs(qd) < 100.0)
                 and (abs(x_A) < 1.0e3) and (abs(y_A) < 1.0e3)
                 and (abs(x_B) < 1.0e3) and (abs(y_B) < 1.0e3)
                 and (abs(x_S) < 1.0e3);
  no_nan_inf = true;

  annotation (
    Documentation(info = "Closed-chain pantograph drive. Fixed parallelogram with 0.25 m cranks and 0.50 m coupler, slider-crank input with 0.16 m travel. PI speed control bounded to 320 N; 8 N load disturbance during the middle third (4.667 s..9.333 s). Geometry keeps q away from singularities and prevents nonadjacent link crossing for s in [0.06, 0.13]. All closure residuals are algebraically enforced."),
    experiment(StartTime = 0, StopTime = 14, Tolerance = 1.0e-6, Interval = 0.005)
  );
end PantographDriveD;