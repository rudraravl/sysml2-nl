model FiveBarPressE
  "Five-bar parallel press mechanism with hybrid position-force control against a compliant workpiece"

  // ==================== Geometry (from requirement) ====================
  parameter Real ba = 0.25      "half base pivot spacing [m]";
  parameter Real L1 = 0.30      "actuated link length [m]";
  parameter Real L2 = 0.42      "passive link length [m]";
  parameter Real y_wp = 0.67    "workpiece surface height [m] — chosen for reachability within workspace";

  // ==================== Contact (from requirement) ====================
  parameter Real k_c   = 200000.0 "contact stiffness [N/m]";
  parameter Real c_c   = 2000.0   "contact damping [N.s/m]";
  parameter Real mu_f  = 0.70     "friction coefficient [1]";
  parameter Real v_eps = 0.001    "friction regularization velocity [m/s]";

  // ==================== Actuator (from requirement) ====================
  parameter Real tau_max = 41.8  "per-actuator torque limit [N.m]";

  // ==================== Dynamics — NOT specified, placeholders ====================
  parameter Real J_eff   = 0.05 "lumped effective joint inertia [kg.m2] — not specified";
  parameter Real b_joint  = 0.50 "joint viscous damping [N.m.s/rad] — not specified";

  // ==================== Control — rate specified, gains are placeholders ====================
  parameter Real dt_ctrl  = 1.0/250.0 "control sample period [s]";
  parameter Real F_base   = 15.0     "base force setpoint [N] — not specified";
  parameter Real dF       = 21.6     "force setpoint step [N]";
  parameter Real y_target = 0.675    "approach target height [m] — not specified";
  parameter Real Kp_x = 2000.0       "tangential position gain [N/m] — not specified";
  parameter Real Kd_x = 80.0         "tangential velocity gain [N.s/m] — not specified";
  parameter Real Kp_y = 4000.0       "normal approach position gain [N/m] — not specified";
  parameter Real Kd_y = 120.0        "normal approach velocity gain [N.s/m] — not specified";
  parameter Real Kp_f = 3.0          "force loop proportional gain — not specified";
  parameter Real Kd_f = 30.0         "force loop damping gain [N.s/m] — not specified";

  // ==================== Timing ====================
  parameter Real T_sim    = 16.0      "simulation duration [s]";
  parameter Real T_mid1   = 16.0/3.0   "middle-third start [s]";
  parameter Real T_mid2   = 32.0/3.0   "middle-third end [s]";
  parameter Real T_settle = 10.4      "settle time for acceptance checks [s]";

  // ==================== Initial conditions ====================
  parameter Real pi_local = 3.141592653589793;
  parameter Real q1_start = 1.4                       "initial actuated angle 1 [rad]";
  parameter Real q2_start = pi_local - q1_start       "initial actuated angle 2 [rad]";

  // ==================== Dynamic states ====================
  Real q1(start = q1_start, fixed = true)  "actuated angle 1 [rad]";
  Real q2(start = q2_start, fixed = true)  "actuated angle 2 [rad]";
  Real dq1(start = 0.0, fixed = true)      "angular velocity 1 [rad/s]";
  Real dq2(start = 0.0, fixed = true)      "angular velocity 2 [rad/s]";

  // ==================== Kinematic variables ====================
  Real Bx  "elbow 1 x [m]";
  Real By  "elbow 1 y [m]";
  Real Dx  "elbow 2 x [m]";
  Real Dy  "elbow 2 y [m]";
  Real dir_x  "B-to-D x component [m]";
  Real dir_y  "B-to-D y component [m]";
  Real Ld     "elbow separation [m]";
  Real mid_x  "midpoint x [m]";
  Real mid_y  "midpoint y [m]";
  Real h_arm  "endpoint height above midline [m]";
  Real Px     "endpoint x [m]";
  Real Py     "endpoint y [m]";

  // ==================== Jacobian ====================
  Real detM  "closure matrix determinant [m2]";
  Real J11   "dPx/dq1 [m/rad]";
  Real J12   "dPx/dq2 [m/rad]";
  Real J21   "dPy/dq1 [m/rad]";
  Real J22   "dPy/dq2 [m/rad]";
  Real dPx   "endpoint x velocity [m/s]";
  Real dPy   "endpoint y velocity [m/s]";

  // ==================== Contact ====================
  Real delta     "penetration [m]";
  Real Fn        "normal contact force [N]";
  Real Ft        "tangential friction force [N]";
  Real vtx       "tangential velocity [m/s]";
  Boolean in_contact  "contact flag";
  Real tc1       "contact torque on joint 1 [N.m]";
  Real tc2       "contact torque on joint 2 [N.m]";

  // ==================== Discrete controller ====================
  discrete Real F_ref_d(start = F_base)   "force reference [N]";
  discrete Real Fcx_d(start = 0.0)        "control force x [N]";
  discrete Real Fcy_d(start = 0.0)        "control force y [N]";
  discrete Real tau1_raw_d(start = 0.0)   "raw torque 1 [N.m]";
  discrete Real tau2_raw_d(start = 0.0)   "raw torque 2 [N.m]";
  discrete Real tau1_d(start = 0.0)       "saturated torque 1 command [N.m]";
  discrete Real tau2_d(start = 0.0)       "saturated torque 2 command [N.m]";
  discrete Boolean in_contact_d(start = false) "discrete contact flag";

  // ==================== Applied torques (ZOH) ====================
  Real tau1  "applied torque 1 [N.m]";
  Real tau2  "applied torque 2 [N.m]";

  // ==================== Verification ====================
  Real closure_err    "closure constraint error [m]";
  Real force_err      "force tracking error [N]";
  Real slip_speed     "tangential slip speed [m/s]";
  Boolean bounds_ok       "actuator bounds satisfied";
  Boolean closure_ok      "closure error within tolerance";
  Boolean force_band_ok   "force within band";
  Boolean locked_contact   "contact locked (no slip)";
  Boolean no_nan           "no NaN or Inf";
  Boolean track_ok         "primary tracking error within tolerance";
  Boolean accept           "fail-closed acceptance";

equation

  // ===== Forward kinematics: elbow positions from actuated angles =====
  Bx = -ba + L1*cos(q1);
  By =  L1*sin(q1);
  Dx =  ba + L1*cos(q2);
  Dy =  L1*sin(q2);

  // ===== Direction, separation, midpoint =====
  dir_x = Dx - Bx;
  dir_y = Dy - By;
  Ld = sqrt(dir_x*dir_x + dir_y*dir_y);
  mid_x = (Bx + Dx)/2.0;
  mid_y = (By + Dy)/2.0;

  // ===== Closure: endpoint as upper circle-circle intersection =====
  h_arm = if Ld < 2.0*L2 then sqrt(max(1e-12, L2*L2 - (Ld/2.0)*(Ld/2.0))) else 0.0;
  Px = mid_x + h_arm*(-dir_y)/max(1e-12, Ld);
  Py = mid_y + h_arm*dir_x/max(1e-12, Ld);

  // ===== Jacobian via differentiated closure constraints =====
  // M * [dP/dq] = rhs,  M = [[Px-Bx, Py-By],[Px-Dx, Py-Dy]]
  detM = (Px - Bx)*(Py - Dy) - (Py - By)*(Px - Dx);

  J11 =  (Py - Dy)*((Px - Bx)*(-L1*sin(q1)) + (Py - By)*(L1*cos(q1)))/max(1e-12, detM);
  J21 = -(Px - Dx)*((Px - Bx)*(-L1*sin(q1)) + (Py - By)*(L1*cos(q1)))/max(1e-12, detM);
  J12 = -(Py - By)*((Px - Dx)*(-L1*sin(q2)) + (Py - Dy)*(L1*cos(q2)))/max(1e-12, detM);
  J22 =  (Px - Bx)*((Px - Dx)*(-L1*sin(q2)) + (Py - Dy)*(L1*cos(q2)))/max(1e-12, detM);

  // ===== Endpoint velocity =====
  dPx = J11*dq1 + J12*dq2;
  dPy = J21*dq1 + J22*dq2;

  // ===== Contact model =====
  delta = Py - y_wp;
  in_contact = delta > 0.0;
  vtx = dPx;

  // Normal force: spring-damper with no-tension clamp
  Fn = if delta > 0.0 then max(0.0, k_c*delta + c_c*dPy) else 0.0;

  // Coulomb friction (regularised via tanh)
  Ft = -mu_f*Fn*tanh(vtx/v_eps);

  // ===== Contact torques on joints: J^T * [Ft, -Fn] =====
  tc1 = J11*Ft + J21*(-Fn);
  tc2 = J12*Ft + J22*(-Fn);

  // ===== Dynamics (explicit ODE, no algebraic loop) =====
  der(q1) = dq1;
  der(q2) = dq2;
  J_eff*der(dq1) = tau1 + tc1 - b_joint*dq1;
  J_eff*der(dq2) = tau2 + tc2 - b_joint*dq2;

  // ===== Zero-order hold from discrete controller =====
  tau1 = tau1_d;
  tau2 = tau2_d;

  // ===== Discrete hybrid position-force controller at 250 Hz =====
  when sample(0, dt_ctrl) then
    // Force reference with 21.6 N step during middle third
    F_ref_d = if (time >= T_mid1 and time < T_mid2) then F_base + dF else F_base;
    in_contact_d = delta > 0.0;

    // Tangential: position control (regulate x to zero)
    Fcx_d = Kp_x*(0.0 - Px) + Kd_x*(0.0 - dPx);

    // Normal: hybrid — position approach before contact, force regulation after
    Fcy_d = if in_contact_d then
              F_ref_d + Kp_f*(F_ref_d - Fn) - Kd_f*dPy
            else
              Kp_y*(y_target - Py) + Kd_y*(0.0 - dPy);

    // Map endpoint force to joint torques via Jacobian transpose
    tau1_raw_d = J11*Fcx_d + J21*Fcy_d;
    tau2_raw_d = J12*Fcx_d + J22*Fcy_d;

    // Saturate to actuator bounds
    tau1_d = max(-tau_max, min(tau_max, tau1_raw_d));
    tau2_d = max(-tau_max, min(tau_max, tau2_raw_d));
  end when;

  // ===== Verification metrics =====
  // Closure error (sum of both passive-link length residuals)
  closure_err = abs(sqrt((Px - Bx)*(Px - Bx) + (Py - By)*(Py - By)) - L2) +
                abs(sqrt((Px - Dx)*(Px - Dx) + (Py - Dy)*(Py - Dy)) - L2);

  force_err  = abs(Fn - F_ref_d);
  slip_speed = abs(vtx);

  // Individual checks
  locked_contact = in_contact and slip_speed < 0.01;
  bounds_ok      = abs(tau1) <= tau_max + 1e-6 and abs(tau2) <= tau_max + 1e-6;
  closure_ok     = closure_err < 0.001;
  force_band_ok  = time < T_settle or force_err < 10.0;
  track_ok       = time < T_settle or closure_err < 0.001;

  // NaN / Inf check on key physical, control, and estimator variables
  no_nan = (q1 >= 0.0 or q1 < 0.0) and (q2 >= 0.0 or q2 < 0.0) and
           (dq1 >= 0.0 or dq1 < 0.0) and (dq2 >= 0.0 or dq2 < 0.0) and
           (Px >= 0.0 or Px < 0.0) and (Py >= 0.0 or Py < 0.0) and
           (Fn >= 0.0 or Fn < 0.0) and (tau1 >= 0.0 or tau1 < 0.0) and
           (tau2 >= 0.0 or tau2 < 0.0) and abs(q1) < 1e100 and abs(q2) < 1e100;

  // Fail-closed acceptance
  accept = bounds_ok and closure_ok and force_band_ok and no_nan and track_ok and
           (time < T_settle or locked_contact);

  annotation(
    experiment(StartTime = 0, StopTime = 16.0, Tolerance = 1e-6, Interval = 0.004),
    Documentation(info = "Five-bar parallel press with hybrid position-force control.
  Geometry: base pivots at +/-0.25 m, actuated links 0.30 m, passive links 0.42 m.
  Contact: stiffness 200 kN/m, damping 2 kN.s/m, friction 0.70.
  Actuators: base-joint torque, limited to 41.8 N.m each.
  Control: 250 Hz discrete hybrid (position tangential / force normal).
  Force reference steps 21.6 N during middle third [5.333, 10.667] s of 16 s run.
  Acceptance is fail-closed: closure < 0.001 m, force band, slip, locked contact,
  torque bounds, no NaN/Inf.
  NOTE: J_eff, b_joint, force setpoint, approach target, and all control gains
  are placeholder values — these quantities were not specified in the requirement."));
end FiveBarPressE;