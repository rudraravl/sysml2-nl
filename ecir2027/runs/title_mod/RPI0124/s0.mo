model DuoArmPointD
  "Instrumented fixed-base articulated manipulator, 2-link planar arm with revolute Y joints in vertical plane"

  // ---- Physical parameters ----
  parameter Real m_pedestal = 20.0 "Pedestal mass [kg] (fixed box base)";
  parameter Real m1 = 5.0  "Link 1 mass [kg]";
  parameter Real m2 = 3.0  "Link 2 mass [kg]";
  parameter Real l1 = 0.55 "Link 1 length [m] (capsule)";
  parameter Real l2 = 0.38 "Link 2 length [m] (capsule)";
  parameter Real g_grav = 9.81 "Gravitational acceleration [m/s2]";
  parameter Real tau_max = 70.0 "Maximum joint torque magnitude [N.m]";
  parameter Real q_max = 1.6  "Joint position limit [rad]";
  // Capsule radii and pedestal box dimensions are not stated — left unknown.
  // parameter Real r_capsule1 = ... "Link 1 capsule radius [m] — UNKNOWN";
  // parameter Real r_capsule2 = ... "Link 2 capsule radius [m] — UNKNOWN";
  // parameter Real ped_box_x  = ... "Pedestal box x-dimension [m] — UNKNOWN";
  // parameter Real ped_box_y  = ... "Pedestal box y-dimension [m] — UNKNOWN";
  // parameter Real ped_box_z  = ... "Pedestal box z-dimension [m] — UNKNOWN";

  // ---- Control parameters ----
  parameter Real Kp = 300.0 "PD proportional gain [N.m/rad]";
  parameter Real Kd = 30.0  "PD derivative gain [N.m.s/rad]";
  parameter Real F_dist = 8.0 "Tip load disturbance force magnitude [N]";
  parameter Real ctrl_rate = 200.0 "Control loop rate [Hz]";

  // ---- Mission parameters ----
  parameter Real T_run  = 14.0   "Total run duration [s]";
  parameter Real T_move = 7.0    "Reference trajectory completion time [s]";
  parameter Real T_hold_start = 9.333 "Hold phase start [s] (2/3 * T_run)";
  parameter Real T_dist_start = 4.667 "Disturbance start [s] (1/3 * T_run)";
  parameter Real T_dist_end   = 9.333 "Disturbance end   [s] (2/3 * T_run)";
  parameter Real q1_target = 0.8 "Target joint 1 position [rad]";
  parameter Real q2_target = 0.6 "Target joint 2 position [rad]";
  parameter Real pi_val = 3.14159265358979 "Pi constant";

  // ---- Derived link inertias (uniform rod about center) ----
  Real I1 = m1 * l1 * l1 / 12.0;
  Real I2 = m2 * l2 * l2 / 12.0;

  // ---- Joint states ----
  Real q1(start = 0.0, fixed = true) "Joint 1 position [rad]";
  Real q2(start = 0.0, fixed = true) "Joint 2 position [rad]";
  Real dq1(start = 0.0, fixed = true) "Joint 1 velocity [rad/s]";
  Real dq2(start = 0.0, fixed = true) "Joint 2 velocity [rad/s]";

  // ---- Reference trajectory ----
  Real s_ref "Smooth reference scalar 0..1";
  Real q1_ref "Reference joint 1 position [rad]";
  Real q2_ref "Reference joint 2 position [rad]";
  Real dq1_ref "Reference joint 1 velocity [rad/s]";
  Real dq2_ref "Reference joint 2 velocity [rad/s]";
  Real x_tip_ref "Reference tip x-position [m]";
  Real z_tip_ref "Reference tip z-position [m]";

  // ---- Commands ----
  Real tau1_cmd "Joint 1 commanded torque pre-saturation [N.m]";
  Real tau2_cmd "Joint 2 commanded torque pre-saturation [N.m]";
  Real tau1_sat "Joint 1 saturated torque [N.m]";
  Real tau2_sat "Joint 2 saturated torque [N.m]";

  // ---- Gravity compensation ----
  Real G1 "Gravity compensation torque joint 1 [N.m]";
  Real G2 "Gravity compensation torque joint 2 [N.m]";

  // ---- Sensor traces (joint encoders) ----
  Real q1_meas  "Joint 1 measured position [rad]";
  Real q2_meas  "Joint 2 measured position [rad]";
  Real dq1_meas "Joint 1 measured velocity [rad/s]";
  Real dq2_meas "Joint 2 measured velocity [rad/s]";

  // ---- Mass matrix and Coriolis ----
  Real M11 "Mass matrix (1,1) [kg.m2]";
  Real M12 "Mass matrix (1,2) [kg.m2]";
  Real M22 "Mass matrix (2,2) [kg.m2]";
  Real C1  "Coriolis/centrifugal term joint 1 [N.m]";
  Real C2  "Coriolis/centrifugal term joint 2 [N.m]";

  // ---- Disturbance ----
  Real dist_active "Disturbance active flag (0 or 1)";
  Real tau_dist1 "Disturbance torque joint 1 [N.m]";
  Real tau_dist2 "Disturbance torque joint 2 [N.m]";
  Real x_tip "Actual tip x-position [m]";
  Real z_tip "Actual tip z-position [m]";

  // ---- Tracking errors ----
  Real e1 "Joint 1 tracking error [rad]";
  Real e2 "Joint 2 tracking error [rad]";
  Real e_tip "Tip position tracking error norm [m]";

  // ---- Joint limit protection ----
  Real tau1_limit "Joint 1 soft-limit torque [N.m]";
  Real tau2_limit "Joint 2 soft-limit torque [N.m]";

equation
  // Mass matrix (2-link planar, rotation about Y, vertical plane)
  M11 = I1 + I2 + m1*(l1/2.0)*(l1/2.0)
        + m2*(l1*l1 + (l2/2.0)*(l2/2.0) + 2.0*l1*(l2/2.0)*cos(q2));
  M12 = I2 + m2*((l2/2.0)*(l2/2.0) + l1*(l2/2.0)*cos(q2));
  M22 = I2 + m2*(l2/2.0)*(l2/2.0);

  // Coriolis / centrifugal terms
  C1 = -m2*l1*(l2/2.0)*sin(q2)*(dq2*dq2 + 2.0*dq1*dq2);
  C2 =  m2*l1*(l2/2.0)*sin(q2)*dq1*dq1;

  // Gravity compensation torques
  G1 = (m1*(l1/2.0) + m2*l1)*g_grav*cos(q1) + m2*(l2/2.0)*g_grav*cos(q1 + q2);
  G2 =  m2*(l2/2.0)*g_grav*cos(q1 + q2);

  // Tip position
  x_tip = l1*cos(q1) + l2*cos(q1 + q2);
  z_tip = l1*sin(q1) + l2*sin(q1 + q2);

  // Reference tip position
  x_tip_ref = l1*cos(q1_ref) + l2*cos(q1_ref + q2_ref);
  z_tip_ref = l1*sin(q1_ref) + l2*sin(q1_ref + q2_ref);

  // Disturbance: 8 N downward tip force during middle third
  dist_active = if time >= T_dist_start and time <= T_dist_end then 1.0 else 0.0;
  tau_dist1 = dist_active * (-F_dist * x_tip);
  tau_dist2 = dist_active * (-F_dist * l2 * cos(q1 + q2));

  // Smooth reference trajectory (cosine interpolation, zero velocity endpoints)
  s_ref  = if time >= T_move then 1.0 else 0.5*(1.0 - cos(pi_val * time / T_move));
  q1_ref = q1_target * s_ref;
  q2_ref = q2_target * s_ref;
  dq1_ref = if time >= T_move then 0.0
            else q1_target * 0.5 * pi_val / T_move * sin(pi_val * time / T_move);
  dq2_ref = if time >= T_move then 0.0
            else q2_target * 0.5 * pi_val / T_move * sin(pi_val * time / T_move);

  // Soft joint-limit protection (activates 0.1 rad before hard limit)
  tau1_limit = if q1 > (q_max - 0.1) then -Kp*(q1 - (q_max - 0.1))
               else if q1 < (-(q_max - 0.1)) then -Kp*(q1 - (-(q_max - 0.1)))
               else 0.0;
  tau2_limit = if q2 > (q_max - 0.1) then -Kp*(q2 - (q_max - 0.1))
               else if q2 < (-(q_max - 0.1)) then -Kp*(q2 - (-(q_max - 0.1)))
               else 0.0;

  // PD control with gravity compensation and limit protection
  tau1_cmd = G1 + Kp*(q1_ref - q1) + Kd*(dq1_ref - dq1) + tau1_limit;
  tau2_cmd = G2 + Kp*(q2_ref - q2) + Kd*(dq2_ref - dq2) + tau2_limit;

  // Command saturation
  tau1_sat = if tau1_cmd > tau_max then tau_max
             else if tau1_cmd < -tau_max then -tau_max
             else tau1_cmd;
  tau2_sat = if tau2_cmd > tau_max then tau_max
             else if tau2_cmd < -tau_max then -tau_max
             else tau2_cmd;

  // Joint encoder sensors
  q1_meas  = q1;
  q2_meas  = q2;
  dq1_meas = dq1;
  dq2_meas = dq2;

  // Tracking errors
  e1 = q1_ref - q1;
  e2 = q2_ref - q2;
  e_tip = sqrt(max((x_tip_ref - x_tip)*(x_tip_ref - x_tip)
                  + (z_tip_ref - z_tip)*(z_tip_ref - z_tip), 0.0));

  // Equations of motion: M*ddq + C + G = tau_sat + tau_dist
  M11*der(dq1) + M12*der(dq2) = tau1_sat + tau_dist1 - C1 - G1;
  M12*der(dq1) + M22*der(dq2) = tau2_sat + tau_dist2 - C2 - G2;

  // Kinematic integration
  der(q1) = dq1;
  der(q2) = dq2;

  // Safety assertions
  assert(abs(q1) <= q_max + 0.01, "Joint 1 position limit exceeded");
  assert(abs(q2) <= q_max + 0.01, "Joint 2 position limit exceeded");
  assert(abs(tau1_sat) <= tau_max + 0.01, "Joint 1 torque saturation violated");
  assert(abs(tau2_sat) <= tau_max + 0.01, "Joint 2 torque saturation violated");

  annotation(
    experiment(StartTime = 0, StopTime = 14, Interval = 0.005, Tolerance = 1e-6),
    Documentation(info = "DuoArmPointD: 2-link articulated manipulator on 20 kg box pedestal.
      Links: 0.55 m (5 kg) and 0.38 m (3 kg) capsules.
      Revolute Y joints, limits ±1.6 rad, actuators ±70 N.m.
      PD joint-space control with gravity compensation.
      8 N downward tip disturbance during middle third (4.667–9.333 s).
      Target (0.8, 0.6) rad, hold for final third.
      Control rate 200 Hz, run time 14 s.
      Capsule radii and pedestal box dimensions not stated — left unknown."));
end DuoArmPointD;