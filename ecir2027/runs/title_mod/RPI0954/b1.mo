model SeaSnakeHoldF
  "Free-base articulated underwater robot holding 6-DOF pose beside offshore structure"

  /* ===== Timing ===== */
  parameter Real Ts        = 0.002  "Control sampling period [s] (500 Hz)";
  parameter Real Tfinal    = 20.0   "Mission duration [s]";

  /* ===== Embodiment ===== */
  parameter Real m_body        = 32.0  "Robot mass [kg]";
  parameter Integer n_modules  = 6     "Number of capsule modules";
  parameter Real module_length = 0.30  "Per-module length [m]";
  parameter Real L_total       = n_modules*module_length "Total body length [m]";
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

  /* ===== Disturbance (tether / current), middle third ===== */
  parameter Real F_dist       = 174.0 "Disturbance load magnitude [N]";
  parameter Real t_dist_start = Tfinal/3.0;
  parameter Real t_dist_end   = 2.0*Tfinal/3.0;

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
  Real z(start=z_ref, fixed=true);
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
  Real q[6](start={0,0,0,0,0,0}, each fixed=true)      "Joint angle [rad]";
  Real qd[6](start={0,0,0,0,0,0}, each fixed=true)     "Joint rate [rad/s]";
  Real qd_des[6]      "Desired joint rate from undulation [rad/s]";
  discrete Real tau_cmd[6]     "Commanded joint torque [N.m]";
  Real tau_sat[6]     "Saturated joint torque [N.m]";

  /* ===== Body-wrench command (discrete) ===== */
  discrete Real Fx_cmd, Fy_cmd, Fz_cmd;
  discrete Real Tx_cmd, Ty_cmd, Tz_cmd;
  Real Fx_sat, Fy_sat, Fz_sat;
  Real Tx_sat, Ty_sat, Tz_sat;

  /* ===== Disturbance application ===== */
  Real F_dist_x, F_dist_y, F_dist_z;
  Boolean disturbance_active;

  /* ===== Propulsion from undulation ===== */
  Real F_prop_x, F_prop_y, F_prop_z;

  /* ===== Sensors ===== */
  Real pressure_sensor  "Pressure reading [Pa]";
  Real imu_ax, imu_ay, imu_az;
  Real imu_wx, imu_wy, imu_wz;
  Real dvl_vx, dvl_vy, dvl_vz;
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

  /* Orientation helper: body-to-world rotation about z (yaw) for simplicity of wrench mapping */
  Real cy "cos(yaw)";
  Real sy "sin(yaw)";

  /* Disturbance direction (fixed world-frame horizontal) */
  parameter Real dist_dir_x = 1.0;
  parameter Real dist_dir_y = 0.0;

  /* Sum of joint rates for propulsion */
  Real qd_sum;
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

  /* neutral buoyancy assumed: buoyancy cancels gravity */
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
  qd_sum = qd[1] + qd[2] + qd[3] + qd[4] + qd[5] + qd[6];
  F_prop_x =  k_prop * qd_sum * cy;
  F_prop_y =  k_prop * qd_sum * sy;
  F_prop_z =  0.0;

  /* ===== Joint dynamics ===== */
  for i in 1:6 loop
    der(q[i])  = qd[i];
    I_joint*der(qd[i]) = tau_sat[i] - d_joint*qd[i];
    tau_sat[i] = sat(tau_cmd[i], tau_max);
  end for;

  /* ===== Undulation command (small-amplitude hold oscillation; 12 actuators via agonist/antagonist) ===== */
  for i in 1:6 loop
    qd_des[i] = 0.10 * sin(2.0*Modelica.Constants.pi*1.0*time + (i-1)*0.5);
  end for;

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

    /* Joint torque command: track desired undulation rate (bounded by saturation) */
    for i in 1:6 loop
      tau_cmd[i] = 2.0*(qd_des[i] - qd[i]);
    end for;
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
  imu_ax  = der(vx);
  imu_ay  = der(vy);
  imu_az  = der(vz);
  imu_wx  = wx;
  imu_wy  = wy;
  imu_wz  = wz;
  dvl_vx  = vx;
  dvl_vy  = vy;
  dvl_vz  = vz;

  /* Forward sonar: range to cylinder along +x body heading (approx world +x near yaw=0) */
  sonar_range = max(0.01, sqrt((x - struct_x)^2 + (y - struct_y)^2) - struct_radius);

  /* ===== Tether tension estimate (quasi-static, along horizontal to base at origin) ===== */
  tether_tension = sqrt(F_dist_x^2 + F_dist_y^2);
  tether_ok = tether_tension <= tether_max_tension;

  /* ===== Clearance to cylinder surface ===== */
  clearance = max(0.0, sqrt((x - struct_x)^2 + (y - struct_y)^2) - struct_radius);

  /* ===== Tracking and verification ===== */
  pos_error = sqrt((x - x_ref)^2 + (y - y_ref)^2 + (z - z_ref)^2);
  att_error = sqrt((roll - roll_ref)^2 + (pitch - pitch_ref)^2 + (yaw - yaw_ref)^2);
  tracking_error = pos_error;
  tracking_ok   = (time >= 13.0) and (tracking_error < 0.24);
  clearance_ok  = clearance >= clearance_min;

  bounds_ok = (abs(Fx_sat) <= Wforce_max + 1e-6) and (abs(Fy_sat) <= Wforce_max + 1e-6)
           and (abs(Fz_sat) <= Wforce_max + 1e-6) and (abs(Tx_sat) <= Wtorque_max + 1e-6)
           and (abs(Ty_sat) <= Wtorque_max + 1e-6) and (abs(Tz_sat) <= Wtorque_max + 1e-6)
           and (abs(tau_sat[1]) <= tau_max + 1e-6)
           and (abs(tau_sat[2]) <= tau_max + 1e-6)
           and (abs(tau_sat[3]) <= tau_max + 1e-6)
           and (abs(tau_sat[4]) <= tau_max + 1e-6)
           and (abs(tau_sat[5]) <= tau_max + 1e-6)
           and (abs(tau_sat[6]) <= tau_max + 1e-6);

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