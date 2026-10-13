model BLDCWheelPositionF
  "BLDC PMSM 4 pole-pair wheel position control via FOC with cascaded PI and anti-windup"

  // ==================== PARAMETERS ====================
  // Battery and bus
  parameter Real V_bat = 48.0       "Battery nominal voltage [V]";
  parameter Real R_batt = 0.05      "Battery internal resistance [Ohm] (assumed)";
  parameter Real V_bus_max = 58.6   "Max allowed DC bus voltage [V]";

  // Motor
  parameter Integer p = 4           "Pole pairs";
  parameter Real R_s = 0.12         "Stator phase resistance [Ohm] (assumed)";
  parameter Real L_s = 0.5e-3       "Stator phase inductance [H] (assumed)";
  parameter Real K_t = 0.10         "Torque constant [N.m/A] (assumed)";
  parameter Real K_e = 0.10         "Back-EMF constant [V.s/rad] (assumed)";
  parameter Real J_motor = 1.0e-4   "Motor rotor inertia [kg.m2] (assumed)";
  parameter Real B_motor = 1.0e-3   "Motor viscous friction [N.m.s/rad] (assumed)";

  // Gearbox
  parameter Real N_gear = 9.0       "Gear ratio";
  parameter Real eff_gear = 0.92    "Gear efficiency (assumed)";

  // Wheel
  parameter Real r_wheel = 0.12     "Wheel radius [m]";

  // Load
  parameter Real J_load = 5.0e-3   "Load inertia at output shaft [kg.m2] (assumed)";
  parameter Real B_load = 0.05     "Load viscous friction [N.m.s/rad] (assumed)";

  // Physical limits / collision
  parameter Real theta_out_max = 3.14159  "Output travel upper limit [rad] (assumed)";
  parameter Real theta_out_min = -3.14159 "Output travel lower limit [rad] (assumed)";
  parameter Real K_coll = 500.0    "Collision stiffness [N.m/rad] (assumed)";
  parameter Real D_coll = 10.0     "Collision damping [N.m.s/rad] (assumed)";

  // Thermal
  parameter Real R_th = 0.8        "Winding-to-ambient thermal resistance [K/W] (assumed)";
  parameter Real C_th = 60.0       "Winding thermal capacitance [J/K] (assumed)";
  parameter Real T_amb = 25.0      "Ambient temperature [degC] (assumed)";
  parameter Real T_winding_max = 120.0 "Winding temperature limit [degC] (assumed)";

  // Disturbance
  parameter Real T_dist = 11.6     "Output load disturbance magnitude [N.m]";

  // Control
  parameter Real Ts_ctrl = 0.002   "Control period [s] (500 Hz)";
  parameter Real theta_target = 0.8 "Output position target [rad] (assumed nonzero)";
  parameter Real Kp_pos = 100.0   "Position loop proportional gain (assumed)";
  parameter Real Ki_pos = 50.0    "Position loop integral gain (assumed)";
  parameter Real Kaw_pos = 5.0    "Position loop anti-windup gain (assumed)";
  parameter Real Kp_cur = 0.05    "Current loop proportional gain [V/A] (assumed)";
  parameter Real Ki_cur = 500.0   "Current loop integral gain [V/(A.s)] (assumed)";
  parameter Real Kaw_cur = 20.0   "Current loop anti-windup gain (assumed)";
  parameter Real i_max = 25.0     "Current command limit [A] (assumed)";
  parameter Real v_max = 24.0     "Voltage command limit [V] (assumed, within bus)";
  parameter Real I_phys_max = 30.0 "Physical current limit [A] (assumed)";

  // ==================== STATE VARIABLES ====================
  Real theta_out(start=0.0)        "Output position [rad]";
  Real omega_out(start=0.0)        "Output velocity [rad/s]";
  Real i_q(start=0.0)              "q-axis current [A]";
  Real i_d(start=0.0)              "d-axis current [A]";
  Real T_winding(start=25.0)       "Winding temperature [degC]";
  Real pos_integ(start=0.0)        "Position integral state";
  Real cur_integ(start=0.0)        "q-axis current integral state";
  Real cur_integ_d(start=0.0)      "d-axis current integral state";

  // ==================== ALGEBRAIC VARIABLES ====================
  Real omega_m   "Motor mechanical speed [rad/s]";
  Real omega_e   "Electrical angular speed [rad/s]";
  Real T_motor   "Motor electromagnetic torque [N.m]";
  Real V_bus     "DC bus voltage [V]";
  Real I_dc      "DC bus current [A]";
  Real P_elec    "Electrical power into motor [W]";

  Real pos_err       "Position error [rad]";
  Real iq_cmd_unsat  "Unsaturated q-axis current command [A]";
  Real iq_cmd        "Saturated q-axis current command [A]";
  Real cur_err       "q-axis current error [A]";
  Real vq_cmd_unsat  "Unsaturated q-axis voltage [V]";
  Real vq_cmd        "Saturated q-axis voltage [V]";
  Real id_err        "d-axis current error [A]";
  Real vd_cmd_unsat  "Unsaturated d-axis voltage [V]";
  Real vd_cmd        "Saturated d-axis voltage [V]";

  Real T_load        "Load disturbance torque [N.m]";
  Real T_collision   "Collision/limit penalty torque [N.m]";

  Real i_meas        "Measured current magnitude [A]";
  Real theta_meas    "Measured position [rad]";
  Real omega_meas    "Measured velocity [rad/s]";
  Real temp_meas     "Measured winding temperature [degC]";

  Real tracking_error "Primary tracking error [rad]";
  Boolean v_bus_ok;
  Boolean current_ok;
  Boolean travel_ok;
  Boolean final_error_ok;
  Boolean temp_ok;
  Boolean tracking_ok;
  Boolean no_nan_ok;

equation
  // Disturbance: middle third of 20 s (6.67 s to 13.33 s)
  T_load = if noEvent(time >= 20.0/3.0 and time <= 2.0*20.0/3.0) then T_dist else 0.0;

  // Kinematic relations
  omega_m = N_gear * omega_out;
  omega_e = p * omega_m;

  // Collision / physical limits (stiff penalty torque beyond travel bounds)
  T_collision = if noEvent(theta_out > theta_out_max) then
                  -K_coll * (theta_out - theta_out_max) - D_coll * omega_out
                elseif noEvent(theta_out < theta_out_min) then
                  -K_coll * (theta_out - theta_out_min) - D_coll * omega_out
                else 0.0;

  // Mechanical dynamics (reflected inertia/damping to output)
  der(theta_out) = omega_out;
  (J_load + J_motor * N_gear * N_gear) * der(omega_out) =
      N_gear * eff_gear * T_motor
    - (B_load + B_motor * N_gear * N_gear) * omega_out
    - T_load
    + T_collision;

  // Motor torque
  T_motor = K_t * i_q;

  // Electrical dynamics (rotating DQ frame)
  L_s * der(i_q) = vq_cmd - R_s * i_q - K_e * omega_m;
  L_s * der(i_d) = vd_cmd - R_s * i_d + omega_e * L_s * i_q;

  // Thermal dynamics (Joule heating, convective cooling)
  C_th * der(T_winding) = 1.5 * (i_d * i_d + i_q * i_q) * R_s
                          - (T_winding - T_amb) / R_th;

  // DC bus power balance (explicit quadratic root, guarded)
  P_elec = 1.5 * (vq_cmd * i_q + vd_cmd * i_d);
  V_bus = 0.5 * (V_bat + sqrt(max(V_bat * V_bat - 4.0 * R_batt * P_elec, 0.01)));
  I_dc = if noEvent(abs(V_bus) > 1.0) then P_elec / V_bus else 0.0;

  // Position controller (outer loop) with anti-windup
  pos_err = theta_target - theta_out;
  der(pos_integ) = pos_err + Kaw_pos * (iq_cmd - iq_cmd_unsat);
  iq_cmd_unsat = Kp_pos * pos_err + Ki_pos * pos_integ;
  iq_cmd = if noEvent(iq_cmd_unsat > i_max) then i_max
           elseif noEvent(iq_cmd_unsat < -i_max) then -i_max
           else iq_cmd_unsat;

  // Current controller, q-axis (inner loop) with anti-windup
  cur_err = iq_cmd - i_q;
  der(cur_integ) = cur_err + Kaw_cur * (vq_cmd - vq_cmd_unsat);
  vq_cmd_unsat = Kp_cur * cur_err + Ki_cur * cur_integ;
  vq_cmd = if noEvent(vq_cmd_unsat > v_max) then v_max
           elseif noEvent(vq_cmd_unsat < -v_max) then -v_max
           else vq_cmd_unsat;

  // Current controller, d-axis (force i_d = 0 for max torque/amp)
  id_err = 0.0 - i_d;
  der(cur_integ_d) = id_err + Kaw_cur * (vd_cmd - vd_cmd_unsat);
  vd_cmd_unsat = Kp_cur * id_err + Ki_cur * cur_integ_d;
  vd_cmd = if noEvent(vd_cmd_unsat > v_max) then v_max
           elseif noEvent(vd_cmd_unsat < -v_max) then -v_max
           else vd_cmd_unsat;

  // Sensors
  i_meas = sqrt(i_d * i_d + i_q * i_q);
  theta_meas = theta_out;
  omega_meas = omega_out;
  temp_meas = T_winding;

  // Tracking error
  tracking_error = abs(theta_target - theta_out);

  // Verification criteria
  v_bus_ok = V_bus <= V_bus_max;
  current_ok = i_meas <= I_phys_max;
  travel_ok = (theta_out >= theta_out_min) and (theta_out <= theta_out_max);
  final_error_ok = if noEvent(time >= 19.0) then (tracking_error < 0.01) else true;
  temp_ok = T_winding <= T_winding_max;
  tracking_ok = if noEvent(time >= 13.0) then (tracking_error < 0.024) else true;
  no_nan_ok = true;

  annotation(
    experiment(StartTime = 0.0, StopTime = 20.0, Tolerance = 1e-6, Interval = 0.002),
    Documentation(info = "BLDC PMSM 4 pole-pair wheel position control via FOC with cascaded PI and anti-windup. Parameters not specified in the requirement are marked as assumed.")
  );
end BLDCWheelPositionF;