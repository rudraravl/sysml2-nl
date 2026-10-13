model VacuumToolInsertA
  // Mass and physical parameters
  parameter Real M_peg = 0.8 "Mass of peg and suction cup";
  parameter Real r_cup = 0.038 "Suction cup radius";
  parameter Real A_cup = Modelica.Constants.pi * r_cup^2;
  parameter Real Clearance = 0.001 "1 mm radial clearance";
  parameter Real mu = 0.35 "Contact friction";
  parameter Real K_wall = 100000.0 "Wall stiffness";
  parameter Real C_wall = 100.0 "Wall damping";
  parameter Real g = 9.81 "Gravity";
  
  // Control parameters
  parameter Real F_max = 230.0 "Linear actuator command limit";
  parameter Real P_min = -70000.0 "Vacuum pressure min";
  parameter Real K_p = 2000.0 "Impedance stiffness";
  parameter Real K_d = 50.0 "Impedance damping";
  
  // States
  Real x "Peg lateral position";
  Real vx "Peg lateral velocity";
  Real y "Peg vertical position";
  Real vy "Peg vertical velocity";
  
  // Control and sensor variables
  Real F_cmd_x "Lateral force command";
  Real F_cmd_y "Vertical force command";
  Real P_vac "Vacuum pressure command";
  Real F_grip "Gripping force from vacuum";
  Real F_dist "Lateral disturbance force";
  Real F_cx "Contact force x on peg";
  Real F_cy "Contact force y on peg";
  Real wrench_x "Measured wrench x";
  Real wrench_y "Measured wrench y";
  Real y_ref "Vertical reference";
  Real x_ref "Lateral reference";
  Real track_err "Tracking error";
  Real tilt "Peg tilt angle";
  
  // Intermediate variables
  Real sign_x "Sign of x";
  Real N_lip "Lip normal force";
  Real N_wall "Wall normal force";
  Real pen_lip "Penetration into lip";
  Real v_pen_lip "Penetration velocity into lip";
  Real pen_wall "Penetration into wall";
  Real v_pen_wall "Penetration velocity into wall";

equation
  // Suction pressure schedule
  P_vac = if time > 0.5 then P_min else 0.0;
  F_grip = -P_vac * A_cup;

  // Disturbance (middle third of 8s -> 2.666 to 5.333)
  F_dist = if time > 8.0/3.0 and time < 16.0/3.0 then 5.0 else 0.0;

  // References
  x_ref = 0.0;
  y_ref = min(0.06, -0.01 + 0.05 * time);

  // Smooth sign function
  sign_x = if x > 1e-6 then 1.0 else if x < -1e-6 then -1.0 else x/1e-6;

  // Contact forces
  pen_lip = abs(x) - (Clearance - y);
  v_pen_lip = sign_x * vx + vy;
  N_lip = if (y > -0.002 and y < 0.0 and pen_lip > 0) then max(0, K_wall * pen_lip + C_wall * v_pen_lip) else 0.0;
  
  pen_wall = abs(x) - Clearance;
  v_pen_wall = sign_x * vx;
  N_wall = if (y >= 0.0 and pen_wall > 0) then max(0, K_wall * pen_wall + C_wall * v_pen_wall) else 0.0;

  F_cx = -N_lip * 0.707 * sign_x - mu * N_lip * 0.707 * tanh(vx / 0.001) - N_wall * sign_x;
  F_cy = -N_lip * 0.707 - mu * N_lip * 0.707 * tanh(vy / 0.001) - mu * N_wall * tanh(vy / 0.001);

  // Wrench sensor (forces on tool)
  wrench_x = -F_cx;
  wrench_y = -F_cy;

  // Impedance control commands
  F_cmd_x = K_p * (x_ref - x) - K_d * vx;
  F_cmd_y = K_p * (y_ref - y) - K_d * vy + M_peg * g;

  // Dynamics
  M_peg * der(vx) = max(-F_max, min(F_max, F_cmd_x)) + F_cx + F_dist;
  M_peg * der(vy) = max(-F_max, min(F_max, F_cmd_y)) + F_cy;
  der(x) = vx;
  der(y) = vy;
  
  // Tilt (2D model, tilt is zero)
  tilt = 0.0;

  // Tracking error
  track_err = sqrt(x^2 + (y - y_ref)^2);

  // Constraints
  assert(abs(F_cmd_x) <= F_max + 1e-3, "Actuator bound violated");
  assert(abs(F_cmd_y) <= F_max + 1e-3, "Actuator bound violated");
  assert(abs(x) < 0.003 or time < 5.2, "Alignment tracking error > 0.003 m after 5.2s");
  assert(abs(wrench_x) <= 1000.0, "Lateral force limit exceeded");
  assert(abs(wrench_y) <= 1000.0, "Axial force limit exceeded");
  assert(abs(tilt) < 0.01, "Peg tilt limit exceeded");
  assert(y > 0.06 - 0.001 or time < 7.0, "Insertion depth not reached");

initial equation
  x = 0.0015;
  vx = 0.0;
  y = -0.01;
  vy = 0.0;
end VacuumToolInsertA;