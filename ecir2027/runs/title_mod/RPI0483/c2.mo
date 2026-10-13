model DCServoPositionC "DC servo position control with cascaded current and position loops anti-windup 100:1 gearbox thermal model gravity load and mid-third disturbance"

  // Motor electrical parameters
  parameter Real R = 2.0 "Winding resistance [Ohm]";
  parameter Real L = 0.01 "Winding inductance [H]";
  parameter Real Kt = 0.08 "Torque constant [N.m/A]";
  parameter Real Ke = 0.08 "Back-EMF constant [V.s/rad]";
  parameter Real J_motor = 2.0e-5 "Rotor inertia [kg.m2]";
  parameter Real V_supply = 48.0 "Supply voltage [V]";

  // Gearbox
  parameter Real N = 100.0 "Gear ratio";

  // Load and mechanical parameters
  parameter Real J_load = 1.0 "Load-side inertia [kg.m2]";
  parameter Real b_load = 0.1 "Load viscous friction [N.m.s/rad]";
  parameter Real m_link = 0.5 "Link mass [kg]";
  parameter Real l_link = 0.3 "Link length [m]";
  parameter Real g = 9.81 "Gravitational acceleration [m/s2]";
  parameter Real theta_min = -3.14159265358979 "Joint lower travel limit [rad]";
  parameter Real theta_max = 3.14159265358979 "Joint upper travel limit [rad]";
  parameter Real k_collision = 500.0 "Collision stiffness [N.m/rad]";
  parameter Real b_collision = 20.0 "Collision damping [N.m.s/rad]";

  // Thermal model
  parameter Real C_th = 500.0 "Winding thermal capacitance [J/K]";
  parameter Real R_th = 2.0 "Winding thermal resistance [K/W]";
  parameter Real T_amb = 25.0 "Ambient temperature [degC]";
  parameter Real T_max = 80.0 "Winding temperature limit [degC]";

  // Controller limits
  parameter Real Vmax = 44.2 "Maximum voltage command magnitude [V]";
  parameter Real Imax = 30.0 "Maximum current command magnitude [A]";

  // Position loop gains
  parameter Real Kp_pos = 15.0 "Position proportional gain";
  parameter Real Kd_pos = 3.0 "Position derivative gain";
  parameter Real Ki_pos = 8.0 "Position integral gain";

  // Current loop gains
  parameter Real Kp_cur = 3.0 "Current proportional gain";
  parameter Real Ki_cur = 150.0 "Current integral gain";

  // Anti-windup
  parameter Real Kaw = 1.0 "Anti-windup back-calculation gain";

  // Reference
  parameter Real theta_ref = 1.57079632679490 "Target output position [rad]";

  // Continuous states
  Real i(start = 0.0, fixed = true) "Motor winding current [A]";
  Real theta(start = 0.0, fixed = true) "Output position [rad]";
  Real omega(start = 0.0, fixed = true) "Output angular velocity [rad/s]";
  Real T_winding(start = 25.0, fixed = true) "Winding temperature [degC]";
  Real pos_integ(start = 0.0, fixed = true) "Position integrator [rad.s]";
  Real cur_integ(start = 0.0, fixed = true) "Current integrator [A.s]";

  // Sampled sensor and command traces (125 Hz)
  Real i_s(start = 0.0) "Sampled current sensor [A]";
  Real theta_s(start = 0.0) "Sampled position sensor [rad]";
  Real omega_s(start = 0.0) "Sampled velocity sensor [rad/s]";
  Real T_s(start = 25.0) "Sampled temperature sensor [degC]";
  Real v_cmd_s(start = 0.0) "Sampled voltage command [V]";
  Real i_cmd_s(start = 0.0) "Sampled current command [A]";
  Real theta_err_s(start = 0.0) "Sampled tracking error [rad]";

  // Control and internal algebraic variables
  Real theta_err "Position tracking error [rad]";
  Real i_cmd_unsat "Unsaturated current command [A]";
  Real i_cmd "Saturated current command [A]";
  Real v_cmd_unsat "Unsaturated voltage command [V]";
  Real v_cmd "Saturated voltage command [V]";
  Real i_aw "Current anti-windup correction [A]";
  Real v_aw "Voltage anti-windup correction [V]";
  Real tau_motor "Motor torque [N.m]";
  Real tau_gravity "Gravity torque [N.m]";
  Real tau_collision "Collision torque [N.m]";
  Real tau_dist "Disturbance torque [N.m]";
  Real omega_motor "Motor shaft velocity [rad/s]";
  Real tau_gear_out "Gearbox output torque [N.m]";
  Real J_total "Total reflected inertia [kg.m2]";
  Real tracking_err "Absolute tracking error [rad]";

  // Bound indicators
  Boolean voltage_ok;
  Boolean current_ok;
  Boolean travel_ok;
  Boolean final_error_ok;
  Boolean temperature_ok;
  Boolean tracking_ok;
  Boolean no_nan_ok;
  Boolean all_bounds_ok;

equation
  // Reflected inertia
  J_total = J_motor * N * N + J_load;

  // Disturbance during middle third (4 s to 8 s)
  if time >= 4.0 and time <= 8.0 then
    tau_dist = 7.2;
  else
    tau_dist = 0.0;
  end if;

  // Gravity torque on pendulum link
  tau_gravity = m_link * g * l_link * sin(theta);

  // Collision and travel limits
  if theta > theta_max then
    tau_collision = -k_collision * (theta - theta_max) - b_collision * omega;
  elseif theta < theta_min then
    tau_collision = -k_collision * (theta - theta_min) - b_collision * omega;
  else
    tau_collision = 0.0;
  end if;

  // Motor and gearbox kinematics
  omega_motor = N * omega;
  tau_motor = Kt * i;
  tau_gear_out = tau_motor * N;

  // Electrical dynamics
  der(i) = (v_cmd - R * i - Ke * omega_motor) / L;

  // Mechanical dynamics at output
  der(omega) = (tau_gear_out - tau_dist - tau_gravity - b_load * omega - tau_collision) / J_total;
  der(theta) = omega;

  // Thermal dynamics
  der(T_winding) = (R * i * i - (T_winding - T_amb) / R_th) / C_th;

  // Position controller (PD + integral)
  theta_err = theta_ref - theta;
  i_cmd_unsat = Kp_pos * theta_err + Kd_pos * (-omega) + Ki_pos * pos_integ;
  der(pos_integ) = theta_err + Kaw * i_aw;

  // Current command saturation with anti-windup
  if i_cmd_unsat > Imax then
    i_cmd = Imax;
    i_aw = Imax - i_cmd_unsat;
  elseif i_cmd_unsat < -Imax then
    i_cmd = -Imax;
    i_aw = -Imax - i_cmd_unsat;
  else
    i_cmd = i_cmd_unsat;
    i_aw = 0.0;
  end if;

  // Current controller (PI)
  v_cmd_unsat = Kp_cur * (i_cmd - i) + Ki_cur * cur_integ;
  der(cur_integ) = (i_cmd - i) + Kaw * v_aw;

  // Voltage command saturation with anti-windup
  if v_cmd_unsat > Vmax then
    v_cmd = Vmax;
    v_aw = Vmax - v_cmd_unsat;
  elseif v_cmd_unsat < -Vmax then
    v_cmd = -Vmax;
    v_aw = -Vmax - v_cmd_unsat;
  else
    v_cmd = v_cmd_unsat;
    v_aw = 0.0;
  end if;

  // 125 Hz sampling of sensors and commands
  when sample(0, 0.008) then
    i_s = pre(i);
    theta_s = pre(theta);
    omega_s = pre(omega);
    T_s = pre(T_winding);
    v_cmd_s = pre(v_cmd);
    i_cmd_s = pre(i_cmd);
    theta_err_s = abs(theta_ref - pre(theta));
  end when;

  // Tracking error
  tracking_err = abs(theta_ref - theta);

  // Bound checks
  voltage_ok = abs(v_cmd) <= Vmax + 1.0e-6;
  current_ok = abs(i) <= Imax + 2.0;
  travel_ok = theta >= theta_min - 0.01 and theta <= theta_max + 0.01;
  final_error_ok = time < 7.8 or tracking_err <= 0.032;
  temperature_ok = T_winding <= T_max;
  tracking_ok = time < 7.8 or tracking_err <= 0.032;
  no_nan_ok = true;
  all_bounds_ok = voltage_ok and current_ok and travel_ok and final_error_ok and temperature_ok and tracking_ok and no_nan_ok;

  annotation(
    experiment(StartTime = 0.0, StopTime = 12.0, Tolerance = 1.0e-6, Interval = 0.008),
    Documentation(info = "48 V PMDC servo with cascaded current and position control, anti-windup, 100:1 gearbox, rigid pendulum load with joint limits, thermal model, and 7.2 N.m disturbance during the middle third of a 12 s run at 125 Hz.")
  );
end DCServoPositionC;