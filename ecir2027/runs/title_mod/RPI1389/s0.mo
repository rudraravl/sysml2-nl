model SoftCrawlAvoidC
  "Contact-aware shape control for a six-chamber compliant body with bounded stiffness scheduling";

  // ----- Required nominal plant configuration -----
  parameter SI.Length L_total = 0.48 "compliant body length";
  parameter Integer N = 6 "serial pneumatic bending chambers";
  parameter SI.Length L_seg = L_total/N "per-chamber length";
  parameter SI.Pressure p_max = 69000.0 "maximum command magnitude, 69 kPa gauge";
  parameter SI.Force F_dist = 7.2 "injected lateral tip load disturbance";
  parameter Real mu_obstacle = 0.55 "fixed cylinder friction coefficient";
  parameter SI.Frequency f_wave = 0.5 "traveling-wave deformation frequency";
  parameter SI.Time t_dist_start = 4.0 "middle third start";
  parameter SI.Time t_dist_end = 8.0 "middle third end";
  parameter SI.Time t_hold = 7.8 "stiffen/hold after target reach";
  parameter SI.Time t_sim = 12.0 "run duration";
  parameter SI.Frequency f_sample = 125.0 "synchronized trace sampling rate";
  parameter SI.Time Ts = 1.0/f_sample "sample period";

  // Target and obstacle: nominal values required to instantiate executable collision behavior.
  // Exact obstacle/target geometry beyond this nominal placement is not specified by the request.
  parameter SI.Length x_target = 0.46 "target tip x";
  parameter SI.Length y_target = -0.07 "target tip y";
  parameter SI.Length x_obstacle = 0.28 "fixed cylinder center x";
  parameter SI.Length y_obstacle = 0.05 "fixed cylinder center y";
  parameter SI.Length r_obstacle = 0.04 "fixed cylinder radius";
  parameter SI.Length contact_margin = 0.002 "collision enabled margin";

  // Nominal actuator and soft-body dynamics values; request did not specify these.
  parameter Real k_p = 2.0e-5 "pressure-to-bending torque gain (N.m/Pa)";
  parameter Real k_q_nom = 0.55 "nominal bending stiffness (N.m/rad)";
  parameter Real k_stiff_range = 1.5 "scheduled stiffness range (N.m/rad)";
  parameter Real c_q_nom = 0.030 "nominal bending damping (N.m.s/rad)";
  parameter Real c_stiff_range = 0.060 "scheduled damping range (N.m.s/rad)";
  parameter Real J_seg = 1.0e-4 "segment inertia (kg.m2)";
  parameter SI.Time tau_p = 0.02 "actuator pressure time constant";
  parameter SI.Time tau_stiff = 0.05 "stiffness scheduling time constant";
  parameter SI.Time tau_T = 0.4 "thermal time constant";
  parameter SI.Temperature T_amb = 293.15 "ambient temperature";
  parameter SI.Temperature T_max = 350.0 "temperature bound";
  parameter Real k_heat = 5.0e-10 "pressure heating coefficient";
  parameter Real k_ctrl_q = 3.5e5 "shape-control proportional gain";
  parameter Real k_ctrl_w = 3.0e3 "shape-control damping gain";
  parameter Real p_wave_amp = 0.08*p_max "bounded traveling-wave amplitude";
  parameter Real q_final = -0.04 "final hold curvature angle per chamber";
  parameter Real q_def_max = 0.35 "deformation bound";
  parameter SI.Force F_contact_max = 30.0 "contact-force bound";
  parameter SI.Length clearance_min = 0.001 "obstacle-clearance bound";
  parameter SI.Length tip_error_bound = 0.042 "primary tracking-error bound";
  parameter Real eps = 1.0e-9 "zero-error guard";

  // Segment states
  Real q1(start=0), q2(start=0), q3(start=0), q4(start=0), q5(start=0), q6(start=0);
  Real w1(start=0), w2(start=0), w3(start=0), w4(start=0), w5(start=0), w6(start=0);
  Real p1(start=0), p2(start=0), p3(start=0), p4(start=0), p5(start=0), p6(start=0);
  Real T1(start=T_amb), T2(start=T_amb), T3(start=T_amb), T4(start=T_amb), T5(start=T_amb), T6(start=T_amb);
  Real stiff1(start=0), stiff2(start=0), stiff3(start=0), stiff4(start=0), stiff5(start=0), stiff6(start=0);

  // Commands and stiffness commands
  Real p_cmd1, p_cmd2, p_cmd3, p_cmd4, p_cmd5, p_cmd6;
  Real stiff_cmd1, stiff_cmd2, stiff_cmd3, stiff_cmd4, stiff_cmd5, stiff_cmd6;
  Real q_des1, q_des2, q_des3, q_des4, q_des5, q_des6;
  Real q_ref;

  // Orientations and node positions
  Real th1, th2, th3, th4, th5, th6;
  Real x1, y1, x2, y2, x3, y3, x4, y4, x5, y5, x6, y6;
  Real xTip, yTip, phiTip;

  // Contact force magnitudes per node
  Real Fc1, Fc2, Fc3, Fc4, Fc5, Fc6;
  Real F_contact_total;
  Real d_clearance;

  // Disturbance
  Real F_dist_y;

  // Traveling-wave pressure component
  Real pw1, pw2, pw3, pw4, pw5, pw6;
  Real wave_scale;

  // Sensors and performance
  Real tipError;
  Real maxAbsPressure;
  Real maxAbsDeformation;
  Real maxTemperature;
  Real finalTipError(start=0);

  // Synchronized traces at 125 Hz for 12 s
  constant Integer n_samples = 1501;
  Integer tick(start=0);
  Real timeLog[n_samples](each start=0);
  Real tipXLog[n_samples](each start=0);
  Real tipYLog[n_samples](each start=0);
  Real tipErrorLog[n_samples](each start=0);
  Real pLog1[n_samples](each start=0);
  Real pLog2[n_samples](each start=0);
  Real pLog3[n_samples](each start=0);
  Real pLog4[n_samples](each start=0);
  Real pLog5[n_samples](each start=0);
  Real pLog6[n_samples](each start=0);
  Real qLog1[n_samples](each start=0);
  Real qLog2[n_samples](each start=0);
  Real qLog3[n_samples](each start=0);
  Real qLog4[n_samples](each start=0);
  Real qLog5[n_samples](each start=0);
  Real qLog6[namples](each start=0);
  Real FcLog1[n_samples](each start=0);
  Real FcLog2[n_samples](each start=0);
  Real FcLog3[n_samples](each start=0);
  Real FcLog4[n_samples](each start=0);
  Real FcLog5[n_samples](each start=0);
  Real FcLog6[n_samples](each start=0);

  function sat "bounded saturation"
    input Real x;
    input Real lo;
    input Real hi;
    output Real y;
  algorithm
    y := if x < lo then lo else if x > hi then hi else x;
  end sat;

  function smoothRamp "smooth transition from 0 to 1"
    input Real t;
    input Real t0;
    input Real dt;
    output Real y;
  algorithm
    y := if t <= t0 then 0.0 elseif t >= t0 + dt then 1.0 else 0.5*(1.0 - cos(Modelica.Constants.pi*(t - t0)/dt));
  end smoothRamp;

  function contactForce "smooth penalty contact magnitude"
    input Real d;
    input Real r;
    input Real margin;
    output Real F;
  algorithm
    F := if d > r + margin then 0.0 else 1.0e6*(r + margin - d);
  end contactForce;

equation
  // Reference shape trajectory to avoid obstacle below it and reach target
  q_ref = q_final * smoothRamp(time, 1.0, 4.0);
  q_des1 = q_ref;
  q_des2 = q_ref;
  q_des3 = q_ref;
  q_des4 = q_ref;
  q_des5 = q_ref;
  q_des6 = q_ref;

  // Disturbance injected during middle third
  F_dist_y = if time >= t_dist_start and time <= t_dist_end then F_dist else 0.0;

  // Traveling-wave pressure component, bounded and decayed after hold
  wave_scale = (1.0 - smoothRamp(time, t_hold, 1.0));
  pw1 = wave_scale * p_wave_amp * sin(2.0*Modelica.Constants.pi*f_wave*time - 0.0*Modelica.Constants.pi/3.0);
  pw2 = wave_scale * p_wave_amp * sin(2.0*Modelica.Constants.pi*f_wave*time - 1.0*Modelica.Constants.pi/3.0);
  pw3 = wave_scale * p_wave_amp * sin(2.0*Modelica.Constants.pi*f_wave*time - 2.0*Modelica.Constants.pi/3.0);
  pw4 = wave_scale * p_wave_amp * sin(2.0*Modelica.Constants.pi*f_wave*time - 3.0*Modelica.Constants.pi/3.0);
  pw5 = wave_scale * p_wave_amp * sin(2.0*Modelica.Constants.pi*f_wave*time - 4.0*Modelica.Constants.pi/3.0);
  pw6 = wave_scale * p_wave_amp * sin(2.0*Modelica.Constants.pi*f_wave*time - 5.0*Modelica.Constants.pi/3.0);

  // Contact-aware stiffness scheduling: bounded incidental contact increases stiffness
  stiff_cmd1 = sat(0.2 + 0.8*smoothRamp(time, t_hold, 1.0) + 2.0*Fc1, 0.0, 1.0);
  stiff_cmd2 = sat(0.2 + 0.8*smoothRamp(time, t_hold, 1.0) + 2.0*Fc2, 0.0, 1.0);
  stiff_cmd3 = sat(0.2 + 0.8*smoothRamp(time, t_hold, 1.0) + 2.0*Fc3, 0.0, 1.0);
  stiff_cmd4 = sat(0.2 + 0.8*smoothRamp(time, t_hold, 1.0) + 2.0*Fc4, 0.0, 1.0);
  stiff_cmd5 = sat(0.2 + 0.8*smoothRamp(time, t_hold, 1.0) + 2.0*Fc5, 0.0, 1.0);
  stiff_cmd6 = sat(0.2 + 0.8*smoothRamp(time, t_hold, 1.0) + 2.0*Fc6, 0.0, 1.0);

  der(stiff1) = (stiff_cmd1 - stiff1)/tau_stiff;
  der(stiff2) = (stiff_cmd2 - stiff2)/tau_stiff;
  der(stiff3) = (stiff_cmd3 - stiff3)/tau_stiff;
  der(stiff4) = (stiff_cmd4 - stiff4)/tau_stiff;
  der(stiff5) = (stiff_cmd5 - stiff5)/tau_stiff;
  der(stiff6) = (stiff_cmd6 - stiff6)/tau_stiff;

  // Bounded actuator commands with maximum magnitude 69 kPa gauge
  p_cmd1 = sat(k_ctrl_q*(q_des1 - q1) - k_ctrl_w*w1 + pw1, -p_max, p_max);
  p_cmd2 = sat(k_ctrl_q*(q_des2 - q2) - k_ctrl_w*w2 + pw2, -p_max, p_max);
  p_cmd3 = sat(k_ctrl_q*(q_des3 - q3) - k_ctrl_w*w3 + pw3, -p_max, p_max);
  p_cmd4 = sat(k_ctrl_q*(q_des4 - q4) - k_ctrl_w*w4 + pw4, -p_max, p_max);
  p_cmd5 = sat(k_ctrl_q*(q_des5 - q5) - k_ctrl_w*w5 + pw5, -p_max, p_max);
  p_cmd6 = sat(k_ctrl_q*(q_des6 - q6) - k_ctrl_w*w6 + pw6, -p_max, p_max);

  // Actuator state dynamics
  der(p1) = (p_cmd1 - p1)/tau_p;
  der(p2) = (p_cmd2 - p2)/tau_p;
  der(p3) = (p_cmd3 - p3)/tau_p;
  der(p4) = (p_cmd4 - p4)/tau_p;
  der(p5) = (p_cmd5 - p5)/tau_p;
  der(p6) = (p_cmd6 - p6)/tau_p;

  // Temperature instrumentation and bound
  der(T1) = (T_amb - T1)/tau_T + k_heat*p1*p1;
  der(T2) = (T_amb - T2)/tau_T + k_heat*p2*p2;
  der(T3) = (T_amb - T3)/tau_T + k_heat*p3*p3;
  der(T4) = (T_amb - T4)/tau_T + k_heat*p4*p4;
  der(T5) = (T_amb - T5)/tau_T + k_heat*p5*p5;
  der(T6) = (T_amb - T6)/tau_T + k_heat*p6*p6;

  // Kinematics
  th1 = q1;
  th2 = q1 + q2;
  th3 = q1 + q2 + q3;
  th4 = q1 + q2 + q3 + q4;
  th5 = q1 + q2 + q3 + q4 + q5;
  th6 = q1 + q2 + q3 + q4 + q5 + q6;

  x1 = L_seg*cos(th1);
  y1 = L_seg*sin(th1);
  x2 = x1 + L_seg*cos(th2);
  y2 = y1 + L_seg*sin(th2);
  x3 = x2 + L_seg*cos(th3);
  y3 = y2 + L_seg*sin(th3);
  x4 = x3 + L_seg*cos(th4);
  y4 = y3 + L_seg*sin(th4);
  x5 = x4 + L_seg*cos(th5);
  y5 = y4 + L_seg*sin(th5);
  x6 = x5 + L_seg*cos(th6);
  y6 = y5 + L_seg*sin(th6);

  xTip = x6;
  yTip = y6;
  phiTip = th6;

  // Distributed contact-force instrumentation with collision enabled
  Fc1 = contactForce(sqrt(max((x1 - x_obstacle)^2 + (y1 - y_obstacle)^2, eps)), r_obstacle, contact_margin);
  Fc2 = contactForce(sqrt(max((x2 - x_obstacle)^2 + (y2 - y_obstacle)^2, eps)), r_obstacle, contact_margin);
  Fc3 = contactForce(sqrt(max((x3 - x_obstacle)^2 + (y3 - y_obstacle)^2, eps)), r_obstacle, contact_margin);
  Fc4 = contactForce(sqrt(max((x4 - x_obstacle)^2 + (y4 - y_obstacle)^2, eps)), r_obstacle, contact_margin);
  Fc5 = contactForce(sqrt(max((x5 - x_obstacle)^2 + (y5 - y_obstacle)^2, eps)), r_obstacle, contact_margin);
  Fc6 = contactForce(sqrt(max((x6 - x_obstacle)^2 + (y6 - y_obstacle)^2, eps)), r_obstacle, contact_margin);

  F_contact_total = Fc1 + Fc2 + Fc3 + Fc4 + Fc5 + Fc6;
  d_clearance = max(r_obstacle + contact_margin - sqrt(min(min(min(min(min(
              (x1 - x_obstacle)^2 + (y1 - y_obstacle)^2,
              (x2 - x_obstacle)^2 + (y2 - y_obstacle)^2),
              (x3 - x_obstacle)^2 + (y3 - y_obstacle)^2),
              (x4 - x_obstacle)^2 + (y4 - y_obstacle)^2),
              (x5 - x_obstacle)^2 + (y5 - y_obstacle)^2),
              (x6 - x_obstacle)^2 + (y6 - y_obstacle)^2)), 0.0);

  // Segment dynamics with anisotropic ground friction and disturbance
  der(q1) = w1;
  der(q2) = w2;
  der(q3) = w3;
  der(q4) = w4;
  der(q5) = w5;
  der(q6) = w6;

  J_seg*der(w1) = k_p*p1 - (k_q_nom + k_stiff_range*stiff1)*q1 - (c_q_nom + c_stiff_range*stiff1)*w1
                  - 0.015*w1*(1.0 + 0.8*cos(2.0*th1)) + Fc1*L_seg*cos(th1) + F_dist_y*L_seg*cos(th1);
  J_seg*der(w2) = k_p*p2 - (k_q_nom + k_stiff_range*stiff2)*q2 - (c_q_nom + c_stiff_range*stiff2)*w2
                  - 0.015*w2*(1.0 + 0.8*cos(2.0*th2)) + Fc2*L_seg*cos(th2);
  J_seg*der(w3) = k_p*p3 - (k_q_nom + k_stiff_range*stiff3)*q3 - (c_q_nom + c_stiff_range*stiff3)*w3
                  - 0.015*w3*(1.0 + 0.8*cos(2.0*th3)) + Fc3*L_seg*cos(th3);
  J_seg*der(w4) = k_p*p4 - (k_q_nom + k_stiff_range*stiff4)*q4 - (c_q_nom + c_stiff_range*stiff4)*w4
                  - 0.015*w4*(1.0 + 0.8*cos(2.0*th4)) + Fc4*L_seg*cos(th4);
  J_seg*der(w5) = k_p*p5 - (k_q_nom + k_stiff_range*stiff5)*q5 - (c_q_nom + c_stiff_range*stiff5)*w5
                  - 0.015*w5*(1.0 + 0.8*cos(2.0*th5)) + Fc5*L_seg*cos(th5);
  J_seg*der(w6) = k_p*p6 - (k_q_nom + k_stiff_range*stiff6)*q6 - (c_q_nom + c_stiff_range*stiff6)*w6
                  - 0.015*w6*(1.0 + 0.8*cos(2.0*th6)) + Fc6*L_seg*cos(th6);

  // Primary tracking error
  tipError = sqrt(max((xTip - x_target)^2 + (yTip - y_target)^2, eps));

  // Bounds and diagnostics
  maxAbsPressure = max(max(max(max(max(abs(p1), abs(p2)), abs(p3)), abs(p4)), abs(p5)), abs(p6));
  maxAbsDeformation = max(max(max(max(max(abs(q1), abs(q2)), abs(q3)), abs(q4)), abs(q5)), abs(q6));
  maxTemperature = max(max(max(max(max(T1, T2), T3), T4), T5), T6);

  // Final tip-error trace and bound verification after hold
  der(finalTipError) = 0.0;
  when time >= t_hold then
    finalTipError = tipError;
  end when;

  assert(maxAbsPressure <= p_max + 1.0, "actuator pressure bound violated");
  assert(maxAbsDeformation <= q_def_max, "deformation bound violated");
  assert(F_contact_total <= F_contact_max, "contact-force bound violated");
  assert(maxTemperature <= T_max, "temperature bound violated");
  assert(d_clearance >= clearance_min, "obstacle-clearance bound violated");
  assert(time < t_hold or tipError <= tip_error_bound, "primary tracking error bound violated");
  assert(not Modelica.Math.isNaN(xTip) and not Modelica.Math.isNaN(yTip), "NaN physical value detected");
  assert(not Modelica.Math.isNaN(p_cmd1), "NaN control value detected");
  assert(not Modelica.Math.isNaN(tipError), "NaN estimator/performance value detected");

  // Synchronized state, command, and sensor traces at 125 Hz
  when sample(0, Ts) then
    tick = pre(tick) + 1;
    if tick <= n_samples then
      timeLog[tick] = time;
      tipXLog[tick] = xTip;
      tipYLog[tick] = yTip;
      tipErrorLog[tick] = tipError;
      pLog1[tick] = p1;
      pLog2[tick] = p2;
      pLog3[tick] = p3;
      pLog4[tick] = p4;
      pLog5[tick] = p5;
      pLog6[tick] = p6;
      qLog1[tick] = q1;
      qLog2[tick] = q2;
      qLog3[tick] = q3;
      qLog4[tick] = q4;
      qLog5[tick] = q5;
      qLog6[tick] = q6;
      FcLog1[tick] = Fc1;
      FcLog2[tick] = Fc2;
      FcLog3[tick] = Fc3;
      FcLog4[tick] = Fc4;
      FcLog5[tick] = Fc5;
      FcLog6[tick] = Fc6;
    end if;
  end when;

  annotation(
    experiment(StopTime=12.0, Tolerance=1.0e-6, Interval=0.008),
    Documentation(info="SoftCrawlAvoidC: six serial pneumatic bending chambers, anisotropic ground friction, fixed cylinder collision with mu=0.55, 69 kPa-gauge command bound, 7.2 N middle-third tip disturbance, 125 Hz synchronized traces for 12 s."));
end SoftCrawlAvoidC;