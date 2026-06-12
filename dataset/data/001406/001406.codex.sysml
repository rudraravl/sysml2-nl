package DomesticRoboticCleaningSystem {

  import ScalarValues::*;
  import SI::*;

  value type Percent specializes Real {
    unit = "%";
    quantityKind = "ratio";
  }

  value type WattHour specializes Real {
    unit = "W.h";
    quantityKind = "energy";
  }

  value type Watt specializes Real {
    unit = "W";
    quantityKind = "power";
  }

  value type Volt specializes Real {
    unit = "V";
    quantityKind = "electricPotential";
  }

  value type Meter specializes Real {
    unit = "m";
    quantityKind = "length";
  }

  value type SquareMeter specializes Real {
    unit = "m^2";
    quantityKind = "area";
  }

  value type MeterPerSecond specializes Real {
    unit = "m/s";
    quantityKind = "speed";
  }

  value type Gram specializes Real {
    unit = "g";
    quantityKind = "mass";
  }

  value type Pascal specializes Real {
    unit = "Pa";
    quantityKind = "pressure";
  }

  value type Second specializes Real {
    unit = "s";
    quantityKind = "time";
  }

  value type Decibel specializes Real {
    unit = "dB";
    quantityKind = "soundPressureLevel";
  }

  enum def CleaningMode {
    enum standard;
    enum quiet;
    enum deep;
    enum spot;
    enum edge;
  }

  enum def SurfaceType {
    enum hardwood;
    enum tile;
    enum carpet;
    enum rug;
    enum unknown;
  }

  enum def RobotHealth {
    enum nominal;
    enum lowBattery;
    enum binFull;
    enum brushJammed;
    enum lostLocalization;
    enum blocked;
    enum unsafe;
  }

  item def Dust {
    attribute mass : Gram;
    attribute particleSize : Meter;
  }

  item def Debris {
    attribute mass : Gram;
    attribute diameter : Meter;
  }

  item def AirFlow {
    attribute volumetricRate : Real;
    attribute vacuumPressure : Pascal;
  }

  item def ElectricalPower {
    attribute voltage : Volt;
    attribute power : Watt;
  }

  item def ChargingEnergy {
    attribute energy : WattHour;
    attribute voltage : Volt;
  }

  item def MapData {
    attribute mappedArea : SquareMeter;
    attribute obstacleCount : Integer;
    attribute localizationConfidence : Percent;
  }

  item def CleaningCommand {
    attribute requestedMode : CleaningMode;
    attribute targetArea : SquareMeter;
    attribute maxDuration : Second;
  }

  item def StatusReport {
    attribute batteryStateOfCharge : Percent;
    attribute collectedDustMass : Gram;
    attribute cleanedArea : SquareMeter;
    attribute health : RobotHealth;
  }

  port def PowerInPort {
    in item power : ElectricalPower;
  }

  port def PowerOutPort {
    out item power : ElectricalPower;
  }

  port def ChargingPort {
    in item energy : ChargingEnergy;
  }

  port def CommandPort {
    in item command : CleaningCommand;
  }

  port def StatusPort {
    out item status : StatusReport;
  }

  port def DustIntakePort {
    in item dust : Dust;
    in item debris : Debris;
    out item airflow : AirFlow;
  }

  port def MapPort {
    out item map : MapData;
  }

  port def WheelDrivePort {
    out item tractionCommand : Real;
  }

  part def DomesticRobot {
    attribute nominalSpeed : MeterPerSecond = 0.35;
    attribute maximumSpeed : MeterPerSecond = 0.65;
    attribute maximumNoise : Decibel = 62.0;
    attribute dustBinCapacity : Gram = 450.0;
    attribute batteryCapacity : WattHour = 96.0;
    attribute minimumOperatingCharge : Percent = 15.0;
    attribute returnToDockChargeThreshold : Percent = 20.0;
    attribute cleanedArea : SquareMeter = 0.0;
    attribute collectedDust : Gram = 0.0;
    attribute health : RobotHealth = RobotHealth::nominal;

    port commandIn : CommandPort;
    port statusOut : StatusPort;
    port chargeIn : ChargingPort;
    port mapOut : MapPort;

    part battery : BatteryPack;
    part controller : MissionController;
    part perception : PerceptionSuite;
    part navigation : NavigationSubsystem;
    part cleaningHead : CleaningSubsystem;
    part drive : DifferentialDrive;
    part safety : SafetySubsystem;
    part wireless : HomeNetworkInterface;

    connect chargeIn.energy to battery.chargePort.energy;
    connect battery.powerOut.power to controller.powerIn.power;
    connect battery.powerOut.power to perception.powerIn.power;
    connect battery.powerOut.power to navigation.powerIn.power;
    connect battery.powerOut.power to cleaningHead.powerIn.power;
    connect battery.powerOut.power to drive.powerIn.power;
    connect commandIn.command to controller.commandIn.command;
    connect perception.mapOut.map to navigation.mapIn.map;
    connect navigation.driveCommand.tractionCommand to drive.driveCommand.tractionCommand;
    connect controller.cleaningCommand.command to cleaningHead.cleaningCommand.command;
    connect controller.statusOut.status to statusOut.status;
    connect perception.mapOut.map to mapOut.map;

    perform action executePrimaryDomesticTask : CleanDomesticFloor;
    exhibit state robotOperationalStates : DomesticRobotStateMachine;
  }

  part def BatteryPack {
    attribute capacity : WattHour = 96.0;
    attribute stateOfCharge : Percent = 100.0;
    attribute nominalVoltage : Volt = 24.0;
    attribute maximumDischargePower : Watt = 180.0;

    port chargePort : ChargingPort;
    port powerOut : PowerOutPort;
  }

  part def MissionController {
    attribute activeMode : CleaningMode = CleaningMode::standard;
    attribute plannedCoverage : SquareMeter = 0.0;
    attribute elapsedMissionTime : Second = 0.0;

    port powerIn : PowerInPort;
    port commandIn : CommandPort;
    port cleaningCommand : CommandPort;
    port statusOut : StatusPort;
  }

  part def PerceptionSuite {
    attribute obstacleDetectionRange : Meter = 3.0;
    attribute cliffDetectionRange : Meter = 0.08;
    attribute localizationConfidence : Percent = 99.0;

    port powerIn : PowerInPort;
    port mapOut : MapPort;

    part lidar : LidarSensor;
    part bumper : ContactBumper;
    part cliffSensors : CliffSensorArray;
    part dirtSensor : DirtSensor;
  }

  part def LidarSensor {
    attribute scanRange : Meter = 6.0;
    attribute angularResolution : Real = 1.0;
    port powerIn : PowerInPort;
  }

  part def ContactBumper {
    attribute actuationForce : Real = 4.0;
    port powerIn : PowerInPort;
  }

  part def CliffSensorArray {
    attribute sensorCount : Integer = 6;
    attribute detectionHeight : Meter = 0.08;
    port powerIn : PowerInPort;
  }

  part def DirtSensor {
    attribute minimumDetectableDustMass : Gram = 0.05;
    port powerIn : PowerInPort;
  }

  part def NavigationSubsystem {
    attribute commandedSpeed : MeterPerSecond = 0.35;
    attribute positionError : Meter = 0.05;
    attribute coveredArea : SquareMeter = 0.0;

    port powerIn : PowerInPort;
    port mapIn : MapPort;
    port driveCommand : WheelDrivePort;
  }

  part def CleaningSubsystem {
    attribute suctionPower : Watt = 80.0;
    attribute brushSpeed : Real = 1200.0;
    attribute collectionEfficiency : Percent = 92.0;
    attribute binFillLevel : Percent = 0.0;

    port powerIn : PowerInPort;
    port cleaningCommand : CommandPort;
    port intake : DustIntakePort;

    part vacuumMotor : VacuumMotor;
    part mainBrush : BrushRoller;
    part sideBrushLeft : SideBrush;
    part sideBrushRight : SideBrush;
    part dustBin : DustBin;

    connect intake.dust to dustBin.collectedDust;
    connect intake.debris to dustBin.collectedDebris;
  }

  part def VacuumMotor {
    attribute ratedPower : Watt = 80.0;
    attribute vacuumPressure : Pascal = 1800.0;
    port powerIn : PowerInPort;
  }

  part def BrushRoller {
    attribute width : Meter = 0.17;
    attribute rotationalSpeed : Real = 1200.0;
    port powerIn : PowerInPort;
  }

  part def SideBrush {
    attribute radius : Meter = 0.045;
    attribute rotationalSpeed : Real = 1600.0;
    port powerIn : PowerInPort;
  }

  part def DustBin {
    attribute capacity : Gram = 450.0;
    attribute fillMass : Gram = 0.0;
    in item collectedDust : Dust;
    in item collectedDebris : Debris;
  }

  part def DifferentialDrive {
    attribute wheelDiameter : Meter = 0.072;
    attribute trackWidth : Meter = 0.235;
    attribute maximumSlope : Real = 10.0;

    port powerIn : PowerInPort;
    port driveCommand : WheelDrivePort;

    part leftMotor : WheelMotor;
    part rightMotor : WheelMotor;
  }

  part def WheelMotor {
    attribute ratedPower : Watt = 25.0;
    attribute maximumTorque : Real = 0.45;
    port powerIn : PowerInPort;
  }

  part def SafetySubsystem {
    attribute emergencyStopLatency : Second = 0.2;
    attribute minimumObstacleClearance : Meter = 0.05;

    port powerIn : PowerInPort;
  }

  part def HomeNetworkInterface {
    attribute wirelessRange : Meter = 25.0;
    attribute encryptedLink : Boolean = true;

    port powerIn : PowerInPort;
    port commandIn : CommandPort;
    port statusOut : StatusPort;
  }

  part def ChargingDock {
    attribute outputVoltage : Volt = 24.0;
    attribute maximumChargePower : Watt = 45.0;
    attribute alignmentTolerance : Meter = 0.03;

    port powerIn : PowerInPort;
    port chargeOut : ChargingPort;
    port statusIn : StatusPort;
  }

  part def DomesticEnvironment {
    attribute totalCleanableArea : SquareMeter = 85.0;
    attribute roomCount : Integer = 5;
    attribute minimumPassageWidth : Meter = 0.72;

    part kitchen : Room {
      attribute cleanableArea : SquareMeter = 18.0;
      attribute dominantSurface : SurfaceType = SurfaceType::tile;
    }

    part livingRoom : Room {
      attribute cleanableArea : SquareMeter = 28.0;
      attribute dominantSurface : SurfaceType = SurfaceType::hardwood;
    }

    part bedroom : Room {
      attribute cleanableArea : SquareMeter = 20.0;
      attribute dominantSurface : SurfaceType = SurfaceType::carpet;
    }

    part hallway : Room {
      attribute cleanableArea : SquareMeter = 11.0;
      attribute dominantSurface : SurfaceType = SurfaceType::hardwood;
    }

    part bathroom : Room {
      attribute cleanableArea : SquareMeter = 8.0;
      attribute dominantSurface : SurfaceType = SurfaceType::tile;
    }
  }

  part def Room {
    attribute cleanableArea : SquareMeter;
    attribute dominantSurface : SurfaceType;
    attribute obstacleCount : Integer = 0;
  }

  part def HomeOwner {
    port commandOut : CommandPort;
    port statusIn : StatusPort;
  }

  part def DomesticRoboticCleaningSystem {
    attribute scheduledStartTime : String = "09:00";
    attribute requiredCoverage : Percent = 95.0;

    part user : HomeOwner;
    part robot : DomesticRobot;
    part dock : ChargingDock;
    part home : DomesticEnvironment;
    part mainsAdapter : HouseholdPowerAdapter;

    connect user.commandOut.command to robot.commandIn.command;
    connect robot.statusOut.status to user.statusIn.status;
    connect mainsAdapter.powerOut.power to dock.powerIn.power;
    connect dock.chargeOut.energy to robot.chargeIn.energy;
    connect robot.statusOut.status to dock.statusIn.status;
  }

  part def HouseholdPowerAdapter {
    attribute inputVoltage : Volt = 120.0;
    attribute outputVoltage : Volt = 24.0;
    attribute maximumOutputPower : Watt = 60.0;

    port powerOut : PowerOutPort;
  }

  action def CleanDomesticFloor {
    in item command : CleaningCommand;
    in item map : MapData;
    out item report : StatusReport;

    attribute targetCoverage : Percent = 95.0;
    attribute maximumMissionTime : Second = 5400.0;
    attribute minimumResidualCharge : Percent = 15.0;

    first start;
    then validateCommand;
    then undock;
    then buildOrUpdateMap;
    then planCoveragePath;
    then cleanRooms;
    then inspectMissedZones;
    then returnToDock;
    then publishCompletionReport;
    then done;

    action validateCommand {
      in item command : CleaningCommand;
      out valid : Boolean;
    }

    action undock {
      out clearedDock : Boolean;
    }

    action buildOrUpdateMap {
      in item map : MapData;
      out item updatedMap : MapData;
    }

    action planCoveragePath {
      in item updatedMap : MapData;
      out plannedArea : SquareMeter;
    }

    action cleanRooms {
      in plannedArea : SquareMeter;
      out cleanedArea : SquareMeter;
      out collectedDust : Gram;
    }

    action inspectMissedZones {
      in cleanedArea : SquareMeter;
      out coverage : Percent;
    }

    action returnToDock {
      in coverage : Percent;
      out docked : Boolean;
    }

    action publishCompletionReport {
      in docked : Boolean;
      out item report : StatusReport;
    }
  }

  action def AvoidObstacle {
    in obstacleDistance : Meter;
    out avoidanceComplete : Boolean;

    first detect;
    then stop;
    then replanLocalPath;
    then resume;

    action detect;
    action stop;
    action replanLocalPath;
    action resume;
  }

  action def RechargeBattery {
    in initialCharge : Percent;
    out finalCharge : Percent;

    first alignWithDock;
    then engageContacts;
    then chargeUntilReady;
    then standby;

    action alignWithDock;
    action engageContacts;
    action chargeUntilReady;
    action standby;
  }

  state def DomesticRobotStateMachine {
    entry action initializeSelfTest;

    state poweredOff;
    state standby;
    state mapping;
    state cleaning;
    state avoidingObstacle;
    state returningToDock;
    state charging;
    state fault;
    state maintenanceRequired;

    transition initial then standby;

    transition standby_to_mapping
      first standby
      accept CleaningCommand
      if health == RobotHealth::nominal
      then mapping;

    transition mapping_to_cleaning
      first mapping
      if localizationConfidence >= 90.0
      then cleaning;

    transition cleaning_to_avoidance
      first cleaning
      accept obstacleDetected
      then avoidingObstacle;

    transition avoidance_to_cleaning
      first avoidingObstacle
      if pathIsClear
      then cleaning;

    transition cleaning_to_return
      first cleaning
      if cleanedArea >= plannedCoverage or batteryStateOfCharge <= returnToDockChargeThreshold
      then returningToDock;

    transition returning_to_charging
      first returningToDock
      if docked
      then charging;

    transition charging_to_standby
      first charging
      if batteryStateOfCharge >= 95.0
      then standby;

    transition any_to_fault
      first standby
      accept unsafeCondition
      then fault;

    transition cleaning_to_maintenance
      first cleaning
      if health == RobotHealth::binFull or health == RobotHealth::brushJammed
      then maintenanceRequired;

    transition maintenance_to_standby
      first maintenanceRequired
      accept userClearedFault
      then standby;
  }

  requirement def PrimaryDomesticTaskRequirement {
    subject robot : DomesticRobot;

    require constraint {
      robot.executePrimaryDomesticTask.report.cleanedArea >= 0.95 * DomesticRoboticCleaningSystem::home.totalCleanableArea
    }

    doc /* The robotic system shall perform its primary domestic floor-cleaning task using the DomesticRobot part. */
  }

  requirement def CoverageRequirement {
    subject system : DomesticRoboticCleaningSystem;

    require constraint {
      system.robot.cleanedArea >= 0.95 * system.home.totalCleanableArea
    }

    doc /* The system shall clean at least 95 percent of the mapped cleanable domestic floor area during a scheduled mission. */
  }

  requirement def BatteryReturnRequirement {
    subject robot : DomesticRobot;

    require constraint {
      robot.battery.stateOfCharge >= robot.minimumOperatingCharge
    }

    doc /* The robot shall preserve sufficient battery charge to return to the charging dock without user intervention. */
  }

  requirement def DustCollectionRequirement {
    subject robot : DomesticRobot;

    require constraint {
      robot.cleaningHead.collectionEfficiency >= 90.0
    }

    doc /* The cleaning subsystem shall collect at least 90 percent of detectable dust and debris encountered by the intake path. */
  }

  requirement def NoiseRequirement {
    subject robot : DomesticRobot;

    require constraint {
      robot.maximumNoise <= 62.0
    }

    doc /* The robot shall not exceed 62 dB during standard cleaning mode in a domestic environment. */
  }

  requirement def SafetyRequirement {
    subject robot : DomesticRobot;

    require constraint {
      robot.safety.emergencyStopLatency <= 0.2 and robot.safety.minimumObstacleClearance >= 0.05
    }

    doc /* The robot shall stop or replan within 0.2 seconds of detecting an unsafe obstacle or cliff condition. */
  }

  requirement def DockingRequirement {
    subject dock : ChargingDock;

    require constraint {
      dock.alignmentTolerance <= 0.03
    }

    doc /* The charging dock and robot shall support autonomous docking within a lateral alignment tolerance of 0.03 m. */
  }

  satisfy PrimaryDomesticTaskRequirement by DomesticRoboticCleaningSystem::robot;
  satisfy CoverageRequirement by DomesticRoboticCleaningSystem;
  satisfy BatteryReturnRequirement by DomesticRoboticCleaningSystem::robot::battery;
  satisfy DustCollectionRequirement by DomesticRoboticCleaningSystem::robot::cleaningHead;
  satisfy NoiseRequirement by DomesticRoboticCleaningSystem::robot;
  satisfy SafetyRequirement by DomesticRoboticCleaningSystem::robot::safety;
  satisfy DockingRequirement by DomesticRoboticCleaningSystem::dock;
}