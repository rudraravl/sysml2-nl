model AirTrioResilientC
  /* Finite placeholders are used for design facts not stated in the requirement:
     formation geometry, route endpoint, disturbance magnitude, dropout start inside
     the middle third, and control gains. Stated values are mass, rotor limit,
     dropout duration, 125 Hz, 12 s, and 7.8 s verification time. */

  parameter Real Ts=0.008 "controller sample interval, 125 Hz (s)";
  parameter Real m=1.8 "quadrotor mass (kg)";
  parameter Real g=9.81 "gravity (m/s2)";
  parameter Real Tmax=11.0 "maximum rotor-thrust command magnitude (N)";

  parameter Real routeTime=12.0 "completed-route duration (s)";
  parameter Real xStart=1.0 "finite placeholder route center start x (m)";
  parameter Real yStart=0.5773502691896257 "finite placeholder route center start y (m)";
  parameter Real zStart=2.0 "finite placeholder route height (m)";
  parameter Real xEnd=10.0 "finite placeholder route center end x (m)";
  parameter Real routeSpeed=(xEnd-xStart)/routeTime "route speed (m/s)";

  parameter Real tDropStart=5.55 "dropout start inside middle third 4..8 s (s)";
  parameter Real tDropDur=0.9 "communication dropout duration (s)";
  parameter Real distForce=3.0 "finite placeholder shared disturbance while comm unavailable (N)";

  parameter Real formationSide=2.0 "finite placeholder formation side (m)";
  parameter Real sqrt3=1.7320508075688772;
  parameter Real off1x=-formationSide/2.0;
  parameter Real off1y=-sqrt3*formationSide/6.0;
  parameter Real off2x=formationSide/2.0;
  parameter Real off2y=-sqrt3*formationSide/6.0;
  parameter Real off3x=0.0;
  parameter Real off3y=sqrt3*formationSide/3.0;

  parameter Real Kp_pos=20.0 "finite placeholder horizontal position gain (1/s2)";
  parameter Real Kd_pos=10.0 "finite placeholder horizontal velocity gain (1/s)";
  parameter Real Kp_z=20.0 "finite placeholder vertical position gain (1/s2)";
  parameter Real Kd_z=10.0 "finite placeholder vertical velocity gain (1/s)";
  parameter Real Kf=10.0 "finite placeholder formation position gain (1/s2)";
  parameter Real Kdf=4.0 "finite placeholder formation velocity gain (1/s)";
  parameter Real Kcoll=25.0 "finite placeholder collision gain (1/s2)";
  parameter Real dColl=1.5 "collision avoidance clearance (m)";
  parameter Real eps=1e-9 "zero-error branch for distance divisors (m)";
  parameter Real tCheck=7.8 "primary tracking verification time (s)";

  Real px1,py1,pz1,vx1,vy1,vz1;
  Real px2,py2,pz2,vx2,vy2,vz2;
  Real px3,py3,pz3,vx3,vy3,vz3;

  Real Fx1,Fy1,Fz1,Fx2,Fy2,Fz2,Fx3,Fy3,Fz3;
  Real distX,distY,distZ;
  Boolean dropoutActive,commOK;

  Real T0_1,dTx1,dTy1,T11,T12,T13,T14;
  Real T0_2,dTx2,dTy2,T21,T22,T23,T24;
  Real T0_3,dTx3,dTy3,T31,T32,T33,T34;

  Real fx_cmd1,fy_cmd1,fz_cmd1;
  Real fx_cmd2,fy_cmd2,fz_cmd2;
  Real fx_cmd3,fy_cmd3,fz_cmd3;

  Real form1x,form1y,form1z,form2x,form2y,form2z,form3x,form3y,form3z;
  Real coll1x,coll1y,coll1z,coll2x,coll2y,coll2z,coll3x,coll3y,coll3z;

  Real routeProgress,routeCompleted,centerXref,centerYref,centerZref,centerVxref;
  Real xRef1,yRef1,zRef1,vRefX1,vRefY1,vRefZ1;
  Real xRef2,yRef2,zRef2,vRefX2,vRefY2,vRefZ2;
  Real xRef3,yRef3,zRef3,vRefX3,vRefY3,vRefZ3;

  Real gpsX1,gpsY1,gpsZ1,imuVx1,imuVy1,imuVz1,imuAx1,imuAy1,imuAz1;
  Real gpsX2,gpsY2,gpsZ2,imuVx2,imuVy2,imuVz2,imuAx2,imuAy2,imuAz2;
  Real gpsX3,gpsY3,gpsZ3,imuVx3,imuVy3,imuVz3,imuAx3,imuAy3,imuAz3;

  Real estX1,estY1,estZ1,estVx1,estVy1,estVz1,estAx1,estAy1,estAz1;
  Real estX2,estY2,estZ2,estVx2,estVy2,estVz2,estAx2,estAy2,estAz2;
  Real estX3,estY3,estZ3,estVx3,estVy3,estVz3,estAx3,estAy3,estAz3;

  Real dx12,dy12,dz12,range12,rep12x,rep12y,rep12z;
  Real dx13,dy13,dz13,range13,rep13x,rep13y,rep13z;
  Real dx23,dy23,dz23,range23,rep23x,rep23y,rep23z;

  discrete Real p2x_r1,p2y_r1,p2z_r1,p2vx_r1,p2vy_r1,p2vz_r1,ts2_r1;
  discrete Real p3x_r1,p3y_r1,p3z_r1,p3vx_r1,p3vy_r1,p3vz_r1,ts3_r1;
  discrete Real p1x_r2,p1y_r2,p1z_r2,p1vx_r2,p1vy_r2,p1vz_r2,ts1_r2;
  discrete Real p3x_r2,p3y_r2,p3z_r2,p3vx_r2,p3vy_r2,p3vz_r2,ts3_r2;
  discrete Real p1x_r3,p1y_r3,p1z_r3,p1vx_r3,p1vy_r3,p1vz_r3,ts1_r3;
  discrete Real p2x_r3,p2y_r3,p2z_r3,p2vx_r3,p2vy_r3,p2vz_r3,ts2_r3;

  Real p2est_x_r1,p2est_y_r1,p2est_z_r1,p2est_vx_r1,p2est_vy_r1,p2est_vz_r1;
  Real p3est_x_r1,p3est_y_r1,p3est_z_r1,p3est_vx_r1,p3est_vy_r1,p3est_vz_r1;
  Real p1est_x_r2,p1est_y_r2,p1est_z_r2,p1est_vx_r2,p1est_vy_r2,p1est_vz_r2;
  Real p3est_x_r2,p3est_y_r2,p3est_z_r2,p3est_vx_r2,p3est_vy_r2,p3est_vz_r2;
  Real p1est_x_r3,p1est_y_r3,p1est_z_r3,p1est_vx_r3,p1est_vy_r3,p1est_vz_r3;
  Real p2est_x_r3,p2est_y_r3,p2est_z_r3,p2est_vx_r3,p2est_vy_r3,p2est_vz_r3;

  Real err12,err13,err23,formationError,degradedFormationError,recoveredFormationError;
  Real primaryTrackingError,primaryTrackingErrorAfter7p8,minClearance;
  Boolean collisionFree;

initial equation
  px1 = xStart + off1x;
  py1 = yStart + off1y;
  pz1 = zStart;
  vx1 = 0.0;
  vy1 = 0.0;
  vz1 = 0.0;

  px2 = xStart + off2x;
  py2 = yStart + off2y;
  pz2 = zStart;
  vx2 = 0.0;
  vy2 = 0.0;
  vz2 = 0.0;

  px3 = xStart + off3x;
  py3 = yStart + off3y;
  pz3 = zStart;
  vx3 = 0.0;
  vy3 = 0.0;
  vz3 = 0.0;

  p2x_r1 = xStart + off2x;
  p2y_r1 = yStart + off2y;
  p2z_r1 = zStart;
  p2vx_r1 = 0.0;
  p2vy_r1 = 0.0;
  p2vz_r1 = 0.0;
  ts2_r1 = 0.0;

  p3x_r1 = xStart + off3x;
  p3y_r1 = yStart + off3y;
  p3z_r1 = zStart;
  p3vx_r1 = 0.0;
  p3vy_r1 = 0.0;
  p3vz_r1 = 0.0;
  ts3_r1 = 0.0;

  p1x_r2 = xStart + off1x;
  p1y_r2 = yStart + off1y;
  p1z_r2 = zStart;
  p1vx_r2 = 0.0;
  p1vy_r2 = 0.0;
  p1vz_r2 = 0.0;
  ts1_r2 = 0.0;

  p3x_r2 = xStart + off3x;
  p3y_r2 = yStart + off3y;
  p3z_r2 = zStart;
  p3vx_r2 = 0.0;
  p3vy_r2 = 0.0;
  p3vz_r2 = 0.0;
  ts3_r2 = 0.0;

  p1x_r3 = xStart + off1x;
  p1y_r3 = yStart + off1y;
  p1z_r3 = zStart;
  p1vx_r3 = 0.0;
  p1vy_r3 = 0.0;
  p1vz_r3 = 0.0;
  ts1_r3 = 0.0;

  p2x_r3 = xStart + off2x;
  p2y_r3 = yStart + off2y;
  p2z_r3 = zStart;
  p2vx_r3 = 0.0;
  p2vy_r3 = 0.0;
  p2vz_r3 = 0.0;
  ts2_r3 = 0.0;

equation
  dropoutActive = time >= tDropStart and time < tDropStart + tDropDur;
  commOK = not dropoutActive;
  distX = if dropoutActive then distForce else 0.0;
  distY = 0.0;
  distZ = 0.0;

  der(px1) = vx1;
  der(py1) = vy1;
  der(pz1) = vz1;
  der(vx1) = (Fx1 + distX)/m;
  der(vy1) = (Fy1 + distY)/m;
  der(vz1) = (Fz1 - m*g + distZ)/m;

  der(px2) = vx2;
  der(py2) = vy2;
  der(pz2) = vz2;
  der(vx2) = (Fx2 + distX)/m;
  der(vy2) = (Fy2 + distY)/m;
  der(vz2) = (Fz2 - m*g + distZ)/m;

  der(px3) = vx3;
  der(py3) = vy3;
  der(pz3) = vz3;
  der(vx3) = (Fx3 + distX)/m;
  der(vy3) = (Fy3 + distY)/m;
  der(vz3) = (Fz3 - m*g + distZ)/m;

  Fx1 = T11 - T12 + T13 - T14;
  Fy1 = T11 + T12 - T13 - T14;
  Fz1 = T11 + T12 + T13 + T14;

  Fx2 = T21 - T22 + T23 - T24;
  Fy2 = T21 + T22 - T23 - T24;
  Fz2 = T21 + T22 + T23 + T24;

  Fx3 = T31 - T32 + T33 - T34;
  Fy3 = T31 + T32 - T33 - T34;
  Fz3 = T31 + T32 + T33 + T34;

  gpsX1 = px1;
  gpsY1 = py1;
  gpsZ1 = pz1;
  imuVx1 = vx1;
  imuVy1 = vy1;
  imuVz1 = vz1;
  imuAx1 = (Fx1 + distX)/m;
  imuAy1 = (Fy1 + distY)/m;
  imuAz1 = (Fz1 - m*g + distZ)/m;

  gpsX2 = px2;
  gpsY2 = py2;
  gpsZ2 = pz2;
  imuVx2 = vx2;
  imuVy2 = vy2;
  imuVz2 = vz2;
  imuAx2 = (Fx2 + distX)/m;
  imuAy2 = (Fy2 + distY)/m;
  imuAz2 = (Fz2 - m*g + distZ)/m;

  gpsX3 = px3;
  gpsY3 = py3;
  gpsZ3 = pz3;
  imuVx3 = vx3;
  imuVy3 = vy3;
  imuVz3 = vz3;
  imuAx3 = (Fx3 + distX)/m;
  imuAy3 = (Fy3 + distY)/m;
  imuAz3 = (Fz3 - m*g + distZ)/m;

  estX1 = gpsX1;
  estY1 = gpsY1;
  estZ1 = gpsZ1;
  estVx1 = imuVx1;
  estVy1 = imuVy1;
  estVz1 = imuVz1;
  estAx1 = imuAx1;
  estAy1 = imuAy1;
  estAz1 = imuAz1;

  estX2 = gpsX2;
  estY2 = gpsY2;
  estZ2 = gpsZ2;
  estVx2 = imuVx2;
  estVy2 = imuVy2;
  estVz2 = imuVz2;
  estAx2 = imuAx2;
  estAy2 = imuAy2;
  estAz2 = imuAz2;

  estX3 = gpsX3;
  estY3 = gpsY3;
  estZ3 = gpsZ3;
  estVx3 = imuVx3;
  estVy3 = imuVy3;
  estVz3 = imuVz3;
  estAx3 = imuAx3;
  estAy3 = imuAy3;
  estAz3 = imuAz3;

  dx12 = px1 - px2;
  dy12 = py1 - py2;
  dz12 = pz1 - pz2;
  range12 = sqrt(max(eps, dx12*dx12 + dy12*dy12 + dz12*dz12));
  rep12x = if range12 < dColl then Kcoll*(dColl - range12)*dx12/max(range12,eps) else 0.0;
  rep12y = if range12 < dColl then Kcoll*(dColl - range12)*dy12/max(range12,eps) else 0.0;
  rep12z = if range12 < dColl then Kcoll*(dColl - range12)*dz12/max(range12,eps) else 0.0;

  dx13 = px1 - px3;
  dy13 = py1 - py3;
  dz13 = pz1 - pz3;
  range13 = sqrt(max(eps, dx13*dx13 + dy13*dy13 + dz13*dz13));
  rep13x = if range13 < dColl then Kcoll*(dColl - range13)*dx13/max(range13,eps) else 0.0;
  rep13y = if range13 < dColl then Kcoll*(dColl - range13)*dy13/max(range13,eps) else 0.0;
  rep13z = if range13 < dColl then Kcoll*(dColl - range13)*dz13/max(range13,eps) else 0.0;

  dx23 = px2 - px3;
  dy23 = py2 - py3;
  dz23 = pz2 - pz3;
  range23 = sqrt(max(eps, dx23*dx23 + dy23*dy23 + dz23*dz23));
  rep23x = if range23 < dColl then Kcoll*(dColl - range23)*dx23/max(range23,eps) else 0.0;
  rep23y = if range23 < dColl then Kcoll*(dColl - range23)*dy23/max(range23,eps) else 0.0;
  rep23z = if range23 < dColl then Kcoll*(dColl - range23)*dz23/max(range23,eps) else 0.0;

  coll1x = rep12x + rep13x;
  coll1y = rep12y + rep13y;
  coll1z = rep12z + rep13z;
  coll2x = -rep12x + rep23x;
  coll2y = -rep12y + rep23y;
  coll2z = -rep12z + rep23z;
  coll3x = -rep13x - rep23x;
  coll3y = -rep13y - rep23y;
  coll3z = -rep13z - rep23z;

  routeProgress = if time >= routeTime then 1.0 else time/routeTime;
  routeCompleted = if time >= routeTime then 1.0 else routeProgress;
  centerXref = xStart + (xEnd - xStart)*routeProgress;
  centerYref = yStart;
  centerZref = zStart;
  centerVxref = if time >= routeTime then 0.0 else routeSpeed;

  xRef1 = centerXref + off1x;
  yRef1 = centerYref + off1y;
  zRef1 = centerZref;
  vRefX1 = centerVxref;
  vRefY1 = 0.0;
  vRefZ1 = 0.0;

  xRef2 = centerXref + off2x;
  yRef2 = centerYref + off2y;
  zRef2 = centerZref;
  vRefX2 = centerVxref;
  vRefY2 = 0.0;
  vRefZ2 = 0.0;

  xRef3 = centerXref + off3x;
  yRef3 = centerYref + off3y;
  zRef3 = centerZref;
  vRefX3 = centerVxref;
  vRefY3 = 0.0;
  vRefZ3 = 0.0;

  p2est_x_r1 = p2x_r1 + p2vx_r1*(time - ts2_r1);
  p2est_y_r1 = p2y_r1 + p2vy_r1*(time - ts2_r1);
  p2est_z_r1 = p2z_r1 + p2vz_r1*(time - ts2_r1);
  p2est_vx_r1 = p2vx_r1;
  p2est_vy_r1 = p2vy_r1;
  p2est_vz_r1 = p2vz_r1;

  p3est_x_r1 = p3x_r1 + p3vx_r1*(time - ts3_r1);
  p3est_y_r1 = p3y_r1 + p3vy_r1*(time - ts3_r1);
  p3est_z_r1 = p3z_r1 + p3vz_r1*(time - ts3_r1);
  p3est_vx_r1 = p3vx_r1;
  p3est_vy_r1 = p3vy_r1;
  p3est_vz_r1 = p3vz_r1;

  p1est_x_r2 = p1x_r2 + p1vx_r2*(time - ts1_r2);
  p1est_y_r2 = p1y_r2 + p1vy_r2*(time - ts1_r2);
  p1est_z_r2 = p1z_r2 + p1vz_r2*(time - ts1_r2);
  p1est_vx_r2 = p1vx_r2;
  p1est_vy_r2 = p1vy_r2;
  p1est_vz_r2 = p1vz_r2;

  p3est_x_r2 = p3x_r2 + p3vx_r2*(time - ts3_r2);
  p3est_y_r2 = p3y_r2 + p3vy_r2*(time - ts3_r2);
  p3est_z_r2 = p3z_r2 + p3vz_r2*(time - ts3_r2);
  p3est_vx_r2 = p3vx_r2;
  p3est_vy_r2 = p3vy_r2;
  p3est_vz_r2 = p3vz_r2;

  p1est_x_r3 = p1x_r3 + p1vx_r3*(time - ts1_r3);
  p1est_y_r3 = p1y_r3 + p1vy_r3*(time - ts1_r3);
  p1est_z_r3 = p1z_r3 + p1vz_r3*(time - ts1_r3);
  p1est_vx_r3 = p1vx_r3;
  p1est_vy_r3 = p1vy_r3;
  p1est_vz_r3 = p1vz_r3;

  p2est_x_r3 = p2x_r3 + p2vx_r3*(time - ts2_r3);
  p2est_y_r3 = p2y_r3 + p2vy_r3*(time - ts2_r3);
  p2est_z_r3 = p2z_r3 + p2vz_r3*(time - ts2_r3);
  p2est_vx_r3 = p2vx_r3;
  p2est_vy_r3 = p2vy_r3;
  p2est_vz_r3 = p2vz_r3;

  form1x = Kf*((p2est_x_r1 - px1) - formationSide) + Kdf*(p2est_vx_r1 - vx1)
         + Kf*((p3est_x_r1 - px1) - formationSide/2.0) + Kdf*(p3est_vx_r1 - vx1);
  form1y = Kf*((p2est_y_r1 - py1) - 0.0) + Kdf*(p2est_vy_r1 - vy1)
         + Kf*((p3est_y_r1 - py1) - sqrt3*formationSide/2.0) + Kdf*(p3est_vy_r1 - vy1);
  form1z = Kf*((p2est_z_r1 - pz1) - 0.0) + Kdf*(p2est_vz_r1 - vz1)
         + Kf*((p3est_z_r1 - pz1) - 0.0) + Kdf*(p3est_vz_r1 - vz1);

  form2x = Kf*((p1est_x_r2 - px2) - (-formationSide)) + Kdf*(p1est_vx_r2 - vx2)
         + Kf*((p3est_x_r2 - px2) - (-formationSide/2.0)) + Kdf*(p3est_vx_r2 - vx2);
  form2y = Kf*((p1est_y_r2 - py2) - 0.0) + Kdf*(p1est_vy_r2 - vy2)
         + Kf*((p3est_y_r2 - py2) - sqrt3*formationSide/2.0) + Kdf*(p3est_vy_r2 - vy2);
  form2z = Kf*((p1est_z_r2 - pz2) - 0.0) + Kdf*(p1est_vz_r2 - vz2)
         + Kf*((p3est_z_r2 - pz2) - 0.0) + Kdf*(p3est_vz_r2 - vz2);

  form3x = Kf*((p1est_x_r3 - px3) - (-formationSide/2.0)) + Kdf*(p1est_vx_r3 - vx3)
         + Kf*((p2est_x_r3 - px3) - (formationSide/2.0)) + Kdf*(p2est_vx_r3 - vx3);
  form3y = Kf*((p1est_y_r3 - py3) - (-sqrt3*formationSide/2.0)) + Kdf*(p1est_vy_r3 - vy3)
         + Kf*((p2est_y_r3 - py3) - (-sqrt3*formationSide/2.0)) + Kdf*(p2est_vy_r3 - vy3);
  form3z = Kf*((p1est_z_r3 - pz3) - 0.0) + Kdf*(p1est_vz_r3 - vz3)
         + Kf*((p2est_z_r3 - pz3) - 0.0) + Kdf*(p2est_vz_r3 - vz3);

  fx_cmd1 = m*(Kp_pos*(xRef1 - px1) + Kd_pos*(vRefX1 - vx1) + form1x + coll1x);
  fy_cmd1 = m*(Kp_pos*(yRef1 - py1) + Kd_pos*(vRefY1 - vy1) + form1y + coll1y);
  fz_cmd1 = m*g + m*(Kp_z*(zRef1 - pz1) + Kd_z*(vRefZ1 - vz1) + form1z + coll1z);

  fx_cmd2 = m*(Kp_pos*(xRef2 - px2) + Kd_pos*(vRefX2 - vx2) + form2x + coll2x);
  fy_cmd2 = m*(Kp_pos*(yRef2 - py2) + Kd_pos*(vRefY2 - vy2) + form2y + coll2y);
  fz_cmd2 = m*g + m*(Kp_z*(zRef2 - pz2) + Kd_z*(vRefZ2 - vz2) + form2z + coll2z);

  fx_cmd3 = m*(Kp_pos*(xRef3 - px3) + Kd_pos*(vRefX3 - vx3) + form3x + coll3x);
  fy_cmd3 = m*(Kp_pos*(yRef3 - py3) + Kd_pos*(vRefY3 - vy3) + form3y + coll3y);
  fz_cmd3 = m*g + m*(Kp_z*(zRef3 - pz3) + Kd_z*(vRefZ3 - vz3) + form3z + coll3z);

  T0_1 = max(0.0, fz_cmd1/4.0);
  dTx1 = fx_cmd1/4.0;
  dTy1 = fy_cmd1/4.0;
  T11 = max(0.0, min(Tmax, T0_1 + dTx1 + dTy1));
  T12 = max(0.0, min(Tmax, T0_1 - dTx1 + dTy1));
  T13 = max(0.0, min(Tmax, T0_1 + dTx1 - dTy1));
  T14 = max(0.0, min(Tmax, T0_1 - dTx1 - dTy1));

  T0_2 = max(0.0, fz_cmd2/4.0);
  dTx2 = fx_cmd2/4.0;
  dTy2 = fy_cmd2/4.0;
  T21 = max(0.0, min(Tmax, T0_2 + dTx2 + dTy2));
  T22 = max(0.0, min(Tmax, T0_2 - dTx2 + dTy2));
  T23 = max(0.0, min(Tmax, T0_2 + dTx2 - dTy2));
  T24 = max(0.0, min(Tmax, T0_2 - dTx2 - dTy2));

  T0_3 = max(0.0, fz_cmd3/4.0);
  dTx3 = fx_cmd3/4.0;
  dTy3 = fy_cmd3/4.0;
  T31 = max(0.0, min(Tmax, T0_3 + dTx3 + dTy3));
  T32 = max(0.0, min(Tmax, T0_3 - dTx3 + dTy3));
  T33 = max(0.0, min(Tmax, T0_3 + dTx3 - dTy3));
  T34 = max(0.0, min(Tmax, T0_3 - dTx3 - dTy3));

  err12 = abs(range12 - formationSide);
  err13 = abs(range13 - formationSide);
  err23 = abs(range23 - formationSide);
  formationError = max(err12, max(err13, err23));
  degradedFormationError = if dropoutActive then formationError else 0.0;
  recoveredFormationError = if time >= tCheck then formationError else 0.0;

  primaryTrackingError = sqrt(max(eps, (px1 - xRef1)^2 + (py1 - yRef1)^2 + (pz1 - zRef1)^2));
  primaryTrackingErrorAfter7p8 = if time >= tCheck then primaryTrackingError else 0.0;

  minClearance = min(range12, min(range13, range23));
  collisionFree = minClearance > dColl;

  when sample(0,Ts) then
    p2x_r1 = if commOK then gpsX2 else pre(p2x_r1);
    p2y_r1 = if commOK then gpsY2 else pre(p2y_r1);
    p2z_r1 = if commOK then gpsZ2 else pre(p2z_r1);
    p2vx_r1 = if commOK then imuVx2 else pre(p2vx_r1);
    p2vy_r1 = if commOK then imuVy2 else pre(p2vy_r1);
    p2vz_r1 = if commOK then imuVz2 else pre(p2vz_r1);
    ts2_r1 = if commOK then time else pre(ts2_r1);

    p3x_r1 = if commOK then gpsX3 else pre(p3x_r1);
    p3y_r1 = if commOK then gpsY3 else pre(p3y_r1);
    p3z_r1 = if commOK then gpsZ3 else pre(p3z_r1);
    p3vx_r1 = if commOK then imuVx3 else pre(p3vx_r1);
    p3vy_r1 = if commOK then imuVy3 else pre(p3vy_r1);
    p3vz_r1 = if commOK then imuVz3 else pre(p3vz_r1);
    ts3_r1 = if commOK then time else pre(ts3_r1);

    p1x_r2 = if commOK then gpsX1 else pre(p1x_r2);
    p1y_r2 = if commOK then gpsY1 else pre(p1y_r2);
    p1z_r2 = if commOK then gpsZ1 else pre(p1z_r2);
    p1vx_r2 = if commOK then imuVx1 else pre(p1vx_r2);
    p1vy_r2 = if commOK then imuVy1 else pre(p1vy_r2);
    p1vz_r2 = if commOK then imuVz1 else pre(p1vz_r2);
    ts1_r2 = if commOK then time else pre(ts1_r2);

    p3x_r2 = if commOK then gpsX3 else pre(p3x_r2);
    p3y_r2 = if commOK then gpsY3 else pre(p3y_r2);
    p3z_r2 = if commOK then gpsZ3 else pre(p3z_r2);
    p3vx_r2 = if commOK then imuVx3 else pre(p3vx_r2);
    p3vy_r2 = if commOK then imuVy3 else pre(p3vy_r2);
    p3vz_r2 = if commOK then imuVz3 else pre(p3vz_r2);
    ts3_r2 = if commOK then time else pre(ts3_r2);

    p1x_r3 = if commOK then gpsX1 else pre(p1x_r3);
    p1y_r3 = if commOK then gpsY1 else pre(p1y_r3);
    p1z_r3 = if commOK then gpsZ1 else pre(p1z_r3);
    p1vx_r3 = if commOK then imuVx1 else pre(p1vx_r3);
    p1vy_r3 = if commOK then imuVy1 else pre(p1vy_r3);
    p1vz_r3 = if commOK then imuVz1 else pre(p1vz_r3);
    ts1_r3 = if commOK then time else pre(ts1_r3);

    p2x_r3 = if commOK then gpsX2 else pre(p2x_r3);
    p2y_r3 = if commOK then gpsY2 else pre(p2y_r3);
    p2z_r3 = if commOK then gpsZ2 else pre(p2z_r3);
    p2vx_r3 = if commOK then imuVx2 else pre(p2vx_r3);
    p2vy_r3 = if commOK then imuVy2 else pre(p2vy_r3);
    p2vz_r3 = if commOK then imuVz2 else pre(p2vz_r3);
    ts2_r3 = if commOK then time else pre(ts2_r3);
  end when;

  annotation(experiment(StopTime=12.0, Interval=0.008, Tolerance=1e-6));
end AirTrioResilientC;