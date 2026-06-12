package RoboticVacuumCleanerSystem {

  import ScalarValues::*;
  import ISQ::*;
  import SI::*;

  attribute def Percentage :> Real {
    doc "A bounded fraction represented as percent.";
    attribute min : Real = 0.0;
    attribute max : Real = 100.0;
  }

  attribute def DustMass :> MassValue {
    unit = g;
  }

  attribute def BatteryEnergy :> EnergyValue {
    unit = W*h;
  }

  attribute def LinearSpeed :> SpeedValue {
    unit = m/s;
  }

  attribute def Area :> AreaValue {
    unit = m^2;
  }

  attribute def SoundLevel :> Real {
    unit = dB;
  }

  attribute def Distance :> LengthValue {
    unit = m;
  }

  item def ElectricalPower {
    attribute voltage : ElectricPotentialValue { unit = V; }
    attribute current : ElectricCurrentValue { unit = A; }
    attribute power : PowerValue { unit = W; }
  }

  item def DustAndDebris {
    attribute mass : DustMass;
    attribute particleSize : LengthValue { unit = mm; }
  }

  item def FloorContact {
    attribute frictionCoefficient : Real;
    attribute surfaceType : String;
  }

  item def MapData {
    attribute coveredArea : Area;
    attribute remainingArea : Area;
    attribute obstacleCount : Integer;
    attribute dockingStationPoseKnown : Boolean;
  }

  item def Command {
    attribute commandId : String;
    attribute mode : CleaningMode;
  }

  item def StatusReport {
    attribute batteryStateOfCharge : Percentage;
    attribute binFillLevel : Percentage;
    attribute cleaningState : RobotState;
    attribute faultCode : String;
  }

  enum def CleaningMode {
    enum scheduled;
    enum spot;
    enum edge;
    enum fullHome;
    enum quiet;
    enum maxSuction;
  }

  enum def RobotState {
    enum docked;
    enum charging;
    enum ready;
    enum cleaning;
    enum returningToDock;
    enum emptyingBin;
    enum faulted;
  }

  enum def FaultType {
    enum none;
    enum wheelStall;
    enum brushJam;
    enum cliffDetected;
    enum binMissing;
    enum batteryLow;
    enum localizationLost;
    enum dockNotFound;
  }

  port def PowerPort {
    in item suppliedPower : ElectricalPower;
  }

  port def ChargePort {
    out item chargingPower : ElectricalPower;
  }

  port def DustPort {
    in item collectedDebris : DustAndDebris;
  }

  port def ExhaustPort {
    out item filteredAir;
  }

  port def MotionCommandPort {
    in attribute commandedSpeed : LinearSpeed;
    in attribute commandedYawRate : Real { unit = rad/s; }
  }

  port def SensorDataPort {
    out attribute measuredDistance : Distance;
    out attribute cliffDetected : Boolean;
    out attribute bumpDetected : Boolean;
    out attribute wheelSlipDetected : Boolean;
  }

  port def UserCommandPort {
    in item userCommand : Command;
    out item robotStatus : StatusReport;
  }

  part def RoboticVacuumCleaner {
    attribute state : RobotState = RobotState::docked;
    attribute activeMode : CleaningMode = CleaningMode::fullHome;
    attribute mass : MassValue { unit = kg; default = 4.2 [kg]; }
    attribute diameter : LengthValue { unit = cm; default = 35.0 [cm]; }
    attribute height : LengthValue { unit = cm; default = 9.5 [cm]; }
    attribute maximumSpeed : LinearSpeed = 0.45 [m/s];
    attribute nominalNoise : SoundLevel = 58.0 [dB];
    attribute cleanedAreaThisRun : Area = 0.0 [m^2];

    port userInterface : UserCommandPort;
    port floorIntake : DustPort;
    port exhaust : ExhaustPort;
    port chargingReceiver : PowerPort;

    part battery : BatteryPack;
    part drive : DifferentialDrive;
    part cleaningHead : CleaningSubsystem;
    part navigation : NavigationSubsystem;
    part controller : ControlComputer;
    part bin : DustBin;
    part wireless : WirelessInterface;

    connect chargingReceiver.suppliedPower to battery.chargeInput.suppliedPower;
    connect controller.motionCommand to drive.motionCommand;
    connect navigation.sensorOutput to controller.sensorInput;
    connect cleaningHead.debrisOutput to bin.debrisInput;
    connect floorIntake.collectedDebris to cleaningHead.floorDebrisInput.collectedDebris;
    connect controller.cleaningCommand to cleaningHead.cleaningControl;
    connect controller.userIo to userInterface;
    connect controller.statusIo to wireless.cloudPort;
    connect bin.binStatus to controller.binMonitor;
    connect battery.batteryStatus to controller.powerMonitor;

    perform action CleanHome;
    exhibit state machine RobotOperationalStates;
  }

  part def BatteryPack {
    attribute capacity : BatteryEnergy = 74.0 [W*h];
    attribute stateOfCharge : Percentage = 100.0;
    attribute lowThreshold : Percentage = 15.0;
    attribute criticalThreshold : Percentage = 7.0;
    attribute nominalVoltage : ElectricPotentialValue = 14.4 [V];

    port chargeInput : PowerPort;

    port batteryStatus {
      out attribute stateOfCharge : Percentage;
      out attribute lowBattery : Boolean;
      out attribute criticalBattery : Boolean;
    }

    action ProvidePower {
      in attribute requestedPower : PowerValue;
      out item deliveredPower : ElectricalPower;
    }

    action Recharge {
      in item receivedPower : ElectricalPower;
      out attribute updatedStateOfCharge : Percentage;
    }
  }

  part def DifferentialDrive {
    attribute wheelDiameter : LengthValue = 7.2 [cm];
    attribute trackWidth : LengthValue = 28.0 [cm];
    attribute maximumClimbHeight : LengthValue = 1.8 [cm];

    port motionCommand : MotionCommandPort;

    part leftWheelMotor : WheelMotor;
    part rightWheelMotor : WheelMotor;
    part caster : PassiveCaster;

    action ExecuteMotion {
      in attribute commandedSpeed : LinearSpeed;
      in attribute commandedYawRate : Real { unit = rad/s; }
      out attribute actualSpeed : LinearSpeed;
      out attribute wheelStall : Boolean;
    }
  }

  part def WheelMotor {
    attribute ratedPower : PowerValue = 18.0 [W];
    attribute maximumTorque : TorqueValue = 0.42 [N*m];
  }

  part def PassiveCaster {
    attribute diameter : LengthValue = 3.0 [cm];
  }

  part def CleaningSubsystem {
    attribute suctionPowerQuiet : PowerValue = 18.0 [W];
    attribute suctionPowerNormal : PowerValue = 32.0 [W];
    attribute suctionPowerMax : PowerValue = 55.0 [W];
    attribute brushSpeed : Real { unit = rpm; default = 1200.0; }

    port floorDebrisInput : DustPort;

    port debrisOutput {
      out item collectedDebris : DustAndDebris;
    }

    port cleaningControl {
      in attribute enabled : Boolean;
      in attribute suctionPower : PowerValue;
      in attribute brushEnabled : Boolean;
    }

    part suctionFan : SuctionFan;
    part mainBrush : RollerBrush;
    part sideBrush : SideBrush;
    part filter : ExhaustFilter;

    action CollectDebris {
      in item debrisOnFloor : DustAndDebris;
      out item debrisInBin : DustAndDebris;
    }
  }

  part def SuctionFan {
    attribute maximumAirflow : Real { unit = L/s; default = 18.0; }
    attribute maximumPower : PowerValue = 55.0 [W];
  }

  part def RollerBrush {
    attribute width : LengthValue = 16.0 [cm];
    attribute jamDetected : Boolean = false;
  }

  part def SideBrush {
    attribute armCount : Integer = 3;
    attribute diameter : LengthValue = 12.0 [cm];
  }

  part def ExhaustFilter {
    attribute filtrationEfficiency : Percentage = 99.0;
    attribute particleCaptureSize : LengthValue = 0.3 [um];
  }

  part def DustBin {
    attribute capacity : DustMass = 450.0 [g];
    attribute fillLevel : Percentage = 0.0;
    attribute installed : Boolean = true;

    port debrisInput : DustPort;

    port binStatus {
      out attribute fillLevel : Percentage;
      out attribute full : Boolean;
      out attribute installed : Boolean;
    }

    action StoreDebris {
      in item debris : DustAndDebris;
      out attribute updatedFillLevel : Percentage;
    }

    action EmptyBin {
      out attribute updatedFillLevel : Percentage = 0.0;
    }
  }

  part def NavigationSubsystem {
    attribute localizationConfidence : Percentage = 100.0;
    attribute obstacleClearance : Distance = 0.05 [m];
    attribute plannedCoverageArea : Area;
    attribute currentMap : MapData;

    port sensorOutput : SensorDataPort;

    part lidar : LidarSensor;
    part bumpSensors : BumperSensorArray;
    part cliffSensors : CliffSensorArray;
    part wheelOdometry : WheelOdometry;
    part imu : InertialMeasurementUnit;

    action BuildMap {
      out item map : MapData;
    }

    action PlanCoveragePath {
      in item map : MapData;
      in attribute mode : CleaningMode;
      out item pathPlan;
    }

    action DetectHazards {
      out attribute fault : FaultType;
    }
  }

  part def LidarSensor {
    attribute range : Distance = 8.0 [m];
    attribute angularResolution : Real { unit = deg; default = 1.0; }
    attribute scanRate : Real { unit = Hz; default = 6.0; }
  }

  part def BumperSensorArray {
    attribute sensorCount : Integer = 6;
  }

  part def CliffSensorArray {
    attribute sensorCount : Integer = 4;
    attribute cliffThreshold : Distance = 0.08 [m];
  }

  part def WheelOdometry {
    attribute positionErrorPerMeter : Percentage = 2.0;
  }

  part def InertialMeasurementUnit {
    attribute yawRateNoise : Real { unit = deg/s; default = 0.5; }
  }

  part def ControlComputer {
    attribute processorClock : Real { unit = GHz; default = 1.2; }
    attribute controlLoopRate : Real { unit = Hz; default = 50.0; }
    attribute currentFault : FaultType = FaultType::none;

    port sensorInput : SensorDataPort;
    port motionCommand : MotionCommandPort;

    port cleaningCommand {
      out attribute enabled : Boolean;
      out attribute suctionPower : PowerValue;
      out attribute brushEnabled : Boolean;
    }

    port userIo : UserCommandPort;

    port powerMonitor {
      in attribute stateOfCharge : Percentage;
      in attribute lowBattery : Boolean;
      in attribute criticalBattery : Boolean;
    }

    port binMonitor {
      in attribute fillLevel : Percentage;
      in attribute full : Boolean;
      in attribute installed : Boolean;
    }

    port statusIo {
      out item status : StatusReport;
    }

    action SelectCleaningMode {
      in item command : Command;
      out attribute selectedMode : CleaningMode;
    }

    action CommandCoverageCleaning {
      in attribute selectedMode : CleaningMode;
      out attribute driveSpeed : LinearSpeed;
      out attribute suctionPower : PowerValue;
      out attribute brushEnabled : Boolean;
    }

    action CommandReturnToDock {
      out attribute dockingRequested : Boolean;
    }

    action StopForFault {
      in attribute fault : FaultType;
      out item status : StatusReport;
    }
  }

  part def WirelessInterface {
    attribute wifiStandard : String = "IEEE 802.11n";
    attribute cloudConnected : Boolean = true;

    port cloudPort {
      in item status : StatusReport;
      out item remoteCommand : Command;
    }
  }

  part def DockingStation {
    attribute locationKnownToRobot : Boolean = true;
    attribute maximumChargePower : PowerValue = 42.0 [W];
    attribute autoEmptyAvailable : Boolean = true;

    port charger : ChargePort;

    part chargerElectronics : ChargerElectronics;
    part debrisEvacuationMotor : DebrisEvacuationMotor;

    action ProvideChargingPower {
      out item chargingPower : ElectricalPower;
    }

    action EvacuateRobotBin {
      in item debris : DustAndDebris;
      out attribute binEmptied : Boolean;
    }
  }

  part def ChargerElectronics {
    attribute outputVoltage : ElectricPotentialValue = 19.0 [V];
    attribute maximumOutputCurrent : ElectricCurrentValue = 2.2 [A];
  }

  part def DebrisEvacuationMotor {
    attribute suctionPower : PowerValue = 650.0 [W];
    attribute evacuationDuration : TimeValue = 18.0 [s];
  }

  action def CleanHome {
    in attribute requestedMode : CleaningMode;
    in item initialMap : MapData;
    out attribute cleanedArea : Area;
    out item finalStatus : StatusReport;

    first start;
    then initializeCleaning;
    then buildOrUpdateMap;
    then planCoverage;
    then executeCoveragePattern;
    then monitorEnergyAndBin;
    then returnToDock;
    then reportCompletion;
    then done;

    action initializeCleaning {
      out attribute suctionPower : PowerValue;
      out attribute brushEnabled : Boolean;
    }

    action buildOrUpdateMap {
      out item updatedMap : MapData;
    }

    action planCoverage {
      in item updatedMap : MapData;
      out item coveragePath;
    }

    action executeCoveragePattern {
      in item coveragePath;
      out attribute areaCovered : Area;
      out attribute debrisCollected : DustMass;
    }

    action monitorEnergyAndBin {
      in attribute areaCovered : Area;
      out attribute continueCleaning : Boolean;
      out attribute returnRequired : Boolean;
    }

    action returnToDock {
      in attribute returnRequired : Boolean;
      out attribute docked : Boolean;
    }

    action reportCompletion {
      in attribute docked : Boolean;
      out item status : StatusReport;
    }
  }

  state def RobotOperationalStates {
    entry action InitializeController;

    state Docked;
    state Charging;
    state Ready;
    state Cleaning;
    state ReturningToDock;
    state EmptyingBin;
    state Faulted;

    transition initial then Docked;

    transition Docked_to_Charging
      first Docked
      accept when battery.stateOfCharge < 100.0
      then Charging;

    transition Charging_to_Ready
      first Charging
      accept when battery.stateOfCharge >= 95.0
      then Ready;

    transition Ready_to_Cleaning
      first Ready
      accept item command : Command
      if command.mode == CleaningMode::fullHome or command.mode == CleaningMode::spot or command.mode == CleaningMode::edge
      do action StartCleaning
      then Cleaning;

    transition Cleaning_to_ReturningForLowBattery
      first Cleaning
      accept when battery.stateOfCharge <= battery.lowThreshold
      do action SaveCoverageProgress
      then ReturningToDock;

    transition Cleaning_to_ReturningForFullBin
      first Cleaning
      accept when bin.fillLevel >= 95.0
      do action PauseCleaning
      then ReturningToDock;

    transition Cleaning_to_ReturningWhenComplete
      first Cleaning
      accept when cleanedAreaThisRun >= navigation.plannedCoverageArea
      do action FinishCoverage
      then ReturningToDock;

    transition Cleaning_to_Faulted
      first Cleaning
      accept when controller.currentFault != FaultType::none
      do action StopMotionAndSuction
      then Faulted;

    transition ReturningToDock_to_EmptyingBin
      first ReturningToDock
      accept when bin.fillLevel > 0.0 and DockingStation::autoEmptyAvailable
      then EmptyingBin;

    transition ReturningToDock_to_Charging
      first ReturningToDock
      accept when battery.stateOfCharge < 100.0
      then Charging;

    transition EmptyingBin_to_Charging
      first EmptyingBin
      accept when bin.fillLevel == 0.0
      then Charging;

    transition Faulted_to_Ready
      first Faulted
      accept item resetCommand : Command
      if resetCommand.commandId == "reset_fault"
      do action ClearFault
      then Ready;
  }

  requirement def PrimaryFunctionRequirement {
    doc "The robotic vacuum cleaner shall autonomously remove dust and debris from accessible indoor floor surfaces while navigating around obstacles, avoiding hazards, and returning to its docking station for charging or bin emptying.";
    subject cleaner : RoboticVacuumCleaner;

    require constraint {
      cleaner.cleanedAreaThisRun >= 0.0 [m^2]
    }
  }

  requirement def CoverageRequirement {
    doc "In full-home mode, the cleaner shall attempt systematic coverage of all mapped accessible floor area before reporting cleaning complete.";
    subject cleaner : RoboticVacuumCleaner;

    require constraint {
      cleaner.navigation.currentMap.coveredArea >= 0.95 * cleaner.navigation.plannedCoverageArea
    }
  }

  requirement def BatteryReturnRequirement {
    doc "The cleaner shall stop active cleaning and return to the docking station when the battery state of charge reaches the low threshold.";
    subject cleaner : RoboticVacuumCleaner;

    require constraint {
      cleaner.battery.stateOfCharge <= cleaner.battery.lowThreshold implies cleaner.state == RobotState::returningToDock
    }
  }

  requirement def HazardAvoidanceRequirement {
    doc "The cleaner shall avoid stair edges and stop motion when a cliff hazard is detected.";
    subject cleaner : RoboticVacuumCleaner;

    require constraint {
      cleaner.navigation.cliffSensors.cliffThreshold == 0.08 [m]
    }
  }

  requirement def DebrisStorageRequirement {
    doc "The cleaner shall store collected debris in an onboard bin and report when the bin is nearly full or missing.";
    subject cleaner : RoboticVacuumCleaner;

    require constraint {
      cleaner.bin.capacity >= 400.0 [g]
    }
  }

  requirement def NoiseRequirement {
    doc "During normal cleaning mode, emitted sound level shall not exceed 65 dB at one meter.";
    subject cleaner : RoboticVacuumCleaner;

    require constraint {
      cleaner.nominalNoise <= 65.0 [dB]
    }
  }

  part roboticVacuumSystem {
    part robot : RoboticVacuumCleaner;
    part dock : DockingStation;

    connect dock.charger.chargingPower to robot.chargingReceiver.suppliedPower;

    attribute primaryFunction : String =
      "Autonomously clean indoor floors by sensing the environment, planning coverage paths, collecting debris, monitoring energy and bin capacity, avoiding hazards, and returning to the dock when cleaning is complete or service is required.";
  }

  satisfy PrimaryFunctionRequirement by roboticVacuumSystem.robot;
  satisfy CoverageRequirement by roboticVacuumSystem.robot;
  satisfy BatteryReturnRequirement by roboticVacuumSystem.robot;
  satisfy HazardAvoidanceRequirement by roboticVacuumSystem.robot;
  satisfy DebrisStorageRequirement by roboticVacuumSystem.robot;
  satisfy NoiseRequirement by roboticVacuumSystem.robot;
}