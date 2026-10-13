model CableWinchPositionD
  "Instrumented electromechanical winch actuator with cascaded current/position control,
   cable-tension/motor-speed inner loops, anti-windup, physical travel limits, and
   a mid-run output load disturbance."

  // ---- Plant embodiment (stated by requirement) ----
  parameter Real V_supply   = 72.0  "V, motor supply / voltage limit";
  parameter Real gear        = 45.0  "gearbox ratio";
  parameter Real r_drum       = 0.09  "m, drum radius";
  parameter Real m_payload   = 140.0 "kg, lifted payload";
  parameter Real g            = 9.81  "m/s^2";
  parameter Real travel_max   = 12.0  "m, cable travel";
  parameter Real target       = 5.0   "m, nonzero target output position";

  // ---- Assumed motor / thermal parameters (not specified by requirement) ----
  parameter Real R          = 0.3   "ohm, winding resistance";
  parameter Real L          = 0.003 "H, winding inductance";
  parameter Real Ke         = 0.1   "V*s/rad, back-EMF constant";
  parameter Real Kt         = 0.1   "N*m/A, torque constant";
  parameter Real J_motor    = 0.0005 "kg*m^2, rotor inertia";
  parameter Real b_visq     = 0.0005 "N*m*s/rad, viscous friction";
  parameter Real T_amb      = 25.0  "degC, ambient";
  parameter Real Rth        = 0.5   "K/W, thermal resistance";
  parameter Real C_winding  = 1000.0 "J/K, winding heat capacity";

  // ---- Physical limit / collision parameters (assumed) ----
  parameter Real k_limit    = 1.0e6 "N/m, limit stiffness";
  parameter Real c_limit    = 1.0e4 "N*s/m, limit damping";

  // ---- Controller gains (assumed tunings) ----
  parameter Real Kp_pos     = 2.5   "1/s, position gain";
  parameter Real v_max      = 1.0   "m/s, velocity command cap";
  parameter Real Kp_vel     = 300.0 "N/(m/s), speed/tension proportional gain";
  parameter Real Ki_vel     = 600.0 "N/m, speed/tension integral gain";
  parameter Real Kaw_vel    = 5.0   "anti-windup gain (tension loop)";
  parameter Real i_max       = 60.0  "A, current command cap";
  parameter Real Kp_cur     = 2.0   "V/A, current proportional gain";
  parameter Real Ki_cur     = 200.0 "V/(A*s), current integral gain";
  parameter Real Kaw_cur    = 20.0  "anti-windup gain (current loop)";

  // ---- Disturbance (middle third of 14 s run) ----
  parameter Real dist_mag     = 8.0   "N, output load disturbance";
  parameter Real t_dist_start = 4.667 "s";
  parameter Real t_dist_end   = 9.333 "s";

  // ---- Run spec ----
  parameter Real Ts   = 0.005 "s, 200 Hz synchronization period";
  parameter Real t_end = 14.0  "s";

  // ---- Dynamic states ----
  Real i         (start=0.0)    "A, motor current (measured)";
  Real omega     (start=0.0)    "rad/s, motor speed";
  Real x         (start=0.0)    "m, cable / output position (measured)";
  Real T_winding (start=T_amb)  "degC, winding temperature (measured)";
  Real integ_vel (start=0.0)    "tension-loop integrator state";
  Real integ_cur (start=0.0)    "current-loop integrator state";

  // ---- Sensor / command traces ----
  Real v          "m/s, output velocity (measured)";
  Real tension    "N, cable tension (measured)";
  Real V_cmd      "V, voltage command";
  Real V_cmd_raw  "V, voltage command before saturation";
  Real v_cmd      "m/s, velocity command";
  Real omega_cmd  "rad/s, motor speed command";
  Real i_cmd      "A, current command";
  Real i_cmd_raw  "A, current command before saturation";
  Real dist       "N, applied output disturbance";
  Real F_limit    "N, physical-limit contact force on payload";
  Real pos_err    "m, primary tracking error";
  Real J_eff      "kg*m^2, effective inertia at motor side";
  Real tau_g      "N*m, gravity load torque at motor side";

  // ---- Bound / integrity observables ----
  Real V_bound_ok;
  Real i_bound_ok;
  Real travel_bound_ok;
  Real final_err_ok;
  Real temp_bound_ok;
  Real no_nan;
  Real sample_tick "synchronized 200 Hz trace marker";

equation
  // Effective inertia and gravity torque (motor side)
  J_eff = J_motor + m_payload*r_drum*r_drum/(gear*gear);
  tau_g = m_payload*g*r_drum/gear;

  // Kinematics: motor speed to cable velocity
  v = omega*r_drum/gear;
  der(x) = v;

  // Motor mechanical dynamics (lumped at motor side), with disturbance + limits
  der(omega) = (Kt*i - (m_payload*g + dist - F_limit)*r_drum/gear - b_visq*omega)/J_eff;

  // Motor electrical dynamics
  L*der(i) = V_cmd - R*i - Ke*omega;

  // Winding thermal model (joule heating, convective cooling)
  C_winding*der(T_winding) = i*i*R - (T_winding - T_amb)/Rth;

  // Disturbance applied during middle third of run
  dist = if (time >= t_dist_start and time <= t_dist_end) then dist_mag else 0.0;

  // Physical travel limits / collision contact force (upward-positive on payload)
  F_limit = if x < 0.0 then
              (-k_limit*x - c_limit*v)
            elseif x > travel_max then
              (-k_limit*(x - travel_max) - c_limit*v)
            else
              0.0;

  // Outer position loop (P) -> velocity command with saturation
  pos_err   = target - x;
  v_cmd     = max(-v_max, min(v_max, Kp_pos*pos_err));
  omega_cmd = v_cmd*gear/r_drum;

  // Cascaded motor-speed / cable-tension loop (PI) -> current command
  // Gravity is explicitly compensated; anti-windup by back-calculation
  i_cmd_raw = (m_payload*g + Kp_vel*(v_cmd - v) + Ki_vel*integ_vel)*r_drum/(gear*Kt);
  i_cmd     = max(-i_max, min(i_max, i_cmd_raw));
  der(integ_vel) = (v_cmd - v) - Kaw_vel*(i_cmd_raw - i_cmd);

  // Inner current loop (PI) -> voltage command with supply saturation
  // Resistive and back-EMF feedforward included; anti-windup by back-calculation
  V_cmd_raw = Kp_cur*(i_cmd - i) + Ki_cur*integ_cur + R*i + Ke*omega;
  V_cmd     = max(-V_supply, min(V_supply, V_cmd_raw));
  der(integ_cur) = (i_cmd - i) - Kaw_cur*(V_cmd_raw - V_cmd);

  // Cable tension sensor (massless cable transmits motor torque directly)
  tension = Kt*i*gear/r_drum;

  // Synchronized 200 Hz trace marker
  sample_tick = floor(time/Ts)*Ts;

  // Bound / integrity observables
  V_bound_ok     = if abs(V_cmd) <= V_supply + 1.0e-6 then 1.0 else 0.0;
  i_bound_ok     = if abs(i)     <= i_max + 1.0e-6   then 1.0 else 0.0;
  travel_bound_ok= if (x >= -1.0e-6 and x <= travel_max + 1.0e-6) then 1.0 else 0.0;
  final_err_ok   = if (time >= 9.1 and abs(pos_err) < 0.03) then 1.0
                   elseif (time < 9.1) then 1.0 else 0.0;
  temp_bound_ok  = if T_winding <= 80.0 then 1.0 else 0.0;
  no_nan = if (abs(i) < 1.0e30 and abs(omega) < 1.0e30 and abs(x) < 1.0e30 and
              abs(V_cmd) < 1.0e30 and abs(T_winding) < 1.0e30 and
              abs(tension) < 1.0e30 and abs(v) < 1.0e30) then 1.0 else 0.0;

  annotation (
    experiment(StopTime = 14.0, Tolerance = 1.0e-6, Interval = 0.005),
    __OpenModelica_simulationFlags(s = "dassl")
  );
end CableWinchPositionD;