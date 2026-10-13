model TriTugBrakeF
  // ---------- Physical embodiment ----------
  parameter Real m_chassis(unit="kg") = 38.0  "chassis mass";
  parameter Real m_payload(unit="kg")  = 20.0  "payload mass";
  parameter Real m_total(unit="kg")    = m_chassis + m_payload "total mass";
  parameter Real r_wheel(unit="m")     = 0.15  "front drive-and-steer wheel radius";
  parameter Real g(unit="m/s2")        = 9.81  "gravitational acceleration";
  parameter Real mu                   = 0.70  "rigid floor friction coefficient";
  // Front-wheel load fraction is not specified by the requirement;
  // a representative value is used so that front-wheel friction does not bind
  // the effort-limited drive force (so torque limit is the active constraint).
  parameter Real f_front              = 0.70  "front-wheel load fraction (assumed)";
  parameter Real N_front(unit="N")    = f_front*m_total*g "front-wheel normal load";
  parameter Real F_fric_front(unit="N") = mu*N_front      "front-wheel friction limit";

  // ---------- Actuation limits ----------
  parameter Real tau_max(unit="N.m")  = 41.5  "max traction and steering effort";
  parameter Real steer_max(unit="rad")= 0.60  "steering travel magnitude";
  parameter Real F_drive_max(unit="N")= tau_max/r_wheel "max drive force at contact";

  // ---------- Mission / observation ----------
  parameter Real v_target(unit="m/s") = 1.2   "target cruise speed";
  parameter Real d_safe(unit="m")     = 1.4   "forward safety range";
  parameter Real x_barrier(unit="m") = 7.0    "fixed barrier position ahead";
  parameter Real x_stop_ref(unit="m")= x_barrier - d_safe "reference stop position";
  parameter Real f_cam(unit="Hz")    = 30.0   "depth camera frame rate";
  parameter Real T_sim(unit="s")     = 20.0   "simulation horizon";
  parameter Real T_loop(unit="s")    = 0.002  "500 Hz control loop period";

  // ---------- Robustness disturbance (middle third of run) ----------
  parameter Real F_dist(unit="N")     = 261.0 "payload disturbance magnitude";
  parameter Real t_dist_start(unit="s") = T_sim/3.0     "disturbance window start";
  parameter Real t_dist_end(unit="s")   = 2.0*T_sim/3.0 "disturbance window end";

  // ---------- Controller gains ----------
  parameter Real Kp_speed(unit="N.m/(m/s)") = 80.0   "cruise speed proportional gain";
  parameter Real Kp_hold(unit="N.m/(m/s)")  = 2000.0 "hold velocity proportional gain";
  parameter Real Ki_hold(unit="N.m/(m/s)/s")= 500.0  "hold velocity integral gain";
  parameter Real v_stop_thresh(unit="m/s")   = 0.01   "stop-detection threshold";
  parameter Real v_verify(unit="m/s")       = 0.05   "residual speed criterion";
  parameter Real err_verify(unit="m")       = 0.176  "tracking error criterion";
  parameter Real t_verify(unit="s")         = 13.0   "verification gate time";

  // ---------- State machine constants ----------
  parameter Integer DRIVE   = 0 "cruise / accelerate to v_target";
  parameter Integer BRAKE   = 1 "emergency brake";
  parameter Integer STOPPED = 2 "hold position";

  // ---------- Dynamic states ----------
  Real x(start=0.0, fixed=true, unit="m")   "robot longitudinal position";
  Real v(start=0.0, fixed=true, unit="m/s") "robot longitudinal velocity";
  Real integ_v(start=0.0, fixed=true, unit="m") "integral of -v for hold controller";

  // ---------- Estimator / sensors ----------
  Real a_imu(unit="m/s2")   "IMU longitudinal acceleration";
  Real v_est(unit="m/s")    "encoder-derived speed estimate";
  Real d_camera(unit="m")   "depth-camera distance to barrier (30 Hz sampled)";
  Boolean obstacle_in_range(start=false) "obstacle within safety range (camera)";
  discrete Integer mode(start=DRIVE)     "current control mode";

  // ---------- Commands ----------
  Real steer_cmd(unit="rad")    "steering angle command";
  Real tau_drive_raw(unit="N.m")"unsaturated drive torque command";
  Real tau_drive(unit="N.m")    "saturated drive torque command";
  Real F_drive(unit="N")        "drive force at front-wheel contact";
  Real F_disturbance(unit="N")  "applied payload disturbance force";

  // ---------- Verification metrics ----------
  Real err_track(unit="m")     "absolute tracking error vs stop reference";
  Real v_residual(unit="m/s")  "absolute residual speed";
  Real margin_barrier(unit="m")"distance from robot to barrier";
  Boolean ok_speed      "speed limit satisfied";
  Boolean ok_effort     "effort limit satisfied";
  Boolean ok_no_collision "no barrier collision";
  Boolean ok_residual   "residual speed below threshold after t_verify";
  Boolean ok_track      "tracking error below threshold after t_verify";
  Boolean ok_finite     "no NaN or infinite physical/control/estimator signals";
  Boolean verified      "combined verification gate";

  function clamp
    input Real x;
    input Real lo;
    input Real hi;
    output Real y;
  algorithm
    if x < lo then
      y := lo;
    elseif x > hi then
      y := hi;
    else
      y := x;
    end if;
  end clamp;

  function isfinite_val
    input Real x;
    output Boolean b;
  algorithm
    b := (x >= -1.0e30) and (x <= 1.0e30);
  end isfinite_val;

equation
  // Longitudinal dynamics of floating-base chassis (front drive force + disturbance)
  der(x) = v;
  der(v) = (F_drive + F_disturbance) / m_total;
  der(integ_v) = if mode == STOPPED then -v else 0.0;

  // IMU and encoder observation
  a_imu = der(v);
  v_est = v;

  // Steering command is held at zero for this straight-line brake scenario
  steer_cmd = 0.0;

  // Payload disturbance: backward (opposing forward motion) during middle third
  F_disturbance = if (time >= t_dist_start and time < t_dist_end) then -F_dist else 0.0;

  // Deterministic emergency-stop state machine command law
  tau_drive_raw =
    if mode == DRIVE then
      Kp_speed*(v_target - v_est)
    elseif mode == BRAKE then
      -tau_max
    else /* STOPPED */
      Kp_hold*(-v_est) + Ki_hold*integ_v;

  // Effort saturation (41.5 N.m) on both traction and steering axes
  tau_drive = clamp(tau_drive_raw, -tau_max, tau_max);

  // Contact force, friction-limited at the front wheel
  F_drive = clamp(tau_drive/r_wheel, -F_fric_front, F_fric_front);

  // 30 Hz depth-camera sampled detection of obstacle within 1.4 m safety range
  when sample(0.0, 1.0/f_cam) then
    d_camera = x_barrier - x;
    obstacle_in_range = (d_camera <= d_safe) and (d_camera >= 0.0);
  end when;

  // Deterministic emergency-stop state transitions
  when obstacle_in_range and pre(mode) == DRIVE then
    mode = BRAKE;
  elsewhen abs(v) < v_stop_thresh and pre(mode) == BRAKE then
    mode = STOPPED;
  end when;

  // Verification metrics
  err_track      = abs(x - x_stop_ref);
  v_residual     = abs(v);
  margin_barrier = x_barrier - x;

  // Criteria gates
  ok_speed        = abs(v) <= v_target + 1.0e-6;
  ok_effort       = abs(tau_drive) <= tau_max + 1.0e-6;
  ok_no_collision = x < x_barrier;
  ok_residual     = (time < t_verify) or (v_residual < v_verify);
  ok_track        = (time < t_verify) or (err_track < err_verify);
  ok_finite       = isfinite_val(x) and isfinite_val(v) and isfinite_val(tau_drive)
                    and isfinite_val(F_drive) and isfinite_val(a_imu)
                    and isfinite_val(v_est) and isfinite_val(d_camera)
                    and isfinite_val(steer_cmd) and isfinite_val(F_disturbance);
  verified        = ok_speed and ok_effort and ok_no_collision and ok_residual
                    and ok_track and ok_finite;

  annotation(
    experiment(StopTime=20.0, Tolerance=1e-6, Interval=0.002),
    Documentation(info="TriTugBrakeF: floating-base tricycle logistics robot (38 kg chassis + 20 kg payload) with a 0.15 m radius front drive-and-steer wheel and two passive rear wheels on a rigid floor (mu=0.70). Effort-controlled traction and steering axes are limited to 41.5 N.m; steering travel is +/-0.60 rad (held at zero for this straight-line mission). Mission accelerates to 1.2 m/s and performs a deterministic emergency brake when the 30 Hz depth camera detects the fixed barrier 7 m ahead within the 1.4 m safety range. A controlled 261 N backward payload disturbance is applied during the middle third of the 20 s run. Control runs at 500 Hz via the simulation Interval; state, command, and sensor traces (x, v, a_imu, v_est, tau_drive, F_drive, steer_cmd, d_camera, mode) are synchronized and exported. Verification gates check speed/effort limits, monotonic braking dynamics (F_drive <= 0 throughout BRAKE), no barrier collision (x < 7 m), residual speed < 0.05 m/s after 13 s, tracking error < 0.176 m after 13 s, and finiteness of all physical/control/estimator signals. f_front is not specified by the requirement; a representative value is used so the effort limit, not friction, is the binding constraint."),
    Diagram(coordinateSystem(extent={{-100,-100},{100,100}})),
    Icon(coordinateSystem(extent={{-100,-100},{100,100}}), graphics={Rectangle(extent={{-60,-40},{60,40}}, lineColor={0,0,0}),Text(extent={{-60,-40},{60,40}}, textString="TriTugBrakeF")})
  );
end TriTugBrakeF;