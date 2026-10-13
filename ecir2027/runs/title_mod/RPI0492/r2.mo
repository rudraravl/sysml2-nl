model DCServoSpeedF
  // Complete PMDC robotic servo speed scenario.
  // Values not stated in the requirement are representative bindings chosen to make
  // an executable model; they are not claimed facts from the request.

  parameter Real T_run=20.0 "s, total run duration";
  parameter Real Ts=0.002 "s, 500 Hz control and trace interval";
  parameter Real V_nom=48.0 "V, nominal DC motor/bus voltage";
  parameter Real V_max=58.6 "V, independent voltage saturation limit";
  parameter Real I_max=30.0 "A, independent current saturation limit (not specified)";
  parameter Real n=100.0 "gear ratio, motor speed / output speed";
  parameter Real eta_g=0.90 "gearbox efficiency (not specified)";
  parameter Real R=0.10 "Ohm, armature resistance";
  parameter Real L=0.010 "H, armature inductance";
  parameter Real Kt=0.030 "N.m/A, torque constant";
  parameter Real Ke=0.030 "V.s/rad, back-emf constant";
  parameter Real J_m=1.0e-5 "kg.m2, rotor inertia";
  parameter Real J_l=0.50 "kg.m2, link/output inertia (not specified)";
  parameter Real J_eq=J_m*n*n + J_l "kg.m2, equivalent inertia at output";
  parameter Real b_v=0.050 "N.m.s/rad, viscous friction (not specified)";
  parameter Real tau_c=0.20 "N.m, Coulomb friction magnitude (not specified)";
  parameter Real omega_reg=0.010 "rad/s, friction regularization speed";
  parameter Real T_dist=17.4 "N.m, load torque disturbance during middle third";
  parameter Real R_batt=0.050 "Ohm, battery internal resistance/droop (not specified)";
  parameter Real Q_nom=5.0 "Ah, battery capacity (not specified)";
  parameter Real SoC0=0.90 "initial state-of-charge (not specified)";
  parameter Real SoC_min=0.10 "lower SoC bound (not specified)";
  parameter Real SoC_max=1.00 "upper SoC bound";
  parameter Real C_th=50.0 "J/K, thermal capacitance (not specified)";
  parameter Real R_th=2.0 "K/W, thermal resistance (not specified)";
  parameter Real T_amb=293.15 "K, ambient temperature";
  parameter Real T_max=353.15 "K, thermal bound (not specified)";
  parameter Real w_ref=10.0 "rad/s, declared mission output speed (not specified)";
  parameter Real t_acc=3.0 "s, acceleration ramp time (not specified)";
  parameter Real t_hold_end=T_run - t_acc "s, end of hold speed";
  parameter Real t_dist_start=T_run/3.0 "s, start of middle-third load";
  parameter Real t_dist_end=2.0*T_run/3.0 "s, end of middle-third load";
  parameter Real Kp_w=50.0 "A/(rad/s), speed proportional gain";
  parameter Real Ki_w=300.0 "A/rad, speed integral gain";
  parameter Real Kp_i=10.0 "V/A, current proportional gain";
  parameter Real w_max=12.0 "rad/s, speed bound";
  parameter Real a_max=50.0 "rad/s2, acceleration bound";

  Real i(start=0.0) "A, armature/phase current";
  Real omega_out(start=0.0) "rad/s, output speed";
  Real theta_out(start=0.0) "rad, output position";
  Real T(start=T_amb) "K, motor thermal state";
  Real SoC(start=SoC0) "dimensionless, battery state-of-charge";

  discrete Real int(start=0.0) "speed-controller integral state";
  discrete Real e(start=0.0) "rad/s, sampled speed error";
  discrete Real i_unsat(start=0.0) "A, unsaturated current command";
  discrete Real i_ref(start=0.0) "A, saturated current command";
  discrete Real v_unsat(start=0.0) "V, unsaturated voltage command";
  discrete Real v_cmd(start=0.0) "V, saturated voltage command";

  Real ref "rad/s, speed command profile";
  Real tracking_error "rad/s, primary tracking error";
  Real a_out "rad/s2, output acceleration";
  Real omega_m "rad/s, motor speed";
  Real theta_motor "rad, rotor position";
  Real tau_motor "N.m, motor torque";
  Real tau_gear "N.m, gearbox output torque";
  Real tau_fric "N.m, mechanical friction torque";
  Real tau_load "N.m, applied load torque";
  Real V_oc "V, battery open-circuit voltage";
  Real V_bus "V, DC-bus voltage";
  Real V_bus_clip "V, positive bus voltage limit applied to actuator";
  Real v_motor "V, actual motor voltage";
  Real I_bus "A, DC-bus current";
  Real P_batt "W, battery power";
  Real P_loss_elec "W, copper loss";
  Real P_loss_gear "W, gearbox loss";
  Real P_loss_fric "W, friction loss";
  Real P_loss "W, total loss";
  Real SoC_percent "%, state-of-charge";

equation
  // Mission speed profile: accelerate, hold, decelerate to rest.
  ref = if time <= t_acc then w_ref*time/t_acc
       elseif time <= t_hold_end then w_ref
       elseif time <= T_run then w_ref*(T_run - time)/(T_run - t_hold_end)
       else 0.0;

  // Middle-third load torque disturbance.
  tau_load = if time >= t_dist_start and time <= t_dist_end then T_dist else 0.0;

  // Battery model with state-of-charge and droop.
  V_oc = V_nom + (V_max - V_nom)*SoC;
  V_bus = V_oc - R_batt*i;
  V_bus_clip = max(0.0, min(V_bus, V_max));
  I_bus = i;
  P_batt = V_bus*i;
  der(SoC) = if SoC <= 0.0 and i > 0.0 then 0.0
             elseif SoC >= 1.0 and i < 0.0 then 0.0
             else -i/(3600.0*Q_nom);
  SoC_percent = 100.0*SoC;

  // Motor electrical dynamics.
  omega_m = n*omega_out;
  L*der(i) = v_motor - R*i - Ke*omega_m;

  // Electromechanical torque and gearbox.
  tau_motor = Kt*i;
  tau_gear = eta_g*n*tau_motor;

  // Mechanical friction and load dynamics.
  tau_fric = b_v*omega_out + tau_c*tanh(omega_out/omega_reg);
  J_eq*der(omega_out) = tau_gear - tau_load - tau_fric;
  der(theta_out) = omega_out;
  theta_motor = n*theta_out;
  a_out = der(omega_out);

  // Thermal state.
  P_loss_elec = R*i^2;
  P_loss_gear = (1.0 - eta_g)*abs(tau_motor*omega_m);
  P_loss_fric = tau_fric*omega_out;
  P_loss = P_loss_elec + P_loss_gear + P_loss_fric;
  C_th*der(T) = P_loss - (T - T_amb)/R_th;

  // Observation.
  tracking_error = ref - omega_out;

  // Discrete current-limited speed regulator at 500 Hz.
  when sample(0.0, Ts) then
    e = ref - omega_out;
    i_unsat = Kp_w*e + Ki_w*pre(int);
    i_ref = max(min(i_unsat, I_max), -I_max);
    v_unsat = R*i_ref + Ke*omega_m + Kp_i*(i_ref - i);
    v_cmd = max(min(v_unsat, V_max), -V_max);
    if abs(i_unsat) <= I_max and abs(v_unsat) <= V_max then
      int = pre(int) + Ts*e;
    else
      int = pre(int);
    end if;
  end when;

  // Actual motor voltage is independently limited and cannot exceed bus or V_max.
  v_motor = if v_cmd > V_bus_clip then V_bus_clip
            elseif v_cmd < -V_bus_clip then -V_bus_clip
            else v_cmd;

  // Verification bounds.
  assert(abs(v_motor) <= V_max + 1.0e-9, "Voltage bound violated");
  assert(abs(i) <= I_max + 1.0e-3, "Current bound violated");
  assert(abs(omega_out) <= w_max, "Speed bound violated");
  assert(abs(a_out) <= a_max, "Acceleration bound violated");
  assert(SoC >= SoC_min and SoC <= SoC_max, "State-of-charge bound violated");
  assert(T <= T_max, "Thermal bound violated");
  assert(time < 13.0 or abs(tracking_error) <= 0.2 + 1.0e-9, "Tracking error > 0.2 rad/s after 13 s");

  // Finite-value checks for physical, control, and sensor variables.
  assert(abs(i) < 1.0e9, "Non-finite armature current");
  assert(abs(v_motor) < 1.0e9, "Non-finite motor voltage");
  assert(abs(omega_out) < 1.0e9, "Non-finite output speed");
  assert(abs(a_out) < 1.0e9, "Non-finite acceleration");
  assert(SoC > -1.0e9 and SoC < 1.0e9, "Non-finite state-of-charge");
  assert(T > -1.0e9 and T < 1.0e9, "Non-finite thermal state");
  assert(abs(v_cmd) < 1.0e9, "Non-finite voltage command");
  assert(abs(i_ref) < 1.0e9, "Non-finite current command");
  assert(abs(tracking_error) < 1.0e9, "Non-finite tracking error");
  assert(abs(V_bus) < 1.0e9, "Non-finite DC-bus voltage");
  assert(abs(P_batt) < 1.0e9, "Non-finite battery power");

  annotation (experiment(StopTime=20.0, Interval=0.002, Tolerance=1.0e-6));
end DCServoSpeedF;