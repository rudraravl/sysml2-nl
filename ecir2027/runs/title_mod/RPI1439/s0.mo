model ElectroSoftAvoidE
  // ===== Requirement-stated parameters =====
  parameter Real L_mem(unit="m") = 0.20 "Membrane length";
  parameter Real W_mem(unit="m") = 0.05 "Membrane width";
  parameter Real h_mem(unit="m") = 0.8e-3 "Membrane thickness";
  parameter Real V_max(unit="V") = 5500.0 "Command magnitude bound 5.5 kV";
  parameter Real mu_obs = 0.55 "Obstacle friction coefficient";
  parameter Real F_dist(unit="N") = 9.6 "Lateral tip load magnitude";
  parameter Real T_sim(unit="s") = 16.0 "Simulation duration";
  parameter Real f_ctrl(unit="Hz") = 250.0 "Control and trace rate";
  parameter Real Ts(unit="s") = 1.0/f_ctrl "Control period";

  // ===== Explicit permittivity (value not stated in requirement; assumed, to be validated) =====
  parameter Real eps_r = 3.0 "Relative permittivity (assumed typical DEA silicone)";
  constant Real eps0(unit="F/m") = 8.8541878128e-12 "Vacuum permittivity";

  // ===== Assumed (not requirement-stated) physical parameters =====
  parameter Real rho_m(unit="kg/m3") = 1100.0 "Membrane density (assumed)";
  parameter Real R_leak(unit="ohm") = 1.0e10 "Leakage resistance (assumed)";
  parameter Real C_th(unit="J/K") = 0.05 "Thermal capacity (assumed)";
  parameter Real G_th(unit="W/K") = 0.005 "Thermal conductance (assumed)";
  parameter Real T_amb(unit="K") = 293.15 "Ambient temperature (assumed)";

  parameter Real k0(unit="N.m/rad") = 1.0 "Base joint stiffness (assumed)";
  parameter Real dk_stiff(unit="N.m/rad") = 11.0 "Voltage-induced stiffness (assumed)";
  parameter Real k_hold_add(unit="N.m/rad") = 6.0 "Hold stiffness addition (assumed)";
  parameter Real d0(unit="N.m.s/rad") = 0.08 "Joint viscous damping (assumed)";
  parameter Real kt_act(unit="N.m/Pa") = 4.0e-3 "Actuation torque per Maxwell pressure (assumed)";

  // Obstacle placement (assumed geometry)
  parameter Real cx_obs(unit="m") = 0.08 "Obstacle center x (assumed)";
  parameter Real cy_obs(unit="m") = 0.035 "Obstacle center y (assumed)";
  parameter Real R_obs(unit="m") = 0.018 "Obstacle radius (assumed)";

  // Target (assumed)
  parameter Real x_t(unit="m") = 0.16 "Target tip x (assumed)";
  parameter Real y_t(unit="m") = 0.11 "Target tip y (assumed)";

  // Section model (3 lumped sections)
  parameter Real Ls(unit="m") = L_mem/3.0 "Section length";
  parameter Real m_sec(unit="kg") = rho_m*Ls*W_mem*h_mem "Section mass";
  parameter Real I_sec(unit="kg.m2") = m_sec*Ls*Ls/3.0 "Section inertia about joint";

  // Contact
  parameter Real k_c(unit="N/m") = 5000.0 "Contact stiffness (assumed)";
  parameter Real d_c(unit="N.s/m") = 20.0 "Contact damping (assumed)";
  parameter Real v_small(unit="m/s") = 0.01 "Friction regularization velocity";

  // Slew limit
  parameter Real dVdt_max(unit="V/s") = 30000.0 "HV slew limit (assumed)";
  parameter Real k_slew(unit="1/s") = 50.0 "Slew tracking gain (assumed)";

  // Control gains (assumed)
  parameter Real Kp_v = 40000.0 "Proportional voltage gain";
  parameter Real Ki_v = 200000.0 "Integral voltage gain";
  parameter Real Kd_v = 3000.0 "Derivative voltage gain";
  parameter Real e_int_max = 0.0125 "Integral anti-windup clamp";
  parameter Real e_hold_thresh(unit="m") = 0.04 "Hold activation threshold";
  parameter Real F_ref(unit="N") = 5.0 "Contact normalization reference";
  parameter Real hold_ramp_rate(unit="1/s") = 0.4 "Hold factor ramp rate";

  // ===== Dynamic states =====
  Real theta1(start=0.0) "Section 1 deformation angle";
  Real theta2(start=0.0) "Section 2 deformation angle";
  Real theta3(start=0.0) "Section 3 deformation angle";
  Real omega1(start=0.0);
  Real omega2(start=0.0);
  Real omega3(start=0.0);
  Real V_act(start=0.0) "Actual slewed high voltage";
  discrete Real V_cmd(start=0.0) "Commanded high voltage (250 Hz)";
  Real e_int(start=0.0) "Integral tracking error";
  Real T_mem(start=T_amb) "Membrane temperature";
  Real hold_factor(start=0.0) "Bounded stiffness scheduling factor [0,1]";

  // ===== Kinematics =====
  Real a1,a2,a3 "Cumulative angles";
  Real x_tip,y_tip "Tip pose";
  Real P1x,P1y,P2x,P2y "Joint positions";
  Real M1x,M1y,M2x,M2y,M3x,M3y "Section midpoints";
  Real dM1x,dM1y,dM2x,dM2y,dM3x,dM3y "Midpoint velocities";

  // ===== Actuator physics =====
  Real p_maxwell(unit="Pa") "Maxwell pressure";
  Real I_leak(unit="A") "Leakage current";
  Real P_leak(unit="W") "Leakage Joule power";
  Real k_eff(unit="N.m/rad") "Effective scheduled joint stiffness";
  Real tau_act(unit="N.m") "Actuation torque per joint";

  // ===== Contact =====
  Real d1,d2,d3,d_tip "Distances to obstacle center";
  Real pen1,pen2,pen3 "Penetration depths";
  Real vp1,vp2,vp3 "Penetration velocities";
  Real n1x,n1y,n2x,n2y,n3x,n3y "Contact normals";
  Real t1x,t1y,t2x,t2y,t3x,t3y "Tangential directions";
  Real vt1,vt2,vt3 "Tangential velocities";
  Real Fn1,Fn2,Fn3 "Normal contact forces";
  Real Ff1x,Ff1y,Ff2x,Ff2y,Ff3x,Ff3y "Friction forces";
  Real Fc1x,Fc1y,Fc2x,Fc2y,Fc3x,Fc3y "Total contact force per section";
  Real F_contact1,F_contact2,F_contact3 "Distributed contact force magnitudes";
  Real F_contact_total "Total distributed contact force";
  Real contact_scale "Contact-aware command reduction factor";
  Real clearance "Obstacle clearance";

  // ===== Disturbance =====
  Real F_tip_dist_y "Lateral tip load y-component";

  // ===== Control and acceptance =====
  Boolean hold_active "Hold/stiffen mode active";
  Real e_primary "Primary tracking error magnitude";
  Real e_x,e_y "Tip position errors";
  Boolean accept_ok(start=true) "Fail-closed acceptance flag";

  // ===== Synchronized output traces =====
  output Real y_V_act = V_act "Actuator state trace";
  output Real y_V_cmd = V_cmd "Command trace";
  output Real y_F_contact = F_contact_total "Distributed contact force trace";
  output Real y_theta1 = theta1 "Section 1 deformation trace";
  output Real y_theta2 = theta2 "Section 2 deformation trace";
  output Real y_theta3 = theta3 "Section 3 deformation trace";
  output Real y_x_tip = x_tip "Tip x pose trace";
  output Real y_y_tip = y_tip "Tip y pose trace";
  output Real y_T = T_mem "Temperature trace";
  output Real y_clearance = clearance "Obstacle clearance trace";
  output Real y_e_primary = e_primary "Primary tracking error trace";
  output Real y_hold = hold_factor "Stiffness scheduling trace";

equation
  // Cumulative angles
  a1 = theta1;
  a2 = theta1 + theta2;
  a3 = theta1 + theta2 + theta3;

  // Joint positions and tip pose
  P1x = Ls*cos(a1);
  P1y = Ls*sin(a1);
  P2x = P1x + Ls*cos(a2);
  P2y = P1y + Ls*sin(a2);
  x_tip = P2x + Ls*cos(a3);
  y_tip = P2y + Ls*sin(a3);

  // Section midpoints
  M1x = (Ls/2.0)*cos(a1);
  M1y = (Ls/2.0)*sin(a1);
  M2x = P1x + (Ls/2.0)*cos(a2);
  M2y = P1y + (Ls/2.0)*sin(a2);
  M3x = P2x + (Ls/2.0)*cos(a3);
  M3y = P2y + (Ls/2.0)*sin(a3);

  // Midpoint velocities
  dM1x = -(Ls/2.0)*sin(a1)*omega1;
  dM1y =  (Ls/2.0)*cos(a1)*omega1;
  dM2x = -Ls*sin(a1)*omega1 - (Ls/2.0)*sin(a2)*(omega1+omega2);
  dM2y =  Ls*cos(a1)*omega1 + (Ls/2.0)*cos(a2)*(omega1+omega2);
  dM3x = -Ls*sin(a2)*(omega1+omega2) - (Ls/2.0)*sin(a3)*(omega1+omega2+omega3);
  dM3y =  Ls*cos(a2)*(omega1+omega2) + (Ls/2.0)*cos(a3)*(omega1+omega2+omega3);

  // Actuator: DEA Maxwell pressure, leakage, thermal
  p_maxwell = eps0*eps_r*(V_act/h_mem)^2;
  I_leak = V_act/R_leak;
  P_leak = V_act*I_leak;
  k_eff = k0 + dk_stiff*(V_act/V_max)^2 + k_hold_add*hold_factor;
  tau_act = kt_act*p_maxwell;
  der(T_mem) = (P_leak - G_th*(T_mem - T_amb))/C_th;

  // Disturbance: 9.6 N lateral tip load during middle third
  F_tip_dist_y = if (time >= T_sim/3.0 and time <= 2.0*T_sim/3.0) then -F_dist else 0.0;

  // Contact against fixed cylinder (collision enabled)
  d1 = max(1e-6, sqrt((M1x-cx_obs)^2 + (M1y-cy_obs)^2));
  d2 = max(1e-6, sqrt((M2x-cx_obs)^2 + (M2y-cy_obs)^2));
  d3 = max(1e-6, sqrt((M3x-cx_obs)^2 + (M3y-cy_obs)^2));
  d_tip = max(1e-6, sqrt((x_tip-cx_obs)^2 + (y_tip-cy_obs)^2));

  n1x = (M1x-cx_obs)/d1;  n1y = (M1y-cy_obs)/d1;
  n2x = (M2x-cx_obs)/d2;  n2y = (M2y-cy_obs)/d2;
  n3x = (M3x-cx_obs)/d3;  n3y = (M3y-cy_obs)/d3;
  t1x = -n1y;  t1y = n1x;
  t2x = -n2y;  t2y = n2x;
  t3x = -n3y;  t3y = n3x;

  pen1 = max(0.0, R_obs - d1);
  pen2 = max(0.0, R_obs - d2);
  pen3 = max(0.0, R_obs - d3);

  vp1 = -((M1x-cx_obs)*dM1x + (M1y-cy_obs)*dM1y)/d1;
  vp2 = -((M2x-cx_obs)*dM2x + (M2y-cy_obs)*dM2y)/d2;
  vp3 = -((M3x-cx_obs)*dM3x + (M3y-cy_obs)*dM3y)/d3;

  Fn1 = if d1 < R_obs then (k_c*pen1 + d_c*vp1) else 0.0;
  Fn2 = if d2 < R_obs then (k_c*pen2 + d_c*vp2) else 0.0;
  Fn3 = if d3 < R_obs then (k_c*pen3 + d_c*vp3) else 0.0;

  vt1 = dM1x*t1x + dM1y*t1y;
  vt2 = dM2x*t2x + dM2y*t2y;
  vt3 = dM3x*t3x + dM3y*t3y;

  Ff1x = -mu_obs*abs(Fn1)*tanh(vt1/v_small)*t1x;
  Ff1y = -mu_obs*abs(Fn1)*tanh(vt1/v_small)*t1y;
  Ff2x = -mu_obs*abs(Fn2)*tanh(vt2/v_small)*t2x;
  Ff2y = -mu_obs*abs(Fn2)*tanh(vt2/v_small)*t2y;
  Ff3x = -mu_obs*abs(Fn3)*tanh(vt3/v_small)*t3x;
  Ff3y = -mu_obs*abs(Fn3)*tanh(vt3/v_small)*t3y;

  Fc1x = Fn1*n1x + Ff1x;
  Fc1y = Fn1*n1y + Ff1y;
  Fc2x = Fn2*n2x + Ff2x;
  Fc2y = Fn2*n2y + Ff2y;
  Fc3x = Fn3*n3x + Ff3x;
  Fc3y = Fn3*n3y + Ff3y;

  F_contact1 = sqrt(Fc1x^2 + Fc1y^2);
  F_contact2 = sqrt(Fc2x^2 + Fc2y^2);
  F_contact3 = sqrt(Fc3x^2 + Fc3y^2);
  F_contact_total = F_contact1 + F_contact2 + F_contact3;
  contact_scale = min(1.0, F_contact_total/F_ref);
  clearance = min(min(d1,d2), min(d3,d_tip)) - R_obs;

  // Equations of motion (viscoelastic Kelvin-Voigt joints)
  I_sec*der(omega1) = tau_act - k_eff*theta1 - d0*omega1
                      + (Fc1y*(M1x - 0.0) - Fc1x*(M1y - 0.0))
                      + F_tip_dist_y*(x_tip - 0.0);
  I_sec*der(omega2) = tau_act - k_eff*theta2 - d0*omega2
                      + (Fc2y*(M2x - P1x) - Fc2x*(M2y - P1y))
                      + F_tip_dist_y*(x_tip - P1x);
  I_sec*der(omega3) = tau_act - k_eff*theta3 - d0*omega3
                      + (Fc3y*(M3x - P2x) - Fc3x*(M3y - P2y))
                      + F_tip_dist_y*(x_tip - P2x);
  der(theta1) = omega1;
  der(theta2) = omega2;
  der(theta3) = omega3;

  // Slew-limited HV channel
  der(V_act) = max(-dVdt_max, min(dVdt_max, k_slew*(V_cmd - V_act)));

  // Integral error with anti-windup
  der(e_int) = if (e_int > e_int_max and (y_t - y_tip) > 0.0)
               or (e_int < -e_int_max and (y_t - y_tip) < 0.0)
               then 0.0 else (y_t - y_tip);

  // Bounded stiffness scheduling / hold-shape mode
  hold_active = e_primary < e_hold_thresh;
  der(hold_factor) = if hold_active and hold_factor < 1.0 then hold_ramp_rate
                    elseif (not hold_active) and hold_factor > 0.0 then -hold_ramp_rate
                    else 0.0;

  // Tracking error
  e_x = x_t - x_tip;
  e_y = y_t - y_tip;
  e_primary = sqrt(e_x^2 + e_y^2);

  // Contact-aware shape control at 250 Hz
  when sample(0.0, Ts) then
    if hold_active then
      V_cmd = pre(V_cmd);
    else
      V_cmd = max(0.0, min(V_max,
                (Kp_v*(y_t - y_tip) + Ki_v*e_int - Kd_v*(omega1+omega2+omega3))
                * (1.0 - 0.5*contact_scale)));
    end if;
  end when;

  // Fail-closed acceptance checks at 250 Hz
  when sample(0.0, Ts) then
    if (V_act > V_max*1.001)
       or (abs(theta1) > 1.57) or (abs(theta2) > 1.57) or (abs(theta3) > 1.57)
       or (F_contact_total > 40.0)
       or (T_mem > 360.0)
       or (clearance < -0.004)
       or (not (V_act > -1e12 and V_act < 1e12))
       or (not (theta1 > -1e12 and theta1 < 1e12))
       or (not (theta2 > -1e12 and theta2 < 1e12))
       or (not (theta3 > -1e12 and theta3 < 1e12))
       or (not (F_contact_total > -1e12 and F_contact_total < 1e12))
       or (not (T_mem > -1e12 and T_mem < 1e12))
       or (not (e_primary > -1e12 and e_primary < 1e12))
       or (not (V_cmd > -1e12 and V_cmd < 1e12))
       or (time >= 10.4 and e_primary > 0.036) then
      accept_ok = false;
    else
      accept_ok = pre(accept_ok);
    end if;
  end when;

  assert(accept_ok, "ElectroSoftAvoidE: fail-closed acceptance bound violated");

  annotation(
    experiment(StopTime = 16.0, Tolerance = 1e-6, Interval = 0.004),
    Documentation(info = "Soft robotic DEA membrane (0.20 m x 0.05 m x 0.8 mm) reaching a target around a fixed cylinder with bounded incidental contact, contact-aware shape control, bounded stiffness scheduling, and a 9.6 N middle-third lateral tip load. Runs at 250 Hz for 16 s. Parameters not stated in the requirement are marked assumed and must be validated."));
end ElectroSoftAvoidE;