model QuadScoutDeliverE
  // ================= Parameters =================
  parameter Real M_fuselage = 1.8 "fuselage mass [kg]";
  parameter Real m_payload = 0.4 "payload mass [kg] (design choice; not specified in request)";
  parameter Real L_cable = 1.0 "cable length [m] (design choice; not specified in request)";
  parameter Real arm_length = 0.22 "rotor arm length [m]";
  parameter Real T_max_per_rotor = 13.2 "max thrust per rotor [N]";
  parameter Real g = 9.81 "gravity [m/s2]";
  parameter Real cd_drag = 0.2 "aero drag coefficient [N.s/m] (design choice; not specified)";
  parameter Real I_pitch = 0.02 "pitch inertia [kg.m2] (design choice; not specified)";
  parameter Real I_yaw = 0.02 "yaw inertia [kg.m2] (design choice; not specified)";
  parameter Real k_yaw_moment = 0.05 "yaw moment coefficient [N.m/N] (design choice; not specified)";
  parameter Real k_att_p = 8.0 "attitude proportional gain";
  parameter Real k_att_d = 1.2 "attitude derivative gain";
  parameter Real k_pos_p = 3.0 "position proportional gain";
  parameter Real k_pos_d = 2.5 "position derivative gain";
  parameter Real k_swing_p = 3.0 "cable swing proportional damping gain";
  parameter Real k_swing_d = 0.6 "cable swing derivative damping gain";
  parameter Real k_yaw_p = 2.0 "yaw proportional gain";
  parameter Real k_yaw_d = 0.5 "yaw derivative gain";
  parameter Real Ts = 0.004 "control sample period [s] (250 Hz)";
  parameter Real z_start = 1.05 "initial hover height [m] (design choice; not specified)";
  parameter Real z_hover = 2.5 "cruise hover height [m] (design choice; not specified)";
  parameter Real z_final = 1.05 "delivery hover height [m] (design choice; not specified)";
  parameter Real x_target = 5.0 "horizontal translation target [m]";
  parameter Real F_gust_amp = 9.6 "gust force amplitude [N]";
  parameter Real T_tension_bound = 2.0*(M_fuselage + m_payload)*g
    "tension upper bound [N] (design choice; not specified in request)";

  // ================= Continuous states =================
  Real x_q(start=0.0) "quad x position [m]";
  Real z_q(start=1.05) "quad z position [m]";
  Real vx_q(start=0.0) "quad x velocity [m/s]";
  Real vz_q(start=0.0) "quad z velocity [m/s]";
  Real theta(start=0.0) "pitch angle [rad]";
  Real theta_dot(start=0.0) "pitch rate [rad/s]";
  Real psi(start=0.0) "yaw angle [rad]";
  Real psi_dot(start=0.0) "yaw rate [rad/s]";
  Real phi(start=0.0) "cable angle from vertical [rad]";
  Real phi_dot(start=0.0) "cable angular rate [rad/s]";

  // ================= Algebraic variables =================
  Real ax_q "quad x acceleration [m/s2]";
  Real az_q "quad z acceleration [m/s2]";
  Real A1 "pendulum intermediate term [m/s2]";
  Real A2 "pendulum intermediate term [m/s2]";
  Real phiddot "cable angular acceleration [rad/s2]";
  Real T_c "cable tension [N]";
  Real T_total "total rotor thrust [N]";
  Real M_pitch "pitch moment [N.m]";
  Real M_yaw "yaw moment [N.m]";
  Real F_gust "applied gust force [N]";
  Real cosPhiSafe "guarded cos(phi) used as divisor";
  Real payload_x "payload x position [m]";
  Real payload_z "payload z position [m]";

  // ================= Discrete controller variables =================
  discrete Real t1(start=5.4) "rotor 1 thrust [N]";
  discrete Real t2(start=5.4) "rotor 2 thrust [N]";
  discrete Real t3(start=5.4) "rotor 3 thrust [N]";
  discrete Real t4(start=5.4) "rotor 4 thrust [N]";
  discrete Real x_sp(start=0.0) "x setpoint [m]";
  discrete Real z_sp(start=1.05) "z setpoint [m]";
  discrete Real vx_sp(start=0.0) "x velocity setpoint [m/s]";
  discrete Real vz_sp(start=0.0) "z velocity setpoint [m/s]";
  discrete Real theta_sp(start=0.0) "pitch setpoint [rad]";
  discrete Real T_total_cmd(start=21.58) "commanded total thrust [N]";
  discrete Real M_pitch_cmd(start=0.0) "commanded pitch moment [N.m]";
  discrete Real M_yaw_cmd(start=0.0) "commanded yaw moment [N.m]";
  discrete Real ax_des(start=0.0) "desired x acceleration [m/s2]";
  discrete Real az_des(start=0.0) "desired z acceleration [m/s2]";
  discrete Real Fx_thrust(start=0.0) "thrust force component x [N]";
  discrete Real Fz_thrust(start=21.58) "thrust force component z [N]";
  discrete Real t_front_avg(start=5.4) "front pair average thrust [N]";
  discrete Real t_rear_avg(start=5.4) "rear pair average thrust [N]";
  discrete Real dyaw(start=0.0) "yaw differential thrust [N]";

  // ================= Sensors =================
  Real gps_x, gps_z, gps_vx, gps_vz;
  Real imu_ax, imu_az, imu_q;
  Real cable_angle_meas, cable_tension_meas;

  // ================= Estimator =================
  Real x_est, z_est, vx_est, vz_est, phi_est, phi_dot_est, theta_est, theta_dot_est;

  // ================= Acceptance =================
  Real tracking_error;
  Real target_dist;
  discrete Real max_err_after_104(start=0.0);
  discrete Real min_payload_z(start=1.0e9);
  discrete Real max_abs_swing(start=0.0);
  discrete Real max_tension(start=0.0);
  discrete Real max_thrust_per_rotor(start=0.0);
  Boolean ok_thrust, ok_tension, ok_swing, ok_target, ok_no_ground, ok_tracking, ok_finite, accept;

protected
  function smoothStep "smoothstep 0->1 for s in [0,1]"
    input Real s;
    output Real y;
  algorithm
    if s <= 0.0 then
      y := 0.0;
    elseif s >= 1.0 then
      y := 1.0;
    else
      y := 3.0*s*s - 2.0*s*s*s;
    end if;
  end smoothStep;

  function smoothStepDer "derivative of smoothstep"
    input Real s;
    output Real y;
  algorithm
    if s <= 0.0 or s >= 1.0 then
      y := 0.0;
    else
      y := 6.0*s*(1.0 - s);
    end if;
  end smoothStepDer;

equation
  // ===== Payload kinematics =====
  payload_x = x_q + L_cable*sin(phi);
  payload_z = z_q - L_cable*cos(phi);

  // ===== Gust: middle third of 16 s window (5.333..10.667 s), 9.6 N lateral =====
  F_gust = F_gust_amp * smoothStep((time - 5.333)/0.5) * smoothStep((10.667 - time)/0.5);

  // ===== Quadrotor translational dynamics =====
  M_fuselage*ax_q = T_total*sin(theta) - cd_drag*vx_q + F_gust + T_c*sin(phi);
  M_fuselage*az_q = T_total*cos(theta) - M_fuselage*g - cd_drag*vz_q - T_c*cos(phi);
  der(x_q) = vx_q;
  der(z_q) = vz_q;
  der(vx_q) = ax_q;
  der(vz_q) = az_q;

  // ===== Cable pendulum dynamics (accelerating pivot) =====
  A1 = ax_q - L_cable*sin(phi)*phi_dot*phi_dot;
  A2 = az_q + L_cable*cos(phi)*phi_dot*phi_dot;
  cosPhiSafe = (if cos(phi) >= 0.0 then max(cos(phi), 1.0e-3) else min(cos(phi), -1.0e-3));
  phiddot = -(sin(phi)*(A2 + g) + cos(phi)*A1)/L_cable;
  T_c*cosPhiSafe = m_payload*(A2 + L_cable*sin(phi)*phiddot + g);
  der(phi) = phi_dot;
  der(phi_dot) = phiddot;

  // ===== Attitude dynamics =====
  I_pitch*der(theta_dot) = M_pitch - 0.3*theta_dot;
  der(theta) = theta_dot;
  I_yaw*der(psi_dot) = M_yaw - 0.3*psi_dot;
  der(psi) = psi_dot;

  // ===== Thrust allocation from four independent rotor thrusts =====
  T_total = t1 + t2 + t3 + t4;
  M_pitch = arm_length*((t3 + t4) - (t1 + t2));
  M_yaw = k_yaw_moment*((t2 + t4) - (t1 + t3));

  // ===== Sensors =====
  gps_x = x_q;
  gps_z = z_q;
  gps_vx = vx_q;
  gps_vz = vz_q;
  imu_ax = ax_q;
  imu_az = az_q + g "specific force includes reaction to gravity";
  imu_q = theta_dot;
  cable_angle_meas = phi;
  cable_tension_meas = T_c;

  // ===== Estimator (noise-free fusion of IMU/GPS/cable sensors) =====
  x_est = gps_x;
  z_est = gps_z;
  vx_est = gps_vx;
  vz_est = gps_vz;
  phi_est = cable_angle_meas;
  phi_dot_est = phi_dot;
  theta_est = theta;
  theta_dot_est = imu_q;

  // ===== Tracking error and target distance =====
  tracking_error = sqrt((x_q - x_sp)^2 + (z_q - z_sp)^2);
  target_dist = sqrt((payload_x - x_target)^2 + (payload_z - 0.0)^2);

  // ===== Sampled controller and acceptance latches at 250 Hz =====
  when sample(0.0, Ts) then
    // Input-shaped trajectory setpoints
    if time <= 1.0 then
      x_sp = 0.0;
      z_sp = z_start;
      vx_sp = 0.0;
      vz_sp = 0.0;
    elseif time <= 4.0 then
      x_sp = 0.0;
      z_sp = z_start + (z_hover - z_start)*smoothStep((time - 1.0)/3.0);
      vx_sp = 0.0;
      vz_sp = (z_hover - z_start)*smoothStepDer((time - 1.0)/3.0)/3.0;
    elseif time <= 11.0 then
      x_sp = x_target*smoothStep((time - 4.0)/7.0);
      z_sp = z_hover;
      vx_sp = x_target*smoothStepDer((time - 4.0)/7.0)/7.0;
      vz_sp = 0.0;
    elseif time <= 13.0 then
      x_sp = x_target;
      z_sp = z_hover + (z_final - z_hover)*smoothStep((time - 11.0)/2.0);
      vx_sp = 0.0;
      vz_sp = (z_final - z_hover)*smoothStepDer((time - 11.0)/2.0)/2.0;
    else
      x_sp = x_target;
      z_sp = z_final;
      vx_sp = 0.0;
      vz_sp = 0.0;
    end if;

    // Position control with cable-swing damping
    ax_des = k_pos_p*(x_sp - x_est) + k_pos_d*(vx_sp - vx_est)
           + k_swing_p*phi_est + k_swing_d*phi_dot_est;
    az_des = k_pos_p*(z_sp - z_est) + k_pos_d*(vz_sp - vz_est);

    // Feedforward thrust accounting for cable load and aerodynamic drag
    Fx_thrust = M_fuselage*ax_des + cd_drag*vx_est - cable_tension_meas*sin(phi_est);
    Fz_thrust = M_fuselage*(g + az_des) + cd_drag*vz_est + cable_tension_meas*cos(phi_est);
    theta_sp = atan2(Fx_thrust, Fz_thrust);
    T_total_cmd = sqrt(Fx_thrust*Fx_thrust + Fz_thrust*Fz_thrust);

    // Attitude and yaw commands
    M_pitch_cmd = k_att_p*(theta_sp - theta_est) - k_att_d*theta_dot_est;
    M_yaw_cmd = k_yaw_p*(0.0 - psi) - k_yaw_d*psi_dot;

    // Allocation to four independently commanded rotors
    t_front_avg = T_total_cmd/4.0 - M_pitch_cmd/(4.0*arm_length);
    t_rear_avg = T_total_cmd/4.0 + M_pitch_cmd/(4.0*arm_length);
    dyaw = M_yaw_cmd/(4.0*k_yaw_moment);
    t1 = max(0.0, min(T_max_per_rotor, t_front_avg - dyaw));
    t2 = max(0.0, min(T_max_per_rotor, t_front_avg + dyaw));
    t3 = max(0.0, min(T_max_per_rotor, t_rear_avg - dyaw));
    t4 = max(0.0, min(T_max_per_rotor, t_rear_avg + dyaw));

    // Acceptance latches (fail-closed: track worst case across run)
    max_err_after_104 = if (time >= 10.4) then max(pre(max_err_after_104), tracking_error) else pre(max_err_after_104);
    min_payload_z = min(pre(min_payload_z), payload_z);
    max_abs_swing = max(pre(max_abs_swing), abs(phi));
    max_tension = max(pre(max_tension), T_c);
    max_thrust_per_rotor = max(pre(max_thrust_per_rotor), max({t1, t2, t3, t4}));
  end when;

  // ===== Acceptance evaluation (fail-closed) =====
  ok_thrust = max_thrust_per_rotor <= T_max_per_rotor + 1.0e-6;
  ok_tension = (max_tension <= T_tension_bound) and (max_tension >= 0.0);
  ok_swing = max_abs_swing < 0.45;
  ok_target = target_dist < 0.8;
  ok_no_ground = min_payload_z >= -1.0e-6;
  ok_tracking = max_err_after_104 < 0.27;
  ok_finite = (abs(x_q) < 1.0e5) and (abs(z_q) < 1.0e5) and (abs(vx_q) < 1.0e5)
            and (abs(vz_q) < 1.0e5) and (abs(theta) < 100.0) and (abs(psi) < 100.0)
            and (abs(phi) < 10.0) and (abs(T_total) < 1.0e4) and (abs(T_c) < 1.0e4)
            and (abs(M_pitch) < 1.0e4) and (abs(M_yaw) < 1.0e4)
            and (abs(t1) < 1.0e4) and (abs(t2) < 1.0e4) and (abs(t3) < 1.0e4) and (abs(t4) < 1.0e4)
            and (abs(x_est) < 1.0e5) and (abs(vx_est) < 1.0e5);
  accept = (time >= 16.0) and ok_thrust and ok_tension and ok_swing
         and ok_target and ok_no_ground and ok_tracking and ok_finite;

  annotation(
    experiment(StartTime=0.0, StopTime=16.0, Tolerance=1e-6),
    Documentation(info="QuadScoutDeliverE: verifiable free-base quadrotor slung-load delivery scenario. "
                       "Lifts a suspended payload, translates 5 m horizontally into a 0.8 m-radius target zone, "
                       "and lowers it under input-shaped position control with cable-swing damping. "
                       "Applies gravity, aerodynamic drag, and a 9.6 N lateral gust during the middle third. "
                       "Synchronized state, command, and sensor traces retained via discrete 250 Hz sampling.")
  );
end QuadScoutDeliverE;