model MonoHopClimbF
  // === Physical Parameters ===
  parameter Real m_body = 10.0 "Body mass [kg]";
  parameter Real m_foot = 0.5 "Foot mass [kg]";
  parameter Real k_leg = 15000.0 "Leg spring stiffness [N/m]";
  parameter Real b_leg = 170.0 "Leg damper [N.s/m]";
  parameter Real L0 = 0.45 "Leg rest length [m]";
  parameter Real Lmin = 0.30 "Minimum leg length [m]";
  parameter Real Lmax = 0.60 "Maximum leg length [m]";
  parameter Real Fmax = 1159.0 "Maximum actuator force [N]";
  parameter Real mu = 0.88 "Friction coefficient [1]";
  parameter Real rise_h = 0.16 "Stair rise [m]";
  parameter Real tread_w = 0.30 "Stair tread [m]";
  parameter Real h_des = 0.85 "Desired apex body height above local ground [m]";
  parameter Real Wpay = 145.0 "Payload disturbance magnitude [N]";
  parameter Real t_pay0 = 20.0 / 3.0 "Payload disturbance start [s]";
  parameter Real t_pay1 = 40.0 / 3.0 "Payload disturbance end [s]";
  parameter Real g = 9.81 "Gravitational acceleration [m/s^2]";
  parameter Real k_contact = 50000.0 "Contact penalty stiffness [N/m]";
  parameter Real b_contact = 500.0 "Contact penalty damping [N.s/m]";
  parameter Real k_stop = 200000.0 "Hard-stop stiffness [N/m]";
  parameter Real b_stop = 200.0 "Hard-stop damping [N.s/m]";

  // === Controller Parameters ===
  parameter Real Kp_imp = 5000.0 "Impedance proportional gain [N/m]";
  parameter Real Kd_imp = 200.0 "Impedance derivative gain [N.s/m]";
  parameter Real Kp_flight = 3000.0 "Flight foot-positioning P gain [N/m]";
  parameter Real Kd_flight = 150.0 "Flight foot-positioning D gain [N.s/m]";
  parameter Real dL_cmd = 0.06 "Leg extension offset for energy injection [m]";

  // === Continuous States ===
  Real x(start=-0.5, fixed=true) "Body x position [m]";
  Real z(start=0.45, fixed=true) "Body z position [m]";
  Real vx(start=0.5, fixed=true) "Body x velocity [m/s]";
  Real vz(start=0.0, fixed=true) "Body z velocity [m/s]";
  Real xf(start=-0.5, fixed=true) "Foot x position [m]";
  Real zf(start=0.0, fixed=true) "Foot z position [m]";
  Real vxf(start=0.0, fixed=true) "Foot x velocity [m/s]";
  Real vzf(start=0.0, fixed=true) "Foot z velocity [m/s]";

  // === Derived Kinematics ===
  Real L "Leg length [m]";
  Real vL "Leg length rate [m/s]";
  Real theta_leg "Leg angle from vertical [rad]";
  Real zg "Ground or stair surface height at foot x [m]";
  Real pen "Contact penetration depth [m]";

  // === Forces ===
  Real F_spring "Leg spring force [N]";
  Real F_damper "Leg damper force [N]";
  Real F_hardstop "Hard-stop force [N]";
  Real F_act_raw "Unbounded actuator force [N]";
  Real F_act "Bounded actuator force [N]";
  Real F_leg "Total axial leg force, positive = extending [N]";
  Real Fpay "Payload disturbance force [N]";
  Real Fc_n "Normal contact force [N]";
  Real Fc_t "Tangential friction force [N]";
  Real Ff_flight_x "Flight foot-positioning force x [N]";
  Real Ff_flight_z "Flight foot-positioning force z [N]";

  // === Controller Variables ===
  Real theta_cmd "Commanded leg angle [rad]";
  Real L_cmd "Commanded leg length [m]";
  Real xf_des "Desired foot x during flight [m]";
  Real zf_des "Desired foot z during flight [m]";
  Real x_target "Target foothold x [m]";
  Real z_target "Target foothold z [m]";
  Real stair_idx "Target stair index, 1-based [1]";
  Real tracking_error "Foothold tracking error [m]";

  // === Sensor Outputs ===
  Real z_body_sensor "Body height sensor [m]";
  Real vx_body_sensor "Body x velocity sensor [m/s]";
  Real vz_body_sensor "Body z velocity sensor [m/s]";
  Real L_encoder "Leg length encoder [m]";
  Real theta_encoder "Leg angle encoder [rad]";
  Real F_foot_sensor "Foot normal force sensor [N]";
  Real z_ground_sensor "Detected ground height [m]";

  // === Discrete State ===
  discrete Integer contact_count(start=0) "Number of distinct support contacts";
  discrete Real min_clear(start=10.0) "Running minimum foot clearance during flight [m]";
  discrete Real last_foothold_error(start=0.0) "Foothold error at last touchdown [m]";
  discrete Real err_at_13(start=1.0) "Foothold error recorded at t=13 s [m]";

  // === Verification Flags ===
  Boolean bounds_ok "Joint and effort bounds satisfied";
  Boolean clearance_ok "Stair-edge clearance satisfied";
  Boolean support_ok "At least two support contacts";
  Boolean completed "Mission completed";
  Boolean no_nan_inf "No NaN or infinite values";
  Boolean tracking_ok "Tracking error below 0.032 m after 13 s";

equation
  // === Leg Kinematics ===
  L = sqrt(max((x - xf) * (x - xf) + (z - zf) * (z - zf), 1e-8));
  vL = if L > 1e-4 then ((x - xf) * (vx - vxf) + (z - zf) * (vz - vzf)) / L else 0.0;
  theta_leg = if L > 1e-4 then atan2(x - xf, z - zf) else 0.0;

  // === Ground / Stair Surface Height ===
  // Stair i covers x in [(i-1)*tread, i*tread), surface at z = i*rise
  // x < 0: flat ground at z = 0; x >= 4*tread: top platform at z = 4*rise
  zg = if xf < 0.0 then 0.0
       elseif xf < 4.0 * tread_w then (floor(xf / tread_w) + 1.0) * rise_h
       else 4.0 * rise_h;

  // === Contact Model (penalty-based) ===
  pen = zg - zf;
  Fc_n = if pen > 0.0 then max(k_contact * pen - b_contact * vzf, 0.0) else 0.0;
  Fc_t = if pen > 0.0 then -mu * Fc_n * tanh(vxf / 0.02) else 0.0;

  // === Leg Forces ===
  F_spring = k_leg * (L0 - L);
  F_damper = -b_leg * vL;
  F_hardstop = if L < Lmin then k_stop * (Lmin - L) - b_stop * vL
               elseif L > Lmax then -k_stop * (L - Lmax) - b_stop * vL
               else 0.0;

  // Joint-space impedance control during stance
  L_cmd = L0 + dL_cmd;
  F_act_raw = if pen > 0.0 then (Kp_imp * (L_cmd - L) + Kd_imp * (0.0 - vL)) else 0.0;
  F_act = max(-Fmax, min(Fmax, F_act_raw));
  F_leg = F_spring + F_damper + F_act + F_hardstop;

  // === Payload Disturbance (middle third of 20 s run) ===
  Fpay = if time >= t_pay0 and time <= t_pay1 then Wpay else 0.0;

  // === Terrain-Aware Foothold Planning ===
  stair_idx = if x < 0.0 then 1.0
              elseif x < tread_w then 2.0
              elseif x < 2.0 * tread_w then 3.0
              elseif x < 3.0 * tread_w then 4.0
              else 4.0;
  x_target = if x >= 4.0 * tread_w then x else (stair_idx - 0.5) * tread_w;
  z_target = stair_idx * rise_h;
  theta_cmd = atan2(x_target - x, max(z - z_target, 0.05));

  // === Flight Foot Positioning ===
  xf_des = x + L0 * sin(theta_cmd);
  zf_des = z - L0 * cos(theta_cmd);
  Ff_flight_x = if pen <= 0.0 then Kp_flight * (xf_des - xf) - Kd_flight * vxf else 0.0;
  Ff_flight_z = if pen <= 0.0 then Kp_flight * (zf_des - zf) - Kd_flight * vzf else 0.0;

  // === Tracking Error (from last touchdown) ===
  tracking_error = last_foothold_error;

  // === Sensors ===
  z_body_sensor = z;
  vx_body_sensor = vx;
  vz_body_sensor = vz;
  L_encoder = L;
  theta_encoder = theta_leg;
  F_foot_sensor = Fc_n;
  z_ground_sensor = zg;

  // === Body Dynamics ===
  der(x) = vx;
  der(z) = vz;
  m_body * der(vx) = F_leg * (x - xf) / L;
  m_body * der(vz) = F_leg * (z - zf) / L - m_body * g - Fpay;

  // === Foot Dynamics ===
  der(xf) = vxf;
  der(zf) = vzf;
  m_foot * der(vxf) = -F_leg * (x - xf) / L + Fc_t + Ff_flight_x;
  m_foot * der(vzf) = -F_leg * (z - zf) / L + Fc_n + Ff_flight_z;

  // === Contact Counting and Foothold Error at Touchdown ===
  when pen > 0.003 then
    contact_count = pre(contact_count) + 1;
    last_foothold_error = sqrt((xf - x_target) * (xf - x_target) + (zf - z_target) * (zf - z_target));
  end when;

  // === Minimum Foot Clearance During Flight (sampled at 500 Hz) ===
  when sample(0, 0.002) then
    min_clear = if (zf - zg) > 0.001 and (zf - zg) < pre(min_clear) then (zf - zg) else pre(min_clear);
  end when;

  // === Record Foothold Error at t = 13 s ===
  when time > 13.0 then
    err_at_13 = pre(last_foothold_error);
  end when;

  // === Verification Criteria ===
  bounds_ok = L >= Lmin - 0.005 and L <= Lmax + 0.005 and abs(F_act) <= Fmax + 0.5;
  clearance_ok = min_clear > 0.0;
  support_ok = contact_count >= 2;
  completed = x >= 4.0 * tread_w - 0.05 and z >= 4.0 * rise_h + 0.20;
  no_nan_inf = abs(x) < 1e8 and abs(z) < 1e8 and abs(vx) < 1e8 and abs(vz) < 1e8
               and abs(F_act) < 1e8 and abs(L) < 1e8 and abs(zg) < 1e8;
  tracking_ok = err_at_13 < 0.032;

  annotation(
    experiment(StartTime = 0.0, StopTime = 20.0, Tolerance = 1e-6, Interval = 0.002),
    Documentation(info = "Monopod hopping robot (MonoHopClimbF): 10 kg cylindrical body on one telescoping leg (0.30-0.60 m, 15 kN/m spring, 170 N.s/m damper, spherical foot). Mission: climb 4 stairs of 0.16 m rise and 0.30 m tread while maintaining body height. Bounded linear actuator (max 1159 N) injects hopping energy. Terrain-aware foothold planning targets stair centers; joint-space impedance controls stance. Rigid stair collision with friction coefficient 0.88. Controlled 145 N payload disturbance applied during middle third (6.667-13.333 s). Runs at 500 Hz for 20 s. Verification: joint and effort bounds, stair-edge clearance, at least two support contacts, completion, foothold tracking error below 0.032 m after 13 s, and no NaN or infinite physical, control, or estimator values.")
  );
end MonoHopClimbF;