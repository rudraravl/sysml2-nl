model DiffRoverBrakeC
  // Physical parameters (SI units)
  parameter Real m = 19.0 "chassis mass [kg]";
  parameter Real Lx = 0.65 "chassis length [m]";
  parameter Real Ly = 0.44 "chassis width [m]";
  parameter Real Lz = 0.22 "chassis height [m]";
  parameter Real r_w = 0.10 "driven wheel radius [m]";
  parameter Real track = 0.46 "wheel separation [m]";
  parameter Real mu = 0.70 "floor friction coefficient [1]";
  parameter Real g = 9.81 "gravitational acceleration [m/s2]";
  parameter Real x_barrier = 7.0 "barrier position ahead of start [m]";

  // Control / mission parameters
  parameter Real v_ref = 1.2 "target cruise speed [m/s]";
  parameter Real tau_max = 12.0 "max motor torque magnitude per wheel [N.m]";
  parameter Real safe_range = 1.4 "emergency-stop safety range [m]";
  parameter Real F_dist = 162.0 "payload disturbance force magnitude [N]";
  parameter Real Kp = 150.0 "speed proportional gain [N.m/(m/s)]";
  parameter Real Ki = 300.0 "speed integral gain [N.m/(m/s)/s]";
  parameter Real Ts = 0.008 "control sample time [s] (125 Hz)";
  parameter Real Tc = 0.033333333 "depth camera sample time [s] (30 Hz)";
  parameter Real v_stop_thresh = 0.04 "stopped speed threshold [m/s]";
  parameter Real T_dist_start = 4.0 "disturbance window start [s]";
  parameter Real T_dist_end = 8.0 "disturbance window end [s]";
  parameter Real T_run = 12.0 "mission duration [s]";

  // Continuous states
  Real x_pos(start=0.0, fixed=true) "forward position [m]";
  Real v(start=0.0, fixed=true) "forward speed [m/s]";
  Real ierr(start=0.0, fixed=true) "speed integral error term [N.m]";

  // Discrete state
  Integer mode(start=1) "1=DRIVE 2=BRAKE 3=STOPPED";

  // Sampled observations
  discrete Real depth_cam(start=7.0) "30 Hz depth camera range reading [m]";

  // Sensor outputs
  Real a_imu "IMU longitudinal acceleration [m/s2]";
  Real depth_dist "instantaneous range to barrier [m]";
  Real enc_v "encoder-derived forward speed [m/s]";

  // Command outputs
  Real tau_R "right wheel motor torque command [N.m]";
  Real tau_L "left wheel motor torque command [N.m]";

  // Forces and diagnostics
  Real F_drive "net longitudinal tire force [N]";
  Real F_disturbance "active disturbance force [N]";
  Real F_brake_lim "friction-limited brake force magnitude [N]";
  Real v_residual "absolute residual speed [m/s]";
  Real stop_margin "remaining distance to barrier [m]";
  Boolean obstacle_in_range;

protected
  Real tau_cmd "per-wheel torque command [N.m]";
  Real tau_pi "unsaturated PI output [N.m]";
  Real v_err "speed tracking error [m/s]";

equation
  // Sensor equations
  a_imu = der(v);
  enc_v = v;
  depth_dist = max(x_barrier - x_pos, 0.0);
  obstacle_in_range = depth_dist <= safe_range;

  // Disturbance injection: middle third of the 12 s run -> [4 s, 8 s]
  F_disturbance = if (time >= T_dist_start and time <= T_dist_end) then F_dist else 0.0;

  // Friction-limited brake force on rigid floor (mu = 0.70)
  F_brake_lim = mu * m * g;

  // Speed tracking error
  v_err = v_ref - v;

  // PI controller with conditional (anti-windup) integration
  tau_pi = Kp*v_err + ierr;
  der(ierr) = if (mode == 1 and abs(tau_pi) < tau_max - 1.0e-6) then Ki*v_err else 0.0;

  // Per-wheel torque command, saturated, by mode
  tau_cmd = if mode == 1 then
              (if tau_pi > tau_max then tau_max elseif tau_pi < -tau_max then -tau_max else tau_pi)
            elseif mode == 2 then -tau_max
            else 0.0;

  // Symmetric commands => straight-line motion (continuous Y-axis wheel joints)
  tau_R = tau_cmd;
  tau_L = tau_cmd;

  // Net longitudinal force
  F_drive = if mode == 1 then 2.0*tau_cmd/r_w
            elseif mode == 2 then -F_brake_lim
            else F_disturbance;

  // Plant dynamics (planar, two driven wheels, one passive caster)
  m * der(v) = F_drive - F_disturbance;
  der(x_pos) = v;

  // Diagnostics
  v_residual = abs(v);
  stop_margin = x_barrier - x_pos;

  // Safety assertions
  assert(stop_margin >= 0.0, "Barrier collision: rover exceeded barrier position");
  assert(v_residual <= 5.0, "Speed exceeded safety bound");

  // Deterministic emergency-stop state machine (event-driven transitions)
  when mode == 1 and depth_dist <= safe_range then
    mode = 2;
  end when;

  when mode == 2 and v <= v_stop_thresh then
    mode = 3;
  end when;

  // 30 Hz depth camera recording of the stop
  when sample(0, Tc) then
    depth_cam = depth_dist;
  end when;

  annotation(
    experiment(StartTime=0, StopTime=12, Tolerance=1e-6, Interval=0.008),
    Documentation(info="DiffRoverBrakeC: floating-base differential-drive rover with deterministic emergency-stop state machine."));
end DiffRoverBrakeC;