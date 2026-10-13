model AUVHoldB
  // ---- Requirement-specified facts ----
  parameter Real m_hull(unit="kg") = 85 "hull mass";
  parameter Real L_hull(unit="m") = 1.5 "hull length";
  parameter Real V_disp(unit="m3") = 0.083 "displaced volume in seawater";
  parameter Real f_thr_max(unit="N") = 90.2 "allowed command magnitude per thruster";
  parameter Real F_tether_inject(unit="N") = 84 "tether/current load disturbance";
  parameter Real f_sample(unit="Hz") = 100 "control and trace rate";
  parameter Real t_end(unit="s") = 10 "mission duration";
  parameter Real e_bound(unit="m") = 0.36 "primary tracking error bound";
  parameter Real t_check(unit="s") = 6.5 "time after which bound applies";

  // ---- Constants and inferred/placeholder physical parameters ----
  constant Real eps = 1e-9 "zero-error guard for norms and divisors";
  parameter Real g_n(unit="m/s2") = 9.80665 "standard gravity";
  // Seawater density is not stated in the requirement. The value below is inferred
  // only from the given mass and displaced volume so that the model is runnable.
  parameter Real rho_sw(unit="kg/m3") = m_hull/V_disp;
  // Hull inertia is not specified; a slender-rod placeholder using only given
  // mass and length is used for a runnable 6-DOF placeholder.
  parameter Real Ixx(unit="kg.m2") = m_hull*L_hull^2/12;
  parameter Real Iyy(unit="kg.m2") = Ixx;
  parameter Real Izz(unit="kg.m2") = Ixx;
  // Thruster moment arms are not specified; a placeholder using hull length is used.
  parameter Real d_thr(unit="m") = L_hull/4;
  // Offshore structure geometry is not specified. These placeholder values are used
  // only to instantiate a fixed collidable cylinder with a finite clearance.
  parameter Real R_struct(unit="m") = L_hull/3 "placeholder cylinder radius";
  parameter Real H_struct(unit="m") = L_hull*10 "placeholder cylinder height";
  parameter Real x_struct(unit="m") = R_struct + L_hull "cylinder center x";
  parameter Real y_struct(unit="m") = 0 "cylinder center y";
  parameter Real z_struct_center(unit="m") = 0 "cylinder center z";
  parameter Real k_contact(unit="N/m") = 1e5 "placeholder contact stiffness";
  parameter Real d_contact(unit="N.s/m") = 1e4 "placeholder contact damping";
  // Tether limit is not specified; total actuator capacity is used as a placeholder limit.
  parameter Real tether_limit(unit="N") = 4*f_thr_max;

  // ---- Mission setpoint ----
  parameter Real x_set(unit="m") = 0;
  parameter Real y_set(unit="m") = 0;
  parameter Real z_set(unit="m") = 0;
  parameter Real phi_set(unit="rad") = 0;
  parameter Real theta_set(unit="rad") = 0;
  parameter Real psi_set(unit="rad") = 0;

  // ---- Controller gains (tunable; chosen for runnable stable station keeping) ----
  parameter Real Kp_xy(unit="N/m") = 800;
  parameter Real Kd_xy(unit="N.s/m") = 200;
  parameter Real Kp_z(unit="N/m") = 800;
  parameter Real Kd_z(unit="N.s/m") = 200;
  parameter Real Kp_phi(unit="N.m/rad") = 40;
  parameter Real Kd_phi(unit="N.m.s/rad") = 20;
  parameter Real Kp_theta(unit="N.m/rad") = 40;
  parameter Real Kd_theta(unit="N.m.s/rad") = 20;
  parameter Real Kp_psi(unit="N.m/rad") = 60;
  parameter Real Kd_psi(unit="N.m.s/rad") = 20;

  // ---- Timing ----
  parameter Real dt(unit="s") = 1/f_sample;
  parameter Real t_start_dist(unit="s") = t_end/3;
  parameter Real t_stop_dist(unit="s") = 2*t_end/3;

  // ---- Continuous state variables ----
  Real x(start=0, fixed=true, unit="m");
  Real y(start=0, fixed=true, unit="m");
  Real z(start=0, fixed=true, unit="m");
  Real vx(start=0, fixed=true, unit="m/s");
  Real vy(start=0, fixed=true, unit="m/s");
  Real vz(start=0, fixed=true, unit="m/s");
  Real phi(start=0, fixed=true, unit="rad");
  Real theta(start=0, fixed=true, unit="rad");
  Real psi(start=0, fixed=true, unit="rad");
  Real p_rate(start=0, fixed=true, unit="rad/s");
  Real q_rate(start=0, fixed=true, unit="rad/s");
  Real r_rate(start=0, fixed=true, unit="rad/s");

  // ---- Discrete controller commands and traces ----
  discrete Real f_surge_port(start=0, unit="N");
  discrete Real f_surge_stbd(start=0, unit="N");
  discrete Real f_heave_fore(start=0, unit="N");
  discrete Real f_heave_aft(start=0, unit="N");
  discrete Real Fwx_des(start=0, unit="N");
  discrete Real Fwy_des(start=0, unit="N");
  discrete Real Fwz_des(start=0, unit="N");
  discrete Real Fx_des(start=0, unit="N");
  discrete Real Fy_des(start=0, unit="N");
  discrete Real Fz_des(start=0, unit="N");
  discrete Real tau_x_des(start=0, unit="N.m");
  discrete Real tau_y_des(start=0, unit="N.m");
  discrete Real tau_z_des(start=0, unit="N.m");
  discrete Real trace_time(start=0, unit="s");
  discrete Real state_trace[12] "synchronized sampled state trace";
  discrete Real command_trace[4] "synchronized sampled command trace";
  discrete Real sensor_trace[11] "synchronized sampled sensor trace";

  // ---- Derived kinematic and dynamic variables ----
  Real ex_c(unit="m") = x_set - x;
  Real ey_c(unit="m") = y_set - y;
  Real ez_c(unit="m") = z_set - z;
  Real ephi_c(unit="rad") = phi_set - phi;
  Real etheta_c(unit="rad") = theta_set - theta;
  Real epsi_c(unit="rad") = psi_set - psi;

  // Rotation matrix body to world (ZYX Euler: yaw=psi, pitch=theta, roll=phi)
  Real R11 = cos(psi)*cos(theta);
  Real R12 = cos(psi)*sin(theta)*sin(phi) - sin(psi)*cos(phi);
  Real R13 = cos(psi)*sin(theta)*cos(phi) + sin(psi)*sin(phi);
  Real R21 = sin(psi)*cos(theta);
  Real R22 = sin(psi)*sin(theta)*sin(phi) + cos(psi)*cos(phi);
  Real R23 = sin(psi)*sin(theta)*cos(phi) - cos(psi)*sin(phi);
  Real R31 = -sin(theta);
  Real R32 = cos(theta)*sin(phi);
  Real R33 = cos(theta)*cos(phi);

  // Actual actuated body forces/torques from saturated thruster commands
  Real Fx_act(unit="N") = f_surge_port + f_surge_stbd;
  Real Fz_act(unit="N") = f_heave_fore + f_heave_aft;
  Real Ty_act(unit="N.m") = -d_thr*(f_heave_fore - f_heave_aft);
  Real Tz_act(unit="N.m") = d_thr*(f_surge_port - f_surge_stbd);
  Real tau_x(unit="N.m") = 0;
  Real tau_y(unit="N.m") = Ty_act;
  Real tau_z(unit="N.m") = Tz_act;

  // Thruster force expressed in world frame
  Real Fwx(unit="N") = R11*Fx_act + R13*Fz_act;
  Real Fwy(unit="N") = R21*Fx_act + R23*Fz_act;
  Real Fwz(unit="N") = R31*Fx_act + R33*Fz_act;

  // Tether/current disturbance: middle third, 84 N along +x toward structure
  Real tether_load(unit="N") = if time >= t_start_dist and time <= t_stop_dist then F_tether_inject else 0;
  Real F_dist_x(unit="N") = tether_load;
  Real F_dist_y(unit="N") = 0;
  Real F_dist_z(unit="N") = 0;

  // Buoyancy and weight
  Real F_buoy_z(unit="N") = rho_sw*g_n*V_disp;
  Real F_weight_z(unit="N") = -m_hull*g_n;
  Real F_net_buoy_z(unit="N") = F_buoy_z + F_weight_z;

  // Fixed collidable cylinder clearance and contact
  Real dist_horiz(unit="m") = sqrt(max((x - x_struct)^2 + (y - y_struct)^2, eps));
  Real clearance(unit="m") = dist_horiz - R_struct;
  Real clearance_rate(unit="m/s") = ((x - x_struct)*vx + (y - y_struct)*vy)/dist_horiz;
  Boolean vertical_inside = abs(z - z_struct_center) <= H_struct/2;
  Real F_contact_mag(unit="N") = if clearance < 0 and vertical_inside then (-k_contact*clearance - d_contact*clearance_rate) else 0;
  Real F_contact_x(unit="N") = ((x - x_struct)/dist_horiz)*F_contact_mag;
  Real F_contact_y(unit="N") = ((y - y_struct)/dist_horiz)*F_contact_mag;
  Real F_contact_z(unit="N") = 0;

  // Linear accelerations
  Real ax(unit="m/s2") = (Fwx + F_dist_x + F_contact_x)/m_hull;
  Real ay(unit="m/s2") = (Fwy + F_dist_y + F_contact_y)/m_hull;
  Real az(unit="m/s2") = (Fwz + F_net_buoy_z + F_dist_z + F_contact_z)/m_hull;

  // Sensors
  Real depth(unit="m") = max(-z, 0);
  Real p_sensor(unit="Pa") = rho_sw*g_n*depth "gauge pressure";
  Real dvl_vx(unit="m/s") = R11*vx + R21*vy + R31*vz;
  Real dvl_vy(unit="m/s") = R12*vx + R22*vy + R32*vz;
  Real dvl_vz(unit="m/s") = R13*vx + R23*vy + R33*vz;
  Real imu_ax(unit="m/s2") = R11*ax + R21*ay + R31*az;
  Real imu_ay(unit="m/s2") = R12*ax + R22*ay + R32*az;
  Real imu_az(unit="m/s2") = R13*ax + R23*ay + R33*az;

  // Forward sonar: range along body x-axis to vertical cylinder
  Real ray_dx = R11;
  Real ray_dy = R21;
  Real A_ray = ray_dx^2 + ray_dy^2;
  Real B_ray = 2*((x - x_struct)*ray_dx + (y - y_struct)*ray_dy);
  Real C_ray = (x - x_struct)^2 + (y - y_struct)^2 - R_struct^2;
  Real disc_ray = B_ray^2 - 4*A_ray*C_ray;
  Real root_ray(unit="m") = if A_ray > eps and disc_ray > 0 then (-B_ray - sqrt(disc_ray))/(2*A_ray) else 0;
  Real sonar_range(unit="m") = if root_ray > 0 then root_ray else 0;

  // Observable body wrench
  Real wrench_Fx(unit="N") = Fx_act;
  Real wrench_Fy(unit="N") = 0;
  Real wrench_Fz(unit="N") = Fz_act;
  Real wrench_Tx(unit="N.m") = 0;
  Real wrench_Ty(unit="N.m") = Ty_act;
  Real wrench_Tz(unit="N.m") = Tz_act;

  // Requirement metrics
  Real pos_error_norm(unit="m") = sqrt(max(ex_c^2 + ey_c^2 + ez_c^2, eps));
  Real att_error_norm(unit="rad") = sqrt(max(ephi_c^2 + etheta_c^2 + epsi_c^2, eps));
  Boolean thruster_bound_ok = abs(f_surge_port) <= f_thr_max + eps and
                             abs(f_surge_stbd) <= f_thr_max + eps and
                             abs(f_heave_fore) <= f_thr_max + eps and
                             abs(f_heave_aft) <= f_thr_max + eps;
  Boolean clearance_ok = clearance >= 0;
  Boolean tether_ok = abs(tether_load) <= tether_limit;
  Boolean primary_error_ok = time <= t_check or pos_error_norm <= e_bound;
  Boolean no_bad_values =
    abs(x) < 1e6 and abs(y) < 1e6 and abs(z) < 1e6 and
    abs(vx) < 1e3 and abs(vy) < 1e3 and abs(vz) < 1e3 and
    abs(phi) < 3.15 and abs(theta) < 3.15 and abs(psi) < 3.15 and
    abs(p_rate) < 1e3 and abs(q_rate) < 1e3 and abs(r_rate) < 1e3 and
    abs(Fx_act) < 1e9 and abs(Fz_act) < 1e9 and abs(Ty_act) < 1e9 and abs(Tz_act) < 1e9 and
    abs(f_surge_port) < 1e9 and abs(f_surge_stbd) < 1e9 and abs(f_heave_fore) < 1e9 and abs(f_heave_aft) < 1e9 and
    abs(p_sensor) < 1e9 and abs(sonar_range) < 1e9 and abs(dvl_vx) < 1e3 and abs(dvl_vy) < 1e3 and abs(dvl_vz) < 1e3 and
    abs(imu_ax) < 1e6 and abs(imu_ay) < 1e6 and abs(imu_az) < 1e6 and
    abs(tether_load) < 1e9 and abs(trace_time) < 1e9 and
    abs(pos_error_norm) < 1e9 and abs(att_error_norm) < 1e9;

equation
  // Translational dynamics
  der(vx) = ax;
  der(vy) = ay;
  der(vz) = az;
  der(x) = vx;
  der(y) = vy;
  der(z) = vz;

  // Euler kinematics
  der(phi) = p_rate + q_rate*sin(phi)*tan(theta) + r_rate*cos(phi)*tan(theta);
  der(theta) = q_rate*cos(phi) - r_rate*sin(phi);
  der(psi) = (q_rate*sin(phi) + r_rate*cos(phi))/cos(theta);

  // Rotational dynamics
  der(p_rate) = (tau_x + (Iyy - Izz)*q_rate*r_rate)/Ixx;
  der(q_rate) = (tau_y + (Izz - Ixx)*p_rate*r_rate)/Iyy;
  der(r_rate) = (tau_z + (Ixx - Iyy)*p_rate*q_rate)/Izz;

  // 100 Hz bounded body-wrench station-keeping controller and synchronized traces
  when sample(0, dt) then
    trace_time = time;
    state_trace = {x, y, z, vx, vy, vz, phi, theta, psi, p_rate, q_rate, r_rate};
    command_trace = {f_surge_port, f_surge_stbd, f_heave_fore, f_heave_aft};
    sensor_trace = {p_sensor, dvl_vx, dvl_vy, dvl_vz, imu_ax, imu_ay, imu_az, p_rate, q_rate, r_rate, sonar_range};

    // World-frame PD station-keeping force
    Fwx_des = Kp_xy*(x_set - x) - Kd_xy*vx;
    Fwy_des = Kp_xy*(y_set - y) - Kd_xy*vy;
    Fwz_des = Kp_z*(z_set - z) - Kd_z*vz;

    // Transform desired world force to body frame
    Fx_des = R11*Fwx_des + R21*Fwy_des + R31*Fwz_des;
    Fy_des = R12*Fwx_des + R22*Fwy_des + R32*Fwz_des;
    Fz_des = R13*Fwx_des + R23*Fwy_des + R33*Fwz_des;

    // Body-frame attitude PD torques
    tau_x_des = Kp_phi*(phi_set - phi) - Kd_phi*p_rate;
    tau_y_des = Kp_theta*(theta_set - theta) - Kd_theta*q_rate;
    tau_z_des = Kp_psi*(psi_set - psi) - Kd_psi*r_rate;

    // Allocation to two surge and two heave bidirectional thrusters with per-thruster bounds
    f_surge_port = max(-f_thr_max, min(f_thr_max, 0.5*(Fx_des + tau_z_des/d_thr)));
    f_surge_stbd = max(-f_thr_max, min(f_thr_max, 0.5*(Fx_des - tau_z_des/d_thr)));
    f_heave_fore = max(-f_thr_max, min(f_thr_max, 0.5*(Fz_des - tau_y_des/d_thr)));
    f_heave_aft = max(-f_thr_max, min(f_thr_max, 0.5*(Fz_des + tau_y_des/d_thr)));
  end when;

  // Requirement enforcement
  assert(no_bad_values, "NaN/infinite/excessive physical, control, or estimator values");
  assert(thruster_bound_ok, "thruster bound violated");
  assert(clearance_ok, "structure clearance violated");
  assert(tether_ok, "tether limit violated");
  assert(primary_error_ok, "primary tracking error bound violated after 6.5 s");

  annotation(experiment(StopTime=10, Interval=0.01, Tolerance=1e-6));
end AUVHoldB;