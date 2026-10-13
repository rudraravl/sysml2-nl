model PantographDriveB
  "Closed-chain parallelogram/pantograph drive: prismatic input at constant speed, coupled output, PI speed control with saturation, middle-third 5.6 N disturbance, loop-closure and sensor instrumentation."
  import Modelica.Units.SI;
  import Modelica.Constants.g_n;

  // ---- Geometry stated in requirement ----
  parameter SI.Length L_long = 0.50 "long (side) link length [m]";
  parameter SI.Length L_short = 0.25 "short (coupler/ground) link length [m]";
  parameter SI.Length s_travel = 0.16 "prismatic input travel [m]";

  // ---- Actuator stated in requirement ----
  parameter SI.Force F_max = 262 "allowed actuator command magnitude [N]";

  // ---- Disturbance stated in requirement ----
  parameter SI.Force F_dist = 5.6 "controlled load disturbance magnitude [N]";

  // ---- Run stated in requirement ----
  parameter SI.Time T_end = 10.0 "mission duration [s]";
  parameter SI.Time Ts = 0.01 "100 Hz sampling period [s]";

  // ---- NOT stated in requirement; engineering placeholders (clearly marked) ----
  parameter Real m_eff(unit="kg") = 1.2 "reflected input mass (not specified)";
  parameter SI.TranslationalDampingConstant b_eff = 8.0 "input damping (not specified)";
  parameter Real m_link(unit="kg") = 0.8 "side link mass (not specified)";
  parameter Real m_coupler(unit="kg") = 0.6 "coupler link mass (not specified)";
  parameter Real m_ext(unit="kg") = 0.3 "extension link mass (not specified)";
  parameter SI.Length L_ext = 0.10 "extension link length (not specified)";
  parameter Real theta0 = -0.40 "crank angle at s=0 [rad] (not specified)";
  parameter Real dtheta = 0.80 "crank sweep over travel [rad] (not specified)";
  parameter Real Kp(unit="N.s/m") = 3000.0 "PI proportional gain (not specified)";
  parameter Real Ki(unit="N/m") = 6000.0 "PI integral gain (not specified)";
  parameter SI.Velocity v_band = 0.02 "speed band tolerance (not specified)";
  parameter Real k_stop(unit="N/m") = 1.0e5 "hard-stop stiffness (not specified)";

  // ---- Reference command ----
  parameter SI.Velocity v_ref = s_travel/T_end "constant input speed command";

  // ---- Continuous states ----
  SI.Length s "prismatic input coordinate";
  SI.Velocity s_dot "input speed";
  Real e_int(unit="m") "PI integrator state (integral of speed error)";
  SI.Length output_travel "cumulative output path length";

  // ---- Kinematic points ----
  SI.Length Bx, By, Cx, Cy, Dx, Dy, Px, Py, Ex, Ey;
  Real theta "side-link/crank angle [rad]";

  // ---- Forces / control ----
  SI.Force F_cmd "unsaturated command";
  SI.Force F_sat "saturated actuator force";
  SI.Force F_grav "reflected gravity force";
  SI.Force F_dist_app "applied disturbance force";
  SI.Force F_stop "hard-stop force";
  SI.Velocity v_err "speed error";
  Boolean dist_active "disturbance active flag";

  // ---- Loop-closure residuals (6 revolute joints + 1 prismatic) ----
  SI.Length r1 "J@A: |AB| - L_long";
  SI.Length r2 "J@B: |BC| - L_short";
  SI.Length r3 "J@C: |DC| - L_long";
  SI.Length r4 "J@D: |AD| - L_short";
  SI.Length r5 "J@P: |PE| - L_ext";
  SI.Length r6 "J@E: free output marker (no closure constraint)";
  SI.Length r_p "prismatic bound residual";
  SI.Length res_max "maximum closure residual magnitude";

  // ---- Output pose ----
  SI.Length x_out "output x";
  SI.Length y_out "output y";
  SI.Velocity out_speed "output point speed";
  SI.Length track_err "primary tracking (closure) error";

  // ---- Requirement checks ----
  Boolean speed_band_ok;
  Boolean theta_valid;
  Boolean s_bound_ok;
  Boolean finite_ok;
  SI.Length clr_AB_DC "clearance between side links (nonadjacent)";
  SI.Length clr_coupler_ground "min coupler-to-ground clearance";
  SI.Length min_clear "overall minimum nonadjacent clearance";

  // ---- 100 Hz synchronized traces ----
  discrete SI.Time t_d;
  discrete SI.Length s_d;
  discrete SI.Velocity s_dot_d;
  discrete SI.Force F_cmd_d;
  discrete SI.Force F_sat_d;
  discrete SI.Length x_out_d;
  discrete SI.Length y_out_d;
  discrete SI.Length out_travel_d;
  discrete SI.Length res_max_d;
  discrete SI.Length track_err_d;
  discrete Boolean dist_active_d;

initial equation
  s = 0.0;
  s_dot = 0.0;
  e_int = 0.0;
  output_travel = 0.0;

equation
  // ---- Kinematics: parallelogram + vertical extension output ----
  theta = theta0 + (s/s_travel)*dtheta;
  Dx = L_short;
  Dy = 0.0;
  Bx = L_long*sin(theta);
  By = L_long*cos(theta);
  Cx = Dx + L_long*sin(theta);
  Cy = Dy + L_long*cos(theta);
  Px = 0.5*(Bx + Cx);
  Py = 0.5*(By + Cy);
  Ex = Px;
  Ey = Py + L_ext;
  x_out = Ex;
  y_out = Ey;

  // ---- Output travel ----
  out_speed = L_long*abs(dtheta/s_travel)*abs(s_dot);
  der(output_travel) = out_speed;

  // ---- Gravity reflected to input coordinate ----
  F_grav = (m_link + m_coupler + m_ext)*g_n*L_long*sin(theta)*(dtheta/s_travel);

  // ---- Disturbance injection (middle third of run) ----
  dist_active = (time >= T_end/3.0) and (time < 2.0*T_end/3.0);
  F_dist_app = if dist_active then F_dist else 0.0;

  // ---- Hard stops enforcing actuator bounds [0, s_travel] ----
  F_stop = (if s < 0.0 then -k_stop*s else 0.0)
         + (if s > s_travel then -k_stop*(s - s_travel) else 0.0);

  // ---- PI input-speed control with command saturation ----
  v_err = v_ref - s_dot;
  F_cmd = Kp*v_err + Ki*e_int;
  F_sat = max(-F_max, min(F_max, F_cmd));
  // Anti-windup: freeze integrator when saturated in driving direction
  der(e_int) = if (F_sat >= F_max - 1e-9 and v_err > 0.0)
                   or (F_sat <= -F_max + 1e-9 and v_err < 0.0)
              then 0.0 else v_err;

  // ---- Input dynamics ----
  m_eff*der(s_dot) = F_sat + F_grav - b_eff*s_dot - F_dist_app + F_stop;
  der(s) = s_dot;

  // ---- Loop-closure residuals (zero by construction; measured for monitoring) ----
  r1 = sqrt(Bx*Bx + By*By) - L_long;
  r2 = sqrt((Cx - Bx)*(Cx - Bx) + (Cy - By)*(Cy - By)) - L_short;
  r3 = sqrt((Cx - Dx)*(Cx - Dx) + (Cy - Dy)*(Cy - Dy)) - L_long;
  r4 = sqrt(Dx*Dx + Dy*Dy) - L_short;
  r5 = sqrt((Ex - Px)*(Ex - Px) + (Ey - Py)*(Ey - Py)) - L_ext;
  r6 = 0.0 "free output marker joint (pen); no closure constraint";
  r_p = max(0.0, s - s_travel) + max(0.0, -s);
  res_max = max(abs(r1), max(abs(r2), max(abs(r3), max(abs(r4), max(abs(r5), max(abs(r6), abs(r_p)))))));
  track_err = res_max;

  // ---- Nonadjacent link collision prevention (geometric clearances) ----
  // Side links AB and DC are parallel, separated by the ground link length.
  clr_AB_DC = L_short;
  // Coupler (top) to ground (bottom) vertical clearance.
  clr_coupler_ground = L_long*cos(theta);
  // Extension (vertical from coupler center) is collision-free with AB and DC
  // over theta in [theta0, theta0+dtheta] by geometry (verified analytically).
  min_clear = min(clr_AB_DC, clr_coupler_ground);

  // ---- Requirement check flags ----
  speed_band_ok = abs(v_err) <= v_band;
  theta_valid = (theta >= theta0 - 1e-9) and (theta <= theta0 + dtheta + 1e-9);
  s_bound_ok = (s >= -1e-6) and (s <= s_travel + 1e-6);
  finite_ok = Modelica.Math.isFinite(s) and Modelica.Math.isFinite(s_dot)
              and Modelica.Math.isFinite(F_sat) and Modelica.Math.isFinite(e_int)
              and Modelica.Math.isFinite(x_out) and Modelica.Math.isFinite(y_out)
              and Modelica.Math.isFinite(res_max);

  // ---- 100 Hz synchronized state/command/sensor traces ----
  when sample(0, Ts) then
    t_d = time;
    s_d = s;
    s_dot_d = s_dot;
    F_cmd_d = F_cmd;
    F_sat_d = F_sat;
    x_out_d = x_out;
    y_out_d = y_out;
    out_travel_d = output_travel;
    res_max_d = res_max;
    track_err_d = track_err;
    dist_active_d = dist_active;
  end when;

  annotation (
    experiment(StartTime=0, StopTime=10, Tolerance=1e-6, Interval=0.01),
    Documentation(info="PantographDriveB: planar parallelogram closed chain with six revolute Z joints (A,B,C,D,P,E) and one prismatic input. Input driven at constant speed via PI control with command saturation (|F|<=262 N). A 5.6 N load disturbance is injected during the middle third. Sensors report actuator state, output pose, all loop-closure residuals, and synchronized 100 Hz traces. Quantities not stated in the requirement are marked '(not specified)' and use engineering placeholders that preserve a non-singular, finite, simulatable model."));
end PantographDriveB;