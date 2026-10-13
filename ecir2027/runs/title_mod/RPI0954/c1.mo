model SeaSnakeHoldF
  "Free-base articulated underwater robot holding 6-DOF pose beside offshore structure"

  /* ===== Timing ===== */
  parameter Real Ts        = 0.002  "Control sampling period [s] (500 Hz)";
  parameter Real Tfinal    = 20.0   "Mission duration [s]";

  /* ===== Embodiment ===== */
  parameter Real m_body        = 32.0  "Robot mass [kg]";
  parameter Integer n_modules  = 6     "Number of capsule modules";
  parameter Real module_length = 0.30  "Per-module length [m]";
  parameter Real L_total       = 1.8   "Total body length [m]";
  parameter Real Ixx = 0.60 "Body inertia x [kg.m2]";
  parameter Real Iyy = 0.60 "Body inertia y [kg.m2]";
  parameter Real Izz = 0.60 "Body inertia z [kg.m2]";
  parameter Real I_joint = 0.02 "Per-joint reflected inertia [kg.m2]";
  parameter Real d_joint = 0.20 "Per-joint damping [N.m.s/rad]";

  /* ===== Actuation bounds ===== */
  parameter Real tau_max        = 39.0 "Joint torque bound per joint [N.m]";
  parameter Real Wforce_max     = 120.0 "Body-wrench force bound [N]";
  parameter Real Wtorque_max    = 40.0  "Body-wrench torque bound [N.m]";

  /* ===== Structure (fixed collidable vertical cylinder) ===== */
  parameter Real struct_radius    = 0.50 "Cylinder radius [m]";
  parameter Real struct_x         = 2.00 "Cylinder center x [m]";
  parameter Real struct_y         = 0.00 "Cylinder center y [m]";
  parameter Real struct_z_center  = 0.00 "Cylinder center z [m]";
  parameter Real struct_height    = 10.0 "Cylinder height [m]";
  parameter Real clearance_min    = 0.30 "Minimum required clearance [m]";

  /* ===== Target pose (hold beside structure) ===== */
  parameter Real x_ref   = 0.00;
  parameter Real y_ref   = 0.00;
  parameter Real z_ref   = -5.00 "Hold depth [m]";
  parameter Real roll_ref  = 0.0;
  parameter Real pitch_ref = 0.0;
  parameter Real yaw_ref   = 0.0;

  /* ===== Disturbance (tether/current), middle third ===== */
  parameter Real F_dist       = 174.0 "Disturbance load magnitude [N]";
  parameter Real t_dist_start = 6.6666666667 "Disturbance start [s]";
  parameter Real t_dist_end   = 13.3333333333 "Disturbance end [s]";

  /* ===== Environment ===== */
  parameter Real rho_water = 1025.0 "Seawater density [kg/m3]";
  parameter Real g         = 9.81  "Gravity [m/s2]";
  parameter Real z_surface = 0.0   "Surface datum [m]";

  /* Hydrodynamic linear drag (simplified) */
  parameter Real d_lin_t = 12.0 "Translational linear drag [N.s/m]";
  parameter Real d_lin_r = 6.0  "Rotational linear drag [N.m.s/rad]";

  /* Propulsion coupling */
  parameter Real k_prop = 3.0 "Joint-rate to axial thrust coefficient [N.s/rad]";

  /* ===== Continuous states: position / velocity ===== */
  Real x(start=0.0, fixed=true);
  Real y(start=0.0, fixed=true);
  Real z(start=-5.0, fixed=true);
  Real vx(start=0.0, fixed=true);
  Real vy(start=0.0, fixed=true);
  Real vz(start=0.0, fixed=true);

  /* Orientation (ZYX Euler) and body angular rates */
  Real roll(start=0.0, fixed=true);
  Real pitch(start=0.0, fixed=true);
  Real yaw(start=0.0, fixed=true);
  Real wx(start=0.0, fixed=true);
  Real wy(start=0.0, fixed=true);
  Real wz(start=0.0, fixed=true);

  /* ===== Joints (6, alternating yaw/pitch); 12 actuators = agonist+antagonist per joint ===== */
  Real q1(start=0.0, fixed=true) "Joint 1 angle [rad]";
  Real q2(start=0.0, fixed=true) "Joint 2 angle [rad]";
  Real q3(start=0.0, fixed=true) "Joint 3 angle [rad]";
  Real q4(start=0.0, fixed=true) "Joint 4 angle [rad]";
  Real q5(start=0.0, fixed=true) "Joint 5 angle [rad]";
  Real q6(start=0.0, fixed=true) "Joint 6 angle [rad]";
  Real qd1(start=0.0, fixed=true) "Joint 1 rate [rad/s]";
  Real qd2(start=0.0, fixed=true) "Joint 2 rate [rad/s]";
  Real qd3(start=0.0, fixed=true) "Joint 3 rate [rad/s]";
  Real qd4(start=0.0, fixed=true) "Joint 4 rate [rad/s]";
  Real qd5(start=0.0, fixed=true) "Joint 5 rate [rad/s]";
  Real qd6(start=0.0, fixed=true) "Joint 6 rate [rad/s]";

  Real qd_des1 "Desired joint 1 rate [rad/s]";
  Real qd_des2 "Desired joint 2 rate [rad/s]";
  Real qd_des3 "Desired joint 3 rate [rad/s]";
  Real qd_des4 "Desired joint 4 rate [rad/s]";
  Real qd_des5 "Desired joint 5 rate [rad/s]";
  Real qd_des6 "Desired joint 6 rate [rad/s]";

  Real tau_cmd1 "Commanded joint 1 torque [N.m]";
  Real tau_cmd2 "Commanded joint 2 torque [N.m]";
  Real tau_cmd3 "Commanded joint 3 torque [N.m]";
  Real tau_cmd4 "Commanded joint 4 torque [N.m]";
  Real tau_cmd5 "Commanded joint 5 torque [N.m]";
  Real tau_cmd6 "Commanded joint 6 torque [N.m]";

  Real tau_sat1 "Saturated joint 1 torque [N.m]";
  Real tau_sat2 "Saturated joint 2 torque [N.m]";
  Real tau_sat3 "Saturated joint 3 torque [N.m]";
  Real tau_sat4 "Saturated joint 4 torque [N.m]";
  Real tau_sat5 "Saturated joint 5 torque [N.m]";
  Real tau_sat6 "Saturated joint 6 torque [N.m]";

  /* ===== Body-wrench command (discrete) ===== */
  discrete Real Fx_cmd "Commanded body force x [N]";
  discrete Real Fy_cmd "Commanded body force y [N]";
  discrete Real Fz_cmd "Commanded body force z [N]";
  discrete Real Tx_cmd "Commanded body torque x [N.m]";
  discrete Real Ty_cmd "Commanded body torque y [N.m]";
  discrete Real Tz_cmd "Commanded body torque z [N.m]";
  Real Fx_sat "Saturated body force x [N]";
  Real Fy_sat "Saturated body force y [N]";
  Real Fz_sat "Saturated body force z [N]";
  Real Tx_sat "Saturated body torque x [N.m]";
  Real Ty_sat "Saturated body torque y [N.m]";
  Real Tz_sat "Saturated body torque z [N.m]";

  /* ===== Disturbance application ===== */
  Real F_dist_x "Disturbance force x [N]";
  Real F_dist_y "Disturbance force y [N]";
  Real F_dist_z "Disturbance force z [N]";
  Boolean disturbance_active "True during middle third";

  /* ===== Propulsion from undulation ===== */
  Real F_prop_x "Propulsion force x [N]";
  Real F_prop_y "Propulsion force y [N]";
  Real F_prop_z "Propulsion force z [N]";
  Real qd_sum "Sum of all joint rates [rad/s]";

  /* ===== Sensors ===== */
  Real pressure_sensor  "Pressure reading [Pa]";
  Real imu_ax "IMU accel x [m/s2]";
  Real imu_ay "IMU accel y [m/s2]";
  Real imu_az "IMU accel z [m/s2]";
  Real imu_wx "IMU ang rate x [rad/s]";
  Real imu_wy "IMU ang rate y [rad/s]";
  Real imu_wz "IMU ang rate z [rad/s]";
  Real dvl_vx "DVL velocity x [m/s]";
  Real dvl_vy "DVL velocity y [m/s]";
  Real dvl_vz "DVL velocity z [m/s]";
  Real sonar_range "Forward sonar range to structure [m]";

  /* ===== Tether ===== */
  parameter Real tether_length     = 8.0  "Tether length [m]";
  parameter Real tether_max_tension= 300.0 "Tether tension limit [N]";
  Real tether_tension "Estimated tether tension [N]";
  Boolean tether_ok;

  /* ===== Verification quantities ===== */
  Real clearance     "Clearance to cylinder surface [m]";
  Real pos_error     "Position error magnitude [m]";
  Real att_error     "Attitude error magnitude [rad]";
  Real tracking_error "Primary tracking error [m]";
  Boolean tracking_ok;
  Boolean bounds_ok;
  Boolean clearance_ok;
  Boolean no_nan_inf;

  /* ===== Discrete sampling bookkeeping ===== */
  discrete Integer tick(start=0);
  discrete Real t_last(start=0.0);

  /* Orientation helper */
  Real cy "cos(yaw)";
  Real sy "sin(yaw)";

  /* Disturbance direction (fixed world-frame horizontal) */
  parameter Real dist_dir_x = 1.0;
  parameter Real dist_dir_y = 0.0;

protected
  function sat "Symmetric saturation"
    input Real u;
    input Real lim;
    output Real y;
  algorithm
    if u > lim then
      y := lim;
    elseif u < -lim then
      y := -lim;
    else
      y := u;
    end if;
  end sat;
equation
  cy = cos(yaw);
  sy = sin(yaw);

  /* ===== Translational dynamics (world frame) ===== */
  der(x) = vx;
  der(y) = vy;
  der(z) = vz;

  /* Neutral buoyancy assumed: buoyancy = weight, net gravity term = 0 */
  m_body*der(vx) = Fx_sat + F_prop_x + F_dist_x - d_lin_t*vx;
  m_body*der(vy) = Fy_sat + F_prop_y + F_dist_y - d_lin_t*vy;
  m_body*der(vz) = Fz_sat + F_prop_z + F_dist_z - d_lin_t*vz;

  /* ===== Rotational dynamics (body frame, simplified diagonal inertia) ===== */
  der(roll)  = wx;
  der(pitch) = wy;
  der(yaw)   = wz;
  Ixx*der(wx) = Tx_sat - d_lin_r*wx;
  Iyy*der(wy) = Ty_sat - d_lin_r*wy;
  Izz*der(wz) = Tz_sat - d_lin_r*wz;

  /* ===== Disturbance force (tether/current) ===== */
  disturbance_active = (time >= t_dist_start) and (time < t_dist_end);
  F_dist_x = if disturbance_active then F_dist*dist_dir_x else 0.0;
  F_dist_y = if disturbance_active then F_dist*dist_dir_y else 0.0;
  F_dist_z = 0.0;

  /* ===== Propulsion from undulatory joint motion (axial thrust along body x) ===== */
  qd_sum = qd1 + qd2 + qd3 + qd4 + qd5 + qd6;
  F_prop_x =  k_prop * qd_sum * cy;
  F_prop_y =  k_prop * qd_sum * sy;
  F_prop_z =  0.0;

  /* ===== Joint dynamics ===== */
  der(q1)  = qd1;
  der(q2)  = qd2;
  der(q3)  = qd3;
  der(q4)  = qd4;
  der(q5)  = qd5;
  der(q6)  = qd6;

  I_joint*der(qd1) = tau_sat1 - d_joint*qd1;
  I_joint*der(qd2) = tau_sat2 - d_joint*qd2;
  I_joint*der(qd3) = tau_sat3 - d_joint*qd3;
  I_joint*der(qd4) = tau_sat4 - d_joint*qd4;
  I_joint*der(qd5) = tau_sat5 - d_joint*qd5;
  I_joint*der(qd6) = tau_sat6 - d_joint*qd6;

  tau_sat1 = sat(tau_cmd1, tau_max);
  tau_sat2 = sat(tau_cmd2, tau_max);
  tau_sat3 = sat(tau_cmd3, tau_max);
  tau_sat4 = sat(tau_cmd4, tau_max);
  tau_sat5 = sat(tau_cmd5, tau_max);
  tau_sat6 = sat(tau_cmd6, tau_max);

  /* ===== Undulation command (small-amplitude hold oscillation) ===== */
  qd_des1 = 0.10 * sin(2.0*Modelica.Constants.pi*1.0*time + 0.0);
  qd_des2 = 0.10 * sin(2.0*Modelica.Constants.pi*1.0*time + 0.5);
  qd_des3 = 0.10 * sin(2.0*Modelica.Constants.pi*1.0*time + 1.0);
  qd_des4 = 0.10 * sin(2.0*Modelica.Constants.pi*1.0*time + 1.5);
  qd_des5 = 0.10 * sin(2.0*Modelica.Constants.pi*1.0*time + 2.0);
  qd_des6 = 0.10 * sin(2.0*Modelica.Constants.pi*1.0*time + 2.5);

  /* Joint torque command: track desired undulation rate (continuous inner loop) */
  tau_cmd1 = 2.0*(qd_des1 - qd1);
  tau_cmd2 = 2.0*(qd_des2 - qd2);
  tau_cmd3 = 2.0*(qd_des3 - qd3);
  tau_cmd4 = 2.0*(qd_des4 - qd4);
  tau_cmd5 = 2.0*(qd_des5 - qd5);
  tau_cmd6 = 2.0*(qd_des6 - qd6);

  /* ===== Discrete body-wrench station-keeping controller @ 500 Hz ===== */
  when sample(0, Ts) then
    tick = pre(tick) + 1;
    t_last = time;

    /* PD position control in world frame */
    Fx_cmd = 2.0*(x_ref - x) - 4.0*vx;
    Fy_cmd = 2.0*(y_ref - y) - 4.0*vy;
    Fz_cmd = 2.0*(z_ref - z) - 4.0*vz;

    /* PD attitude control */
    Tx_cmd = 1.5*(roll_ref  - roll)  - 1.0*wx;
    Ty_cmd = 1.5*(pitch_ref - pitch) - 1.0*wy;
    Tz_cmd = 1.5*(yaw_ref   - yaw)   - 1.0*wz;
  end when;

  /* ===== Saturate body wrench ===== */
  Fx_sat = sat(Fx_cmd, Wforce_max);
  Fy_sat = sat(Fy_cmd, Wforce_max);
  Fz_sat = sat(Fz_cmd, Wforce_max);
  Tx_sat = sat(Tx_cmd, Wtorque_max);
  Ty_sat = sat(Ty_cmd, Wtorque_max);
  Tz_sat = sat(Tz_cmd, Wtorque_max);

  /* ===== Sensors ===== */
  pressure_sensor = rho_water * g * (z_surface - z) + 101325.0;

  /* IMU accelerations computed from force balance (avoid der() on RHS) */
  imu_ax = (Fx_sat + F_prop_x + F_dist_x - d_lin_t*vx) / m_body;
  imu_ay = (Fy_sat + F_prop_y + F_dist_y - d_lin_t*vy) / m_body;
  imu_az = (Fz_sat + F_prop_z + F_dist_z - d_lin_t*vz) / m_body;
  imu_wx = wx;
  imu_wy = wy;
  imu_wz = wz;
  dvl_vx = vx;
  dvl_vy = vy;
  dvl_vz = vz;

  /* Forward sonar: range to cylinder along horizontal plane */
  sonar_range = max(0.01, sqrt((x - struct_x)*(x - struct_x) + (y - struct_y)*(y - struct_y)) - struct_radius);

  /* ===== Tether tension estimate (quasi-static, horizontal disturbance) ===== */
  tether_tension = sqrt(F_dist_x*F_dist_x + F_dist_y*F_dist_y);
  tether_ok = tether_tension <= tether_max_tension;

  /* ===== Clearance to cylinder surface ===== */
  clearance = max(0.0, sqrt((x - struct_x)*(x - struct_x) + (y - struct_y)*(y - struct_y)) - struct_radius);

  /* ===== Tracking and verification ===== */
  pos_error = sqrt((x - x_ref)*(x - x_ref) + (y - y_ref)*(y - y_ref) + (z - z_ref)*(z - z_ref));
  att_error = sqrt((roll - roll_ref)*(roll - roll_ref) + (pitch - pitch_ref)*(pitch - pitch_ref) + (yaw - yaw_ref)*(yaw - yaw_ref));
  tracking_error = pos_error;
  tracking_ok   = (time >= 13.0) and (tracking_error < 0.24);
  clearance_ok  = clearance >= clearance_min;

  bounds_ok = (abs(Fx_sat) <= Wforce_max + 1e-6) and (abs(Fy_sat) <= Wforce_max + 1e-6)
           and (abs(Fz_sat) <= Wforce_max + 1e-6) and (abs(Tx_sat) <= Wtorque_max + 1e-6)
           and (abs(Ty_sat) <= Wtorque_max + 1e-6) and (abs(Tz_sat) <= Wtorque_max + 1e-6)
           and (abs(tau_sat1) <= tau_max + 1e-6) and (abs(tau_sat2) <= tau_max + 1e-6)
           and (abs(tau_sat3) <= tau_max + 1e-6) and (abs(tau_sat4) <= tau_max + 1e-6)
           and (abs(tau_sat5) <= tau_max + 1e-6) and (abs(tau_sat6) <= tau_max + 1e-6);

  /* NaN/Inf sanity check via bounded magnitude */
  no_nan_inf = (abs(x) < 1e9) and (abs(y) < 1e9) and (abs(z) < 1e9)
           and (abs(vx) < 1e9) and (abs(vy) < 1e9) and (abs(vz) < 1e9)
           and (abs(roll) < 1e9) and (abs(pitch) < 1e9) and (abs(yaw) < 1e9)
           and (abs(wx) < 1e9) and (abs(wy) < 1e9) and (abs(wz) < 1e9)
           and (abs(tracking_error) < 1e9) and (abs(tether_tension) < 1e9)
           and (abs(pressure_sensor) < 1e9) and (abs(sonar_range) < 1e9);

  annotation (
    Documentation(info="SeaSnakeHoldF: 32 kg articulated underwater robot (6 modules x 0.30 m,
      alternating yaw/pitch joints, passive tail fin represented by k_prop coupling).
      12 bounded joint actuators (agonist+antagonist per joint, |tau|<=39 N.m).
      Bounded body-wrench station keeping. Fixed collidable cylinder offshore structure.
      174 N tether/current disturbance applied during middle third [6.67, 13.33] s.
      Discrete control at 500 Hz, 20 s mission. Primary tracking error < 0.24 m after 13 s."),
    experiment(StartTime=0, StopTime=20.0, Tolerance=1e-6, Interval=0.002),
    uses(Modelica(version="4.0.0")));
end SeaSnakeHoldF;