model GantryPathSplineE
  constant Real T_end(unit="s") = 16.0;
  constant Real Ts(unit="s") = 0.004 "250 Hz control update period";
  constant Real acceptanceTime(unit="s") = 10.4;

  // Waypoint timestamps: scenario placeholders; the requirement did not specify them.
  constant Real t0(unit="s") = 0.0;
  constant Real t1(unit="s") = T_end/3;
  constant Real t2(unit="s") = 2*T_end/3;
  constant Real t3(unit="s") = T_end;

  // Gantry travels and moving masses from the requirement.
  constant Real Lx(unit="m") = 1.8;
  constant Real Ly(unit="m") = 1.2;
  constant Real Lz(unit="m") = 0.55;
  constant Real m_x(unit="kg") = 18.0;
  constant Real m_y(unit="kg") = 12.0;
  constant Real m_z(unit="kg") = 7.0;

  // Waypoint coordinates: scenario placeholders within the stated travels;
  // the requirement did not specify the four poses.
  constant Real px0(unit="m") = 0.30;
  constant Real px1(unit="m") = 0.90;
  constant Real px2(unit="m") = 1.20;
  constant Real px3(unit="m") = 1.50;
  constant Real py0(unit="m") = 0.60;
  constant Real py1(unit="m") = 0.60;
  constant Real py2(unit="m") = 0.60;
  constant Real py3(unit="m") = 0.60;
  constant Real pz0(unit="m") = 0.20;
  constant Real pz1(unit="m") = 0.35;
  constant Real pz2(unit="m") = 0.25;
  constant Real pz3(unit="m") = 0.30;

  // Fixed cylindrical obstacle: location/radius are scenario placeholders;
  // only the 0.06 m required clearance is from the requirement.
  constant Real obs_x(unit="m") = 1.00;
  constant Real obs_y(unit="m") = 0.30;
  constant Real obs_r(unit="m") = 0.05;
  constant Real obs_z0(unit="m") = 0.0;
  constant Real obs_z1(unit="m") = 0.55;
  constant Real clearanceReq(unit="m") = 0.06;

  // Actuator and disturbance limits from the requirement.
  constant Real Fmax(unit="N") = 990.0;
  constant Real disturbanceMag(unit="N") = 12.0;
  // The requirement did not specify disturbance direction; this scenario applies +x tool force.

  // Controller gains: design choices, not specified by the requirement.
  constant Real Kp(unit="1/s2") = 100.0;
  constant Real Kd(unit="1/s") = 50.0;
  constant Real Ki(unit="1/s3") = 5.0;
  constant Real Klim(unit="N/m") = 2000.0;
  constant Real margin(unit="m") = 0.10;
  constant Real Fmargin(unit="N") = 1.0;

  // Acceptance and numerical-guard constants.
  constant Real trackingTol(unit="m") = 0.032;
  constant Real orientationTol(unit="rad") = 1e-9;
  constant Real forceTol(unit="N") = 1e-6;
  constant Real eps2(unit="m2") = 1e-12;
  constant Real boundM(unit="m") = 1e12;
  constant Real boundMps(unit="m/s") = 1e12;
  constant Real boundMps2(unit="m/s2") = 1e12;
  constant Real boundN(unit="N") = 1e12;
  constant Real boundMs(unit="m.s") = 1e12;
  constant Real boundM2(unit="m2") = 1e12;
  constant Real boundRad(unit="rad") = 1e12;

  // Plant states.
  Real qx(start=px0, fixed=true, unit="m") "X prismatic joint position";
  Real vx(start=0.0, fixed=true, unit="m/s") "X prismatic joint velocity";
  Real qy(start=py0, fixed=true, unit="m") "Y prismatic joint position";
  Real vy(start=0.0, fixed=true, unit="m/s") "Y prismatic joint velocity";
  Real qz(start=pz0, fixed=true, unit="m") "Z prismatic joint position";
  Real vz(start=0.0, fixed=true, unit="m/s") "Z prismatic joint velocity";

  // Desired trajectory and errors.
  Real px_des(unit="m");
  Real py_des(unit="m");
  Real pz_des(unit="m");
  Real vx_des(unit="m/s");
  Real vy_des(unit="m/s");
  Real vz_des(unit="m/s");
  Real ax_des(unit="m/s2");
  Real ay_des(unit="m/s2");
  Real az_des(unit="m/s2");
  Real ex(unit="m");
  Real ey(unit="m");
  Real ez(unit="m");
  Real errNorm2(unit="m2");
  Real cartError(unit="m");
  Real orientationError(unit="rad");
  Real clearance(unit="m");

  // Disturbance and wrist wrench.
  Real dist_x(unit="N");
  Real dist_y(unit="N");
  Real dist_z(unit="N");
  Real wrench_x(unit="N");
  Real wrench_y(unit="N");
  Real wrench_z(unit="N");

  // Discrete controller variables.
  discrete Real Fx_cmd(unit="N", start=0.0, fixed=true);
  discrete Real Fy_cmd(unit="N", start=0.0, fixed=true);
  discrete Real Fz_cmd(unit="N", start=0.0, fixed=true);
  discrete Real Fx_raw(unit="N", start=0.0, fixed=true);
  discrete Real Fy_raw(unit="N", start=0.0, fixed=true);
  discrete Real Fz_raw(unit="N", start=0.0, fixed=true);
  discrete Real Flim_x(unit="N", start=0.0, fixed=true);
  discrete Real Flim_y(unit="N", start=0.0, fixed=true);
  discrete Real Flim_z(unit="N", start=0.0, fixed=true);
  discrete Real int_ex(unit="m.s", start=0.0, fixed=true);
  discrete Real int_ey(unit="m.s", start=0.0, fixed=true);
  discrete Real int_ez(unit="m.s", start=0.0, fixed=true);

  // Synchronized traces.
  Real state_qx(unit="m") = qx;
  Real state_vx(unit="m/s") = vx;
  Real state_qy(unit="m") = qy;
  Real state_vy(unit="m/s") = vy;
  Real state_qz(unit="m") = qz;
  Real state_vz(unit="m/s") = vz;
  Real command_Fx(unit="N") = Fx_cmd;
  Real command_Fy(unit="N") = Fy_cmd;
  Real command_Fz(unit="N") = Fz_cmd;
  Real sensor_qx(unit="m") = qx;
  Real sensor_vx(unit="m/s") = vx;
  Real sensor_qy(unit="m") = qy;
  Real sensor_vy(unit="m/s") = vy;
  Real sensor_qz(unit="m") = qz;
  Real sensor_vz(unit="m/s") = vz;
  Real sensor_pose_x(unit="m") = qx;
  Real sensor_pose_y(unit="m") = qy;
  Real sensor_pose_z(unit="m") = qz;
  Real sensor_orient_error(unit="rad") = orientationError;
  Real sensor_wrench_x(unit="N") = wrench_x;
  Real sensor_wrench_y(unit="N") = wrench_y;
  Real sensor_wrench_z(unit="N") = wrench_z;

  Boolean acceptanceOk;

protected
  function smoothPos
    input Real t(unit="s");
    input Real t0(unit="s");
    input Real t1(unit="s");
    input Real t2(unit="s");
    input Real t3(unit="s");
    input Real p0(unit="m");
    input Real p1(unit="m");
    input Real p2(unit="m");
    input Real p3(unit="m");
    output Real y(unit="m");
  protected
    Real h(unit="s");
    Real s;
    Real dp(unit="m");
  algorithm
    if t <= t0 then
      y := p0;
    elseif t < t1 then
      h := t1 - t0; s := (t - t0)/h; dp := p1 - p0;
      y := p0 + dp*(3.0*s*s - 2.0*s*s*s);
    elseif t < t2 then
      h := t2 - t1; s := (t - t1)/h; dp := p2 - p1;
      y := p1 + dp*(3.0*s*s - 2.0*s*s*s);
    elseif t < t3 then
      h := t3 - t2; s := (t - t2)/h; dp := p3 - p2;
      y := p2 + dp*(3.0*s*s - 2.0*s*s*s);
    else
      y := p3;
    end if;
  end smoothPos;

  function smoothVel
    input Real t(unit="s");
    input Real t0(unit="s");
    input Real t1(unit="s");
    input Real t2(unit="s");
    input Real t3(unit="s");
    input Real p0(unit="m");
    input Real p1(unit="m");
    input Real p2(unit="m");
    input Real p3(unit="m");
    output Real y(unit="m/s");
  protected
    Real h(unit="s");
    Real s;
    Real dp(unit="m");
  algorithm
    if t <= t0 then
      y := 0.0;
    elseif t < t1 then
      h := t1 - t0; s := (t - t0)/h; dp := p1 - p0;
      y := dp*(6.0*s - 6.0*s*s)/h;
    elseif t < t2 then
      h := t2 - t1; s := (t - t1)/h; dp := p2 - p1;
      y := dp*(6.0*s - 6.0*s*s)/h;
    elseif t < t3 then
      h := t3 - t2; s := (t - t2)/h; dp := p3 - p2;
      y := dp*(6.0*s - 6.0*s*s)/h;
    else
      y := 0.0;
    end if;
  end smoothVel;

  function smoothAcc
    input Real t(unit="s");
    input Real t0(unit="s");
    input Real t1(unit="s");
    input Real t2(unit="s");
    input Real t3(unit="s");
    input Real p0(unit="m");
    input Real p1(unit="m");
    input Real p2(unit="m");
    input Real p3(unit="m");
    output Real y(unit="m/s2");
  protected
    Real h(unit="s");
    Real s;
    Real dp(unit="m");
  algorithm
    if t <= t0 then
      y := 0.0;
    elseif t < t1 then
      h := t1 - t0; s := (t - t0)/h; dp := p1 - p0;
      y := dp*(6.0 - 12.0*s)/(h*h);
    elseif t < t2 then
      h := t2 - t1; s := (t - t1)/h; dp := p2 - p1;
      y := dp*(6.0 - 12.0*s)/(h*h);
    elseif t < t3 then
      h := t3 - t2; s := (t - t2)/h; dp := p3 - p2;
      y := dp*(6.0 - 12.0*s)/(h*h);
    else
      y := 0.0;
    end if;
  end smoothAcc;

equation
  // Fixed Cartesian gantry plant: synchronized prismatic force-driven axes.
  // No damping or friction was stated, so only the stated masses and force actuators are modeled.
  der(qx) = vx;
  der(vx) = (Fx_cmd + dist_x)/m_x;
  der(qy) = vy;
  der(vy) = (Fy_cmd + dist_y)/m_y;
  der(qz) = vz;
  der(vz) = (Fz_cmd + dist_z)/m_z;

  // Controlled 12 N tool disturbance during the middle third.
  dist_x = if noEvent(time >= t1 and time <= t2) then disturbanceMag else 0.0;
  dist_y = 0.0;
  dist_z = 0.0;

  // Wrist wrench sensor when available.
  wrench_x = dist_x;
  wrench_y = dist_y;
  wrench_z = dist_z;

  // Cartesian spline through four timestamped poses; tool orientation is preserved by the prismatic structure.
  px_des = smoothPos(time, t0, t1, t2, t3, px0, px1, px2, px3);
  py_des = smoothPos(time, t0, t1, t2, t3, py0, py1, py2, py3);
  pz_des = smoothPos(time, t0, t1, t2, t3, pz0, pz1, pz2, pz3);
  vx_des = smoothVel(time, t0, t1, t2, t3, px0, px1, px2, px3);
  vy_des = smoothVel(time, t0, t1, t2, t3, py0, py1, py2, py3);
  vz_des = smoothVel(time, t0, t1, t2, t3, pz0, pz1, pz2, pz3);
  ax_des = smoothAcc(time, t0, t1, t2, t3, px0, px1, px2, px3);
  ay_des = smoothAcc(time, t0, t1, t2, t3, py0, py1, py2, py3);
  az_des = smoothAcc(time, t0, t1, t2, t3, pz0, pz1, pz2, pz3);

  // Operational-space tracking errors.
  ex = px_des - qx;
  ey = py_des - qy;
  ez = pz_des - qz;
  errNorm2 = ex*ex + ey*ey + ez*ez;
  cartError = if errNorm2 > eps2 then sqrt(errNorm2) else 0.0;
  orientationError = 0.0;

  // Obstacle clearance to the side of the vertical cylinder.
  clearance = if noEvent(qz >= obs_z0 and qz <= obs_z1) then
              sqrt(max((qx - obs_x)^2 + (qy - obs_y)^2, eps2)) - obs_r
            else
              boundM;

  // Fail-closed acceptance: joint bounds, effort bounds, Cartesian error, orientation error,
  // obstacle clearance, finite commands, and finite physical/control values.
  acceptanceOk =
    (qx >= 0.0 and qx <= Lx) and
    (qy >= 0.0 and qy <= Ly) and
    (qz >= 0.0 and qz <= Lz) and
    (Fx_cmd >= -(Fmax + forceTol) and Fx_cmd <= (Fmax + forceTol)) and
    (Fy_cmd >= -(Fmax + forceTol) and Fy_cmd <= (Fmax + forceTol)) and
    (Fz_cmd >= -(Fmax + forceTol) and Fz_cmd <= (Fmax + forceTol)) and
    (Fx_raw > -boundN and Fx_raw < boundN) and
    (Fy_raw > -boundN and Fy_raw < boundN) and
    (Fz_raw > -boundN and Fz_raw < boundN) and
    (Flim_x > -boundN and Flim_x < boundN) and
    (Flim_y > -boundN and Flim_y < boundN) and
    (Flim_z > -boundN and Flim_z < boundN) and
    (int_ex > -boundMs and int_ex < boundMs) and
    (int_ey > -boundMs and int_ey < boundMs) and
    (int_ez > -boundMs and int_ez < boundMs) and
    (qx == qx) and (qy == qy) and (qz == qz) and
    (vx == vx) and (vy == vy) and (vz == vz) and
    (px_des == px_des) and (py_des == py_des) and (pz_des == pz_des) and
    (vx_des == vx_des) and (vy_des == vy_des) and (vz_des == vz_des) and
    (ax_des == ax_des) and (ay_des == ay_des) and (az_des == az_des) and
    (wrench_x == wrench_x) and (wrench_y == wrench_y) and (wrench_z == wrench_z) and
    (errNorm2 == errNorm2) and (cartError == cartError) and
    (clearance == clearance) and (orientationError == orientationError) and
    (qx > -boundM and qx < boundM) and
    (qy > -boundM and qy < boundM) and
    (qz > -boundM and qz < boundM) and
    (vx > -boundMps and vx < boundMps) and
    (vy > -boundMps and vy < boundMps) and
    (vz > -boundMps and vz < boundMps) and
    (px_des > -boundM and px_des < boundM) and
    (py_des > -boundM and py_des < boundM) and
    (pz_des > -boundM and pz_des < boundM) and
    (vx_des > -boundMps and vx_des < boundMps) and
    (vy_des > -boundMps and vy_des < boundMps) and
    (vz_des > -boundMps and vz_des < boundMps) and
    (ax_des > -boundMps2 and ax_des < boundMps2) and
    (ay_des > -boundMps2 and ay_des < boundMps2) and
    (az_des > -boundMps2 and az_des < boundMps2) and
    (errNorm2 > -boundM2 and errNorm2 < boundM2) and
    (cartError > -boundM and cartError < boundM) and
    (clearance > -boundM and clearance < boundM) and
    (orientationError > -boundRad and orientationError < boundRad) and
    (orientationError <= orientationTol) and
    (clearance >= clearanceReq) and
    (if noEvent(time >= acceptanceTime) then cartError <= trackingTol else true);

  assert(acceptanceOk, "GantryPathSplineE fail-closed acceptance violated");

algorithm
  when sample(0, Ts) then
    // Operational-space controller with joint-limit avoidance and measured wrench compensation.
    int_ex := pre(int_ex) + (if abs(pre(Fx_cmd)) < Fmax - Fmargin then Ts*ex else 0.0);
    int_ey := pre(int_ey) + (if abs(pre(Fy_cmd)) < Fmax - Fmargin then Ts*ey else 0.0);
    int_ez := pre(int_ez) + (if abs(pre(Fz_cmd)) < Fmax - Fmargin then Ts*ez else 0.0);

    Flim_x := if qx < margin then Klim*(margin - qx)
              elseif qx > Lx - margin then -Klim*(qx - (Lx - margin))
              else 0.0;
    Flim_y := if qy < margin then Klim*(margin - qy)
              elseif qy > Ly - margin then -Klim*(qy - (Ly - margin))
              else 0.0;
    Flim_z := if qz < margin then Klim*(margin - qz)
              elseif qz > Lz - margin then -Klim*(qz - (Lz - margin))
              else 0.0;

    Fx_raw := m_x*(ax_des + Kp*ex + Kd*(vx_des - vx) + Ki*int_ex) - wrench_x + Flim_x;
    Fy_raw := m_y*(ay_des + Kp*ey + Kd*(vy_des - vy) + Ki*int_ey) - wrench_y + Flim_y;
    Fz_raw := m_z*(az_des + Kp*ez + Kd*(vz_des - vz) + Ki*int_ez) - wrench_z + Flim_z;

    Fx_cmd := max(-Fmax, min(Fmax, Fx_raw));
    Fy_cmd := max(-Fmax, min(Fmax, Fy_raw));
    Fz_cmd := max(-Fmax, min(Fmax, Fz_raw));
  end when;

  annotation(experiment(StartTime=0, StopTime=16, Interval=0.004, Tolerance=1e-6));
end GantryPathSplineE;