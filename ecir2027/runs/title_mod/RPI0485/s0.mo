model DCServoPositionE
  "DC servo position actuator with cascaded current/position control, gravity load, collision stops, thermal state, and middle-third disturbance"

  // ---- Electrical parameters (48 V PMDC motor) ----
  parameter Real V_bus   = 48.0  "Bus nominal voltage [V]";
  parameter Real V_max   = 52.8  "Command magnitude bound [V]";
  parameter Real R       = 0.5   "Winding resistance [Ohm]";
  parameter Real L_w     = 0.003 "Winding inductance [H]";
  parameter Real Kt      = 0.08  "Torque constant [N.m/A]";
  parameter Real Ke      = 0.08  "Back-EMF constant [V.s/rad]";
  parameter Real I_max   = 30.0  "Current saturation [A]";

  // ---- Mechanical parameters ----
  parameter Real Jm      = 1.0e-5 "Rotor inertia [kg.m2]";
  parameter Real N_gear  = 100.0  "Gearbox ratio";
  parameter Real Jl      = 0.5    "Link inertia [kg.m2]";
  parameter Real ml      = 2.0    "Link mass [kg]";
  parameter Real ll      = 0.3    "Link COM distance [m]";
  parameter Real g       = 9.81   "Gravity [m/s2]";
  parameter Real b_fric  = 0.02   "Viscous friction at output [N.m.s/rad]";
  parameter Real theta_max = 1.57 "Travel limit [rad]";
  parameter Real k_stop  = 1.0e4  "Collision stop stiffness [N.m/rad]";
  parameter Real c_stop  = 5.0e1   "Collision stop damping [N.m.s/rad]";
  parameter Real J_eff   = Jl + Jm*N_gear*N_gear "Reflected effective inertia [kg.m2]";

  // ---- Thermal parameters ----
  parameter Real T_amb   = 25.0  "Ambient temperature [degC]";
  parameter Real Cth     = 100.0 "Winding thermal capacitance [J/K]";
  parameter Real Rth     = 1.5   "Winding thermal resistance [K/W]";

  // ---- Control parameters (cascaded, 250 Hz) ----
  parameter Real theta_ref = 1.0  "Target position [rad]";
  parameter Real Kp_pos    = 10.0 "Position proportional gain";
  parameter Real Ki_pos    = 2.0  "Position integral gain";
  parameter Real Kaw_pos   = 1.0  "Position anti-windup gain";
  parameter Real Kp_cur    = 2.0  "Current proportional gain";
  parameter Real Ki_cur    = 100.0 "Current integral gain";
  parameter Real Kaw_cur   = 5.0  "Current anti-windup gain";
  parameter Real Ts        = 0.004 "Controller sample period [s] (250 Hz)";
  parameter Real t_end     = 16.0  "Scenario end time [s]";
  parameter Real tau_dist  = 9.6   "Disturbance torque magnitude [N.m]";

  // ---- Continuous states ----
  Real i       "Winding current [A]";
  Real omega_l "Output angular velocity [rad/s]";
  Real theta_l "Output position [rad]";
  Real T_w     "Winding temperature [degC]";

  // ---- Discrete control states ----
  discrete Real integ_pos(start=0.0, fixed=true)    "Position integrator";
  discrete Real integ_cur(start=0.0, fixed=true)    "Current integrator";
  discrete Real i_cmd_unsat(start=0.0, fixed=true)  "Unsaturated current command [A]";
  discrete Real i_sat(start=0.0, fixed=true)        "Saturated current command [A]";
  discrete Real v_cmd_unsat(start=0.0, fixed=true)  "Unsaturated voltage command [V]";
  discrete Real v_sat(start=0.0, fixed=true)        "Saturated voltage command [V]";
  discrete Real e_pos(start=0.0, fixed=true)        "Position error [rad]";
  discrete Real e_cur(start=0.0, fixed=true)        "Current error [A]";

  // ---- Physical intermediates ----
  Real tau_motor "Motor electromagnetic torque [N.m]";
  Real tau_grav  "Gravity torque at output [N.m]";
  Real tau_stop  "Collision stop torque [N.m]";
  Real e_motor   "Back-EMF [V]";
  Real omega_m   "Motor angular velocity [rad/s]";
  Real tau_d     "Active disturbance torque [N.m]";

  // ---- Sensor traces ----
  Real theta_meas     "Measured output position [rad]";
  Real omega_meas     "Measured output velocity [rad/s]";
  Real i_meas         "Measured current [A]";
  Real T_meas         "Measured winding temperature [degC]";
  Real tracking_error "Primary tracking error [rad]";

initial equation
  i       = 0.0;
  omega_l = 0.0;
  theta_l = 0.0;
  T_w     = T_amb;

equation
  // Disturbance applied during middle third of scenario
  tau_d = if (time >= t_end/3.0 and time <= 2.0*t_end/3.0) then tau_dist else 0.0;

  // Gravity torque on revolute link
  tau_grav = ml * g * ll * sin(theta_l);

  // Collision / physical travel limits (spring-damper stops)
  tau_stop = if theta_l >  theta_max then -k_stop*(theta_l - theta_max) - c_stop*omega_l
       else if theta_l < -theta_max then -k_stop*(theta_l + theta_max) - c_stop*omega_l
       else 0.0;

  // Motor electromechanics
  tau_motor = Kt * i;
  e_motor   = Ke * omega_m;
  omega_m   = N_gear * omega_l;

  // Electrical winding dynamics (voltage source with back-EMF)
  L_w * der(i) = v_sat - R * i - e_motor;

  // Mechanical dynamics through ideal 100:1 gear (reflected inertia)
  J_eff * der(omega_l) = N_gear * tau_motor - tau_grav - b_fric * omega_l - tau_stop - tau_d;
  der(theta_l) = omega_l;

  // Thermal state (Joule heating, convective cooling)
  Cth * der(T_w) = R * i * i - (T_w - T_amb) / Rth;

  // Sensor traces (synchronized state)
  theta_meas     = theta_l;
  omega_meas     = omega_l;
  i_meas         = i;
  T_meas         = T_w;
  tracking_error = theta_ref - theta_l;

  // ---- Discrete cascaded controller at 250 Hz ----
  when sample(0, Ts) then
    // Position loop with back-calculation anti-windup
    e_pos         = theta_ref - theta_l;
    integ_pos     = pre(integ_pos) + Ts * (e_pos - Kaw_pos * (pre(i_cmd_unsat) - pre(i_sat)));
    i_cmd_unsat   = Kp_pos * e_pos + integ_pos;
    i_sat         = max(-I_max, min(I_max, i_cmd_unsat));
    // Current loop with back-calculation anti-windup
    e_cur         = i_sat - i;
    integ_cur     = pre(integ_cur) + Ts * (e_cur - Kaw_cur * (pre(v_cmd_unsat) - pre(v_sat)));
    v_cmd_unsat   = Kp_cur * e_cur + integ_cur;
    v_sat         = max(-V_max, min(V_max, v_cmd_unsat));
  end when;

  annotation(
    experiment(StartTime=0, StopTime=16, Tolerance=1e-6, Interval=0.004),
    Documentation(info="
      Acceptance criteria (fail-closed, verifiable from traces):
        |v_sat|     <= 52.8 V
        |i|         <= 30 A
        |theta_l|   <= 1.57 rad
        |tracking_error| < 0.027 rad for all time >= 10.4 s
        T_w bounded by T_amb + (I_max^2 * R) * Rth
        No NaN or Inf in any physical, control, or estimator variable.
      Disturbance: 9.6 N.m output load applied during middle third [5.333, 10.667] s.
      Controller: cascaded PI position (outer) -> PI current (inner), 250 Hz, anti-windup.
      Plant: 48 V PMDC motor, R, L, Kt, Ke, rotor inertia, thermal RC;
             100:1 ideal gear; revolute rigid link with gravity, viscous friction,
             and spring-damper collision stops at +/-1.57 rad.
    ")
  );
end DCServoPositionE;