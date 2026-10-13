model AirTrioResilientA
  // ---- Stated physical facts ----
  parameter Real m = 1.8 "robot mass [kg]";
  parameter Real Tmax = 8.64 "per-rotor thrust magnitude limit [N]";
  parameter Real g = 9.81 "gravitational acceleration [m/s^2]";

  // ---- Stated scenario timing ----
  parameter Real Ts = 0.0125 "control period [s] (80 Hz)";
  parameter Real t_drop_start = 3.0 "communication dropout start [s] (inside middle third of 8 s)";
  parameter Real t_drop_end = 3.5 "communication dropout end [s] (0.5 s dropout)";

  // ---- Assumed values for facts not stated in the request ----
  parameter Real F_dist = 2.0 "shared environmental disturbance force [N] (assumed)";
  parameter Real sin_t = 0.3 "rotor tilt sine (assumed)";
  parameter Real cos_t = 0.953939 "rotor tilt cosine (assumed)";
  parameter Real kp = 8.0 "position control gain (assumed)";
  parameter Real kv = 5.0 "velocity control gain (assumed)";
  parameter Real kc = 3.0 "distributed consensus/formation gain (assumed)";
  parameter Real krep = 6.0 "collision-avoidance gain (assumed)";
  parameter Real d_safe = 0.6 "collision-avoidance radius [m] (assumed)";
  parameter Real d_form = 1.0 "formation circumradius [m] (assumed)";
  parameter Real route_speed = 0.75 "route speed [m/s] (assumed route)";
  parameter Real z_ref = 2.0 "cruise altitude [m] (assumed)";
  parameter Real route_len = 6.0 "route length [m] (assumed; completes at 8 s)";

  // Formation offsets (assumed equilateral triangle, horizontal)
  parameter Real ox[3] = {d_form, -d_form/2.0, -d_form/2.0};
  parameter Real oy[3] = {0.0, d_form*0.8660254, -d_form*0.8660254};

  // ---- Continuous robot state ----
  Real px[3], py[3], pz[3];
  Real vx[3], vy[3], vz[3];

  // ---- Continuous derived quantities ----
  Real Fx[3], Fy[3], Fz[3];
  Real Fdist_y;
  Real route_x;
  Real refx[3], refy[3], refz[3];

  // ---- Discrete control / communication state ----
  discrete Real Trot[12](each start=4.6) "12 independent rotor-thrust commands [N]";
  discrete Real prx[3](start={1.0,-0.5,-0.5}) "last-received peer x";
  discrete Real pry[3](start={0.0,0.8660254,-0.8660254});
  discrete Real prz[3](each start=2.0);
  discrete Real vrx[3](each start=0.0);
  discrete Real vry[3](each start=0.0);
  discrete Real vrz[3](each start=0.0);
  discrete Real tstamp[3](each start=0.0) "receive timestamps [s]";
  discrete Real ppx[3], ppy[3], ppz[3] "predicted peer positions";
  discrete Real cx[3], cy[3], cz[3] "consensus forces";
  discrete Real dx12, dy12, dx13, dy13, dx23, dy23, d12, d13, d23;
  discrete Real repx[3], repy[3] "collision-avoidance forces";
  discrete Real Ux[3], Uy[3], Uz[3], avgT[3];

  // ---- Traces / observable outputs ----
  Real track_err[3];
  Real primary_track_err;
  Real formation_err;
  discrete Real formation_err_degraded(start=0.0);
  discrete Real formation_err_recovered(start=0.0);
  Real range12, range13, range23;
  Real imu_ax[3], imu_ay[3], imu_az[3];
  Boolean commOK;
  Boolean route_complete;

initial equation
  px[1] = ox[1]; py[1] = oy[1]; pz[1] = z_ref;
  px[2] = ox[2]; py[2] = oy[2]; pz[2] = z_ref;
  px[3] = ox[3]; py[3] = oy[3]; pz[3] = z_ref;
  for i in 1:3 loop
    vx[i] = 0.0; vy[i] = 0.0; vz[i] = 0.0;
  end for;

equation
  // Route and per-robot references
  route_x = route_speed * time;
  route_complete = route_x >= route_len - 1e-9;
  for i in 1:3 loop
    refx[i] = route_x + ox[i];
    refy[i] = oy[i];
    refz[i] = z_ref;
  end for;

  // Communication availability
  commOK = not (time >= t_drop_start and time <= t_drop_end);

  // Shared environmental disturbance applied only while comms are down
  Fdist_y = if (time >= t_drop_start and time <= t_drop_end) then F_dist else 0.0;

  // Rotor-to-body force allocation (12 independent rotor-thrust groups)
  for i in 1:3 loop
    Fx[i] = sin_t * (Trot[4*i-3] - Trot[4*i-1]);
    Fy[i] = sin_t * (Trot[4*i-2] - Trot[4*i]);
    Fz[i] = cos_t * (Trot[4*i-3] + Trot[4*i-2] + Trot[4*i-1] + Trot[4*i]);
  end for;

  // Point-mass Newtonian dynamics
  for i in 1:3 loop
    der(px[i]) = vx[i];
    der(py[i]) = vy[i];
    der(pz[i]) = vz[i];
    der(vx[i]) = Fx[i] / m;
    der(vy[i]) = (Fy[i] + Fdist_y) / m;
    der(vz[i]) = (Fz[i] - m * g) / m;
  end for;

  // IMU (specific force) and peer-relative range sensor traces
  for i in 1:3 loop
    imu_ax[i] = Fx[i] / m;
    imu_ay[i] = (Fy[i] + Fdist_y) / m;
    imu_az[i] = (Fz[i] - m * g) / m;
  end for;
  range12 = max(sqrt((px[1]-px[2])^2 + (py[1]-py[2])^2 + (pz[1]-pz[2])^2), 1e-6);
  range13 = max(sqrt((px[1]-px[3])^2 + (py[1]-py[3])^2 + (pz[1]-pz[3])^2), 1e-6);
  range23 = max(sqrt((px[2]-px[3])^2 + (py[2]-py[3])^2 + (pz[2]-pz[3])^2), 1e-6);

  // Tracking error (primary = robot 1) and formation error (finite, nonzero-branch)
  for i in 1:3 loop
    track_err[i] = sqrt((px[i]-refx[i])^2 + (py[i]-refy[i])^2 + (pz[i]-refz[i])^2 + 1e-12);
  end for;
  primary_track_err = track_err[1];
  formation_err = sqrt(
    ((px[1]-px[2])-(ox[1]-ox[2]))^2 + ((py[1]-py[2])-(oy[1]-oy[2]))^2 +
    ((px[1]-px[3])-(ox[1]-ox[3]))^2 + ((py[1]-py[3])-(oy[1]-oy[3]))^2 +
    ((px[2]-px[3])-(ox[2]-ox[3]))^2 + ((py[2]-py[3])-(oy[2]-oy[3]))^2 + 1e-12);

  // Degraded (end of dropout) and recovered (near end) formation error snapshots
  when time >= t_drop_end then
    formation_err_degraded = formation_err;
  end when;
  when time >= 7.95 then
    formation_err_recovered = formation_err;
  end when;

  // ---- Distributed control at 80 Hz with prediction during dropout ----
  when sample(0, Ts) then
    // Local proprioception/exteroception: refresh last-received peer state + timestamps
    for i in 1:3 loop
      prx[i] = if not (time >= t_drop_start and time <= t_drop_end) then px[i] else pre(prx[i]);
      pry[i] = if not (time >= t_drop_start and time <= t_drop_end) then py[i] else pre(pry[i]);
      prz[i] = if not (time >= t_drop_start and time <= t_drop_end) then pz[i] else pre(prz[i]);
      vrx[i] = if not (time >= t_drop_start and time <= t_drop_end) then vx[i] else pre(vrx[i]);
      vry[i] = if not (time >= t_drop_start and time <= t_drop_end) then vy[i] else pre(vry[i]);
      vrz[i] = if not (time >= t_drop_start and time <= t_drop_end) then vz[i] else pre(vrz[i]);
      tstamp[i] = if not (time >= t_drop_start and time <= t_drop_end) then time else pre(tstamp[i]);
    end for;

    // Dead-reckoning prediction of peer positions from last-received state
    for i in 1:3 loop
      ppx[i] = prx[i] + vrx[i] * (time - tstamp[i]);
      ppy[i] = pry[i] + vry[i] * (time - tstamp[i]);
      ppz[i] = prz[i] + vrz[i] * (time - tstamp[i]);
    end for;

    // Consensus / formation coupling (explicit per robot)
    cx[1] = kc * (((ppx[2]-ppx[1])-(ox[2]-ox[1])) + ((ppx[3]-ppx[1])-(ox[3]-ox[1])));
    cy[1] = kc * (((ppy[2]-ppy[1])-(oy[2]-oy[1])) + ((ppy[3]-ppy[1])-(oy[3]-oy[1])));
    cz[1] = kc * ((ppz[2]-ppz[1]) + (ppz[3]-ppz[1]));
    cx[2] = kc * (((ppx[1]-ppx[2])-(ox[1]-ox[2])) + ((ppx[3]-ppx[2])-(ox[3]-ox[2])));
    cy[2] = kc * (((ppy[1]-ppy[2])-(oy[1]-oy[2])) + ((ppy[3]-ppy[2])-(oy[3]-oy[2])));
    cz[2] = kc * ((ppz[1]-ppz[2]) + (ppz[3]-ppz[2]));
    cx[3] = kc * (((ppx[1]-ppx[3])-(ox[1]-ox[3])) + ((ppx[2]-ppx[3])-(ox[2]-ox[3])));
    cy[3] = kc * (((ppy[1]-ppy[3])-(oy[1]-oy[3])) + ((ppy[2]-ppy[3])-(oy[2]-oy[3])));
    cz[3] = kc * ((ppz[1]-ppz[3]) + (ppz[2]-ppz[3]));

    // Pairwise horizontal distances (finite zero-error branch)
    dx12 = px[1]-px[2]; dy12 = py[1]-py[2];
    d12 = max(sqrt(dx12*dx12 + dy12*dy12), 1e-6);
    dx13 = px[1]-px[3]; dy13 = py[1]-py[3];
    d13 = max(sqrt(dx13*dx13 + dy13*dy13), 1e-6);
    dx23 = px[2]-px[3]; dy23 = py[2]-py[3];
    d23 = max(sqrt(dx23*dx23 + dy23*dy23), 1e-6);

    // Collision avoidance repulsion (bounded, pushes pairs apart)
    repx[1] = (if d12<d_safe then krep*(d_safe/d12-1.0)*dx12/d12 else 0.0)
             + (if d13<d_safe then krep*(d_safe/d13-1.0)*dx13/d13 else 0.0);
    repy[1] = (if d12<d_safe then krep*(d_safe/d12-1.0)*dy12/d12 else 0.0)
             + (if d13<d_safe then krep*(d_safe/d13-1.0)*dy13/d13 else 0.0);
    repx[2] = (if d12<d_safe then krep*(d_safe/d12-1.0)*(-dx12)/d12 else 0.0)
             + (if d23<d_safe then krep*(d_safe/d23-1.0)*dx23/d23 else 0.0);
    repy[2] = (if d12<d_safe then krep*(d_safe/d12-1.0)*(-dy12)/d12 else 0.0)
             + (if d23<d_safe then krep*(d_safe/d23-1.0)*dy23/d23 else 0.0);
    repx[3] = (if d13<d_safe then krep*(d_safe/d13-1.0)*(-dx13)/d13 else 0.0)
             + (if d23<d_safe then krep*(d_safe/d23-1.0)*(-dx23)/d23 else 0.0);
    repy[3] = (if d13<d_safe then krep*(d_safe/d13-1.0)*(-dy13)/d13 else 0.0)
             + (if d23<d_safe then krep*(d_safe/d23-1.0)*(-dy23)/d23 else 0.0);

    // Distributed control: desired net body force per robot
    for i in 1:3 loop
      Ux[i] = kp*((route_x + ox[i]) - px[i]) + kv*(route_speed - vx[i]) + cx[i] + repx[i];
      Uy[i] = kp*(oy[i] - py[i]) + kv*(0.0 - vy[i]) + cy[i] + repy[i];
      Uz[i] = m*g + kp*(z_ref - pz[i]) + kv*(0.0 - vz[i]) + cz[i];
      avgT[i] = Uz[i] / (4.0*cos_t);
    end for;

    // Allocation to 12 independent rotor thrusts with bounds [0, Tmax]
    for i in 1:3 loop
      Trot[4*i-3] = (if (avgT[i] + Ux[i]/(2.0*sin_t)) < 0.0 then 0.0
                      elseif (avgT[i] + Ux[i]/(2.0*sin_t)) > Tmax then Tmax
                      else (avgT[i] + Ux[i]/(2.0*sin_t)));
      Trot[4*i-1] = (if (avgT[i] - Ux[i]/(2.0*sin_t)) < 0.0 then 0.0
                      elseif (avgT[i] - Ux[i]/(2.0*sin_t)) > Tmax then Tmax
                      else (avgT[i] - Ux[i]/(2.0*sin_t)));
      Trot[4*i-2] = (if (avgT[i] + Uy[i]/(2.0*sin_t)) < 0.0 then 0.0
                      elseif (avgT[i] + Uy[i]/(2.0*sin_t)) > Tmax then Tmax
                      else (avgT[i] + Uy[i]/(2.0*sin_t)));
      Trot[4*i]   = (if (avgT[i] - Uy[i]/(2.0*sin_t)) < 0.0 then 0.0
                      elseif (avgT[i] - Uy[i]/(2.0*sin_t)) > Tmax then Tmax
                      else (avgT[i] - Uy[i]/(2.0*sin_t)));
    end for;
  end when;

  annotation (
    Experiment(StopTime=8.0, Tolerance=1e-4, Interval=0.0125),
    Documentation(info="AirTrioResilientA: three 1.8 kg quadrotors with 12 independent rotor-thrust groups (<=8.64 N/rotor). Distributed control with dead-reckoning peer prediction maintains coordinated motion through a controlled 0.5 s communication dropout (3.0-3.5 s) coincident with a shared environmental disturbance, then recovers the formation. Values not stated in the request (tilt, gains, geometry, route, disturbance magnitude) are declared as assumptions."));
end AirTrioResilientA;