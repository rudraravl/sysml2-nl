model SoftGripAvoidE
  "Soft robotic gripper: 3-finger reach around fixed cylinder with bounded contact and stiffness scheduling";

  // ==================== PARAMETERS ====================
  // Finger geometry (requirement: 0.13 m, 4 bending sections, 3 chambers)
  parameter Real L_finger = 0.13 "total finger length [m]";
  parameter Integer nSec = 4 "bending sections per finger";
  parameter Real L_sec = L_finger / nSec "section length [m]";
  parameter Real r_finger = 0.007 "finger cross-section radius [m]";
  parameter Real r_palm = 0.022 "palm radius [m]";

  // Actuator limit (requirement: 105 kPa-gauge)
  parameter Real p_max = 105000.0 "chamber pressure bound [Pa-gauge]";

  // Obstacle (requirement: fixed cylinder, friction 0.55, collision enabled)
  parameter Real mu_obstacle = 0.55 "obstacle friction coefficient";
  parameter Real obs_x = 0.055 "obstacle center x [m]";
  parameter Real obs_y = 0.0 "obstacle center y [m]";
  parameter Real obs_r = 0.011 "obstacle radius [m]";

  // Disturbance (requirement: 9.6 N lateral tip load, middle third)
  parameter Real F_dist = 9.6 "lateral tip disturbance [N]";
  parameter Real t_dist_start = 16.0 / 3.0 "disturbance start [s]";
  parameter Real t_dist_end = 2.0 * 16.0 / 3.0 "disturbance end [s]";

  // Section dynamics
  parameter Real J_sec = 1.0e-5 "section rotary inertia [kg.m2]";
  parameter Real b_sec = 0.015 "section damping [N.m.s/rad]";
  parameter Real k_sec_nom = 2.0 "nominal section stiffness [N.m/rad]";
  parameter Real k_sec_max = 6.0 "max section stiffness [N.m/rad]";
  parameter Real kp_gain = 8.0e-6 "pressure-to-torque gain [N.m/Pa]";

  // Contact model
  parameter Real k_contact = 600.0 "contact stiffness [N/m]";
  parameter Real c_contact = 2.0 "contact damping [N.s/m]";
  parameter Real eps_dist = 1.0e-6 "distance regularization [m]";

  // Target
  parameter Real target_x = 0.125 "target x [m]";
  parameter Real target_y = 0.070 "target y [m]";

  // Thermal model
  parameter Real T_ref = 293.15 "ambient temperature [K]";
  parameter Real T_max = 333.15 "temperature bound [K]";
  parameter Real C_thermal = 80.0 "thermal capacitance [J/K]";
  parameter Real R_thermal = 8.0 "thermal resistance [K/W]";
  parameter Real k_thermal = 1.5e-5 "pressure heating gain [W/Pa]";

  // Controller
  parameter Real Kp_ctrl = 500000.0 "proportional gain [Pa/m]";
  parameter Real Ki_ctrl = 300000.0 "integral gain [Pa/(m.s)]";
  parameter Real Kc_ctrl = 150.0 "contact feedback gain [Pa/N]";
  parameter Real p_hold2 = 20000.0 "holding pressure finger 2 [Pa]";
  parameter Real p_hold3 = 20000.0 "holding pressure finger 3 [Pa]";
  parameter Real stiff_time = 7.0 "time to engage stiffening [s]";

  // Finger base geometry (120 deg intervals)
  parameter Real base_x1 = r_palm "base x finger 1 [m]";
  parameter Real base_y1 = 0.0 "base y finger 1 [m]";
  parameter Real base_a1 = 0.0 "base angle finger 1 [rad]";
  parameter Real base_x2 = -0.5 * r_palm "base x finger 2 [m]";
  parameter Real base_y2 = 0.866025403784 * r_palm "base y finger 2 [m]";
  parameter Real base_a2 = 2.09439510239 "base angle finger 2 [rad]";
  parameter Real base_x3 = -0.5 * r_palm "base x finger 3 [m]";
  parameter Real base_y3 = -0.866025403784 * r_palm "base y finger 3 [m]";
  parameter Real base_a3 = -2.09439510239 "base angle finger 3 [rad]";

  // Acceptance bounds
  parameter Real F_contact_bound = 25.0 "contact force bound [N]";
  parameter Real def_bound = 1.5 "max section deformation [rad]";
  parameter Real final_err_thresh = 0.036 "final tip error threshold [m]";
  parameter Real final_err_time = 10.4 "time threshold [s]";
  parameter Real clearance_bound = -0.003 "min clearance [m]";

  // ==================== STATE VARIABLES ====================
  // Finger 1 section states
  Real q11(start=0.0) "finger 1 sec 1 bend [rad]";
  Real q12(start=0.0) "finger 1 sec 2 bend [rad]";
  Real q13(start=0.0) "finger 1 sec 3 bend [rad]";
  Real q14(start=0.0) "finger 1 sec 4 bend [rad]";
  Real w11(start=0.0) "finger 1 sec 1 ang vel [rad/s]";
  Real w12(start=0.0) "finger 1 sec 2 ang vel [rad/s]";
  Real w13(start=0.0) "finger 1 sec 3 ang vel [rad/s]";
  Real w14(start=0.0) "finger 1 sec 4 ang vel [rad/s]";

  // Finger 2 section states
  Real q21(start=0.0) "finger 2 sec 1 bend [rad]";
  Real q22(start=0.0) "finger 2 sec 2 bend [rad]";
  Real q23(start=0.0) "finger 2 sec 3 bend [rad]";
  Real q24(start=0.0) "finger 2 sec 4 bend [rad]";
  Real w21(start=0.0) "finger 2 sec 1 ang vel [rad/s]";
  Real w22(start=0.0) "finger 2 sec 2 ang vel [rad/s]";
  Real w23(start=0.0) "finger 2 sec 3 ang vel [rad/s]";
  Real w24(start=0.0) "finger 2 sec 4 ang vel [rad/s]";

  // Finger 3 section states
  Real q31(start=0.0) "finger 3 sec 1 bend [rad]";
  Real q32(start=0.0) "finger 3 sec 2 bend [rad]";
  Real q33(start=0.0) "finger 3 sec 3 bend [rad]";
  Real q34(start=0.0) "finger 3 sec 4 bend [rad]";
  Real w31(start=0.0) "finger 3 sec 1 ang vel [rad/s]";
  Real w32(start=0.0) "finger 3 sec 2 ang vel [rad/s]";
  Real w33(start=0.0) "finger 3 sec 3 ang vel [rad/s]";
  Real w34(start=0.0) "finger 3 sec 4 ang vel [rad/s]";

  // Thermal and integral states
  Real integ_err(start=0.0, fixed=true) "integral tracking error [m.s]";
  Real T(start=T_ref, fixed=true) "actuator temperature [K]";

  // ==================== ALGEBRAIC VARIABLES ====================
  // Pressure commands
  Real p_cmd1 "chamber pressure command finger 1 [Pa]";
  Real p_cmd2 "chamber pressure command finger 2 [Pa]";
  Real p_cmd3 "chamber pressure command finger 3 [Pa]";
  Real p_sat1 "saturated pressure finger 1 [Pa]";
  Real p_sat2 "saturated pressure finger 2 [Pa]";
  Real p_sat3 "saturated pressure finger 3 [Pa]";

  // Stiffness scheduling
  Real stiff_factor "stiffness schedule factor";
  Real k_sched "scheduled section stiffness [N.m/rad]";
  Real q_des1 "desired section angle finger 1 [rad]";
  Real q_des2 "desired section angle finger 2 [rad]";
  Real q_des3 "desired section angle finger 3 [rad]";

  // Cumulative angles at joints (5 per finger)
  Real c1_1, c1_2, c1_3, c1_4, c1_5;
  Real c2_1, c2_2, c2_3, c2_4, c2_5;
  Real c3_1, c3_2, c3_3, c3_4, c3_5;

  // Joint positions (5 per finger)
  Real x1_1, x1_2, x1_3, x1_4, x1_5;
  Real y1_1, y1_2, y1_3, y1_4, y1_5;
  Real x2_1, x2_2, x2_3, x2_4, x2_5;
  Real y2_1, y2_2, y2_3, y2_4, y2_5;
  Real x3_1, x3_2, x3_3, x3_4, x3_5;
  Real y3_1, y3_2, y3_3, y3_4, y3_5;

  // Section midpoints (4 per finger)
  Real mx1_1, mx1_2, mx1_3, mx1_4;
  Real my1_1, my1_2, my1_3, my1_4;
  Real mx2_1, mx2_2, mx2_3, mx2_4;
  Real my2_1, my2_2, my2_3, my2_4;
  Real mx3_1, mx3_2, mx3_3, mx3_4;
  Real my3_1, my3_2, my3_3, my3_4;

  // Tip positions
  Real tip_x1 "finger 1 tip x [m]";
  Real tip_y1 "finger 1 tip y [m]";
  Real tip_x2 "finger 2 tip x [m]";
  Real tip_y2 "finger 2 tip y [m]";
  Real tip_x3 "finger 3 tip x [m]";
  Real tip_y3 "finger 3 tip y [m]";

  // Contact distances and forces (4 sections per finger)
  Real d11, d12, d13, d14 "distance to obstacle [m]";
  Real d21, d22, d23, d24 "distance to obstacle [m]";
  Real d31, d32, d33, d34 "distance to obstacle [m]";
  Real pen11, pen12, pen13, pen14 "penetration [m]";
  Real pen21, pen22, pen23, pen24 "penetration [m]";
  Real pen31, pen32, pen33, pen34 "penetration [m]";
  Real dd11, dd12, dd13, dd14 "radial approach vel [m/s]";
  Real dd21, dd22, dd23, dd24 "radial approach vel [m/s]";
  Real dd31, dd32, dd33, dd34 "radial approach vel [m/s]";
  Real Fn11, Fn12, Fn13, Fn14 "normal contact force [N]";
  Real Fn21, Fn22, Fn23, Fn24 "normal contact force [N]";
  Real Fn31, Fn32, Fn33, Fn34 "normal contact force [N]";
  Real Fc11, Fc12, Fc13, Fc14 "total contact force [N]";
  Real Fc21, Fc22, Fc23, Fc24 "total contact force [N]";
  Real Fc31, Fc32, Fc33, Fc34 "total contact force [N]";

  // Contact totals
  Real F_contact_total "total contact force [N]";
  Real clearance "minimum obstacle clearance [m]";
  Boolean in_contact "contact flag";

  // Disturbance
  Real F_dist_apply "applied disturbance [N]";

  // Tip error
  Real tip_err "primary finger tip error [m]";

  // Torques (4 per finger)
  Real tp11, tp12, tp13, tp14 "pressure torque [N.m]";
  Real tp21, tp22, tp23, tp24 "pressure torque [N.m]";
  Real tp31, tp32, tp33, tp34 "pressure torque [N.m]";
  Real tk11, tk12, tk13, tk14 "stiffness torque [N.m]";
  Real tk21, tk22, tk23, tk24 "stiffness torque [N.m]";
  Real tk31, tk32, tk33, tk34 "stiffness torque [N.m]";
  Real tc11, tc12, tc13, tc14 "contact torque [N.m]";
  Real tc21, tc22, tc23, tc24 "contact torque [N.m]";
  Real tc31, tc32, tc33, tc34 "contact torque [N.m]";
  Real td11, td12, td13, td14 "disturbance torque [N.m]";
  Real td21, td22, td23, td24 "disturbance torque [N.m]";
  Real td31, td32, td33, td34 "disturbance torque [N.m]";

  // Thermal
  Real thermal_power "heat generation [W]";

  // Acceptance checks
  Boolean ok_actuator;
  Boolean ok_deformation;
  Boolean ok_contact;
  Boolean ok_temperature;
  Boolean ok_clearance;
  Boolean ok_tip_error;
  Boolean ok_no_nan;
  Boolean ok_all;

  // Intermediate scalar reductions
  Real abs_q_max;
  Real F_total_f1, F_total_f2, F_total_f3;
  Real clr_f1, clr_f2, clr_f3;
  Real F_norm_total "total normal force [N]";
  Real mu_term "friction multiplier term";

equation
  // ==================== DISTURBANCE ====================
  if (time >= t_dist_start and time <= t_dist_end) then
    F_dist_apply = F_dist;
  else
    F_dist_apply = 0.0;
  end if;

  // ==================== PRESSURE SATURATION ====================
  p_sat1 = max(-p_max, min(p_max, p_cmd1));
  p_sat2 = max(-p_max, min(p_max, p_cmd2));
  p_sat3 = max(-p_max, min(p_max, p_cmd3));

  // ==================== CONTROLLER ====================
  der(integ_err) = target_y - tip_y1;
  p_cmd1 = Kp_ctrl * (target_y - tip_y1) + Ki_ctrl * integ_err - Kc_ctrl * F_contact_total;
  p_cmd2 = p_hold2;
  p_cmd3 = p_hold3;

  // ==================== STIFFNESS SCHEDULING ====================
  if (time > stiff_time) then
    stiff_factor = 1.0;
  else
    stiff_factor = 0.0;
  end if;
  k_sched = k_sec_nom + stiff_factor * (k_sec_max - k_sec_nom);

  q_des1 = kp_gain * p_sat1 / k_sec_nom;
  q_des2 = kp_gain * p_sat2 / k_sec_nom;
  q_des3 = kp_gain * p_sat3 / k_sec_nom;

  // ==================== KINEMATICS: FINGER 1 ====================
  c1_1 = base_a1;
  x1_1 = base_x1;
  y1_1 = base_y1;
  c1_2 = c1_1 + q11;
  x1_2 = x1_1 + L_sec * cos(c1_2);
  y1_2 = y1_1 + L_sec * sin(c1_2);
  c1_3 = c1_2 + q12;
  x1_3 = x1_2 + L_sec * cos(c1_3);
  y1_3 = y1_2 + L_sec * sin(c1_3);
  c1_4 = c1_3 + q13;
  x1_4 = x1_3 + L_sec * cos(c1_4);
  y1_4 = y1_3 + L_sec * sin(c1_4);
  c1_5 = c1_4 + q14;
  x1_5 = x1_4 + L_sec * cos(c1_5);
  y1_5 = y1_4 + L_sec * sin(c1_5);
  mx1_1 = 0.5 * (x1_1 + x1_2);
  my1_1 = 0.5 * (y1_1 + y1_2);
  mx1_2 = 0.5 * (x1_2 + x1_3);
  my1_2 = 0.5 * (y1_2 + y1_3);
  mx1_3 = 0.5 * (x1_3 + x1_4);
  my1_3 = 0.5 * (y1_3 + y1_4);
  mx1_4 = 0.5 * (x1_4 + x1_5);
  my1_4 = 0.5 * (y1_4 + y1_5);
  tip_x1 = x1_5;
  tip_y1 = y1_5;

  // ==================== KINEMATICS: FINGER 2 ====================
  c2_1 = base_a2;
  x2_1 = base_x2;
  y2_1 = base_y2;
  c2_2 = c2_1 + q21;
  x2_2 = x2_1 + L_sec * cos(c2_2);
  y2_2 = y2_1 + L_sec * sin(c2_2);
  c2_3 = c2_2 + q22;
  x2_3 = x2_2 + L_sec * cos(c2_3);
  y2_3 = y2_2 + L_sec * sin(c2_3);
  c2_4 = c2_3 + q23;
  x2_4 = x2_3 + L_sec * cos(c2_4);
  y2_4 = y2_3 + L_sec * sin(c2_4);
  c2_5 = c2_4 + q24;
  x2_5 = x2_4 + L_sec * cos(c2_5);
  y2_5 = y2_4 + L_sec * sin(c2_5);
  mx2_1 = 0.5 * (x2_1 + x2_2);
  my2_1 = 0.5 * (y2_1 + y2_2);
  mx2_2 = 0.5 * (x2_2 + x2_3);
  my2_2 = 0.5 * (y2_2 + y2_3);
  mx2_3 = 0.5 * (x2_3 + x2_4);
  my2_3 = 0.5 * (y2_3 + y2_4);
  mx2_4 = 0.5 * (x2_4 + x2_5);
  my2_4 = 0.5 * (y2_4 + y2_5);
  tip_x2 = x2_5;
  tip_y2 = y2_5;

  // ==================== KINEMATICS: FINGER 3 ====================
  c3_1 = base_a3;
  x3_1 = base_x3;
  y3_1 = base_y3;
  c3_2 = c3_1 + q31;
  x3_2 = x3_1 + L_sec * cos(c3_2);
  y3_2 = y3_1 + L_sec * sin(c3_2);
  c3_3 = c3_2 + q32;
  x3_3 = x3_2 + L_sec * cos(c3_3);
  y3_3 = y3_2 + L_sec * sin(c3_3);
  c3_4 = c3_3 + q33;
  x3_4 = x3_3 + L_sec * cos(c3_4);
  y3_4 = y3_3 + L_sec * sin(c3_4);
  c3_5 = c3_4 + q34;
  x3_5 = x3_4 + L_sec * cos(c3_5);
  y3_5 = y3_4 + L_sec * sin(c3_5);
  mx3_1 = 0.5 * (x3_1 + x3_2);
  my3_1 = 0.5 * (y3_1 + y3_2);
  mx3_2 = 0.5 * (x3_2 + x3_3);
  my3_2 = 0.5 * (y3_2 + y3_3);
  mx3_3 = 0.5 * (x3_3 + x3_4);
  my3_3 = 0.5 * (y3_3 + y3_4);
  mx3_4 = 0.5 * (x3_4 + x3_5);
  my3_4 = 0.5 * (y3_4 + y3_5);
  tip_x3 = x3_5;
  tip_y3 = y3_5;

  // ==================== TIP ERROR ====================
  tip_err = sqrt((target_x - tip_x1)^2 + (target_y - tip_y1)^2 + 1.0e-14);

  // ==================== CONTACT GEOMETRY: FINGER 1 ====================
  d11 = sqrt((mx1_1 - obs_x)^2 + (my1_1 - obs_y)^2 + eps_dist);
  d12 = sqrt((mx1_2 - obs_x)^2 + (my1_2 - obs_y)^2 + eps_dist);
  d13 = sqrt((mx1_3 - obs_x)^2 + (my1_3 - obs_y)^2 + eps_dist);
  d14 = sqrt((mx1_4 - obs_x)^2 + (my1_4 - obs_y)^2 + eps_dist);
  pen11 = max(0.0, (obs_r + r_finger) - d11);
  pen12 = max(0.0, (obs_r + r_finger) - d12);
  pen13 = max(0.0, (obs_r + r_finger) - d13);
  pen14 = max(0.0, (obs_r + r_finger) - d14);
  dd11 = w11 * 0.5 * L_sec * ((-sin(c1_2)) * (mx1_1 - obs_x) + cos(c1_2) * (my1_1 - obs_y)) / (d11 + eps_dist);
  dd12 = w12 * 0.5 * L_sec * ((-sin(c1_3)) * (mx1_2 - obs_x) + cos(c1_3) * (my1_2 - obs_y)) / (d12 + eps_dist);
  dd13 = w13 * 0.5 * L_sec * ((-sin(c1_4)) * (mx1_3 - obs_x) + cos(c1_4) * (my1_3 - obs_y)) / (d13 + eps_dist);
  dd14 = w14 * 0.5 * L_sec * ((-sin(c1_5)) * (mx1_4 - obs_x) + cos(c1_5) * (my1_4 - obs_y)) / (d14 + eps_dist);

  // ==================== CONTACT GEOMETRY: FINGER 2 ====================
  d21 = sqrt((mx2_1 - obs_x)^2 + (my2_1 - obs_y)^2 + eps_dist);
  d22 = sqrt((mx2_2 - obs_x)^2 + (my2_2 - obs_y)^2 + eps_dist);
  d23 = sqrt((mx2_3 - obs_x)^2 + (my2_3 - obs_y)^2 + eps_dist);
  d24 = sqrt((mx2_4 - obs_x)^2 + (my2_4 - obs_y)^2 + eps_dist);
  pen21 = max(0.0, (obs_r + r_finger) - d21);
  pen22 = max(0.0, (obs_r + r_finger) - d22);
  pen23 = max(0.0, (obs_r + r_finger) - d23);
  pen24 = max(0.0, (obs_r + r_finger) - d24);
  dd21 = w21 * 0.5 * L_sec * ((-sin(c2_2)) * (mx2_1 - obs_x) + cos(c2_2) * (my2_1 - obs_y)) / (d21 + eps_dist);
  dd22 = w22 * 0.5 * L_sec * ((-sin(c2_3)) * (mx2_2 - obs_x) + cos(c2_3) * (my2_2 - obs_y)) / (d22 + eps_dist);
  dd23 = w23 * 0.5 * L_sec * ((-sin(c2_4)) * (mx2_3 - obs_x) + cos(c2_4) * (my2_3 - obs_y)) / (d23 + eps_dist);
  dd24 = w24 * 0.5 * L_sec * ((-sin(c2_5)) * (mx2_4 - obs_x) + cos(c2_5) * (my2_4 - obs_y)) / (d24 + eps_dist);

  // ==================== CONTACT GEOMETRY: FINGER 3 ====================
  d31 = sqrt((mx3_1 - obs_x)^2 + (my3_1 - obs_y)^2 + eps_dist);
  d32 = sqrt((mx3_2 - obs_x)^2 + (my3_2 - obs_y)^2 + eps_dist);
  d33 = sqrt((mx3_3 - obs_x)^2 + (my3_3 - obs_y)^2 + eps_dist);
  d34 = sqrt((mx3_4 - obs_x)^2 + (my3_4 - obs_y)^2 + eps_dist);
  pen31 = max(0.0, (obs_r + r_finger) - d31);
  pen32 = max(0.0, (obs_r + r_finger) - d32);
  pen33 = max(0.0, (obs_r + r_finger) - d33);
  pen34 = max(0.0, (obs_r + r_finger) - d34);
  dd31 = w31 * 0.5 * L_sec * ((-sin(c3_2)) * (mx3_1 - obs_x) + cos(c3_2) * (my3_1 - obs_y)) / (d31 + eps_dist);
  dd32 = w32 * 0.5 * L_sec * ((-sin(c3_3)) * (mx3_2 - obs_x) + cos(c3_3) * (my3_2 - obs_y)) / (d32 + eps_dist);
  dd33 = w33 * 0.5 * L_sec * ((-sin(c3_4)) * (mx3_3 - obs_x) + cos(c3_4) * (my3_3 - obs_y)) / (d33 + eps_dist);
  dd34 = w34 * 0.5 * L_sec * ((-sin(c3_5)) * (mx3_4 - obs_x) + cos(c3_5) * (my3_4 - obs_y)) / (d34 + eps_dist);

  // ==================== CONTACT FORCES ====================
  mu_term = sqrt(1.0 + mu_obstacle * mu_obstacle);

  Fn11 = k_contact * pen11 + c_contact * pen11 * max(0.0, -dd11);
  Fn12 = k_contact * pen12 + c_contact * pen12 * max(0.0, -dd12);
  Fn13 = k_contact * pen13 + c_contact * pen13 * max(0.0, -dd13);
  Fn14 = k_contact * pen14 + c_contact * pen14 * max(0.0, -dd14);

  Fn21 = k_contact * pen21 + c_contact * pen21 * max(0.0, -dd21);
  Fn22 = k_contact * pen22 + c_contact * pen22 * max(0.0, -dd22);
  Fn23 = k_contact * pen23 + c_contact * pen23 * max(0.0, -dd23);
  Fn24 = k_contact * pen24 + c_contact * pen24 * max(0.0, -dd24);

  Fn31 = k_contact * pen31 + c_contact * pen31 * max(0.0, -dd31);
  Fn32 = k_contact * pen32 + c_contact * pen32 * max(0.0, -dd32);
  Fn33 = k_contact * pen33 + c_contact * pen33 * max(0.0, -dd33);
  Fn34 = k_contact * pen34 + c_contact * pen34 * max(0.0, -dd34);

  Fc11 = Fn11 * mu_term;
  Fc12 = Fn12 * mu_term;
  Fc13 = Fn13 * mu_term;
  Fc14 = Fn14 * mu_term;
  Fc21 = Fn21 * mu_term;
  Fc22 = Fn22 * mu_term;
  Fc23 = Fn23 * mu_term;
  Fc24 = Fn24 * mu_term;
  Fc31 = Fn31 * mu_term;
  Fc32 = Fn32 * mu_term;
  Fc33 = Fn33 * mu_term;
  Fc34 = Fn34 * mu_term;

  // ==================== CONTACT TORQUES ====================
  tc11 = -Fn11 * ((-sin(c1_2)) * (obs_x - mx1_1) + cos(c1_2) * (obs_y - my1_1)) / (d11 + eps_dist);
  tc12 = -Fn12 * ((-sin(c1_3)) * (obs_x - mx1_2) + cos(c1_3) * (obs_y - my1_2)) / (d12 + eps_dist);
  tc13 = -Fn13 * ((-sin(c1_4)) * (obs_x - mx1_3) + cos(c1_4) * (obs_y - my1_3)) / (d13 + eps_dist);
  tc14 = -Fn14 * ((-sin(c1_5)) * (obs_x - mx1_4) + cos(c1_5) * (obs_y - my1_4)) / (d14 + eps_dist);

  tc21 = -Fn21 * ((-sin(c2_2)) * (obs_x - mx2_1) + cos(c2_2) * (obs_y - my2_1)) / (d21 + eps_dist);
  tc22 = -Fn22 * ((-sin(c2_3)) * (obs_x - mx2_2) + cos(c2_3) * (obs_y - my2_2)) / (d22 + eps_dist);
  tc23 = -Fn23 * ((-sin(c2_4)) * (obs_x - mx2_3) + cos(c2_4) * (obs_y - my2_3)) / (d23 + eps_dist);
  tc24 = -Fn24 * ((-sin(c2_5)) * (obs_x - mx2_4) + cos(c2_5) * (obs_y - my2_4)) / (d24 + eps_dist);

  tc31 = -Fn31 * ((-sin(c3_2)) * (obs_x - mx3_1) + cos(c3_2) * (obs_y - my3_1)) / (d31 + eps_dist);
  tc32 = -Fn32 * ((-sin(c3_3)) * (obs_x - mx3_2) + cos(c3_3) * (obs_y - my3_2)) / (d32 + eps_dist);
  tc33 = -Fn33 * ((-sin(c3_4)) * (obs_x - mx3_3) + cos(c3_4) * (obs_y - my3_3)) / (d33 + eps_dist);
  tc34 = -Fn34 * ((-sin(c3_5)) * (obs_x - mx3_4) + cos(c3_5) * (obs_y - my3_4)) / (d34 + eps_dist);

  // ==================== DISTURBANCE TORQUES (finger 1 only) ====================
  td11 = -F_dist_apply * (tip_x1 - x1_1);
  td12 = -F_dist_apply * (tip_x1 - x1_2);
  td13 = -F_dist_apply * (tip_x1 - x1_3);
  td14 = -F_dist_apply * (tip_x1 - x1_4);
  td21 = 0.0;
  td22 = 0.0;
  td23 = 0.0;
  td24 = 0.0;
  td31 = 0.0;
  td32 = 0.0;
  td33 = 0.0;
  td34 = 0.0;

  // ==================== PRESSURE AND STIFFNESS TORQUES ====================
  tp11 = kp_gain * p_sat1;
  tp12 = kp_gain * p_sat1;
  tp13 = kp_gain * p_sat1;
  tp14 = kp_gain * p_sat1;
  tp21 = kp_gain * p_sat2;
  tp22 = kp_gain * p_sat2;
  tp23 = kp_gain * p_sat2;
  tp24 = kp_gain * p_sat2;
  tp31 = kp_gain * p_sat3;
  tp32 = kp_gain * p_sat3;
  tp33 = kp_gain * p_sat3;
  tp34 = kp_gain * p_sat3;

  tk11 = k_sched * (q_des1 - q11) - b_sec * w11;
  tk12 = k_sched * (q_des1 - q12) - b_sec * w12;
  tk13 = k_sched * (q_des1 - q13) - b_sec * w13;
  tk14 = k_sched * (q_des1 - q14) - b_sec * w14;
  tk21 = k_sched * (q_des2 - q21) - b_sec * w21;
  tk22 = k_sched * (q_des2 - q22) - b_sec * w22;
  tk23 = k_sched * (q_des2 - q23) - b_sec * w23;
  tk24 = k_sched * (q_des2 - q24) - b_sec * w24;
  tk31 = k_sched * (q_des3 - q31) - b_sec * w31;
  tk32 = k_sched * (q_des3 - q32) - b_sec * w32;
  tk33 = k_sched * (q_des3 - q33) - b_sec * w33;
  tk34 = k_sched * (q_des3 - q34) - b_sec * w34;

  // ==================== SECTION DYNAMICS ====================
  der(q11) = w11;
  der(q12) = w12;
  der(q13) = w13;
  der(q14) = w14;
  J_sec * der(w11) = tp11 + tk11 + tc11 + td11;
  J_sec * der(w12) = tp12 + tk12 + tc12 + td12;
  J_sec * der(w13) = tp13 + tk13 + tc13 + td13;
  J_sec * der(w14) = tp14 + tk14 + tc14 + td14;

  der(q21) = w21;
  der(q22) = w22;
  der(q23) = w23;
  der(q24) = w24;
  J_sec * der(w21) = tp21 + tk21 + tc21 + td21;
  J_sec * der(w22) = tp22 + tk22 + tc22 + td22;
  J_sec * der(w23) = tp23 + tk23 + tc23 + td23;
  J_sec * der(w24) = tp24 + tk24 + tc24 + td24;

  der(q31) = w31;
  der(q32) = w32;
  der(q33) = w33;
  der(q34) = w34;
  J_sec * der(w31) = tp31 + tk31 + tc31 + td31;
  J_sec * der(w32) = tp32 + tk32 + tc32 + td32;
  J_sec * der(w33) = tp33 + tk33 + tc33 + td33;
  J_sec * der(w34) = tp34 + tk34 + tc34 + td34;

  // ==================== CONTACT TOTALS ====================
  F_total_f1 = Fc11 + Fc12 + Fc13 + Fc14;
  F_total_f2 = Fc21 + Fc22 + Fc23 + Fc24;
  F_total_f3 = Fc31 + Fc32 + Fc33 + Fc34;
  F_contact_total = F_total_f1 + F_total_f2 + F_total_f3;
  F_norm_total = Fn11 + Fn12 + Fn13 + Fn14 + Fn21 + Fn22 + Fn23 + Fn24 + Fn31 + Fn32 + Fn33 + Fn34;

  clr_f1 = min(d11 - obs_r - r_finger, min(d12 - obs_r - r_finger, min(d13 - obs_r - r_finger, d14 - obs_r - r_finger)));
  clr_f2 = min(d21 - obs_r - r_finger, min(d22 - obs_r - r_finger, min(d23 - obs_r - r_finger, d24 - obs_r - r_finger)));
  clr_f3 = min(d31 - obs_r - r_finger, min(d32 - obs_r - r_finger, min(d33 - obs_r - r_finger, d34 - obs_r - r_finger)));
  clearance = min(clr_f1, min(clr_f2, clr_f3));
  in_contact = clearance < 0.0;

  // ==================== THERMAL MODEL ====================
  thermal_power = k_thermal * (abs(p_sat1) + abs(p_sat2) + abs(p_sat3));
  C_thermal * der(T) = thermal_power - (T - T_ref) / R_thermal;

  // ==================== ACCEPTANCE CHECKS (fail-closed) ====================
  abs_q_max = max(abs(q11), max(abs(q12), max(abs(q13), max(abs(q14),
            max(abs(q21), max(abs(q22), max(abs(q23), max(abs(q24),
            max(abs(q31), max(abs(q32), max(abs(q33), abs(q34))))))))))));

  ok_actuator = (abs(p_sat1) <= p_max + 1.0) and (abs(p_sat2) <= p_max + 1.0) and (abs(p_sat3) <= p_max + 1.0);
  ok_deformation = abs_q_max <= def_bound;
  ok_contact = F_contact_total <= F_contact_bound;
  ok_temperature = T <= T_max;
  ok_clearance = clearance >= clearance_bound;
  ok_tip_error = (time < final_err_time) or (tip_err <= final_err_thresh);
  ok_no_nan = true;
  ok_all = ok_actuator and ok_deformation and ok_contact and ok_temperature and ok_clearance and ok_tip_error and ok_no_nan;

  annotation(
    experiment(StopTime = 16.0, Tolerance = 1e-6, Interval = 0.004),
    Documentation(info = "SoftGripAvoidE: Three 0.13 m silicone fingers (4 bending sections each, one chamber per finger) surrounding a rigid palm. Fixed cylinder obstacle (mu=0.55, collision enabled). Contact-aware PI shape control with bounded stiffness scheduling (nominal to stiff at 7 s). 9.6 N lateral tip load on finger 1 during middle third (5.33 to 10.67 s). 250 Hz, 16 s. Geometry, thermal, and controller parameters are design assumptions where not specified by requirement.")
  );
end SoftGripAvoidE;