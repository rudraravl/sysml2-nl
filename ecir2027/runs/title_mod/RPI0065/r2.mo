model TiltWingDeliverE
  "Free-base tilt-wing delivery robot with suspended payload, sensors, controller, and fail-closed acceptance."

  // Scenario timing and sampling
  parameter Real Ts(unit="s") = 1.0/250.0 "controller and trace sample period";
  parameter Real tFinal(unit="s") = 16.0 "simulation duration";
  parameter Integer N = 4001 "number of synchronized trace slots";

  // Physical constants and plant structure
  parameter Real g(unit="m/s2") = 9.81 "gravitational acceleration";
  parameter Real m_fuselage(unit="kg") = 6.2 "capsule fuselage mass";
  parameter Real m_payload(unit="kg") = 2.0 "payload mass; not stated in requirement, selected feasible placeholder";
  parameter Real m_eff(unit="kg") = m_fuselage + m_payload "effective translational mass used by controller feedforward";
  parameter Real rotor_arm(unit="m") = 0.62 "rotor distance from fuselage center";
  parameter Real wing_span(unit="m") = 1.8 "wing span";
  parameter Real cable_length(unit="m") = 1.0 "cable length; not stated, selected to allow ground placement without fuselage strike";
  parameter Real I_pitch(unit="kg.m2") = 1.0 "pitch inertia; not stated, selected placeholder";
  parameter Real pitch_damp(unit="N.m.s/rad") = 2.0 "pitch damping; not stated, selected placeholder";

  // Rotor and tilt bounds
  parameter Real Tmax(unit="N") = 57.2 "per-rotor thrust command and actuation bound";
  parameter Real alpha_min(unit="rad") = 0.0 "minimum rotor tilt joint travel";
  parameter Real alpha_max(unit="rad") = 1.57 "maximum rotor tilt joint travel";
  parameter Real tension_limit(unit="N") = 2.0*Tmax "tension bound derived from total thrust bound";

  // Aero and disturbance
  parameter Real dragGain(unit="N.s2/m3") = 6.0 "aerodynamic drag gain per wing span; not stated, selected nonzero";
  parameter Real gustStart(unit="s") = tFinal/3.0 "middle-third gust start";
  parameter Real gustEnd(unit="s") = 2.0*tFinal/3.0 "middle-third gust end";
  parameter Real gustRamp(unit="s") = 0.5 "finite gust ramp time";
  parameter Real gustMagnitude(unit="N") = 9.6 "controlled lateral gust magnitude";

  // Mission geometry
  parameter Real x_target(unit="m") = 5.0 "horizontal translation target";
  parameter Real target_radius(unit="m") = 0.8 "target-zone radius";
  parameter Real z_initial(unit="m") = 2.0 "initial fuselage height";
  parameter Real z_cruise(unit="m") = 2.5 "cruise/lift height";
  parameter Real z_lower(unit="m") = 1.0 "final lowering height";
  parameter Real ground_clearance(unit="m") = 0.1 "minimum fuselage ground clearance";

  // Controller gains
  parameter Real Kp_x(unit="N/m") = 50.0;
  parameter Real Kd_x(unit="N.s/m") = 30.0;
  parameter Real Kp_z(unit="N/m") = 60.0;
  parameter Real Kd_z(unit="N.s/m") = 40.0;
  parameter Real K_swing(unit="N.s/rad") = 20.0 "cable-swing rate damping gain";
  parameter Real K_theta(unit="N/rad") = 10.0 "cable-angle feedback gain";

  // Actuator dynamics
  parameter Real tauThrust(unit="s") = 0.05 "thrust actuator time constant";
  parameter Real tauTilt(unit="s") = 0.1 "tilt actuator time constant";
  parameter Real TL_init(unit="N") = 0.5*(m_fuselage + m_payload)*g "initial hover thrust per rotor";

  // Continuous plant states
  Real x(start=0.0, unit="m") "fuselage horizontal position";
  Real z(start=z_initial, unit="m") "fuselage vertical position";
  Real vx(start=0.0, unit="m/s") "fuselage horizontal velocity";
  Real vz(start=0.0, unit="m/s") "fuselage vertical velocity";
  Real q(start=0.0, unit="rad") "fuselage pitch angle";
  Real qd(start=0.0, unit="rad/s") "fuselage pitch rate";
  Real theta(start=0.0, unit="rad") "cable angle from vertical";
  Real theta_d(start=0.0, unit="rad/s") "cable angular rate";
  Real TL(start=TL_init, unit="N") "left rotor actual thrust";
  Real TR(start=TL_init, unit="N") "right rotor actual thrust";
  Real alphaL(start=0.0, unit="rad") "left rotor actual tilt";
  Real alphaR(start=0.0, unit="rad") "right rotor actual tilt";

  // Reference trajectories
  Real x_ref(unit="m") "shaped horizontal position reference";
  Real z_ref(unit="m") "shaped vertical position reference";
  Real vx_ref(unit="m/s") "shaped horizontal velocity reference";
  Real vz_ref(unit="m/s") "shaped vertical velocity reference";
  Real ax_ref(unit="m/s2") "shaped horizontal acceleration reference";
  Real az_ref(unit="m/s2") "shaped vertical acceleration reference";

  // Plant forces and accelerations
  Real FxL(unit="N") "left rotor horizontal thrust component";
  Real FzL(unit="N") "left rotor vertical thrust component";
  Real FxR(unit="N") "right rotor horizontal thrust component";
  Real FzR(unit="N") "right rotor vertical thrust component";
  Real Fx_total(unit="N") "total rotor horizontal force";
  Real Fz_total(unit="N") "total rotor vertical force";
  Real drag_x(unit="N") "aerodynamic drag in x";
  Real drag_z(unit="N") "aerodynamic drag in z";
  Real gustForce(unit="N") "finite lateral gust force";
  Real gustShape "dimensionless gust shape";
  Real Fnet_x(unit="N") "net fuselage horizontal force";
  Real Fnet_z(unit="N") "net fuselage vertical force";
  Real ax(unit="m/s2") "fuselage horizontal acceleration";
  Real az(unit="m/s2") "fuselage vertical acceleration";
  Real pitch_torque(unit="N.m") "net pitch torque";
  Real theta_dd(unit="rad/s2") "cable angular acceleration";
  Real B "tension intermediate variable";
  Real den "tension denominator";
  Real den_safe "tension denominator with zero-error branch";
  Real tension_raw(unit="N") "cable tension before slack clamp";
  Real tension(unit="N") "cable tension, nonnegative";

  // Payload
  Real payload_x(unit="m") "payload horizontal position";
  Real payload_z(unit="m") "payload vertical position";

  // Sensors
  Real gps_x(unit="m") "GPS horizontal position";
  Real gps_z(unit="m") "GPS vertical position";
  Real imu_acc_x(unit="m/s2") "IMU horizontal acceleration";
  Real imu_acc_z(unit="m/s2") "IMU vertical acceleration";
  Real imu_gyro_y(unit="rad/s") "IMU pitch rate";
  Real cable_angle_meas(unit="rad") "cable angle measurement";
  Real cable_rate_meas(unit="rad/s") "cable angular rate measurement";
  Real tension_meas(unit="N") "cable tension measurement";

  // Estimator
  discrete Real est_x(start=0.0, unit="m") "estimated horizontal position";
  discrete Real est_z(start=z_initial, unit="m") "estimated vertical position";
  discrete Real est_vx(start=0.0, unit="m/s") "estimated horizontal velocity";
  discrete Real est_vz(start=0.0, unit="m/s") "estimated vertical velocity";
  discrete Real gps_x_prev(start=0.0, unit="m") "previous GPS x";
  discrete Real gps_z_prev(start=z_initial, unit="m") "previous GPS z";

  // Controller commands
  discrete Real cmd_TL(start=TL_init, unit="N") "left rotor thrust command";
  discrete Real cmd_TR(start=TL_init, unit="N") "right rotor thrust command";
  discrete Real cmd_alphaL(start=0.0, unit="rad") "left tilt command";
  discrete Real cmd_alphaR(start=0.0, unit="rad") "right tilt command";
  Real Fx_des(unit="N") "desired horizontal force";
  Real Fz_des(unit="N") "desired vertical force";
  Real T_total_des(unit="N") "desired total thrust";
  Real T_total_cmd(unit="N") "bounded total thrust command";
  Real alpha_des(unit="rad") "desired tilt";

  // Acceptance
  Real primary_tracking_error(unit="m") "fuselage position tracking error";
  Boolean thrust_ok;
  Boolean tension_ok;
  Boolean swing_ok;
  Boolean tilt_ok;
  Boolean no_ground_strike;
  Boolean tracking_ok;
  Boolean finite_ok;
  Boolean early_ok;
  Boolean target_zone_placement;
  output Boolean violation(start=false) "fail-closed violation latch";
  output Boolean acceptance(start=false) "fail-closed acceptance";

  // Synchronized traces at 250 Hz
  discrete Integer k(start=0);
  discrete Real trace_time[N](each start=0.0) "time, s";
  discrete Real trace_state_x[N](each start=0.0) "fuselage x, m";
  discrete Real trace_state_z[N](each start=0.0) "fuselage z, m";
  discrete Real trace_state_vx[N](each start=0.0) "fuselage vx, m/s";
  discrete Real trace_state_vz[N](each start=0.0) "fuselage vz, m/s";
  discrete Real trace_state_theta[N](each start=0.0) "cable angle, rad";
  discrete Real trace_state_theta_d[N](each start=0.0) "cable rate, rad/s";
  discrete Real trace_state_TL[N](each start=TL_init) "left thrust, N";
  discrete Real trace_state_TR[N](each start=TL_init) "right thrust, N";
  discrete Real trace_state_alphaL[N](each start=0.0) "left tilt, rad";
  discrete Real trace_state_alphaR[N](each start=0.0) "right tilt, rad";
  discrete Real trace_cmd_TL[N](each start=TL_init) "left thrust command, N";
  discrete Real trace_cmd_TR[N](each start=TL_init) "right thrust command, N";
  discrete Real trace_cmd_alphaL[N](each start=0.0) "left tilt command, rad";
  discrete Real trace_cmd_alphaR[N](each start=0.0) "right tilt command, rad";
  discrete Real trace_sensor_gps_x[N](each start=0.0) "GPS x, m";
  discrete Real trace_sensor_gps_z[N](each start=0.0) "GPS z, m";
  discrete Real trace_sensor_imu_acc_x[N](each start=0.0) "IMU ax, m/s2";
  discrete Real trace_sensor_imu_acc_z[N](each start=0.0) "IMU az, m/s2";
  discrete Real trace_sensor_cable_angle[N](each start=0.0) "cable angle sensor, rad";
  discrete Real trace_sensor_tension[N](each start=0.0) "tension sensor, N";

equation
  // Shaped position references
  x_ref = x_target*smoothstep((time - 1.0)/4.0);
  vx_ref = x_target*dsmoothstep((time - 1.0)/4.0)/4.0;
  ax_ref = x_target*d2smoothstep((time - 1.0)/4.0)/(4.0*4.0);

  z_ref = z_initial + (z_cruise - z_initial)*smoothstep((time - 0.5)/1.5)
          - (z_cruise - z_lower)*smoothstep((time - 10.0)/4.0);
  vz_ref = (z_cruise - z_initial)*dsmoothstep((time - 0.5)/1.5)/1.5
           - (z_cruise - z_lower)*dsmoothstep((time - 10.0)/4.0)/4.0;
  az_ref = (z_cruise - z_initial)*d2smoothstep((time - 0.5)/1.5)/(1.5*1.5)
           - (z_cruise - z_lower)*d2smoothstep((time - 10.0)/4.0)/(4.0*4.0);

  // Rotor force components in world frame
  FxL = TL*sin(alphaL - q);
  FzL = TL*cos(alphaL - q);
  FxR = TR*sin(alphaR - q);
  FzR = TR*cos(alphaR - q);
  Fx_total = FxL + FxR;
  Fz_total = FzL + FzR;

  // Aerodynamic drag using wing span
  drag_x = -dragGain*wing_span*noEvent(vx*abs(vx));
  drag_z = -dragGain*wing_span*noEvent(vz*abs(vz));

  // Finite middle-third lateral gust, opposing translation as a controlled disturbance
  gustShape = smoothstep((time - gustStart)/gustRamp) - smoothstep((time - gustEnd)/gustRamp);
  gustForce = -gustMagnitude*gustShape;

  // Pitch dynamics and torque from rotor vertical components at rotor arms
  pitch_torque = rotor_arm*(TR*cos(alphaR - q) - TL*cos(alphaL - q));
  der(q) = qd;
  der(qd) = (pitch_torque - pitch_damp*qd)/I_pitch;

  // Cable tension solved explicitly to avoid algebraic loop
  B = (Fz_total - m_fuselage*g + drag_z)*cos(theta)/m_fuselage
      - (Fx_total + drag_x + gustForce)*sin(theta)/m_fuselage
      + cable_length*theta_d*theta_d
      + g*cos(theta);
  den = 1.0 + (m_payload/m_fuselage)*cos(2.0*theta);
  den_safe = if den > 1.0e-6 then den else 1.0e-6;
  tension_raw = m_payload*B/den_safe;
  tension = noEvent(if tension_raw < 0.0 then 0.0 else tension_raw);

  // Fuselage translational dynamics with cable force on fuselage
  Fnet_x = Fx_total + drag_x + gustForce - tension*sin(theta);
  Fnet_z = Fz_total - m_fuselage*g + drag_z - tension*cos(theta);
  ax = Fnet_x/m_fuselage;
  az = Fnet_z/m_fuselage;
  der(x) = vx;
  der(z) = vz;
  der(vx) = ax;
  der(vz) = az;

  // Pendulum payload dynamics
  theta_dd = -(ax*cos(theta) + az*sin(theta))/cable_length - (g/cable_length)*sin(theta);
  der(theta) = theta_d;
  der(theta_d) = theta_dd;

  // Payload kinematics
  payload_x = x + cable_length*sin(theta);
  payload_z = z - cable_length*cos(theta);

  // Sensors
  gps_x = x;
  gps_z = z;
  imu_acc_x = ax;
  imu_acc_z = az;
  imu_gyro_y = qd;
  cable_angle_meas = theta;
  cable_rate_meas = theta_d;
  tension_meas = tension;

  // Actuator dynamics
  der(TL) = (cmd_TL - TL)/tauThrust;
  der(TR) = (cmd_TR - TR)/tauThrust;
  der(alphaL) = (cmd_alphaL - alphaL)/tauTilt;
  der(alphaR) = (cmd_alphaR - alphaR)/tauTilt;

  // Tracking and acceptance checks
  primary_tracking_error = sqrt((x - x_ref)*(x - x_ref) + (z - z_ref)*(z - z_ref));

  thrust_ok = noEvent(TL <= Tmax + 1.0e-6 and TR <= Tmax + 1.0e-6 and
                      TL >= -1.0e-6 and TR >= -1.0e-6 and
                      cmd_TL <= Tmax + 1.0e-6 and cmd_TR <= Tmax + 1.0e-6 and
                      cmd_TL >= -1.0e-6 and cmd_TR >= -1.0e-6);
  tension_ok = noEvent(tension_meas >= -1.0e-6 and tension_meas <= tension_limit + 1.0e-6);
  swing_ok = noEvent(abs(theta) <= 0.45);
  tilt_ok = noEvent(alphaL >= alpha_min - 1.0e-6 and alphaL <= alpha_max + 1.0e-6 and
                    alphaR >= alpha_min - 1.0e-6 and alphaR <= alpha_max + 1.0e-6 and
                    cmd_alphaL >= alpha_min - 1.0e-6 and cmd_alphaL <= alpha_max + 1.0e-6 and
                    cmd_alphaR >= alpha_min - 1.0e-6 and cmd_alphaR <= alpha_max + 1.0e-6);
  no_ground_strike = noEvent(z > ground_clearance and payload_z >= -0.05);
  tracking_ok = noEvent(if time >= 10.4 then primary_tracking_error <= 0.27 else true);
  finite_ok = noEvent(
    abs(x) <= 1.0e9 and abs(z) <= 1.0e9 and abs(vx) <= 1.0e9 and abs(vz) <= 1.0e9 and
    abs(q) <= 1.0e9 and abs(qd) <= 1.0e9 and abs(theta) <= 1.0e9 and abs(theta_d) <= 1.0e9 and
    abs(TL) <= 1.0e9 and abs(TR) <= 1.0e9 and abs(alphaL) <= 1.0e9 and abs(alphaR) <= 1.0e9 and
    abs(cmd_TL) <= 1.0e9 and abs(cmd_TR) <= 1.0e9 and abs(cmd_alphaL) <= 1.0e9 and abs(cmd_alphaR) <= 1.0e9 and
    abs(gps_x) <= 1.0e9 and abs(gps_z) <= 1.0e9 and abs(imu_acc_x) <= 1.0e9 and abs(imu_acc_z) <= 1.0e9 and
    abs(imu_gyro_y) <= 1.0e9 and abs(cable_angle_meas) <= 1.0e9 and abs(cable_rate_meas) <= 1.0e9 and
    abs(tension_meas) <= 1.0e9 and abs(tension_raw) <= 1.0e9 and abs(B) <= 1.0e9 and
    abs(den_safe) >= 1.0e-12 and abs(primary_tracking_error) <= 1.0e9 and
    abs(est_x) <= 1.0e9 and abs(est_z) <= 1.0e9 and abs(est_vx) <= 1.0e9 and abs(est_vz) <= 1.0e9 and
    abs(gustForce) <= 1.0e9 and abs(drag_x) <= 1.0e9 and abs(drag_z) <= 1.0e9
  );
  early_ok = thrust_ok and tension_ok and swing_ok and tilt_ok and no_ground_strike and tracking_ok and finite_ok;
  target_zone_placement = noEvent(time >= tFinal - 0.01 and
                                  abs(payload_x - x_target) <= target_radius and
                                  payload_z <= 0.2 and payload_z >= -0.05);

  // 250 Hz sampled controller, estimator, traces, and fail-closed acceptance
  when sample(0, Ts) then
    // GPS/IMU velocity estimator
    est_x = gps_x;
    est_z = gps_z;
    est_vx = 0.5*(pre(est_vx) + Ts*imu_acc_x) + 0.5*((gps_x - pre(gps_x_prev))/Ts);
    est_vz = 0.5*(pre(est_vz) + Ts*imu_acc_z) + 0.5*((gps_z - pre(gps_z_prev))/Ts);
    gps_x_prev = gps_x;
    gps_z_prev = gps_z;

    // Input-shaped position control with cable-swing damping and tension feedforward
    Fx_des = m_eff*ax_ref + Kp_x*(x_ref - est_x) + Kd_x*(vx_ref - est_vx)
             + K_swing*cable_rate_meas + K_theta*cable_angle_meas;
    Fz_des = m_fuselage*g + tension_meas + m_eff*az_ref
             + Kp_z*(z_ref - est_z) + Kd_z*(vz_ref - est_vz);

    // Thrust and tilt command bounds
    T_total_des = sqrt(Fx_des*Fx_des + Fz_des*Fz_des);
    T_total_cmd = if T_total_des > 2.0*Tmax then 2.0*Tmax
                  elseif T_total_des < 0.0 then 0.0
                  else T_total_des;
    cmd_TL = 0.5*T_total_cmd;
    cmd_TR = 0.5*T_total_cmd;

    alpha_des = atan(Fx_des/(if Fz_des > 1.0 then Fz_des else 1.0));
    cmd_alphaL = if alpha_des < alpha_min then alpha_min
                 elseif alpha_des > alpha_max then alpha_max
                 else alpha_des;
    cmd_alphaR = cmd_alphaL;

    // Fail-closed acceptance latches
    violation = pre(violation) or not early_ok;
    acceptance = (not (pre(violation) or not early_ok)) and
                 (time >= tFinal - 0.01) and target_zone_placement;

    // Synchronized trace retention
    k = if pre(k) + 1 <= N then pre(k) + 1 else N;
    trace_time[k] = time;
    trace_state_x[k] = x;
    trace_state_z[k] = z;
    trace_state_vx[k] = vx;
    trace_state_vz[k] = vz;
    trace_state_theta[k] = theta;
    trace_state_theta_d[k] = theta_d;
    trace_state_TL[k] = TL;
    trace_state_TR[k] = TR;
    trace_state_alphaL[k] = alphaL;
    trace_state_alphaR[k] = alphaR;
    trace_cmd_TL[k] = cmd_TL;
    trace_cmd_TR[k] = cmd_TR;
    trace_cmd_alphaL[k] = cmd_alphaL;
    trace_cmd_alphaR[k] = cmd_alphaR;
    trace_sensor_gps_x[k] = gps_x;
    trace_sensor_gps_z[k] = gps_z;
    trace_sensor_imu_acc_x[k] = imu_acc_x;
    trace_sensor_imu_acc_z[k] = imu_acc_z;
    trace_sensor_cable_angle[k] = cable_angle_meas;
    trace_sensor_tension[k] = tension_meas;
  end when;

  annotation(experiment(StopTime=16, Interval=0.004, Tolerance=1e-4));
end TiltWingDeliverE;