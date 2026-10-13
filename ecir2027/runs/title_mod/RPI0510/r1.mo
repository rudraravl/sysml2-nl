model BLDCWheelPositionF
  "BLDC FOC wheel position control scenario - electromechanical robotic actuator"

  // ---- Electrical / motor parameters
  parameter Real Vbat = 48.0 "Battery nominal voltage [V]";
  parameter Real Rbat = 0.05 "Battery internal resistance [Ohm]";
  parameter Real Rw = 0.10 "Winding resistance [Ohm]";
  parameter Real Lq = 0.5e-3 "Q-axis inductance [H]";
  parameter Real p_poles = 4.0 "Pole pairs";
  parameter Real Ke = 0.05 "Back-EMF constant [V s/rad mech]";
  parameter Real Kt = 0.05 "Torque constant [N m/A]";
  parameter Real J_m = 1.0e-5 "Motor inertia [kg m2]";
  parameter Real J_w = 1.0e-2 "Wheel inertia [kg m2]";
  parameter Real b_m = 1.0e-6 "Motor viscous friction [N m s]";
  parameter Real b_w = 1.0e-4 "Wheel viscous friction [N m s]";
  parameter Real r_w = 0.12 "Wheel radius [m]";
  parameter Real N = 9.0 "Gear ratio";
  parameter Real theta_limit = 3.14159265358979 "Output travel limit [rad]";

  // ---- Mechanical limits / collision (rigid body joint with physical limits)
  parameter Real k_collision = 1000.0 "Collision stiffness [N m/rad]";
  parameter Real b_collision = 10.0 "Collision damping [N m s/rad]";

  // ---- Thermal model
  parameter Real T_amb = 25.0 "Ambient temperature [degC]";
  parameter Real C_th = 50.0 "Winding thermal capacitance [J/K]";
  parameter Real R_th = 0.5 "Winding thermal resistance [K/W]";

  // ---- Control / scenario
  parameter Real Ts = 0.002 "Control sample time [s] (500 Hz)";
  parameter Real theta_ref = 1.0 "Target output position [rad]";
  parameter Real F_load = 11.6 "Output load disturbance [N]";
  parameter Real Vmax_bus = 58.6 "Max DC bus voltage [V]";
  parameter Real Vmax_phase = 27.7 "Max phase voltage [V] (approx Vbus/sqrt(3))";
  parameter Real Imax = 20.0 "Max phase current command [A]";
  parameter Real Imax_verify = 25.0 "Current verification bound [A]";
  parameter Real Tmax = 1.5 "Max motor torque [N m]";
  parameter Real omega_max = 50.0 "Max output speed command [rad/s]";
  parameter Real Tmax_winding = 80.0 "Winding temperature bound [degC]";

  // ---- Controller gains
  parameter Real Kp_pos = 8.0 "Position proportional gain";
  parameter Real Kd_pos = 0.3 "Position derivative gain";
  parameter Real Kp_vel = 0.5 "Velocity proportional gain";
  parameter Real Ki_vel = 5.0 "Velocity integral gain";
  parameter Real Kp_cur = 0.05 "Current proportional gain";
  parameter Real Ki_cur = 100.0 "Current integral gain";

  // ---- Continuous states
  Real iq(start=0.0) "Q-axis current [A]";
  Real omega_m(start=0.0) "Motor mechanical speed [rad/s]";
  Real theta_m(start=0.0) "Motor angle [rad]";
  Real T_w(start=T_amb) "Winding temperature [degC]";

  // ---- Derived / sensor observables
  Real theta_out "Output (wheel) position [rad]";
  Real omega_out "Output (wheel) speed [rad/s]";
  Real T_motor "Motor torque [N m]";
  Real Vbus "DC bus voltage [V]";
  Real Ibus "DC bus current [A]";
  Real P_motor "Motor electrical power [W]";
  Real T_collision_wheel "Collision torque at wheel [N m]";
  Real F_load_active "Active load force [N]";
  Real err_primary "Primary tracking error [rad]";

  // ---- Discrete controller states (zero-order hold)
  discrete Real omega_ref(start=0.0) "Velocity command [rad/s]";
  discrete Real integ_vel(start=0.0) "Velocity integrator state";
  discrete Real T_ref(start=0.0) "Torque command [N m]";
  discrete Real i_ref(start=0.0) "Current command [A]";
  discrete Real integ_cur(start=0.0) "Current integrator state";
  discrete Real vq(start=0.0) "Q-axis voltage command [V]";

  // ---- Verification flags
  Boolean Vbus_ok "DC bus voltage within bound";
  Boolean I_ok "Phase current within bound";
  Boolean travel_ok "Output travel within physical limits";
  Boolean temp_ok "Winding temperature within bound";
  Boolean tracking_ok "Primary tracking error below 0.024 rad after 13 s";
  Boolean no_nan_inf_ok "No NaN or infinite physical/control/estimator values";

protected
  discrete Real omega_ref_raw(start=0.0);
  discrete Real e_vel(start=0.0);
  discrete Real T_ref_unsat(start=0.0);
  discrete Real e_cur(start=0.0);
  discrete Real vq_unsat(start=0.0);

equation
  // ---- Output kinematics (gearbox)
  theta_out = theta_m / N;
  omega_out = omega_m / N;
  T_motor = Kt * iq;

  // ---- Load disturbance active during the middle third of the 20 s run
  F_load_active = if (time >= 20.0/3.0 and time <= 40.0/3.0) then F_load else 0.0;

  // ---- Collision / physical limits at the wheel (rigid body joint stops)
  T_collision_wheel =
      if theta_out > theta_limit then
        -k_collision*(theta_out - theta_limit) - b_collision*omega_out
      else if theta_out < -theta_limit then
        -k_collision*(theta_out + theta_limit) - b_collision*omega_out
      else
        0.0;

  // ---- Mechanical dynamics in motor coordinates (driven rigid body + gearbox + wheel)
  (J_m + J_w/(N*N))*der(omega_m) =
      Kt*iq
    - (F_load_active*r_w + T_collision_wheel)/N
    - (b_m + b_w/(N*N))*omega_m;

  der(theta_m) = omega_m;

  // ---- Electrical q-axis dynamics (field-oriented control, id = 0)
  der(iq) = (vq - Rw*iq - Ke*p_poles*omega_m) / Lq;

  // ---- DC bus (battery with internal resistance)
  P_motor = 1.5 * vq * iq;
  Ibus = P_motor / 48.0;
  Vbus = Vbat - Rbat*Ibus;

  // ---- Winding thermal model (Joule heating -> ambient)
  C_th * der(T_w) = Rw*iq*iq - (T_w - T_amb)/R_th;

  // ---- Primary tracking error
  err_primary = theta_ref - theta_out;

  // ---- Verification criteria
  Vbus_ok = Vbus <= Vmax_bus + 1.0e-6;
  I_ok = abs(iq) <= Imax_verify + 1.0e-6;
  travel_ok = abs(theta_out) <= theta_limit + 1.0e-4;
  temp_ok = T_w <= Tmax_winding;
  tracking_ok = (time >= 13.0) and (abs(err_primary) < 0.024);
  // NaN/Inf check: comparisons against NaN are false, so the conjuncts are true only for finite values.
  no_nan_inf_ok =
       (iq > 0.0 or iq <= 0.0)
   and (omega_m > 0.0 or omega_m <= 0.0)
   and (theta_m > 0.0 or theta_m <= 0.0)
   and (T_w > 0.0 or T_w <= 0.0)
   and (vq > 0.0 or vq <= 0.0)
   and (integ_cur > 0.0 or integ_cur <= 0.0)
   and (integ_vel > 0.0 or integ_vel <= 0.0)
   and (theta_out > 0.0 or theta_out <= 0.0);

algorithm
  // ---- Cascaded digital controller at 500 Hz: position -> velocity -> current, with anti-windup
  when sample(0, Ts) then
    // Position (PD) -> velocity reference, saturated
    omega_ref_raw := Kp_pos*(theta_ref - theta_out) - Kd_pos*omega_out;
    omega_ref := max(-omega_max, min(omega_max, omega_ref_raw));

    // Velocity PI with conditional-integration anti-windup
    e_vel := omega_ref - omega_m;
    T_ref_unsat := Kp_vel*e_vel + Ki_vel*integ_vel;
    T_ref := max(-Tmax, min(Tmax, T_ref_unsat));
    if (T_ref_unsat > Tmax and e_vel > 0.0) or (T_ref_unsat < -Tmax and e_vel < 0.0) then
      integ_vel := integ_vel;
    else
      integ_vel := integ_vel + Ts*e_vel;
    end if;

    // Torque -> current (id = 0 FOC), current-limited
    i_ref := max(-Imax, min(Imax, T_ref / Kt));

    // Current PI with conditional-integration anti-windup, voltage-limited to phase max
    e_cur := i_ref - iq;
    vq_unsat := Kp_cur*e_cur + Ki_cur*integ_cur;
    vq := max(-Vmax_phase, min(Vmax_phase, vq_unsat));
    if (vq_unsat > Vmax_phase and e_cur > 0.0) or (vq_unsat < -Vmax_phase and e_cur < 0.0) then
      integ_cur := integ_cur;
    else
      integ_cur := integ_cur + Ts*e_cur;
    end if;
  end when;

  annotation (
    experiment(StartTime=0.0, StopTime=20.0, Tolerance=1e-6, Interval=0.002),
    Documentation(info="BLDCWheelPositionF: 48 V three-phase PM motor (4 pole pairs) driving a 0.12 m wheel through a 9:1 gearbox from a battery with internal resistance. Field-oriented (id=0) inverter with cascaded position/velocity/current control and anti-windup runs at 500 Hz for 20 s. A 11.6 N output load disturbance is applied during the middle third (6.67 s .. 13.33 s). Sensors: phase current, output position/velocity, winding temperature. Physical joint limits with collision modeled at +/- pi rad of output travel. Verification flags monitor bus voltage (<= 58.6 V), current, travel, temperature, primary tracking error (< 0.024 rad after 13 s), and finite-value integrity."));
end BLDCWheelPositionF;