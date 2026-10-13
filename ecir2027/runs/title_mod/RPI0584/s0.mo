model CableWinchSpeedB
  // ===== Stated facts (from requirement) =====
  parameter Real V_supply(unit="V") = 72            "DC supply nominal";
  parameter Real N_gb = 45                          "gearbox ratio";
  parameter Real r_drum(unit="m") = 0.09            "drum radius";
  parameter Real m_load(unit="kg") = 140             "payload mass";
  parameter Real L_travel(unit="m") = 12             "cable travel";
  parameter Real V_cmd_max(unit="V") = 59            "allowed voltage command magnitude";
  parameter Real T_dist(unit="N.m") = 8.4            "disturbance torque at drum";
  parameter Real f_sample(unit="Hz") = 100           "sensor sample rate";
  parameter Real t_end(unit="s") = 10               "mission duration";
  parameter Real err_tol(unit="m/s") = 0.3           "tracking error bound";
  parameter Real t_settle(unit="s") = 6.5           "settling time";

  // ===== Physical constants =====
  parameter Real g(unit="m/s2") = 9.81;

  // ===== Derived from stated facts =====
  parameter Real t_phase(unit="s") = t_end/3        "duration of each phase";
  parameter Real v_hold(unit="m/s") = L_travel/(2*t_phase) "hold linear speed";
  parameter Real omega_drum_hold(unit="rad/s") = v_hold/r_drum;
  parameter Real omega_motor_hold(unit="rad/s") = omega_drum_hold*N_gb;
  parameter Real a_ref(unit="m/s2") = v_hold/t_phase "reference accel magnitude";
  parameter Real weight(unit="N") = m_load*g;
  parameter Real tau_grav_drum(unit="N.m") = weight*r_drum;

  // ===== Assumed nominal physical parameters (not stated; required for simulation) =====
  parameter Real eta_gb = 0.92                       "gearbox efficiency";
  parameter Real R_a(unit="Ohm") = 0.05              "armature resistance";
  parameter Real L_a(unit="H") = 5e-4                "armature inductance";
  parameter Real k_emf(unit="V.s/rad") = 0.06        "back-EMF = torque constant";
  parameter Real J_motor(unit="kg.m2") = 1e-4        "rotor inertia";
  parameter Real J_load_drum(unit="kg.m2") = m_load*r_drum^2 "payload reflected to drum";
  parameter Real b_fric(unit="N.m.s/rad") = 1e-3     "motor-side viscous friction";
  parameter Real R_batt(unit="Ohm") = 0.03           "battery internal resistance (droop)";
  parameter Real Q_batt(unit="A.s") = 5400           "battery capacity (assumed 1.5 Ah)";
  parameter Real i_max(unit="A") = 60                "current bound (assumed)";
  parameter Real T_amb(unit="K") = 293.15            "ambient temperature";
  parameter Real C_th(unit="J/K") = 200              "motor thermal capacitance";
  parameter Real R_th(unit="K/W") = 0.5              "motor thermal resistance";
  parameter Real T_max(unit="K") = 353.15             "thermal bound (80 degC)";

  parameter Real tau_grav_motor(unit="N.m") = tau_grav_drum/(N_gb*eta_gb);
  parameter Real J_total(unit="kg.m2") = J_motor + J_load_drum/(N_gb^2);

  // ===== Controller gains (assumed, tuned) =====
  parameter Real Kp_w = 0.5                          "speed loop gain (V per rad/s)";
  parameter Real Ki_w = 5.0                         "speed loop integral gain";
  parameter Real Kp_t = 0.005                        "tension loop proportional gain";
  parameter Real Ki_t = 0.02                         "tension loop integral gain";

  // ===== Dynamic states =====
  Real theta_motor(unit="rad")    "rotor position sensor";
  Real omega_motor(unit="rad/s")  "rotor speed";
  Real i_arm(unit="A")            "armature/phase current";
  Real SOC(start=1.0)             "battery state of charge (0..1)";
  Real T_motor(unit="K", start=T_amb) "motor winding temperature";
  Real int_e_speed(start=0.0)     "speed loop integrator";
  Real int_e_tens(start=0.0)      "tension loop integrator";

  // ===== Algebraic / sensor signals =====
  Real omega_drum(unit="rad/s")  "output (drum) speed";
  Real v_lin(unit="m/s")         "linear output speed";
  Real x_lin(unit="m")           "linear position";
  Real a_lin(unit="m/s2")        "linear acceleration";
  Real V_bus(unit="V")           "sensed DC-bus voltage";
  Real V_cmd(unit="V")           "voltage command (unclamped)";
  Real V_motor(unit="V")        "applied motor voltage (clamped)";
  Real T_cable(unit="N")        "cable tension sensor";
  Real tau_dist_motor(unit="N.m") "disturbance torque reflected to motor";
  Real v_ref(unit="m/s")        "speed reference command";
  Real a_refsig(unit="m/s2")    "reference acceleration signal";
  Real T_ref(unit="N")          "tension reference command";
  Real e_speed(unit="m/s")      "speed tracking error";
  Real e_tens(unit="N")         "tension tracking error";
  Real err_track(unit="m/s")    "primary tracking error magnitude";
  Boolean dist_active           "disturbance active flag (middle third)";

  // ===== Bounds checks =====
  Boolean ok_voltage;
  Boolean ok_current;
  Boolean ok_speed;
  Boolean ok_accel;
  Boolean ok_soc;
  Boolean ok_thermal;
  Boolean ok_track;

  // ===== 100 Hz sampled sensor traces =====
  discrete Real s_omega_motor(unit="rad/s");
  discrete Real s_i_arm(unit="A");
  discrete Real s_theta(unit="rad");
  discrete Real s_v_bus(unit="V");
  discrete Real s_v_lin(unit="m/s");

initial equation
  theta_motor = 0.0;
  omega_motor = 0.0;
  i_arm = 0.0;

equation
  // ----- Mission speed reference (accelerate / hold / decelerate) -----
  if time < t_phase then
    v_ref    = (v_hold/t_phase)*time;
    a_refsig = a_ref;
  elseif time < 2*t_phase then
    v_ref    = v_hold;
    a_refsig = 0.0;
  elseif time < t_end then
    v_ref    = v_hold - (v_hold/t_phase)*(time - 2*t_phase);
    a_refsig = -a_ref;
  else
    v_ref    = 0.0;
    a_refsig = 0.0;
  end if;

  // ----- Disturbance injected during the middle third -----
  dist_active      = (time >= t_phase) and (time < 2*t_phase);
  tau_dist_motor   = if dist_active then T_dist/(N_gb*eta_gb) else 0.0;

  // ----- Mechanical kinematics -----
  omega_drum = omega_motor/N_gb;
  v_lin      = omega_drum*r_drum;
  x_lin      = theta_motor/N_gb*r_drum;
  der(theta_motor) = omega_motor;

  // ----- Mechanical dynamics (lumped at motor side) -----
  der(omega_motor) = (k_emf*i_arm - tau_grav_motor - b_fric*omega_motor - tau_dist_motor)/J_total;
  a_lin = (k_emf*i_arm - tau_grav_motor - b_fric*omega_motor - tau_dist_motor)/J_total/N_gb*r_drum;

  // ----- Electrical dynamics -----
  der(i_arm) = (V_motor - R_a*i_arm - k_emf*omega_motor)/L_a;

  // ----- Battery droop and state of charge -----
  V_bus   = V_supply - R_batt*i_arm;
  der(SOC) = -i_arm/Q_batt;

  // ----- Thermal model -----
  der(T_motor) = (i_arm^2*R_a - (T_motor - T_amb)/R_th)/C_th;

  // ----- Cable tension (massless cable + payload) -----
  T_ref   = m_load*(g + a_refsig);
  T_cable = m_load*(g + a_lin);

  // ----- Cascaded control: motor-speed loop + cable-tension trim -----
  e_speed = v_ref - v_lin;
  e_tens  = T_ref - T_cable;
  der(int_e_speed) = e_speed;
  der(int_e_tens)  = e_tens;

  // Voltage command = back-EMF FF + gravity FF + speed PI + tension trim
  V_cmd = k_emf*omega_motor
        + R_a*(tau_grav_motor/k_emf)
        + (Kp_w*N_gb/r_drum)*e_speed + Ki_w*int_e_speed
        + Kp_t*e_tens + Ki_t*int_e_tens;

  // Limit applied voltage to allowed command magnitude
  V_motor = max(min(V_cmd, V_cmd_max), -V_cmd_max);

  // ----- Primary tracking error -----
  err_track = abs(v_ref - v_lin);

  // ----- Bounds -----
  ok_voltage = abs(V_motor) <= V_cmd_max + 1e-9;
  ok_current = abs(i_arm)   <= i_max;
  ok_speed   = abs(v_lin)   <= v_hold*1.1 + 1e-9;
  ok_accel   = abs(a_lin)   <= a_ref*2.0 + 1e-9;
  ok_soc     = (SOC >= 0.0) and (SOC <= 1.0);
  ok_thermal = T_motor <= T_max;
  ok_track   = (time <= t_settle) or (err_track < err_tol);

  // ----- No NaN / infinite physical, control, or estimator values -----
  assert(omega_motor == omega_motor,  "omega_motor is NaN");
  assert(i_arm == i_arm,               "i_arm is NaN");
  assert(V_motor == V_motor,           "V_motor is NaN");
  assert(SOC == SOC,                   "SOC is NaN");
  assert(T_motor == T_motor,           "T_motor is NaN");
  assert(v_lin == v_lin,               "v_lin is NaN");
  assert(err_track == err_track,       "err_track is NaN");
  assert(omega_motor < 1e9,            "omega_motor unbounded");
  assert(i_arm < 1e9,                   "i_arm unbounded");

  // ----- 100 Hz synchronized sensor traces -----
  when sample(0, 1/f_sample) then
    s_omega_motor = omega_motor;
    s_i_arm       = i_arm;
    s_theta       = theta_motor;
    s_v_bus       = V_bus;
    s_v_lin       = v_lin;
  end when;

  annotation (
    experiment(StopTime=10, Tolerance=1e-6, Interval=0.01),
    Documentation(info="CableWinchSpeedB: trapezoidal lift mission for a 72 V motor, 45:1 gearbox, 0.09 m drum lifting 140 kg over 12 m. Cascaded motor-speed and cable-tension loops command armature voltage (limited to 59 V). An 8.4 N.m disturbance is applied at the drum during the middle third of the 10 s mission. Sensors sampled at 100 Hz. Parameters not stated in the requirement (eta_gb, R_a, L_a, k_emf, J_motor, friction, R_batt, capacity, thermal, current bound, gains) are nominal assumed values required for simulation and are clearly labeled above."));
end CableWinchSpeedB;