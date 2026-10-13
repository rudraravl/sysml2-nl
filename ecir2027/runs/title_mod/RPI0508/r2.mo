model BLDCWheelPositionD
  "Instrumented BLDC wheel position actuator with cascaded current/position control and anti-windup"

  // === Battery ===
  parameter Real V_batt = 48.0   "Battery open-circuit voltage [V]";
  parameter Real R_batt = 0.05  "Battery internal resistance [Ohm]";
  Real v_bus "Bus voltage under load [V]";
  Real i_bus  "Battery current [A]";

  // === Motor electrical (PM BLDC, FOC q-axis) ===
  parameter Real R_w = 0.2      "Per-phase winding resistance [Ohm]";
  parameter Real L_w = 0.001    "Per-phase winding inductance [H]";
  parameter Real Ke = 0.05      "Back-EMF constant [V.s/rad]";
  parameter Real Kt = 0.05      "Torque constant [N.m/A]";
  parameter Integer p = 4       "Pole pairs";
  parameter Real i_q_max = 40.0 "Phase current limit [A]";
  Real i_q(start=0, fixed=true) "q-axis current [A]";
  Real v_q        "Unsaturated q-axis voltage command [V]";
  Real v_q_sat    "Saturated q-axis voltage applied [V]";
  Real e_emf      "Back-EMF [V]";
  Real i_q_ref    "Current reference (saturated) [A]";

  // === Current controller (inner cascade) ===
  parameter Real Kp_cur = 100.0 "Current proportional gain";
  parameter Real Ki_cur = 500.0 "Current integral gain";
  Real cur_err               "Current error [A]";
  Real integral_cur(start=0, fixed=true) "Current integrator state [V]";
  Real cur_aw                 "Current anti-windup correction [V]";

  // === Mechanical ===
  parameter Real N = 9.0       "Gearbox ratio";
  parameter Real r_wheel = 0.12 "Wheel radius [m]";
  parameter Real J_motor = 1e-5 "Motor rotor inertia [kg.m2]";
  parameter Real J_wheel = 0.01 "Wheel/load inertia [kg.m2]";
  parameter Real b_motor = 1e-6 "Motor viscous friction [N.m.s/rad]";
  parameter Real b_wheel = 0.002 "Wheel viscous friction [N.m.s/rad]";
  parameter Real theta_min = -0.1 "Lower travel limit [rad]";
  parameter Real theta_max = 3.0  "Upper travel limit [rad]";
  parameter Real k_collision = 1e4 "Collision stiffness [N.m/rad]";
  parameter Real b_collision = 5.0 "Collision damping [N.m.s/rad]";
  parameter Real m_load = 2.0  "Equivalent gravitational load mass [kg]";
  parameter Real g = 9.81      "Gravity [m/s2]";
  parameter Real L_arm = 0.3   "Effective gravity arm [m]";
  Real omega_m(start=0, fixed=true) "Motor angular velocity [rad/s]";
  Real theta_w(start=0, fixed=true) "Wheel output position [rad]";
  Real omega_w     "Wheel angular velocity [rad/s]";
  Real T_motor     "Motor electromagnetic torque [N.m]";
  Real T_gear_out  "Gearbox output torque [N.m]";
  Real T_gravity   "Steady gravity load torque [N.m]";
  Real T_disturb   "Disturbance load torque [N.m]";
  Real T_collision "Collision/reaction torque at limits [N.m]";
  Real J_eq        "Equivalent inertia reflected to motor [kg.m2]";
  Real b_eq        "Equivalent friction reflected to motor [N.m.s/rad]";

  // === Position controller (outer cascade) ===
  parameter Real theta_target = 1.0 "Nonzero target output position [rad]";
  parameter Real Kp_pos = 30.0 "Position proportional gain";
  parameter Real Ki_pos = 20.0 "Position integral gain";
  parameter Real Kd_pos = 2.0  "Position derivative gain on velocity";
  Real pos_err               "Position error [rad]";
  Real integral_pos(start=0, fixed=true) "Position integrator state [A]";
  Real pos_aw                 "Position anti-windup correction [A]";
  Real i_q_ref_unsat          "Unsaturated current reference [A]";

  // === Thermal ===
  parameter Real T_amb = 25.0   "Ambient temperature [degC]";
  parameter Real R_th = 1.0     "Winding-to-ambient thermal resistance [K/W]";
  parameter Real C_th = 500.0   "Winding thermal capacitance [J/K]";
  parameter Real T_limit = 90.0 "Winding temperature limit [degC]";
  Real T_winding(start=T_amb, fixed=true) "Winding temperature [degC]";
  Real Q_loss     "Joule heat loss [W]";

  // === Sensors ===
  Real i_measured     "Measured electrical current [A]";
  Real theta_measured "Measured output position [rad]";
  Real omega_measured "Measured output velocity [rad/s]";
  Real T_measured     "Measured winding temperature [degC]";

  // === Synchronized traces ===
  Real state_position    "State trace: position [rad]";
  Real state_velocity    "State trace: velocity [rad/s]";
  Real state_current     "State trace: current [A]";
  Real state_temperature "State trace: temperature [degC]";
  Real cmd_current       "Command trace: current reference [A]";
  Real cmd_voltage       "Command trace: applied voltage [V]";
  Real sensor_position   "Sensor trace: position [rad]";
  Real sensor_velocity   "Sensor trace: velocity [rad/s]";
  Real sensor_current    "Sensor trace: current [A]";
  Real sensor_temperature "Sensor trace: temperature [degC]";

  // === Bounds and metrics ===
  Real e_track            "Primary tracking error magnitude [rad]";
  Real final_error        "Final position error magnitude [rad]";
  Real voltage_bound      "Bus voltage bound monitor [V]";
  Real current_bound      "Current bound monitor [A]";
  Real travel_bound       "Travel bound monitor [rad]";
  Real temperature_bound  "Temperature bound monitor [degC]";
  Boolean voltage_ok;
  Boolean current_ok;
  Boolean travel_ok;
  Boolean temperature_ok;
  Boolean tracking_ok;
  Boolean no_nan_inf;

equation
  // === Battery ===
  i_bus = 1.5 * v_q_sat * i_q / V_batt;
  v_bus = V_batt - R_batt * i_bus;

  // === Electrical dynamics (q-axis) ===
  e_emf = p * Ke * omega_m;
  L_w * der(i_q) = v_q_sat - R_w * i_q - e_emf;

  // === Torque and gearbox ===
  T_motor    = Kt * i_q;
  T_gear_out = N * T_motor;

  // === Reflected mechanical parameters ===
  J_eq = J_motor + J_wheel / (N*N);
  b_eq = b_motor + b_wheel / (N*N);
  omega_w = omega_m / N;

  // === Loads on wheel side ===
  T_gravity = m_load * g * L_arm;
  T_disturb = if (time >= 4.6667 and time <= 9.3333) then 8.0 else 0.0;

  // === Collision / physical limits ===
  T_collision = (if theta_w > theta_max then
                   -k_collision*(theta_w - theta_max) - b_collision*omega_w
                 elseif theta_w < theta_min then
                   -k_collision*(theta_w - theta_min) - b_collision*omega_w
                 else 0.0);

  // === Motor-side equation of motion ===
  J_eq * der(omega_m) = T_motor - b_eq * omega_m - (T_gravity + T_disturb - T_collision)/N;

  // === Output position ===
  der(theta_w) = omega_w;

  // === Position controller (outer cascade, PI + D on velocity) ===
  pos_err = theta_target - theta_w;
  der(integral_pos) = Ki_pos * pos_err + pos_aw;
  i_q_ref_unsat = Kp_pos * pos_err + integral_pos - Kd_pos * omega_w;
  i_q_ref = if i_q_ref_unsat > i_q_max then i_q_max
            elseif i_q_ref_unsat < -i_q_max then -i_q_max
            else i_q_ref_unsat;
  pos_aw = if i_q_ref_unsat > i_q_max then (i_q_max - i_q_ref_unsat)
           elseif i_q_ref_unsat < -i_q_max then (-i_q_max - i_q_ref_unsat)
           else 0.0;

  // === Current controller (inner cascade, PI) ===
  cur_err = i_q_ref - i_q;
  der(integral_cur) = Ki_cur * cur_err + cur_aw;
  v_q = Kp_cur * cur_err + integral_cur;
  v_q_sat = if v_q > V_batt then V_batt
            elseif v_q < -V_batt then -V_batt
            else v_q;
  cur_aw = if v_q > V_batt then (V_batt - v_q)
           elseif v_q < -V_batt then (-V_batt - v_q)
           else 0.0;

  // === Thermal model of winding ===
  Q_loss = R_w * i_q * i_q;
  C_th * der(T_winding) = Q_loss - (T_winding - T_amb) / R_th;

  // === Sensors ===
  i_measured     = i_q;
  theta_measured = theta_w;
  omega_measured = omega_w;
  T_measured     = T_winding;

  // === Synchronized state, command, and sensor traces ===
  state_position    = theta_w;
  state_velocity    = omega_w;
  state_current     = i_q;
  state_temperature = T_winding;
  cmd_current       = i_q_ref;
  cmd_voltage       = v_q_sat;
  sensor_position   = theta_measured;
  sensor_velocity   = omega_measured;
  sensor_current   = i_measured;
  sensor_temperature = T_measured;

  // === Bounds and requirement metrics ===
  e_track           = abs(pos_err);
  final_error       = e_track;
  voltage_bound     = v_bus;
  current_bound     = i_q;
  travel_bound      = theta_w;
  temperature_bound = T_winding;

  voltage_ok     = (v_bus >= 0.0) and (v_bus <= V_batt + 1e-6);
  current_ok     = (abs(i_q) <= i_q_max + 1e-6);
  travel_ok      = (theta_w >= theta_min - 1e-3) and (theta_w <= theta_max + 1e-3);
  temperature_ok = (T_winding <= T_limit);
  tracking_ok    = (if time >= 9.1 then (e_track <= 0.03) else true);
  no_nan_inf     = (e_track >= 0.0) and (abs(i_q) >= 0.0) and (abs(omega_w) >= 0.0)
                   and (T_winding >= -1000.0) and (v_bus >= -1000.0);

  annotation(
    experiment(StartTime=0, StopTime=14, Tolerance=1e-6, Interval=0.005),
    Documentation(info="48 V three-phase PM BLDC (4 pole pairs) driving a 0.12 m wheel through a 9:1 gearbox with a battery of internal resistance. Field-oriented inverter limits phase voltage to the 48 V bus. Cascaded current (inner) and position (outer) PI control with back-calculation anti-windup. Driven rigid body has collision spring-damper at physical travel limits and a steady gravity load. A controlled 8 N.m output load disturbance is applied during the middle third of the 14 s, 200 Hz run. Tracks a 1.0 rad nonzero target and holds. Exports synchronized state, command, and sensor traces with voltage, current, travel, final-error, and temperature bounds and a primary tracking-error requirement below 0.03 rad after 9.1 s."));
end BLDCWheelPositionD;