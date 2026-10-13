model FiveBarPressA
  // Geometry and actuator limits from requirement
  parameter Real base_half(unit="m") = 0.25 "base pivot half separation";
  parameter Real L1(unit="m") = 0.30 "actuated link length";
  parameter Real L2(unit="m") = 0.42 "passive link length";
  parameter Real tau_max(unit="N.m") = 27.4 "per-actuator command magnitude limit";

  // Contact model from requirement
  parameter Real k_contact(unit="N/m") = 200000.0;
  parameter Real d_contact(unit="N.s/m") = 2000.0;
  parameter Real mu_contact = 0.70;

  // Scenario timing
  parameter Real T(unit="s") = 0.0125 "80 Hz sample period";
  parameter Real T_end(unit="s") = 8.0;
  parameter Integer N = 641 "samples at 80 Hz over 8 s, including t=0 and t=8";
  parameter Real T_dist_start(unit="s") = 8.0/3.0 "middle third start";
  parameter Real T_dist_end(unit="s") = 16.0/3.0 "middle third end";
  parameter Real disturbance_force(unit="N") = 9.0 "controlled force change during middle third";

  // Values not stated in the requirement; selected only to make the model executable
  parameter Real m(unit="kg") = 20.0 "assumed lumped endpoint mass, not specified";
  parameter Real y_surface(unit="m") = -0.34995 "assumed fixed workpiece plane, not specified";
  parameter Real F_ref_nom(unit="N") = 10.0 "assumed normal force setpoint, not specified";
  parameter Real F_band(unit="N") = 1.0 "assumed contact-force band, not specified";
  parameter Real v_lock(unit="m/s") = 0.001 "assumed locked-contact speed, not specified";
  parameter Real x_ref(unit="m") = 0.0 "assumed tangential position setpoint, not specified";
  parameter Real Kp_x(unit="N/m") = 1000.0;
  parameter Real Kd_x(unit="N.s/m") = 200.0;
  parameter Real Kf = 0.5 "normal force feedback gain";
  parameter Real Kv_y(unit="N.s/m") = 0.0;
  parameter Real v_tanh(unit="m/s") = 0.01 "friction velocity smoothing, not specified";

  // Numerical guards
  parameter Real eps_d = 1.0e-9;
  parameter Real eps_a = 1.0e-6;
  parameter Real eps_det = 1.0e-9;

  // Dynamic states
  Real x(start=0.0, unit="m");
  Real y(start=-0.350, unit="m");
  Real vx(start=0.0, unit="m/s");
  Real vy(start=0.0, unit="m/s");

  // Joint-level variables
  Real theta1(unit="rad");
  Real theta2(unit="rad");
  Real omega1(unit="rad/s");
  Real omega2(unit="rad/s");

  // Contact and force variables
  Real penetration(unit="m");
  Real F_n(unit="N") "normal contact force, positive upward";
  Real F_contact_x(unit="N");
  Real F_contact_y(unit="N");
  Real F_act_x(unit="N");
  Real F_act_y(unit="N");
  Real F_ref_actual(unit="N");

  // Discrete control commands
  discrete Real Fx_cmd(start=0.0, unit="N");
  discrete Real Fy_cmd(start=0.0, unit="N");
  discrete Real tau1_cmd(start=0.0, unit="N.m");
  discrete Real tau2_cmd(start=0.0, unit="N.m");

  // Requirement monitors
  Real closure_error(unit="m");
  Real tangential_slip(unit="m/s");
  Real actuator_bound_margin(unit="N.m");
  Boolean locked_contact;
  Boolean force_in_band;
  Boolean actuator_bounds_ok;
  Boolean closure_requirement_met;

  // Feedback sensors
  Real sensor_x(unit="m") = x;
  Real sensor_y(unit="m") = y;
  Real sensor_theta1(unit="rad") = theta1;
  Real sensor_theta2(unit="rad") = theta2;
  Real sensor_omega1(unit="rad/s") = omega1;
  Real sensor_omega2(unit="rad/s") = omega2;
  Real sensor_tau1(unit="N.m") = tau1_cmd;
  Real sensor_tau2(unit="N.m") = tau2_cmd;
  Real sensor_Fn(unit="N") = F_n;

  // Synchronized 80 Hz traces
  Real trace_t[N](each start=0.0, each unit="s");
  Real trace_x[N](each start=0.0, each unit="m");
  Real trace_y[N](each start=0.0, each unit="m");
  Real trace_vx[N](each start=0.0, each unit="m/s");
  Real trace_vy[N](each start=0.0, each unit="m/s");
  Real trace_theta1[N](each start=0.0, each unit="rad");
  Real trace_theta2[N](each start=0.0, each unit="rad");
  Real trace_Fx_cmd[N](each start=0.0, each unit="N");
  Real trace_Fy_cmd[N](each start=0.0, each unit="N");
  Real trace_tau1_cmd[N](each start=0.0, each unit="N.m");
  Real trace_tau2_cmd[N](each start=0.0, each unit="N.m");
  Real trace_Fn[N](each start=0.0, each unit="N");
  Real trace_closure_error[N](each start=0.0, each unit="m");
  Real trace_force_in_band[N](each start=0.0);
  Real trace_actuator_bounds[N](each start=0.0);
  Real trace_locked_contact[N](each start=0.0);
  Real trace_closure_requirement[N](each start=0.0);
  Integer i(start=0);

  // Kinematic intermediates
  Real rxA, ryA, dA, dA_safe, arg1, arg1c, alpha1;
  Real rxB, ryB, d2, d2_safe, arg2, arg2c, alpha2;
  Real Cx, Cy, Dx, Dy;
  Real r1x, r1y, r2x, r2y, len1, len1_safe, len2, len2_safe;
  Real n1x, n1y, n2x, n2y, t1x, t1y, t2x, t2y;
  Real a1, a2, a1_safe, a2_safe, detM, detM_safe;

protected
  Real lambda1;
  Real lambda2;
  Real tau1_raw;
  Real tau2_raw;

equation
  // Dynamics of the pressed output point
  der(x) = vx;
  der(y) = vy;
  m*der(vx) = F_act_x + F_contact_x;
  m*der(vy) = F_act_y + F_contact_y;

  // Left inverse kinematics under five-bar closure
  rxA = x + base_half;
  ryA = y;
  dA = sqrt(rxA*rxA + ryA*ryA);
  dA_safe = if dA > eps_d then dA else eps_d;
  arg1 = (L1*L1 + dA_safe*dA_safe - L2*L2)/(2.0*L1*dA_safe);
  arg1c = if arg1 > 1.0 then 1.0 elseif arg1 < -1.0 then -1.0 else arg1;
  alpha1 = acos(arg1c);
  theta1 = atan2(ryA, rxA) - alpha1;

  // Right inverse kinematics under five-bar closure
  rxB = x - base_half;
  ryB = y;
  d2 = sqrt(rxB*rxB + ryB*ryB);
  d2_safe = if d2 > eps_d then d2 else eps_d;
  arg2 = (L1*L1 + d2_safe*d2_safe - L2*L2)/(2.0*L1*d2_safe);
  arg2c = if arg2 > 1.0 then 1.0 elseif arg2 < -1.0 then -1.0 else arg2;
  alpha2 = acos(arg2c);
  theta2 = atan2(ryB, rxB) + alpha2;

  // Active link tip positions
  Cx = -base_half + L1*cos(theta1);
  Cy = L1*sin(theta1);
  Dx = base_half + L1*cos(theta2);
  Dy = L1*sin(theta2);

  // Passive link unit vectors and closure error
  r1x = x - Cx;
  r1y = y - Cy;
  r2x = x - Dx;
  r2y = y - Dy;
  len1 = sqrt(r1x*r1x + r1y*r1y);
  len2 = sqrt(r2x*r2x + r2y*r2y);
  len1_safe = if len1 > eps_d then len1 else eps_d;
  len2_safe = if len2 > eps_d then len2 else eps_d;
  n1x = r1x/len1_safe;
  n1y = r1y/len1_safe;
  n2x = r2x/len2_safe;
  n2y = r2y/len2_safe;
  closure_error = sqrt((len1 - L2)*(len1 - L2) + (len2 - L2)*(len2 - L2));

  // Jacobian-related quantities for torque/force mapping
  t1x = -sin(theta1);
  t1y = cos(theta1);
  t2x = -sin(theta2);
  t2y = cos(theta2);
  a1 = L1*(n1x*t1x + n1y*t1y);
  a2 = L1*(n2x*t2x + n2y*t2y);
  a1_safe = if a1 > eps_a then a1 elseif a1 < -eps_a then a1 else (if a1 >= 0.0 then eps_a else -eps_a);
  a2_safe = if a2 > eps_a then a2 elseif a2 < -eps_a then a2 else (if a2 >= 0.0 then eps_a else -eps_a);
  detM = n1x*n2y - n1y*n2x;
  detM_safe = if detM > eps_det then detM elseif detM < -eps_det then detM else (if detM >= 0.0 then eps_det else -eps_det);

  // Endpoint force produced by saturated actuator torques: F = M^T * diag(1/a) * tau
  F_act_x = n1x*tau1_cmd/a1_safe + n2x*tau2_cmd/a2_safe;
  F_act_y = n1y*tau1_cmd/a1_safe + n2y*tau2_cmd/a2_safe;

  // Joint velocity sensors from endpoint velocity
  omega1 = (n1x*vx + n1y*vy)/a1_safe;
  omega2 = (n2x*vx + n2y*vy)/a2_safe;

  // Fixed compliant workpiece contact
  penetration = y_surface - y;
  F_n = if penetration > 0.0 then
          (if k_contact*penetration - d_contact*vy > 0.0 then k_contact*penetration - d_contact*vy else 0.0)
        else 0.0;
  F_contact_y = F_n;
  F_contact_x = -mu_contact*F_n*tanh(vx/v_tanh);

  // Reference with controlled middle-third 9 N force change
  F_ref_actual = F_ref_nom + (if time >= T_dist_start and time <= T_dist_end then disturbance_force else 0.0);

  // Requirement monitors
  tangential_slip = abs(vx);
  locked_contact = F_n > 0.0 and abs(vx) < v_lock;
  force_in_band = F_n >= F_ref_actual - F_band and F_n <= F_ref_actual + F_band;
  actuator_bounds_ok = abs(tau1_cmd) <= tau_max + 1.0e-6 and abs(tau2_cmd) <= tau_max + 1.0e-6;
  actuator_bound_margin = tau_max - (if abs(tau1_cmd) > abs(tau2_cmd) then abs(tau1_cmd) else abs(tau2_cmd));
  closure_requirement_met = if time >= 5.2 then closure_error < 0.001 else true;

algorithm
  when sample(0.0, T) then
    i := if pre(i) < N then pre(i) + 1 else N;

    // Hybrid control: tangential position, normal force
    Fx_cmd := Kp_x*(x_ref - x) - Kd_x*vx;
    Fy_cmd := -F_ref_actual - Kf*(F_ref_actual - F_n) - Kv_y*vy;

    // Torque command from endpoint force command: tau = J^T * F_cmd
    lambda1 := (n2y*Fx_cmd - n2x*Fy_cmd)/detM_safe;
    lambda2 := (-n1y*Fx_cmd + n1x*Fy_cmd)/detM_safe;
    tau1_raw := a1*lambda1;
    tau2_raw := a2*lambda2;

    // Actuator magnitude limit
    tau1_cmd := if tau1_raw > tau_max then tau_max elseif tau1_raw < -tau_max then -tau_max else tau1_raw;
    tau2_cmd := if tau2_raw > tau_max then tau_max elseif tau2_raw < -tau_max then -tau_max else tau2_raw;

    // Synchronized state, command, and sensor traces
    trace_t[i] := time;
    trace_x[i] := x;
    trace_y[i] := y;
    trace_vx[i] := vx;
    trace_vy[i] := vy;
    trace_theta1[i] := theta1;
    trace_theta2[i] := theta2;
    trace_Fx_cmd[i] := Fx_cmd;
    trace_Fy_cmd[i] := Fy_cmd;
    trace_tau1_cmd[i] := tau1_cmd;
    trace_tau2_cmd[i] := tau2_cmd;
    trace_Fn[i] := F_n;
    trace_closure_error[i] := closure_error;
    trace_force_in_band[i] := if force_in_band then 1.0 else 0.0;
    trace_actuator_bounds[i] := if actuator_bounds_ok then 1.0 else 0.0;
    trace_locked_contact[i] := if locked_contact then 1.0 else 0.0;
    trace_closure_requirement[i] := if closure_requirement_met then 1.0 else 0.0;
  end when;

  annotation(experiment(StopTime=8.0, Tolerance=1.0e-6));
end FiveBarPressA;