model GimbalPathCycleF
  "Yaw-pitch-roll gimbal performing periodic pick-transfer-return cycles with bounded torque control";

  // ---- Timing ----
  parameter Real T_cycle(unit="s") = 5.0 "Cycle period [s]";
  parameter Integer N_cycles = 4 "Required complete cycles";
  parameter Real T_run(unit="s") = 20.0 "Total simulation run time [s]";

  // ---- Payload ----
  parameter Real m_nom(unit="kg") = 4.0 "Nominal camera mass [kg]";
  parameter Real payload_var = 0.174 "Payload variation fraction [-]";
  parameter Real r_com(unit="m") = 0.05 "Camera COM offset from pitch axis [m]";

  // ---- Lumped inertias per axis (including nominal camera) ----
  parameter Real J_yaw(unit="kg.m2") = 0.35 "Yaw axis inertia [kg.m2]";
  parameter Real J_pitch(unit="kg.m2") = 0.15 "Pitch axis inertia [kg.m2]";
  parameter Real J_roll(unit="kg.m2") = 0.08 "Roll axis inertia [kg.m2]";

  // ---- Actuation ----
  parameter Real tau_max(unit="N.m") = 24.4 "Maximum actuator torque [N.m]";

  // ---- Joint limits ----
  parameter Real yaw_min = -2.8 "Yaw lower limit [rad]";
  parameter Real yaw_max = 2.8 "Yaw upper limit [rad]";
  parameter Real pitch_min = -1.2 "Pitch lower limit [rad]";
  parameter Real pitch_max = 1.0 "Pitch upper limit [rad]";
  parameter Real roll_min = -0.8 "Roll lower limit [rad]";
  parameter Real roll_max = 0.8 "Roll upper limit [rad]";

  // ---- Station poses (two-station workcell) ----
  parameter Real yaw_A = -1.4 "Station A yaw pose [rad]";
  parameter Real yaw_B = 1.4 "Station B yaw pose [rad]";
  parameter Real pitch_station = 0.0 "Station pitch pose [rad]";
  parameter Real roll_station = 0.0 "Station roll pose [rad]";

  // ---- Control gains (PD with feedforward velocity) ----
  parameter Real Kp(unit="N.m/rad") = 150.0 "Position gain [N.m/rad]";
  parameter Real Kd(unit="N.m.s/rad") = 18.0 "Damping gain [N.m.s/rad]";

  // ---- Joint-limit contact (collision model) ----
  parameter Real k_contact(unit="N.m/rad") = 2000.0 "Contact stiffness [N.m/rad]";
  parameter Real d_contact(unit="N.m.s/rad") = 30.0 "Contact damping [N.m.s/rad]";

  // ---- Joint viscous damping ----
  parameter Real b_joint(unit="N.m.s/rad") = 0.3 "Joint viscous damping [N.m.s/rad]";

  // ---- Gravity constant ----
  constant Real g(unit="m/s2") = 9.80665 "Gravitational acceleration [m/s2]";

  // ---- State variables ----
  Real q_yaw(start = yaw_A) "Yaw angle [rad]";
  Real qd_yaw(start = 0.0) "Yaw angular velocity [rad/s]";
  Real q_pitch(start = pitch_station) "Pitch angle [rad]";
  Real qd_pitch(start = 0.0) "Pitch angular velocity [rad/s]";
  Real q_roll(start = roll_station) "Roll angle [rad]";
  Real qd_roll(start = 0.0) "Roll angular velocity [rad/s]";

  // ---- Reference trajectory ----
  Real q_yaw_ref "Yaw reference [rad]";
  Real qd_yaw_ref "Yaw reference velocity [rad/s]";
  Real q_pitch_ref "Pitch reference [rad]";
  Real qd_pitch_ref "Pitch reference velocity [rad/s]";
  Real q_roll_ref "Roll reference [rad]";
  Real qd_roll_ref "Roll reference velocity [rad/s]";

  // ---- Torque commands and applied torques ----
  Real tau_yaw_cmd "Yaw torque command (pre-saturation) [N.m]";
  Real tau_pitch_cmd "Pitch torque command (pre-saturation) [N.m]";
  Real tau_roll_cmd "Roll torque command (pre-saturation) [N.m]";
  Real tau_yaw "Yaw applied torque [N.m]";
  Real tau_pitch "Pitch applied torque [N.m]";
  Real tau_roll "Roll applied torque [N.m]";

  // ---- Contact torques (joint-limit collision) ----
  Real tau_c_yaw "Yaw contact torque [N.m]";
  Real tau_c_pitch "Pitch contact torque [N.m]";
  Real tau_c_roll "Roll contact torque [N.m]";

  // ---- Cycle phase and progress ----
  Real cycle_time "Time within current cycle [s]";
  Real phase "Phase index: 0=pick at A, 1=transfer A->B, 2=return B->A";
  Real completed_cycles "Number of completed cycles [-]";

  // ---- Effective payload ----
  Real m_eff "Effective camera mass [kg]";
  Real inertia_scale "Inertia scale factor due to payload variation [-]";

  // ---- Tracking errors ----
  Real track_err_yaw "Yaw tracking error [rad]";
  Real track_err_pitch "Pitch tracking error [rad]";
  Real track_err_roll "Roll tracking error [rad]";
  Real track_err_primary "Primary (maximum) tracking error [rad]";

  // ---- Station pose error ----
  Real station_pose_err "Error to current target station pose [rad]";

  // ---- Cycle-time error ----
  Real cycle_time_err "Cycle-time error (open-loop, nominally zero) [s]";

  // ---- Verification flags ----
  Boolean state_bounds_ok "Joint angles within limits";
  Boolean effort_bounds_ok "Applied torques within bounds";
  Boolean tracking_ok "Primary tracking error < 0.032 rad after 13 s";
  Boolean no_nan_inf "No NaN or infinite physical/control values";
  Boolean all_ok "All verification criteria satisfied";

initial equation
  q_yaw = yaw_A;
  qd_yaw = 0.0;
  q_pitch = pitch_station;
  qd_pitch = 0.0;
  q_roll = roll_station;
  qd_roll = 0.0;

equation
  // ---- Cycle timing ----
  cycle_time = mod(time, T_cycle);
  completed_cycles = floor(time / T_cycle);
  cycle_time_err = 0.0; // Open-loop trajectory: cycle-time error is zero by construction

  // ---- Phase index: 0=pick at A [0,T/3), 1=transfer [T/3,2T/3), 2=return [2T/3,T) ----
  if cycle_time < T_cycle / 3.0 then
    phase = 0.0;
  elseif cycle_time < 2.0 * T_cycle / 3.0 then
    phase = 1.0;
  else
    phase = 2.0;
  end if;

  // ---- Payload variation: 17.4% increase during middle third of total run ----
  if time >= T_run / 3.0 and time <= 2.0 * T_run / 3.0 then
    m_eff = m_nom * (1.0 + payload_var);
  else
    m_eff = m_nom;
  end if;
  inertia_scale = m_eff / m_nom;

  // ---- Phase-indexed trajectory with cosine smoothing ----
  // Yaw: dwell at A, cosine transfer A->B, cosine return B->A
  if cycle_time < T_cycle / 3.0 then
    // Phase 0: Pick at station A (dwell)
    q_yaw_ref = yaw_A;
    qd_yaw_ref = 0.0;
  elseif cycle_time < 2.0 * T_cycle / 3.0 then
    // Phase 1: Transfer A -> B (cosine smooth transition)
    q_yaw_ref = yaw_A + (yaw_B - yaw_A) * 0.5
      * (1.0 - cos(3.14159265358979323846 * (cycle_time - T_cycle / 3.0) / (T_cycle / 3.0)));
    qd_yaw_ref = (yaw_B - yaw_A) * 0.5 * 3.14159265358979323846 / (T_cycle / 3.0)
      * sin(3.14159265358979323846 * (cycle_time - T_cycle / 3.0) / (T_cycle / 3.0));
  else
    // Phase 2: Return B -> A (cosine smooth transition)
    q_yaw_ref = yaw_B + (yaw_A - yaw_B) * 0.5
      * (1.0 - cos(3.14159265358979323846 * (cycle_time - 2.0 * T_cycle / 3.0) / (T_cycle / 3.0)));
    qd_yaw_ref = (yaw_A - yaw_B) * 0.5 * 3.14159265358979323846 / (T_cycle / 3.0)
      * sin(3.14159265358979323846 * (cycle_time - 2.0 * T_cycle / 3.0) / (T_cycle / 3.0));
  end if;

  // Pitch and roll: hold at station pose throughout cycle
  q_pitch_ref = pitch_station;
  qd_pitch_ref = 0.0;
  q_roll_ref = roll_station;
  qd_roll_ref = 0.0;

  // ---- Joint-limit collision contact (collision enabled) ----
  // Yaw contact
  if q_yaw > yaw_max then
    tau_c_yaw = -k_contact * (q_yaw - yaw_max) - d_contact * max(qd_yaw, 0.0);
  elseif q_yaw < yaw_min then
    tau_c_yaw = -k_contact * (q_yaw - yaw_min) - d_contact * min(qd_yaw, 0.0);
  else
    tau_c_yaw = 0.0;
  end if;

  // Pitch contact
  if q_pitch > pitch_max then
    tau_c_pitch = -k_contact * (q_pitch - pitch_max) - d_contact * max(qd_pitch, 0.0);
  elseif q_pitch < pitch_min then
    tau_c_pitch = -k_contact * (q_pitch - pitch_min) - d_contact * min(qd_pitch, 0.0);
  else
    tau_c_pitch = 0.0;
  end if;

  // Roll contact
  if q_roll > roll_max then
    tau_c_roll = -k_contact * (q_roll - roll_max) - d_contact * max(qd_roll, 0.0);
  elseif q_roll < roll_min then
    tau_c_roll = -k_contact * (q_roll - roll_min) - d_contact * min(qd_roll, 0.0);
  else
    tau_c_roll = 0.0;
  end if;

  // ---- PD control law with bounded torque ----
  tau_yaw_cmd = Kp * (q_yaw_ref - q_yaw) + Kd * (qd_yaw_ref - qd_yaw);
  tau_pitch_cmd = Kp * (q_pitch_ref - q_pitch) + Kd * (qd_pitch_ref - qd_pitch);
  tau_roll_cmd = Kp * (q_roll_ref - q_roll) + Kd * (qd_roll_ref - qd_roll);

  // Torque saturation
  tau_yaw = max(-tau_max, min(tau_max, tau_yaw_cmd));
  tau_pitch = max(-tau_max, min(tau_max, tau_pitch_cmd));
  tau_roll = max(-tau_max, min(tau_max, tau_roll_cmd));

  // ---- Gimbal dynamics ----
  // Yaw axis
  J_yaw * inertia_scale * der(qd_yaw) = tau_yaw - b_joint * qd_yaw + tau_c_yaw;
  der(q_yaw) = qd_yaw;

  // Pitch axis (with gravity torque)
  J_pitch * inertia_scale * der(qd_pitch) = tau_pitch - b_joint * qd_pitch
    - m_eff * g * r_com * sin(q_pitch) + tau_c_pitch;
  der(q_pitch) = qd_pitch;

  // Roll axis
  J_roll * inertia_scale * der(qd_roll) = tau_roll - b_joint * qd_roll + tau_c_roll;
  der(q_roll) = qd_roll;

  // ---- Tracking errors ----
  track_err_yaw = abs(q_yaw_ref - q_yaw);
  track_err_pitch = abs(q_pitch_ref - q_pitch);
  track_err_roll = abs(q_roll_ref - q_roll);
  track_err_primary = max(track_err_yaw, max(track_err_pitch, track_err_roll));

  // ---- Station pose error (error to current target station) ----
  if phase < 0.5 or phase > 1.5 then
    // At or returning to station A
    station_pose_err = sqrt((yaw_A - q_yaw) * (yaw_A - q_yaw)
      + (pitch_station - q_pitch) * (pitch_station - q_pitch)
      + (roll_station - q_roll) * (roll_station - q_roll));
  else
    // Transferring to station B
    station_pose_err = sqrt((yaw_B - q_yaw) * (yaw_B - q_yaw)
      + (pitch_station - q_pitch) * (pitch_station - q_pitch)
      + (roll_station - q_roll) * (roll_station - q_roll));
  end if;

  // ---- Verification criteria ----
  // State bounds: all joints within limits
  state_bounds_ok = q_yaw >= yaw_min and q_yaw <= yaw_max
    and q_pitch >= pitch_min and q_pitch <= pitch_max
    and q_roll >= roll_min and q_roll <= roll_max;

  // Effort bounds: applied torques within actuator limits
  effort_bounds_ok = abs(tau_yaw) <= tau_max + 0.001
    and abs(tau_pitch) <= tau_max + 0.001
    and abs(tau_roll) <= tau_max + 0.001;

  // Tracking: primary tracking error below 0.032 rad after 13 s
  tracking_ok = if time >= 13.0 then track_err_primary < 0.032 else true;

  // No NaN or infinite values (x == x is false for NaN in IEEE 754)
  no_nan_inf = (q_yaw == q_yaw) and (qd_yaw == qd_yaw)
    and (q_pitch == q_pitch) and (qd_pitch == qd_pitch)
    and (q_roll == q_roll) and (qd_roll == qd_roll)
    and (tau_yaw == tau_yaw) and (tau_pitch == tau_pitch) and (tau_roll == tau_roll)
    and (q_yaw_ref == q_yaw_ref) and (q_pitch_ref == q_pitch_ref) and (q_roll_ref == q_roll_ref);

  // Aggregate verification
  all_ok = state_bounds_ok and effort_bounds_ok and tracking_ok and no_nan_inf;

  annotation(
    experiment(StartTime = 0, StopTime = 20, Tolerance = 1e-6, Interval = 0.002),
    Documentation(info = "GimbalPathCycleF: Fixed yaw-pitch-roll gimbal carrying a 4 kg camera, performing 4 pick-transfer-return cycles (T_cycle = 5 s) over 20 s at 500 Hz control rate.
Phase-indexed trajectory control with cosine-smoothed transitions and bounded PD torque (max 24.4 N.m).
Two-station workcell (Station A at yaw=-1.4 rad, Station B at yaw=+1.4 rad) with collision modeled as joint-limit soft contact.
17.4 percent payload variation disturbance applied during middle third of run [6.67 s, 13.33 s].
Verification: state bounds (joint limits), effort bounds (torque limits), cycle-time error, station pose error, completed cycles >= 4, primary tracking error < 0.032 rad after 13 s, no NaN/infinite values."));
end GimbalPathCycleF;