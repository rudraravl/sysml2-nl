package AutomatedPoolCleanerSystem {

  import ScalarValues::*;
  import SI::*;

  value type Length :> Real {
    unit = "m";
  }

  value type Area :> Real {
    unit = "m^2";
  }

  value type Volume :> Real {
    unit = "L";
  }

  value type FlowRate :> Real {
    unit = "L/min";
  }

  value type Pressure :> Real {
    unit = "kPa";
  }

  value type ElectricPotential :> Real {
    unit = "V";
  }

  value type ElectricCurrent :> Real {
    unit = "A";
  }

  value type Power :> Real {
    unit = "W";
  }

  value type Energy :> Real {
    unit = "Wh";
  }

  value type TimeDuration :> Real {
    unit = "min";
  }

  value type Speed :> Real {
    unit = "m/s";
  }

  value type Mass :> Real {
    unit = "kg";
  }

  value type Percent :> Real {
    unit = "%";
  }

  value type Turbidity :> Real {
    unit = "NTU";
  }

  value type Temperature :> Real {
    unit = "degC";
  }

  item def ElectricalPower {
    attribute voltage : ElectricPotential;
    attribute current : ElectricCurrent;
    attribute availablePower : Power;
  }

  item def WaterFlow {
    attribute flowRate : FlowRate;
    attribute pressure : Pressure;
    attribute debrisConcentration : Percent;
    attribute turbidity : Turbidity;
  }

  item def Debris {
    attribute debrisMass : Mass;
    attribute debrisVolume : Volume;
    attribute particleSize : Length;
  }

  item def Command {
    attribute startRequested : Boolean;
    attribute stopRequested : Boolean;
    attribute selectedMode : CleaningMode;
    attribute scheduledRunTime : TimeDuration;
  }

  item def Status {
    attribute stateName : String;
    attribute batteryCharge : Percent;
    attribute binFillLevel : Percent;
    attribute faultPresent : Boolean;
    attribute coveredArea : Area;
  }

  enum def CleaningMode {
    enum manual;
    enum automatic;
    enum wallOnly;
    enum floorOnly;
    enum waterline;
    enum quickClean;
  }

  enum def FaultCode {
    enum none;
    enum lowBattery;
    enum cloggedFilter;
    enum pumpOverload;
    enum motorStall;
    enum navigationFault;
    enum waterIngress;
    enum outOfWater;
  }

  port def ElectricalPort {
    in item powerIn : ElectricalPower;
  }

  port def WaterInletPort {
    in item incomingWater : WaterFlow;
    out item capturedDebris : Debris;
  }

  port def WaterOutletPort {
    out item filteredWater : WaterFlow;
  }

  port def CommandPort {
    in item command : Command;
  }

  port def StatusPort {
    out item status : Status;
  }

  port def DrivePort {
    out item tractionCommand : DriveCommand;
  }

  item def DriveCommand {
    attribute leftTrackSpeed : Speed;
    attribute rightTrackSpeed : Speed;
    attribute brushSpeed : Speed;
  }

  part def AutomatedPoolCleaner {
    attribute ratedVoltage : ElectricPotential = 24.0;
    attribute maxPowerDraw : Power = 180.0;
    attribute nominalFlowRate : FlowRate = 70.0;
    attribute maximumPoolArea : Area = 120.0;
    attribute debrisBinCapacity : Volume = 4.0;
    attribute minimumOperatingDepth : Length = 0.35;
    attribute maximumOperatingDepth : Length = 3.0;
    attribute targetCoverage : Percent = 95.0;

    port powerPort : ElectricalPort;
    port inlet : WaterInletPort;
    port outlet : WaterOutletPort;
    port commandPort : CommandPort;
    port statusPort : StatusPort;

    part battery : BatteryModule;
    part controller : ControlUnit;
    part navigation : NavigationSensorSuite;
    part pump : SuctionPump;
    part filter : DebrisFilter;
    part drive : DriveSystem;
    part brushes : BrushAssembly;
    part housing : WaterproofHousing;
    part diagnostics : DiagnosticMonitor;

    connect powerPort.powerIn to battery.externalPower;
    connect battery.powerOutput to controller.powerInput;
    connect battery.powerOutput to pump.powerInput;
    connect battery.powerOutput to drive.powerInput;
    connect battery.powerOutput to brushes.powerInput;

    connect commandPort.command to controller.operatorCommand;
    connect controller.driveCommand to drive.driveCommandInput;
    connect controller.pumpCommand to pump.pumpCommandInput;
    connect controller.brushCommand to brushes.brushCommandInput;

    connect navigation.navigationData to controller.navigationInput;
    connect diagnostics.diagnosticStatus to controller.diagnosticInput;
    connect controller.cleanerStatus to statusPort.status;

    connect inlet.incomingWater to pump.waterInput;
    connect pump.pressurizedWaterOutput to filter.unfilteredWaterInput;
    connect filter.filteredWaterOutput to outlet.filteredWater;
    connect filter.removedDebris to inlet.capturedDebris;

    perform action cleanPool;
    exhibit state cleanerOperatingStates;
  }

  part def BatteryModule {
    attribute capacity : Energy = 500.0;
    attribute chargeLevel : Percent = 100.0;
    attribute outputVoltage : ElectricPotential = 24.0;
    attribute maximumCurrent : ElectricCurrent = 12.0;

    in item externalPower : ElectricalPower;
    out item powerOutput : ElectricalPower;
  }

  part def ControlUnit {
    attribute processorLoad : Percent;
    attribute plannedCoverage : Percent;
    attribute activeMode : CleaningMode;
    attribute currentFault : FaultCode = FaultCode::none;

    in item powerInput : ElectricalPower;
    in item operatorCommand : Command;
    in item navigationInput : NavigationData;
    in item diagnosticInput : DiagnosticData;

    out item driveCommand : DriveCommand;
    out item pumpCommand : PumpCommand;
    out item brushCommand : BrushCommand;
    out item cleanerStatus : Status;
  }

  item def PumpCommand {
    attribute enabled : Boolean;
    attribute requestedFlowRate : FlowRate;
  }

  item def BrushCommand {
    attribute enabled : Boolean;
    attribute brushSpeed : Speed;
  }

  item def NavigationData {
    attribute positionX : Length;
    attribute positionY : Length;
    attribute depth : Length;
    attribute obstacleDetected : Boolean;
    attribute wallDetected : Boolean;
    attribute slopeAngle : Real;
    attribute estimatedCoveredArea : Area;
  }

  item def DiagnosticData {
    attribute batteryCharge : Percent;
    attribute motorCurrent : ElectricCurrent;
    attribute pumpPressure : Pressure;
    attribute filterFillLevel : Percent;
    attribute internalTemperature : Temperature;
    attribute detectedFault : FaultCode;
  }

  part def NavigationSensorSuite {
    attribute sonarRange : Length = 2.5;
    attribute imuUpdateRate : Real = 100.0;
    attribute coverageMapResolution : Length = 0.25;

    out item navigationData : NavigationData;

    part sonar : SonarSensor;
    part imu : InertialMeasurementUnit;
    part depthSensor : DepthSensor;
    part contactSwitches : ContactSwitchArray;
  }

  part def SonarSensor {
    attribute maximumRange : Length = 2.5;
    attribute minimumRange : Length = 0.05;
  }

  part def InertialMeasurementUnit {
    attribute accelerationRange : Real = 16.0;
    attribute angularRateRange : Real = 2000.0;
  }

  part def DepthSensor {
    attribute maximumDepth : Length = 3.5;
    attribute accuracy : Length = 0.02;
  }

  part def ContactSwitchArray {
    attribute switchCount : Integer = 6;
  }

  part def SuctionPump {
    attribute ratedPower : Power = 90.0;
    attribute maximumFlowRate : FlowRate = 85.0;
    attribute maximumPressure : Pressure = 45.0;

    in item powerInput : ElectricalPower;
    in item pumpCommandInput : PumpCommand;
    in item waterInput : WaterFlow;
    out item pressurizedWaterOutput : WaterFlow;
  }

  part def DebrisFilter {
    attribute meshOpening : Length = 0.0002;
    attribute capacity : Volume = 4.0;
    attribute fillLevel : Percent = 0.0;
    attribute captureEfficiency : Percent = 98.0;

    in item unfilteredWaterInput : WaterFlow;
    out item filteredWaterOutput : WaterFlow;
    out item removedDebris : Debris;
  }

  part def DriveSystem {
    attribute maximumSpeed : Speed = 0.18;
    attribute climbingCapability : Real = 35.0;
    attribute trackWidth : Length = 0.28;

    in item powerInput : ElectricalPower;
    in item driveCommandInput : DriveCommand;

    part leftTrack : TractionTrack;
    part rightTrack : TractionTrack;
    part driveMotors : DriveMotor[2];
  }

  part def TractionTrack {
    attribute contactLength : Length = 0.22;
    attribute treadHeight : Length = 0.008;
  }

  part def DriveMotor {
    attribute ratedPower : Power = 35.0;
    attribute stallCurrent : ElectricCurrent = 8.0;
  }

  part def BrushAssembly {
    attribute brushWidth : Length = 0.32;
    attribute nominalBrushSpeed : Speed = 1.2;

    in item powerInput : ElectricalPower;
    in item brushCommandInput : BrushCommand;

    part frontBrush : RotatingBrush;
    part rearBrush : RotatingBrush;
  }

  part def RotatingBrush {
    attribute diameter : Length = 0.06;
    attribute bristleLength : Length = 0.018;
  }

  part def WaterproofHousing {
    attribute dryMass : Mass = 8.5;
    attribute ingressProtectionRating : String = "IP68";
    attribute length : Length = 0.46;
    attribute width : Length = 0.39;
    attribute height : Length = 0.24;
  }

  part def DiagnosticMonitor {
    attribute samplePeriod : TimeDuration = 0.1;

    out item diagnosticStatus : DiagnosticData;
  }

  action def CleanPool {
    in item selectedMode : CleaningMode;
    in item poolArea : Area;
    out item completedCoverage : Percent;
    out item collectedDebris : Debris;

    first startPump;
    then startBrushes;
    then initializeCoverageMap;
    then executeCoveragePattern;
    then inspectWaterline;
    then returnToRetrievalPoint;
    then shutdownCleaning;

    action startPump {
      out item command : PumpCommand;
    }

    action startBrushes {
      out item command : BrushCommand;
    }

    action initializeCoverageMap {
      in item poolArea : Area;
      out item plannedRoute : NavigationData;
    }

    action executeCoveragePattern {
      in item plannedRoute : NavigationData;
      out item coveredArea : Area;
      out item debris : Debris;
    }

    action inspectWaterline {
      out item wallCoverage : Percent;
    }

    action returnToRetrievalPoint {
      out item finalPosition : NavigationData;
    }

    action shutdownCleaning {
      out item finalStatus : Status;
    }
  }

  action cleanPool : CleanPool {
    in selectedMode = CleaningMode::automatic;
    in poolArea = 80.0;
  }

  state def CleanerOperatingStates {
    entry action initializeSystem;

    state Off;
    state Charging;
    state Ready;
    state Cleaning;
    state Navigating;
    state Filtering;
    state Returning;
    state Completed;
    state Faulted;

    transition first Off;

    transition Off_to_Charging
      first Off
      then Charging
      accept Command
      if command.startRequested == false;

    transition Charging_to_Ready
      first Charging
      then Ready
      if battery.chargeLevel >= 95.0;

    transition Ready_to_Cleaning
      first Ready
      then Cleaning
      accept Command
      if command.startRequested == true;

    transition Cleaning_to_Navigating
      first Cleaning
      then Navigating;

    transition Navigating_to_Filtering
      first Navigating
      then Filtering
      if pump.nominalFlowRate > 0.0;

    transition Filtering_to_Navigating
      first Filtering
      then Navigating
      if controller.plannedCoverage < 95.0;

    transition Navigating_to_Returning
      first Navigating
      then Returning
      if controller.plannedCoverage >= 95.0;

    transition Returning_to_Completed
      first Returning
      then Completed;

    transition Completed_to_Ready
      first Completed
      then Ready;

    transition Cleaning_to_Faulted
      first Cleaning
      then Faulted
      if controller.currentFault != FaultCode::none;

    transition Navigating_to_Faulted
      first Navigating
      then Faulted
      if controller.currentFault != FaultCode::none;

    transition Filtering_to_Faulted
      first Filtering
      then Faulted
      if controller.currentFault != FaultCode::none;

    transition Faulted_to_Ready
      first Faulted
      then Ready
      accept Command
      if command.stopRequested == true;

    entry action initializeSystem {
      out item status : Status;
    }
  }

  requirement def PrimaryFunctionRequirement {
    subject cleaner : AutomatedPoolCleaner;

    doc /* The automated pool cleaner shall autonomously move through a swimming pool, loosen debris from pool surfaces, draw water and debris through an onboard suction and filtration path, retain collected debris, discharge filtered water back to the pool, and report operating status with minimal operator intervention. */

    require constraint {
      cleaner.nominalFlowRate >= 60.0 and
      cleaner.targetCoverage >= 90.0 and
      cleaner.maximumPoolArea >= 80.0
    }
  }

  requirement def CoverageRequirement {
    subject cleaner : AutomatedPoolCleaner;

    doc /* In automatic mode, the cleaner shall cover at least 95 percent of the configured pool floor and reachable wall surfaces during a scheduled cleaning cycle. */

    require constraint {
      cleaner.targetCoverage >= 95.0
    }
  }

  requirement def FiltrationRequirement {
    subject cleaner : AutomatedPoolCleaner;

    doc /* The cleaner shall remove suspended and settled debris by maintaining suction flow through the debris filter while its pump and brushes are enabled. */

    require constraint {
      cleaner.filter.captureEfficiency >= 95.0 and
      cleaner.pump.maximumFlowRate >= cleaner.nominalFlowRate
    }
  }

  requirement def MobilityRequirement {
    subject cleaner : AutomatedPoolCleaner;

    doc /* The cleaner shall propel itself across the pool floor, climb typical pool wall slopes, avoid obstacles, and return to a retrieval location after completing the cleaning cycle. */

    require constraint {
      cleaner.drive.maximumSpeed >= 0.10 and
      cleaner.drive.climbingCapability >= 30.0
    }
  }

  requirement def PowerRequirement {
    subject cleaner : AutomatedPoolCleaner;

    doc /* The onboard power system shall provide sufficient electrical energy for a complete automatic cleaning cycle without exceeding rated power limits. */

    require constraint {
      cleaner.battery.capacity >= 400.0 and
      cleaner.maxPowerDraw <= 200.0
    }
  }

  requirement def SafetyRequirement {
    subject cleaner : AutomatedPoolCleaner;

    doc /* The cleaner shall detect low battery, clogged filter, motor stall, pump overload, water ingress, and out-of-water conditions and transition to a faulted or safe shutdown state. */

    require constraint {
      cleaner.diagnostics.samplePeriod <= 0.5
    }
  }

  requirement def WaterproofRequirement {
    subject cleaner : AutomatedPoolCleaner;

    doc /* The cleaner housing shall prevent harmful water ingress at operating depths up to three meters. */

    require constraint {
      cleaner.maximumOperatingDepth <= 3.0 and
      cleaner.housing.ingressProtectionRating == "IP68"
    }
  }

  satisfy PrimaryFunctionRequirement by AutomatedPoolCleaner;
  satisfy CoverageRequirement by AutomatedPoolCleaner;
  satisfy FiltrationRequirement by AutomatedPoolCleaner;
  satisfy MobilityRequirement by AutomatedPoolCleaner;
  satisfy PowerRequirement by AutomatedPoolCleaner;
  satisfy SafetyRequirement by AutomatedPoolCleaner;
  satisfy WaterproofRequirement by AutomatedPoolCleaner;

}