model GliderDiveD
  parameter Real m_total = 60.0 "Total mass including pitch mass [kg]";
  parameter Real m_pitch = 6.0 "Translating internal pitch mass [kg]";
  parameter Real L_hull = 1.8 "Hull length [m]";
  parameter Real A_wing = 0.42 "Wing area [m2]";
  parameter Real rho_sw = 1025.0 "Seawater density [kg/m3]";
  parameter Real g_acc = 9.81 "Gravitational acceleration [m/s2]";
  parameter Real V0 = m_total / rho_sw "Neutral buoyancy volume [m3]";
  parameter Real delta_V_max = 0.001 "Max buoyancy volume change [m3]";
  parameter Real s_p_max = 0.15 "Max pitch mass travel [m]";
  parameter Real I_pitch = 15.0 "Pitch moment of inertia [kg.m2]";
  parameter Real I_roll = 3.0 "Roll moment of inertia [kg.m2]";
  parameter Real d_pitch = 8.0 "Pitch rotational damping [N.m.s/rad]";
  parameter Real d_roll = 5.0 "Roll rotational damping [N.m.s/rad]";
  parameter Real k_z = 5.0 "Vertical quadratic drag coefficient [N.s2/m2]";
  parameter Real k_h = 10.0 "Horizontal quadratic drag coefficient [N.s2/m2]";
  parameter Real F_current = 80.0 "Current force magnitude [N]";
  parameter Real tau_buoy = 0.2 "Buoyancy actuator time constant [s]";
  parameter Real tau_pitch = 0.15 "Pitch mass actuator time constant [s]";
  parameter Real tau_roll = 0.15 "Roll actuator time constant [s]";

  parameter Real Kp_depth = 0.005 "Depth proportional gain [1/m]";
  parameter Real Kd_depth = 0.01 "Depth derivative gain [s/m]";
  parameter Real Ki_depth = 0.0005 "Depth integral gain [1/(m.s)]";
  parameter Real Kp_pitch = 2.0 "Pitch proportional gain [1/rad]";
  parameter Real Kd_pitch = 1.0 "Pitch derivative gain [s/rad]";
  parameter Real theta_cmd_max = 0.3 "Maximum pitch command [rad]";
  parameter Real Kp_heading = 1.5 "Heading proportional gain [1/rad]";
  parameter Real Kd_heading = 0.5 "Heading derivative gain [s/rad]";
  parameter Real Kp_roll = 10.0 "Roll proportional gain [1/rad]";
  parameter Real Kd_roll = 3.0 "Roll derivative gain [s/rad]";
  parameter Real phi_cmd_max = 0.3 "Maximum roll command [rad]";
  parameter Real delta_phi_max = 0.1 "Max roll actuator deflection [rad]";

  parameter Real z_target_deep = 8.0 "Deep target depth [m]";
  parameter Real z_target_shallow = 3.0 "Shallow target depth [m]";
  parameter Real t_return_start = 10.0 "Return phase start time [s]";
  parameter Real t_curr_start = 14.0 / 3.0 "Current disturbance start [s]";
  parameter Real t_curr_end = 28.0 / 3.0 "Current disturbance end [s]";
  parameter Real z_init = 3.0 "Initial depth [m]";

  Real z "Depth [m], positive downward";
  Real vz "Vertical velocity [m/s], positive downward";
  Real theta "Pitch angle [rad], positive nose-down";
  Real theta_dot "Pitch rate [rad/s]";
  Real phi "Roll angle [rad]";
  Real phi_dot "Roll rate [rad/s]";
  Real psi "Heading [rad]";
  Real psi_dot "Heading rate [rad/s]";
  Real x_horiz "Horizontal position [m]";
  Real vx "Horizontal velocity [m/s]";
  Real delta_V "Buoyancy volume change [m3], positive upward";
  Real s_p "Pitch mass position [m], positive forward";
  Real delta_phi "Roll actuator deflection [rad]";
  Real depth_err_int "Depth error integral [m.s]";

  Real z_cmd "Depth command [m]";
  Real psi_cmd "Heading command [rad]";
  Real theta_cmd "Pitch command [rad]";
  Real s_p_cmd "Pitch mass command [m]";
  Real delta_V_cmd "Buoyancy command [m3]";
  Real phi_cmd "Roll command [rad]";
  Real delta_phi_cmd "Roll actuator command [rad]";
  Real delta_V_cmd_sat "Saturated buoyancy command [m3]";
  Real s_p_cmd_sat "Saturated pitch mass command [m]";
  Real delta_phi_cmd_sat "Saturated roll actuator command [rad]";

  Real F_buoy "Net buoyancy force [N], positive downward";
  Real F_drag_z "Vertical drag force [N]";
  Real F_drag_h "Horizontal drag force [N]";
  Real F_curr "Current force [N]";
  Real M_pitch "Pitch moment [N.m]";
  Real M_roll "Roll moment [N.m]";

  Real tracking_error "Primary tracking error [m]";
  Real z_meas "Measured depth [m]";
  Real vz_meas "Measured vertical velocity [m/s]";
  Real theta_meas "Measured pitch [rad]";
  Real phi_meas "Measured roll [rad]";
  Real psi_meas "Measured heading [rad]";
  Real vx_meas "Measured horizontal velocity [m/s]";

  Real err "Depth error [m], positive = too deep";
  Real vz_switch "Switching velocity threshold [m/s]";

initial equation
  z = z_init;
  vz = 0.0;
  theta = 0.0;
  theta_dot = 0.0;
  phi = 0.0;
  phi_dot = 0.0;
  psi = 0.0;
  psi_dot = 0.0;
  x_horiz = 0.0;
  vx = 0.0;
  delta_V = 0.0;
  s_p = 0.0;
  delta_phi = 0.0;
  depth_err_int = 0.0;

equation
  // Mission command generation
  z_cmd = if time < t_return_start then z_target_deep else z_target_shallow;
  psi_cmd = 0.0;

  // Current disturbance: 80 N during middle third of 14 s
  F_curr = if time > t_curr_start and time < t_curr_end then F_current else 0.0;

  // Forces
  F_buoy = -rho_sw * delta_V * g_acc;
  F_drag_z = k_z * vz * abs(vz);
  F_drag_h = k_h * vx * abs(vx);

  // Depth dynamics (positive z downward)
  m_total * der(vz) = F_buoy - F_drag_z;
  der(z) = vz;

  // Horizontal dynamics
  m_total * der(vx) = F_curr - F_drag_h;
  der(x_horiz) = vx;

  // Pitch dynamics from internal pitch mass
  M_pitch = m_pitch * g_acc * s_p * cos(theta);
  I_pitch * der(theta_dot) = M_pitch - d_pitch * theta_dot;
  der(theta) = theta_dot;

  // Roll dynamics from roll actuator
  M_roll = m_pitch * g_acc * delta_phi * 0.3;
  I_roll * der(phi_dot) = M_roll - d_roll * phi_dot;
  der(phi) = phi_dot;

  // Heading dynamics coupled to roll and current disturbance
  der(psi_dot) = -0.5 * psi_dot + 0.3 * phi + 0.005 * F_curr / max(m_total, 1.0);
  der(psi) = psi_dot;

  // Depth controller: switching-curve bang-bang with PD near target
  err = z - z_cmd;
  vz_switch = sqrt(max(2.0 * (exp(min(abs(err) / 6.0, 10.0)) - 1.0), 0.0));

  delta_V_cmd = if abs(err) < 0.3 then
                  Kp_depth * err + Kd_depth * vz + Ki_depth * depth_err_int
                elseif err < 0.0 and vz < vz_switch then
                  -delta_V_max
                elseif err < 0.0 then
                  delta_V_max
                elseif err > 0.0 and vz > -vz_switch then
                  delta_V_max
                else
                  -delta_V_max;

  // Integral with anti-windup (only near target)
  der(depth_err_int) = if abs(err) < 0.5 then err else 0.0;

  // Cascaded depth -> pitch command
  theta_cmd = max(min(0.05 * (z_cmd - z), theta_cmd_max), -theta_cmd_max);

  // Pitch controller: PD on pitch error -> pitch mass command
  s_p_cmd = Kp_pitch * (theta_cmd - theta) + Kd_pitch * (-theta_dot);

  // Heading controller: PD on heading error -> roll command
  phi_cmd = max(min(Kp_heading * (psi_cmd - psi) - Kd_heading * psi_dot, phi_cmd_max), -phi_cmd_max);

  // Roll controller: PD on roll error -> roll actuator command
  delta_phi_cmd = Kp_roll * (phi_cmd - phi) + Kd_roll * (-phi_dot);

  // Actuator saturation (bounded allocation)
  delta_V_cmd_sat = max(min(delta_V_cmd, delta_V_max), -delta_V_max);
  s_p_cmd_sat = max(min(s_p_cmd, s_p_max), -s_p_max);
  delta_phi_cmd_sat = max(min(delta_phi_cmd, delta_phi_max), -delta_phi_max);

  // First-order actuator dynamics
  der(delta_V) = (delta_V_cmd_sat - delta_V) / tau_buoy;
  der(s_p) = (s_p_cmd_sat - s_p) / tau_pitch;
  der(delta_phi) = (delta_phi_cmd_sat - delta_phi) / tau_roll;

  // Sensors: pressure depth, IMU attitude, Doppler velocity
  z_meas = z;
  vz_meas = vz;
  theta_meas = theta;
  phi_meas = phi;
  psi_meas = psi;
  vx_meas = vx;

  // Primary tracking error
  tracking_error = abs(z - z_cmd);

annotation (
  experiment(StartTime = 0, StopTime = 14.0, Tolerance = 1e-6, Interval = 0.005),
  Documentation(info = "GliderDiveD: Instrumented free-base marine robot.
    60 kg, 1.8 m streamlined capsule hull, 0.42 m2 wing area.
    Variable-buoyancy unit (0.001 m3 max change) and 6 kg translating pitch mass.
    Seawater density 1025 kg/m3. Gravity, buoyancy, quadratic drag modeled.
    Mission: descend to 8 m, hold depth and zero heading, return to 3 m.
    80 N current force during middle third. 200 Hz, 14 s.
    Cascaded depth and attitude control with bounded allocation.
    Note: With 10 N max buoyancy force on 60 kg, full return to 3 m within
    14 s is not physically achievable. The glider ascends toward 3 m
    and makes partial progress after the return command at t=10 s.")
);
end GliderDiveD;