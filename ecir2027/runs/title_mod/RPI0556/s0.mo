model SeriesElasticPositionD
  // ---- Physical parameters (SI) ----
  parameter Real V_supply   = 48.0  "Supply voltage limit [V]";
  parameter Real N           = 100.0 "Gearbox ratio";
  parameter Real k_spring    = 850.0 "Series torsional spring stiffness [N.m/rad]";
  parameter Real R           = 0.5   "Winding resistance [ohm]";
  parameter Real L           = 1.0e-3 "Winding inductance [H]";
  parameter Real Kt          = 0.05  "Torque constant [N.m/A]";
  parameter Real Ke          = 0.05  "Back-EMF constant [V.s/rad]";
  parameter Real J_m         = 1.0e-5 "Motor rotor inertia [kg.m2]";
  parameter Real b_m         = 1.0e-6 "Motor viscous friction [N.m.s/rad]";
  parameter Real J_load      = 0.1   "Driven rigid-body inertia [kg.m2]";
  parameter Real b_load      = 0.1   "Load viscous friction [N.m.s/rad]";
  parameter Real tau_gravity = 3.0   "Constant gravity/load torque [N.m]";
  parameter Real tau_disturb = 8.0   "Disturbance amplitude [N.m]";
  parameter Real theta_max   = 1.5   "Upper travel limit [rad]";
  parameter Real theta_min   = -1.5  "Lower travel limit [rad]";
  parameter Real k_stop      = 1.0e5 "Travel-stop stiffness [N.m/rad]";
  parameter Real c_stop      = 100.0 "Travel-stop damping [N.m.s/rad]";

  // ---- Thermal model ----
  parameter Real C_th  = 50.0 "Winding thermal capacitance [J/K]";
  parameter Real R_th  = 2.0  "Winding thermal resistance [K/W]";
  parameter Real T_amb = 25.0 "Ambient temperature [degC]";

  // ---- Controller parameters ----
  parameter Real Ts       = 0.005 "Sample time [s] (200 Hz)";
  parameter Real V_max    = 48.0  "Voltage saturation [V]";
  parameter Real i_max    = 15.0  "Current limit [A]";
  parameter Real tau_max  = 25.0  "Spring-torque limit [N.m]";
  parameter Real Kp_pos   = 200.0 "Position proportional gain [N.m/rad]";
  parameter Real Ki_pos   = 400.0 "Position integral gain [N.m/(rad.s)]";
  parameter Real Kd_pos   = 5.0   "Position derivative gain [N.m.s/rad]";
  parameter Real Kaw_pos  = 0.5   "Position anti-windup gain";
  parameter Real Kp_cur   = 2.0   "Current proportional gain [V/A]";
  parameter Real Ki_cur   = 500.0 "Current integral gain [V/(A.s)]";
  parameter Real Kaw_cur  = 0.5   "Current anti-windup gain";
  parameter Real theta_target = 1.0 "Nonzero target output position [rad]";
  parameter Real t_ramp   = 1.0   "Reference ramp duration [s]";

  // ---- Continuous states ----
  Real i          "Motor winding current [A]";
  Real T_w        "Winding temperature [degC]";
  Real theta_m    "Motor angle [rad]";
  Real omega_m    "Motor speed [rad/s]";
  Real theta_load "Output position [rad]";
  Real omega_load "Output velocity [rad/s]";

  // ---- Discrete controller states ----
  discrete Real xi_pos(start=0.0) "Position-loop integrator";
  discrete Real xi_cur(start=0.0) "Current-loop integrator";
  discrete Real V_cmd(start=0.0)          "Commanded voltage [V]";
  discrete Real tau_spring_ref(start=0.0) "Spring-torque reference [N.m]";
  discrete Real i_ref(start=0.0)          "Current reference [A]";

  // ---- Discrete scratch (assigned inside when) ----
  discrete Real e_pos_d;
  discrete Real tau_unsat_pos;
  discrete Real tau_sat_pos;
  discrete Real e_cur_d;
  discrete Real V_unsat;
  discrete Real V_sat;

  // ---- Derived / continuous signals ----
  Real tau_spring "Spring torque [N.m]";
  Real F_coll     "Collision/limit force [N.m]";
  Real tau_dist   "Applied disturbance torque [N.m]";
  Real theta_cmd  "Reference trajectory [rad]";
  Real track_err  "Tracking error [rad]";

  // ---- Sensor traces ----
  Real i_meas         "Measured current [A]";
  Real theta_out_meas "Measured output position [rad]";
  Real omega_out_meas "Measured output velocity [rad/s]";
  Real T_w_meas       "Measured winding temperature [degC]";

initial equation
  i = 0.0;
  T_w = T_amb;
  theta_m = 0.0;
  omega_m = 0.0;
  theta_load = 0.0;
  omega_load = 0.0;

equation
  // ---- Smooth nonzero reference (raised cosine to target) ----
  theta_cmd = if time <= t_ramp then
                0.5*theta_target*(1.0 - cos(Modelica.Constants.pi*time/t_ramp))
              else theta_target;

  // ---- Electrical dynamics ----
  L*der(i) = V_cmd - R*i - Ke*omega_m;

  // ---- Motor mechanical dynamics ----
  J_m*der(omega_m) = Kt*i - tau_spring/N - b_m*omega_m;
  der(theta_m) = omega_m;

  // ---- Series-elastic spring between gearbox output and load ----
  tau_spring = k_spring*(theta_m/N - theta_load);

  // ---- Travel limits with collision (stiff stop-damper) ----
  F_coll = if theta_load > theta_max then
             -k_stop*(theta_load - theta_max) - c_stop*max(omega_load, 0.0)
           elseif theta_load < theta_min then
             -k_stop*(theta_load - theta_min) - c_stop*min(omega_load, 0.0)
           else 0.0;

  // ---- Load disturbance: trapezoid over the middle third of 14 s ----
  tau_dist = if (time < 14.0/3.0) or (time > 28.0/3.0) then 0.0
             elseif time < 14.0/3.0 + 1.0 then
               tau_disturb*(time - 14.0/3.0)/1.0
             elseif time > 28.0/3.0 - 1.0 then
               tau_disturb*(28.0/3.0 - time)/1.0
             else tau_disturb;

  // ---- Load (driven rigid body) dynamics ----
  J_load*der(omega_load) = tau_spring - b_load*omega_load - tau_gravity - tau_dist + F_coll;
  der(theta_load) = omega_load;

  // ---- Winding thermal model ----
  C_th*der(T_w) = i*i*R - (T_w - T_amb)/R_th;

  // ---- Sensors ----
  i_meas         = i;
  theta_out_meas = theta_load;
  omega_out_meas = omega_load;
  T_w_meas       = T_w;
  track_err      = theta_cmd - theta_load;

  // ---- Cascaded current + position/torque controller at 200 Hz ----
  when sample(0, Ts) then
    // Outer position -> spring-torque reference (PI+D with anti-windup)
    e_pos_d       = theta_cmd - theta_load;
    tau_unsat_pos = Kp_pos*e_pos_d + Ki_pos*pre(xi_pos) - Kd_pos*omega_load;
    tau_sat_pos   = if tau_unsat_pos > tau_max then tau_max
                    elseif tau_unsat_pos < -tau_max then -tau_max
                    else tau_unsat_pos;
    xi_pos        = pre(xi_pos) + Ts*(e_pos_d - Kaw_pos*(tau_unsat_pos - tau_sat_pos));
    tau_spring_ref = tau_sat_pos;
    i_ref         = tau_spring_ref/(N*Kt);

    // Inner current -> voltage command (PI with anti-windup and 48 V saturation)
    e_cur_d = i_ref - i;
    V_unsat = Kp_cur*e_cur_d + Ki_cur*pre(xi_cur);
    V_sat   = if V_unsat > V_max then V_max
              elseif V_unsat < -V_max then -V_max
              else V_unsat;
    xi_cur  = pre(xi_cur) + Ts*(e_cur_d - Kaw_cur*(V_unsat - V_sat));
    V_cmd   = V_sat;
  end when;

  // ---- Required bounds ----
  assert(abs(V_cmd) <= V_max + 1.0e-6, "Voltage bound violated");
  assert(abs(i) <= i_max + 1.0, "Current bound violated");
  assert(theta_load >= theta_min - 1.0e-3 and theta_load <= theta_max + 1.0e-3,
         "Travel bound violated");
  assert(T_w <= 80.0, "Temperature bound violated");
  assert(time < 9.1 or abs(track_err) <= 0.03,
         "Primary tracking error exceeded 0.03 rad after 9.1 s");

  annotation(experiment(StopTime=14.0, Tolerance=1.0e-6));
end SeriesElasticPositionD;