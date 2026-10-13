model WheelLegRecoverB
  "Floating-base wheeled-leg robot WheelLegRecoverB - lateral impulse recovery mission"

  // ===== Known parameters from requirement =====
  parameter Real m_torso = 28.0  "Torso mass [kg]";
  parameter Real r_wheel = 0.10 "Wheel radius [m]";
  parameter Real tau_max  = 45.1 "Max allowed command magnitude per joint [N.m]";
  parameter Real mu_ground = 0.90 "Ground friction coefficient [-]";
  parameter Real F_push   = 98.0  "Lateral push disturbance magnitude [N]";
  parameter Real f_ctrl   = 100.0 "Control loop rate [Hz]";
  parameter Real T_sim    = 10.0  "Mission duration [s]";
  parameter Real err_thresh = 0.144 "Primary tracking error threshold after settle [rad]";
  parameter Real t_settle  = 6.5   "Settle time [s]";
  parameter Real slip_max  = 0.03  "Max allowed foot slip [m]";

  // ===== Unknown parameters (placeholder values — NOT specified in requirement) =====
  parameter Real h_ref     = 0.50  "Reference body height [m] — not specified";
  parameter Real I_body    = 1.2   "Body roll-axis inertia [kg.m2] — not specified";
  parameter Real m_base    = 4.0   "Effective wheeled base mass [kg] — not specified";
  parameter Real L_leg     = 0.45  "Effective leg moment arm [m] — not specified";
  parameter Real g         = 9.81  "Gravitational acceleration [m/s2]";
  parameter Real tau_filt  = 0.01  "Estimator filter time constant [s] — not specified";

  // Controller gains (tuned placeholders — not from requirement)
  parameter Real Kp_th = 1200.0 "Roll proportional gain";
  parameter Real Kd_th = 80.0   "Roll derivative gain";
  parameter Real Kp_x  = 1.0    "Base position proportional gain";
  parameter Real Kd_x  = 5.0    "Base velocity derivative gain";
  parameter Real Kp_h  = 200.0  "Height proportional gain";
  parameter Real Kd_h  = 30.0   "Height derivative gain";
  parameter Real th_switch = 0.15 "Contact switching tilt threshold [rad]";

  // ===== Derived constants =====
  parameter Real m_total = m_torso + m_base "Total robot mass [kg]";
  parameter Real dt_ctrl = 1.0 / f_ctrl     "Control timestep [s]";
  parameter Real N_normal = m_total * g     "Total normal force [N]";
  parameter Real F_fric_max = mu_ground * N_normal "Max static friction force [N]";
  parameter Real F_leg_max  = 8.0 * tau_max / L_leg "Max leg vertical force from torque [N]";
  parameter Real t_push_s  = T_sim / 3.0    "Push start time [s]";
  parameter Real t_push_e  = 2.0 * T_sim / 3.0 "Push end time [s]";

  // ===== Plant dynamic states =====
  Real x_cart(start=0.0)  "Lateral base (wheel contact) position [m]";
  Real vx_cart(start=0.0) "Lateral base velocity [m/s]";
  Real theta(start=0.0)   "Body roll angle from vertical [rad]";
  Real omega(start=0.0)   "Body roll angular velocity [rad/s]";
  Real h_body(start=h_ref) "Body COM height above ground [m]";
  Real vh(start=0.0)      "Body height velocity [m/s]";

  // ===== Slip states =====
  Real slip_vel(start=0.0) "Wheel slip velocity [m/s]";
  Real slip_acc(start=0.0) "Accumulated foot slip distance [m]";

  // ===== Estimator states (IMU + kinematics + force-qualified contact) =====
  Real theta_est(start=0.0)   "Estimated roll angle [rad]";
  Real omega_est(start=0.0)   "Estimated angular velocity [rad/s]";
  Real x_est(start=0.0)       "Estimated base position [m]";
  Real vx_est(start=0.0)      "Estimated base velocity [m/s]";
  Real h_est(start=h_ref)     "Estimated body height [m]";
  Real vh_est(start=0.0)      "Estimated height velocity [m/s]";
  Boolean contact_qualified   "Force-qualified stance contact [-]";

  // ===== Discrete controller outputs (100 Hz) =====
  discrete Real F_wheel_cmd_disc(start=0.0) "Discrete commanded wheel force [N]";
  discrete Real F_leg_cmd_disc(start=0.0)   "Discrete commanded leg force [N]";
  discrete Real ctrl_mode(start=0.0)        "Control mode: 0=normal, 1=recovery [-]";

  // ===== Saturated commands =====
  Real F_wheel_cmd        "Commanded total wheel force before saturation [N]";
  Real F_wheel_tq_sat     "Wheel force after torque saturation [N]";
  Real F_wheel_sat        "Wheel force after torque+friction saturation [N]";
  Real F_leg_cmd          "Commanded net leg vertical force before saturation [N]";
  Real F_leg_sat          "Saturated leg vertical force [N]";
  Real tau_wheel_per      "Saturated per-wheel torque [N.m]";
  Real tau_leg_per        "Saturated per-joint leg torque [N.m]";
  Real tau_wheel_cmd_per  "Commanded per-wheel torque [N.m]";
  Real tau_leg_cmd_per    "Commanded per-joint leg torque [N.m]";

  // ===== Disturbance =====
  Boolean disturbance_active "Push disturbance active [-]";
  Real F_push_actual        "Actual push force applied [N]";

  // ===== Traces =====
  Real x_com     "Body COM lateral position [m]";
  Real z_com     "Body COM vertical position [m]";
  Real track_err "Primary tracking error (abs roll) [rad]";
  Real ax_cart   "Base lateral acceleration [m/s2]";
  Real alpha     "Body angular acceleration [rad/s2]";
  Real det_m     "Mass matrix determinant [kg2.m2]";

  // ===== Requirement flags =====
  Boolean req_tracking "Tracking error below threshold after settle [-]";
  Boolean req_slip     "Slip below maximum [-]";
  Boolean req_height   "Positive body height [-]";
  Boolean req_recovery "Attitude recovery after disturbance [-]";
  Boolean req_torque   "Torque within bounds [-]";
  Boolean req_noNaN    "No NaN or infinite values [-]";

equation
  // ===== Disturbance injection (middle third of mission) =====
  disturbance_active = (time >= t_push_s) and (time < t_push_e);
  F_push_actual = if disturbance_active then F_push else 0.0;

  // ===== Estimator: first-order filters representing IMU + kinematic fusion =====
  der(theta_est) = (theta - theta_est) / tau_filt;
  der(omega_est) = (omega - omega_est) / tau_filt;
  der(x_est)    = (x_cart - x_est) / tau_filt;
  der(vx_est)   = (vx_cart - vx_est) / tau_filt;
  der(h_est)    = (h_body - h_est) / tau_filt;
  der(vh_est)   = (vh - vh_est) / tau_filt;
  // Force-qualified stance contact: positive leg force and body above ground
  contact_qualified = (F_leg_sat > 1.0) and (h_body > 0.01);

  // ===== Whole-body balance controller with contact switching (discrete, 100 Hz) =====
  when sample(0, dt_ctrl) then
    if abs(theta_est) > th_switch then
      // Recovery mode: prioritize balance, relax position regulation
      ctrl_mode = 1.0;
      F_wheel_cmd_disc = 1.5 * Kp_th * theta_est + 1.5 * Kd_th * omega_est;
    else
      // Normal mode: balance + position regulation
      ctrl_mode = 0.0;
      F_wheel_cmd_disc = Kp_th * theta_est + Kd_th * omega_est
                       + Kp_x * x_est + Kd_x * vx_est;
    end if;
    // Height controller: maintain reference height against gravity
    F_leg_cmd_disc = m_torso * g + Kp_h * (h_ref - h_est) + Kd_h * (0.0 - vh_est);
  end when;

  F_wheel_cmd = F_wheel_cmd_disc;
  F_leg_cmd   = F_leg_cmd_disc;

  // ===== Commanded per-joint torques (before saturation) =====
  tau_wheel_cmd_per = F_wheel_cmd * r_wheel / 4.0;
  tau_leg_cmd_per   = F_leg_cmd * L_leg / 8.0;

  // ===== Torque saturation =====
  // Per-wheel torque limit (4 wheels, each limited to tau_max)
  F_wheel_tq_sat = if abs(tau_wheel_cmd_per) > tau_max then
                     sign(tau_wheel_cmd_per) * tau_max * 4.0 / r_wheel
                   else F_wheel_cmd;
  // Friction saturation
  F_wheel_sat = if abs(F_wheel_tq_sat) > F_fric_max then
                  sign(F_wheel_tq_sat) * F_fric_max
                else F_wheel_tq_sat;
  // Leg force: per-joint limit (8 joints) and positivity (no pulling ground)
  F_leg_sat = if F_leg_cmd > F_leg_max then F_leg_max
              else if F_leg_cmd < 0.0 then 0.0
              else F_leg_cmd;

  // ===== Saturated per-joint torques =====
  tau_wheel_per = F_wheel_sat * r_wheel / 4.0;
  tau_leg_per   = F_leg_sat * L_leg / 8.0;

  // ===== Slip model: excess commanded force beyond friction causes sliding =====
  der(slip_vel) = if abs(F_wheel_cmd) > F_fric_max then
                    sign(F_wheel_cmd) * (abs(F_wheel_cmd) - F_fric_max) / m_total
                  else if abs(slip_vel) > 1e-6 then
                    -10.0 * slip_vel
                  else 0.0;
  der(slip_acc) = abs(slip_vel);

  // ===== Plant: inverted-pendulum-on-wheeled-cart (lateral plane) =====
  // COM kinematics
  x_com = x_cart + h_body * sin(theta);
  z_com = h_body * cos(theta);

  // Mass-matrix RHS: horizontal momentum and angular momentum about base pivot
  // External push force acts at body COM: contributes to both equations
  det_m = m_total * (m_torso * h_body^2 + I_body)
          - (m_torso * h_body * cos(theta))^2;
  // det_m = m_torso*h^2*(m_base + m_torso*sin(theta)^2) + m_total*I_body > 0 always

  // [m_total,          m_torso*h*cos(theta)   ] [ax]   [F_wheel_sat + F_push + m_torso*h*sin(theta)*omega^2]
  // [m_torso*h*cos(theta), m_torso*h^2+I_body] [alp] = [m_torso*g*h*sin(theta) + F_push*h*cos(theta)          ]
  ax_cart = ((m_torso * h_body^2 + I_body) * (F_wheel_sat + F_push_actual + m_torso * h_body * sin(theta) * omega^2)
             - m_torso * h_body * cos(theta) * (m_torso * g * h_body * sin(theta) + F_push_actual * h_body * cos(theta)))
            / det_m;
  alpha = (m_total * (m_torso * g * h_body * sin(theta) + F_push_actual * h_body * cos(theta))
           - m_torso * h_body * cos(theta) * (F_wheel_sat + F_push_actual + m_torso * h_body * sin(theta) * omega^2))
          / det_m;

  // Lateral + roll state derivatives
  der(x_cart)  = vx_cart;
  der(vx_cart) = ax_cart;
  der(theta)   = omega;
  der(omega)   = alpha;

  // Height dynamics (vertical, independent)
  der(h_body) = vh;
  der(vh)     = (F_leg_sat - m_torso * g) / m_torso;

  // ===== Tracking error =====
  track_err = abs(theta);

  // ===== Requirement checks =====
  req_tracking = (time < t_settle) or (track_err < err_thresh);
  req_slip     = slip_acc <= slip_max;
  req_height   = h_body > 0.0;
  req_recovery = (time < t_push_e) or (track_err < err_thresh);
  req_torque   = (abs(tau_wheel_per) <= tau_max + 1e-6)
                 and (abs(tau_leg_per) <= tau_max + 1e-6);
  req_noNaN    = (abs(theta) < 1e6) and (abs(omega) < 1e6)
                 and (abs(x_cart) < 1e6) and (abs(vx_cart) < 1e6)
                 and (h_body > -1e6) and (abs(vh) < 1e6)
                 and (abs(F_wheel_sat) < 1e6) and (abs(F_leg_sat) < 1e6)
                 and (abs(theta_est) < 1e6) and (abs(omega_est) < 1e6)
                 and (abs(slip_vel) < 1e6) and (abs(slip_acc) < 1e6);

  annotation(experiment(StartTime = 0.0, StopTime = 10.0, Tolerance = 1e-6, Interval = 0.01));
end WheelLegRecoverB;