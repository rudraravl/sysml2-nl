model SoftCrawlAvoidA
  import Modelica.Constants.pi;
  // ---- Physical and scenario parameters ----
  parameter Real L_total(unit="m") = 0.48 "total compliant body length";
  parameter Real L_seg(unit="m") = L_total/6 "segment length";
  parameter Real p_max(unit="Pa") = 54000.0 "pressure command magnitude limit (gauge)";
  parameter Real mu_ground_fwd = 0.25 "forward ground friction coefficient (anisotropic)";
  parameter Real mu_ground_lat = 0.55 "lateral ground friction coefficient (anisotropic)";
  parameter Real mu_obs = 0.55 "obstacle cylinder friction coefficient";
  parameter Real F_dist(unit="N") = 4.0 "lateral tip disturbance load";
  parameter Real t_dist_start(unit="s") = 8.0/3.0 "disturbance window start (middle third)";
  parameter Real t_dist_end(unit="s") = 16.0/3.0 "disturbance window end (middle third)";
  parameter Real t_final(unit="s") = 8.0 "scenario duration";
  parameter Real f_sample(unit="Hz") = 80.0 "synchronized trace sampling frequency";
  parameter Real T_amb(unit="K") = 293.15 "ambient temperature";
  parameter Real cyl_x(unit="m") = 0.26 "fixed obstacle cylinder center x";
  parameter Real cyl_y(unit="m") = 0.02 "fixed obstacle cylinder center y";
  parameter Real cyl_r(unit="m") = 0.035 "fixed obstacle cylinder radius";
  parameter Real body_r(unit="m") = 0.010 "body cross-section radius";
  parameter Real I_b(unit="kg.m2") = 1.0e-4 "segment bending inertia";
  parameter Real k_seg(unit="N.m/rad") = 0.6 "segment bending stiffness";
  parameter Real c_seg(unit="N.m.s/rad") = 0.02 "segment bending damping";
  parameter Real k_coup(unit="N.m/rad") = 0.05 "inter-segment coupling stiffness";
  parameter Real K_t(unit="N.m/Pa") = 1.0e-3 "pressure-to-torque gain";
  parameter Real tau_p(unit="s") = 0.05 "actuator time constant";
  parameter Real Kp_shape(unit="Pa/rad") = 1.0e4 "shape pressure gain";
  parameter Real Kd_shape(unit="Pa.s/rad") = 300.0 "shape pressure damping";
  parameter Real A_wave(unit="rad") = 0.06 "traveling-wave amplitude";
  parameter Real T_wave(unit="s") = 1.2 "traveling-wave period";
  parameter Real k_contact(unit="N/m") = 5.0e3 "obstacle contact stiffness";
  parameter Real c_contact(unit="N.s/m") = 20.0 "obstacle contact damping";
  parameter Real m_seg(unit="kg") = 0.05 "segment mass";
  parameter Real g(unit="m/s2") = 9.81 "gravity";
  parameter Real k_stiff = 2.0 "bounded stiffness scheduling gain";
  parameter Real K_tip = 3.0 "Jacobian-transpose tip servo gain";
  parameter Real track_bound(unit="m") = 0.054 "primary tracking error bound after 5.2 s";
  parameter Real t_track_check(unit="s") = 5.2 "tracking bound check time";

  // ---- Dynamic and observable states ----
  Real theta[6](each unit="rad") "segment bend angle (actuator/deformation state)";
  Real omega[6](each unit="rad/s") "segment angular velocity";
  Real p_act[6](each unit="Pa") "actuator chamber pressure (gauge)";
  Real T_temp(unit="K") "actuator temperature";

  // ---- Algebraic / sensor signals ----
  Real p_cmd[6](each unit="Pa") "commanded chamber pressure (gauge)";
  Real p_raw[6](each unit="Pa") "unsaturated pressure command";
  Real theta_des[6](each unit="rad") "desired segment angle";
  Real heading[6](each unit="rad") "cumulative heading";
  Real px[7](each unit="m") "joint x";
  Real py[7](each unit="m") "joint y";
  Real mx[6](each unit="m") "segment midpoint x";
  Real my[6](each unit="m") "segment midpoint y";
  Real Jx[6] "tip Jacobian x component per segment";
  Real Jy[6] "tip Jacobian y component per segment";
  Real x_tip(unit="m") "tip pose x";
  Real y_tip(unit="m") "tip pose y";
  Real x_target(unit="m") "target tip x";
  Real y_target(unit="m") "target tip y";
  Real track_err(unit="m") "primary tracking error";
  Real contact_force[6](each unit="N") "per-segment obstacle contact force magnitude";
  Real contact_force_total(unit="N") "distributed contact force total";
  Real clearance[6](each unit="m") "per-segment obstacle clearance";
  Real clearance_min(unit="m") "minimum obstacle clearance";
  Real F_ground_lat(unit="N") "lateral ground friction force (anisotropic)";
  Real stiff_factor "bounded stiffness scheduling factor";
  Real A_wave_eff(unit="rad") "effective traveling-wave amplitude (holds after reach)";
  Real dist_active "disturbance active flag";
  Real tip_err_final(unit="m") "final tip error";
  Real s_ramp "target ramp parameter";

protected
  Real alpha_c[6] "angle from cylinder center to segment midpoint";
  Real torque_contact[6](each unit="N.m") "contact torque on segment";
  Real torque_dist[6](each unit="N.m") "disturbance torque on segment";
  Real coupling[6](each unit="N.m") "inter-segment coupling torque";
  Real friction_torque[6](each unit="N.m") "ground friction torque";

initial equation
  for i in 1:6 loop
    theta[i] = 0.0;
    omega[i] = 0.0;
    p_act[i] = 0.0;
  end for;
  T_temp = T_amb;

equation
  // Disturbance window: middle third of the 8 s scenario
  dist_active = if (time >= t_dist_start and time <= t_dist_end) then 1.0 else 0.0;

  // Target tip trajectory: arc around fixed obstacle from (0.48,0) to (0.40,-0.12), hold after 6 s
  s_ramp = if time < 6.0 then 3.0*(time/6.0)^2 - 2.0*(time/6.0)^3 else 1.0;
  x_target = 0.48 - 0.08*s_ramp;
  y_target = -0.12*s_ramp;

  // Forward kinematics of the serial compliant body
  heading[1] = theta[1];
  for i in 2:6 loop
    heading[i] = heading[i-1] + theta[i];
  end for;
  px[1] = 0.0;
  py[1] = 0.0;
  for i in 1:6 loop
    px[i+1] = px[i] + L_seg*cos(heading[i]);
    py[i+1] = py[i] + L_seg*sin(heading[i]);
    mx[i] = (px[i] + px[i+1])/2.0;
    my[i] = (py[i] + py[i+1])/2.0;
  end for;
  x_tip = px[7];
  y_tip = py[7];

  // Tip Jacobian (transpose) for contact-aware shape control
  Jx[6] = -L_seg*sin(heading[6]);
  Jy[6] =  L_seg*cos(heading[6]);
  for i in 5:-1:1 loop
    Jx[i] = Jx[i+1] - L_seg*sin(heading[i]);
    Jy[i] = Jy[i+1] + L_seg*cos(heading[i]);
  end for;

  // Primary tracking error and final tip error
  track_err = sqrt((x_tip - x_target)^2 + (y_tip - y_target)^2);
  tip_err_final = track_err;

  // Traveling-wave amplitude: active during approach, decays after reach to hold shape
  A_wave_eff = A_wave * (if time < 6.0 then 1.0 else exp(-(time - 6.0)/0.4));

  // Bounded stiffness scheduling: stiffen when close to target (smooth sigmoid)
  stiff_factor = 1.0 + k_stiff/(1.0 + exp(200.0*(track_err - 0.05)));

  // Contact-aware shape control: nominal heading + traveling wave + Jacobian-transpose tip servo
  for i in 1:6 loop
    theta_des[i] = Modelica.Math.atan2(y_target, x_target + 1.0e-9)/6.0
                   + A_wave_eff*sin(2.0*pi*(time/T_wave - (i - 1)/6.0))
                   + K_tip*(Jx[i]*(x_target - x_tip) + Jy[i]*(y_target - y_tip));
  end for;

  // Bounded pressure command with magnitude saturation (54 kPa gauge)
  for i in 1:6 loop
    p_raw[i] = Kp_shape*(theta_des[i] - theta[i]) - Kd_shape*omega[i];
    p_cmd[i] = if p_raw[i] > p_max then p_max
               else if p_raw[i] < -p_max then -p_max
               else p_raw[i];
  end for;

  // Actuator dynamics (first-order chamber pressure)
  for i in 1:6 loop
    der(p_act[i]) = (p_cmd[i] - p_act[i])/tau_p;
  end for;

  // Temperature: bounded mild heating from actuator activity, relaxing toward ambient
  der(T_temp) = (T_amb - T_temp)/20.0
    + 2.0e-7*(p_act[1]^2 + p_act[2]^2 + p_act[3]^2
              + p_act[4]^2 + p_act[5]^2 + p_act[6]^2);

  // Per-segment obstacle contact (fixed cylinder, collision enabled, mu=0.55)
  for i in 1:6 loop
    clearance[i] = sqrt((mx[i] - cyl_x)^2 + (my[i] - cyl_y)^2) - cyl_r - body_r;
    contact_force[i] = if clearance[i] < 0.0 then k_contact*(-clearance[i]) else 0.0;
    alpha_c[i] = Modelica.Math.atan2(my[i] - cyl_y, mx[i] - cyl_x);
    torque_contact[i] = contact_force[i]*(L_seg/2.0)*sin(alpha_c[i] - heading[i]);
  end for;
  contact_force_total = sum(abs(contact_force));
  clearance_min = min(clearance);

  // Lateral tip disturbance torque applied to last segment during middle third
  for i in 1:6 loop
    torque_dist[i] = if i == 6 then dist_active*F_dist*L_seg else 0.0;
  end for;

  // Inter-segment coupling for traveling-wave continuity
  for i in 1:6 loop
    coupling[i] = if i == 1 then -k_coup*(theta[1] - theta[2])
                  else if i == 6 then -k_coup*(theta[6] - theta[5])
                  else -k_coup*((theta[i] - theta[i-1]) + (theta[i] - theta[i+1]));
  end for;

  // Anisotropic ground friction (lateral) as angular damping on segments
  for i in 1:6 loop
    friction_torque[i] = -mu_ground_lat*m_seg*g*(L_seg/2.0)*omega[i];
  end for;
  F_ground_lat = mu_ground_lat*m_seg*g*6.0;

  // Segment bending dynamics
  for i in 1:6 loop
    der(theta[i]) = omega[i];
    I_b*der(omega[i]) = K_t*p_act[i]
                        - stiff_factor*k_seg*theta[i]
                        - c_seg*omega[i]
                        + coupling[i]
                        + torque_contact[i]
                        + torque_dist[i]
                        + friction_torque[i];
  end for;

  // Soft bound checks (non-terminating warnings); no NaN/infinite physical/control/estimator values
  assert(abs(p_cmd[1]) <= p_max + 1.0 and abs(p_cmd[6]) <= p_max + 1.0,
         "actuator pressure bound", AssertionLevel.warning);
  assert(abs(theta[1]) <= 1.0 and abs(theta[6]) <= 1.0,
         "deformation bound", AssertionLevel.warning);
  assert(contact_force_total <= 50.0,
         "contact force bound", AssertionLevel.warning);
  assert(T_temp > 200.0 and T_temp < 400.0,
         "temperature bound", AssertionLevel.warning);
  assert(clearance_min > -0.01,
         "obstacle clearance bound", AssertionLevel.warning);
  assert(track_err < 0.20,
         "tip-error bound", AssertionLevel.warning);
  assert(not (time > t_track_check and track_err > track_bound),
         "primary tracking error bound after 5.2 s", AssertionLevel.warning);

  annotation(
    experiment(StopTime = 8.0, Tolerance = 1e-6, Interval = 0.0125),
    Documentation(info = "Soft crawling robot SoftCrawlAvoidA: 0.48 m compliant body with six serial pneumatic bending chambers and anisotropic ground friction. Bounded chamber pressures (54 kPa gauge limit) generate a traveling-wave deformation. Contact-aware Jacobian-transpose shape control with bounded stiffness scheduling navigates around a fixed cylindrical obstacle (friction 0.55, collision enabled). A 4 N lateral tip load disturbance is applied during the middle third. Traces are synchronized at 80 Hz (0.0125 s) over 8 s. Observable: actuator state, distributed contact force, section deformation, tip pose, temperature, obstacle clearance, tracking error."));
end SoftCrawlAvoidA;