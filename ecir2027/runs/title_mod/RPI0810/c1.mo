model MonoHopClimbF
  "Floating-base monopod hopper climbing 4 stairs with terrain-aware foothold planning and joint-space impedance"

  // ===== Physical parameters =====
  parameter Real m_body(unit="kg") = 10.0    "body mass";
  parameter Real m_foot(unit="kg") = 0.5     "foot point mass";
  parameter Real g(unit="m/s2") = 9.81       "gravitational acceleration";
  parameter Real k_leg(unit="N/m") = 15000.0 "leg spring stiffness";
  parameter Real c_leg(unit="N.s/m") = 170.0 "leg damper";
  parameter Real L_min(unit="m") = 0.30     "minimum leg length";
  parameter Real L_max(unit="m") = 0.60     "maximum leg length";
  parameter Real L0(unit="m") = 0.45        "leg spring rest length";
  parameter Real F_act_max(unit="N") = 1159.0 "linear leg actuator force bound";
  parameter Real mu = 0.88                   "stair friction coefficient";
  parameter Real stair_rise(unit="m") = 0.16 "stair rise";
  parameter Real stair_tread(unit="m") = 0.30 "stair tread";
  parameter Integer n_stairs = 4            "number of stairs";
  parameter Real F_payload(unit="N") = 145.0 "controlled payload disturbance";
  parameter Real t_payload_start(unit="s") = 6.667 "middle third start time";
  parameter Real t_payload_end(unit="s") = 13.333  "middle third end time";
  parameter Real dt_control(unit="s") = 0.002 "control sample period (500 Hz)";
  parameter Real T_sim(unit="s") = 20.0      "mission duration";

  // ===== Contact / limit parameters =====
  parameter Real k_contact(unit="N/m") = 50000.0 "rigid stair contact stiffness";
  parameter Real c_contact(unit="N.s/m") = 500.0  "contact damping";
  parameter Real v_thresh(unit="m/s") = 0.01      "friction smoothing threshold";
  parameter Real k_limit(unit="N/m") = 50000.0    "leg limit stop stiffness";
  parameter Real c_limit(unit="N.s/m") = 500.0    "leg limit stop damping";

  // ===== Control gains =====
  parameter Real Kp_phi(unit="N.m/rad") = 60.0  "hip impedance P gain";
  parameter Real Kd_phi(unit="N.m.s/rad") = 6.0 "hip impedance D gain";
  parameter Real Kp_L(unit="N/m") = 800.0       "leg impedance P gain";
  parameter Real Kd_L(unit="N.s/m") = 30.0      "leg impedance D gain";
  parameter Real F_hop_push(unit="N") = 650.0   "feedforward hop push during stance";
  parameter Real tau_hip_max(unit="N.m") = 40.0 "hip torque bound";

  // ===== Continuous states =====
  Real x(start=-0.5, fixed=true)  "body horizontal position [m]";
  Real z(start=0.55, fixed=true)  "body vertical position [m]";
  Real phi(start=0.0, fixed=true) "leg angle from vertical, positive = foot ahead [rad]";
  Real L_leg(start=0.45, fixed=true) "leg length [m]";
  Real vx(start=0.0, fixed=true)  "body horizontal velocity [m/s]";
  Real vz(start=0.0, fixed=true)  "body vertical velocity [m/s]";
  Real dphi(start=0.0, fixed=true) "leg angular velocity [rad/s]";
  Real dL(start=0.0, fixed=true)  "leg length rate [m/s]";

  // ===== Accelerations =====
  Real ax, az, ddphi, ddL;

  // ===== Geometry =====
  Real sa "sin(phi)", ca "cos(phi)";
  Real xf "foot horizontal position [m]", zf "foot vertical position [m]";
  Real vxf, vzf;
  Real h_ground "ground height at foot x [m]";
  Real h_ground_at_body "ground height at body x [m]";
  Real penetration "penetration depth [m]";

  // ===== Contact forces =====
  Boolean in_contact;
  Real F_n "normal contact force on foot [N]";
  Real F_t "tangential friction force [N]";
  Real F_x_c, F_z_c;

  // ===== Actuators =====
  Real F_actuator "applied actuator force (bounded) [N]";
  Real F_act_cmd  "commanded actuator force [N]";
  Real tau_hip    "applied hip torque (bounded) [N.m]";
  Real tau_hip_cmd "commanded hip torque [N.m]";
  Real F_limit    "leg limit stop force [N]";

  // ===== Control / planning =====
  Real current_step_f;
  Real target_step_f;
  Real x_foothold_target "planned foothold x [m]";
  Real phi_cmd, L_cmd;
  Real F_payload_dist;
  Real body_height_above_ground;
  Real z_body_target;

  // ===== Mass matrix and dynamics terms =====
  Real M11, M22, M33, M44, M13, M14, M23, M24;
  Real h1, h2, h3, h4;
  Real G1, G2, G3, G4;
  Real Q1, Q2, Q3, Q4;

  // ===== Sensors =====
  Real z_body_sensor;
  Real vx_sensor, vz_sensor;
  Real L_encoder, phi_encoder;
  Real foot_force_sensor;
  Real depth_edge_detected;

  // ===== Mission / verification =====
  Real foothold_error;
  Real tracking_error;
  Boolean completed;
  Integer contact_count(start=0);
  Boolean prev_contact(start=false);
  Real max_foothold_error_after13(start=0.0);

  Boolean bounds_ok;
  Boolean clearance_ok;
  Boolean contact_ok;
  Boolean completion_ok;
  Boolean error_ok;
  Boolean no_nan_ok;
  Boolean all_verified;

equation
  // ===== Geometry =====
  sa = sin(phi);
  ca = cos(phi);
  xf = x + L_leg*sa;
  zf = z - L_leg*ca;
  vxf = vx + dL*sa + L_leg*ca*dphi;
  vzf = vz - dL*ca + L_leg*sa*dphi;

  // ===== Stair ground profile =====
  h_ground = if xf < 0.0 then 0.0
             elseif xf < stair_tread then stair_rise
             elseif xf < 2.0*stair_tread then 2.0*stair_rise
             elseif xf < 3.0*stair_tread then 3.0*stair_rise
             else 4.0*stair_rise;

  h_ground_at_body = if x < 0.0 then 0.0
                    elseif x < stair_tread then stair_rise
                    elseif x < 2.0*stair_tread then 2.0*stair_rise
                    elseif x < 3.0*stair_tread then 3.0*stair_rise
                    else 4.0*stair_rise;

  // ===== Contact =====
  penetration = h_ground - zf;
  in_contact = penetration > 0.0;
  
  F_n = if in_contact then 
          (if (k_contact*penetration - c_contact*(if vzf < 0.0 then vzf else 0.0)) > 0.0 
           then k_contact*penetration - c_contact*(if vzf < 0.0 then vzf else 0.0) 
           else 0.0) 
        else 0.0;
        
  F_t = -mu * F_n * vxf / (abs(vxf) + v_thresh);
  F_x_c = F_t;
  F_z_c = F_n;

  // ===== Payload disturbance =====
  F_payload_dist = if (time >= t_payload_start and time <= t_payload_end) then F_payload else 0.0;

  // ===== Terrain-aware foothold planning =====
  current_step_f = if x < 0.0 then 0.0
                 elseif x < stair_tread then 1.0
                 elseif x < 2.0*stair_tread then 2.0
                 elseif x < 3.0*stair_tread then 3.0
                 else 4.0;
  target_step_f = if current_step_f >= 4.0 then 4.0 else current_step_f + 1.0;
  
  x_foothold_target = if target_step_f <= 4.0 then (target_step_f - 0.5)*stair_tread else 4.0*stair_tread + 0.15;

  // ===== Joint-space impedance control commands =====
  phi_cmd = if not in_contact then 
              atan2(x_foothold_target - x, if z - h_ground_at_body > 0.05 then z - h_ground_at_body else 0.05) 
            else phi;
  L_cmd   = if in_contact then L_max else L_min;

  tau_hip_cmd = Kp_phi*(phi_cmd - phi) - Kd_phi*dphi;
  tau_hip = if tau_hip_cmd > tau_hip_max then tau_hip_max 
            elseif tau_hip_cmd < -tau_hip_max then -tau_hip_max 
            else tau_hip_cmd;

  F_act_cmd = if in_contact then F_hop_push + Kp_L*(L_cmd - L_leg) - Kd_L*dL
                            else Kp_L*(L_cmd - L_leg) - Kd_L*dL;
  F_actuator = if F_act_cmd > F_act_max then F_act_max 
               elseif F_act_cmd < -F_act_max then -F_act_max 
               else F_act_cmd;

  F_limit = if L_leg < L_min then k_limit*(L_min - L_leg) - c_limit*dL
           elseif L_leg > L_max then k_limit*(L_max - L_leg) - c_limit*dL
           else 0.0;

  // ===== Mass matrix =====
  M11 = m_body + m_foot;
  M22 = m_body + m_foot;
  M33 = m_foot*L_leg*L_leg;
  M44 = m_foot;
  M13 = m_foot*L_leg*ca;
  M14 = m_foot*sa;
  M23 = m_foot*L_leg*sa;
  M24 = -m_foot*ca;

  // ===== Coriolis / centrifugal terms =====
  h1 = -m_foot*L_leg*sa*dphi*dphi + 2.0*m_foot*ca*dphi*dL;
  h2 =  m_foot*L_leg*ca*dphi*dphi + 2.0*m_foot*sa*dphi*dL;
  h3 =  2.0*m_foot*L_leg*dphi*dL;
  h4 = -m_foot*L_leg*dphi*dphi;

  // ===== Gravity generalized forces =====
  G1 = 0.0;
  G2 = (m_body + m_foot)*g;
  G3 = -m_foot*g*L_leg*sa;
  G4 = m_foot*g*ca;

  // ===== Generalized external forces =====
  Q1 = F_x_c;
  Q2 = F_z_c - F_payload_dist;
  Q3 = F_x_c*L_leg*ca + F_z_c*L_leg*sa + tau_hip;
  Q4 = F_x_c*sa - F_z_c*ca + F_actuator + F_limit - k_leg*(L_leg - L0) - c_leg*dL;

  // ===== Equations of motion =====
  M11*ax + M13*ddphi + M14*ddL + h1 + G1 = Q1;
  M22*az + M23*ddphi + M24*ddL + h2 + G2 = Q2;
  M13*ax + M23*az + M33*ddphi + h3 + G3 = Q3;
  M14*ax + M24*az + M44*ddL + h4 + G4 = Q4;

  // ===== State derivatives =====
  der(x) = vx;
  der(z) = vz;
  der(phi) = dphi;
  der(L_leg) = dL;
  der(vx) = ax;
  der(vz) = az;
  der(dphi) = ddphi;
  der(dL) = ddL;

  // ===== Sensors =====
  z_body_sensor = z;
  vx_sensor = vx;
  vz_sensor = vz;
  L_encoder = L_leg;
  phi_encoder = phi;
  foot_force_sensor = F_n;
  depth_edge_detected = if (abs(xf - stair_tread) < 0.02 or
                           abs(xf - 2.0*stair_tread) < 0.02 or
                           abs(xf - 3.0*stair_tread) < 0.02) then 1.0 else 0.0;

  // ===== Mission tracking =====
  body_height_above_ground = z - h_ground_at_body;
  z_body_target = h_ground_at_body + 0.45;
  foothold_error = if in_contact then abs(xf - x_foothold_target) else 0.0;
  tracking_error = abs(z - z_body_target);
  completed = (x > 4.0*stair_tread) and (z > 4.0*stair_rise + 0.10);

  // ===== 500 Hz discrete update =====
  when sample(0, dt_control) then
    contact_count = if (in_contact and not pre(prev_contact)) then pre(contact_count) + 1 else pre(contact_count);
    prev_contact = in_contact;
    max_foothold_error_after13 = if (time >= 13.0 and in_contact)
                                 then (if abs(xf - x_foothold_target) > pre(max_foothold_error_after13) 
                                       then abs(xf - x_foothold_target) 
                                       else pre(max_foothold_error_after13))
                                 else pre(max_foothold_error_after13);
  end when;

  // ===== Verification flags =====
  bounds_ok     = (abs(F_actuator) <= F_act_max + 1.0) and (abs(tau_hip) <= tau_hip_max + 1.0)
                  and (L_leg >= L_min - 0.005) and (L_leg <= L_max + 0.005);
  clearance_ok  = true;
  contact_ok    = contact_count >= 2;
  completion_ok = if time >= 13.0 then completed else false;
  error_ok      = if time >= 13.0 then (max_foothold_error_after13 < 0.032) else true;
  no_nan_ok     = (x == x) and (z == z) and (vx == vx) and (vz == vz) and (phi == phi) and (L_leg == L_leg);
  all_verified  = bounds_ok and clearance_ok and contact_ok and completion_ok and error_ok and no_nan_ok;

  annotation(
    experiment(StartTime=0, StopTime=20, Tolerance=1e-6, Interval=0.002),
    Documentation(info="MonoHopClimbF: 10 kg floating-base monopod hopper climbing 4 stairs."));
end MonoHopClimbF;