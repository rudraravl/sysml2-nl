model BipedTwoRecoverB
  // ===== Stated physical parameters =====
  parameter Real m_body = 36.0 "kg, pelvis mass";
  parameter Real L_thigh = 0.42 "m, thigh length";
  parameter Real L_shank = 0.40 "m, shank length";
  parameter Real L_leg = L_thigh + L_shank "m, total leg length";
  parameter Real tau_max = 102.0 "N.m, max allowed joint torque per joint";
  parameter Real mu = 0.90 "ground friction coefficient";
  parameter Real F_push = 98.0 "N, lateral push disturbance magnitude";

  // ===== Stated mission parameters =====
  parameter Real T_sim = 10.0 "s, mission duration";
  parameter Real f_ctrl = 100.0 "Hz, control rate";
  parameter Real err_thresh = 0.144 "rad, primary tracking error threshold after t_check";
  parameter Real t_check = 6.5 "s, error check time";
  parameter Real slip_thresh = 0.03 "m, foot slip limit";

  // ===== Derived constants =====
  parameter Real dt_ctrl = 1.0 / f_ctrl "s, control period";
  parameter Real t_push_on = T_sim / 3.0 "s, push start (middle third)";
  parameter Real t_push_off = 2.0 * T_sim / 3.0 "s, push end (middle third)";
  parameter Real g = 9.81 "m/s^2";

  // ===== Assumed parameters (not stated; nominal engineering choices) =====
  // Stance width, body inertia, foot mass, leg stiffness, and controller gains
  // are NOT specified in the requirement. Values below are reasonable assumptions
  // chosen to satisfy the stated recovery, slip, and torque constraints.
  parameter Real W_stance = 0.34 "m, assumed lateral stance width";
  parameter Real I_body = 2.0 "kg.m^2, assumed body roll inertia about CoM";
  parameter Real m_foot = 1.5 "kg, assumed foot mass per foot";
  parameter Real k_leg = 20000.0 "N/m, assumed leg vertical stiffness";
  parameter Real d_leg = 400.0 "N.s/m, assumed leg vertical damping";
  parameter Real d_foot = 300.0 "N.s/m, assumed foot lateral slip damping";
  parameter Real est_tau = 0.02 "s, estimator (IMU+kinematics) time constant";
  parameter Real kp_roll = 1200.0 "N.m/rad, roll proportional gain (assumed)";
  parameter Real kd_roll = 120.0 "N.m.s/rad, roll derivative gain (assumed)";
  parameter Real kp_pos = 200.0 "N/m, lateral position proportional gain (assumed)";
  parameter Real kd_pos = 20.0 "N.s/m, lateral position derivative gain (assumed)";
  parameter Real x_footL0 = -W_stance / 2.0 "m, initial left foot position";
  parameter Real x_footR0 = W_stance / 2.0 "m, initial right foot position";

  // ===== Continuous dynamic states =====
  Real theta(start = 0.0, fixed = true) "body roll angle [rad], positive = lean right";
  Real omega(start = 0.0, fixed = true) "body roll rate [rad/s]";
  Real z(start = L_leg, fixed = true) "CoM height [m]";
  Real vz(start = 0.0, fixed = true) "CoM vertical velocity [m/s]";
  Real x_footL(start = x_footL0, fixed = true) "left foot lateral position [m]";
  Real vx_footL(start = 0.0, fixed = true) "left foot lateral velocity [m/s]";
  Real x_footR(start = x_footR0, fixed = true) "right foot lateral position [m]";
  Real vx_footR(start = 0.0, fixed = true) "right foot lateral velocity [m/s]";

  // Estimator states (IMU + kinematics + force-qualified contact fusion)
  Real theta_est(start = 0.0, fixed = true) "estimated roll [rad]";
  Real omega_est(start = 0.0, fixed = true) "estimated roll rate [rad/s]";
  Real x_est(start = 0.0, fixed = true) "estimated lateral CoM position [m]";
  Real vx_est(start = 0.0, fixed = true) "estimated lateral CoM velocity [m/s]";
  Real z_est(start = L_leg, fixed = true) "estimated CoM height [m]";

  // ===== Discrete controller states (100 Hz zero-order hold) =====
  discrete Real tau_cmd_total_d(start = 0.0) "discrete total torque command [N.m]";
  discrete Real wL_d(start = 0.5) "discrete left weight distribution [-]";
  discrete Real wR_d(start = 0.5) "discrete right weight distribution [-]";

  // ===== Algebraic variables =====
  Real F_dist "applied disturbance force [N]";
  Real I_eff "effective roll inertia about pivot [kg.m^2]";
  Real alpha "roll angular acceleration [rad/s^2]";
  Real N_total "total vertical normal force [N]";
  Real NL "left foot normal force [N]";
  Real NR "right foot normal force [N]";
  Real wL "left weight distribution [-]";
  Real wR "right weight distribution [-]";
  Real x_pivot "effective pivot lateral position [m]";
  Real x_com "CoM lateral position [m]";
  Real vx_com "CoM lateral velocity [m/s]";
  Real ax_com_qs "quasi-static CoM lateral acceleration [m/s^2]";
  Real F_grf "total horizontal ground reaction force [N]";
  Real F_req_L "required horizontal force at left foot [N]";
  Real F_req_R "required horizontal force at right foot [N]";
  Real F_excess_L "excess force causing left foot slip [N]";
  Real F_excess_R "excess force causing right foot slip [N]";
  Real F_fric_max_L "max friction force at left foot [N]";
  Real F_fric_max_R "max friction force at right foot [N]";
  Real tau_cmdL "left torque command pre-saturation [N.m]";
  Real tau_cmdR "right torque command pre-saturation [N.m]";
  Real tauL "actual left joint torque (bounded) [N.m]";
  Real tauR "actual right joint torque (bounded) [N.m]";
  Real tau_total "sum of actual joint torques [N.m]";
  Real slipL "left foot displacement from initial [m]";
  Real slipR "right foot displacement from initial [m]";
  Real slip_max "maximum foot slip [m]";
  Real tracking_error "primary tracking error = |theta| [rad]";

  // Requirement monitors
  Boolean contactL "left foot in stance contact";
  Boolean contactR "right foot in stance contact";
  Boolean height_positive "body height > 0";
  Boolean slip_within_limit "foot slip <= 0.03 m";
  Boolean error_within_limit "tracking error <= 0.144 rad for t >= 6.5 s";
  Boolean values_finite "no NaN or Inf (bounds check proxy)";

equation
  // ===== Disturbance: 98 N lateral push during middle third [3.33, 6.67] s =====
  F_dist = if (time >= t_push_on and time < t_push_off) then F_push else 0.0;

  // ===== Effective inertia (inverted pendulum about ground pivot) =====
  I_eff = m_body * z * z + I_body;

  // ===== Weight distribution from roll angle (avoids algebraic loop) =====
  // theta > 0 (lean right) => more weight on right foot
  wL = max(0.0, min(1.0, 0.5 - theta * z / W_stance));
  wR = 1.0 - wL;

  // ===== Pivot and CoM kinematics =====
  x_pivot = wL * x_footL + wR * x_footR;
  x_com = x_pivot + z * sin(theta);
  vx_com = wL * vx_footL + wR * vx_footR + z * cos(theta) * omega;

  // ===== Force-qualified contact detection =====
  contactL = (wL > 0.01) and (z > 0.05);
  contactR = (wR > 0.01) and (z > 0.05);

  // ===== Vertical dynamics (spring-damper leg support) =====
  N_total = m_body * g + k_leg * (L_leg - z) - d_leg * vz;
  NL = wL * max(N_total, 0.0);
  NR = wR * max(N_total, 0.0);
  m_body * der(vz) = N_total - m_body * g;
  der(z) = vz;

  // ===== Roll dynamics (inverted pendulum) =====
  tau_total = tauL + tauR;
  alpha = (m_body * g * z * sin(theta) + F_dist * z * cos(theta) - tau_total) / I_eff;
  der(omega) = alpha;
  der(theta) = omega;

  // ===== Horizontal ground reaction force (quasi-static, pivot assumed fixed) =====
  ax_com_qs = z * cos(theta) * alpha - z * sin(theta) * omega * omega;
  F_grf = m_body * ax_com_qs - F_dist;

  // ===== Friction-limited foot contact (regularized Coulomb) =====
  F_fric_max_L = mu * NL;
  F_fric_max_R = mu * NR;
  F_req_L = wL * F_grf;
  F_req_R = wR * F_grf;

  // No slip when |F_req| < mu*N; excess force drives foot acceleration
  F_excess_L = F_req_L - F_fric_max_L * tanh(F_req_L / (F_fric_max_L + 1e-9));
  F_excess_R = F_req_R - F_fric_max_R * tanh(F_req_R / (F_fric_max_R + 1e-9));

  // Foot slip dynamics
  m_foot * der(vx_footL) = F_excess_L - d_foot * vx_footL;
  m_foot * der(vx_footR) = F_excess_R - d_foot * vx_footR;
  der(x_footL) = vx_footL;
  der(x_footR) = vx_footR;

  // ===== Estimator: IMU + kinematics + force-qualified contact fusion =====
  // First-order low-pass filter representing sensor fusion with bounded latency
  der(theta_est) = (theta - theta_est) / est_tau;
  der(omega_est) = (omega - omega_est) / est_tau;
  der(x_est) = (x_com - x_est) / est_tau;
  der(vx_est) = (vx_com - vx_est) / est_tau;
  der(z_est) = (z - z_est) / est_tau;

  // ===== Whole-body balance controller (100 Hz discrete, contact switching) =====
  when sample(0, dt_ctrl) then
    // PD on estimated roll + lateral position, converted to pivot torque
    tau_cmd_total_d = -(kp_roll * theta_est + kd_roll * omega_est)
                      - (kp_pos * x_est + kd_pos * vx_est) * z_est;
    // Contact switching: weight distribution from estimated roll
    wL_d = max(0.0, min(1.0, 0.5 - theta_est * z_est / W_stance));
    wR_d = 1.0 - wL_d;
  end when;

  // Torque distribution via contact weights and bounded actuator saturation
  tau_cmdL = wL_d * tau_cmd_total_d;
  tau_cmdR = wR_d * tau_cmd_total_d;
  tauL = max(-tau_max, min(tau_max, tau_cmdL));
  tauR = max(-tau_max, min(tau_max, tau_cmdR));

  // ===== Synchronized state, command, and sensor traces =====
  slipL = abs(x_footL - x_footL0);
  slipR = abs(x_footR - x_footR0);
  slip_max = max(slipL, slipR);
  tracking_error = abs(theta);

  // ===== Requirement monitors =====
  height_positive = z > 0.0;
  slip_within_limit = slip_max <= slip_thresh;
  error_within_limit = (time < t_check) or (tracking_error <= err_thresh);
  values_finite = (abs(theta) < 1e6) and (abs(omega) < 1e6) and (abs(z) < 1e6)
                  and (abs(tauL) < 1e6) and (abs(tauR) < 1e6)
                  and (abs(theta_est) < 1e6) and (abs(x_est) < 1e6)
                  and (abs(F_dist) < 1e6) and (abs(F_grf) < 1e6);

  annotation(
    experiment(StopTime = 10.0, Tolerance = 1e-6, Interval = 0.001),
    Documentation(info = "<html>
      <p><b>BipedTwoRecoverB</b>: Lateral balance recovery for a floating-base biped.</p>
      <p>Stands in place and recovers from a 98 N lateral push applied during the
      middle third of a 10 s mission. Controller runs at 100 Hz with whole-body
      balance control and contact switching.</p>
      <p><b>Stated constraints:</b> torque bound 102 N.m/joint, friction 0.90,
      foot slip &lt; 0.03 m, positive body height, tracking error &lt; 0.144 rad
      after 6.5 s, no NaN/Inf.</p>
      <p><b>Assumed parameters</b> (stance width, body inertia, foot mass, leg
      stiffness, controller gains) are labeled in the code and are NOT stated in
      the requirement. They represent reasonable engineering choices to satisfy
      the stated physical and mission constraints.</p>
    </html>")
  );
end BipedTwoRecoverB;