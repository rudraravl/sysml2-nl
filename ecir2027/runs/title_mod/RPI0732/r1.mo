model QuadPawTraverseF
  "Robotics scenario for floating-base legged robot crossing a height field"

  // Parameters
  parameter Real m_torso = 22.0 "Torso mass [kg]";
  parameter Real L_thigh = 0.32 "Thigh length [m]";
  parameter Real L_shank = 0.30 "Shank length [m]";
  parameter Real tau_max = 58.6 "Max joint torque per actuator [N.m]";
  parameter Real mu = 0.78 "Contact friction coefficient";
  parameter Real v_cmd = 0.5 "Commanded average speed [m/s]";
  parameter Real f_push = 130.0 "Lateral push disturbance [N]";
  parameter Real g = 9.81 "Gravity [m/s^2]";
  parameter Real Ixx = 1.0 "Inertia X [kg.m^2]";
  parameter Real Iyy = 1.0 "Inertia Y [kg.m^2]";
  parameter Real Izz = 1.0 "Inertia Z [kg.m^2]";

  // Torso states
  Real x_pos(start=0.0, fixed=true);
  Real y_pos(start=0.0, fixed=true);
  Real z_pos(start=0.5, fixed=true);
  Real vx(start=0.5, fixed=true);
  Real vy(start=0.0, fixed=true);
  Real vz(start=0.0, fixed=true);
  Real roll(start=0.0, fixed=true);
  Real pitch(start=0.0, fixed=true);
  Real yaw(start=0.0, fixed=true);
  Real wx(start=0.0, fixed=true);
  Real wy(start=0.0, fixed=true);
  Real wz(start=0.0, fixed=true);

  // Leg 1 (Front Left)
  Real q1(start=0.0, fixed=true), qd1(start=0.0, fixed=true), tau1, tau_sat1, q_des1;
  // Leg 2 (Front Right)
  Real q2(start=0.0, fixed=true), qd2(start=0.0, fixed=true), tau2, tau_sat2, q_des2;
  Real q3(start=0.0, fixed=true), qd3(start=0.0, fixed=true), tau3, tau_sat3, q_des3;
  // Leg 3 (Hind Left)
  Real q4(start=0.0, fixed=true), qd4(start=0.0, fixed=true), tau4, tau_sat4, q_des4;
  Real q5(start=0.0, fixed=true), qd5(start=0.0, fixed=true), tau5, tau_sat5, q_des5;
  Real q6(start=0.0, fixed=true), qd6(start=0.0, fixed=true), tau6, tau_sat6, q_des6;
  // Leg 4 (Hind Right)
  Real q7(start=0.0, fixed=true), qd7(start=0.0, fixed=true), tau7, tau_sat7, q_des7;
  Real q8(start=0.0, fixed=true), qd8(start=0.0, fixed=true), tau8, tau_sat8, q_des8;
  Real q9(start=0.0, fixed=true), qd9(start=0.0, fixed=true), tau9, tau_sat9, q_des9;
  Real q10(start=0.0, fixed=true), qd10(start=0.0, fixed=true), tau10, tau_sat10, q_des10;
  Real q11(start=0.0, fixed=true), qd11(start=0.0, fixed=true), tau11, tau_sat11, q_des11;
  Real q12(start=0.0, fixed=true), qd12(start=0.0, fixed=true), tau12, tau_sat12, q_des12;

  // Environment and observations
  Real F_push_y;
  Real z_terrain_val;
  Real clearance;
  Real path_err;

  // Forces and moments
  Real Fx, Fy, Fz, Mroll, Mpitch, Myaw;
  Real sum_tau_front, sum_tau_hind, sum_tau_all;
  Real Fy_unsat;

  function terrainHeight
    "Smooth height field with 0.08m rocks and 0.12m gaps"
    input Real x;
    output Real z;
  protected
    Real rock1, rock2, gap1, gap2;
  algorithm
    rock1 := 0.08 * 0.5 * (1 + Modelica.Math.tanh(50*(x-3))) * 0.5 * (1 - Modelica.Math.tanh(50*(x-3.5)));
    gap1 := -0.12 * 0.5 * (1 + Modelica.Math.tanh(50*(x-6))) * 0.5 * (1 - Modelica.Math.tanh(50*(x-6.12)));
    rock2 := 0.08 * 0.5 * (1 + Modelica.Math.tanh(50*(x-9))) * 0.5 * (1 - Modelica.Math.tanh(50*(x-9.5)));
    gap2 := -0.12 * 0.5 * (1 + Modelica.Math.tanh(50*(x-12))) * 0.5 * (1 - Modelica.Math.tanh(50*(x-12.12)));
    z := rock1 + gap1 + rock2 + gap2;
  end terrainHeight;

equation
  // Disturbance: 130 N lateral push during middle third (6.66s to 13.33s)
  F_push_y = if time >= 20.0/3.0 and time <= 40.0/3.0 then 130.0 else 0.0;

  // Terrain and clearances
  z_terrain_val = terrainHeight(x_pos);
  clearance = z_pos - z_terrain_val;
  path_err = x_pos - v_cmd * time;

  // Foothold planning and swing-foot trajectory control
  // Trotting gait with corrective bias for path and height tracking
  q_des1 = 0.1 * Modelica.Math.sin(2 * Modelica.Constants.pi * 2.0 * time) - 2.0 * path_err;
  q_des2 = 0.1 * Modelica.Math.sin(2 * Modelica.Constants.pi * 2.0 * time);
  q_des3 = 0.2 * Modelica.Math.sin(2 * Modelica.Constants.pi * 2.0 * time) + 1.0 * (0.5 - z_pos);
  
  q_des4 = 0.1 * Modelica.Math.sin(2 * Modelica.Constants.pi * 2.0 * time + Modelica.Constants.pi);
  q_des5 = 0.1 * Modelica.Math.sin(2 * Modelica.Constants.pi * 2.0 * time + Modelica.Constants.pi);
  q_des6 = 0.2 * Modelica.Math.sin(2 * Modelica.Constants.pi * 2.0 * time + Modelica.Constants.pi) + 1.0 * (0.5 - z_pos);
  
  q_des7 = 0.1 * Modelica.Math.sin(2 * Modelica.Constants.pi * 2.0 * time + Modelica.Constants.pi);
  q_des8 = 0.1 * Modelica.Math.sin(2 * Modelica.Constants.pi * 2.0 * time + Modelica.Constants.pi);
  q_des9 = 0.2 * Modelica.Math.sin(2 * Modelica.Constants.pi * 2.0 * time + Modelica.Constants.pi) + 1.0 * (0.5 - z_pos);
  
  q_des10 = 0.1 * Modelica.Math.sin(2 * Modelica.Constants.pi * 2.0 * time) + 2.0 * path_err;
  q_des11 = 0.1 * Modelica.Math.sin(2 * Modelica.Constants.pi * 2.0 * time);
  q_des12 = 0.2 * Modelica.Math.sin(2 * Modelica.Constants.pi * 2.0 * time) + 1.0 * (0.5 - z_pos);

  // Joint dynamics and torque bounds (58.6 N.m)
  tau1 = 50.0 * (q_des1 - q1) - 5.0 * qd1;
  tau_sat1 = max(-tau_max, min(tau_max, tau1));
  der(q1) = qd1;
  der(qd1) = tau_sat1 / 0.1;

  tau2 = 50.0 * (q_des2 - q2) - 5.0 * qd2;
  tau_sat2 = max(-tau_max, min(tau_max, tau2));
  der(q2) = qd2;
  der(qd2) = tau_sat2 / 0.1;

  tau3 = 50.0 * (q_des3 - q3) - 5.0 * qd3;
  tau_sat3 = max(-tau_max, min(tau_max, tau3));
  der(q3) = qd3;
  der(qd3) = tau_sat3 / 0.1;

  tau4 = 50.0 * (q_des4 - q4) - 5.0 * qd4;
  tau_sat4 = max(-tau_max, min(tau_max, tau4));
  der(q4) = qd4;
  der(qd4) = tau_sat4 / 0.1;

  tau5 = 50.0 * (q_des5 - q5) - 5.0 * qd5;
  tau_sat5 = max(-tau_max, min(tau_max, tau5));
  der(q5) = qd5;
  der(qd5) = tau_sat5 / 0.1;

  tau6 = 50.0 * (q_des6 - q6) - 5.0 * qd6;
  tau_sat6 = max(-tau_max, min(tau_max, tau6));
  der(q6) = qd6;
  der(qd6) = tau_sat6 / 0.1;

  tau7 = 50.0 * (q_des7 - q7) - 5.0 * qd7;
  tau_sat7 = max(-tau_max, min(tau_max, tau7));
  der(q7) = qd7;
  der(qd7) = tau_sat7 / 0.1;

  tau8 = 50.0 * (q_des8 - q8) - 5.0 * qd8;
  tau_sat8 = max(-tau_max, min(tau_max, tau8));
  der(q8) = qd8;
  der(qd8) = tau_sat8 / 0.1;

  tau9 = 50.0 * (q_des9 - q9) - 5.0 * qd9;
  tau_sat9 = max(-tau_max, min(tau_max, tau9));
  der(q9) = qd9;
  der(qd9) = tau_sat9 / 0.1;

  tau10 = 50.0 * (q_des10 - q10) - 5.0 * qd10;
  tau_sat10 = max(-tau_max, min(tau_max, tau10));
  der(q10) = qd10;
  der(qd10) = tau_sat10 / 0.1;

  tau11 = 50.0 * (q_des11 - q11) - 5.0 * qd11;
  tau_sat11 = max(-tau_max, min(tau_max, tau11));
  der(q11) = qd11;
  der(qd11) = tau_sat11 / 0.1;

  tau12 = 50.0 * (q_des12 - q12) - 5.0 * qd12;
  tau_sat12 = max(-tau_max, min(tau_max, tau12));
  der(q12) = qd12;
  der(qd12) = tau_sat12 / 0.1;

  // Force mapping from joint torques to torso wrench
  sum_tau_front = tau_sat1 + tau_sat2 + tau_sat3 + tau_sat4 + tau_sat5 + tau_sat6;
  sum_tau_hind = tau_sat7 + tau_sat8 + tau_sat9 + tau_sat10 + tau_sat11 + tau_sat12;
  sum_tau_all = sum_tau_front + sum_tau_hind;

  Fx = (sum_tau_front - sum_tau_hind) * 1.0;
  Fy_unsat = 500.0 * (0.0 - y_pos) - 100.0 * vy;
  Fz = sum_tau_all * 2.0 + m_torso * g;
  
  // Friction constraint |Fy| <= mu * |Fz|
  Fy = max(-mu * abs(Fz), min(mu * abs(Fz), Fy_unsat));
  
  // Attitude stabilization
  Mroll = 500.0 * (0.0 - roll) - 50.0 * wx;
  Mpitch = 500.0 * (0.0 - pitch) - 50.0 * wy;
  Myaw = 500.0 * (0.0 - yaw) - 50.0 * wz;

  // Torso dynamics
  der(x_pos) = vx;
  der(y_pos) = vy;
  der(z_pos) = vz;
  der(vx) = Fx / m_torso;
  der(vy) = (Fy + F_push_y) / m_torso;
  der(vz) = Fz / m_torso - g;

  der(roll) = wx;
  der(pitch) = wy;
  der(yaw) = wz;
  der(wx) = Mroll / Ixx;
  der(wy) = Mpitch / Iyy;
  der(wz) = Myaw / Izz;

end QuadPawTraverseF;