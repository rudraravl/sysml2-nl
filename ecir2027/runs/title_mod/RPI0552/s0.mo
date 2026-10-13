model BallScrewRecoverF
  "Electromechanical ball-screw robotic actuator: cascaded current/position control,
   feedforward, disturbance observer, backlash, Coulomb friction, thermal dynamics.
   24 V motor drives 18 kg carriage via 5 mm-pitch ball screw with belt reduction.
   29 N disturbance applied during the middle third of a 20 s, 500 Hz mission.
   Motor and transmission parameters are representative design values where the
   requirement did not specify exact datasheet figures."

  // ---- Motor (representative 24 V DC motor) ----
  parameter Real Ra  = 2.5    "Armature resistance [ohm]";
  parameter Real La  = 5.0e-3 "Armature inductance [H]";
  parameter Real Ke  = 0.05   "Back-EMF constant [V.s/rad]";
  parameter Real Kt  = 0.05   "Torque constant [N.m/A]";
  parameter Real Jm  = 1.0e-5 "Motor rotor inertia [kg.m2]";
  parameter Real Bm  = 1.0e-6 "Motor viscous friction [N.m.s/rad]";

  // ---- Transmission ----
  parameter Real N      = 2.0   "Belt reduction ratio (motor : screw)";
  parameter Real p      = 5.0e-3 "Ball-screw pitch [m/rev]";
  parameter Real k_s    = p/(2.0*Modelica.Constants.pi)         "Linear disp per screw rad [m/rad]";
  parameter Real k_x    = p/(2.0*Modelica.Constants.pi*N)       "Linear disp per motor rad [m/rad]";
  parameter Real Kt_eff = Kt*2.0*Modelica.Constants.pi*N/p     "Force per motor current (rigid) [N/A]";
  parameter Real travel = 0.65   "Travel range [m]";

  // ---- Backlash ----
  parameter Real b_bl   = 2.0e-3 "Backlash half-angle at motor side [rad]";
  parameter Real k_bl   = 10.0    "Contact stiffness [N.m/rad]";
  parameter Real c_bl   = 0.05    "Contact damping [N.m.s/rad]";
  parameter Real eps_bl = 2.0e-4  "Backlash gate smoothing width [rad]";

  // ---- Load / friction ----
  parameter Real m         = 18.0   "Carriage mass [kg]";
  parameter Real Fc        = 5.0    "Coulomb friction force [N]";
  parameter Real v_thresh  = 1.0e-3 "Friction smoothing velocity [m/s]";
  parameter Real J_s       = 1.0e-3 "Screw inertia [kg.m2]";

  // ---- Limits ----
  parameter Real V_supply = 24.0  "Nominal supply voltage [V]";
  parameter Real Vmax     = 29.3  "Voltage saturation limit [V]";
  parameter Real i_max    = 10.0  "Current reference clamp [A]";

  // ---- Command ----
  parameter Real f_cmd  = 0.05         "Command frequency [Hz]";
  parameter Real w_cmd  = 2.0*Modelica.Constants.pi*f_cmd "Command angular frequency [rad/s]";
  parameter Real A_cmd  = 0.225        "Command amplitude [m]";

  // ---- Control gains ----
  parameter Real Kp_x   = 30.0  "Position proportional gain [A/m]";
  parameter Real Ki_x   = 100.0 "Position integral gain [A/(m.s)]";
  parameter Real Kd_x   = 3.0   "Position derivative gain [A.s/m]";
  parameter Real Kaw_x  = 1.0   "Position anti-windup gain [1/s]";
  parameter Real Kp_i   = 1.0   "Current proportional gain [V/A]";
  parameter Real Ki_i   = 200.0 "Current integral gain [V/(A.s)]";
  parameter Real Kaw_i  = 1.0   "Current anti-windup gain [1/s]";

  // ---- Observer ----
  parameter Real L_obs  = 50.0  "Disturbance-observer bandwidth [1/s]";

  // ---- Thermal ----
  parameter Real T_amb = 25.0 "Ambient temperature [degC]";
  parameter Real Rth   = 5.0  "Winding-to-ambient thermal resistance [K/W]";
  parameter Real Cth   = 50.0 "Winding thermal capacitance [J/K]";

  // ---- Disturbance ----
  parameter Real F_dist_val   = 29.0   "Disturbance force magnitude [N]";
  parameter Real t_dist_start = 20.0/3.0 "Disturbance onset (middle third) [s]";
  parameter Real t_dist_end   = 40.0/3.0 "Disturbance release [s]";

  // ---- Verification threshold ----
  parameter Real e_tol = 0.032 "Tracking-error tolerance after 13 s [m]";

  // ---- Dynamic states ----
  Real i        "Motor current [A]";
  Real theta_m  "Motor angle [rad]";
  Real omega_m  "Motor speed [rad/s]";
  Real theta_s  "Screw angle [rad]";
  Real omega_s  "Screw speed [rad/s]";
  Real d_hat    "Disturbance force estimate [N]";
  Real T_w      "Winding temperature [degC]";
  Real e_i_int  "Current-loop integral state [A]";
  Real e_x_int  "Position-loop integral state [m]";

  // ---- Derived / observable signals ----
  Real vm         "Applied motor voltage [V]";
  Real v_raw      "Unsaturated motor voltage command [V]";
  Real i_ref      "Saturated current reference [A]";
  Real i_ref_raw  "Unsaturated current reference [A]";
  Real v_ff       "Voltage feedforward [V]";
  Real i_ff       "Current feedforward [A]";
  Real F_ff       "Force feedforward [N]";
  Real omega_m_ff "Motor-speed feedforward [rad/s]";
  Real e_x        "Position tracking error [m]";
  Real e_i        "Current tracking error [A]";
  Real x_cmd      "Position command [m]";
  Real vc_cmd     "Velocity command [m/s]";
  Real a_cmd      "Acceleration command [m/s2]";
  Real x          "Carriage position [m]";
  Real v_car      "Carriage velocity [m/s]";
  Real F_fric     "Coulomb friction force [N]";
  Real F_dist     "Applied disturbance force [N]";
  Real F_motor_est "Rigid-model motor force estimate [N]";
  Real a_meas     "Measured (plant) acceleration [m/s2]";
  Real a_model    "Observer model acceleration [m/s2]";
  Real delta      "Backlash relative angle [rad]";
  Real tau_contact "Contact torque across backlash [N.m]";
  Real tau_spring "Contact spring torque [N.m]";
  Real tau_damp   "Contact damping torque [N.m]";
  Real gate_d     "Backlash contact gate [1]";
  Real peak_dev   "Peak position deviation [m]";
  Real recovering(start=1.0) "Recovery flag (1 pending, 0 recovered)";
  Real recovery_time "Time from disturbance onset to recovery [s]";
  Real terminal_error "Absolute position error (read at t=20 s) [m]";

initial equation
  i        = 0.0;
  theta_m  = 0.0;
  omega_m  = 0.0;
  theta_s  = 0.0;
  omega_s  = 0.0;
  d_hat    = 0.0;
  T_w      = T_amb;
  e_i_int  = 0.0;
  e_x_int  = 0.0;
  peak_dev   = 0.0;
  recovery_time = 0.0;

equation
  // ---- Smooth rest-to-rest motion command (within 0.65 m travel) ----
  x_cmd  = A_cmd*(1.0 - Modelica.Math.cos(w_cmd*time));
  vc_cmd = A_cmd*w_cmd*Modelica.Math.sin(w_cmd*time);
  a_cmd  = A_cmd*w_cmd*w_cmd*Modelica.Math.cos(w_cmd*time);

  // ---- Feedforward ----
  F_ff       = m*a_cmd;
  i_ff       = F_ff / Kt_eff;
  omega_m_ff = vc_cmd / k_x;
  v_ff       = Ra*i_ff + Ke*omega_m_ff;

  // ---- Smooth Coulomb friction ----
  F_fric = Fc*Modelica.Math.tanh(v_car / v_thresh);

  // ---- Kinematics ----
  v_car = omega_s * k_s;
  x     = theta_s * k_s;

  // ---- Disturbance: 29 N during middle third ----
  F_dist = if (time >= t_dist_start and time <= t_dist_end) then F_dist_val else 0.0;

  // ---- Backlash contact (smoothed) ----
  delta      = theta_m/N - theta_s;
  tau_spring = k_bl*(delta - (b_bl/2.0)*Modelica.Math.tanh(2.0*delta/b_bl));
  gate_d     = 0.5*(Modelica.Math.tanh((delta - b_bl/2.0)/eps_bl)
                     - Modelica.Math.tanh((-delta - b_bl/2.0)/eps_bl));
  tau_damp   = c_bl*(omega_m/N - omega_s)*gate_d;
  tau_contact = tau_spring + tau_damp;

  // ---- Motor electrical dynamics ----
  La*der(i) = vm - Ra*i - Ke*omega_m;

  // ---- Motor mechanical dynamics ----
  Jm*der(omega_m) = Kt*i - Bm*omega_m - tau_contact;
  der(theta_m) = omega_m;

  // ---- Screw + carriage rigid-body dynamics ----
  (J_s + m*k_s*k_s)*der(omega_s) = tau_contact - (F_fric + F_dist)*k_s;
  der(theta_s) = omega_s;

  // ---- Disturbance observer (force estimate) ----
  F_motor_est = Kt_eff * i;
  a_meas  = k_s*der(omega_s);
  a_model = (F_motor_est - d_hat - F_fric) / m;
  der(d_hat) = L_obs*(a_meas - a_model);

  // ---- Outer position loop (cascaded) ----
  e_x       = x_cmd - x;
  i_ref_raw = Kp_x*e_x + Ki_x*e_x_int + Kd_x*(vc_cmd - v_car)
              + i_ff - d_hat/Kt_eff;
  i_ref = if i_ref_raw > i_max then i_max
          else if i_ref_raw < -i_max then -i_max
          else i_ref_raw;
  der(e_x_int) = e_x - Kaw_x*(i_ref_raw - i_ref);

  // ---- Inner current loop (cascaded) ----
  e_i   = i_ref - i;
  v_raw = Kp_i*e_i + Ki_i*e_i_int + v_ff;
  vm    = if v_raw > Vmax then Vmax
          else if v_raw < -Vmax then -Vmax
          else v_raw;
  der(e_i_int) = e_i - Kaw_i*(v_raw - vm);

  // ---- Winding thermal dynamics ----
  Cth*der(T_w) = i*i*Ra - (T_w - T_amb)/Rth;

  // ---- Verification evidence ----
  // Peak position deviation
  when abs(x_cmd - x) > pre(peak_dev) then
    peak_dev = abs(x_cmd - x);
  end when;

  // Recovery time: first time error drops below tolerance after disturbance onset
  when time > t_dist_start and abs(x_cmd - x) < e_tol and pre(recovering) > 0.5 then
    recovering     = 0.0;
    recovery_time  = time - t_dist_start;
  end when;

  // Terminal error (continuous; read value at t = 20 s)
  terminal_error = abs(e_x);

  annotation(
    experiment(StartTime = 0, StopTime = 20, Tolerance = 1e-6, Interval = 0.002),
    Documentation(info = "<html>
<p>Ball-screw robotic actuator scenario. 24 V motor drives 18 kg carriage through
5 mm-pitch ball screw with belt reduction (N=2), backlash, and Coulomb friction.
Cascaded current/position loops command motor voltage (limited to 29.3 V) with
feedforward motion control and a disturbance observer. A 29 N disturbance is
applied during the middle third (6.67–13.33 s). Winding temperature tracked via
first-order thermal model. Mission: 20 s at 500 Hz.</p>
<p>Motor, screw, belt, backlash, friction, and thermal parameters are
representative design values; exact datasheet figures were not specified in the
requirement and are treated as unknown.</p>
</html>")
  );
end BallScrewRecoverF;