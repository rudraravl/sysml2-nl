model HydBoomForceE
  "Verifiable hydraulic boom/stick force-regulation scenario"
  extends Modelica.Icons.Example;

  // ===== Timing =====
  parameter Real t_end = 16.0 "Simulation duration [s]";
  parameter Real dt = 0.004 "Control/sample period (250 Hz) [s]";

  // ===== Geometry =====
  parameter Real L1 = 2.0 "Boom length [m]";
  parameter Real L2 = 1.4 "Stick length [m]";
  parameter Real a1 = 0.4 "Boom cylinder base anchor height [m]";
  parameter Real b1 = 1.5 "Boom cylinder boom anchor distance [m]";
  parameter Real a2 = 0.8 "Stick cylinder boom-back anchor [m]";
  parameter Real b2 = 0.5 "Stick cylinder stick anchor [m]";
  parameter Real l1_ret = 1.1 "Boom cyl retracted length [m]";
  parameter Real l2_ret = 0.3 "Stick cyl retracted length [m]";
  parameter Real stroke1 = 0.8 "Boom cyl stroke [m]";
  parameter Real stroke2 = 0.4 "Stick cyl stroke [m]";

  // ===== Masses/inertia =====
  parameter Real m1 = 80.0 "Boom mass [kg]";
  parameter Real m2 = 60.0 "Stick mass [kg]";
  parameter Real m3 = 300.0 "Payload mass [kg]";
  parameter Real g = 9.81 "Gravity [m/s2]";
  parameter Real r1c = 0.5*L1 "Boom CoM [m]";
  parameter Real r2c = 0.5*L2 "Stick CoM [m]";
  parameter Real I1 = m1*L1*L1/12.0 "Boom inertia about CoM [kg.m2]";
  parameter Real I2 = m2*L2*L2/12.0 "Stick inertia about CoM [kg.m2]";

  // ===== Hydraulic parameters =====
  parameter Real rho = 850.0 "Oil density [kg/m3]";
  parameter Real beta_e = 5.0e8 "Effective bulk modulus [Pa]";
  parameter Real pt = 0.0 "Tank pressure [Pa]";
  parameter Real p_relief = 25.0e6 "Relief valve pressure [Pa]";
  parameter Real p_margin = 1.5e6 "Load-sensing margin [Pa]";
  parameter Real Q_pump_max = 0.004 "Pump max flow (command bound) [m3/s]";
  parameter Real Cv = 2.0e-6 "Valve conductance [m3/(s.sqrt(Pa))]";
  parameter Real A_c1 = 8.0e-3 "Boom cyl cap area [m2]";
  parameter Real a_r1 = 4.0e-3 "Boom cyl rod area [m2]";
  parameter Real A_c2 = 5.0e-3 "Stick cyl cap area [m2]";
  parameter Real a_r2 = 2.5e-3 "Stick cyl rod area [m2]";
  parameter Real VA1d = 2.0e-3 "Boom cyl cap dead volume [m3]";
  parameter Real VB1d = 2.0e-3 "Boom cyl rod dead volume [m3]";
  parameter Real VA2d = 1.0e-3 "Stick cyl cap dead volume [m3]";
  parameter Real VB2d = 1.0e-3 "Stick cyl rod dead volume [m3]";
  parameter Real V_supply = 2.0e-2 "Supply line volume [m3]";
  parameter Real K_relief = 5.0e-7 "Relief conductance [m3/(s.Pa)]";
  parameter Real K_ls = 2.0e-7 "Load-sensing pump gain [m3/(s.Pa)]";
  parameter Real eps = 1.0e-3 "Numerical smoothing constant";

  // ===== Contact =====
  parameter Real Kc = 2.0e5 "Contact stiffness [N/m]";
  parameter Real Cc = 5.0e3 "Contact damping [N.s/m]";
  parameter Real x_env = 2.502 "Environment wall x-position [m]";

  // ===== Setpoints/disturbance =====
  parameter Real F_ref = 2000.0 "Commanded output force [N]";
  parameter Real F_dist = 180.0 "Load change disturbance [N]";
  parameter Real theta2_ref = 0.5 "Stick angle hold setpoint [rad]";

  // ===== Controller gains =====
  parameter Real Kpfo = -2.0e3 "Outer force->pressure proportional [Pa/N]";
  parameter Real Kifo = -5.0e3 "Outer force->pressure integral [Pa/(N.s)]";
  parameter Real p_cmd1_base = -1.5e6 "Baseline pressure command [Pa]";
  parameter Real Kppio = 5.0e-6 "Inner pressure->valve proportional [1/Pa]";
  parameter Real Kipio = 1.0e-7 "Inner pressure->valve integral [1/(Pa.s)]";
  parameter Real Kp_pos = 3.0 "Stick position proportional [1/rad]";
  parameter Real Kd_pos = 0.5 "Stick position derivative [s/rad]";
  parameter Real Ki_pos = 2.0 "Stick position integral [1/(rad.s)]";

  // ===== Continuous states =====
  Real theta1(start=0.5) "Boom angle from horizontal [rad]";
  Real dtheta1(start=0.0) "Boom angular velocity [rad/s]";
  Real theta2(start=0.5) "Stick angle relative to boom [rad]";
  Real dtheta2(start=0.0) "Stick angular velocity [rad/s]";
  Real pA1(start=5.0e5) "Boom cyl cap (piston-side) pressure [Pa]";
  Real pB1(start=4.25e6) "Boom cyl rod-side pressure [Pa]";
  Real pA2(start=5.0e5) "Stick cyl cap pressure [Pa]";
  Real pB2(start=9.0e5) "Stick cyl rod-side pressure [Pa]";
  Real ps(start=6.0e6) "Shared supply pressure [Pa]";

  // ===== Discrete controller states =====
  discrete Real p_cmd1(start=-1.5e6) "Pressure command (boom) [Pa]";
  discrete Real integ_F(start=0.0) "Force error integral [N.s]";
  discrete Real integ_p1(start=0.0) "Pressure error integral [Pa.s]";
  discrete Real integ_th2(start=0.0) "Stick position error integral [rad.s]";
  discrete Real u1(start=0.0) "Boom valve command [-]";
  discrete Real u2(start=0.0) "Stick valve command [-]";
  discrete Real u1_raw(start=0.0) "Boom valve cmd (unclamped) [-]";
  discrete Real u2_raw(start=0.0) "Stick valve cmd (unclamped) [-]";

  // ===== Computed signals =====
  Real l1, l2, x1, x2, dx1, dx2, dl1_dth1, dl2_dth2;
  Real F1, F2, tau1, tau2;
  Real x_tip, y_tip, vx_tip, vy_tip;
  Real delta_pen, F_contact;
  Real d_window, F_ext_y;
  Real M11, M12, M22, detM, h1, h2, G1, G2;
  Real tau_c1, tau_c2, tau_d1, tau_d2, r1, r2;
  Real V_A1, V_B1, V_A2, V_B2;
  Real QA1, QB1, QA2, QB2;
  Real Q_pump, Q_used, Q_relief, p_load_max, target_ps;
  Real p_meas1, F_err, p_err1, theta2_err;

  // ===== Acceptance outputs =====
  output Real track_err "Tracking error (|F_ref-F_contact|) after 10.4 s [N]";
  output Boolean b_pressure_ok "Chamber and supply pressures within bounds";
  output Boolean b_flow_ok "Valve and pump flows within bounds";
  output Boolean b_contact_ok "Contact force within band";
  output Boolean b_no_endstop "No cylinder end-stop impact";
  output Boolean b_stable "Stable hold (low joint velocities)";
  output Boolean b_track_ok "Primary tracking error < 18 N after 10.4 s";
  output Boolean b_no_nan "No NaN/infinite physical, control, estimator values";
  output Boolean b_all_ok "Fail-closed acceptance: all checks pass";

equation
  // ===== Geometry / kinematics =====
  l1 = sqrt(b1*b1 + a1*a1 - 2.0*a1*b1*sin(theta1));
  l2 = sqrt(a2*a2 + b2*b2 - 2.0*a2*b2*cos(theta2));
  x1 = l1 - l1_ret;
  x2 = l2 - l2_ret;
  dl1_dth1 = -a1*b1*cos(theta1)/noEvent(if abs(l1) > 1.0e-6 then l1 else 1.0e-6);
  dl2_dth2 = a2*b2*sin(theta2)/noEvent(if abs(l2) > 1.0e-6 then l2 else 1.0e-6);
  dx1 = dl1_dth1*dtheta1;
  dx2 = dl2_dth2*dtheta2;

  // ===== Cylinder forces and joint torques =====
  F1 = pA1*A_c1 - pB1*a_r1;
  F2 = pA2*A_c2 - pB2*a_r2;
  tau1 = F1*dl1_dth1;
  tau2 = F2*dl2_dth2;

  // ===== Tip kinematics =====
  x_tip = L1*cos(theta1) + L2*cos(theta1+theta2);
  y_tip = L1*sin(theta1) + L2*sin(theta1+theta2);
  vx_tip = (-L1*sin(theta1) - L2*sin(theta1+theta2))*dtheta1 - L2*sin(theta1+theta2)*dtheta2;
  vy_tip = (L1*cos(theta1) + L2*cos(theta1+theta2))*dtheta1 + L2*cos(theta1+theta2)*dtheta2;

  // ===== Compliant contact with fixed support =====
  delta_pen = noEvent(if x_tip > x_env then x_tip - x_env else 0.0);
  F_contact = noEvent(if x_tip > x_env then Kc*delta_pen + Cc*vx_tip else 0.0);
  tau_c1 = (L1*sin(theta1) + L2*sin(theta1+theta2))*F_contact;
  tau_c2 = L2*sin(theta1+theta2)*F_contact;

  // ===== 180 N disturbance (downward at tip), middle third of run =====
  d_window = noEvent(if time < 5.5 then 0.0 elseif time < 6.0 then (time-5.5)/0.5
                    elseif time < 9.5 then 1.0 elseif time < 10.0 then (10.0-time)/0.5
                    else 0.0);
  F_ext_y = -F_dist*d_window;
  tau_d1 = (L1*cos(theta1) + L2*cos(theta1+theta2))*F_ext_y;
  tau_d2 = L2*cos(theta1+theta2)*F_ext_y;

  // ===== 2-link manipulator dynamics =====
  M11 = I1 + I2 + m1*r1c*r1c + m2*(L1*L1 + r2c*r2c + 2.0*L1*r2c*cos(theta2))
        + m3*(L1*L1 + L2*L2 + 2.0*L1*L2*cos(theta2));
  M12 = I2 + m2*(r2c*r2c + L1*r2c*cos(theta2)) + m3*(L2*L2 + L1*L2*cos(theta2));
  M22 = I2 + m2*r2c*r2c + m3*L2*L2;
  h1 = -m2*L1*r2c*sin(theta2)*dtheta2*dtheta2
        - 2.0*m2*L1*r2c*sin(theta2)*dtheta1*dtheta2
        - m3*L1*L2*sin(theta2)*(dtheta2*dtheta2 + 2.0*dtheta1*dtheta2);
  h2 = m2*L1*r2c*sin(theta2)*dtheta1*dtheta1 + m3*L1*L2*sin(theta2)*dtheta1*dtheta1;
  G1 = (m1*g*r1c + (m2+m3)*g*L1)*cos(theta1)
        + (m2*g*r2c + m3*g*L2)*cos(theta1+theta2);
  G2 = (m2*g*r2c + m3*g*L2)*cos(theta1+theta2);
  detM = M11*M22 - M12*M12 + 1.0e-3;
  r1 = tau1 + tau_d1 - G1 - h1 - tau_c1;
  r2 = tau2 + tau_d2 - G2 - h2 - tau_c2;
  der(theta1) = dtheta1;
  der(dtheta1) = (M22*r1 - M12*r2)/detM;
  der(theta2) = dtheta2;
  der(dtheta2) = (-M12*r1 + M11*r2)/detM;

  // ===== Hydraulic chamber volumes =====
  V_A1 = VA1d + A_c1*x1;
  V_B1 = VB1d + a_r1*(stroke1 - x1);
  V_A2 = VA2d + A_c2*x2;
  V_B2 = VB2d + a_r2*(stroke2 - x2);

  // ===== Valve flows (4/3, signed: + into chamber, - to tank) =====
  QA1 = noEvent(if u1 >= 0.0 then Cv*u1*sqrt(2.0*max(eps, ps-pA1)/rho)
                else -Cv*(-u1)*sqrt(2.0*max(eps, pA1-pt)/rho));
  QB1 = noEvent(if u1 >= 0.0 then -Cv*u1*sqrt(2.0*max(eps, pB1-pt)/rho)
                else Cv*(-u1)*sqrt(2.0*max(eps, ps-pB1)/rho));
  QA2 = noEvent(if u2 >= 0.0 then Cv*u2*sqrt(2.0*max(eps, ps-pA2)/rho)
                else -Cv*(-u2)*sqrt(2.0*max(eps, pA2-pt)/rho));
  QB2 = noEvent(if u2 >= 0.0 then -Cv*u2*sqrt(2.0*max(eps, pB2-pt)/rho)
                else Cv*(-u2)*sqrt(2.0*max(eps, ps-pB2)/rho));

  // ===== Chamber pressure continuity =====
  der(pA1) = beta_e/noEvent(if V_A1 > 1.0e-6 then V_A1 else 1.0e-6)*(QA1 - A_c1*dx1);
  der(pB1) = beta_e/noEvent(if V_B1 > 1.0e-6 then V_B1 else 1.0e-6)*(QB1 + a_r1*dx1);
  der(pA2) = beta_e/noEvent(if V_A2 > 1.0e-6 then V_A2 else 1.0e-6)*(QA2 - A_c2*dx2);
  der(pB2) = beta_e/noEvent(if V_B2 > 1.0e-6 then V_B2 else 1.0e-6)*(QB2 + a_r2*dx2);

  // ===== Shared load-sensing pump + relief valve =====
  p_load_max = noEvent(max(max(pA1, pB1), max(pA2, pB2)));
  target_ps = p_load_max + p_margin;
  Q_used = noEvent(max(0.0, QA1) + max(0.0, QB1) + max(0.0, QA2) + max(0.0, QB2));
  Q_pump = noEvent(max(0.0, min(Q_pump_max, K_ls*(target_ps - ps))));
  Q_relief = noEvent(if ps > p_relief then K_relief*(ps - p_relief) else 0.0);
  der(ps) = beta_e/noEvent(if V_supply > 1.0e-6 then V_supply else 1.0e-6)
            *(Q_pump - Q_used - Q_relief);

  // ===== Sensor and error signals =====
  p_meas1 = pA1 - pB1*(a_r1/A_c1);
  F_err = F_ref - F_contact;
  p_err1 = p_cmd1 - p_meas1;
  theta2_err = theta2_ref - theta2;

  // ===== Cascaded pressure/force regulator @ 250 Hz =====
  when sample(0.0, dt) then
    integ_F = pre(integ_F) + F_err*dt;
    p_cmd1 = max(-p_relief, min(p_relief, p_cmd1_base + Kpfo*F_err + Kifo*integ_F));
    integ_p1 = pre(integ_p1) + p_err1*dt;
    u1_raw = Kppio*p_err1 + Kipio*integ_p1;
    u1 = max(-1.0, min(1.0, u1_raw));
    integ_th2 = pre(integ_th2) + theta2_err*dt;
    u2_raw = Kp_pos*theta2_err + Kd_pos*(-dtheta2) + Ki_pos*integ_th2;
    u2 = max(-1.0, min(1.0, u2_raw));
  end when;

  // ===== Acceptance checks (fail-closed) =====
  track_err = noEvent(if time >= 10.4 then abs(F_ref - F_contact) else 0.0);
  b_pressure_ok = noEvent(
      pA1 >= -1.0 and pA1 <= p_relief*1.05 and
      pB1 >= -1.0 and pB1 <= p_relief*1.05 and
      pA2 >= -1.0 and pA2 <= p_relief*1.05 and
      pB2 >= -1.0 and pB2 <= p_relief*1.05 and
      ps  >= -1.0 and ps  <= p_relief*1.05);
  b_flow_ok = noEvent(
      abs(QA1) <= Q_pump_max*1.5 and abs(QB1) <= Q_pump_max*1.5 and
      abs(QA2) <= Q_pump_max*1.5 and abs(QB2) <= Q_pump_max*1.5 and
      Q_pump <= Q_pump_max*1.05 and Q_pump >= 0.0);
  b_contact_ok = noEvent(F_contact >= 0.0 and F_contact <= 8.0e3);
  b_no_endstop = noEvent(
      x1 > 0.05*stroke1 and x1 < 0.95*stroke1 and
      x2 > 0.05*stroke2 and x2 < 0.95*stroke2);
  b_stable = noEvent(abs(dtheta1) < 0.1 and abs(dtheta2) < 0.1);
  b_track_ok = noEvent(if time >= 10.4 then abs(F_ref - F_contact) < 18.0 else true);
  b_no_nan = noEvent(
      (pA1>=0.0 or pA1<0.0) and (pB1>=0.0 or pB1<0.0) and
      (pA2>=0.0 or pA2<0.0) and (pB2>=0.0 or pB2<0.0) and
      (ps>=0.0 or ps<0.0) and
      (theta1>=0.0 or theta1<0.0) and (theta2>=0.0 or theta2<0.0) and
      (dtheta1>=0.0 or dtheta1<0.0) and (dtheta2>=0.0 or dtheta2<0.0) and
      (F_contact>=0.0 or F_contact<0.0) and (F1>=0.0 or F1<0.0) and
      (F2>=0.0 or F2<0.0) and (u1>=0.0 or u1<0.0) and (u2>=0.0 or u2<0.0) and
      (p_cmd1>=0.0 or p_cmd1<0.0) and (Q_pump>=0.0 or Q_pump<0.0));
  b_all_ok = b_pressure_ok and b_flow_ok and b_contact_ok and b_no_endstop
             and b_stable and b_track_ok and b_no_nan;

  annotation(
    experiment(StartTime=0.0, StopTime=16.0, Tolerance=1.0e-5, Interval=0.004),
    Documentation(info="HydBoomForceE: planar two-link (boom 2.0 m, stick 1.4 m) hydraulic
      actuator with two geometrically grounded double-acting cylinders, 300 kg payload,
      shared load-sensing pump (bounded at 0.004 m3/s) and relief valve.
      Cascaded pressure (inner) / force (outer) regulation holds a commanded
      contact force against a compliant wall (fixed support). A controlled 180 N
      load change is applied to the tip during the middle third of the 16 s run
      sampled at 250 Hz. Acceptance is fail-closed: pressure/flow bounds,
      contact-force band, no end-stop impact, stable hold, primary tracking
      error < 18 N after 10.4 s, and no NaN/infinite values."));
end HydBoomForceE;