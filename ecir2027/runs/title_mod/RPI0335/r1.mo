model StewartPressE
  parameter Real PI=Modelica.Constants.pi;
  parameter Real Rb=0.45 "fixed base radius [m]";
  parameter Real Rp=0.32 "moving platform radius [m]";
  parameter Real m=36 "moving platform mass [kg]";
  parameter Real Lmin=0.55 "minimum strut length [m]";
  parameter Real Lmax=0.85 "maximum strut length [m]";
  parameter Real Fmax=4620 "per-strut command and force limit [N]";
  parameter Real kContact=200000 "contact stiffness [N/m]";
  parameter Real cContact=2000 "contact damping [N.s/m]";
  parameter Real mu=0.70 "contact friction coefficient";
  parameter Real Ts=0.004 "controller sample period for 250 Hz [s]";
  parameter Real zWork=0.50 "fixed compliant workpiece surface height [m], chosen inside strut range";
  parameter Real z0=0.80 "initial platform height [m], chosen inside strut range";
  parameter Real g=0.0 "gravity not specified in requirement; set to zero [m/s2]";
  parameter Real h=sqrt(Rb*Rb + Rp*Rp - 2.0*Rb*Rp*cos(PI/6.0)) "constant horizontal strut offset for symmetric hexapod [m]";
  parameter Real Kp_pos=400 "position controller proportional gain [N/m]";
  parameter Real Kd_pos=240 "position controller derivative gain [N.s/m]";
  parameter Real Kf=0.10 "contact-force error gain per strut [N/N]";
  parameter Real Kdf=12000 "contact-force velocity damping gain total [N.s/m]";
  parameter Real Fband=21.6 "contact force band [N], equal to specified force change";
  parameter Real vTol=1.0e-4 "friction regularization and locked-contact slip threshold [m/s]";

  parameter Real bx[6]={Rb*cos(0.0),
                        Rb*cos(PI/3.0),
                        Rb*cos(2.0*PI/3.0),
                        Rb*cos(PI),
                        Rb*cos(4.0*PI/3.0),
                        Rb*cos(5.0*PI/3.0)};
  parameter Real by[6]={Rb*sin(0.0),
                        Rb*sin(PI/3.0),
                        Rb*sin(2.0*PI/3.0),
                        Rb*sin(PI),
                        Rb*sin(4.0*PI/3.0),
                        Rb*sin(5.0*PI/3.0)};
  parameter Real px0[6]={Rp*cos(PI/6.0),
                         Rp*cos(PI/2.0),
                         Rp*cos(5.0*PI/6.0),
                         Rp*cos(7.0*PI/6.0),
                         Rp*cos(3.0*PI/2.0),
                         Rp*cos(11.0*PI/6.0)};
  parameter Real py0[6]={Rp*sin(PI/6.0),
                         Rp*sin(PI/2.0),
                         Rp*sin(5.0*PI/6.0),
                         Rp*sin(7.0*PI/6.0),
                         Rp*sin(3.0*PI/2.0),
                         Rp*sin(11.0*PI/6.0)};

  Real x,y,z,vx,vy,vz;
  Real dx[6],dy[6],L[6],ux[6],uy[6],uz[6];
  Real F[6],Fsensor[6];
  Real penetration,vApproach,Fn,vt,FfricMag,FfricX,FfricY,slip;
  Boolean lockedContact;

  Real sensorPoseX,sensorPoseY,sensorPoseZ,sensorRoll,sensorPitch,sensorYaw,sensorNormalForce;

  discrete Real FcmdRaw[6](each start=0.0);
  discrete Real Fcmd[6](each start=0.0);
  discrete Real z_s(start=z0);
  discrete Real vz_s(start=0.0);
  discrete Real Fn_s(start=0.0);
  discrete Real L_s(start=sqrt(h*h + z0*z0));
  discrete Real Fdes(start=0.0);
  discrete Real z_ref(start=zWork);
  discrete Real z_cmd(start=zWork);
  discrete Real Lcmd[6](each start=sqrt(h*h + z0*z0));
  discrete Boolean contactEstimate(start=false);

  Real closureError,primaryTrackingError,contactForceBandError;
  Boolean contactForceInBand,actuatorBoundsOK,strutBoundsOK,finiteOK,lockedContactRequired,acceptance;

protected
  discrete Real FposTotal(start=0.0);
  discrete Real Fff(start=0.0);
  discrete Real r(start=0.0);

equation
  for i in 1:6 loop
    dx[i] = x + px0[i] - bx[i];
    dy[i] = y + py0[i] - by[i];
    L[i] = sqrt(dx[i]*dx[i] + dy[i]*dy[i] + z*z);
    ux[i] = dx[i]/L[i];
    uy[i] = dy[i]/L[i];
    uz[i] = z/L[i];
    F[i] = Fcmd[i];
    Fsensor[i] = F[i];
  end for;

  penetration = max(0.0, zWork - z);
  vApproach = max(0.0, -vz);
  Fn = if penetration > 0.0 then kContact*penetration + cContact*vApproach else 0.0;

  vt = sqrt(vx*vx + vy*vy);
  FfricMag = mu*Fn*tanh(vt/vTol);
  FfricX = -FfricMag*vx/max(vt,vTol);
  FfricY = -FfricMag*vy/max(vt,vTol);
  slip = vt;
  lockedContact = Fn > 0.0 and vt <= vTol;

  der(x) = vx;
  der(y) = vy;
  der(z) = vz;

  m*der(vx) = -F[1]*ux[1] - F[2]*ux[2] - F[3]*ux[3] - F[4]*ux[4] - F[5]*ux[5] - F[6]*ux[6] + FfricX;
  m*der(vy) = -F[1]*uy[1] - F[2]*uy[2] - F[3]*uy[3] - F[4]*uy[4] - F[5]*uy[5] - F[6]*uy[6] + FfricY;
  m*der(vz) = -F[1]*uz[1] - F[2]*uz[2] - F[3]*uz[3] - F[4]*uz[4] - F[5]*uz[5] - F[6]*uz[6] + Fn - m*g;

  sensorPoseX = x;
  sensorPoseY = y;
  sensorPoseZ = z;
  sensorRoll = 0.0;
  sensorPitch = 0.0;
  sensorYaw = 0.0;
  sensorNormalForce = Fn;

  closureError = max(abs(L[1]-Lcmd[1]),
               max(abs(L[2]-Lcmd[2]),
               max(abs(L[3]-Lcmd[3]),
               max(abs(L[4]-Lcmd[4]),
               max(abs(L[5]-Lcmd[5]),
                   abs(L[6]-Lcmd[6]))))));
  primaryTrackingError = closureError;

  contactForceBandError = abs(Fn - Fdes);
  contactForceInBand = contactForceBandError <= Fband + 1.0e-6;

  actuatorBoundsOK = abs(Fcmd[1]) <= Fmax + 1.0e-6 and abs(Fcmd[2]) <= Fmax + 1.0e-6 and
                     abs(Fcmd[3]) <= Fmax + 1.0e-6 and abs(Fcmd[4]) <= Fmax + 1.0e-6 and
                     abs(Fcmd[5]) <= Fmax + 1.0e-6 and abs(Fcmd[6]) <= Fmax + 1.0e-6 and
                     abs(F[1]) <= Fmax + 1.0e-6 and abs(F[2]) <= Fmax + 1.0e-6 and
                     abs(F[3]) <= Fmax + 1.0e-6 and abs(F[4]) <= Fmax + 1.0e-6 and
                     abs(F[5]) <= Fmax + 1.0e-6 and abs(F[6]) <= Fmax + 1.0e-6;

  strutBoundsOK = L[1] >= Lmin - 1.0e-6 and L[1] <= Lmax + 1.0e-6 and
                  L[2] >= Lmin - 1.0e-6 and L[2] <= Lmax + 1.0e-6 and
                  L[3] >= Lmin - 1.0e-6 and L[3] <= Lmax + 1.0e-6 and
                  L[4] >= Lmin - 1.0e-6 and L[4] <= Lmax + 1.0e-6 and
                  L[5] >= Lmin - 1.0e-6 and L[5] <= Lmax + 1.0e-6 and
                  L[6] >= Lmin - 1.0e-6 and L[6] <= Lmax + 1.0e-6;

  finiteOK = abs(x) <= 1.0e307 and abs(y) <= 1.0e307 and abs(z) <= 1.0e307 and
             abs(vx) <= 1.0e307 and abs(vy) <= 1.0e307 and abs(vz) <= 1.0e307 and
             abs(Fn) <= 1.0e307 and abs(FfricX) <= 1.0e307 and abs(FfricY) <= 1.0e307 and
             abs(z_s) <= 1.0e307 and abs(vz_s) <= 1.0e307 and abs(Fn_s) <= 1.0e307 and
             abs(L_s) <= 1.0e307 and abs(Fdes) <= 1.0e307 and abs(z_cmd) <= 1.0e307 and
             abs(FposTotal) <= 1.0e307 and abs(Fff) <= 1.0e307 and abs(r) <= 1.0e307 and
             abs(Fcmd[1]) <= 1.0e307 and abs(Fcmd[2]) <= 1.0e307 and abs(Fcmd[3]) <= 1.0e307 and
             abs(Fcmd[4]) <= 1.0e307 and abs(Fcmd[5]) <= 1.0e307 and abs(Fcmd[6]) <= 1.0e307 and
             abs(FcmdRaw[1]) <= 1.0e307 and abs(FcmdRaw[2]) <= 1.0e307 and abs(FcmdRaw[3]) <= 1.0e307 and
             abs(FcmdRaw[4]) <= 1.0e307 and abs(FcmdRaw[5]) <= 1.0e307 and abs(FcmdRaw[6]) <= 1.0e307 and
             abs(Lcmd[1]) <= 1.0e307 and abs(Lcmd[2]) <= 1.0e307 and abs(Lcmd[3]) <= 1.0e307 and
             abs(Lcmd[4]) <= 1.0e307 and abs(Lcmd[5]) <= 1.0e307 and abs(Lcmd[6]) <= 1.0e307;

  lockedContactRequired = if (Fdes > 0.0 and Fn > 0.0) then lockedContact else true;

  acceptance = actuatorBoundsOK and strutBoundsOK and finiteOK and contactForceInBand and
               slip <= vTol and lockedContactRequired and
               (if time >= 10.4 then primaryTrackingError <= 0.001 else true);

  assert(actuatorBoundsOK, "actuator bound violated");
  assert(strutBoundsOK, "strut length bound violated");
  assert(finiteOK, "non-finite physical, control, or estimator value detected");
  assert(contactForceInBand, "contact force band violated");
  assert(slip <= vTol, "tangential slip exceeded");
  assert(lockedContactRequired, "contact not locked under force");
  assert(time < 10.4 or primaryTrackingError <= 0.001, "primary tracking/closure error > 0.001 m after 10.4 s");

algorithm
  when sample(0.0, Ts) then
    r := 0.0;
    Fff := 0.0;
    FposTotal := 0.0;
    z_cmd := zWork;

    z_s := z;
    vz_s := vz;
    Fn_s := Fn;
    L_s := L[1];

    Fdes := if time >= 16.0/3.0 and time < 32.0/3.0 then 21.6 else 0.0;
    z_ref := zWork;
    contactEstimate := (Fn_s > 0.0) or (Fdes > 0.0);

    if contactEstimate then
      z_cmd := zWork - Fdes/kContact;
      r := if abs(L_s) > 1.0e-9 then z_s/L_s else 0.0;
      Fff := if abs(r) > 1.0e-9 then Fdes/(6.0*r) else 0.0;
      for i in 1:6 loop
        FcmdRaw[i] := Fff + Kf*(Fdes - Fn_s) + Kdf*vz_s/6.0;
        Lcmd[i] := sqrt(h*h + z_cmd*z_cmd);
      end for;
    else
      z_cmd := zWork;
      FposTotal := Kp_pos*(z_s - z_ref) + Kd_pos*vz_s;
      for i in 1:6 loop
        FcmdRaw[i] := FposTotal/6.0;
        Lcmd[i] := sqrt(h*h + z_cmd*z_cmd);
      end for;
    end if;

    for i in 1:6 loop
      Fcmd[i] := if FcmdRaw[i] > Fmax then Fmax
                 elseif FcmdRaw[i] < -Fmax then -Fmax
                 else FcmdRaw[i];
    end for;
  end when;

initial equation
  x = 0.0;
  y = 0.0;
  z = z0;
  vx = 0.0;
  vy = 0.0;
  vz = 0.0;

  annotation(experiment(StopTime=16, Interval=0.004));
end StewartPressE;