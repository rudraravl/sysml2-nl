model TiltWingTouchA
  /* Free-base planar tilt-wing aerial robot model.
     Unknown geometric/inertial/contact values not stated in the request are
     marked "assumed" and selected only to make the model executable. */

  // Stated physical parameters
  parameter Real m = 6.2 "capsule fuselage mass";
  parameter Real d_rotor = 0.62 "rotor distance from center";
  parameter Real wingSpan = 1.8 "wing span";
  parameter Real gammaMin = 0.0 "rotor tilt joint lower travel";
  parameter Real gammaMax = 1.57 "rotor tilt joint upper travel";
  parameter Real T_max = 37.4 "per-rotor command magnitude limit";
  parameter Real Ts = 1.0/80.0 "control and trace sample period";
  parameter Real tEnd = 8.0 "scenario duration";
  parameter Real windForce = 1.5 "tangential wind disturbance";
  parameter Real windStart = 8.0/3.0 "middle third start";
  parameter Real windEnd = 16.0/3.0 "middle third end";
  parameter Real preContactStart = 5.5 "control transition to impedance/force mode";
  parameter Real contactStart = 6.0 "last quarter contact-hold start";
  parameter Real mu_wall = 0.55 "wall friction coefficient";

  // Assumed model values required for executable dynamics
  parameter Real g = 9.81 "gravity";
  parameter Real I_pitch = 0.25 "assumed pitch inertia";
  parameter Real wallX = 0.0 "fixed vertical inspection surface plane";
  parameter Real L_probe = 0.25 "assumed probe length";
  parameter Real k_contact = 220.0 "assumed normal contact stiffness";
  parameter Real d_contact = 25.0 "assumed normal contact damping";
  parameter Real F_contact_des = 9.0 "desired bounded normal probe force";
  parameter Real xPreRef = L_probe + 0.01 "pre-contact stand-off reference";
  parameter Real xContactRef = L_probe - F_contact_des/k_contact "contact reference";
  parameter Real z_ref = 1.0 "vertical reference";
  parameter Real vApproachMax = 0.15 "assumed approach speed bound";
  parameter Real vZmax = 0.15 "assumed vertical command speed bound";
  parameter Real thetaMax = 0.35 "assumed attitude bound";
  parameter Real fanRadius = 0.10 "assumed fan radius for collision check";
  parameter Real Kp_x = 25.0 "normal position gain";
  parameter Real Kd_x = 12.0 "normal velocity gain";
  parameter Real Kx = 0.5 "normal speed command gain";
  parameter Real Kp_z = 20.0 "vertical position gain";
  parameter Real Kd_z = 10.0 "vertical velocity gain";
  parameter Real Kz = 0.5 "vertical speed command gain";
  parameter Real Kp_theta = 10.0 "pitch attitude gain";
  parameter Real Kd_theta = 5.0 "pitch rate gain";
  parameter Real Kf = 1.0 "probe force feedback gain";
  parameter Real FxSat = 30.0 "horizontal desired force saturation";
  parameter Real MSat = 10.0 "pitch moment saturation";
  parameter Real tauThrust = 0.02 "assumed thrust actuator time constant";
  parameter Real tauTilt = 0.05 "assumed tilt actuator time constant";
  parameter Real vSmall = 0.01 "friction velocity smoothing";
  parameter Real eps = 1.0e-6 "monitor tolerance";

  // Physical states
  Real x(start=0.90, fixed=true) "normal stand-off from wall";
  Real z(start=1.0, fixed=true) "vertical position";
  Real theta(start=0.0, fixed=true) "pitch attitude";
  Real vx(start=0.0, fixed=true) "normal velocity";
  Real vz(start=0.0, fixed=true) "vertical velocity";
  Real q(start=0.0, fixed=true) "pitch rate";

  // Actuator states
  Real T1_raw(start=m*g/2.0, fixed=true) "rotor 1 thrust state";
  Real T2_raw(start=m*g/2.0, fixed=true) "rotor 2 thrust state";
  Real gamma1_raw(start=0.0, fixed=true) "rotor 1 tilt state";
  Real gamma2_raw(start=0.0, fixed=true) "rotor 2 tilt state";

  // Actuated quantities
  Real T1_actual "rotor 1 thrust";
  Real T2_actual "rotor 2 thrust";
  Real gamma1 "rotor 1 tilt angle";
  Real gamma2 "rotor 2 tilt angle";

  // Contact and environment
  Real penetration "probe penetration into wall";
  Real F_contact_normal "normal probe contact force on robot";
  Real F_friction_z "wall tangential friction force on robot";
  Real F_wind_z "controlled tangential wind disturbance";
  Boolean windActive "middle third wind window";
  Boolean contactPhase "position-to-impedance transition active";
  Boolean lastQuarter "last quarter contact-hold window";

  // Physical rotor forces and moments
  Real Fbx "body-frame horizontal force";
  Real Fby "body-frame vertical force";
  Real Fx_phys "world-frame horizontal force";
  Real Fz_phys "world-frame vertical force";
  Real M_phys "pitch moment";

  // Command traces
  discrete Real t_log(start=0.0) "synchronized sample time trace";
  discrete Real x_ref(start=0.26) "normal position reference";
  discrete Real F_contact_ff(start=0.0) "contact force feedforward";
  discrete Real v_cmd(start=0.0) "normal velocity command";
  discrete Real vz_cmd(start=0.0) "vertical velocity command";
  discrete Real Fx_des(start=0.0) "desired horizontal force";
  discrete Real Fz_des(start=m*g) "desired vertical force";
  discrete Real M_des(start=0.0) "desired pitch moment";
  discrete Real gamma_cmd(start=0.0) " commanded rotor tilt";
  discrete Real T1_cmd(start=m*g/2.0) "rotor 1 thrust command";
  discrete Real T2_cmd(start=m*g/2.0) "rotor 2 thrust command";
  discrete Real gamma1_cmd(start=0.0) "rotor 1 tilt command";
  discrete Real gamma2_cmd(start=0.0) "rotor 2 tilt command";

  // Sensor and estimator traces
  Real lidar_range "lidar range to wall";
  Real optical_flow_x "optical flow horizontal velocity estimate";
  Real optical_flow_z "optical flow vertical velocity estimate";
  Real imu_pitch "IMU pitch estimate";
  Real imu_gyro "IMU pitch-rate estimate";
  Real imu_accel_x "IMU horizontal acceleration estimate";
  Real imu_accel_z "IMU vertical acceleration estimate";
  Real probe_force_normal "probe normal force sensor";
  Real probe_force_tangential "probe tangential force sensor";
  Boolean est_contact "probe contact estimate";
  Real est_x "estimated normal position";
  Real est_z "estimated vertical position";
  Real est_vx "estimated normal velocity";
  Real est_vz "estimated vertical velocity";
  Real est_theta "estimated pitch";

  // Requirement monitors
  Real trackingError "primary normal tracking error";
  Real standOff "normal stand-off distance";
  Boolean trackingOK;
  Boolean thrustBoundOK;
  Boolean attitudeBoundOK;
  Boolean approachSpeedOK;
  Boolean contactForceOK;
  Boolean noFanCollision;
  Boolean rotorWithinWing;
  Boolean finiteValuesOK;

protected
  discrete Real e_x, e_z, Fx_pos, Fx_ff, Fbx_cmd, Fby_cmd, T_cmd_local, T_scale, Fbx_s, Fby_s, T_avg, dT;

equation
  // Environment windows
  windActive = time >= windStart and time <= windEnd;
  contactPhase = time >= preContactStart;
  lastQuarter = time >= contactStart;

  // Actuator dynamics with saturation
  der(T1_raw) = (T1_cmd - T1_raw)/tauThrust;
  T1_actual = max(0.0, min(T_max, T1_raw));
  der(T2_raw) = (T2_cmd - T2_raw)/tauThrust;
  T2_actual = max(0.0, min(T_max, T2_raw));

  der(gamma1_raw) = (gamma1_cmd - gamma1_raw)/tauTilt;
  gamma1 = max(gammaMin, min(gammaMax, gamma1_raw));
  der(gamma2_raw) = (gamma2_cmd - gamma2_raw)/tauTilt;
  gamma2 = max(gammaMin, min(gammaMax, gamma2_raw));

  // Fixed collidable wall with friction
  penetration = max(0.0, L_probe - (x - wallX));
  F_contact_normal = if penetration > 0.0 then max(0.0, k_contact*penetration - d_contact*vx) else 0.0;
  F_friction_z = -mu_wall*F_contact_normal*tanh(vz/vSmall);
  F_wind_z = if windActive then -windForce else 0.0;

  // Rotor forces in body frame
  Fbx = -T1_actual*sin(gamma1) - T2_actual*sin(gamma2);
  Fby = T1_actual*cos(gamma1) + T2_actual*cos(gamma2);

  // Transform to world frame
  Fx_phys = Fbx*cos(theta) - Fby*sin(theta);
  Fz_phys = Fbx*sin(theta) + Fby*cos(theta);

  // Pitch moment from differential thrust
  M_phys = d_rotor*(T1_actual*cos(gamma1) - T2_actual*cos(gamma2));

  // Rigid-body dynamics
  der(x) = vx;
  der(z) = vz;
  der(theta) = q;
  m*der(vx) = Fx_phys + F_contact_normal;
  m*der(vz) = Fz_phys - m*g + F_friction_z + F_wind_z;
  I_pitch*der(q) = M_phys;

  // Sensors and estimator
  lidar_range = max(0.0, x - wallX);
  optical_flow_x = vx;
  optical_flow_z = vz;
  imu_pitch = theta;
  imu_gyro = q;
  imu_accel_x = (Fx_phys + F_contact_normal)/m;
  imu_accel_z = (Fz_phys - m*g + F_friction_z + F_wind_z)/m;
  probe_force_normal = F_contact_normal;
  probe_force_tangential = F_friction_z;
  est_contact = F_contact_normal > 0.01;
  est_x = x;
  est_z = z;
  est_vx = vx;
  est_vz = vz;
  est_theta = theta;

  // Requirement traces and monitors
  trackingError = abs(x - x_ref);
  standOff = x - wallX;
  trackingOK = if time >= 5.2 then trackingError < 0.054 else true;
  thrustBoundOK = T1_cmd <= T_max + eps and T2_cmd <= T_max + eps and T1_cmd >= -eps and T2_cmd >= -eps;
  attitudeBoundOK = abs(theta) <= thetaMax;
  approachSpeedOK = abs(vx) <= vApproachMax + eps;
  contactForceOK = if time >= contactStart then F_contact_normal >= 5.0 and F_contact_normal <= 14.0 else true;
  noFanCollision = (x - fanRadius) > wallX + eps;
  rotorWithinWing = d_rotor <= wingSpan/2.0;

  finiteValuesOK =
    (x >= -1.0e6 and x <= 1.0e6) and
    (z >= -1.0e6 and z <= 1.0e6) and
    (theta >= -1.0e6 and theta <= 1.0e6) and
    (vx >= -1.0e6 and vx <= 1.0e6) and
    (vz >= -1.0e6 and vz <= 1.0e6) and
    (q >= -1.0e6 and q <= 1.0e6) and
    (T1_actual >= -1.0e6 and T1_actual <= 1.0e6) and
    (T2_actual >= -1.0e6 and T2_actual <= 1.0e6) and
    (gamma1 >= -1.0e6 and gamma1 <= 1.0e6) and
    (gamma2 >= -1.0e6 and gamma2 <= 1.0e6) and
    (Fx_des >= -1.0e6 and Fx_des <= 1.0e6) and
    (Fz_des >= -1.0e6 and Fz_des <= 1.0e6) and
    (T1_cmd >= -1.0e6 and T1_cmd <= 1.0e6) and
    (T2_cmd >= -1.0e6 and T2_cmd <= 1.0e6) and
    (F_contact_normal >= -1.0e6 and F_contact_normal <= 1.0e6) and
    (lidar_range >= -1.0e6 and lidar_range <= 1.0e6) and
    (optical_flow_x >= -1.0e6 and optical_flow_x <= 1.0e6) and
    (optical_flow_z >= -1.0e6 and optical_flow_z <= 1.0e6) and
    (imu_pitch >= -1.0e6 and imu_pitch <= 1.0e6) and
    (imu_gyro >= -1.0e6 and imu_gyro <= 1.0e6) and
    (imu_accel_x >= -1.0e6 and imu_accel_x <= 1.0e6) and
    (imu_accel_z >= -1.0e6 and imu_accel_z <= 1.0e6) and
    (probe_force_normal >= -1.0e6 and probe_force_normal <= 1.0e6);

algorithm
  when sample(0, Ts) then
    t_log := time;

    // Hybrid reference: position control, then impedance/force regulation
    if time < preContactStart then
      x_ref := xPreRef;
      F_contact_ff := 0.0;
    else
      x_ref := xContactRef;
      F_contact_ff := F_contact_des;
    end if;

    // Normal position-to-speed control
    e_x := x_ref - x;
    v_cmd := max(-vApproachMax, min(vApproachMax, Kx*e_x));
    Fx_pos := Kp_x*e_x + Kd_x*(v_cmd - vx);

    // Impedance/force feedback during contact
    if F_contact_normal > 0.01 then
      Fx_ff := -F_contact_ff - Kf*(F_contact_des - F_contact_normal);
    else
      Fx_ff := -F_contact_ff;
    end if;

    Fx_des := max(-FxSat, min(FxSat, Fx_pos + Fx_ff));

    // Vertical position control with wind feedforward
    e_z := z_ref - z;
    vz_cmd := max(-vZmax, min(vZmax, Kz*e_z));
    Fz_des := max(0.0, min(2.0*T_max, m*g + Kp_z*e_z + Kd_z*(vz_cmd - vz) + (if windActive then windForce else 0.0)));

    // Attitude regulation
    M_des := max(-MSat, min(MSat, -Kp_theta*theta - Kd_theta*q));

    // Map desired world force to rotor thrust magnitude and tilt
    Fbx_cmd := Fx_des*cos(theta) + Fz_des*sin(theta);
    Fby_cmd := -Fx_des*sin(theta) + Fz_des*cos(theta);
    T_cmd_local := sqrt(Fbx_cmd*Fbx_cmd + Fby_cmd*Fby_cmd);
    T_scale := if T_cmd_local > 2.0*T_max then 2.0*T_max/max(T_cmd_local, 1.0e-6) else 1.0;
    Fbx_s := Fbx_cmd*T_scale;
    Fby_s := Fby_cmd*T_scale;

    gamma_cmd := max(gammaMin, min(gammaMax, atan(-Fbx_s/max(Fby_s, 1.0e-6))));
    T_avg := 0.5*sqrt(Fbx_s*Fbx_s + Fby_s*Fby_s);
    dT := M_des/(2.0*d_rotor);

    T1_cmd := max(0.0, min(T_max, T_avg + dT));
    T2_cmd := max(0.0, min(T_max, T_avg - dT));
    gamma1_cmd := gamma_cmd;
    gamma2_cmd := gamma_cmd;
  end when;

  annotation (experiment(StopTime=8.0, Tolerance=1.0e-6, Interval=0.0125));
end TiltWingTouchA;