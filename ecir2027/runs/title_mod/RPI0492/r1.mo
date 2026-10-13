model DCServoSpeedF
  parameter Real V_max = 58.6 "Maximum applied voltage (V)";
  parameter Real I_max = 60.0 "Maximum armature current (A)";
  parameter Real R_a = 0.12 "Armature resistance (Ohm)";
  parameter Real L_a = 0.6e-3 "Armature inductance (H)";
  parameter Real Kt = 0.05 "Torque constant (N.m/A)";
  parameter Real Ke = 0.05 "Back-EMF constant (V.s/rad)";
  parameter Real J_motor = 1.2e-4 "Rotor inertia (kg.m2)";
  parameter Real b_motor = 2e-5 "Motor viscous friction (N.m.s/rad)";
  parameter Real N = 100.0 "Gear ratio (motor:output = N:1)";
  parameter Real eta_g = 0.9 "Gearbox efficiency (dimensionless)";
  parameter Real J_load = 0.15 "Link inertia at output (kg.m2)";
  parameter Real b_load = 0.04 "Link viscous friction (N.m.s/rad)";
  parameter Real T_load = 17.4 "Load disturbance torque at output (N.m)";
  parameter Real Voc_full = 51.8 "Battery open-circuit voltage at full SOC (V)";
  parameter Real R_bat = 0.04 "Battery internal resistance (Ohm)";
  parameter Real Q_cap = 5.0 "Battery capacity (Ah)";
  parameter Real theta_th = 0.5 "Thermal resistance (K/W)";
  parameter Real C_th = 200.0 "Thermal capacitance (J/K)";
  parameter Real T_amb = 293.15 "Ambient temperature (K)";
  parameter Real T_max = 343.15 "Maximum winding temperature (K)";
  parameter Real w_ref_hold = 3.0 "Held output speed reference (rad/s)";
  parameter Real Kp_sp = 80.0 "Speed loop proportional gain";
  parameter Real Ki_sp = 200.0 "Speed loop integral gain";
  parameter Real Kp_cur = 0.5 "Current loop proportional gain";
  parameter Real Ki_cur = 200.0 "Current loop integral gain";
  parameter Real SOC_min = 0.05 "Minimum state of charge";
  parameter Real w_max = 12.0 "Maximum output speed (rad/s)";
  parameter Real acc_max = 50.0 "Maximum output acceleration (rad/s2)";

  Real i_a(start=0.0) "Armature current (A)";
  Real w_motor(start=0.0) "Motor angular velocity (rad/s)";
  Real theta_motor(start=0.0) "Motor/rotor position (rad)";
  Real SOC(start=1.0) "Battery state of charge (0..1)";
  Real T_winding(start=T_amb) "Winding temperature (K)";
  Real integ_sp(start=0.0) "Speed loop integrator state";
  Real integ_cur(start=0.0) "Current loop integrator state";

  Real w_out "Output angular velocity (rad/s)";
  Real theta_out "Output position (rad)";
  Real acc_out "Output acceleration (rad/s2)";
  Real V_bus "DC bus voltage (V)";
  Real V_cmd "Unsaturated voltage command (V)";
  Real V_app "Applied armature voltage (V)";
  Real w_ref "Speed reference (rad/s)";
  Real i_cmd "Unsaturated current command (A)";
  Real i_cmd_sat "Saturated current command (A)";
  Real tau_motor "Motor electromagnetic torque (N.m)";
  Real tau_load "Active load disturbance torque at output (N.m)";
  Real track_err "Speed tracking error (rad/s)";
  Real J_eq_motor "Equivalent inertia at motor side (kg.m2)";
  Real b_eq_motor "Equivalent friction at motor side (N.m.s/rad)";

  Boolean voltage_ok;
  Boolean current_ok;
  Boolean speed_ok;
  Boolean accel_ok;
  Boolean soc_ok;
  Boolean thermal_ok;
  Boolean tracking_ok;
  Boolean no_nan;

equation
  // Reference speed schedule: ramp up, hold, ramp down, rest
  w_ref = if time < 3.0 then w_ref_hold*time/3.0
          elseif time < 13.0 then w_ref_hold
          elseif time < 17.0 then w_ref_hold*(1.0 - (time - 13.0)/4.0)
          else 0.0;

  // Battery open-circuit voltage droops with SOC; bus voltage drops under load
  V_bus = Voc_full*(0.85 + 0.15*SOC) - R_bat*i_a;

  // State of charge dynamics (discharge only when current positive)
  der(SOC) = -max(i_a, 0.0)/(3600.0*Q_cap);

  // Motor electrical dynamics
  L_a*der(i_a) = V_app - R_a*i_a - Ke*w_motor;
  der(theta_motor) = w_motor;

  // Motor electromagnetic torque
  tau_motor = Kt*i_a;

  // Kinematics through gearbox
  w_out = w_motor/N;
  theta_out = theta_motor/N;
  acc_out = der(w_motor)/N;

  // Load disturbance applied during the middle third of the 20 s window
  tau_load = if (time >= 20.0/3.0 and time <= 2.0*20.0/3.0) then T_load else 0.0;

  // Equivalent inertia and friction at motor side (load reflected, efficiency accounted)
  J_eq_motor = J_motor + J_load/(eta_g*N*N);
  b_eq_motor = b_motor + b_load/(eta_g*N);

  // Motor-side equation of motion
  J_eq_motor*der(w_motor) = tau_motor - b_eq_motor*w_motor - tau_load/(eta_g*N);

  // Thermal state (first-order, dissipation = i^2*R)
  C_th*der(T_winding) = i_a*i_a*R_a - (T_winding - T_amb)/theta_th;

  // Speed loop with conditional (anti-windup) integration
  track_err = w_ref - w_out;
  der(integ_sp) = if ((i_cmd > I_max and track_err > 0.0) or
                      (i_cmd < -I_max and track_err < 0.0))
                  then 0.0 else track_err;
  i_cmd = Kp_sp*track_err + Ki_sp*integ_sp;
  i_cmd_sat = max(-I_max, min(I_max, i_cmd));

  // Current loop with back-EMF feedforward and conditional (anti-windup) integration
  der(integ_cur) = if ((V_cmd > V_max and (i_cmd_sat - i_a) > 0.0) or
                       (V_cmd < -V_max and (i_cmd_sat - i_a) < 0.0))
                   then 0.0 else (i_cmd_sat - i_a);
  V_cmd = Kp_cur*(i_cmd_sat - i_a) + Ki_cur*integ_cur + Ke*w_motor;
  V_app = max(-V_max, min(V_max, V_cmd));

  // Verification flags
  voltage_ok = abs(V_app) <= V_max + 1.0e-6;
  current_ok = abs(i_a) <= I_max + 1.0e-6;
  speed_ok = abs(w_out) <= w_max + 1.0e-6;
  accel_ok = abs(acc_out) <= acc_max + 1.0e-6;
  soc_ok = SOC >= SOC_min;
  thermal_ok = T_winding <= T_max;
  tracking_ok = (time <= 13.0) or (abs(track_err) < 0.2);
  no_nan = not (Modelica.Math.isNaN(i_a) or Modelica.Math.isNaN(w_out) or
                Modelica.Math.isNaN(V_app) or Modelica.Math.isNaN(SOC) or
                Modelica.Math.isNaN(T_winding) or Modelica.Math.isNaN(w_ref));

  annotation (experiment(StopTime=20.0, Tolerance=1e-6, Interval=0.002));
end DCServoSpeedF;