model CableWinchTorqueC
  "Electromechanical cable winch with cascaded current/speed/tension control tracking output force against compliant load, 72V motor, 45:1 gearbox, 0.09m drum, 140kg payload, 12m travel"

  // ==================== Physical parameters ====================
  parameter Real V_max = 66.2 "V, maximum voltage command magnitude";
  parameter Real V_supply = 72.0 "V, motor supply voltage rating";
  parameter Real N_gear = 45.0 "gearbox ratio";
  parameter Real r_drum = 0.09 "m, drum radius";
  parameter Real m_payload = 140.0 "kg, payload mass";
  parameter Real L_travel = 12.0 "m, total cable travel";
  parameter Real g = 9.81 "m/s2, gravitational acceleration";

  // Motor electrical — specific values not stated in requirement; chosen for 72V motor class
  parameter Real R_motor = 2.0 "ohm, armature resistance";
  parameter Real L_motor = 0.02 "H, armature inductance";
  parameter Real Kt_motor = 0.2 "N.m/A, torque constant";
  parameter Real Ke_motor = 0.2 "V.s/rad, back-EMF constant";
  parameter Real i_max = 20.0 "A, current limit";

  // Motor mechanical
  parameter Real J_motor = 0.01 "kg.m2, motor rotor inertia";
  parameter Real B_motor = 0.001 "N.m.s/rad, motor viscous friction";
  parameter Real J_drum = 0.1 "kg.m2, drum inertia";
  parameter Real B_drum = 0.01 "N.m.s/rad, drum viscous friction";

  // Transmission compliance (gearbox)
  parameter Real k_gb = 1000.0 "N.m/rad, gearbox torsional stiffness";
  parameter Real c_gb = 10.0 "N.m.s/rad, gearbox torsional damping";
  parameter Real dtheta_gb_max = 0.2 "rad, gearbox deflection limit";

  // Cable compliance
  parameter Real k_cable = 5000.0 "N/m, cable stiffness";
  parameter Real c_cable = 50.0 "N.s/m, cable damping";

  // Contact stiffness and damping (rigid support geometry)
  parameter Real k_contact = 10000.0 "N/m, contact stiffness";
  parameter Real c_contact = 100.0 "N.s/m, contact damping";

  // Thermal
  parameter Real C_thermal = 500.0 "J/K, thermal capacitance";
  parameter Real k_thermal = 2.0 "W/K, thermal conductance";
  parameter Real T_amb = 20.0 "degC, ambient temperature";
  parameter Real T_max = 80.0 "degC, thermal limit";

  // Command and disturbance
  parameter Real F_cmd_val = m_payload * g "N, force command (hold payload weight)";
  parameter Real F_dist_val = 13.5 "N, disturbance load change magnitude";
  parameter Real F_bound = 5000.0 "N, force upper bound";
  parameter Real omega_max = 500.0 "rad/s, speed command limit";

  // Controller gains — current loop (inner)
  parameter Real Kp_i = 1.4 "current loop proportional gain";
  parameter Real Ki_i = 50.0 "current loop integral gain";

  // Controller gains — speed loop (middle)
  parameter Real Kp_w = 2.1 "speed loop proportional gain";
  parameter Real Ki_w = 45.0 "speed loop integral gain";

  // Controller gains — tension/force loop (outer)
  parameter Real Kp_f = 0.42 "force loop proportional gain";
  parameter Real Ki_f = 0.9 "force loop integral gain";

  // Sampling
  parameter Real Ts = 1.0 / 125.0 "s, 125 Hz sampling period (run simulation for 12 s)";

  // ==================== Derived initial conditions ====================
  parameter Real T_hold = m_payload * g * r_drum "N.m, drum torque to hold payload";
  parameter Real dtheta_gb0 = T_hold / k_gb "rad, initial gearbox deflection under load";
  parameter Real y0 = 5.0 "m, initial payload height above support";
  parameter Real theta_drum0 = y0 / r_drum "rad, initial drum angle";
  parameter Real theta_motor0 = N_gear * (theta_drum0 + dtheta_gb0) "rad, initial motor angle";
  parameter Real i0 = T_hold / (Kt_motor * N_gear) "A, initial holding current";
  parameter Real V0 = R_motor * i0 "V, initial holding voltage";

  // ==================== Dynamic states ====================
  Real i_motor(start = i0) "A, motor current (measured)";
  Real omega_motor(start = 0) "rad/s, motor angular velocity";
  Real theta_motor(start = theta_motor0) "rad, motor angle";
  Real omega_drum(start = 0) "rad/s, drum angular velocity";
  Real theta_drum(start = theta_drum0) "rad, drum angle";
  Real v_load(start = 0) "m/s, payload velocity";
  Real y_load(start = y0) "m, payload position";
  Real T_winding(start = T_amb) "degC, motor winding temperature (measured)";

  // Controller integrator states
  Real integ_i(start = 0) "current loop integrator";
  Real integ_w(start = i0) "speed loop integrator";
  Real integ_f(start = 0) "force loop integrator";

  // ==================== Computed signals ====================
  Real V_cmd_raw "V, unsaturated voltage command";
  Real V_sat "V, saturated voltage command";
  Real i_cmd_raw "A, unsaturated current command";
  Real i_cmd "A, saturated current command";
  Real omega_cmd_raw "rad/s, unsaturated speed command";
  Real omega_cmd "rad/s, saturated speed command";
  Real F_cmd "N, force command";
  Real F_dist "N, disturbance force (downward)";
  Real F_cable "N, cable tension (measured)";
  Real F_contact "N, contact force (measured)";
  Real T_gb "N.m, gearbox transmitted torque";
  Real T_motor_side "N.m, motor-side torque (measured)";
  Real T_load_side "N.m, load-side torque (measured)";
  Real dtheta_gb "rad, gearbox deflection";
  Real T_em "N.m, motor electromagnetic torque";
  Real F_error "N, force tracking error";
  Real F_error_abs "N, absolute force tracking error";

  // ==================== Bound indicators ====================
  Boolean V_bound_ok "electrical: voltage within bounds";
  Boolean i_bound_ok "electrical: current within bounds";
  Boolean T_bound_ok "thermal: temperature within bounds";
  Boolean joint_bound_ok "joint: motor speed and payload travel within bounds";
  Boolean gb_defl_ok "transmission deflection within bounds";
  Boolean force_bound_ok "contact force within bounds";
  Boolean tracking_ok "tracking error below 2.1 N after 7.8 s";

equation
  // ===== Force command and disturbance injection (middle third: 4–8 s) =====
  F_cmd = F_cmd_val;
  F_dist = if (time >= 4.0 and time < 8.0) then F_dist_val else 0.0;

  // ===== Motor electromagnetic torque =====
  T_em = Kt_motor * i_motor;

  // ===== Motor electrical dynamics =====
  L_motor * der(i_motor) = V_sat - R_motor * i_motor - Ke_motor * omega_motor;

  // ===== Gearbox compliance (transmission deflection) =====
  dtheta_gb = theta_motor / N_gear - theta_drum;
  T_gb = k_gb * dtheta_gb + c_gb * (omega_motor / N_gear - omega_drum);
  T_motor_side = T_gb / N_gear;
  T_load_side = T_gb;

  // ===== Motor mechanical dynamics =====
  J_motor * der(omega_motor) = T_em - T_gb / N_gear - B_motor * omega_motor;
  der(theta_motor) = omega_motor;

  // ===== Drum dynamics =====
  J_drum * der(omega_drum) = T_gb - F_cable * r_drum - B_drum * omega_drum;
  der(theta_drum) = omega_drum;

  // ===== Cable tension (massless compliant cable with gravity preload) =====
  F_cable = k_cable * (r_drum * theta_drum - y_load)
          + c_cable * (r_drum * omega_drum - v_load)
          + m_payload * g;

  // ===== Contact force (rigid support at y=0, compliant contact) =====
  F_contact = if (y_load < 0 and v_load < 0) then
               (k_contact * (-y_load) + c_contact * (-v_load))
             elseif (y_load < 0) then
               k_contact * (-y_load)
             else
               0.0;

  // ===== Payload dynamics =====
  m_payload * der(v_load) = F_cable + F_contact - m_payload * g - F_dist;
  der(y_load) = v_load;

  // ===== Thermal dynamics =====
  C_thermal * der(T_winding) = i_motor * i_motor * R_motor
                             - k_thermal * (T_winding - T_amb);

  // ==================== Cascaded controllers ====================

  // --- Force/tension loop (outer) -> speed command ---
  F_error = F_cmd - F_cable;
  F_error_abs = abs(F_error);
  omega_cmd_raw = Kp_f * F_error + integ_f;
  omega_cmd = if omega_cmd_raw > omega_max then omega_max
              elseif omega_cmd_raw < -omega_max then -omega_max
              else omega_cmd_raw;
  der(integ_f) = Ki_f * F_error + (Ki_f / Kp_f) * (omega_cmd - omega_cmd_raw);

  // --- Speed loop (middle) -> current command ---
  i_cmd_raw = Kp_w * (omega_cmd - omega_motor) + integ_w;
  i_cmd = if i_cmd_raw > i_max then i_max
          elseif i_cmd_raw < -i_max then -i_max
          else i_cmd_raw;
  der(integ_w) = Ki_w * (omega_cmd - omega_motor)
               + (Ki_w / Kp_w) * (i_cmd - i_cmd_raw);

  // --- Current loop (inner) -> voltage command (with back-EMF and R feedforward) ---
  V_cmd_raw = Kp_i * (i_cmd - i_motor) + integ_i
            + R_motor * i_motor + Ke_motor * omega_motor;
  V_sat = if V_cmd_raw > V_max then V_max
          elseif V_cmd_raw < -V_max then -V_max
          else V_cmd_raw;
  der(integ_i) = Ki_i * (i_cmd - i_motor) + (Ki_i / Kp_i) * (V_sat - V_cmd_raw);

  // ==================== Bound checks ====================
  V_bound_ok = abs(V_cmd_raw) <= V_max + 0.01;
  i_bound_ok = abs(i_motor) <= i_max + 0.01;
  T_bound_ok = T_winding <= T_max;
  joint_bound_ok = abs(omega_motor) <= omega_max + 0.01
                   and y_load >= 0.0 and y_load <= L_travel;
  gb_defl_ok = abs(dtheta_gb) <= dtheta_gb_max;
  force_bound_ok = F_cable >= 0.0 and F_cable <= F_bound;
  tracking_ok = if time >= 7.8 then F_error_abs < 2.1 else true;

end CableWinchTorqueC;