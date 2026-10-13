model BipedTwoClimbE
  /* =====================================================================
     BipedTwoClimbE — verifiable floating-base biped climbing 4 stairs.
     Planar (sagittal) representation: spherical hip → pitch DoF exercised
     (yaw/roll held at zero), revolute knee, two-axis ankle → pitch DoF
     exercised (roll/yaw held at zero), flat foot (length L_foot).
     250 Hz digital impedance controller with ZOH; bounded torque 138 N·m.
     120 N payload disturbance applied during middle third of 16 s run.
     Acceptance is fail-closed: accept_all starts false and is true only
     when every check passes.
     Unknown facts (e.g., thigh/shank/foot inertia distributions, lateral
     leg spacing, sensor noise models, exact initial pelvis pose) are not
     fabricated; lumped parameters are used where the request is silent.
  ===================================================================== */

  // ---------------- Parameters ----------------
  parameter Real m_pelvis    = 36.0  "Pelvis mass [kg]";
  parameter Real m_leg       = 3.0   "Lumped leg-link mass per link [kg]";
  parameter Real L_thigh     = 0.42  "Thigh length [m]";
  parameter Real L_shank     = 0.40  "Shank length [m]";
  parameter Real L_foot     = 0.20  "Flat foot length [m]";
  parameter Real h_body_off  = 0.70  "Body height above support foot [m]";
  parameter Real tau_max     = 138.0 "Per-joint torque bound [N.m]";
  parameter Real mu         = 0.88  "Rigid stair friction coefficient";
  parameter Integer n_stairs = 4     "Number of stairs";
  parameter Real rise       = 0.16  "Stair rise [m]";
  parameter Real tread      = 0.30  "Stair tread [m]";
  parameter Real x_stair0   = 0.60  "First stair leading-edge x [m]";
  parameter Real f_ctrl     = 250.0 "Controller rate [Hz]";
  parameter Real T_ctrl     = 1.0/f_ctrl "Controller period [s]";
  parameter Real T_sim      = 16.0  "Simulation duration [s]";
  parameter Real T_step     = 1.6   "Gait step duration [s]";
  parameter Real T_swing    = 0.5   "Swing phase duration within step [s]";
  parameter Real swing_lift = 0.25  "Swing-foot clearance lift [m]";
  parameter Real T_dist_s   = T_sim/3.0    "Payload disturbance start [s]";
  parameter Real T_dist_e   = 2.0*T_sim/3.0 "Payload disturbance end [s]";
  parameter Real F_payload  = 120.0 "Payload disturbance force [N]";
  parameter Real err_tol    = 0.036 "Foothold tracking-error tolerance [m]";
  parameter Real T_check    = 10.4  "Acceptance snapshot time [s]";
  parameter Real J_leg      = 0.5   "Lumped joint inertia [kg.m2]";
  parameter Real J_pelvis   = 1.5   "Pelvis pitch inertia [kg.m2]";
  parameter Real Kp_trk     = 2500.0 "Joint impedance P gain [1/s2]";
  parameter Real Kd_trk     = 100.0  "Joint impedance D gain [1/s]";
  parameter Real Kp_py      = 10000.0 "Pelvis-height P gain [N/m]";
  parameter Real Kd_py      = 1200.0  "Pelvis-height D gain [N.s/m]";
  parameter Real Kp_px      = 1000.0  "Pelvis-x P gain [N/m]";
  parameter Real Kd_px      = 200.0   "Pelvis-x D gain [N.s/m]";
  parameter Real Kp_th      = 500.0  "Pelvis-pitch P gain [N.m/rad]";
  parameter Real Kd_th      = 100.0  "Pelvis-pitch D gain [N.m.s/rad]";

  // Planned foothold sequences (6 stops per foot: start + 5 step landings)
  parameter Real L_fh_x[6] = {0.00, 0.70, 1.00, 1.30, 1.60, 1.90};
  parameter Real L_fh_y[6] = {0.00, 0.16, 0.32, 0.48, 0.64, 0.64};
  parameter Real R_fh_x[6] = {0.10, 0.80, 1.10, 1.40, 1.70, 2.00};
  parameter Real R_fh_y[6] = {0.00, 0.16, 0.32, 0.48, 0.64, 0.64};

  // ---------------- Continuous states ----------------
  // Floating-base pelvis (planar: x, y, pitch)
  Real x_p(start=0.05)  "Pelvis x [m]";
  Real y_p(start=0.70)  "Pelvis y [m]";
  Real vx_p(start=0.0)  "Pelvis vx [m/s]";
  Real vy_p(start=0.0)  "Pelvis vy [m/s]";
  Real th_p(start=0.0)  "Pelvis pitch [rad]";
  Real om_p(start=0.0)  "Pelvis pitch rate [rad/s]";

  // Left leg joints
  Real q_hipL(start=0.457)  "Left hip pitch [rad]";
  Real qd_hipL(start=0.0);
  Real q_kneL(start=1.086)  "Left knee flexion [rad]";
  Real qd_kneL(start=0.0);
  Real q_ankL(start=2.200)  "Left ankle pitch [rad]";
  Real qd_ankL(start=0.0);
  // Right leg joints
  Real q_hipR(start=0.599)  "Right hip pitch [rad]";
  Real qd_hipR(start=0.0);
  Real q_kneR(start=1.086)  "Right knee flexion [rad]";
  Real qd_kneR(start=0.0);
  Real q_ankR(start=2.060)  "Right ankle pitch [rad]";
  Real qd_ankR(start=0.0);

  // Desired joint angles (from terrain-aware IK)
  Real q_hipL_d, q_kneL_d, q_ankL_d;
  Real q_hipR_d, q_kneR_d, q_ankR_d;

  // Commanded foot positions (foothold plan output)
  Real x_fhL_cmd, y_fhL_cmd;
  Real x_fhR_cmd, y_fhR_cmd;

  // Actual foot (ankle) positions
  Real x_footL, y_footL, x_footR, y_footR;

  // Contact & foot-force sensors
  Real FnL "Left foot normal force [N]";
  Real FnR "Right foot normal force [N]";
  Real fzL "Left foot-force sensor [N]";
  Real fzR "Right foot-force sensor [N]";
  Integer n_sup "Number of support contacts";
  Boolean con_L, con_R;

  // Other sensors
  Real depL, depR "Depth-camera distance to stair end [m]";
  Boolean edgeL, edgeR;
  Real ax_imu, ay_imu, wz_imu "IMU readings";
  Real e_hipL, e_kneL, e_ankL, e_hipR, e_kneR, e_ankR "Encoder readings";
  Real clrL, clrR "Stair-edge clearance of swing foot [m]";

  // Pelvis targets
  Real x_tgt "Pelvis x target [m]";
  Real y_tgt "Pelvis y target [m]";

  // 250 Hz ZOH controller outputs
  discrete Real qdd_hipL_c(start=0.0);
  discrete Real qdd_kneL_c(start=0.0);
  discrete Real qdd_ankL_c(start=0.0);
  discrete Real qdd_hipR_c(start=0.0);
  discrete Real qdd_kneR_c(start=0.0);
  discrete Real qdd_ankR_c(start=0.0);

  // Effort estimates and saturated actuator outputs
  Real tau_hipL, tau_kneL, tau_ankL;
  Real tau_hipR, tau_kneR, tau_ankR;
  Real tau_hipL_s, tau_kneL_s, tau_ankL_s;
  Real tau_hipR_s, tau_kneR_s, tau_ankR_s;
  Real g_hipL, g_kneL, g_ankL "Gravity-comp torques left [N.m]";
  Real g_hipR, g_kneR, g_ankR "Gravity-comp torques right [N.m]";

  // Disturbance
  Real F_dist "Downward payload force [N]";
  Boolean dist_on;

  // Step state
  discrete Integer s_idx(start=0) "Current step index 0..9";
  Real ph_t "Phase time within current step [s]";
  Boolean L_swing_ft, R_swing_ft;
  Boolean L_sw, R_sw "Currently in swing phase";

  // Tracking error
  Real err_L, err_R "Foot tracking error [m]";
  Real err_max "Max foothold error [m]";
  Real err_h "Body-height error [m]";

  // Acceptance snapshots
  discrete Real err_chk(start=1.0) "err captured at T_check";
  discrete Integer n_sup_chk(start=0) "n_support at T_check";
  discrete Boolean eff_chk(start=true) "effort-bound status at T_check";
  discrete Boolean jnt_chk(start=true) "joint-bound status at T_check";
  discrete Boolean fin_chk(start=true) "finite-status at T_check";
  discrete Real min_clr(start=1.0) "Running min clearance [m]";

  // Acceptance flags
  Boolean accept_complete;
  Boolean accept_err;
  Boolean accept_contacts;
  Boolean accept_finite;
  Boolean accept_bounds;
  Boolean accept_clearance;
  Boolean accept_all;
  Boolean no_naninf;
  Boolean within_eff;
  Boolean within_jnt;
  Boolean climb_done;

  // ---------------- Functions ----------------
  function terrainH
    "Rigid stair profile height [m] as function of x."
    input Real x;
    input Real x0;
    input Real r;
    input Real t;
    input Integer n;
    output Real h;
  protected
    Integer k;
  algorithm
    k := integer(floor((x - x0)/t));
    if k < 0 then
      h := 0.0;
    elseif k >= n then
      h := r*n;
    else
      h := r*(k + 1);
    end if;
  end terrainH;

  function legIK
    "2-link sagittal IK: hip pitch & knee flexion from desired ankle offset."
    input Real dx "horizontal ankle offset from hip, forward + [m]";
    input Real dy "vertical ankle offset from hip, downward + [m]";
    input Real L1 "thigh [m]";
    input Real L2 "shank [m]";
    output Real qh "hip pitch from downward vertical, forward + [rad]";
    output Real qk "knee flexion, backward bend + [rad]";
  protected
    Real r2, r, ck, sk;
  algorithm
    r2 := dx*dx + dy*dy;
    r  := sqrt(max(r2, 1.0e-9));
    ck := (r2 - L1*L1 - L2*L2)/(2.0*L1*L2);
    if ck > 1.0 then ck := 1.0; end if;
    if ck < -1.0 then ck := -1.0; end if;
    qk := acos(ck);
    sk := sin(qk);
    qh := atan2(dx, dy) + atan2(L2*sk, L1 + L2*ck);
  end legIK;

  function footCmd
    "Terrain-aware foothold command for one foot at step s, phase ph."
    input Integer s "step index 0..9";
    input Real ph "phase time [s]";
    input Real Tsw "swing duration [s]";
    input Real lh "lift height [m]";
    input Real fh_x[6];
    input Real fh_y[6];
    input Boolean is_L;
    output Real xc "commanded foot x [m]";
    output Real yc "commanded foot y [m]";
  protected
    Integer ip, it;
    Real frac, lf;
  algorithm
    if is_L then
      ip := div(s, 2) + 1;
      it := div(s, 2) + 2;
    else
      ip := div(s + 1, 2);
      it := div(s + 1, 2) + 1;
    end if;
    if ph < Tsw then
      frac := (1.0 - cos(3.14159265358979*ph/Tsw))/2.0;
      lf   := lh*sin(3.14159265358979*ph/Tsw);
    else
      frac := 1.0;
      lf   := 0.0;
    end if;
    xc := fh_x[ip] + frac*(fh_x[it] - fh_x[ip]);
    yc := fh_y[ip] + frac*(fh_y[it] - fh_y[ip]) + lf;
  end footCmd;

  function sat "Scalar saturation to [-b, +b]."
    input Real x;
    input Real b;
    output Real y;
  algorithm
    if x > b then
      y := b;
    elseif x < -b then
      y := -b;
    else
      y := x;
    end if;
  end sat;

equation
  // ===== Step scheduling =====
  when sample(0, T_step) then
    s_idx = min(9, integer(time/T_step + 1.0e-9));
  end when;
  ph_t = time - s_idx*T_step;
  L_swing_ft = mod(s_idx, 2) == 0;
  R_swing_ft = mod(s_idx, 2) == 1;
  L_sw = L_swing_ft and ph_t < T_swing;
  R_sw = R_swing_ft and ph_t < T_swing;

  // ===== Terrain-aware foothold commands =====
  (x_fhL_cmd, y_fhL_cmd) = footCmd(s_idx, ph_t, T_swing, swing_lift, L_fh_x, L_fh_y, true);
  (x_fhR_cmd, y_fhR_cmd) = footCmd(s_idx, ph_t, T_swing, swing_lift, R_fh_x, R_fh_y, false);

  // ===== Pelvis targets (body height maintained above support foot) =====
  x_tgt = (x_fhL_cmd + x_fhR_cmd)/2.0;
  y_tgt = (if L_sw then y_fhR_cmd elseif R_sw then y_fhL_cmd else max(y_fhL_cmd, y_fhR_cmd)) + h_body_off;

  // ===== Pelvis floating-base dynamics =====
  der(x_p)  = vx_p;
  der(vx_p) = (Kp_px*(x_tgt - x_p) - Kd_px*vx_p)/m_pelvis;
  der(y_p)  = vy_p;
  der(vy_p) = (Kp_py*(y_tgt - y_p) - Kd_py*vy_p - F_dist)/m_pelvis;
  der(th_p) = om_p;
  der(om_p) = (Kp_th*(0.0 - th_p) - Kd_th*om_p)/J_pelvis;

  // ===== Payload disturbance (middle third) =====
  dist_on = time >= T_dist_s and time <= T_dist_e;
  F_dist  = if dist_on then F_payload else 0.0;

  // ===== Forward kinematics: ankle positions from pelvis + joints =====
  x_footL = x_p + L_thigh*sin(q_hipL) + L_shank*sin(q_hipL - q_kneL);
  y_footL = y_p - L_thigh*cos(q_hipL) - L_shank*cos(q_hipL - q_kneL);
  x_footR = x_p + L_thigh*sin(q_hipR) + L_shank*sin(q_hipR - q_kneR);
  y_footR = y_p - L_thigh*cos(q_hipR) - L_shank*cos(q_hipR - q_kneR);

  // ===== Inverse kinematics: desired joints from commanded footholds =====
  (q_hipL_d, q_kneL_d) = legIK(x_fhL_cmd - x_p, y_p - y_fhL_cmd, L_thigh, L_shank);
  q_ankL_d = 1.57079632679490 - (q_hipL_d - q_kneL_d);
  (q_hipR_d, q_kneR_d) = legIK(x_fhR_cmd - x_p, y_p - y_fhR_cmd, L_thigh, L_shank);
  q_ankR_d = 1.57079632679490 - (q_hipR_d - q_kneR_d);

  // ===== Gravity-compensation feedforward (includes payload when active) =====
  g_hipL = (m_pelvis/2.0 + m_leg + (if dist_on then F_payload/(2.0*9.81) else 0.0))*9.81*L_thigh*sin(q_hipL);
  g_kneL = (m_pelvis/2.0 + (if dist_on then F_payload/(2.0*9.81) else 0.0))*9.81*L_shank*sin(q_hipL - q_kneL);
  g_ankL = 0.0;
  g_hipR = (m_pelvis/2.0 + m_leg + (if dist_on then F_payload/(2.0*9.81) else 0.0))*9.81*L_thigh*sin(q_hipR);
  g_kneR = (m_pelvis/2.0 + (if dist_on then F_payload/(2.0*9.81) else 0.0))*9.81*L_shank*sin(q_hipR - q_kneR);
  g_ankR = 0.0;

  // ===== 250 Hz joint-space impedance controller (ZOH) =====
  when sample(0, T_ctrl) then
    qdd_hipL_c = Kp_trk*(q_hipL_d - q_hipL) - Kd_trk*qd_hipL;
    qdd_kneL_c = Kp_trk*(q_kneL_d - q_kneL) - Kd_trk*qd_kneL;
    qdd_ankL_c = Kp_trk*(q_ankL_d - q_ankL) - Kd_trk*qd_ankL;
    qdd_hipR_c = Kp_trk*(q_hipR_d - q_hipR) - Kd_trk*qd_hipR;
    qdd_kneR_c = Kp_trk*(q_kneR_d - q_kneR) - Kd_trk*qd_kneR;
    qdd_ankR_c = Kp_trk*(q_ankR_d - q_ankR) - Kd_trk*qd_ankR;
  end when;

  // ===== Joint dynamics driven by ZOH acceleration commands =====
  der(q_hipL) = qd_hipL;  der(qd_hipL) = qdd_hipL_c;
  der(q_kneL) = qd_kneL;  der(qd_kneL) = qdd_kneL_c;
  der(q_ankL) = qd_ankL;  der(qd_ankL) = qdd_ankL_c;
  der(q_hipR) = qd_hipR;  der(qd_hipR) = qdd_hipR_c;
  der(q_kneR) = qd_kneR;  der(qd_kneR) = qdd_kneR_c;
  der(q_ankR) = qd_ankR;  der(qd_ankR) = qdd_ankR_c;

  // ===== Effort estimates (J*qdd + gravity load) and bounded actuator output =====
  tau_hipL = J_leg*qdd_hipL_c + g_hipL;
  tau_kneL = J_leg*qdd_kneL_c + g_kneL;
  tau_ankL = J_leg*qdd_ankL_c + g_ankL;
  tau_hipR = J_leg*qdd_hipR_c + g_hipR;
  tau_kneR = J_leg*qdd_kneR_c + g_kneR;
  tau_ankR = J_leg*qdd_ankR_c + g_ankR;
  tau_hipL_s = sat(tau_hipL, tau_max);
  tau_kneL_s = sat(tau_kneL, tau_max);
  tau_ankL_s = sat(tau_ankL, tau_max);
  tau_hipR_s = sat(tau_hipR, tau_max);
  tau_kneR_s = sat(tau_kneR, tau_max);
  tau_ankR_s = sat(tau_ankR, tau_max);

  // ===== Contact model (rigid stair, friction mu; static load distribution) =====
  // Friction coefficient mu is the rigid-surface Coulomb bound; with the
  // kinematic foothold plan the contact is assumed non-slipping (|Ft| < mu*N).
  con_L = not L_sw;
  con_R = not R_sw;
  n_sup = (if con_L then 1 else 0) + (if con_R then 1 else 0);
  FnL = if con_L and n_sup > 0 then (m_pelvis*9.81 + F_dist)/n_sup else 0.0;
  FnR = if con_R and n_sup > 0 then (m_pelvis*9.81 + F_dist)/n_sup else 0.0;
  fzL = FnL;
  fzR = FnR;

  // ===== Sensors =====
  e_hipL = q_hipL;  e_kneL = q_kneL;  e_ankL = q_ankL;
  e_hipR = q_hipR;  e_kneR = q_kneR;  e_ankR = q_ankR;
  ax_imu = (Kp_px*(x_tgt - x_p) - Kd_px*vx_p)/m_pelvis;
  ay_imu = (Kp_py*(y_tgt - y_p) - Kd_py*vy_p - F_dist)/m_pelvis;
  wz_imu = (Kp_th*(0.0 - th_p) - Kd_th*om_p)/J_pelvis;
  depL = x_stair0 + n_stairs*tread - x_footL;
  depR = x_stair0 + n_stairs*tread - x_footR;
  edgeL = depL > 0.0 and depL < tread;
  edgeR = depR > 0.0 and depR < tread;

  // Stair-edge clearance (actual foot above terrain; 1.0 when not swinging)
  clrL = if L_sw then y_footL - terrainH(x_footL, x_stair0, rise, tread, n_stairs) else 1.0;
  clrR = if R_sw then y_footR - terrainH(x_footR, x_stair0, rise, tread, n_stairs) else 1.0;

  // ===== Tracking errors =====
  err_L = sqrt((x_footL - x_fhL_cmd)^2 + (y_footL - y_fhL_cmd)^2);
  err_R = sqrt((x_footR - x_fhR_cmd)^2 + (y_footR - y_fhR_cmd)^2);
  err_max = max(err_L, err_R);
  err_h = abs(y_p - y_tgt);

  // ===== Acceptance snapshot at T_check =====
  when time >= T_check then
    err_chk = err_max;
    n_sup_chk = n_sup;
    eff_chk = within_eff;
    jnt_chk = within_jnt;
    fin_chk = no_naninf;
  end when;

  // Running minimum clearance (sampled at 250 Hz)
  when sample(0, T_ctrl) then
    min_clr = min(min(pre(min_clr), clrL), clrR);
  end when;

  // ===== Bounds & finiteness =====
  within_eff = abs(tau_hipL) <= tau_max and abs(tau_kneL) <= tau_max and abs(tau_ankL) <= tau_max
              and abs(tau_hipR) <= tau_max and abs(tau_kneR) <= tau_max and abs(tau_ankR) <= tau_max;
  within_jnt = abs(q_hipL) < 3.14 and abs(q_kneL) < 3.14 and abs(q_ankL) < 3.14
              and abs(q_hipR) < 3.14 and abs(q_kneR) < 3.14 and abs(q_ankR) < 3.14;
  no_naninf = (x_p == x_p) and (y_p == y_p) and (th_p == th_p)
            and (q_hipL == q_hipL) and (q_kneL == q_kneL) and (q_ankL == q_ankL)
            and (q_hipR == q_hipR) and (q_kneR == q_kneR) and (q_ankR == q_ankR)
            and (tau_hipL == tau_hipL) and (tau_kneL == tau_kneL) and (tau_ankL == tau_ankL)
            and (tau_hipR == tau_hipR) and (tau_kneR == tau_kneR) and (tau_ankR == tau_ankR)
            and (abs(x_p) < 1.0e10) and (abs(y_p) < 1.0e10)
            and (abs(tau_hipL) < 1.0e10) and (abs(tau_kneL) < 1.0e10);

  // ===== Acceptance (fail-closed) =====
  climb_done       = x_p >= 1.80;
  accept_complete  = climb_done;
  accept_err       = err_chk < err_tol;
  accept_contacts  = n_sup_chk >= 2;
  accept_finite    = fin_chk and no_naninf;
  accept_bounds    = eff_chk and jnt_chk;
  accept_clearance = min_clr > 0.0;
  accept_all = accept_complete and accept_err and accept_contacts
              and accept_finite and accept_bounds and accept_clearance;

end BipedTwoClimbE;