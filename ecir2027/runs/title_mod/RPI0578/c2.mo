model CableWinchPositionB
  "Electromechanical cable-winch actuator: move output to a nonzero target and hold against gravity and load"

  // ===== Physical parameters (facts from requirement) =====
  parameter Real V_supply = 72.0  "Nominal motor supply voltage [V]";
  parameter Real V_max    = 59.0  "Allowed command voltage magnitude [V]";
  parameter Real N         = 45.0  "Gearbox ratio";
  parameter Real r_drum    = 0.09  "Drum radius [m]";
  parameter Real m_payload = 140.0 "Payload mass [kg]";
  parameter Real g         = 9.81  "Gravity [m/s2]";
  parameter Real x_max     = 12.0  "Cable travel limit [m]";

  // ===== Assumed motor / drum parameters (not stated; chosen for physically consistent 72 V drive) =====
  parameter Real eta_g   = 0.9    "Gearbox efficiency";
  parameter Real Ra      = 0.5    "Armature resistance [ohm]";
  parameter Real La      = 0.01   "Armature inductance [H]";
  parameter Real Ke      = 0.2    "Back-EMF constant [V.s/rad]";
  parameter Real Kt      = 0.2    "Torque constant [N.m/A]";
  parameter Real J_motor = 0.0001 "Motor inertia [kg.m2]";
  parameter Real J_drum  = 0.02   "Drum inertia [kg.m2]";
  parameter Real b_motor = 0.0001 "Motor viscous friction [N.m.s/rad]";
  parameter Real T_amb   = 25.0   "Ambient temperature [degC]";
  parameter Real Rth     = 1.0    "Winding thermal resistance [K/W]";
  parameter Real Cth     = 200.0  "Winding thermal capacitance [J/K]";
  parameter Real k_stop  = 1.0e6  "End-stop spring stiffness [N/m]";
  parameter Real c_stop  = 1.0e4  "End-stop damping [N.s/m]";

  // ===== Derived parameters =====
  parameter Real Kc     = Kt * N * eta_g / r_drum "Current-to-cable-force gain [N/A]";
  parameter Real m_eff  = m_payload + (J_drum + J_motor * N * N) / (r_drum * r_drum) "Effective mass [kg]";
  parameter Real b_ref  = b_motor * N * N / (r_drum * r_drum) "Reflected viscous damping [N.s/m]";
  parameter Real i_ff   = m_payload * g / Kc "Gravity feedforward current [A]";

  // ===== Disturbance (middle third of 10 s mission) =====
  parameter Real t_dist_start = 10.0 / 3.0  "Disturbance start time [s]";
  parameter Real t_dist_end   = 2.0 * 10.0 / 3.0 "Disturbance end time [s]";
  parameter Real F_dist       = 5.6 "Controlled output load disturbance [N]";

  // ===== Target =====
  parameter Real x_target = 2.0 "Nonzero target position [m]";

  // ===== Controller (cascaded current / speed / position, 100 Hz) =====
  parameter Real Ts      = 0.01  "Controller sample period [s]";
  parameter Real Kp_pos  = 2.0   "Position-loop gain";
  parameter Real v_lim   = 0.45  "Speed command limit [m/s]";
  parameter Real Kp_spd  = 30.0  "Speed-loop proportional gain";
  parameter Real Ki_spd  = 80.0  "Speed-loop integral gain";
  parameter Real I_max   = 40.0  "Current command limit [A]";
  parameter Real Kp_cur  = 5.0   "Current-loop proportional gain";
  parameter Real Ki_cur  = 100.0 "Current-loop integral gain";

  // ===== Bounds =====
  parameter Real I_bound   = 55.0  "Current physical bound [A]";
  parameter Real T_bound   = 100.0 "Winding temperature bound [degC]";
  parameter Real err_bound = 0.036 "Tracking-error bound after 6.5 s [m]";

  // ===== Continuous states =====
  Real x(start = 0.0, fixed = true) "Cable / output position [m]";
  Real v(start = 0.0, fixed = true) "Cable / output velocity [m/s]";
  Real i(start = 0.0, fixed = true) "Motor armature current [A]";
  Real T_w(start = T_amb, fixed = true) "Winding temperature [degC]";

  // ===== Discrete controller states =====
  discrete Real v_ref_d(start = 0.0)    "Speed command [m/s]";
  discrete Real i_ref_d(start = 0.0)    "Current command [A]";
  discrete Real v_cmd_d(start = 0.0)    "Voltage command [V]";
  discrete Real integ_spd(start = 0.0)  "Speed-loop integrator";
  discrete Real integ_cur(start = 0.0)  "Current-loop integrator";
  discrete Real v_ref_raw(start = 0.0)  "Unsaturated speed command";
  discrete Real i_ref_raw(start = 0.0)  "Unsaturated current command";
  discrete Real v_cmd_raw(start = 0.0)  "Unsaturated voltage command";

  // ===== Signals =====
  Real v_cmd        "Applied motor voltage [V]";
  Real F_gravity    "Gravity force [N]";
  Real F_disturb    "Disturbance force [N]";
  Real F_collision  "End-stop contact force [N]";
  Real a            "Cable acceleration [m/s2]";

  // ===== Sensors and traces =====
  Real sensor_current      "Current sensor trace [A]";
  Real sensor_position     "Position sensor trace [m]";
  Real sensor_velocity     "Velocity sensor trace [m/s]";
  Real sensor_temperature  "Temperature sensor trace [degC]";
  Real tracking_error      "Position tracking error [m]";
  Real final_error         "Final position error [m]";

equation
  // Forces on payload (up positive)
  F_gravity = m_payload * g;
  F_disturb = if (time >= t_dist_start and time <= t_dist_end) then F_dist else 0.0;
  F_collision = if x < 0.0 then (-k_stop * x - c_stop * min(v, 0.0))
                elseif x > x_max then (-k_stop * (x - x_max) - c_stop * max(v, 0.0))
                else 0.0;

  // Mechanical dynamics reflected to the payload (rigid body + drum + motor inertia)
  a = (Kc * i - F_gravity - F_disturb + F_collision - b_ref * v) / m_eff;
  der(x) = v;
  der(v) = a;

  // Electrical dynamics (DC motor armature)
  v_cmd = v_cmd_d;
  der(i) = (v_cmd - Ra * i - Ke * N * v / r_drum) / La;

  // Lumped winding thermal dynamics
  der(T_w) = (i * i * Ra - (T_w - T_amb) / Rth) / Cth;

  // Synchronized sensor / state / command traces
  sensor_current = i;
  sensor_position = x;
  sensor_velocity = v;
  sensor_temperature = T_w;
  tracking_error = x_target - x;
  final_error = x_target - x;

  // ===== Bounds checks =====
  assert(abs(v_cmd) <= V_max + 1.0e-6, "Voltage bound violated");
  assert(abs(i) <= I_bound, "Current bound violated");
  assert(x >= -1.0e-3 and x <= x_max + 1.0e-3, "Travel bound violated");
  assert(time < 6.5 or abs(tracking_error) < err_bound, "Tracking error bound violated after 6.5 s");
  assert(T_w < T_bound, "Temperature bound violated");

algorithm
  // ===== Discrete cascaded controller at 100 Hz with anti-windup =====
  when sample(0, Ts) then
    // Outer loop: position -> speed command (saturated)
    v_ref_raw := Kp_pos * (x_target - x);
    if v_ref_raw > v_lim then
      v_ref_d := v_lim;
    elseif v_ref_raw < -v_lim then
      v_ref_d := -v_lim;
    else
      v_ref_d := v_ref_raw;
    end if;

    // Middle loop: speed -> current command (PI + gravity feedforward, conditional-integration anti-windup)
    i_ref_raw := Kp_spd * (v_ref_d - v) + integ_spd + i_ff;
    if abs(i_ref_raw) <= I_max then
      integ_spd := integ_spd + Ki_spd * (v_ref_d - v) * Ts;
    end if;
    i_ref_raw := Kp_spd * (v_ref_d - v) + integ_spd + i_ff;
    if i_ref_raw > I_max then
      i_ref_d := I_max;
    elseif i_ref_raw < -I_max then
      i_ref_d := -I_max;
    else
      i_ref_d := i_ref_raw;
    end if;

    // Inner loop: current -> voltage command (PI, conditional-integration anti-windup)
    v_cmd_raw := Kp_cur * (i_ref_d - i) + integ_cur;
    if abs(v_cmd_raw) <= V_max then
      integ_cur := integ_cur + Ki_cur * (i_ref_d - i) * Ts;
    end if;
    v_cmd_raw := Kp_cur * (i_ref_d - i) + integ_cur;
    if v_cmd_raw > V_max then
      v_cmd_d := V_max;
    elseif v_cmd_raw < -V_max then
      v_cmd_d := -V_max;
    else
      v_cmd_d := v_cmd_raw;
    end if;
  end when;

  annotation(
    experiment(StartTime = 0, StopTime = 10.0, Tolerance = 1.0e-6, Interval = 0.01),
    Documentation(info = "CableWinchPositionB: cascaded current/speed/position control with anti-windup driving a 72 V DC motor through a 45:1 gearbox and 0.09 m drum lifting a 140 kg payload over a 12 m travel. A 5.6 N output load disturbance is injected during the middle third of the 10 s mission. Motor electrical and inertial parameters are assumed where not stated.")
  );
end CableWinchPositionB;