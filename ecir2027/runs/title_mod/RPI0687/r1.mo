model HydBoomTrackC
  "Fluid-power robotic actuator with feedforward flow control and pressure-position feedback"

  // -- Physical constants --
  parameter Real g = 9.81 "Gravitational acceleration (m/s2)";
  parameter Real beta_oil = 1.2e9 "Effective bulk modulus (Pa)";

  // -- Geometry (from requirement) --
  parameter Real L1 = 2.0 "Boom length (m)";
  parameter Real L2 = 1.4 "Stick length (m)";
  parameter Real m_load = 300.0 "Payload mass (kg)";
  // Link masses not stated in requirement -- treated as unknown;
  // dynamics use point-mass payload at the stick tip only.

  // -- Boom cylinder --
  parameter Real Ap1 = 0.0049 "Boom cylinder piston area (m2)";
  parameter Real Ar1 = 0.0028 "Boom cylinder rod area (m2)";
  parameter Real Ls1 = 1.0 "Boom cylinder stroke (m)";
  parameter Real Vd1a = 5e-5 "Boom cylinder dead volume A (m3)";
  parameter Real Vd1b = 5e-5 "Boom cylinder dead volume B (m3)";
  parameter Real r1 = 0.45 "Boom cylinder moment arm (m)";

  // -- Stick cylinder --
  parameter Real Ap2 = 0.0031 "Stick cylinder piston area (m2)";
  parameter Real Ar2 = 0.0018 "Stick cylinder rod area (m2)";
  parameter Real Ls2 = 0.7 "Stick cylinder stroke (m)";
  parameter Real Vd2a = 3e-5 "Stick cylinder dead volume A (m3)";
  parameter Real Vd2b = 3e-5 "Stick cylinder dead volume B (m3)";
  parameter Real r2 = 0.35 "Stick cylinder moment arm (m)";

  // -- Friction and leakage --
  parameter Real b1 = 80.0 "Boom viscous friction coefficient (N.m.s/rad)";
  parameter Real b2 = 50.0 "Stick viscous friction coefficient (N.m.s/rad)";
  parameter Real Cleak = 5e-13 "Cylinder internal leakage coefficient (m3/(s.Pa))";

  // -- Valve, pump, relief --
  parameter Real Qmax = 0.003 "Maximum command magnitude / pump flow (m3/s)";
  parameter Real p_relief = 28.0e6 "Relief valve cracking pressure (Pa)";
  parameter Real G_relief = 5.0e-8 "Relief valve conductance (m3/(s.Pa))";
  parameter Real V_supply = 2.0e-4 "Supply line volume (m3)";

  // -- Controller gains --
  parameter Real Kff = 1.0 "Feedforward gain";
  parameter Real Kp_pos = 12.0 "Position proportional gain (1/m)";
  parameter Real Kd_pos = 4.0 "Velocity derivative gain (s/m)";
  parameter Real Kp_pres = 3.0e-8 "Pressure feedback gain (1/Pa)";
  parameter Real Kp2 = 30.0 "Stick position gain (1/rad)";
  parameter Real Kd2 = 6.0 "Stick velocity gain (s/rad)";

  // -- Trajectory parameters --
  parameter Real theta1_0 = 0.30 "Initial boom angle (rad)";
  parameter Real theta2_0 = 0.15 "Initial stick angle (rad)";
  parameter Real t_seg1_start = 0.5 "Segment 1 start time (s)";
  parameter Real t_seg1_end = 4.0 "Segment 1 end time (s)";
  parameter Real t_seg2_start = 8.0 "Segment 2 start time (s)";
  parameter Real t_seg2_end = 11.5 "Segment 2 end time (s)";
  parameter Real y_amp1 = 0.8 "Segment 1 tip-height amplitude (m)";
  parameter Real y_amp2 = -0.5 "Segment 2 tip-height amplitude (m)";

  // -- Disturbance --
  parameter Real Fdist = 198.0 "Payload disturbance step (N)";
  parameter Real t_dist_start = 4.0 "Disturbance start (s, middle third)";
  parameter Real t_dist_end = 8.0 "Disturbance end (s, middle third)";

  // -- Initial conditions --
  parameter Real pa1_0 = 4.8e6 "Initial boom cylinder A pressure (Pa)";
  parameter Real pb1_0 = 1.0e6 "Initial boom cylinder B pressure (Pa)";
  parameter Real pa2_0 = 4.0e6 "Initial stick cylinder A pressure (Pa)";
  parameter Real pb2_0 = 1.0e6 "Initial stick cylinder B pressure (Pa)";
  parameter Real p_supply_0 = 6.0e6 "Initial supply pressure (Pa)";

  // -- Derived initial tip height --
  parameter Real y_tip_0 = L1 * sin(theta1_0) + L2 * sin(theta1_0 + theta2_0)
    "Initial tip height (m)";

  // ===== State variables =====
  Real theta1(start = theta1_0) "Boom angle (rad)";
  Real theta2(start = theta2_0) "Stick angle (rad)";
  Real omega1(start = 0.0) "Boom angular velocity (rad/s)";
  Real omega2(start = 0.0) "Stick angular velocity (rad/s)";
  Real pa1(start = pa1_0) "Boom cylinder chamber A pressure (Pa)";
  Real pb1(start = pb1_0) "Boom cylinder chamber B pressure (Pa)";
  Real pa2(start = pa2_0) "Stick cylinder chamber A pressure (Pa)";
  Real pb2(start = pb2_0) "Stick cylinder chamber B pressure (Pa)";
  Real p_supply(start = p_supply_0) "Supply / pump pressure (Pa)";

  // ===== Control variables =====
  Real u1_raw "Boom raw (unsaturated) valve command";
  Real u2_raw "Stick raw (unsaturated) valve command";
  Real u1 "Boom saturated valve command (-)";
  Real u2 "Stick saturated valve command (-)";
  Real u_pump "Pump flow command (m3/s)";
  Real u_cmd_norm "Normalized primary command (-)";

  // ===== Cylinder variables =====
  Real x1 "Boom cylinder piston position (m)";
  Real x2 "Stick cylinder piston position (m)";
  Real v1 "Boom cylinder piston velocity (m/s)";
  Real v2 "Stick cylinder piston velocity (m/s)";
  Real F1 "Boom cylinder net force (N)";
  Real F2 "Stick cylinder net force (N)";
  Real tau1 "Boom joint torque (N.m)";
  Real tau2 "Stick joint torque (N.m)";
  Real Va1 "Boom chamber A volume (m3)";
  Real Vb1 "Boom chamber B volume (m3)";
  Real Va2 "Stick chamber A volume (m3)";
  Real Vb2 "Stick chamber B volume (m3)";

  // ===== Disturbance =====
  Real F_dist_active "Active disturbance force (N)";
  Real tau_dist "Disturbance torque at stick joint (N.m)";

  // ===== Dynamics intermediates =====
  Real th1dd "Boom angular acceleration (rad/s2)";
  Real th2dd "Stick angular acceleration (rad/s2)";
  Real M11 "Mass matrix element 11";
  Real M12 "Mass matrix element 12";
  Real M22 "Mass matrix element 22";
  Real det_M "Mass matrix determinant";
  Real det_M_safe "Safeguarded determinant (lower-bounded)";
  Real C1 "Coriolis term boom";
  Real C2 "Coriolis term stick";
  Real G1 "Gravity torque boom";
  Real G2 "Gravity torque stick";

  // ===== Trajectory and tracking =====
  Real y_des "Desired tip height (m)";
  Real yd_des "Desired tip velocity (m/s)";
  Real y_tip "Actual tip height (m)";
  Real y_tip_dot "Actual tip velocity (m/s)";
  Real y_tip_ddot "Actual tip acceleration (m/s2)";
  Real err_pos "Tip position tracking error (m)";

  // ===== Flow variables =====
  Real Q_A1 "Flow into boom chamber A (m3/s)";
  Real Q_B1 "Flow out of boom chamber B (m3/s)";
  Real Q_A2 "Flow into stick chamber A (m3/s)";
  Real Q_B2 "Flow out of stick chamber B (m3/s)";
  Real Q_pump "Pump / supply flow (m3/s)";
  Real Q_relief "Relief valve flow (m3/s)";
  Real Q_supply_total "Total supply flow to valves (m3/s)";

  // ===== Feedforward =====
  Real denom_ff "Feedforward kinematic denominator";
  Real omega_ff "Feedforward boom angular velocity (rad/s)";
  Real Q_ff "Feedforward flow (m3/s)";

  // ===== Bounds checks =====
  Boolean b_travel "Travel bound satisfied";
  Boolean b_pressure "Pressure bound satisfied";
  Boolean b_flow "Flow / command bound satisfied";
  Boolean b_accel "Acceleration bound satisfied";
  Boolean b_err "Trajectory-error bound satisfied";
  Boolean b_relief "Relief-valve bound satisfied";
  Boolean bounds_ok "All bounds satisfied";
  Boolean err_after_78 "Primary tracking error below 0.019 m after 7.8 s";

equation
  // =====================
  // Trajectory generation (smooth two-segment smoothstep)
  // =====================
  y_des = y_tip_0
          + y_amp1 * smoothstep_s(time, t_seg1_start, t_seg1_end)
          + y_amp2 * smoothstep_s(time, t_seg2_start, t_seg2_end);

  yd_des = y_amp1 * smoothstep_ds(time, t_seg1_start, t_seg1_end)
          + y_amp2 * smoothstep_ds(time, t_seg2_start, t_seg2_end);

  // =====================
  // Forward kinematics
  // =====================
  y_tip = L1 * sin(theta1) + L2 * sin(theta1 + theta2);
  y_tip_dot = L1 * cos(theta1) * omega1
            + L2 * cos(theta1 + theta2) * (omega1 + omega2);
  err_pos = y_tip - y_des;

  // =====================
  // Payload disturbance (finite-duration step, middle third)
  // =====================
  F_dist_active = if time >= t_dist_start and time < t_dist_end then Fdist else 0.0;
  tau_dist = F_dist_active * L2 * cos(theta1 + theta2);

  // =====================
  // Manipulator dynamics (2-DOF planar, point mass at tip)
  // =====================
  M11 = m_load * (L1 * L1 + L2 * L2 + 2.0 * L1 * L2 * cos(theta2));
  M12 = m_load * (L2 * L2 + L1 * L2 * cos(theta2));
  M22 = m_load * L2 * L2;
  det_M = M11 * M22 - M12 * M12;
  det_M_safe = max(det_M, 100.0);

  C1 = -m_load * L1 * L2 * sin(theta2) * omega2 * (2.0 * omega1 + omega2);
  C2 =  m_load * L1 * L2 * sin(theta2) * omega1 * omega1;
  G1 =  m_load * g * (L1 * cos(theta1) + L2 * cos(theta1 + theta2));
  G2 =  m_load * g * L2 * cos(theta1 + theta2);

  // Solve M * [th1dd; th2dd] = rhs  via Cramer's rule
  th1dd = ( M22 * (tau1 - b1 * omega1 - C1 - G1)
           - M12 * (tau2 + tau_dist - b2 * omega2 - C2 - G2)) / det_M_safe;
  th2dd = ( M11 * (tau2 + tau_dist - b2 * omega2 - C2 - G2)
           - M12 * (tau1 - b1 * omega1 - C1 - G1)) / det_M_safe;

  der(theta1) = omega1;
  der(theta2) = omega2;
  der(omega1) = th1dd;
  der(omega2) = th2dd;

  // =====================
  // Cylinder kinematics (linearised, constant moment arm)
  // =====================
  x1 = theta1 * r1;
  x2 = theta2 * r2;
  v1 = omega1 * r1;
  v2 = omega2 * r2;

  Va1 = Ap1 * x1 + Vd1a;
  Vb1 = Ar1 * (Ls1 - x1) + Vd1b;
  Va2 = Ap2 * x2 + Vd2a;
  Vb2 = Ar2 * (Ls2 - x2) + Vd2b;

  F1 = pa1 * Ap1 - pb1 * Ar1;
  F2 = pa2 * Ap2 - pb2 * Ar2;
  tau1 = F1 * r1;
  tau2 = F2 * r2;

  // =====================
  // Hydraulic chamber pressure dynamics
  // =====================
  der(pa1) = (beta_oil / Va1) * (Q_A1 - Ap1 * v1 - Cleak * (pa1 - pb1));
  der(pb1) = (beta_oil / Vb1) * (-Q_B1 + Ar1 * v1 + Cleak * (pa1 - pb1));
  der(pa2) = (beta_oil / Va2) * (Q_A2 - Ap2 * v2 - Cleak * (pa2 - pb2));
  der(pb2) = (beta_oil / Vb2) * (-Q_B2 + Ar2 * v2 + Cleak * (pa2 - pb2));

  // =====================
  // Valve flow equations (flow-commanded proportional valves)
  // =====================
  Q_A1 = u1 * Qmax;
  Q_B1 = u1 * Qmax;
  Q_A2 = u2 * Qmax;
  Q_B2 = u2 * Qmax;

  // =====================
  // Load-sensing pump and relief valve
  // =====================
  Q_pump = u_pump;
  Q_supply_total = max(Q_A1, 0.0) + max(Q_A2, 0.0);
  Q_relief = max(0.0, p_supply - p_relief) * G_relief;
  der(p_supply) = (beta_oil / V_supply) * (Q_pump - Q_supply_total - Q_relief);
  u_pump = max(abs(u1), abs(u2)) * Qmax;

  // =====================
  // Feedforward flow control
  // =====================
  denom_ff = L1 * cos(theta1) + L2 * cos(theta1 + theta2);
  omega_ff = yd_des / max(denom_ff, 0.1);
  Q_ff = Ap1 * r1 * omega_ff;

  // =====================
  // Controller: feedforward + pressure-position feedback
  // =====================
  u1_raw = Kff * (Q_ff / Qmax)
         + Kp_pos * (y_des - y_tip)
         + Kd_pos * (yd_des - y_tip_dot)
         - Kp_pres * (pa1 - pb1);

  u2_raw = Kp2 * (theta2_0 - theta2)
         - Kd2 * omega2
         - Kp_pres * (pa2 - pb2);

  u1 = max(-1.0, min(1.0, u1_raw));
  u2 = max(-1.0, min(1.0, u2_raw));
  u_cmd_norm = u1;

  // =====================
  // Tip acceleration (sensor)
  // =====================
  y_tip_ddot = L1 * (cos(theta1) * th1dd - sin(theta1) * omega1 * omega1)
             + L2 * (cos(theta1 + theta2) * (th1dd + th2dd)
                     - sin(theta1 + theta2) * (omega1 + omega2) * (omega1 + omega2));

  // =====================
  // Bounds
  // =====================
  b_travel  = y_tip >= 0.0 and y_tip <= 4.0;
  b_pressure = pa1 < p_relief and pb1 < p_relief
             and pa2 < p_relief and pb2 < p_relief
             and p_supply < p_relief * 1.5;
  b_flow    = abs(u1) <= 1.0 + 1.0e-3 and abs(u2) <= 1.0 + 1.0e-3;
  b_accel   = abs(y_tip_ddot) <= 15.0;
  b_err     = abs(err_pos) <= 0.05;
  b_relief  = p_supply <= p_relief + 2.0e6;
  bounds_ok = b_travel and b_pressure and b_flow and b_accel and b_err and b_relief;
  err_after_78 = if time >= 7.8 then abs(err_pos) <= 0.019 else true;

  annotation(
    experiment(StartTime = 0, StopTime = 12, Tolerance = 1e-6, Interval = 0.008),
    Documentation(info = "HydBoomTrackC: fluid-power robotic actuator system with feedforward flow control
      and pressure-position feedback.  Two-segment smooth smoothstep trajectory for tip height.
      198 N payload step disturbance during middle third (4-8 s).  Two double-acting cylinders
      drive a 2.0 m boom and 1.4 m stick carrying a 300 kg payload.  Two valve sections share
      a load-sensing pump and relief valve.  Link masses not stated in requirement are treated
      as unknown; manipulator dynamics use point-mass payload only.  Viscous friction, internal
      leakage, and finite-duration disturbance are included.  Run at 125 Hz (Interval = 0.008 s)
      for 12 s.  Primary tracking error must be below 0.019 m after 7.8 s.")
  );
end HydBoomTrackC;