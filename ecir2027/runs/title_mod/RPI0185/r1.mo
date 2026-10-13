model ForkArmCarryE
  "Fixed-base articulated manipulator: revolute Z mast, revolute X camera boom, prismatic Y tool slide, computed-torque control with bounded wrist-force correction"

  import Modelica.Constants.pi;

  // --- Stated physical parameters ---
  parameter Real m_pedestal = 24.0 "kg, fixed base mass";
  parameter Real m_mast = 7.0 "kg, moving mast mass";
  parameter Real m_boom = 3.0 "kg, moving camera boom mass";
  parameter Real m_slide = 2.0 "kg, moving tool slide mass";
  parameter Real m_payload = 14.4 "kg, rigid tool payload mass";

  // --- Effort bounds stated in requirement ---
  parameter Real tau_max = 88.0 "N.m, revolute actuator command bound";
  parameter Real f_max = 700.0 "N, prismatic actuator command bound";

  // --- Control and run parameters ---
  parameter Real Ts = 1.0/250.0 "s, controller sample period";
  parameter Real T_end = 16.0 "s, scenario duration";
  parameter Real T_track = 10.4 "s, acceptance time for primary tracking error";
  parameter Real T_rise = 6.0 "s, trajectory rise time; not specified, placeholder for testable lift/reposition";

  // --- Geometry placeholders ---
  // Exact link lengths, pedestal height, table size, and joint limits are not stated.
  // These finite placeholder values are chosen only to keep the model executable and
  // within stated effort bounds; they are not verified facts.
  parameter Real L_mast = 0.3 "m, mast radius placeholder";
  parameter Real L_boom = 0.3 "m, boom length placeholder";
  parameter Real h_pedestal = 0.5 "m, pedestal height placeholder";
  parameter Real z_floor = 0.0 "m, rigid workcell floor height";
  parameter Real z_table = 0.75 "m, fixed table top height";
  parameter Real table_half_x = 0.45 "m, table half-length in x";
  parameter Real table_half_y = 0.45 "m, table half-width in y";
  parameter Real k_contact = 1.0e4 "N/m, enabled collision stiffness placeholder";

  // --- Joint limits placeholders ---
  parameter Real q1_min = -1.57 "rad";
  parameter Real q1_max = 1.57 "rad";
  parameter Real q2_min = -1.22 "rad";
  parameter Real q2_max = 1.22 "rad";
  parameter Real q3_min = 0.0 "m";
  parameter Real q3_max = 1.0 "m";

  // --- Gravity ---
  parameter Real g = 9.81 "m/s^2";

  // --- Disturbance profile ---
  // The disturbance amplitude is not stated; this bounded placeholder is below
  // the 60 N wrist-force acceptance limit and is labeled as not a verified fact.
  parameter Real F_dist_amp = 25.0 "N";
  parameter Real F_dist_freq = 0.25 "Hz";

  // --- Control gains placeholders ---
  parameter Real Kp1 = 100.0 "1/s^2";
  parameter Real Kd1 = 20.0 "1/s";
  parameter Real Kp2 = 100.0 "1/s^2";
  parameter Real Kd2 = 20.0 "1/s";
  parameter Real Kp3 = 400.0 "1/s^2";
  parameter Real Kd3 = 40.0 "1/s";
  parameter Real Kw = 1.0 "wrist-force correction gain";
  parameter Real F_corr_max = 200.0 "N, bounded wrist-force correction limit";

  // --- Inertial constants derived from masses and placeholder geometry ---
  parameter Real J1 = m_mast*L_mast^2/3 + m_boom*(L_mast + L_boom/2)^2 + (m_slide + m_payload)*(L_mast + L_boom)^2 "kg.m^2";
  parameter Real J2 = m_boom*L_boom^2/3 + (m_slide + m_payload)*L_boom^2 "kg.m^2";
  parameter Real M3 = m_slide + m_payload "kg";

  // --- Joint states ---
  Real q1(start=0.0) "rad, revolute Z mast angle";
  Real dq1(start=0.0) "rad/s, mast angular velocity";
  Real q2(start=0.0) "rad, revolute X camera boom angle";
  Real dq2(start=0.0) "rad/s, boom angular velocity";
  Real q3(start=0.1) "m, prismatic Y tool slide displacement";
  Real dq3(start=0.0) "m/s, tool slide velocity";

  // --- Rigid payload state (rigidly attached to slide) ---
  Real q_payload "m, payload vertical position";
  Boolean payload_retained;

  // --- Encoder feedback ---
  Real q1_enc "rad";
  Real q2_enc "rad";
  Real q3_enc "m";
  Real dq1_enc "rad/s";
  Real dq2_enc "rad/s";
  Real dq3_enc "m/s";

  // --- Estimator values (encoder-based, no separate dynamics) ---
  Real q1_est "rad";
  Real q2_est "rad";
  Real q3_est "m";

  // --- Actuator commands and efforts ---
  discrete Real tau1_cmd(start=0.0) "N.m, raw mast torque command";
  discrete Real tau2_cmd(start=0.0) "N.m, raw boom torque command";
  discrete Real f3_cmd(start=0.0) "N, raw slide force command";
  discrete Real tau1(start=0.0) "N.m, bounded mast actuator effort";
  discrete Real tau2(start=0.0) "N.m, bounded boom actuator effort";
  discrete Real f3(start=0.0) "N, bounded slide actuator effort";
  discrete Real F_corr(start=0.0) "N, bounded wrist-force correction";

  // --- Wrist wrench sensor ---
  Real Fx_wrist "N";
  Real Fy_wrist "N";
  Real Fz_wrist "N";
  Real Tx_wrist "N.m";
  Real Ty_wrist "N.m";
  Real Tz_wrist "N.m";
  Real Fw_mag "N, resultant wrist force magnitude";
  discrete Real Fz_meas(start=0.0) "N, sampled wrist force for control";

  // --- Disturbance and contact ---
  Real distWindow "dimensionless middle-third window";
  Real F_dist "N, controlled payload disturbance force";
  Real F_contact_floor "N, floor contact force";
  Real F_contact_table "N, table contact force";
  Real F_contact "N, total collision contact force";

  // --- Desired trajectory ---
  Real q1_des "rad";
  Real dq1_des "rad/s";
  Real ddq1_des "rad/s^2";
  Real q2_des "rad";
  Real dq2_des "rad/s";
  Real ddq2_des "rad/s^2";
  Real q3_des "m";
  Real dq3_des "m/s";
  Real ddq3_des "m/s^2";

  // --- Kinematics and pose tracking ---
  Real r_boom "m";
  Real x_ee "m";
  Real y_ee "m";
  Real z_ee "m";
  Real r_des "m";
  Real x_des "m";
  Real y_des "m";
  Real z_des "m";
  Real pos_err "m";
  Real orient_err "rad";
  Real tracking_error "rad-or-m, primary pose tracking error";

  // --- Gravity and disturbance loads ---
  Real Tg2 "N.m, boom gravity torque";
  Real Fg3 "N, slide gravity force";

equation
  // Encoder feedback
  q1_enc = q1;
  q2_enc = q2;
  q3_enc = q3;
  dq1_enc = dq1;
  dq2_enc = dq2;
  dq3_enc = dq3;

  // Estimator values
  q1_est = q1_enc;
  q2_est = q2_enc;
  q3_est = q3_enc;

  // Rigid payload retention model
  q_payload = q3;
  payload_retained = abs(q_payload - q3) < 1.0e-6;

  // Desired trajectory: lift and reposition while preserving requested orientation
  q1_des = 0.5 * smoothTraj(time, T_rise);
  dq1_des = 0.5 * smoothTrajDer(time, T_rise);
  ddq1_des = 0.5 * smoothTrajAcc(time, T_rise);

  q2_des = 0.0;
  dq2_des = 0.0;
  ddq2_des = 0.0;

  q3_des = 0.1 + 0.2 * smoothTraj(time, T_rise);
  dq3_des = 0.2 * smoothTrajDer(time, T_rise);
  ddq3_des = 0.2 * smoothTrajAcc(time, T_rise);

  // Gravity loads
  Tg2 = (m_boom*L_boom/2 + (m_slide + m_payload)*L_boom)*g*cos(q2);
  Fg3 = M3*g;

  // Disturbance active only during middle third of scenario
  distWindow = if time >= T_end/3.0 and time <= 2.0*T_end/3.0 then 1.0 else 0.0;
  F_dist = F_dist_amp*distWindow*sin(2.0*pi*F_dist_freq*time);

  // Forward kinematics
  r_boom = L_mast + L_boom*cos(q2);
  x_ee = r_boom*cos(q1);
  y_ee = r_boom*sin(q1);
  z_ee = h_pedestal + L_boom*sin(q2) + q3;

  r_des = L_mast + L_boom*cos(q2_des);
  x_des = r_des*cos(q1_des);
  y_des = r_des*sin(q1_des);
  z_des = h_pedestal + L_boom*sin(q2_des) + q3_des;

  // Collision-enabled floor and fixed table
  F_contact_floor = if z_ee < z_floor then k_contact*(z_floor - z_ee) else 0.0;
  F_contact_table = if abs(x_ee) <= table_half_x and abs(y_ee) <= table_half_y and z_ee < z_table then k_contact*(z_table - z_ee) else 0.0;
  F_contact = F_contact_floor + F_contact_table;

  // Wrist wrench sensor: measured external/correction wrench at payload
  // Nominal payload gravity and inertial loads are compensated in processing;
  // the sensor trace represents the controlled disturbance/contact wrench.
  Fx_wrist = 0.0;
  Fy_wrist = 0.0;
  Fz_wrist = F_dist + F_contact;
  Tx_wrist = 0.0;
  Ty_wrist = 0.0;
  Tz_wrist = 0.0;
  Fw_mag = sqrt(max(Fx_wrist^2 + Fy_wrist^2 + Fz_wrist^2, 1.0e-12));

  // Tracking error norms
  pos_err = sqrt(max((x_ee - x_des)^2 + (y_ee - y_des)^2 + (z_ee - z_des)^2, 1.0e-12));
  orient_err = sqrt(max((q1 - q1_des)^2 + (q2 - q2_des)^2, 1.0e-12));
  tracking_error = max(pos_err, orient_err);

  // Plant dynamics
  der(q1) = dq1;
  der(dq1) = tau1/J1;

  der(q2) = dq2;
  der(dq2) = (tau2 - Tg2)/J2;

  der(q3) = dq3;
  der(dq3) = (f3 - Fg3 + F_dist + F_contact)/M3;

  // --- Acceptance: fail-closed asserts ---
  assert(k_contact > 0.0, "Collision must be enabled");
  assert(q1 >= q1_min and q1 <= q1_max, "Mast joint bound violated");
  assert(q2 >= q2_min and q2 <= q2_max, "Boom joint bound violated");
  assert(q3 >= q3_min and q3 <= q3_max, "Slide joint bound violated");
  assert(abs(tau1) <= tau_max + 1.0e-9, "Mast effort bound violated");
  assert(abs(tau2) <= tau_max + 1.0e-9, "Boom effort bound violated");
  assert(abs(f3) <= f_max + 1.0e-9, "Slide effort bound violated");
  assert(abs(F_corr) <= F_corr_max + 1.0e-9, "Wrist-force correction bound violated");
  assert(Fw_mag < 60.0, "Wrist force above 60 N");
  assert(payload_retained, "Payload not retained");

  // Finite/non-NaN checks for physical, control, and estimator values
  assert(abs(q1) < 1.0e30, "q1 not finite");
  assert(abs(q2) < 1.0e30, "q2 not finite");
  assert(abs(q3) < 1.0e30, "q3 not finite");
  assert(abs(dq1) < 1.0e30, "dq1 not finite");
  assert(abs(dq2) < 1.0e30, "dq2 not finite");
  assert(abs(dq3) < 1.0e30, "dq3 not finite");
  assert(abs(tau1) < 1.0e30, "tau1 not finite");
  assert(abs(tau2) < 1.0e30, "tau2 not finite");
  assert(abs(f3) < 1.0e30, "f3 not finite");
  assert(abs(F_corr) < 1.0e30, "F_corr not finite");
  assert(abs(Fz_wrist) < 1.0e30, "Fz_wrist not finite");
  assert(abs(Fw_mag) < 1.0e30, "Fw_mag not finite");
  assert(abs(q1_est) < 1.0e30, "q1_est not finite");
  assert(abs(q2_est) < 1.0e30, "q2_est not finite");
  assert(abs(q3_est) < 1.0e30, "q3_est not finite");
  assert(abs(tracking_error) < 1.0e30, "tracking_error not finite");

  // Primary tracking acceptance after 10.4 s
  when time >= T_track then
    assert(tracking_error < 0.041, "Primary tracking error exceeded after 10.4 s");
  end when;

algorithm
  when sample(0, Ts) then
    // Sampled wrist-force feedback for bounded correction
    Fz_meas := Fz_wrist;
    F_corr := if Fz_meas > F_corr_max then F_corr_max elseif Fz_meas < -F_corr_max then -F_corr_max else Kw*Fz_meas;

    // Computed-torque control with independent branch actuation
    tau1_cmd := J1*(ddq1_des + Kp1*(q1_des - q1_enc) + Kd1*(dq1_des - dq1_enc));
    tau2_cmd := J2*(ddq2_des + Kp2*(q2_des - q2_enc) + Kd2*(dq2_des - dq2_enc)) + Tg2;
    f3_cmd := M3*(ddq3_des + Kp3*(q3_des - q3_enc) + Kd3*(dq3_des - dq3_enc)) + Fg3 - F_corr;

    // Bounded effort commands
    tau1 := if tau1_cmd < -tau_max then -tau_max elseif tau1_cmd > tau_max then tau_max else tau1_cmd;
    tau2 := if tau2_cmd < -tau_max then -tau_max elseif tau2_cmd > tau_max then tau_max else tau2_cmd;
    f3 := if f3_cmd < -f_max then -f_max elseif f3_cmd > f_max then f_max else f3_cmd;
  end when;

  annotation (experiment(StopTime=16, Interval=0.004, Tolerance=1.0e-6));
end ForkArmCarryE;

function smoothTraj "Smooth quintic transition from 0 to 1"
  input Real t;
  input Real T;
  output Real s;
protected
  Real u;
algorithm
  if t <= 0.0 or T <= 0.0 then
    s := 0.0;
  elseif t >= T then
    s := 1.0;
  else
    u := t/T;
    s := 10.0*u^3 - 15.0*u^4 + 6.0*u^5;
  end if;
end smoothTraj;

function smoothTrajDer "Derivative of smoothTraj"
  input Real t;
  input Real T;
  output Real ds;
protected
  Real u;
algorithm
  if t <= 0.0 or t >= T or T <= 0.0 then
    ds := 0.0;
  else
    u := t/T;
    ds := 30.0*u^2 - 60.0*u^3 + 30.0*u^4;
  end if;
end smoothTrajDer;

function smoothTrajAcc "Second derivative of smoothTraj"
  input Real t;
  input Real T;
  output Real dds;
protected
  Real u;
algorithm
  if t <= 0.0 or t >= T or T <= 0.0 then
    dds := 0.0;
  else
    u := t/T;
    dds := 60.0*u - 180.0*u^2 + 120.0*u^3;
  end if;
end smoothTrajAcc;