model SoftCrawlAvoidA
  // ------------------------------------------------------------------
  // Soft crawling robot with contact-aware shape control and bounded
  // stiffness scheduling. Reduced-order lumped model.
  // Facts not stated in the request are design assumptions (commented).
  // ------------------------------------------------------------------

  // --- Stated parameters ---
  parameter Real L_body     = 0.48    "total compliant body length [m]";
  parameter Integer N       = 6       "number of serial pneumatic chambers";
  parameter Real p_max      = 54000.0 "command magnitude limit [Pa gauge]";
  parameter Real mu_obs     = 0.55    "fixed cylinder friction coefficient [1]";
  parameter Real F_dist     = 4.0     "lateral tip disturbance magnitude [N]";
  parameter Real f_sample   = 80.0    "sensor/control rate [Hz] (guidance)";
  parameter Real t_end      = 8.0     "scenario duration [s]";
  parameter Real t_settle   = 5.2     "tracking-error deadline [s]";
  parameter Real err_bound  = 0.054   "primary tracking error bound after t_settle [m]";

  // --- Derived / design-assumption parameters (not stated) ---
  parameter Real L_seg      = L_body/N "per-segment length [m]";
  parameter Real r_body     = 0.025   "effective body radius [m] (assumption)";
  parameter Real m_body     = 0.80    "effective body mass [kg] (assumption)";
  parameter Real J_seg      = 1.0e-3  "segment bending inertia [kg.m2] (assumption)";
  parameter Real k_chamber  = 12.0    "nominal chamber bending stiffness [N.m/rad] (assumption)";
  parameter Real c_chamber  = 0.8     "chamber damping [N.m.s/rad] (assumption)";
  parameter Real gain_p     = 5.0e-5  "pressure-to-torque gain [N.m/Pa] (assumption)";
  parameter Real mu_g_fwd   = 0.15    "forward ground friction coeff [1] (assumption)";
  parameter Real mu_g_bwd   = 0.85    "backward ground friction coeff [1] (assumption)";
  parameter Real K_prop     = 1.5e-5  "propulsion gain [m2] (assumption)";
  parameter Real c_drag_x  = 2.0     "longitudinal drag [N.s/m] (assumption)";
  parameter Real c_drag_y  = 6.0     "lateral drag [N.s/m] (assumption)";
  parameter Real Kp_steer  = 15.0    "lateral steering proportional gain [N/m] (assumption)";
  parameter Real Ki_steer  = 8.0     "lateral steering integral gain [N/(m.s)] (assumption)";
  parameter Real F_steer_max = 5.0   "steering force authority [N] (assumption)";
  parameter Real Kp_p      = 2.0e4   "shape-control pressure gain [Pa/m] (assumption)";
  parameter Real wave_freq = 0.5     "traveling-wave frequency [Hz] (assumption)";
  parameter Real wave_amp  = 30000.0 "traveling-wave pressure amplitude [Pa] (<=p_max)";
  parameter Real k_contact = 1.0e4   "obstacle contact stiffness [N/m] (assumption)";
  parameter Real r_obs     = 0.04    "fixed cylinder radius [m] (assumption)";
  parameter Real x_obs     = 0.35    "obstacle center x [m] (assumption)";
  parameter Real y_obs     = 0.0      "obstacle center y [m] (assumption)";
  parameter Real x_target  = 0.60    "tip target x [m] (assumption)";
  parameter Real y_target  = 0.10    "tip target y [m] (assumption)";
  parameter Real T_env     = 293.15  "environment temperature [K] (assumption)";
  parameter Real R_therm   = 0.5     "thermal resistance [K/W] (assumption)";
  parameter Real C_therm   = 5.0     "thermal capacitance [J/K] (assumption)";
  parameter Real alpha_th  = 1.0e-6  "pressure-loss-to-heat coefficient [1/Pa] (assumption)";
  parameter Real temp_max  = 340.0   "temperature bound [K]";
  parameter Real deform_max = 0.6    "section deformation bound [rad]";
  parameter Real contact_max = 30.0  "contact-force bound [N]";
  parameter Real clear_min  = 0.001  "obstacle-clearance bound [m]";
  parameter Real t_dist_start = 8.0/3.0 "disturbance start [s]";
  parameter Real t_dist_end   = 16.0/3.0 "disturbance end [s]";
  parameter Real lateral_weight[6] = {0.0,0.5,1.0,1.0,0.5,0.0} "shape-control weight [1] (assumption)";

  // --- States ---
  Real x_b(start=0, fixed=true)   "body base x [m]";
  Real y_b(start=0, fixed=true)   "body base y [m]";
  Real vx_b(start=0, fixed=true)  "body base vx [m/s]";
  Real vy_b(start=0, fixed=true)  "body base vy [m/s]";
  Real theta[6](each start=0, each fixed=true)  "chamber bending angle [rad]";
  Real dtheta[6](each start=0, each fixed=true) "chamber angular velocity [rad/s]";
  Real T_act(start=T_env, fixed=true) "actuator temperature [K]";
  Real err_int(start=0, fixed=true) "lateral steering integral state [m.s]";

  // --- Computed / sensor quantities ---
  Real p_cmd[6]    "chamber pressure command [Pa gauge]";
  Real p_sat[6]    "saturated pressure command [Pa gauge]";
  Real p_steer     "lateral shape-control pressure [Pa]";
  Real k_sched[6]  "scheduled (bounded) chamber stiffness [N.m/rad]";
  Real phi_cum[6]  "cumulative segment orientation [rad]";
  Real seg_x[6]    "segment distal x [m]";
  Real seg_y[6]    "segment distal y [m]";
  Real dist[6]     "segment-to-obstacle center distance [m]";
  Real pen[6]      "obstacle penetration per segment [m]";
  Real contact_force[6] "distributed contact force per segment [N]";
  Real F_obs_x     "obstacle contact force on body, x [N]";
  Real F_obs_y     "obstacle contact force on body, y [N]";
  Real contact_total "total distributed contact force [N]";
  Real clearance   "minimum obstacle clearance [m]";
  Real x_tip       "tip x [m]";
  Real y_tip       "tip y [m]";
  Real phi_tip     "tip orientation [rad]";
  Real vx_tip      "tip vx [m/s]";
  Real vy_tip      "tip vy [m/s]";
  Real tracking_error "tip-to-target distance [m]";
  Real F_steer     "lateral steering force [N]";
  Real F_steer_raw "lateral steering force before saturation [N]";
  Real F_prop_x    "propulsion force [N]";
  Real F_dist_y    "applied lateral disturbance [N]";
  Real wave_phase  "traveling-wave phase [rad]";
  Real P_loss      "thermal loss power [W]";
  Real d1,d2,d3,d4,d5,d6 "segment distances (scalar reduction helpers) [m]";
  Real c1,c2,c3,c4,c5,c6 "contact forces (scalar reduction helpers) [N]";
  Real p1,p2,p3,p4,p5,p6 "saturated pressures (scalar helpers) [Pa]";
  Real th1,th2,th3,th4,th5,th6 "bending angles (scalar helpers) [rad]";
  Real k1,k2,k3,k4,k5,k6 "scheduled stiffness (scalar helpers) [N.m/rad]";
  Real max_abs_p   "max |saturated pressure| [Pa]";
  Real max_abs_th  "max |bending angle| [rad]";
  Real max_contact "max segment contact force [N]";
  Real max_abs_state "max |key state| for finiteness check [1]";

  // --- Bound flags ---
  Boolean b_cmd     "command within bound";
  Boolean b_deform  "deformation within bound";
  Boolean b_contact "contact force within bound";
  Boolean b_temp    "temperature within bound";
  Boolean b_clear   "clearance within bound (incidental contact only)";
  Boolean b_track   "tracking error within bound after settle";
  Boolean b_finite  "no NaN/infinite physical/control/estimator values";

equation
  // --- Traveling-wave pressure command with lateral shape control ---
  wave_phase = 2.0*Modelica.Constants.pi*wave_freq*time;
  p_steer = Kp_p*(y_target - y_tip);
  p_cmd[1] = wave_amp*Modelica.Math.sin(wave_phase - 0.0*Modelica.Constants.pi/3.0) + p_steer*lateral_weight[1];
  p_cmd[2] = wave_amp*Modelica.Math.sin(wave_phase - 1.0*Modelica.Constants.pi/3.0) + p_steer*lateral_weight[2];
  p_cmd[3] = wave_amp*Modelica.Math.sin(wave_phase - 2.0*Modelica.Constants.pi/3.0) + p_steer*lateral_weight[3];
  p_cmd[4] = wave_amp*Modelica.Math.sin(wave_phase - 3.0*Modelica.Constants.pi/3.0) + p_steer*lateral_weight[4];
  p_cmd[5] = wave_amp*Modelica.Math.sin(wave_phase - 4.0*Modelica.Constants.pi/3.0) + p_steer*lateral_weight[5];
  p_cmd[6] = wave_amp*Modelica.Math.sin(wave_phase - 5.0*Modelica.Constants.pi/3.0) + p_steer*lateral_weight[6];

  // --- Bounded pressure saturation (command magnitude limit 54 kPa) ---
  p1 = max(-p_max, min(p_max, p_cmd[1]));
  p2 = max(-p_max, min(p_max, p_cmd[2]));
  p3 = max(-p_max, min(p_max, p_cmd[3]));
  p4 = max(-p_max, min(p_max, p_cmd[4]));
  p5 = max(-p_max, min(p_max, p_cmd[5]));
  p6 = max(-p_max, min(p_max, p_cmd[6]));
  p_sat[1] = p1; p_sat[2] = p2; p_sat[3] = p3;
  p_sat[4] = p4; p_sat[5] = p5; p_sat[6] = p6;

  // --- Bounded stiffness scheduling (stiffen on contact) ---
  // k_sched in [k_chamber, 1.5*k_chamber], bounded by tanh.
  k1 = k_chamber*(1.0 + 0.5*Modelica.Math.tanh(contact_force[1]/1.0));
  k2 = k_chamber*(1.0 + 0.5*Modelica.Math.tanh(contact_force[2]/1.0));
  k3 = k_chamber*(1.0 + 0.5*Modelica.Math.tanh(contact_force[3]/1.0));
  k4 = k_chamber*(1.0 + 0.5*Modelica.Math.tanh(contact_force[4]/1.0));
  k5 = k_chamber*(1.0 + 0.5*Modelica.Math.tanh(contact_force[5]/1.0));
  k6 = k_chamber*(1.0 + 0.5*Modelica.Math.tanh(contact_force[6]/1.0));
  k_sched[1] = k1; k_sched[2] = k2; k_sched[3] = k3;
  k_sched[4] = k4; k_sched[5] = k5; k_sched[6] = k6;

  // --- Chamber bending dynamics (per-segment second order) ---
  der(theta[1])  = dtheta[1];
  der(theta[2])  = dtheta[2];
  der(theta[3])  = dtheta[3];
  der(theta[4])  = dtheta[4];
  der(theta[5])  = dtheta[5];
  der(theta[6])  = dtheta[6];
  J_seg*der(dtheta[1]) = gain_p*p_sat[1] - k_sched[1]*theta[1] - c_chamber*dtheta[1];
  J_seg*der(dtheta[2]) = gain_p*p_sat[2] - k_sched[2]*theta[2] - c_chamber*dtheta[2];
  J_seg*der(dtheta[3]) = gain_p*p_sat[3] - k_sched[3]*theta[3] - c_chamber*dtheta[3];
  J_seg*der(dtheta[4]) = gain_p*p_sat[4] - k_sched[4]*theta[4] - c_chamber*dtheta[4];
  J_seg*der(dtheta[5]) = gain_p*p_sat[5] - k_sched[5]*theta[5] - c_chamber*dtheta[5];
  J_seg*der(dtheta[6]) = gain_p*p_sat[6] - k_sched[6]*theta[6] - c_chamber*dtheta[6];

  // --- Forward kinematics from base (base orientation = x axis) ---
  phi_cum[1] = theta[1];
  phi_cum[2] = phi_cum[1] + theta[2];
  phi_cum[3] = phi_cum[2] + theta[3];
  phi_cum[4] = phi_cum[3] + theta[4];
  phi_cum[5] = phi_cum[4] + theta[5];
  phi_cum[6] = phi_cum[5] + theta[6];
  seg_x[1] = x_b + L_seg*Modelica.Math.cos(phi_cum[1]);
  seg_y[1] = y_b + L_seg*Modelica.Math.sin(phi_cum[1]);
  seg_x[2] = seg_x[1] + L_seg*Modelica.Math.cos(phi_cum[2]);
  seg_y[2] = seg_y[1] + L_seg*Modelica.Math.sin(phi_cum[2]);
  seg_x[3] = seg_x[2] + L_seg*Modelica.Math.cos(phi_cum[3]);
  seg_y[3] = seg_y[2] + L_seg*Modelica.Math.sin(phi_cum[3]);
  seg_x[4] = seg_x[3] + L_seg*Modelica.Math.cos(phi_cum[4]);
  seg_y[4] = seg_y[3] + L_seg*Modelica.Math.sin(phi_cum[4]);
  seg_x[5] = seg_x[4] + L_seg*Modelica.Math.cos(phi_cum[5]);
  seg_y[5] = seg_y[4] + L_seg*Modelica.Math.sin(phi_cum[5]);
  seg_x[6] = seg_x[5] + L_seg*Modelica.Math.cos(phi_cum[6]);
  seg_y[6] = seg_y[5] + L_seg*Modelica.Math.sin(phi_cum[6]);
  x_tip = seg_x[6];
  y_tip = seg_y[6];
  phi_tip = phi_cum[6];
  vx_tip = der(x_tip);
  vy_tip = der(y_tip);

  // --- Obstacle distance, penetration, distributed contact force ---
  d1 = Modelica.Math.sqrt((seg_x[1]-x_obs)^2 + (seg_y[1]-y_obs)^2);
  d2 = Modelica.Math.sqrt((seg_x[2]-x_obs)^2 + (seg_y[2]-y_obs)^2);
  d3 = Modelica.Math.sqrt((seg_x[3]-x_obs)^2 + (seg_y[3]-y_obs)^2);
  d4 = Modelica.Math.sqrt((seg_x[4]-x_obs)^2 + (seg_y[4]-y_obs)^2);
  d5 = Modelica.Math.sqrt((seg_x[5]-x_obs)^2 + (seg_y[5]-y_obs)^2);
  d6 = Modelica.Math.sqrt((seg_x[6]-x_obs)^2 + (seg_y[6]-y_obs)^2);
  dist[1]=d1; dist[2]=d2; dist[3]=d3; dist[4]=d4; dist[5]=d5; dist[6]=d6;
  pen[1] = max(0.0, (r_body + r_obs) - d1);
  pen[2] = max(0.0, (r_body + r_obs) - d2);
  pen[3] = max(0.0, (r_body + r_obs) - d3);
  pen[4] = max(0.0, (r_body + r_obs) - d4);
  pen[5] = max(0.0, (r_body + r_obs) - d5);
  pen[6] = max(0.0, (r_body + r_obs) - d6);
  c1 = k_contact*pen[1];
  c2 = k_contact*pen[2];
  c3 = k_contact*pen[3];
  c4 = k_contact*pen[4];
  c5 = k_contact*pen[5];
  c6 = k_contact*pen[6];
  contact_force[1]=c1; contact_force[2]=c2; contact_force[3]=c3;
  contact_force[4]=c4; contact_force[5]=c5; contact_force[6]=c6;
  contact_total = c1 + c2 + c3 + c4 + c5 + c6;

  // Obstacle contact force on body (repulsive, away from cylinder).
  // Divisor protected against zero by max(...,1e-6).
  F_obs_x = (c1*(seg_x[1]-x_obs)/max(d1,1.0e-6)
           + c2*(seg_x[2]-x_obs)/max(d2,1.0e-6)
           + c3*(seg_x[3]-x_obs)/max(d3,1.0e-6)
           + c4*(seg_x[4]-x_obs)/max(d4,1.0e-6)
           + c5*(seg_x[5]-x_obs)/max(d5,1.0e-6)
           + c6*(seg_x[6]-x_obs)/max(d6,1.0e-6)) * mu_obs;
  F_obs_y = (c1*(seg_y[1]-y_obs)/max(d1,1.0e-6)
           + c2*(seg_y[2]-y_obs)/max(d2,1.0e-6)
           + c3*(seg_y[3]-y_obs)/max(d3,1.0e-6)
           + c4*(seg_y[4]-y_obs)/max(d4,1.0e-6)
           + c5*(seg_y[5]-y_obs)/max(d5,1.0e-6)
           + c6*(seg_y[6]-y_obs)/max(d6,1.0e-6)) * mu_obs;

  // Minimum clearance (scalar explicit reduction).
  clearance = min(min(min(min(min(d1,d2),d3),d4),d5),d6) - (r_body + r_obs);

  // --- Propulsion from anisotropic ground friction rectified by wave ---
  F_prop_x = K_prop * wave_amp * (mu_g_bwd - mu_g_fwd);

  // --- Lateral steering (PI) with bounded authority ---
  F_steer_raw = Kp_steer*(y_target - y_tip) + Ki_steer*err_int;
  F_steer = max(-F_steer_max, min(F_steer_max, F_steer_raw));
  der(err_int) = y_target - y_tip;

  // --- Lateral tip disturbance (middle third of scenario, toward obstacle) ---
  F_dist_y = if (time >= t_dist_start and time <= t_dist_end) then -F_dist else 0.0;

  // --- Base dynamics ---
  der(x_b) = vx_b;
  der(y_b) = vy_b;
  m_body*der(vx_b) = F_prop_x - c_drag_x*vx_b + F_obs_x;
  m_body*der(vy_b) = F_steer - c_drag_y*vy_b + F_obs_y + F_dist_y;

  // --- Tip tracking error ---
  tracking_error = Modelica.Math.sqrt((x_tip - x_target)^2 + (y_tip - y_target)^2);

  // --- Thermal model (pressure loss -> heat, bounded by conduction) ---
  P_loss = alpha_th*(p1*p1 + p2*p2 + p3*p3 + p4*p4 + p5*p5 + p6*p6);
  C_therm*der(T_act) = P_loss - (T_act - T_env)/R_therm;

  // --- Scalar reductions for bound checks ---
  max_abs_p  = max(max(max(max(max(abs(p1),abs(p2)),abs(p3)),abs(p4)),abs(p5)),abs(p6));
  th1=abs(theta[1]); th2=abs(theta[2]); th3=abs(theta[3]);
  th4=abs(theta[4]); th5=abs(theta[5]); th6=abs(theta[6]);
  max_abs_th = max(max(max(max(max(th1,th2),th3),th4),th5),th6);
  max_contact = max(max(max(max(max(c1,c2),c3),c4),c5),c6);
  max_abs_state = max(max(max(max(max(abs(x_tip),abs(y_tip)),abs(vx_b)),abs(vy_b)),abs(T_act));

  // --- Bound assertions ---
  b_cmd     = max_abs_p <= p_max + 1.0;
  b_deform  = max_abs_th <= deform_max;
  b_contact = max_contact <= contact_max;
  b_temp    = T_act <= temp_max;
  b_clear   = clearance >= -1.0e-9;   // incidental contact only: penetration bounded
  b_track   = if time < t_settle then true else (tracking_error <= err_bound);
  b_finite  = max_abs_state < 1.0e20 and abs(tracking_error) < 1.0e20 and abs(F_prop_x) < 1.0e20;

  assert(b_cmd,     "Actuator command bound violated");
  assert(b_deform,  "Section deformation bound violated");
  assert(b_contact, "Distributed contact-force bound violated");
  assert(b_temp,    "Temperature bound violated");
  assert(b_track,   "Primary tracking error bound violated after 5.2 s");
  assert(b_finite,  "NaN/Infinite physical, control, or estimator value detected");

  annotation (
    Documentation(info="Soft crawler SoftCrawlAvoidA: six-chamber traveling-wave
      pneumatic bending body (0.48 m) with anisotropic ground friction,
      contact-aware bounded stiffness scheduling, fixed cylindrical obstacle
      (mu=0.55) with collision, 4 N lateral tip disturbance over middle third,
      80 Hz / 8 s scenario, synchronized state/command/sensor traces.
      Unstated geometric and physical values are design assumptions."),
    experiment(StartTime=0, StopTime=8, Tolerance=1e-6, Interval=0.0125));
end SoftCrawlAvoidA;