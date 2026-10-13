model BallScrewRecoverE
  // ----------------------------------------------------------------
  // Electromechanical ball-screw actuator with cascaded current/position
  // control, feedforward, disturbance observer, saturation, and thermal
  // dynamics. Plant: 24 V motor, 18 kg carriage, 5 mm pitch ball screw,
  // belt reduction, backlash, Coulomb friction, 0.65 m travel.
  // 24 N disturbance applied over middle third of a 16 s, 250 Hz run.
  // NOTE: Numerical values for motor/transmission parameters not stated
  // in the requirement are assumed engineering defaults so the model
  // remains fully bound and simulatable; they are NOT factual claims.
  // ----------------------------------------------------------------

  // Electrical / motor (assumed defaults)
  parameter Real R         = 1.0    "Winding resistance at ambient [Ohm]";
  parameter Real L         = 1.0e-3  "Winding inductance [H]";
  parameter Real Kt        = 0.05   "Torque constant [N.m/A]";
  parameter Real Ke        = 0.05   "Back-EMF constant [V.s/rad]";
  parameter Real J_motor   = 1.0e-4 "Motor rotor inertia [kg.m2]";
  parameter Real b_motor   = 1.0e-5 "Motor viscous friction [N.m.s/rad]";

  // Transmission
  parameter Real N_belt    = 2.0    "Belt reduction ratio (motor:screw)";
  parameter Real pitch     = 0.005  "Ball screw pitch [m/rev]";
  parameter Real eta_screw = 0.9    "Screw transmission efficiency";
  parameter Real m_load    = 18.0   "Carriage mass [kg]";
  parameter Real b_load    = 5.0    "Carriage viscous friction [N.s/m]";
  parameter Real F_coulomb = 2.0    "Coulomb friction force [N]";
  parameter Real backlash  = 5.0e-4 "Backlash gap [m]";
  parameter Real k_back    = 1.0e6  "Backlash contact stiffness [N/m]";
  parameter Real travel    = 0.65   "Carriage travel range [m]";

  // Controller
  parameter Real V_supply  = 24.0   "Nominal supply voltage [V]";
  parameter Real V_max     = 26.4   "Voltage command magnitude bound [V]";
  parameter Real Ts        = 0.004  "Control/sample period [s] (250 Hz)";
  parameter Real Kp_pos    = 600.0  "Position proportional gain [N/m]";
  parameter Real Kd_pos    = 120.0  "Position derivative gain [N.s/m]";
  parameter Real Kff_acc   = 1.0    "Feedforward acceleration gain";
  parameter Real Kp_cur    = 30.0   "Current loop proportional gain [V/A]";

  // Disturbance (middle third of 16 s run)
  parameter Real T_sim         = 16.0  "Simulation duration [s]";
  parameter Real t_dist_start  = T_sim/3     "Disturbance start time [s]";
  parameter Real t_dist_end    = 2*T_sim/3   "Disturbance end time [s]";
  parameter Real F_dist_mag    = 24.0  "Disturbance force magnitude [N]";

  // Observer
  parameter Real L_obs     = 80.0   "Disturbance observer gain [N.s/m]";

  // Thermal
  parameter Real C_th      = 80.0   "Winding thermal capacitance [J/K]";
  parameter Real R_th      = 1.5    "Winding-to-ambient thermal resistance [K/W]";
  parameter Real T_amb     = 25.0   "Ambient temperature [degC]";
  parameter Real alpha_temp= 0.00393 "Copper temperature coefficient [1/K]";

  // Reference trajectory
  parameter Real x_ref_amp = 0.15   "Reference amplitude [m]";
  parameter Real x_ref_freq= 0.15   "Reference frequency [Hz]";

  // Protection thresholds
  parameter Real T_winding_limit = 130.0 "Winding over-temperature limit [degC]";
  parameter Real i_limit         = 30.0  "Overcurrent limit [A]";
  parameter Real omega_limit     = 600.0 "Overspeed limit [rad/s]";
  parameter Real err_limit       = 0.036 "Tracking error acceptance limit [m]";
  parameter Real recovery_threshold = 0.001 "Recovery error threshold [m]";

  // ---- Continuous states ----
  Real i_motor(start=0)       "Motor winding current [A]";
  Real omega_motor(start=0)   "Motor angular velocity [rad/s]";
  Real theta_motor(start=0)   "Motor angular position [rad]";
  Real x_carriage(start=0)    "Carriage position [m]";
  Real v_carriage(start=0)    "Carriage velocity [m/s]";
  Real T_winding(start=T_amb) "Winding temperature [degC]";
  Real v_hat(start=0)         "Observer velocity estimate [m/s]";
  Real F_dist_est(start=0)    "Disturbance force estimate [N]";

  // ---- Discrete control / status ----
  discrete Real  V_command(start=0)     "Pre-saturation voltage command [V]";
  discrete Real  V_applied(start=0)     "Saturated applied voltage [V]";
  discrete Real  i_cmd(start=0)         "Current command [A]";
  discrete Real  F_cmd(start=0)         "Force command [N]";
  discrete Real  peak_error(start=0)    "Peak tracking error [m]";
  discrete Real  error_at_10_4(start=0) "Tracking error captured at t=10.4 s [m]";
  discrete Real  recovery_time(start=0) "Recovery time after disturbance end [s]";
  discrete Boolean captured_10_4(start=false) "Capture flag for t=10.4 s";
  discrete Boolean recovered(start=false)    "Recovery flag";
  discrete Boolean saturated(start=false)    "Voltage saturation flag";
  discrete Boolean thermal_ok(start=true)    "Thermal protection status";
  discrete Boolean current_ok(start=true)    "Overcurrent protection status";
  discrete Boolean overspeed_ok(start=true)  "Overspeed protection status";
  discrete Boolean travel_ok(start=true)     "Travel limit protection status";
  discrete Boolean tracking_ok(start=true)   "Tracking acceptance status";
  Boolean all_ok "Aggregated acceptance status";

  // ---- Algebraic signals ----
  Real tau_motor       "Motor torque [N.m]";
  Real K_force         "Force gain [N per N.m]";
  Real x_ideal         "Ideal position from motor angle [m]";
  Real delta           "Backlash relative displacement [m]";
  Real F_drive         "Transmitted drive force [N]";
  Real F_disturbance   "Applied disturbance force [N]";
  Real x_ref           "Reference position [m]";
  Real v_ref           "Reference velocity [m/s]";
  Real a_ref           "Reference acceleration [m/s2]";
  Real tracking_error  "Instantaneous tracking error [m]";
  Real terminal_error  "Terminal tracking error magnitude [m]";
  Real F_coulomb_act   "Coulomb friction force [N]";
  Real motor_loss      "Resistive copper loss [W]";

protected
  constant Real pi = Modelica.Constants.pi;

equation
  // Transmission force gain (motor torque -> linear force)
  K_force = (2*pi/pitch)*N_belt*eta_screw;

  // Smooth sinusoidal motion command
  x_ref = x_ref_amp*sin(2*pi*x_ref_freq*time);
  v_ref = 2*pi*x_ref_freq*x_ref_amp*cos(2*pi*x_ref_freq*time);
  a_ref = -((2*pi*x_ref_freq)^2)*x_ref;

  // ---- Electrical dynamics (temperature-dependent resistance) ----
  L*der(i_motor) = V_applied - R*(1 + alpha_temp*(T_winding - T_amb))*i_motor - Ke*omega_motor;
  tau_motor = Kt*i_motor;

  // ---- Motor mechanical dynamics with reaction torque from screw ----
  J_motor*der(omega_motor) = tau_motor - b_motor*omega_motor
                            - F_drive*pitch/(2*pi*N_belt)/eta_screw;
  der(theta_motor) = omega_motor;

  // ---- Backlash transmission ----
  x_ideal = theta_motor*pitch/(2*pi*N_belt);
  delta   = x_ideal - x_carriage;
  F_drive = if abs(delta) <= backlash/2 then 0.0
            else k_back*(delta - (if delta > 0 then backlash/2 else -backlash/2));

  // ---- Carriage dynamics (Coulomb via smooth tanh) ----
  F_coulomb_act = F_coulomb*tanh(v_carriage/0.01);
  m_load*der(v_carriage) = F_drive - b_load*v_carriage - F_coulomb_act - F_disturbance;
  der(x_carriage) = v_carriage;

  // ---- Disturbance applied over middle third of run ----
  F_disturbance = if (time >= t_dist_start and time <= t_dist_end) then F_dist_mag else 0.0;

  // ---- Thermal dynamics ----
  motor_loss = R*(1 + alpha_temp*(T_winding - T_amb))*i_motor*i_motor;
  C_th*der(T_winding) = motor_loss - (T_winding - T_amb)/R_th;

  // ---- Tracking error ----
  tracking_error = x_carriage - x_ref;
  terminal_error = abs(tracking_error);

  // ---- Disturbance observer (Luenberger-type, no second derivative) ----
  der(v_hat)      = (F_drive - b_load*v_hat - F_coulomb*tanh(v_hat/0.01) - F_dist_est)/m_load;
  der(F_dist_est) = L_obs*(v_hat - v_carriage);

  // ---- Aggregated acceptance (fail-closed) ----
  all_ok = thermal_ok and current_ok and overspeed_ok and travel_ok
           and tracking_ok and recovered;

  // ---- Sampled cascaded control and status at 250 Hz ----
  when sample(0, Ts) then
    // Position/velocity loop with feedforward and disturbance rejection
    F_cmd      = Kp_pos*(x_ref - x_carriage) + Kd_pos*(v_ref - v_carriage)
                 + m_load*a_ref*Kff_acc - F_dist_est;
    i_cmd      = F_cmd / K_force;
    V_command  = Kp_cur*(i_cmd - i_motor);
    saturated  = abs(V_command) > V_max;
    V_applied  = if V_command > V_max then V_max
                 else (if V_command < -V_max then -V_max else V_command);

    // Peak tracking error
    if abs(tracking_error) > pre(peak_error) then
      peak_error = abs(tracking_error);
    else
      peak_error = pre(peak_error);
    end if;

    // Capture tracking error at t = 10.4 s (acceptance checkpoint)
    if time >= 10.4 and not pre(captured_10_4) then
      error_at_10_4 = abs(tracking_error);
      captured_10_4 = true;
    else
      error_at_10_4 = pre(error_at_10_4);
      captured_10_4 = pre(captured_10_4);
    end if;

    // Recovery: elapsed time after disturbance end until error below threshold
    if time > t_dist_end and abs(tracking_error) < recovery_threshold and not pre(recovered) then
      recovered     = true;
      recovery_time = time - t_dist_end;
    else
      recovered     = pre(recovered);
      recovery_time = pre(recovery_time);
    end if;

    // Protection latches (fail-closed: once tripped, stays tripped)
    thermal_ok   = pre(thermal_ok)   and (T_winding        <= T_winding_limit);
    current_ok   = pre(current_ok)   and (abs(i_motor)     <= i_limit);
    overspeed_ok = pre(overspeed_ok) and (abs(omega_motor) <= omega_limit);
    travel_ok    = pre(travel_ok)    and (abs(x_carriage)  <= travel);
    tracking_ok  = pre(tracking_ok) and (pre(error_at_10_4) <= err_limit or not pre(captured_10_4));
  end when;

  annotation (
    Documentation(info="BallScrewRecoverE: 24 V motor driving 18 kg carriage via 5 mm pitch
      ball screw with belt reduction, backlash, Coulomb friction, 0.65 m travel.
      Cascaded current (inner) and position (outer) loops command motor voltage,
      bounded to +-26.4 V, with feedforward and a Luenberger disturbance observer.
      24 N disturbance applied over the middle third of a 16 s, 250 Hz run.
      Records voltage, current, mechanical state, disturbance estimate, and
      winding temperature. Acceptance is fail-closed via latched protection flags."),
    experiment(StopTime=16.0, Tolerance=1e-6, Interval=0.004)
  );
end BallScrewRecoverE;