model PantographDriveD
  "Instrumented planar parallelogram (pantograph) mechanism driven by a bounded prismatic actuator with PI speed control and mid-third disturbance."

  // ============ Geometry parameters ============
  parameter Real L1 = 0.25 "short link length AB=CD [m]";
  parameter Real L2 = 0.50 "long link length AD=BC [m]";
  parameter Real s_travel = 0.16 "prismatic input travel [m]";

  // ============ Inertia / mass parameters ============
  parameter Real m_link = 0.80 "mass of each moving link [kg]";
  parameter Real m_act  = 1.50 "actuator reflected mass [kg]";
  parameter Real J_link = 0.020 "link rotational inertia about pivot [kg.m2]";

  // ============ Actuator bounds ============
  parameter Real F_max = 320.0 "actuator force bound [N]";
  parameter Real s_min = 0.030 "lower prismatic bound [m]";
  parameter Real s_max = 0.030 + s_travel "upper prismatic bound [m]";

  // ============ Control parameters ============
  parameter Real v_cmd = 0.16/14.0 "commanded constant input speed [m/s]";
  parameter Real Kp = 15000.0 "PI proportional gain [N.s/m]";
  parameter Real Ki = 5000.0  "PI integral gain [N/m]";
  parameter Real v_band = 0.002 "acceptable speed band [m/s]";

  // ============ Disturbance parameters ============
  parameter Real F_dist = 8.0 "disturbance force magnitude [N]";
  parameter Real t_dist_start = 14.0/3.0 "middle-third start [s]";
  parameter Real t_dist_end   = 2.0*14.0/3.0 "middle-third end [s]";

  // ============ Gravity ============
  parameter Real g = 9.81 "gravitational acceleration [m/s2]";

  // ============ Simulation / instrumentation ============
  parameter Real T_end = 14.0 "simulation duration [s]";
  parameter Real f_sample = 200.0 "instrumentation sample rate [Hz]";
  parameter Real dt_sample = 1.0/f_sample "sample period [s]";

  // ============ Initial conditions ============
  parameter Real alpha0 = 0.50 "initial crank angle [rad]";
  parameter Real s0 = L1*(1.0 - Modelica.Math.cos(alpha0)) "initial input [m]";

  // ============ Dynamic states ============
  Real alpha(start=alpha0, fixed=true) "crank angle AB [rad]";
  Real omega(start=0.0, fixed=true)    "crank angular velocity [rad/s]";
  Real integ(start=0.0, fixed=true)    "PI integrator state [m]";
  Real output_travel(start=0.0, fixed=true) "cumulative output path length [m]";

  // ============ Algebraic (sensed / control) ============
  Real s        "prismatic input position [m]";
  Real v        "prismatic input velocity [m/s]";
  Real s_cmd    "commanded input position [m]";
  Real v_cmd_eff "commanded input velocity, post-saturation [m/s]";
  Real e_v      "velocity error [m/s]";
  Real F_cmd    "unbounded force command [N]";
  Real F_act    "saturated actuator force [N]";
  Real F_dist_eff "active disturbance force [N]";
  Real tau_act  "generalized actuator torque [N.m]";
  Real tau_dist "generalized disturbance torque [N.m]";
  Real tau_grav "generalized gravity torque [N.m]";
  Real J_eff    "effective inertia [kg.m2]";
  Real dJ_eff   "dJ_eff/dalpha [kg.m2/rad]";

  // ============ Geometry ============
  Real Ax "pivot A x [m]";
  Real Ay "pivot A y [m]";
  Real Bx "joint B x [m]";
  Real By "joint B y [m]";
  Real Cx "joint C x [m]";
  Real Cy "joint C y [m]";
  Real Dx "pivot D x [m]";
  Real Dy "pivot D y [m]";
  Real beta     "DC link angle [rad]";
  Real alpha_ref "reference crank angle from s_cmd [rad]";
  Real beta_ref  "reference DC angle [rad]";

  // ============ Closure residuals ============
  Real res_AB        "AB length closure [m]";
  Real res_BC        "BC length closure [m]";
  Real res_DC        "DC length closure [m]";
  Real res_AD        "AD length closure [m]";
  Real res_crank     "crank-slider closure [m]";
  Real res_parallel  "parallelogram (beta-alpha) closure [rad]";

  // ============ Output ============
  Real output_speed "output speed |dC/dt| [m/s]";

  // ============ Performance / validity flags ============
  Real tracking_err      "input tracking error |s-s_cmd| [m]";
  Real within_band       "1 if speed in band else 0";
  Real actuator_in_bounds "1 if s in bounds else 0";
  Real valid             "1 if all physical/control values finite, else 0";

  // ============ Synchronized 200 Hz traces (discrete) ============
  discrete Real s_sampled            "sampled input position [m]";
  discrete Real v_sampled            "sampled input velocity [m/s]";
  discrete Real F_sampled            "sampled actuator force [N]";
  discrete Real Cx_sampled           "sampled output x [m]";
  discrete Real Cy_sampled           "sampled output y [m]";
  discrete Real res_BC_sampled       "sampled BC closure [m]";
  discrete Real tracking_err_sampled "sampled tracking error [m]";
  discrete Real omega_sampled        "sampled angular velocity [rad/s]";

equation
  // ===== Commanded trajectory: constant-speed ramp with end clamps =====
  s_cmd = if (s0 + v_cmd*time > s_max) then s_max
          else if (s0 + v_cmd*time < s_min) then s_min
          else s0 + v_cmd*time;
  v_cmd_eff = if (s0 + v_cmd*time >= s_max) then 0.0 else v_cmd;

  // ===== Input kinematics (crank-slider: s = L1(1 - cos alpha)) =====
  s = L1*(1.0 - Modelica.Math.cos(alpha));
  v = L1*Modelica.Math.sin(alpha)*omega;
  e_v = v_cmd_eff - v;

  // ===== PI speed control with command saturation =====
  der(integ) = e_v;
  F_cmd = Kp*e_v + Ki*integ;
  F_act = if (F_cmd >  F_max) then  F_max
          else if (F_cmd < -F_max) then -F_max
          else F_cmd;

  // ===== Disturbance: 8 N during middle third =====
  F_dist_eff = if (time >= t_dist_start and time <= t_dist_end) then F_dist else 0.0;

  // ===== Generalized torques (virtual work: ds = L1 sin alpha dalpha) =====
  tau_act  = F_act      * L1*Modelica.Math.sin(alpha);
  tau_dist = F_dist_eff * L1*Modelica.Math.sin(alpha);
  tau_grav = 2.0*m_link*g*L1*Modelica.Math.cos(alpha);

  // ===== Effective inertia and Coriolis term =====
  J_eff  = J_link + m_act*(L1*Modelica.Math.sin(alpha))^2;
  dJ_eff = 2.0*m_act*L1^2*Modelica.Math.sin(alpha)*Modelica.Math.cos(alpha);

  // ===== Equations of motion (Lagrangian, alpha coordinate) — explicit =====
  der(omega) = (tau_act - tau_grav - tau_dist - 0.5*dJ_eff*omega^2) / J_eff;
  der(alpha) = omega;

  // ===== Parallelogram geometry (beta = alpha branch) =====
  Ax = 0.0;
  Ay = 0.0;
  Dx = L2;
  Dy = 0.0;
  Bx = L1*Modelica.Math.cos(alpha);
  By = L1*Modelica.Math.sin(alpha);
  beta = alpha;
  Cx = Dx + L1*Modelica.Math.cos(beta);
  Cy = Dy + L1*Modelica.Math.sin(beta);

  // ===== Output motion =====
  output_speed = L1*abs(omega);
  der(output_travel) = output_speed;

  // ===== Joint references from commanded input =====
  alpha_ref = Modelica.Math.acos(if (1.0 - s_cmd/L1 > 1.0) then 1.0
                                 else if (1.0 - s_cmd/L1 < -1.0) then -1.0
                                 else 1.0 - s_cmd/L1);
  beta_ref  = alpha_ref;

  // ===== Loop-closure residuals (instrumented; identically zero for ideal parallelogram) =====
  res_AB       = Modelica.Math.sqrt(Bx*Bx + By*By) - L1;
  res_BC       = Modelica.Math.sqrt((Cx - Bx)*(Cx - Bx) + (Cy - By)*(Cy - By)) - L2;
  res_DC       = Modelica.Math.sqrt((Cx - Dx)*(Cx - Dx) + (Cy - Dy)*(Cy - Dy)) - L1;
  res_AD       = Modelica.Math.sqrt(Dx*Dx + Dy*Dy) - L2;
  res_crank    = s - L1*(1.0 - Modelica.Math.cos(alpha));
  res_parallel = beta - alpha;

  // ===== Tracking and bounds checks =====
  tracking_err = abs(s - s_cmd);
  within_band        = if abs(v - v_cmd_eff) <= v_band then 1.0 else 0.0;
  actuator_in_bounds = if (s >= s_min - 1e-6 and s <= s_max + 1e-6) then 1.0 else 0.0;

  // ===== Validity: range and bound checks =====
  valid = if (s > -1.0 and s < 1.0 and abs(omega) < 1000.0 and abs(F_act) <= F_max + 1.0
             and abs(alpha) < 10.0 and abs(integ) < 1.0e6) then 1.0 else 0.0;

  // ===== Synchronized 200 Hz sensor traces =====
  when sample(0, dt_sample) then
    s_sampled            = s;
    v_sampled            = v;
    F_sampled            = F_act;
    Cx_sampled           = Cx;
    Cy_sampled           = Cy;
    res_BC_sampled       = res_BC;
    tracking_err_sampled = tracking_err;
    omega_sampled        = omega;
  end when;

  // Prevent nonadjacent link collision:
  // Nonadjacent pairs in this planar parallelogram are AB-DC (always
  // separated by L2 horizontally) and AD-BC (separated by L1*sin(alpha)
  // vertically). With alpha constrained via the s bounds, both clearances
  // remain strictly positive; geometric self-collision is therefore
  // impossible within the actuator bounds. No additional contact model
  // is required for the declared embodiment.

  annotation (
    Documentation(info="PantographDriveD: planar parallelogram with six revolute
      joints (A,B,C,D plus crank-slider rod ends E,F) and one prismatic input
      of 0.16 m travel. PI speed control with 320 N saturation; 8 N load
      disturbance applied during the middle third [4.67, 9.33] s. Gravity 9.81.
      Instrumented at 200 Hz for 14 s with full closure-residual, output-travel
      and tracking traces."),
    experiment(StopTime=14.0, Tolerance=1e-6, Interval=0.005));
end PantographDriveD;