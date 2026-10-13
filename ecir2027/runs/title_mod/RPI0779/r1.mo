model HexaWalkTraverseE
  import Modelica.Math.*;
  import Modelica.Constants.*;

  // ===== Functions =====

  function terrainHeight
    "Terrain height field with 0.08 m rocks and two 0.12 m gaps"
    input Real x "World x position [m]";
    output Real h "Terrain height [m]";
  protected
    Real r1, r2, g1, g2;
  algorithm
    r1 := 0.08*exp(-((x - 1.5)/0.20)^2) + 0.06*exp(-((x - 2.5)/0.15)^2);
    r2 := 0.08*exp(-((x - 5.0)/0.20)^2) + 0.07*exp(-((x - 6.0)/0.18)^2);
    g1 := -0.12*(1.0/(1.0 + exp(-40.0*(x - 2.94))))*(1.0/(1.0 + exp(40.0*(x - 3.06))));
    g2 := -0.12*(1.0/(1.0 + exp(-40.0*(x - 6.94))))*(1.0/(1.0 + exp(40.0*(x - 7.06))));
    h := r1 + r2 + g1 + g2;
  end terrainHeight;

  function legIK
    "2-link inverse kinematics for femur-tibia chain"
    input Real rx "Horizontal reach from coxa tip [m]";
    input Real rz "Vertical drop positive downward [m]";
    input Real Lf "Femur length [m]";
    input Real Lt "Tibia length [m]";
    output Real q2 "Femur angle [rad]";
    output Real q3 "Tibia angle [rad]";
  protected
    Real cos_q3;
  algorithm
    cos_q3 := (rx*rx + rz*rz - Lf*Lf - Lt*Lt)/(2.0*Lf*Lt);
    if cos_q3 > 0.999 then
      cos_q3 := 0.999;
    elseif cos_q3 < -0.999 then
      cos_q3 := -0.999;
    end if;
    q3 := acos(cos_q3);
    q2 := atan2(rz, rx) - atan2(Lt*sin(q3), Lf + Lt*cos(q3));
  end legIK;

  function satT
    "Saturate torque to +/- tmax"
    input Real tau;
    input Real tmax;
    output Real result;
  algorithm
    if tau > tmax then
      result := tmax;
    elseif tau < -tmax then
      result := -tmax;
    else
      result := tau;
    end if;
  end satT;

  function maxAbs18
    "Max absolute value over 6x3 array"
    input Real arr[6,3];
    output Real result;
  algorithm
    result := 0.0;
    for i in 1:6 loop
      for j in 1:3 loop
        if abs(arr[i,j]) > result then
          result := abs(arr[i,j]);
        end if;
      end for;
    end for;
  end maxAbs18;

  function min6
    "Minimum of 6-element array"
    input Real arr[6];
    output Real result;
  algorithm
    result := arr[1];
    for i in 2:6 loop
      if arr[i] < result then
        result := arr[i];
      end if;
    end for;
  end min6;

  // ===== Physical Parameters =====
  parameter Real m_body = 15.0 "Body mass [kg]";
  parameter Real I_xx = 0.3 "Roll inertia [kg.m^2]";
  parameter Real I_yy = 0.5 "Pitch inertia [kg.m^2]";
  parameter Real I_zz = 0.4 "Yaw inertia [kg.m^2]";
  parameter Real body_radius = 0.20 "Capsule radius [m]";
  parameter Real body_length = 0.40 "Capsule length [m]";
  parameter Real L_coxa = 0.12 "Coxa link length [m]";
  parameter Real L_femur = 0.22 "Femur link length [m]";
  parameter Real L_tibia = 0.26 "Tibia link length [m]";
  parameter Real tau_max_val = 22.0 "Joint torque saturation [N.m]";
  parameter Real mu = 0.78 "Contact friction coefficient";
  parameter Real g_grav = 9.81 "Gravity [m/s^2]";
  parameter Real J_eff = 0.01 "Effective joint inertia [kg.m^2]";
  parameter Real B_eff = 0.05 "Joint damping [N.m.s/rad]";
  parameter Real Kp = 100.0 "Joint PD proportional [N.m/rad]";
  parameter Real Kd = 5.0 "Joint PD derivative [N.m.s/rad]";

  // ===== Mission Parameters =====
  parameter Real v_cmd = 0.25 "Commanded average speed [m/s]";
  parameter Real T_sim = 16.0 "Simulation duration [s]";
  parameter Real f_ctrl = 250.0 "Control frequency [Hz]";
  parameter Real dt_ctrl = 1.0/f_ctrl "Control timestep [s]";
  parameter Real F_push = 108.0 "Lateral push force [N]";
  parameter Real t_push_start = T_sim/3.0 "Push start time [s]";
  parameter Real t_push_end = 2.0*T_sim/3.0 "Push end time [s]";
  parameter Real clearance_req = 0.03 "Minimum foot clearance [m]";
  parameter Real attitude_req = 0.45 "Maximum attitude [rad]";
  parameter Real err_req = 0.135 "Maximum tracking error [m]";
  parameter Real t_check = 10.4 "Error check time [s]";
  parameter Real route_length = 4.0 "Route length [m]";

  // ===== Gait Parameters =====
  parameter Real T_gait = 1.0 "Gait period [s]";
  parameter Real duty = 0.6 "Stance duty factor";
  parameter Real stride = 0.25 "Stride length [m]";
  parameter Real R_nom = 0.42 "Nominal horizontal reach [m]";
  parameter Real z_nom = 0.35 "Nominal body height [m]";
  parameter Real swing_h = 0.06 "Swing foot clearance [m]";
  parameter Real k_c = 20000.0 "Contact spring stiffness [N/m]";
  parameter Real c_c = 500.0 "Contact damping [N.s/m]";
  parameter Real k_rep = 100000.0 "Torso repulsion stiffness [N/m]";
  parameter Real c_drag = 2.0 "Body aerodynamic drag [N.s/m]";

  // Standing pose joint angles
  parameter Real q2_stand = 0.553 "Standing femur angle [rad]";
  parameter Real q3_stand = 0.569 "Standing tibia angle [rad]";

  // Leg mounting configuration
  parameter Real mount_x[6] = {0.15, 0.0, -0.15, 0.15, 0.0, -0.15} "Mount x in body frame [m]";
  parameter Real mount_y[6] = {0.15, 0.15, 0.15, -0.15, -0.15, -0.15} "Mount y in body frame [m]";
  parameter Real leg_side[6] = {1.0, 1.0, 1.0, -1.0, -1.0, -1.0} "Leg side (+1 left, -1 right)";
  parameter Real phase_off[6] = {0.0, 0.5, 0.0, 0.5, 0.0, 0.5} "Gait phase offset (tripod)";

  // ===== Body States (6 DOF) =====
  Real x_b(start=0.0, fixed=true) "Body x position [m]";
  Real y_b(start=0.0, fixed=true) "Body y position [m]";
  Real z_b(start=0.35, fixed=true) "Body z position [m]";
  Real vx(start=0.0, fixed=true) "Body x velocity [m/s]";
  Real vy(start=0.0, fixed=true) "Body y velocity [m/s]";
  Real vz(start=0.0, fixed=true) "Body z velocity [m/s]";
  Real roll(start=0.0, fixed=true) "Body roll [rad]";
  Real pitch(start=0.0, fixed=true) "Body pitch [rad]";
  Real yaw(start=0.0, fixed=true) "Body yaw [rad]";
  Real wx(start=0.0, fixed=true) "Body roll rate [rad/s]";
  Real wy(start=0.0, fixed=true) "Body pitch rate [rad/s]";
  Real wz(start=0.0, fixed=true) "Body yaw rate [rad/s]";

  // ===== Leg Joint States (18 revolute joints) =====
  Real q[6,3] "Joint angles [rad]";
  Real qd[6,3] "Joint angular velocities [rad/s]";

  // ===== Forward Kinematics =====
  Real R_leg[6] "Horizontal reach from mount [m]";
  Real H_leg[6] "Vertical drop from mount [m]";
  Real foot_body_x[6] "Foot x in body frame [m]";
  Real foot_body_y[6] "Foot y in body frame [m]";
  Real foot_body_z[6] "Foot z in body frame [m]";
  Real foot_x[6] "Foot x in world frame [m]";
  Real foot_y[6] "Foot y in world frame [m]";
  Real foot_z[6] "Foot z in world frame [m]";
  Real dR_dt[6] "Rate of horizontal reach [m/s]";
  Real dH_dt[6] "Rate of vertical drop [m/s]";
  Real dfoot_body_x[6] "Foot body-frame x velocity [m/s]";
  Real dfoot_body_y[6] "Foot body-frame y velocity [m/s]";
  Real dfoot_body_z[6] "Foot body-frame z velocity [m/s]";
  Real foot_vx[6] "Foot world x velocity [m/s]";
  Real foot_vy[6] "Foot world y velocity [m/s]";
  Real foot_vz[6] "Foot world z velocity [m/s]";

  // ===== Contact =====
  Real terrain_h_foot[6] "Terrain height at foot [m]";
  Real penetration[6] "Foot penetration into terrain [m]";
  Real contact_fz[6] "Vertical contact force [N]";
  Real contact_fx[6] "X friction force [N]";
  Real contact_fy[6] "Y friction force [N]";
  Boolean in_contact[6] "Foot in contact flag";

  // ===== Body Forces and Torques =====
  Real total_fx "Total body x force [N]";
  Real total_fy "Total body y force [N]";
  Real total_fz "Total body z force [N]";
  Real total_tx "Total roll torque [N.m]";
  Real total_ty "Total pitch torque [N.m]";
  Real total_tz "Total yaw torque [N.m]";
  Real F_dist_y "Lateral disturbance force [N]";
  Real F_repulse_z "Torso repulsion force [N]";
  Real terrain_at_body "Terrain height at body x [m]";
  Real cos_yaw "cos(yaw)";
  Real sin_yaw "sin(yaw)";

  // ===== Controller =====
  Real phase[6] "Gait phase per leg [0..1]";
  Real swing_p[6] "Swing phase [0..1]";
  Real dx_des[6] "Desired foot x in body frame [m]";
  Real dz_clr[6] "Swing clearance offset [m]";
  Real foot_world_x_des[6] "Desired foot world x [m]";
  Real terrain_at_des[6] "Terrain height at desired foot [m]";
  Real dx_mount[6] "Desired foot x relative to mount [m]";
  Real dy_mount[6] "Desired foot y relative to mount [m]";
  Real R_mount[6] "Desired horizontal distance mount to foot [m]";
  Real rx_ik[6] "IK horizontal input [m]";
  Real rz_ik[6] "IK vertical input [m]";
  Real q_des[6,3] "Desired joint angles [rad]";
  Real qd_des[6,3] "Desired joint velocities [rad/s]";
  Real tau_cmd[6,3] "Unsaturated commanded torque [N.m]";
  Real tau_sat[6,3] "Saturated commanded torque [N.m]";
  Real depth_reading "Forward depth sensor reading [m]";

  // ===== Sensors =====
  Real imu_roll "IMU roll measurement [rad]";
  Real imu_pitch "IMU pitch measurement [rad]";
  Real imu_yaw "IMU yaw measurement [rad]";

  // ===== Acceptance Monitors =====
  Real clearance_vals[6] "Per-leg clearance values [m]";
  Real min_clearance "Minimum observed clearance [m]";
  Real max_attitude "Maximum attitude [rad]";
  Real path_error "Body-path tracking error [m]";
  Real max_tau_unsat "Maximum unsaturated torque [N.m]";
  Boolean ok_actuator "Actuator bounds satisfied";
  Boolean ok_clearance "Clearance satisfied";
  Boolean ok_attitude "Attitude satisfied";
  Boolean ok_route "Route completion satisfied";
  Boolean ok_tracking "Tracking error satisfied";
  Boolean ok_no_nan "No NaN/infinite values";
  Boolean all_pass "All acceptance criteria pass";

  // ===== Synchronized Traces =====
  Real trace_x, trace_y, trace_z "Body position trace [m]";
  Real trace_roll, trace_pitch, trace_yaw "Body orientation trace [rad]";
  Real trace_tau_max "Max saturated torque trace [N.m]";
  Real trace_depth "Depth sensor trace [m]";
  Real trace_contact_fz_sum "Total contact force trace [N]";

initial equation
  for i in 1:6 loop
    q[i,1] = 0.0;
    q[i,2] = q2_stand;
    q[i,3] = q3_stand;
  end for;
  for i in 1:6 loop
    for j in 1:3 loop
      qd[i,j] = 0.0;
    end for;
  end for;

equation
  // ===== Body Kinematics =====
  der(x_b) = vx;
  der(y_b) = vy;
  der(z_b) = vz;
  der(roll) = wx;
  der(pitch) = wy;
  der(yaw) = wz;

  // ===== Body Dynamics (simplified Euler, no gyroscopic coupling) =====
  der(vx) = total_fx/m_body;
  der(vy) = total_fy/m_body;
  der(vz) = total_fz/m_body;
  der(wx) = total_tx/I_xx;
  der(wy) = total_ty/I_yy;
  der(wz) = total_tz/I_zz;

  // Yaw trigonometry
  cos_yaw = cos(yaw);
  sin_yaw = sin(yaw);

  // ===== Forward Kinematics (6 legs x 3 joints) =====
  for i in 1:6 loop
    R_leg[i] = L_coxa + L_femur*cos(q[i,2]) + L_tibia*cos(q[i,2] + q[i,3]);
    H_leg[i] = L_femur*sin(q[i,2]) + L_tibia*sin(q[i,2] + q[i,3]);

    foot_body_x[i] = mount_x[i] + R_leg[i]*sin(q[i,1]);
    foot_body_y[i] = mount_y[i] + leg_side[i]*R_leg[i]*cos(q[i,1]);
    foot_body_z[i] = -H_leg[i];

    foot_x[i] = x_b + foot_body_x[i]*cos_yaw - foot_body_y[i]*sin_yaw;
    foot_y[i] = y_b + foot_body_x[i]*sin_yaw + foot_body_y[i]*cos_yaw;
    foot_z[i] = z_b + foot_body_z[i];

    // Foot velocity Jacobian
    dR_dt[i] = -L_femur*sin(q[i,2])*qd[i,2]
               - L_tibia*sin(q[i,2] + q[i,3])*(qd[i,2] + qd[i,3]);
    dH_dt[i] = L_femur*cos(q[i,2])*qd[i,2]
               + L_tibia*cos(q[i,2] + q[i,3])*(qd[i,2] + qd[i,3]);

    dfoot_body_x[i] = dR_dt[i]*sin(q[i,1]) + R_leg[i]*cos(q[i,1])*qd[i,1];
    dfoot_body_y[i] = leg_side[i]*(dR_dt[i]*cos(q[i,1])
                       - R_leg[i]*sin(q[i,1])*qd[i,1]);
    dfoot_body_z[i] = -dH_dt[i];

    foot_vx[i] = vx + dfoot_body_x[i];
    foot_vy[i] = vy + dfoot_body_y[i];
    foot_vz[i] = vz + dfoot_body_z[i];
  end for;

  // ===== Contact Model (spring-damper + Coulomb friction) =====
  for i in 1:6 loop
    terrain_h_foot[i] = terrainHeight(foot_x[i]);
    penetration[i] = max(0.0, terrain_h_foot[i] - foot_z[i]);
    in_contact[i] = terrain_h_foot[i] > foot_z[i];

    contact_fz[i] = if terrain_h_foot[i] > foot_z[i] then
      max(0.0, k_c*(terrain_h_foot[i] - foot_z[i]) - c_c*foot_vz[i])
    else 0.0;

    contact_fx[i] = -mu*contact_fz[i]*tanh(foot_vx[i]/0.01);
    contact_fy[i] = -mu*contact_fz[i]*tanh(foot_vy[i]/0.01);
  end for;

  // ===== Lateral Push Disturbance (middle third, smoothed) =====
  F_dist_y = F_push*(tanh(10.0*(time - t_push_start))
             - tanh(10.0*(time - t_push_end)))/2.0;

  // ===== Torso-Terrain Collision Prohibition =====
  terrain_at_body = terrainHeight(x_b);
  F_repulse_z = max(0.0, k_rep*(0.03 - (z_b - body_radius - terrain_at_body)));

  // ===== Body Forces =====
  total_fx = contact_fx[1] + contact_fx[2] + contact_fx[3]
           + contact_fx[4] + contact_fx[5] + contact_fx[6] - c_drag*vx;
  total_fy = contact_fy[1] + contact_fy[2] + contact_fy[3]
           + contact_fy[4] + contact_fy[5] + contact_fy[6] - c_drag*vy + F_dist_y;
  total_fz = contact_fz[1] + contact_fz[2] + contact_fz[3]
           + contact_fz[4] + contact_fz[5] + contact_fz[6]
           - m_body*g_grav + F_repulse_z;

  // ===== Body Torques =====
  total_tx = (foot_body_y[1]*contact_fz[1] - foot_body_z[1]*contact_fy[1])
           + (foot_body_y[2]*contact_fz[2] - foot_body_z[2]*contact_fy[2])
           + (foot_body_y[3]*contact_fz[3] - foot_body_z[3]*contact_fy[3])
           + (foot_body_y[4]*contact_fz[4] - foot_body_z[4]*contact_fy[4])
           + (foot_body_y[5]*contact_fz[5] - foot_body_z[5]*contact_fy[5])
           + (foot_body_y[6]*contact_fz[6] - foot_body_z[6]*contact_fy[6]);

  total_ty = (foot_body_z[1]*contact_fx[1] - foot_body_x[1]*contact_fz[1])
           + (foot_body_z[2]*contact_fx[2] - foot_body_x[2]*contact_fz[2])
           + (foot_body_z[3]*contact_fx[3] - foot_body_x[3]*contact_fz[3])
           + (foot_body_z[4]*contact_fx[4] - foot_body_x[4]*contact_fz[4])
           + (foot_body_z[5]*contact_fx[5] - foot_body_x[5]*contact_fz[5])
           + (foot_body_z[6]*contact_fx[6] - foot_body_x[6]*contact_fz[6]);

  total_tz = (foot_body_x[1]*contact_fy[1] - foot_body_y[1]*contact_fx[1])
           + (foot_body_x[2]*contact_fy[2] - foot_body_y[2]*contact_fx[2])
           + (foot_body_x[3]*contact_fy[3] - foot_body_y[3]*contact_fx[3])
           + (foot_body_x[4]*contact_fy[4] - foot_body_y[4]*contact_fx[4])
           + (foot_body_x[5]*contact_fy[5] - foot_body_y[5]*contact_fx[5])
           + (foot_body_x[6]*contact_fy[6] - foot_body_y[6]*contact_fx[6]);

  // ===== Controller: Gait Scheduler + Foothold Planning + Swing Trajectory =====
  // Continuous-time controller; intended 250 Hz update rate (parameter f_ctrl).
  for i in 1:6 loop
    // Gait phase (tripod: legs 1,3,5 vs 2,4,6)
    phase[i] = mod(time/T_gait + phase_off[i], 1.0);
    swing_p[i] = if phase[i] >= duty then
      (phase[i] - duty)/(1.0 - duty) else 0.0;

    // Desired foot x oscillates +/- stride/2 in body frame
    dx_des[i] = if phase[i] < duty then
      mount_x[i] + stride/2.0 - stride*phase[i]/duty
    else
      mount_x[i] - stride/2.0 + stride*swing_p[i];

    // Swing clearance trajectory (sinusoidal lift)
    dz_clr[i] = if phase[i] >= duty then
      swing_h*sin(pi*swing_p[i])
    else 0.0;

    // Foothold planning: desired foot world x for terrain lookup
    foot_world_x_des[i] = x_b + dx_des[i];

    // Terrain at desired foothold (max in +/-0.15 m vicinity for obstacle clearance)
    terrain_at_des[i] = max(terrainHeight(foot_world_x_des[i] - 0.15),
                       max(terrainHeight(foot_world_x_des[i]),
                           terrainHeight(foot_world_x_des[i] + 0.15)));

    // Inverse kinematics inputs
    dx_mount[i] = dx_des[i] - mount_x[i];
    dy_mount[i] = leg_side[i]*R_nom;
    R_mount[i] = sqrt(dx_mount[i]^2 + dy_mount[i]^2);
    rx_ik[i] = max(R_mount[i] - L_coxa, 0.01);
    rz_ik[i] = max(z_b - terrain_at_des[i] - dz_clr[i], 0.01);

    // Coxa angle (direction in body frame)
    q_des[i,1] = atan2(dx_mount[i], dy_mount[i]);

    // Femur and tibia from 2-link IK
    (q_des[i,2], q_des[i,3]) = legIK(rx_ik[i], rz_ik[i], L_femur, L_tibia);

    // Desired joint velocities (zero setpoint for PD damping)
    qd_des[i,1] = 0.0;
    qd_des[i,2] = 0.0;
    qd_des[i,3] = 0.0;

    // PD joint control with 22 N.m saturation
    for j in 1:3 loop
      tau_cmd[i,j] = Kp*(q_des[i,j] - q[i,j]) + Kd*(qd_des[i,j] - qd[i,j]);
      tau_sat[i,j] = satT(tau_cmd[i,j], tau_max_val);
    end for;
  end for;

  // ===== Joint Dynamics (18 actuators) =====
  for i in 1:6 loop
    for j in 1:3 loop
      der(q[i,j]) = qd[i,j];
      der(qd[i,j]) = (tau_sat[i,j] - B_eff*qd[i,j])/J_eff;
    end for;
  end for;

  // ===== Sensors =====
  // IMU
  imu_roll = roll;
  imu_pitch = pitch;
  imu_yaw = yaw;

  // Forward depth measurement (terrain 0.3 m ahead)
  depth_reading = terrainHeight(x_b + 0.3);

  // ===== Synchronized Traces =====
  trace_x = x_b;
  trace_y = y_b;
  trace_z = z_b;
  trace_roll = roll;
  trace_pitch = pitch;
  trace_yaw = yaw;
  trace_tau_max = maxAbs18(tau_sat);
  trace_depth = depth_reading;
  trace_contact_fz_sum = contact_fz[1] + contact_fz[2] + contact_fz[3]
                        + contact_fz[4] + contact_fz[5] + contact_fz[6];

  // ===== Acceptance Monitors (fail-closed) =====
  // Clearance: min foot height above terrain during swing
  for i in 1:6 loop
    clearance_vals[i] = if phase[i] >= duty then
      foot_z[i] - terrain_h_foot[i]
    else 1.0e9;
  end for;
  min_clearance = min6(clearance_vals);

  // Attitude: max of roll and pitch
  max_attitude = max(abs(roll), abs(pitch));

  // Path tracking error
  path_error = abs(x_b - v_cmd*time);

  // Actuator bounds (check unsaturated command)
  max_tau_unsat = maxAbs18(tau_cmd);

  // Fail-closed acceptance checks
  ok_actuator = max_tau_unsat <= tau_max_val*1.001;
  ok_clearance = min_clearance >= clearance_req;
  ok_attitude = max_attitude < attitude_req;
  ok_route = x_b >= route_length*0.9;
  ok_tracking = if time >= t_check then path_error < err_req else true;
  ok_no_nan = abs(x_b) < 1.0e10 and abs(y_b) < 1.0e10 and abs(z_b) < 1.0e10
              and abs(roll) < 1.0e10 and abs(pitch) < 1.0e10 and abs(yaw) < 1.0e10
              and abs(vx) < 1.0e10 and abs(vy) < 1.0e10 and abs(vz) < 1.0e10;

  all_pass = ok_actuator and ok_clearance and ok_attitude
           and ok_route and ok_tracking and ok_no_nan;

  annotation(
    experiment(StopTime = 16.0, Tolerance = 1e-6, Interval = 0.004),
    Documentation(info = "HexaWalkTraverseE: Floating-base hexapod traversing a height field
      with 0.08 m rocks and two 0.12 m gaps at commanded speed v_cmd.
      Plant: 15 kg capsule body, 6 legs x 3 revolute joints (coxa 0.12 m,
      femur 0.22 m, tibia 0.26 m), 18 saturated actuators (22 N.m bound),
      contact friction 0.78, torso-terrain collision prohibited.
      Controller: tripod gait, terrain-aware foothold planning, swing-foot
      trajectory control, 108 N lateral push in middle third.
      Sensors: joint encoders, IMU, contact force, forward depth.
      Acceptance: fail-closed (actuator bounds, clearance > 0.03 m,
      attitude < 0.45 rad, route completion, tracking error < 0.135 m
      after 10.4 s, no NaN/Inf).")
  );
end HexaWalkTraverseE;