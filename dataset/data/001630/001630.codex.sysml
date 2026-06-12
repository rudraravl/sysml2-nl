package WolfRoboticsModel {

  import ScalarValues::*;

  attribute def Length_m :> Real { doc "meters"; }
  attribute def Mass_kg :> Real { doc "kilograms"; }
  attribute def Speed_mps :> Real { doc "meters per second"; }
  attribute def Power_W :> Real { doc "watts"; }
  attribute def Energy_Wh :> Real { doc "watt hours"; }
  attribute def Voltage_V :> Real { doc "volts"; }
  attribute def Force_N :> Real { doc "newtons"; }
  attribute def Temperature_C :> Real { doc "degrees Celsius"; }
  attribute def Percent :> Real { doc "percent from 0 to 100"; }
  attribute def Time_s :> Real { doc "seconds"; }

  item def MissionCommand {
    attribute missionId : String;
    attribute targetZone : String;
    attribute priority : Integer;
    attribute requestedMode : String;
  }

  item def TerrainMap {
    attribute mapId : String;
    attribute resolution : Length_m;
    attribute confidence : Percent;
  }

  item def SensorFrame {
    attribute timestamp : Time_s;
    attribute obstacleRange : Length_m;
    attribute thermalContrast : Temperature_C;
    attribute acousticBearing_deg : Real;
  }

  item def MotionCommand {
    attribute linearSpeed : Speed_mps;
    attribute yawRate_degps : Real;
    attribute gaitMode : String;
  }

  item def BatteryPower {
    attribute voltage : Voltage_V;
    attribute availableEnergy : Energy_Wh;
    attribute peakPower : Power_W;
  }

  item def StatusReport {
    attribute healthState : String;
    attribute batteryStateOfCharge : Percent;
    attribute currentMode : String;
    attribute payloadSecured : Boolean;
  }

  port def CommandPort {
    in item command : MissionCommand;
    out item status : StatusReport;
  }

  port def PerceptionPort {
    out item sensedFrame : SensorFrame;
    out item localMap : TerrainMap;
  }

  port def MotionPort {
    in item motion : MotionCommand;
  }

  port def PowerPort {
    in item power : BatteryPower;
  }

  port def PayloadPort {
    in item pickupRequest : MissionCommand;
    out item payloadStatus : StatusReport;
  }

  part def SensorMast {
    attribute height : Length_m = 0.82;
    attribute mass : Mass_kg = 4.6;
    attribute maxDetectionRange : Length_m = 120.0;
    port perception : PerceptionPort;
  }

  part def NavigationComputer {
    attribute processorPower : Power_W = 95.0;
    attribute mapUpdatePeriod : Time_s = 0.10;
    port commandLink : CommandPort;
    port perceptionIn : PerceptionPort;
    port motionOut : MotionPort;
  }

  part def QuadrupedMobilityBase {
    attribute bodyLength : Length_m = 1.35;
    attribute stanceWidth : Length_m = 0.48;
    attribute mass : Mass_kg = 58.0;
    attribute maxSpeed : Speed_mps = 4.2;
    attribute continuousTractiveForce : Force_N = 620.0;
    port motionIn : MotionPort;
    port powerIn : PowerPort;

    part frontLeftLeg : LegAssembly;
    part frontRightLeg : LegAssembly;
    part rearLeftLeg : LegAssembly;
    part rearRightLeg : LegAssembly;
  }

  part def LegAssembly {
    attribute limbLength : Length_m = 0.64;
    attribute actuatorCount : Integer = 3;
    attribute peakJointTorque_Nm : Real = 190.0;
    attribute nominalPower : Power_W = 340.0;
  }

  part def BatteryModule {
    attribute nominalVoltage : Voltage_V = 72.0;
    attribute capacity : Energy_Wh = 3600.0;
    attribute mass : Mass_kg = 22.0;
    attribute minimumReserve : Percent = 18.0;
    port powerOut : PowerPort;
  }

  part def PayloadHandler {
    attribute payloadCapacity : Mass_kg = 18.0;
    attribute gripperForce : Force_N = 280.0;
    attribute secureLatchTime : Time_s = 2.5;
    port payload : PayloadPort;
    port powerIn : PowerPort;
  }

  part def CommunicationsUnit {
    attribute lineOfSightRange : Length_m = 2500.0;
    attribute transmitPower : Power_W = 8.0;
    port commandNetwork : CommandPort;
    port powerIn : PowerPort;
  }

  part def WolfRoboticsSystem {
    doc "Wolf Robotics is an autonomous wolf-inspired quadruped robotic system whose primary high-level function is to traverse difficult terrain, perceive its surroundings, and transport or retrieve mission payloads while reporting operational status to a remote operator."

    attribute totalMass : Mass_kg = 92.4;
    attribute nominalEndurance : Time_s = 10800.0;
    attribute cruiseSpeed : Speed_mps = 1.6;
    attribute maximumSlope_deg : Real = 38.0;
    attribute operatingLowTemperature : Temperature_C = -20.0;
    attribute operatingHighTemperature : Temperature_C = 45.0;

    port operatorInterface : CommandPort;
    port payloadInterface : PayloadPort;

    part sensors : SensorMast;
    part autonomy : NavigationComputer;
    part mobility : QuadrupedMobilityBase;
    part battery : BatteryModule;
    part payloadHandler : PayloadHandler;
    part communications : CommunicationsUnit;

    connect operatorInterface to communications.commandNetwork;
    connect communications.commandNetwork to autonomy.commandLink;
    connect sensors.perception to autonomy.perceptionIn;
    connect autonomy.motionOut to mobility.motionIn;
    connect battery.powerOut to mobility.powerIn;
    connect battery.powerOut to payloadHandler.powerIn;
    connect battery.powerOut to communications.powerIn;
    connect payloadInterface to payloadHandler.payload;
  }

  action def ExecuteWolfRoboticsMission {
    in item mission : MissionCommand;
    out item report : StatusReport;

    action receiveMission {
      in item command : MissionCommand;
      out item accepted : MissionCommand;
    }

    action buildTerrainUnderstanding {
      in item frame : SensorFrame;
      out item map : TerrainMap;
    }

    action planWolfGaitRoute {
      in item map : TerrainMap;
      in item command : MissionCommand;
      out item motion : MotionCommand;
    }

    action traverseTerrain {
      in item motion : MotionCommand;
      out item progress : StatusReport;
    }

    action acquirePayload {
      in item command : MissionCommand;
      out item payloadSecured : StatusReport;
    }

    action returnStatus {
      in item progress : StatusReport;
      out item report : StatusReport;
    }

    first start;
    then receiveMission;
    then buildTerrainUnderstanding;
    then planWolfGaitRoute;
    then traverseTerrain;
    then acquirePayload;
    then returnStatus;
    then done;
  }

  state def WolfRoboticsOperatingState {
    state Off;
    state Standby;
    state SelfTest;
    state AutonomousTraverse;
    state PayloadHandling;
    state ReturnToOperator;
    state FaultSafe;

    transition first Off;
    transition Off then Standby accept PowerEnabled;
    transition Standby then SelfTest accept MissionReceived;
    transition SelfTest then AutonomousTraverse accept SelfTestPassed;
    transition AutonomousTraverse then PayloadHandling accept TargetReached;
    transition PayloadHandling then ReturnToOperator accept PayloadSecured;
    transition AutonomousTraverse then FaultSafe accept CriticalFault;
    transition PayloadHandling then FaultSafe accept CriticalFault;
    transition ReturnToOperator then Standby accept MissionComplete;
    transition FaultSafe then Standby accept FaultCleared;
  }

  requirement def PrimaryFunctionRequirement {
    doc "The Wolf Robotics system shall autonomously traverse uneven terrain, detect obstacles, select stable gait commands, handle a mission payload, and provide status reports to an operator."
    subject system : WolfRoboticsSystem;
    require constraint {
      system.cruiseSpeed >= 1.0 and
      system.maximumSlope_deg >= 30.0 and
      system.nominalEndurance >= 7200.0
    }
  }

  requirement def PerceptionRequirement {
    doc "The system shall detect terrain obstacles at sufficient range to support autonomous navigation."
    subject sensorMast : SensorMast;
    require constraint {
      sensorMast.maxDetectionRange >= 100.0
    }
  }

  requirement def MobilityRequirement {
    doc "The mobility base shall provide stable quadruped movement over rough terrain while carrying the integrated payload handler."
    subject base : QuadrupedMobilityBase;
    require constraint {
      base.maxSpeed >= 4.0 and
      base.continuousTractiveForce >= 600.0
    }
  }

  requirement def PayloadRequirement {
    doc "The payload handler shall secure and carry mission payloads up to 18 kg."
    subject handler : PayloadHandler;
    require constraint {
      handler.payloadCapacity >= 18.0 and
      handler.gripperForce >= 250.0
    }
  }

  part wolfRobot : WolfRoboticsSystem;

  requirement primaryFunction : PrimaryFunctionRequirement {
    subject system = wolfRobot;
  }

  requirement perceptionPerformance : PerceptionRequirement {
    subject sensorMast = wolfRobot.sensors;
  }

  requirement mobilityPerformance : MobilityRequirement {
    subject base = wolfRobot.mobility;
  }

  requirement payloadPerformance : PayloadRequirement {
    subject handler = wolfRobot.payloadHandler;
  }

  satisfy primaryFunction by wolfRobot;
  satisfy perceptionPerformance by wolfRobot.sensors;
  satisfy mobilityPerformance by wolfRobot.mobility;
  satisfy payloadPerformance by wolfRobot.payloadHandler;
}