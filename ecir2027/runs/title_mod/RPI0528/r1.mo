model BLDCWheelRecoverF
  // ============================================================
  // Mission: smooth motion command with finite disturbance
  //          rejection and no protection trip.
  // Domain : electromechanical robotic actuator (48 V PM BLDC,
  //          9:1 gearbox, 0.12 m wheel, battery + FOC inverter).
  // ============================================================

  // --- Electrical power source (assumed values, labelled) ---
  parameter Real V_bat(unit="V") = 48.0    "Battery open-circuit voltage";
  parameter Real R_bat(unit="Ohm") = 0.05  "Battery internal resistance (assumed)";
  parameter Real C_bus(unit="F") = 2.0e-3  "DC bus capacitance (assumed)";

  // --- Motor electrical (q-axis lumped, assumed) ---
  parameter Real R_w(unit="Ohm") = 0.30   "Winding resistance, q-axis equivalent";
  parameter Real L_q(unit="H") = 0.5e-3   "Q-axis inductance";
  parameter Real Kt(unit="N.m/A") = 0.5   "Torque constant (== back-EMF const per mech rad/s)";
  parameter Real pp = 4                   "Pole pairs";

  // --- Mechanical ---
  parameter Real N_gear = 9                "Gear ratio motor:wheel";
  parameter Real eta_gear = 0.95           "Gearbox efficiency (assumed)";
  parameter Real J_rotor(unit="kg.m2") = 1.0e-4 "Rotor inertia (assumed)";
  parameter Real b_rotor(unit="N.m.s/rad") = 1.0e-4 "Rotor viscous friction (assumed)";
  parameter Real r_wheel(unit="m") = 0.12  "Wheel radius";
  parameter Real J_wheel(unit="kg.m2") = 1.0e-3 "Wheel inertia (assumed)";
  parameter Real m_eff(unit="kg") = 5.0    "Effective load mass on wheel (assumed)";

  // --- Thermal ---
  parameter Real C_th(unit="J/K") = 50.0   "Winding thermal capacitance (assumed)";
  parameter Real R_th(unit="K/W") = 0.5    "Winding-to-ambient thermal resistance (assumed)";
  parameter Real T_amb(unit="degC") = 25.0 "Ambient temperature";
  parameter Real T_limit(unit="degC") = 90.0 "Thermal trip limit (assumed)";

  // --- Control / protection ---
  parameter Real i_q_max(unit="A") = 15.0  "Q-axis current limit";
  parameter Real V_bus_limit(unit="V") = 58.6 "DC bus voltage limit";
  parameter Real omega_bw(unit="rad/s") = 628.318 "Current loop bandwidth (~100 Hz)";
  parameter Real Kp_pos(unit="N.m/rad") = 5.0 "Position gain (motor side)";
  parameter Real Kd_pos(unit="N.m.s/rad") = 0.2 "Velocity gain (motor side)";
  parameter Real L_obs(unit="1/s") = 30.0  "Disturbance observer gain";

  // --- Disturbance ---
  parameter Real F_dist(unit="N") = 29.0   "Disturbance force at wheel";
  parameter Real t_start(unit="s") = 6.6667 "Disturbance start (middle third)";
  parameter Real t_end(unit="s")   = 13.3333 "Disturbance end (middle third)";

  // --- Reference motion ---
  parameter Real A_ref(unit="rad") = 2.0   "Reference wheel angle amplitude";
  parameter Real f_ref(unit="Hz") = 0.1    "Reference frequency";
  parameter Real two_pi_f = 2.0*3.14159265358979*f_ref;

  // =================== States ===================
  Real V_bus(start=V_bat, fixed=true, unit="V")       "DC bus voltage";
  Real i_q(start=0, fixed=true, unit="A")             "Q-axis current";
  Real omega_m(start=0, fixed=true, unit="rad/s")     "Motor mechanical speed";
  Real theta_m(start=0, fixed=true, unit="rad")       "Motor angle";
  Real T_w(start=T_amb, fixed=true, unit="degC")      "Winding temperature";
  Real dist_est(start=0, fixed=true, unit="N.m")      "Disturbance estimate (motor side)";
  Real omega_est(start=0, fixed=true, unit="rad/s")   "Observer motor speed";

  discrete Real peak_dev(start=0, fixed=true, unit="rad")   "Peak deviation (sampled 500 Hz)";
  discrete Real t_recover(start=-1.0, fixed=true, unit="s") "First time error<0.032 after disturbance";
  discrete Real terminal_error(start=0, fixed=true, unit="rad") "Tracking error at simulation end";

  // =================== Algebraic / sensed ===================
  Real i_bat(unit="A")    "Battery current";
  Real i_inv(unit="A")    "Inverter DC-side current";
  Real v_q(unit="V")      "Q-axis voltage";
  Real tau_m(unit="N.m")  "Motor electromagnetic torque";
  Real omega_w(unit="rad/s") "Wheel speed";
  Real theta_w(unit="rad")  "Wheel angle";
  Real theta_ref(unit="rad") "Reference wheel angle";
  Real omega_ref(unit="rad/s") "Reference wheel speed";
  Real alpha_ref(unit="rad/s2") "Reference wheel acceleration";
  Real omega_ref_m(unit="rad/s") "Reference motor speed";
  Real alpha_ref_m(unit="rad/s2") "Reference motor acceleration";
  Real i_q_ref_raw(unit="A") "Unsaturated q-axis current command";
  Real i_q_ref(unit="A")     "Saturated q-axis current command";
  Real tau_ff(unit="N.m")    "Feedforward torque (motor side)";
  Real tau_ctrl(unit="N.m")  "Total control torque (motor side)";
  Real e_pos_m(unit="rad")   "Position error at motor side";
  Real e_omega_m(unit="rad/s") "Speed error at motor side";
  Real pos_error(unit="rad") "Wheel tracking error";
  Real F_dist_now(unit="N")  "Applied disturbance force";
  Real tau_dist_m(unit="N.m") "Disturbance torque referred to motor";
  Real J_total_m(unit="kg.m2") "Total inertia referred to motor";
  Real P_elec(unit="W")      "Electrical power into motor";
  Real P_loss(unit="W")      "Copper loss";
  Real recovery_time(unit="s") "Recovery time after disturbance end";

  Boolean trip_bus     "DC bus over-voltage flag";
  Boolean trip_current "Over-current flag";
  Boolean trip_thermal "Over-temperature flag";
  Boolean ok_no_nan    "No NaN/Inf in key physical/control/estimator values";

protected
  Real safe_Vbus(unit="V") "Guarded bus voltage (for division)";

equation
  // --- Guarded bus voltage (avoids division by zero) ---
  safe_Vbus = noEvent(if V_bus > 0.1 then V_bus else 0.1);

  // --- Disturbance profile ---
  F_dist_now = noEvent(if time >= t_start and time <= t_end then F_dist else 0.0);
  tau_dist_m = F_dist_now * r_wheel / N_gear;

  // --- Smooth reference trajectory (sinusoidal) ---
  theta_ref  = A_ref * sin(two_pi_f * time);
  omega_ref  = A_ref * two_pi_f * cos(two_pi_f * time);
  alpha_ref  = -A_ref * two_pi_f * two_pi_f * sin(two_pi_f * time);
  omega_ref_m = omega_ref * N_gear;
  alpha_ref_m = alpha_ref * N_gear;

  // --- Inertia referred to motor ---
  J_total_m = J_rotor + (J_wheel + m_eff * r_wheel * r_wheel) / (N_gear * N_gear);

  // --- Motor mechanical dynamics (rigid gearbox) ---
  tau_m = Kt * i_q;
  der(omega_m) = (tau_m - b_rotor * omega_m - tau_dist_m) / J_total_m;
  der(theta_m) = omega_m;
  omega_w = omega_m / N_gear;
  theta_w = theta_m / N_gear;

  // --- Current loop (q-axis, first order) ---
  der(i_q) = omega_bw * (i_q_ref - i_q);
  v_q = R_w * i_q + L_q * der(i_q) + Kt * omega_m;

  // --- DC bus power balance ---
  P_elec = v_q * i_q;
  i_inv = P_elec / safe_Vbus;
  i_bat = (V_bat - V_bus) / R_bat;
  C_bus * der(V_bus) = i_bat - i_inv;

  // --- Thermal dynamics ---
  P_loss = R_w * i_q * i_q;
  C_th * der(T_w) = P_loss - (T_w - T_amb) / R_th;

  // --- Disturbance observer (Luenberger-style) ---
  der(omega_est) = (tau_m - b_rotor * omega_est - dist_est) / J_total_m;
  der(dist_est) = L_obs * (omega_m - omega_est);

  // --- Feedforward motion control with disturbance estimate ---
  e_pos_m = (theta_ref - theta_w) * N_gear;
  e_omega_m = (omega_ref - omega_w) * N_gear;
  tau_ff = J_total_m * alpha_ref_m + b_rotor * omega_ref_m + dist_est;
  tau_ctrl = Kp_pos * e_pos_m + Kd_pos * e_omega_m + tau_ff;
  i_q_ref_raw = tau_ctrl / Kt;
  // Current saturation (preserves actuator limit)
  i_q_ref = noEvent(if i_q_ref_raw >  i_q_max then  i_q_max
               else if i_q_ref_raw < -i_q_max then -i_q_max
               else i_q_ref_raw);

  // --- Tracking error (wheel side) ---
  pos_error = theta_ref - theta_w;

  // --- Recovery time definition ---
  recovery_time = noEvent(if t_recover > 0.0 then t_recover - t_end else -1.0);

  // --- Protection flags ---
  trip_bus     = noEvent(V_bus > V_bus_limit);
  trip_current = noEvent(abs(i_q) > i_q_max * 1.05);
  trip_thermal = noEvent(T_w > T_limit);

  // --- NaN / Inf check (NaN != NaN; large magnitudes flagged) ---
  ok_no_nan = (V_bus == V_bus) and (i_q == i_q) and (omega_m == omega_m)
           and (theta_m == theta_m) and (T_w == T_w) and (dist_est == dist_est)
           and (pos_error == pos_error) and (omega_est == omega_est)
           and noEvent(V_bus < 1.0e6) and noEvent(V_bus > -1.0e6)
           and noEvent(abs(i_q) < 1.0e6) and noEvent(abs(omega_m) < 1.0e6)
           and noEvent(abs(dist_est) < 1.0e6) and noEvent(abs(T_w) < 1.0e6);

  // --- Peak deviation (sampled at 500 Hz) ---
  when sample(0, 0.002) then
    peak_dev = max(pre(peak_dev), abs(pos_error));
  end when;

  // --- First time error settles below 0.032 rad after disturbance end ---
  when time >= t_end and noEvent(abs(pos_error) < 0.032) then
    if pre(t_recover) < 0.0 then
      t_recover = time;
    else
      t_recover = pre(t_recover);
    end if;
  end when;

  // --- Terminal error at end of run ---
  when terminal() then
    terminal_error = pos_error;
  end when;

  annotation (
    experiment(StopTime=20.0, Tolerance=1e-6, Interval=0.002),
    Documentation(info="BLDC wheel actuator recovery scenario.
  48 V PM motor, 4 pole pairs, 9:1 gearbox, 0.12 m wheel.
  FOC current loop + feedforward motion control + disturbance observer.
  29 N disturbance applied during middle third of the 20 s run.
  500 Hz output sampling. Tracks sin reference, must settle < 0.032 rad after 13 s
  and remain within electrical (58.6 V bus, current limit) and thermal limits.")
  );
end BLDCWheelRecoverF;