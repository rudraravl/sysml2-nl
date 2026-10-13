model TiltWingDeliverE
  import Modelica.Constants.pi;
  import Modelica.Math.atan2;

  parameter Real m_fuselage(unit="kg")=6.2 "capsule fuselage mass";
  parameter Real rotorArm(unit="m")=0.62 "rotor distance from center";
  parameter Real wingSpan(unit="m")=1.8 "wing span";
  parameter Real tiltMin(unit="rad")=0.0 "rotor tilt joint lower travel";
  parameter Real tiltMax(unit="rad")=1.57 "rotor tilt joint upper travel";
  parameter Real thrustBoundPerRotor(unit="N")=57.2 "command bound per rotor";
  parameter Real tensionBound(unit="N")=2*thrustBoundPerRotor "cable tension bound from combined rotor thrust";

  parameter Real m_payload(unit="kg")=1.0 "payload mass not stated; selected for executable dynamics";
  parameter Real L_cable(unit="m")=1.0 "cable length not stated; selected for executable dynamics";
  parameter Real g(unit="m/s2")=9.81;
  parameter Real cDrag(unit="kg/m")=5.0 "drag coefficient not stated; selected for executable dynamics";
  parameter Real gustForce(unit="N")=9.6;
  parameter Real duration(unit="s")=16.0;
  parameter Real Ts(unit="s")=0.004 "250 Hz control and trace period";
  parameter Real tLiftEnd(unit="s")=2.0;
  parameter Real tCruiseEnd(unit="s")=8.0;
  parameter Real tLowerStart(unit="s")=12.0;
  parameter Real tLowerEnd(unit="s")=15.0;
  parameter Real gustStart(unit="s")=duration/3 "middle third start";
  parameter Real gustEnd(unit="s")=2*duration/3 "middle third end";
  parameter Real xTarget(unit="m")=5.0;
  parameter Real targetRadius(unit="m")=0.8;
  parameter Real zInitial(unit="m")=1.5 "initial fuselage height not stated; selected for executable dynamics";
  parameter Real zCruise(unit="m")=2.5 "cruise height not stated; selected for executable dynamics";
  parameter Real zLower(unit="m")=1.4 "lowering height not stated; selected for executable dynamics";
  parameter Real swingLimit(unit="rad")=0.45;
  parameter Real trackingLimit(unit="m")=0.27;
  parameter Real trackingTime(unit="s")=10.4;
  parameter Real acceptanceTime(unit="s")=15.5;
  parameter Real m_total(unit="kg")=m_fuselage + m_payload;
  parameter Real Fz_min(unit="N")=1.0;
  parameter Real zeroForce(unit="N")=0.0;
  parameter Real zeroAngle(unit="rad")=0.0;
  parameter Real tau_thrust(unit="s")=0.02;
  parameter Real tau_tilt(unit="s")=0.02;
  parameter Real Kp_x(unit="1/s2")=20.0;
  parameter Real Kd_x(unit="1/s")=12.0;
  parameter Real Ki_x(unit="1/s3")=1.0;
  parameter Real Kp_z(unit="1/s2")=10.0;
  parameter Real Kd_z(unit="1/s")=6.0;
  parameter Real Ki_z(unit="1/s3")=1.0;
  parameter Real K_swing(unit="m/s2")=2.0;
  parameter Real K_swing_d(unit="m/s")=1.5;

  Real x_f(unit="m", start=0.0);
  Real z_f(unit="m", start=zInitial);
  Real vx_f(unit="m/s", start=0.0);
  Real vz_f(unit="m/s", start=0.0);
  Real ax_f(unit="m/s2");
  Real az_f(unit="m/s2");
  Real theta_c(unit="rad", start=0.0);
  Real omega_c(unit="rad/s", start=0.0);
  Real x_payload(unit="m");
  Real z_payload(unit="m");
  Real T_c(unit="N");
  Real thrustL(unit="N", start=0.5*m_total*g);
  Real thrustR(unit="N", start=0.5*m_total*g);
  Real tiltL(unit="rad", start=0.0);
  Real tiltR(unit="rad", start=0.0);
  Real alpha(unit="rad");
  Real T_total(unit="N");
  Real F_thrust_x(unit="N");
  Real F_thrust_z(unit="N");
  Real F_drag_x(unit="N");
  Real F_drag_z(unit="N");
  Real F_gust_x(unit="N");
  Real F_ext_x(unit="N");
  Real F_ext_z(unit="N");
  Real y_rotor_plus(unit="m");
  Real y_rotor_minus(unit="m");
  Real wingHalfSpan(unit="m");
  Boolean rotorWithinWing;

  Real x_des(unit="m");
  Real vx_des(unit="m/s");
  Real ax_des(unit="m/s2");
  Real z_des(unit="m");
  Real vz_des(unit="m/s");
  Real az_des(unit="m/s2");

  Real sensor_x(unit="m", start=0.0);
  Real sensor_z(unit="m", start=zInitial);
  Real sensor_vx(unit="m/s", start=0.0);
  Real sensor_vz(unit="m/s", start=0.0);
  Real sensor_ax(unit="m/s2", start=0.0);
  Real sensor_az(unit="m/s2", start=0.0);
  Real sensor_theta(unit="rad", start=0.0);
  Real sensor_omega(unit="rad/s", start=0.0);
  Real sensor_T(unit="N", start=m_payload*g);

  Real trace_time(unit="s", start=0.0);
  Real trace_x(unit="m", start=0.0);
  Real trace_z(unit="m", start=zInitial);
  Real trace_vx(unit="m/s", start=0.0);
  Real trace_vz(unit="m/s", start=0.0);
  Real trace_theta(unit="rad", start=0.0);
  Real trace_omega(unit="rad/s", start=0.0);
  Real trace_T(unit="N", start=m_payload*g);
  Real trace_thrustCmdL(unit="N", start=0.5*m_total*g);
  Real trace_thrustCmdR(unit="N", start=0.5*m_total*g);
  Real trace_tiltCmdL(unit="rad", start=0.0);
  Real trace_tiltCmdR(unit="rad", start=0.0);
  Real trace_sensor_x(unit="m", start=0.0);
  Real trace_sensor_z(unit="m", start=zInitial);
  Real trace_sensor_theta(unit="rad", start=0.0);
  Real trace_sensor_T(unit="N", start=m_payload*g);

  Real ex(unit="m", start=0.0);
  Real evx(unit="m/s", start=0.0);
  Real ez(unit="m", start=0.0);
  Real evz(unit="m/s", start=0.0);
  Real ix(unit="m.s", start=0.0);
  Real iz(unit="m.s", start=0.0);
  Real ax_cmd(unit="m/s2", start=0.0);
  Real az_cmd(unit="m/s2", start=0.0);
  Real Fx_req(unit="N", start=0.0);
  Real Fz_req(unit="N", start=m_total*g);
  Real Fz_req_safe(unit="N", start=m_total*g);
  Real F_drag_ff_x(unit="N", start=0.0);
  Real F_drag_ff_z(unit="N", start=0.0);
  Real alpha_cmd(unit="rad", start=0.0);
  Real T_total_req(unit="N", start=m_total*g);
  Real T_per_req(unit="N", start=0.5*m_total*g);
  Real thrustCmdL(unit="N", start=0.5*m_total*g);
  Real thrustCmdR(unit="N", start=0.5*m_total*g);
  Real tiltCmdL(unit="rad", start=0.0);
  Real tiltCmdR(unit="rad", start=0.0);
  Boolean saturated(start=false);

  Boolean thrustBounded;
  Boolean tensionBounded;
  Boolean tiltBounded;
  Boolean swingBounded;
  Boolean noGroundStrike;
  Boolean trackingOk;
  Boolean finiteOk;
  Boolean runtimeOk;
  Boolean targetPlacement;
  Boolean fault(start=false);
  Boolean accepted;
  Real trackingError(unit="m");
  Real primaryTrackingError(unit="m");

equation
  y_rotor_plus = rotorArm;
  y_rotor_minus = -rotorArm;
  wingHalfSpan = wingSpan/2;
  rotorWithinWing = rotorArm <= wingHalfSpan;

  x_des = if time < tLiftEnd then 0.0 elseif time < tCruiseEnd then 0.5*xTarget*(1 - cos(pi*(time - tLiftEnd)/(tCruiseEnd - tLiftEnd))) else xTarget;
  vx_des = if time < tLiftEnd then 0.0 elseif time < tCruiseEnd then 0.5*xTarget*pi/(tCruiseEnd - tLiftEnd)*sin(pi*(time - tLiftEnd)/(tCruiseEnd - tLiftEnd)) else 0.0;
  ax_des = if time < tLiftEnd then 0.0 elseif time < tCruiseEnd then 0.5*xTarget*(pi/(tCruiseEnd - tLiftEnd))^2*cos(pi*(time - tLiftEnd)/(tCruiseEnd - tLiftEnd)) else 0.0;

  z_des = if time < tLiftEnd then zInitial + (zCruise - zInitial)*0.5*(1 - cos(pi*time/tLiftEnd)) elseif time < tLowerStart then zCruise elseif time < tLowerEnd then zCruise + (zLower - zCruise)*0.5*(1 - cos(pi*(time - tLowerStart)/(tLowerEnd - tLowerStart))) else zLower;
  vz_des = if time < tLiftEnd then (zCruise - zInitial)*0.5*pi/tLiftEnd*sin(pi*time/tLiftEnd) elseif time < tLowerStart then 0.0 elseif time < tLowerEnd then (zLower - zCruise)*0.5*pi/(tLowerEnd - tLowerStart)*sin(pi*(time - tLowerStart)/(tLowerEnd - tLowerStart)) else 0.0;
  az_des = if time < tLiftEnd then (zCruise - zInitial)*0.5*(pi/tLiftEnd)^2*cos(pi*time/tLiftEnd) elseif time < tLowerStart then 0.0 elseif time < tLowerEnd then (zLower - zCruise)*0.5*(pi/(tLowerEnd - tLowerStart))^2*cos(pi*(time - tLowerStart)/(tLowerEnd - tLowerStart)) else 0.0;

  der(x_f) = vx_f;
  der(z_f) = vz_f;
  der(vx_f) = ax_f;
  der(vz_f) = az_f;
  der(theta_c) = omega_c;
  der(omega_c) = -(g*sin(theta_c) + ax_f*cos(theta_c) + az_f*sin(theta_c))/L_cable;

  alpha = (tiltL + tiltR)/2;
  T_total = thrustL + thrustR;
  F_thrust_x = T_total*sin(alpha);
  F_thrust_z = T_total*cos(alpha);

  F_drag_x = -cDrag*vx_f*abs(vx_f);
  F_drag_z = -cDrag*vz_f*abs(vz_f);
  F_gust_x = if time >= gustStart and time <= gustEnd then -gustForce else zeroForce;

  F_ext_x = F_thrust_x + F_drag_x + F_gust_x;
  F_ext_z = F_thrust_z + F_drag_z - m_fuselage*g;

  T_c = m_payload*(L_cable*omega_c*omega_c + g*cos(theta_c) + (F_ext_z*cos(theta_c) - F_ext_x*sin(theta_c))/m_fuselage)/(1 + m_payload/m_fuselage);
  ax_f = (F_ext_x + T_c*sin(theta_c))/m_fuselage;
  az_f = (F_ext_z - T_c*cos(theta_c))/m_fuselage;

  x_payload = x_f + L_cable*sin(theta_c);
  z_payload = z_f - L_cable*cos(theta_c);

  der(thrustL) = (thrustCmdL - thrustL)/tau_thrust;
  der(thrustR) = (thrustCmdR - thrustR)/tau_thrust;
  der(tiltL) = (tiltCmdL - tiltL)/tau_tilt;
  der(tiltR) = (tiltCmdR - tiltR)/tau_tilt;

  trackingError = sqrt((x_f - x_des)^2 + (z_f - z_des)^2);
  primaryTrackingError = trackingError;

  thrustBounded = thrustCmdL >= zeroForce and thrustCmdL <= thrustBoundPerRotor and
                  thrustCmdR >= zeroForce and thrustCmdR <= thrustBoundPerRotor and
                  thrustL >= zeroForce and thrustL <= thrustBoundPerRotor and
                  thrustR >= zeroForce and thrustR <= thrustBoundPerRotor;
  tensionBounded = T_c >= zeroForce and T_c <= tensionBound;
  tiltBounded = tiltCmdL >= tiltMin and tiltCmdL <= tiltMax and
                tiltCmdR >= tiltMin and tiltCmdR <= tiltMax and
                tiltL >= tiltMin and tiltL <= tiltMax and
                tiltR >= tiltMin and tiltR <= tiltMax;
  swingBounded = abs(theta_c) <= swingLimit;
  noGroundStrike = z_payload > 0.0 and z_f > 0.0;
  trackingOk = time < trackingTime or trackingError <= trackingLimit;
  targetPlacement = abs(x_payload - xTarget) <= targetRadius and z_payload <= targetRadius and z_payload >= 0.0;

  finiteOk = abs(x_f)<=1e9 and abs(z_f)<=1e9 and abs(vx_f)<=1e9 and abs(vz_f)<=1e9 and
             abs(theta_c)<=1e9 and abs(omega_c)<=1e9 and abs(x_payload)<=1e9 and abs(z_payload)<=1e9 and
             abs(T_c)<=1e9 and abs(ax_f)<=1e9 and abs(az_f)<=1e9 and
             abs(F_ext_x)<=1e9 and abs(F_ext_z)<=1e9 and abs(F_thrust_x)<=1e9 and abs(F_thrust_z)<=1e9 and
             abs(F_drag_x)<=1e9 and abs(F_drag_z)<=1e9 and abs(F_gust_x)<=1e9 and
             abs(thrustL)<=1e9 and abs(thrustR)<=1e9 and abs(tiltL)<=1e9 and abs(tiltR)<=1e9 and
             abs(thrustCmdL)<=1e9 and abs(thrustCmdR)<=1e9 and abs(tiltCmdL)<=1e9 and abs(tiltCmdR)<=1e9 and
             abs(ax_cmd)<=1e9 and abs(az_cmd)<=1e9 and abs(alpha_cmd)<=1e9 and
             abs(T_total_req)<=1e9 and abs(T_per_req)<=1e9 and abs(ix)<=1e9 and abs(iz)<=1e9 and
             abs(sensor_x)<=1e9 and abs(sensor_z)<=1e9 and abs(sensor_vx)<=1e9 and abs(sensor_vz)<=1e9 and
             abs(sensor_ax)<=1e9 and abs(sensor_az)<=1e9 and abs(sensor_theta)<=1e9 and abs(sensor_omega)<=1e9 and
             abs(sensor_T)<=1e9 and abs(trace_x)<=1e9 and abs(trace_z)<=1e9 and abs(trace_theta)<=1e9 and
             abs(trace_T)<=1e9 and abs(trace_thrustCmdL)<=1e9 and abs(trace_thrustCmdR)<=1e9 and
             abs(trace_tiltCmdL)<=1e9 and abs(trace_tiltCmdR)<=1e9 and abs(trace_sensor_x)<=1e9 and
             abs(trace_sensor_z)<=1e9 and abs(trace_sensor_theta)<=1e9 and abs(trace_sensor_T)<=1e9;

  runtimeOk = thrustBounded and tensionBounded and tiltBounded and swingBounded and noGroundStrike and trackingOk and finiteOk;
  accepted = not fault and time >= acceptanceTime and targetPlacement;

algorithm
  when not runtimeOk then
    fault := true;
  end when;

  when sample(0, Ts) then
    sensor_x := x_f;
    sensor_z := z_f;
    sensor_vx := vx_f;
    sensor_vz := vz_f;
    sensor_ax := ax_f;
    sensor_az := az_f;
    sensor_theta := theta_c;
    sensor_omega := omega_c;
    sensor_T := T_c;

    ex := x_des - sensor_x;
    evx := vx_des - sensor_vx;
    ez := z_des - sensor_z;
    evz := vz_des - sensor_vz;

    ax_cmd := ax_des + Kp_x*ex + Kd_x*evx + Ki_x*pre(ix) + K_swing*sensor_theta + K_swing_d*sensor_omega;
    az_cmd := az_des + Kp_z*ez + Kd_z*evz + Ki_z*pre(iz);

    F_drag_ff_x := cDrag*sensor_vx*abs(sensor_vx);
    F_drag_ff_z := cDrag*sensor_vz*abs(sensor_vz);

    Fx_req := m_total*ax_cmd + F_drag_ff_x;
    Fz_req := m_total*(g + az_cmd) + F_drag_ff_z;
    Fz_req_safe := if Fz_req < Fz_min then Fz_min else Fz_req;

    alpha_cmd := atan2(Fx_req, Fz_req_safe);
    T_total_req := sqrt(Fx_req*Fx_req + Fz_req*Fz_req);
    T_per_req := T_total_req/2.0;

    thrustCmdL := if T_per_req < zeroForce then zeroForce elseif T_per_req > thrustBoundPerRotor then thrustBoundPerRotor else T_per_req;
    thrustCmdR := thrustCmdL;
    tiltCmdL := if alpha_cmd < zeroAngle then zeroAngle elseif alpha_cmd > tiltMax then tiltMax else alpha_cmd;
    tiltCmdR := tiltCmdL;

    saturated := (T_per_req > thrustBoundPerRotor) or (T_per_req < zeroForce) or (alpha_cmd < zeroAngle) or (alpha_cmd > tiltMax);

    if saturated then
      ix := pre(ix);
      iz := pre(iz);
    else
      ix := pre(ix) + Ts*ex;
      iz := pre(iz) + Ts*ez;
    end if;

    trace_time := time;
    trace_x := x_f;
    trace_z := z_f;
    trace_vx := vx_f;
    trace_vz := vz_f;
    trace_theta := theta_c;
    trace_omega := omega_c;
    trace_T := T_c;
    trace_thrustCmdL := thrustCmdL;
    trace_thrustCmdR := thrustCmdR;
    trace_tiltCmdL := tiltCmdL;
    trace_tiltCmdR := tiltCmdR;
    trace_sensor_x := sensor_x;
    trace_sensor_z := sensor_z;
    trace_sensor_theta := sensor_theta;
    trace_sensor_T := sensor_T;
  end when;

  annotation(experiment(StartTime=0, StopTime=16, Tolerance=1e-6));
end TiltWingDeliverE;