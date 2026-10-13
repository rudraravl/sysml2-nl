model SoftGripShapeF
  import Modelica.Units.SI;
  import Modelica.Constants;
  import Modelica.Math;

  // ===== Finger embodiment =====
  parameter SI.Length L = 0.13 "Silicone finger length";
  parameter Integer nSec = 4 "Bending sections per finger";
  parameter SI.Length Ls = L / nSec "Section length";
  parameter SI.Length rPalm = 0.025 "Rigid palm radius";
  parameter Real a1 = 0.0 "Finger 1 base angle [rad]";
  parameter Real a2 = 2.0 * Constants.pi / 3.0 "Finger 2 base angle [rad]";
  parameter Real a3 = 4.0 * Constants.pi / 3.0 "Finger 3 base angle [rad]";

  // ===== Actuation limits =====
  parameter SI.Pressure Pmax = 116000 "Maximum gauge pressure command";

  // ===== Reduced-order deformation model =====
  parameter Real kc = 3.0e-4 "Curvature-pressure gain [1/(m.Pa)]";
  parameter Real tau_c = 0.06 "Curvature first-order time constant [s]";
  parameter Real kLoad = 0.8 "Tip-load curvature sensitivity [1/(m.N)]";
  parameter Real kGrav = 0.5 "Gravity sag curvature coefficient [1/m]";

  // ===== Target shape =====
  parameter SI.Length rTarget = 0.12 "Desired fingertip radius from palm center";
  Real dx_target = rTarget - rPalm "Target radial offset of fingertip from palm edge";

  // ===== Controller (shape feedback) =====
  parameter Real kp = 7.0e5 "Proportional gain [Pa/m]";
  parameter Real kd = 3.0e4 "Derivative gain [Pa.s/m]";
  parameter Real tau_d = 0.02 "Derivative filter time constant [s]";
  parameter SI.Pressure P_bias = 33800 "Feedforward pressure for nominal target shape";

  // ===== Disturbance =====
  parameter SI.Force Fd_amp = 8.7 "Controlled tip load disturbance magnitude";

  // ===== Thermal model =====
  parameter SI.Temperature Tamb = 293.15 "Ambient temperature";
  parameter Real kHeat = 1.0e-6 "Dissipation heating coefficient [K/(s.Pa)]";
  parameter Real kCool = 0.003 "Convective cooling rate [1/s]";

  // ===== Verification thresholds =====
  parameter SI.Length e_thresh = 0.036 "Primary tracking error bound after 13 s [m]";
  parameter Real kMax = 80.0 "Curvature bound [1/m]";
  parameter SI.Temperature Tlim = 373.15 "Temperature upper limit [K]";

  // ===== Curvature states: 3 fingers x 4 sections =====
  Real k1s1(start=0), k1s2(start=0), k1s3(start=0), k1s4(start=0);
  Real k2s1(start=0), k2s2(start=0), k2s3(start=0), k2s4(start=0);
  Real k3s1(start=0), k3s2(start=0), k3s3(start=0), k3s4(start=0);

  // ===== Finger 1 forward kinematics =====
  Real p1s1, p1s2, p1s3, p1s4;
  Real t1_0 = 0, t1_1, t1_2, t1_3, t1_4;
  Real m1s1, m1s2, m1s3, m1s4;
  Real x1_1, x1_2, x1_3, x1_4;
  Real y1_1, y1_2, y1_3, y1_4;
  Real x1tip, y1tip, r1tip;

  // ===== Finger 2 forward kinematics =====
  Real p2s1, p2s2, p2s3, p2s4;
  Real t2_0 = 0, t2_1, t2_2, t2_3, t2_4;
  Real m2s1, m2s2, m2s3, m2s4;
  Real x2_1, x2_2, x2_3, x2_4;
  Real y2_1, y2_2, y2_3, y2_4;
  Real x2tip, y2tip, r2tip;

  // ===== Finger 3 forward kinematics =====
  Real p3s1, p3s2, p3s3, p3s4;
  Real t3_0 = 0, t3_1, t3_2, t3_3, t3_4;
  Real m3s1, m3s2, m3s3, m3s4;
  Real x3_1, x3_2, x3_3, x3_4;
  Real y3_1, y3_2, y3_3, y3_4;
  Real x3tip, y3tip, r3tip;

  // ===== Shared-frame (world) tip positions =====
  Real wx1, wy1, wx2, wy2, wx3, wy3;

  // ===== Shape error signals =====
  Real e1, e2, e3;
  Real e_max;
  Real e1_filt(start=0), e2_filt(start=0), e3_filt(start=0);

  // ===== Pressure commands (actuator) =====
  SI.Pressure Pc1, Pc2, Pc3;
  SI.Pressure Pc1_raw, Pc2_raw, Pc3_raw;

  // ===== Disturbance force =====
  Boolean dist_on;
  SI.Force F_dist1;

  // ===== Temperature sensors =====
  SI.Temperature T1(start=293.15), T2(start=293.15), T3(start=293.15);

  // ===== Finite-state machine =====
  Integer fsm(start=1) "1=approach,2=grip,3=disturb,4=hold";

  // ===== Verification flags =====
  Boolean track_ok "Primary tracking error <= 0.036 m after 13 s";
  Boolean actuator_ok "Pressures within [0, Pmax]";
  Boolean curvature_ok "All section curvatures bounded";
  Boolean temp_ok "Temperatures within physical range";
  Boolean fsm_ok "FSM in valid state";
  Boolean no_nan "No NaN or infinite values";

equation
  // ===== Finite-state machine =====
  when time >= 1.0 and pre(fsm) == 1 then
    fsm = 2;
  elsewhen time >= 6.667 and pre(fsm) == 2 then
    fsm = 3;
  elsewhen time >= 13.333 and pre(fsm) == 3 then
    fsm = 4;
  end when;

  // ===== Disturbance: 8.7 N tip load during middle third (6.667–13.333 s) =====
  dist_on = (time >= 6.667) and (time <= 13.333);
  F_dist1 = if dist_on then Fd_amp else 0.0;

  // ===== Finger 1 curvature dynamics =====
  tau_c * der(k1s1) = kc * Pc1 - k1s1 - kLoad * F_dist1 * 0.4 + kGrav * Math.cos(t1_0);
  tau_c * der(k1s2) = kc * Pc1 - k1s2 - kLoad * F_dist1 * 0.3 + kGrav * Math.cos(t1_1);
  tau_c * der(k1s3) = kc * Pc1 - k1s3 - kLoad * F_dist1 * 0.2 + kGrav * Math.cos(t1_2);
  tau_c * der(k1s4) = kc * Pc1 - k1s4 - kLoad * F_dist1 * 0.1 + kGrav * Math.cos(t1_3);

  // ===== Finger 2 curvature dynamics =====
  tau_c * der(k2s1) = kc * Pc2 - k2s1 + kGrav * Math.cos(t2_0);
  tau_c * der(k2s2) = kc * Pc2 - k2s2 + kGrav * Math.cos(t2_1);
  tau_c * der(k2s3) = kc * Pc2 - k2s3 + kGrav * Math.cos(t2_2);
  tau_c * der(k2s4) = kc * Pc2 - k2s4 + kGrav * Math.cos(t2_3);

  // ===== Finger 3 curvature dynamics =====
  tau_c * der(k3s1) = kc * Pc3 - k3s1 + kGrav * Math.cos(t3_0);
  tau_c * der(k3s2) = kc * Pc3 - k3s2 + kGrav * Math.cos(t3_1);
  tau_c * der(k3s3) = kc * Pc3 - k3s3 + kGrav * Math.cos(t3_2);
  tau_c * der(k3s4) = kc * Pc3 - k3s4 + kGrav * Math.cos(t3_3);

  // ===== Finger 1 forward kinematics (constant-curvature arc per section) =====
  p1s1 = k1s1 * Ls;
  p1s2 = k1s2 * Ls;
  p1s3 = k1s3 * Ls;
  p1s4 = k1s4 * Ls;
  t1_1 = t1_0 + p1s1;
  t1_2 = t1_1 + p1s2;
  t1_3 = t1_2 + p1s3;
  t1_4 = t1_3 + p1s4;
  m1s1 = t1_0 + p1s1 / 2.0;
  m1s2 = t1_1 + p1s2 / 2.0;
  m1s3 = t1_2 + p1s3 / 2.0;
  m1s4 = t1_3 + p1s4 / 2.0;
  x1_1 = Ls * Math.cos(m1s1);
  y1_1 = Ls * Math.sin(m1s1);
  x1_2 = x1_1 + Ls * Math.cos(m1s2);
  y1_2 = y1_1 + Ls * Math.sin(m1s2);
  x1_3 = x1_2 + Ls * Math.cos(m1s3);
  y1_3 = y1_2 + Ls * Math.sin(m1s3);
  x1_4 = x1_3 + Ls * Math.cos(m1s4);
  y1_4 = y1_3 + Ls * Math.sin(m1s4);
  x1tip = x1_4;
  y1tip = y1_4;
  r1tip = rPalm + x1tip;

  // ===== Finger 2 forward kinematics =====
  p2s1 = k2s1 * Ls;
  p2s2 = k2s2 * Ls;
  p2s3 = k2s3 * Ls;
  p2s4 = k2s4 * Ls;
  t2_1 = t2_0 + p2s1;
  t2_2 = t2_1 + p2s2;
  t2_3 = t2_2 + p2s3;
  t2_4 = t2_3 + p2s4;
  m2s1 = t2_0 + p2s1 / 2.0;
  m2s2 = t2_1 + p2s2 / 2.0;
  m2s3 = t2_2 + p2s3 / 2.0;
  m2s4 = t2_3 + p2s4 / 2.0;
  x2_1 = Ls * Math.cos(m2s1);
  y2_1 = Ls * Math.sin(m2s1);
  x2_2 = x2_1 + Ls * Math.cos(m2s2);
  y2_2 = y2_1 + Ls * Math.sin(m2s2);
  x2_3 = x2_2 + Ls * Math.cos(m2s3);
  y2_3 = y2_2 + Ls * Math.sin(m2s3);
  x2_4 = x2_3 + Ls * Math.cos(m2s4);
  y2_4 = y2_3 + Ls * Math.sin(m2s4);
  x2tip = x2_4;
  y2tip = y2_4;
  r2tip = rPalm + x2tip;

  // ===== Finger 3 forward kinematics =====
  p3s1 = k3s1 * Ls;
  p3s2 = k3s2 * Ls;
  p3s3 = k3s3 * Ls;
  p3s4 = k3s4 * Ls;
  t3_1 = t3_0 + p3s1;
  t3_2 = t3_1 + p3s2;
  t3_3 = t3_2 + p3s3;
  t3_4 = t3_3 + p3s4;
  m3s1 = t3_0 + p3s1 / 2.0;
  m3s2 = t3_1 + p3s2 / 2.0;
  m3s3 = t3_2 + p3s3 / 2.0;
  m3s4 = t3_3 + p3s4 / 2.0;
  x3_1 = Ls * Math.cos(m3s1);
  y3_1 = Ls * Math.sin(m3s1);
  x3_2 = x3_1 + Ls * Math.cos(m3s2);
  y3_2 = y3_1 + Ls * Math.sin(m3s2);
  x3_3 = x3_2 + Ls * Math.cos(m3s3);
  y3_3 = y3_2 + Ls * Math.sin(m3s3);
  x3_4 = x3_3 + Ls * Math.cos(m3s4);
  y3_4 = y3_3 + Ls * Math.sin(m3s4);
  x3tip = x3_4;
  y3tip = y3_4;
  r3tip = rPalm + x3tip;

  // ===== World-frame tip positions (shared frame, undeformed & actuated geometry) =====
  wx1 = rPalm * Math.cos(a1) + x1tip * Math.cos(a1) - y1tip * Math.sin(a1);
  wy1 = rPalm * Math.sin(a1) + x1tip * Math.sin(a1) + y1tip * Math.cos(a1);
  wx2 = rPalm * Math.cos(a2) + x2tip * Math.cos(a2) - y2tip * Math.sin(a2);
  wy2 = rPalm * Math.sin(a2) + x2tip * Math.sin(a2) + y2tip * Math.cos(a2);
  wx3 = rPalm * Math.cos(a3) + x3tip * Math.cos(a3) - y3tip * Math.sin(a3);
  wy3 = rPalm * Math.sin(a3) + x3tip * Math.sin(a3) + y3tip * Math.cos(a3);

  // ===== Shape error (radial deviation from target) =====
  e1 = x1tip - dx_target;
  e2 = x2tip - dx_target;
  e3 = x3tip - dx_target;
  e_max = max(abs(e1), max(abs(e2), abs(e3)));

  // ===== Filtered error for derivative term =====
  der(e1_filt) = (e1 - e1_filt) / tau_d;
  der(e2_filt) = (e2 - e2_filt) / tau_d;
  der(e3_filt) = (e3 - e3_filt) / tau_d;

  // ===== Shape-feedback controller (reduced-order deformation model) =====
  Pc1_raw = P_bias + kp * e1 + kd * (e1 - e1_filt) / tau_d;
  Pc2_raw = P_bias + kp * e2 + kd * (e2 - e2_filt) / tau_d;
  Pc3_raw = P_bias + kp * e3 + kd * (e3 - e3_filt) / tau_d;
  Pc1 = max(0.0, min(Pmax, Pc1_raw));
  Pc2 = max(0.0, min(Pmax, Pc2_raw));
  Pc3 = max(0.0, min(Pmax, Pc3_raw));

  // ===== Temperature dynamics (dissipation + cooling) =====
  der(T1) = kHeat * abs(Pc1) - kCool * (T1 - Tamb);
  der(T2) = kHeat * abs(Pc2) - kCool * (T2 - Tamb);
  der(T3) = kHeat * abs(Pc3) - kCool * (T3 - Tamb);

  // ===== Verification criteria =====
  track_ok = if time >= 13.0 then (e_max <= e_thresh) else true;
  actuator_ok = (Pc1 >= 0.0) and (Pc1 <= Pmax) and
                (Pc2 >= 0.0) and (Pc2 <= Pmax) and
                (Pc3 >= 0.0) and (Pc3 <= Pmax);
  curvature_ok = (abs(k1s1) < kMax) and (abs(k1s2) < kMax) and (abs(k1s3) < kMax) and (abs(k1s4) < kMax) and
                 (abs(k2s1) < kMax) and (abs(k2s2) < kMax) and (abs(k2s3) < kMax) and (abs(k2s4) < kMax) and
                 (abs(k3s1) < kMax) and (abs(k3s2) < kMax) and (abs(k3s3) < kMax) and (abs(k3s4) < kMax);
  temp_ok = (T1 > 200.0) and (T1 < Tlim) and (T2 > 200.0) and (T2 < Tlim) and (T3 > 200.0) and (T3 < Tlim);
  fsm_ok = (fsm >= 1) and (fsm <= 4);
  no_nan = (e_max < 1.0e10) and (e_max > -1.0e10) and
           (Pc1 < 1.0e10) and (Pc1 > -1.0e10) and
           (Pc2 < 1.0e10) and (Pc2 > -1.0e10) and
           (Pc3 < 1.0e10) and (Pc3 > -1.0e10) and
           (T1 < 1.0e10) and (T1 > -1.0e10) and
           (T2 < 1.0e10) and (T2 > -1.0e10) and
           (T3 < 1.0e10) and (T3 > -1.0e10) and
           (wx1 < 1.0e10) and (wx1 > -1.0e10) and
           (wy1 < 1.0e10) and (wy1 > -1.0e10);

  annotation(
    experiment(StartTime=0, StopTime=20, Tolerance=1e-6, Interval=0.002),
    Documentation(info="SoftGripShapeF: Three 0.13 m silicone fingers (4 bending sections each) around a rigid palm. Chamber-pressure commands (<=116 kPa gauge) bend fingers via a reduced-order constant-curvature model. Shape feedback controls tip radius to target. 8.7 N tip-load disturbance applied to finger 1 during middle third (6.667-13.333 s). Synchronized state, command, and sensor traces at 500 Hz (Interval=0.002 s) for 20 s. Verification: actuator bounds, curvature bounds, temperature bounds, FSM validity, tracking error < 0.036 m after 13 s, and no NaN/infinite values.")
  );
end SoftGripShapeF;