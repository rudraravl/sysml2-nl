package Suzuki_Frame_Based_Motorcycle_System {

  import ScalarValues::*;

  attribute def kg :> Real;
  attribute def mm :> Real;
  attribute def N :> Real;
  attribute def Nm :> Real;
  attribute def deg :> Real;
  attribute def km_per_h :> Real;

  item def RiderLoad {
    attribute mass : kg;
    attribute seatedForce : N;
  }

  item def RoadLoad {
    attribute verticalForce : N;
    attribute lateralForce : N;
    attribute brakingForce : N;
  }

  item def EngineTorque {
    attribute torque : Nm;
    attribute speed : Real;
  }

  item def SteeringInput {
    attribute steeringAngle : deg;
    attribute riderForce : N;
  }

  item def BrakeCommand {
    attribute leverForce : N;
  }

  item def Fuel {
    attribute volume : Real;
  }

  port def LoadPort {
    in item load : RoadLoad;
  }

  port def RiderPort {
    in item riderLoad : RiderLoad;
  }

  port def TorquePort {
    in item torque : EngineTorque;
  }

  port def SteeringPort {
    in item input : SteeringInput;
  }

  port def BrakePort {
    in item command : BrakeCommand;
  }

  port def FuelPort {
    in item fuel : Fuel;
  }

  part def SuzukiFrameBasedMotorcycle {
    attribute wetMass : kg = 185.0;
    attribute wheelbase : mm = 1400.0;
    attribute rakeAngle : deg = 25.0;
    attribute trail : mm = 100.0;
    attribute maximumSpeed : km_per_h = 180.0;

    port riderInterfacePort : RiderPort;
    port steeringInputPort : SteeringPort;
    port frontRoadPort : LoadPort;
    port rearRoadPort : LoadPort;
    port fuelFillPort : FuelPort;
    port brakeControlPort : BrakePort;

    part frame : SuzukiTwinSparFrame;
    part engine : InlineEngine;
    part frontSuspension : TelescopicFrontFork;
    part rearSuspension : RearSwingarmSuspension;
    part frontWheel : WheelAssembly;
    part rearWheel : WheelAssembly;
    part fuelTank : FuelTank;
    part seat : RiderSeat;
    part handlebar : HandlebarAssembly;
    part brakeSystem : HydraulicBrakeSystem;

    connect riderInterfacePort to seat.riderPort;
    connect steeringInputPort to handlebar.steeringPort;
    connect fuelFillPort to fuelTank.fillPort;
    connect brakeControlPort to brakeSystem.commandPort;

    connect seat.frameMountPort to frame.seatMountPort;
    connect fuelTank.frameMountPort to frame.tankMountPort;
    connect engine.frameMountPort to frame.engineMountPort;
    connect handlebar.steeringStemPort to frame.steeringHeadPort;

    connect frontRoadPort to frontWheel.roadLoadPort;
    connect rearRoadPort to rearWheel.roadLoadPort;

    connect frontWheel.axlePort to frontSuspension.axlePort;
    connect frontSuspension.steeringHeadPort to frame.steeringHeadPort;

    connect rearWheel.axlePort to rearSuspension.axlePort;
    connect rearSuspension.pivotPort to frame.swingarmPivotPort;

    connect engine.outputTorquePort to rearWheel.driveTorquePort;
    connect brakeSystem.frontBrakePort to frontWheel.brakePort;
    connect brakeSystem.rearBrakePort to rearWheel.brakePort;

    perform action primaryFunction;
    exhibit state lifecycle;
  }

  part def SuzukiTwinSparFrame {
    attribute frameMass : kg = 14.5;
    attribute mainSparWallThickness : mm = 3.0;
    attribute torsionalStiffness : Nm = 1250.0;
    attribute yieldLoad : N = 18000.0;

    port steeringHeadPort : LoadPort;
    port swingarmPivotPort : LoadPort;
    port engineMountPort : LoadPort;
    port seatMountPort : LoadPort;
    port tankMountPort : LoadPort;

    part steeringHead : SteeringHeadTube;
    part leftMainSpar : MainSpar;
    part rightMainSpar : MainSpar;
    part crossMember : CrossMember;
    part engineCradle : EngineMountCradle;
    part swingarmPivotBoss : SwingarmPivotBoss;
    part rearSubframe : RearSubframe;

    connect steeringHead.lowerLoadPort to leftMainSpar.frontLoadPort;
    connect steeringHead.lowerLoadPort to rightMainSpar.frontLoadPort;
    connect leftMainSpar.rearLoadPort to swingarmPivotBoss.leftLoadPort;
    connect rightMainSpar.rearLoadPort to swingarmPivotBoss.rightLoadPort;
    connect crossMember.leftPort to leftMainSpar.midLoadPort;
    connect crossMember.rightPort to rightMainSpar.midLoadPort;
    connect engineCradle.upperPort to crossMember.centerPort;
    connect engineCradle.lowerPort to swingarmPivotBoss.centerLoadPort;
    connect rearSubframe.forwardPort to swingarmPivotBoss.subframePort;
  }

  part def SteeringHeadTube {
    attribute bearingSpacing : mm = 145.0;
    attribute rakeAngle : deg = 25.0;
    port lowerLoadPort : LoadPort;
  }

  part def MainSpar {
    attribute length : mm = 620.0;
    attribute sectionHeight : mm = 85.0;
    attribute sectionWidth : mm = 42.0;
    port frontLoadPort : LoadPort;
    port midLoadPort : LoadPort;
    port rearLoadPort : LoadPort;
  }

  part def CrossMember {
    attribute width : mm = 310.0;
    port leftPort : LoadPort;
    port rightPort : LoadPort;
    port centerPort : LoadPort;
  }

  part def EngineMountCradle {
    attribute mountCount : Integer = 4;
    port upperPort : LoadPort;
    port lowerPort : LoadPort;
  }

  part def SwingarmPivotBoss {
    attribute pivotDiameter : mm = 22.0;
    port leftLoadPort : LoadPort;
    port rightLoadPort : LoadPort;
    port centerLoadPort : LoadPort;
    port subframePort : LoadPort;
  }

  part def RearSubframe {
    attribute payloadLimit : kg = 185.0;
    port forwardPort : LoadPort;
  }

  part def InlineEngine {
    attribute displacement : Real = 0.645;
    attribute peakTorque : Nm = 64.0;
    attribute engineMass : kg = 58.0;

    port frameMountPort : LoadPort;
    port outputTorquePort : TorquePort;
  }

  part def TelescopicFrontFork {
    attribute travel : mm = 120.0;
    attribute tubeDiameter : mm = 41.0;

    port steeringHeadPort : LoadPort;
    port axlePort : LoadPort;
  }

  part def RearSwingarmSuspension {
    attribute travel : mm = 130.0;
    attribute swingarmLength : mm = 575.0;

    port pivotPort : LoadPort;
    port axlePort : LoadPort;
  }

  part def WheelAssembly {
    attribute rimDiameter : mm = 432.0;
    attribute tireWidth : mm = 120.0;

    port roadLoadPort : LoadPort;
    port axlePort : LoadPort;
    port driveTorquePort : TorquePort;
    port brakePort : BrakePort;
  }

  part def FuelTank {
    attribute capacity : Real = 14.5;
    attribute mountedMassFull : kg = 13.0;

    port fillPort : FuelPort;
    port frameMountPort : LoadPort;
  }

  part def RiderSeat {
    attribute seatHeight : mm = 785.0;
    attribute cushionLoadLimit : kg = 120.0;

    port riderPort : RiderPort;
    port frameMountPort : LoadPort;
  }

  part def HandlebarAssembly {
    attribute width : mm = 760.0;

    port steeringPort : SteeringPort;
    port steeringStemPort : LoadPort;
  }

  part def HydraulicBrakeSystem {
    attribute frontDiscDiameter : mm = 290.0;
    attribute rearDiscDiameter : mm = 240.0;

    port commandPort : BrakePort;
    port frontBrakePort : BrakePort;
    port rearBrakePort : BrakePort;
  }

  action def SupportAndAlignMotorcycle {
    in item rider : RiderLoad;
    in item frontLoad : RoadLoad;
    in item rearLoad : RoadLoad;
    in item engineTorque : EngineTorque;

    out attribute chassisStable : Boolean;

    action distributeRiderLoad;
    action carryPowertrainMass;
    action transferSuspensionLoads;
    action maintainSteeringGeometry;
    action reactDriveAndBrakeTorque;

    first start;
    then distributeRiderLoad;
    then carryPowertrainMass;
    then transferSuspensionLoads;
    then maintainSteeringGeometry;
    then reactDriveAndBrakeTorque;
    then done;

    bind chassisStable = true;
  }

  state def MotorcycleLifecycle {
    state parked;
    state ready;
    state accelerating;
    state cruising;
    state braking;
    state cornering;
    state stopped;

    transition parked_to_ready first parked then ready;
    transition ready_to_accelerating first ready then accelerating;
    transition accelerating_to_cruising first accelerating then cruising;
    transition cruising_to_cornering first cruising then cornering;
    transition cornering_to_cruising first cornering then cruising;
    transition cruising_to_braking first cruising then braking;
    transition braking_to_stopped first braking then stopped;
    transition stopped_to_ready first stopped then ready;
  }

  requirement def PrimaryFunctionRequirement {
    subject motorcycle : SuzukiFrameBasedMotorcycle;

    doc /* The system shall use a Suzuki-style twin-spar motorcycle frame as the central load-bearing structure to support the rider, engine, fuel system, steering assembly, suspension, and wheels while maintaining wheel alignment and steering geometry during acceleration, braking, cornering, and road-load events. */

    require constraint {
      motorcycle.frame.torsionalStiffness >= 1000.0
    }

    require constraint {
      motorcycle.wheelbase >= 1350.0 and motorcycle.wheelbase <= 1450.0
    }

    require constraint {
      motorcycle.frame.yieldLoad >= 15000.0
    }
  }

  requirement def RiderSupportRequirement {
    subject frame : SuzukiTwinSparFrame;

    require constraint {
      frame.rearSubframe.payloadLimit >= 180.0
    }
  }

  requirement def SteeringGeometryRequirement {
    subject motorcycle : SuzukiFrameBasedMotorcycle;

    require constraint {
      motorcycle.rakeAngle >= 23.0 and motorcycle.rakeAngle <= 27.0
    }

    require constraint {
      motorcycle.trail >= 90.0 and motorcycle.trail <= 110.0
    }
  }

  requirement def PowertrainMountRequirement {
    subject engine : InlineEngine;

    require constraint {
      engine.peakTorque >= 60.0
    }
  }

  part suzukiFrameSystem : SuzukiFrameBasedMotorcycle {
    :>> primaryFunction : SupportAndAlignMotorcycle;
    :>> lifecycle : MotorcycleLifecycle;
  }

  requirement primaryFunctionRequirement : PrimaryFunctionRequirement {
    subject suzukiFrameSystem;
  }

  requirement riderSupportRequirement : RiderSupportRequirement {
    subject suzukiFrameSystem.frame;
  }

  requirement steeringGeometryRequirement : SteeringGeometryRequirement {
    subject suzukiFrameSystem;
  }

  requirement powertrainMountRequirement : PowertrainMountRequirement {
    subject suzukiFrameSystem.engine;
  }
}