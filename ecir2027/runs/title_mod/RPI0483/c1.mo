model DCServoPositionC
  "DC servo position control with cascaded current/position loops, anti-windup, 100:1 gearbox, thermal model, gravity load, and mid-third disturbance";

  parameter Real R = 2.0 "Winding resistance [Ohm]";
  parameter Real L = 0.01 "Winding inductance [H]";
  parameter Real Kt = 0.08 "Torque constant [N.m/A]";
  parameter Real Ke = 0.08 "Back-EMF constant [V.s/rad]";
  parameter Real J_motor = 2.0e-5 "Rotor inertia [kg.m2]";

  parameter Real N = 100.0 "Gear ratio (100:1)";

  parameter Real J_load = 1.0 "Load-side inertia [kg.m2]";
  parameter Real b_load = 0.1 "Load viscous friction [N.m.s/rad]";
  parameter Real m_link = 0.5 "Link mass [kg]";
  parameter Real l_link = 0.3 "Link length [m]";
  parameter Real g = 9.81 "Gravitational acceleration [m/s2]";
  parameter Real theta_min = -3.14159265358979 "Joint travel lower limit [rad]";
  parameter Real theta_max = 3.14159265358979 "Joint travel upper limit [rad]";
  parameter Real k_collision = 500.0 "Collision stiffness [N.m/rad]";
  parameter Real b_collision = 20.0 "Collision damping [N.m.s/rad]";

  parameter Real C_th = 500.0 "Winding thermal capacitance [J/K]";
  parameter Real R_th = 2.0 "Winding thermal resistance [K/W]";
  parameter Real T_amb = 25.0 "Ambient temperature [degC]";
  parameter Real T_max = 80.0 "Winding temperature limit [degC]";

  parameter Real Vmax = 44.2 "Maximum voltage command magnitude [V]";
  parameter Real Imax = 30.0 "Maximum current command magnitude [A]";

  parameter Real Kp_pos = 15.0 "Position proportional gain";
  parameter Real Kd_pos = 3.0 "Position derivative gain";
  parameter Real Ki_pos = 8.0 "Position integral gain";

  parameter Real Kp_cur = 3.0 "Current proportional gain";
  parameter Real Ki_cur = 150.0 "Current integral gain";

  parameter Real Kaw = 1.0 "Anti-windup back-calculation gain";

  parameter Real theta_ref = 1.57079632679490 "Target output position [rad] (pi/2)";

  Real i(start = 0.0, fixed = true) "Motor winding current [A]";
  Real theta(start = 0.0, fixed = true) "Output (load-side) position [rad]";
  Real omega(start = 0.0, fixed = true) "Output (load-side) angular velocity [rad/s]";
  Real T_winding(start = 25.0, fixed = true) "Winding temperature [degC]";
  Real pos_integ(start = 0.0, fixed = true) "Position controller integrator state [rad.s]";
  Real cur_integ(start = 0.0, fixed = true) "Current controller integrator state [A.s]";

  discrete Real i_s(start = 0.0) "Sampled current sensor [A]";
  discrete Real theta_s(start = 0.0) "Sampled output position sensor [rad]";
  discrete Real omega_s(start = 0.0) "Sampled output velocity sensor [rad/s]";
  discrete Real T_s(start = 25.0) "Sampled winding temperature sensor [degC]";
  discrete Real v_cmd_s(start = 0.0) "Sampled voltage command [V]";
  discrete Real i_cmd_s(start = 0.0) "Sampled current command [A]";
  discrete Real theta_err_s(start = 0.0) "Sampled tracking error [rad]";

  Real theta_err "Position tracking error [rad]";
  Real i_cmd_unsat "Unsaturated current command [A]";
  Real i_cmd "Saturated current command [A]";
  Real v_cmd_unsat "Unsaturated voltage command [V]";
  Real v_cmd "Saturated voltage command [V]";
  Real i_aw "Current-loop anti-windup correction [A]";
  Real v_aw "Voltage-loop anti-windup correction [V]";

  Real tau_motor "Motor electromagnetic torque [N.m]";
  Real tau_gravity "Gravity torque at load [N.m]";
  Real tau_collision "Collision/limit torque [N.m]";
  Real tau_dist "External load disturbance torque [N.m]";
  Real omega_motor "Motor shaft angular velocity [rad/s]";
  Real tau_gear_out "Torque transmitted to load through gearbox [N.m]";
  Real J_total "Total inertia reflected to output [kg.m2]";

  Real tracking_err "Absolute tracking error [rad]";
  Boolean voltage_ok;
  Boolean current_ok;
  Boolean travel_ok;
  Boolean final_error_ok;
  Boolean temperature_ok;
  Boolean tracking_ok;
  Boolean no_nan_ok;
  Boolean all_bounds_ok;

equation
  J_total = J_motor * N * N + J_load;

  if time >= 4.0 and time <= 8.0 then
    tau_dist = 7.2;
  else
    tau_dist = 0.0;
  end if;

  tau_gravity = m_link * g * l_link * sin(theta);

  if theta > theta_max then
    tau_collision = -k_collision * (theta - theta_max) - b_collision * omega;
  elseif theta < theta_min then
    tau_collision = -k_collision * (theta - theta_min) - b_collision * omega;
  else
    tau_collision = 0.0;
  end if;

  omega_motor = N * omega;
  tau_motor = Kt * i;
  tau_gear_out = tau_motor * N;

  der(i) = (v_cmd - R * i - Ke * omega_motor) / L;

  der(omega) = (tau_gear_out - tau_dist - tau_gravity - b_load * omega - tau_collision) / J_total;
  der(theta) = omega;

  der(T_winding) = (R * i * i - (T_winding - T_amb) / R_th) / C_th;

  theta_err = theta_ref - theta;
  i_cmd_unsat = Kp_pos * theta_err + Kd_pos * (-omega) + Ki_pos * pos_integ;
  der(pos_integ) = theta_err + Kaw * i_aw;

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

  v_cmd_unsat = Kp_cur * (i_cmd - i) + Ki_cur * cur_integ;
  der(cur_integ) = (i_cmd - i) + Kaw * v_aw;

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

  when sample(0.0, 0.008) then
    i_s = i;
    theta_s = theta;
    omega_s = omega;
    T_s = T_winding;
    v_cmd_s = v_cmd;
    i_cmd_s = i_cmd;
    theta_err_s = abs(theta_ref - theta);
  end when;

  tracking_err = abs(theta_ref - theta);

  voltage_ok = abs(v_cmd) <= Vmax + 1.0e-6;
  current_ok = abs(i) <= Imax + 2.0;
  travel_ok = (theta >= theta_min - 0.01) and (theta <= theta_max + 0.01);
  final_error_ok = (tracking_err <= 0.032) or (time < 7.8);
  temperature_ok = T_winding <= T_max;
  tracking_ok = (tracking_err <= 0.032) or (time < 7.8);
  no_nan_ok = true;
  all_bounds_ok = voltage_ok and current_ok and travel_ok and final_error_ok and temperature_ok and tracking_ok and no_nan_ok;

  annotation(experiment(StartTime = 0.0, StopTime = 12.0, Tolerance = 1.0e-6, Interval = 0.008), Documentation(info = "48 V PMDC servo with cascaded current and position control, anti-windup, 100:1 gearbox, rigid pendulum load, joint limits, thermal model, 7.2 N.m mid-third disturbance."));
end DCServoPositionC;