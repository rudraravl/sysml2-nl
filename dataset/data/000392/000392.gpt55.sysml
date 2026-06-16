package BushRobotPrimaryTaskSystem {

  import ScalarValues::*;
  import SI::*;
  import ISQ::*;

  value type Length specializes ISQ::length {
    unit = SI::metre;
  }

  value type Area specializes ISQ::area {
    unit = SI::squareMetre;
  }

  value type Mass specializes ISQ::mass {
    unit = SI::kilogram;
  }

  value type Time specializes ISQ::time {
    unit = SI::second;
  }

  value type Velocity specializes ISQ::speed {
    unit = SI::metrePerSecond;
  }

  value type Acceleration specializes ISQ::acceleration {
    unit = SI::metrePerSecondSquared;
  }

  value type ElectricPotential specializes ISQ::electricPotential {
    unit = SI::volt;
  }

  value type ElectricCurrent specializes ISQ::electricCurrent {
    unit = SI::ampere;
  }

  value type ElectricCharge specializes ISQ::electricCharge {
    unit = SI::ampereHour;
  }

  value type Power specializes ISQ::power {
    unit = SI::watt;
  }

  value type Energy specializes ISQ::energy {
    unit = SI::joule;
  }

  value type Temperature specializes ISQ::thermodynamicTemperature {
    unit = SI::degreeCelsius;
  }

  value type Angle specializes ISQ::planeAngle {
    unit = SI::degree;
  }

  value type Frequency specializes ISQ::frequency {
    unit = SI::hertz;
  }

  value type Force specializes ISQ::force {
    unit = SI::newton;
  }

  value type Torque specializes ISQ::torque {
    unit = SI::newtonMetre;
  }

  value type Percent specializes Real {
    unit = one;
  }

  value type BooleanFlag specializes Boolean;

  enum def MissionPhase {
    enum idle;
    enum selfCheck;
    enum navigatingToWorksite;
    enum surveying;
    enum bushClearing;
    enum collectingBiomass;
    enum returningToBase;
    enum docking;
    enum faulted;
    enum emergencyStop;
    enum complete;
  }

  enum def TerrainClass {
    enum paved;
    enum grass;
    enum lowBrush;
    enum denseBush;
    enum mud;
    enum gravel;
    enum slope;
    enum unknown;
  }

  enum def ObstacleClass {
    enum none;
    enum human;
    enum animal;
    enum tree;
    enum rock;
    enum fence;
    enum water;
    enum vehicle;
    enum unknown;
  }

  enum def ToolMode {
    enum stowed;
    enum armed;
    enum trimming;
    enum mulching;
    enum jamClearing;
    enum disabled;
  }

  enum def HealthStatus {
    enum nominal;
    enum degraded;
    enum warning;
    enum critical;
    enum failed;
  }

  item def GeoPoint {
    attribute latitude : Real;
    attribute longitude : Real;
    attribute altitude : Length;
  }

  item def Pose3D {
    attribute position : GeoPoint;
    attribute yaw : Angle;
    attribute pitch : Angle;
    attribute roll : Angle;
  }

  item def VelocityCommand {
    attribute linearSpeed : Velocity;
    attribute angularRate : Frequency;
    attribute maxAcceleration : Acceleration;
  }

  item def ToolCommand {
    attribute mode : ToolMode;
    attribute cutterSpeed : Frequency;
    attribute feedForceLimit : Force;
    attribute cuttingHeight : Length;
  }

  item def PowerPacket {
    attribute voltage : ElectricPotential;
    attribute current : ElectricCurrent;
    attribute availablePower : Power;
  }

  item def BatteryState {
    attribute stateOfCharge : Percent;
    attribute voltage : ElectricPotential;
    attribute current : ElectricCurrent;
    attribute temperature : Temperature;
    attribute estimatedRemainingEnergy : Energy;
    attribute health : HealthStatus;
  }

  item def TerrainObservation {
    attribute terrain : TerrainClass;
    attribute obstacle : ObstacleClass;
    attribute confidence : Percent;
    attribute clearanceAhead : Length;
    attribute slopeAngle : Angle;
    attribute vegetationHeight : Length;
    attribute vegetationDensity : Percent;
  }

  item def CutMaterial {
    attribute estimatedMass : Mass;
    attribute moistureContent : Percent;
    attribute fragmentLength : Length;
  }

  item def MissionPlan {
    attribute workArea : Area;
    attribute startPoint : GeoPoint;
    attribute boundaryNorthEast : GeoPoint;
    attribute boundarySouthWest : GeoPoint;
    attribute targetCutHeight : Length;
    attribute maxAllowedSpeed : Velocity;
    attribute requiredCoverage : Percent;
    attribute returnPoint : GeoPoint;
  }

  item def MissionReport {
    attribute completedArea : Area;
    attribute clearedBiomass : Mass;
    attribute coverageAchieved : Percent;
    attribute elapsedTime : Time;
    attribute energyUsed : Energy;
    attribute finalHealth : HealthStatus;
    attribute success : BooleanFlag;
  }

  item def SafetyEvent {
    attribute obstacle : ObstacleClass;
    attribute distance : Length;
    attribute robotSpeed : Velocity;
    attribute emergencyStopRequired : BooleanFlag;
  }

  item def DiagnosticPacket {
    attribute status : HealthStatus;
    attribute faultCode : String;
    attribute message : String;
    attribute timestamp : Time;
  }

  port def PowerPort {
    inout item power : PowerPacket;
  }

  port def CommandPort {
    in item velocityCommand : VelocityCommand;
    in item toolCommand : ToolCommand;
  }

  port def MissionPort {
    in item missionPlan : MissionPlan;
    out item missionReport : MissionReport;
  }

  port def NavigationDataPort {
    out item pose : Pose3D;
    out item terrainObservation : TerrainObservation;
  }

  port def SensorDataPort {
    out item observation : TerrainObservation;
    out item pose : Pose3D;
  }

  port def SafetyPort {
    out item safetyEvent : SafetyEvent;
    in item emergencyStopSignal : BooleanFlag;
  }

  port def DiagnosticPort {
    out item diagnostic : DiagnosticPacket;
  }

  port def MaterialPort {
    out item cutMaterial : CutMaterial;
  }

  port def MechanicalDrivePort {
    in item velocityCommand : VelocityCommand;
    out item pose : Pose3D;
  }

  port def ToolInterfacePort {
    in item toolCommand : ToolCommand;
    out item cutMaterial : CutMaterial;
  }

  part def LithiumBatteryPack {
    attribute nominalVoltage : ElectricPotential = 48 [SI::volt];
    attribute capacity : ElectricCharge = 80 [SI::ampereHour];
    attribute maxContinuousPower : Power = 3000 [SI::watt];
    attribute maxTemperature : Temperature = 60 [SI::degreeCelsius];
    attribute minStateOfChargeForReturn : Percent = 20;
    attribute state : BatteryState;

    port powerOut : PowerPort;
    port diagnostics : DiagnosticPort;

    requirement batteryCapacityRequirement {
      doc "The battery shall provide sufficient energy for at least two hours of bush clearing operation."
      require constraint { capacity >= 80 [SI::ampereHour] }
    }

    state def BatteryStateMachine {
      state initial;
      state supplying;
      state lowCharge;
      state overheated;
      state isolated;

      transition first initial then supplying;
      transition supplying_to_lowCharge first supplying
        if state.stateOfCharge <= minStateOfChargeForReturn
        then lowCharge;
      transition supplying_to_overheated first supplying
        if state.temperature >= maxTemperature
        then overheated;
      transition lowCharge_to_isolated first lowCharge
        if state.stateOfCharge <= 5
        then isolated;
      transition overheated_to_isolated first overheated
        if state.temperature >= 70 [SI::degreeCelsius]
        then isolated;
    }
  }

  part def RuggedMobilityBase {
    attribute mass : Mass = 85 [SI::kilogram];
    attribute trackWidth : Length = 0.72 [SI::metre];
    attribute groundClearance : Length = 0.18 [SI::metre];
    attribute maxForwardSpeed : Velocity = 1.4 [SI::metrePerSecond];
    attribute maxSlope : Angle = 25 [SI::degree];
    attribute maxTractiveForce : Force = 1600 [SI::newton];

    port powerIn : PowerPort;
    port commandIn : MechanicalDrivePort;
    port diagnostics : DiagnosticPort;

    action def ExecuteMotion {
      in item command : VelocityCommand;
      in item terrain : TerrainObservation;
      out item poseEstimate : Pose3D;

      constraint speedLimit {
        command.linearSpeed <= maxForwardSpeed
      }

      constraint slopeLimit {
        terrain.slopeAngle <= maxSlope
      }
    }
  }

  part def NavigationController {
    attribute nominalLocalizationAccuracy : Length = 0.05 [SI::metre];
    attribute pathUpdateRate : Frequency = 10 [SI::hertz];
    attribute obstacleStopDistance : Length = 1.2 [SI::metre];
    attribute coverageTarget : Percent = 98;

    port missionIn : MissionPort;
    port sensorIn : SensorDataPort;
    port driveCommandOut : CommandPort;
    port navigationOut : NavigationDataPort;
    port safetyOut : SafetyPort;
    port diagnostics : DiagnosticPort;

    action def PlanCoveragePath {
      in item mission : MissionPlan;
      in item observation : TerrainObservation;
      out item command : VelocityCommand;

      constraint respectMissionSpeed {
        command.linearSpeed <= mission.maxAllowedSpeed
      }

      constraint stopForHuman {
        if observation.obstacle == ObstacleClass::human then command.linearSpeed == 0 [SI::metrePerSecond]
      }
    }

    action def UpdateCoverageMap {
      in item pose : Pose3D;
      in item observation : TerrainObservation;
      out item report : MissionReport;
    }

    state def NavigationStateMachine {
      state initial;
      state awaitingMission;
      state planning;
      state followingPath;
      state replanning;
      state returning;
      state stoppedForObstacle;
      state complete;

      transition first initial then awaitingMission;
      transition awaitingMission_to_planning first awaitingMission accept missionIn.missionPlan then planning;
      transition planning_to_following first planning then followingPath;
      transition following_to_replanning first followingPath if sensorIn.observation.obstacle != ObstacleClass::none then replanning;
      transition replanning_to_following first replanning if sensorIn.observation.clearanceAhead > obstacleStopDistance then followingPath;
      transition following_to_stopped first followingPath if sensorIn.observation.obstacle == ObstacleClass::human then stoppedForObstacle;
      transition stopped_to_following first stoppedForObstacle if sensorIn.observation.obstacle == ObstacleClass::none then followingPath;
      transition following_to_returning first followingPath if missionIn.missionPlan.requiredCoverage <= coverageTarget then returning;
      transition returning_to_complete first returning then complete;
    }
  }

  part def PerceptionSensorSuite {
    attribute lidarRange : Length = 30 [SI::metre];
    attribute stereoCameraRange : Length = 12 [SI::metre];
    attribute thermalCameraRange : Length = 20 [SI::metre];
    attribute imuUpdateRate : Frequency = 100 [SI::hertz];
    attribute gnssAccuracyOpenSky : Length = 0.03 [SI::metre];
    attribute minimumDetectableObstacleHeight : Length = 0.10 [SI::metre];

    port powerIn : PowerPort;
    port sensorOut : SensorDataPort;
    port diagnostics : DiagnosticPort;

    action def ClassifyTerrain {
      out item observation : TerrainObservation;

      constraint detectBush {
        observation.vegetationHeight >= 0 [SI::metre]
      }

      constraint confidenceBound {
        observation.confidence >= 0 and observation.confidence <= 100
      }
    }

    action def DetectObstacle {
      out item safetyEvent : SafetyEvent;

      constraint humanStopTrigger {
        if safetyEvent.obstacle == ObstacleClass::human then safetyEvent.emergencyStopRequired == true
      }
    }
  }

  part def BushClearingTool {
    attribute cuttingWidth : Length = 0.65 [SI::metre];
    attribute adjustableCutHeightMin : Length = 0.03 [SI::metre];
    attribute adjustableCutHeightMax : Length = 0.35 [SI::metre];
    attribute cutterRatedPower : Power = 1200 [SI::watt];
    attribute maxCutterSpeed : Frequency = 70 [SI::hertz];
    attribute maxFeedForce : Force = 450 [SI::newton];
    attribute jamTorqueThreshold : Torque = 85 [SI::newtonMetre];
    attribute mode : ToolMode = ToolMode::stowed;

    port powerIn : PowerPort;
    port toolCommandIn : ToolInterfacePort;
    port materialOut : MaterialPort;
    port diagnostics : DiagnosticPort;

    action def TrimBushVegetation {
      in item command : ToolCommand;
      in item observation : TerrainObservation;
      out item material : CutMaterial;

      constraint commandedHeightRange {
        command.cuttingHeight >= adjustableCutHeightMin and
        command.cuttingHeight <= adjustableCutHeightMax
      }

      constraint cutterSpeedRange {
        command.cutterSpeed <= maxCutterSpeed
      }

      constraint vegetationApplicability {
        observation.terrain == TerrainClass::lowBrush or observation.terrain == TerrainClass::denseBush
      }
    }

    action def ClearToolJam {
      out item diagnostic : DiagnosticPacket;
    }

    state def ToolStateMachine {
      state initial;
      state stowed;
      state armed;
      state trimming;
      state jammed;
      state disabled;

      transition first initial then stowed;
      transition stowed_to_armed first stowed accept toolCommandIn.toolCommand if toolCommandIn.toolCommand.mode == ToolMode::armed then armed;
      transition armed_to_trimming first armed accept toolCommandIn.toolCommand if toolCommandIn.toolCommand.mode == ToolMode::trimming then trimming;
      transition trimming_to_armed first trimming accept toolCommandIn.toolCommand if toolCommandIn.toolCommand.mode == ToolMode::armed then armed;
      transition trimming_to_jammed first trimming if toolCommandIn.toolCommand.feedForceLimit >= maxFeedForce then jammed;
      transition jammed_to_armed first jammed accept toolCommandIn.toolCommand if toolCommandIn.toolCommand.mode == ToolMode::jamClearing then armed;
      transition armed_to_disabled first armed accept toolCommandIn.toolCommand if toolCommandIn.toolCommand.mode == ToolMode::disabled then disabled;
      transition trimming_to_disabled first trimming accept toolCommandIn.toolCommand if toolCommandIn.toolCommand.mode == ToolMode::disabled then disabled;
    }
  }

  part def BiomassCollectionBin {
    attribute capacityMass : Mass = 18 [SI::kilogram];
    attribute capacityVolumeEquivalentArea : Area = 120 [SI::squareMetre];
    attribute currentMass : Mass = 0 [SI::kilogram];
    attribute fullThreshold : Percent = 90;

    port materialIn : MaterialPort;
    port diagnostics : DiagnosticPort;

    action def CollectCutMaterial {
      in item material : CutMaterial;

      constraint capacityNotExceeded {
        currentMass + material.estimatedMass <= capacityMass
      }
    }

    state def BinStateMachine {
      state initial;
      state available;
      state nearlyFull;
      state full;

      transition first initial then available;
      transition available_to_nearlyFull first available if currentMass >= capacityMass * 0.90 then nearlyFull;
      transition nearlyFull_to_full first nearlyFull if currentMass >= capacityMass then full;
      transition full_to_available first full if currentMass == 0 [SI::kilogram] then available;
    }
  }

  part def SafetyController {
    attribute emergencyStopLatency : Time = 0.10 [SI::second];
    attribute protectiveStopDistance : Length = 1.2 [SI::metre];
    attribute restartDelay : Time = 2 [SI::second];
    attribute maximumSafeSpeedNearHuman : Velocity = 0 [SI::metrePerSecond];

    port sensorSafetyIn : SafetyPort;
    port commandOut : CommandPort;
    port diagnostics : DiagnosticPort;

    action def EvaluateSafety {
      in item event : SafetyEvent;
      out item stopSignal : BooleanFlag;

      constraint stopOnHuman {
        if event.obstacle == ObstacleClass::human and event.distance <= protectiveStopDistance
        then stopSignal == true
      }

      constraint stopLatency {
        emergencyStopLatency <= 0.10 [SI::second]
      }
    }

    state def SafetyStateMachine {
      state initial;
      state monitoring;
      state protectiveStop;
      state emergencyStopped;
      state restartInterlock;

      transition first initial then monitoring;
      transition monitoring_to_protectiveStop first monitoring if sensorSafetyIn.safetyEvent.distance <= protectiveStopDistance then protectiveStop;
      transition protectiveStop_to_emergency first protectiveStop if sensorSafetyIn.safetyEvent.emergencyStopRequired == true then emergencyStopped;
      transition protectiveStop_to_restart first protectiveStop if sensorSafetyIn.safetyEvent.obstacle == ObstacleClass::none then restartInterlock;
      transition restart_to_monitoring first restartInterlock after restartDelay then monitoring;
    }
  }

  part def MissionSupervisor {
    attribute missionTimeout : Time = 7200 [SI::second];
    attribute minimumCoverage : Percent = 98;
    attribute minimumBatteryForDispatch : Percent = 85;
    attribute maximumOperatingTemperature : Temperature = 50 [SI::degreeCelsius];

    port missionPort : MissionPort;
    port navCommandOut : CommandPort;
    port toolCommandOut : CommandPort;
    port diagnostics : DiagnosticPort;

    action def StartMission {
      in item mission : MissionPlan;
      in item batteryState : BatteryState;
      out item initialToolCommand : ToolCommand;

      constraint batteryDispatch {
        batteryState.stateOfCharge >= minimumBatteryForDispatch
      }

      constraint primaryToolMode {
        initialToolCommand.mode == ToolMode::armed
      }
    }

    action def GenerateMissionReport {
      in item completedArea : Area;
      in item biomass : Mass;
      in item elapsed : Time;
      out item report : MissionReport;

      constraint successCoverage {
        report.coverageAchieved >= minimumCoverage
      }
    }

    state def MissionStateMachine {
      state initial;
      state idle;
      state selfCheck;
      state dispatchingBushRobot;
      state clearingBush;
      state returnRequested;
      state docking;
      state reporting;
      state complete;
      state faulted;

      transition first initial then idle;
      transition idle_to_selfCheck first idle accept missionPort.missionPlan then selfCheck;
      transition selfCheck_to_dispatch first selfCheck then dispatchingBushRobot;
      transition dispatch_to_clearing first dispatchingBushRobot then clearingBush;
      transition clearing_to_return first clearingBush if missionPort.missionReport.coverageAchieved >= minimumCoverage then returnRequested;
      transition clearing_to_faulted first clearingBush if missionPort.missionReport.finalHealth == HealthStatus::critical then faulted;
      transition return_to_docking first returnRequested then docking;
      transition docking_to_reporting first docking then reporting;
      transition reporting_to_complete first reporting then complete;
    }
  }

  part def DockingStation {
    attribute chargerVoltage : ElectricPotential = 48 [SI::volt];
    attribute chargerPower : Power = 1500 [SI::watt];
    attribute dockingTolerance : Length = 0.08 [SI::metre];
    attribute rechargeTimeFromTwentyPercent : Time = 9000 [SI::second];

    port powerOut : PowerPort;
    port missionPort : MissionPort;
    port diagnostics : DiagnosticPort;

    action def RechargeBattery {
      inout item batteryState : BatteryState;

      constraint chargingVoltage {
        batteryState.voltage <= chargerVoltage
      }
    }
  }

  part def BushRobot {
    attribute robotName : String = "BushBot-BR01";
    attribute totalMass : Mass = 142 [SI::kilogram];
    attribute length : Length = 1.25 [SI::metre];
    attribute width : Length = 0.82 [SI::metre];
    attribute height : Length = 0.88 [SI::metre];
    attribute ratedOperatingTime : Time = 7200 [SI::second];
    attribute maximumPrimaryTaskAreaPerCharge : Area = 2500 [SI::squareMetre];
    attribute nominalClearingRate : Area = 0.42 [SI::squareMetre];
    attribute missionPhase : MissionPhase = MissionPhase::idle;

    port missionInterface : MissionPort;
    port diagnostics : DiagnosticPort;

    part battery : LithiumBatteryPack;
    part mobilityBase : RuggedMobilityBase;
    part perception : PerceptionSensorSuite;
    part navigation : NavigationController;
    part clearingTool : BushClearingTool;
    part collectionBin : BiomassCollectionBin;
    part safetyController : SafetyController;
    part supervisor : MissionSupervisor;

    connect battery.powerOut to mobilityBase.powerIn;
    connect battery.powerOut to perception.powerIn;
    connect battery.powerOut to clearingTool.powerIn;

    connect perception.sensorOut to navigation.sensorIn;
    connect navigation.driveCommandOut to mobilityBase.commandIn;
    connect navigation.safetyOut to safetyController.sensorSafetyIn;
    connect safetyController.commandOut to mobilityBase.commandIn;

    connect supervisor.navCommandOut to navigation.driveCommandOut;
    connect supervisor.toolCommandOut to clearingTool.toolCommandIn;

    connect clearingTool.materialOut to collectionBin.materialIn;
    connect missionInterface to supervisor.missionPort;
    connect supervisor.missionPort to navigation.missionIn;

    connect battery.diagnostics to diagnostics;
    connect mobilityBase.diagnostics to diagnostics;
    connect perception.diagnostics to diagnostics;
    connect navigation.diagnostics to diagnostics;
    connect clearingTool.diagnostics to diagnostics;
    connect collectionBin.diagnostics to diagnostics;
    connect safetyController.diagnostics to diagnostics;
    connect supervisor.diagnostics to diagnostics;

    action def PerformPrimaryBushClearingTask {
      in item mission : MissionPlan;
      out item report : MissionReport;

      first startMission : supervisor.StartMission;
      then planPath : navigation.PlanCoveragePath;
      then classifyTerrain : perception.ClassifyTerrain;
      then trimBush : clearingTool.TrimBushVegetation;
      then collectMaterial : collectionBin.CollectCutMaterial;
      then updateMap : navigation.UpdateCoverageMap;
      then generateReport : supervisor.GenerateMissionReport;

      constraint primaryTaskArea {
        mission.workArea <= maximumPrimaryTaskAreaPerCharge
      }

      constraint primaryTaskCoverage {
        report.coverageAchieved >= mission.requiredCoverage
      }

      constraint primaryTaskSuccess {
        report.success == true
      }
    }

    state def BushRobotOperationalStateMachine {
      state initial;
      state poweredOff;
      state booting;
      state ready;
      state executingPrimaryTask;
      state obstaclePause;
      state returningToDock;
      state docked;
      state maintenanceRequired;
      state emergencyStopped;
      state completed;

      transition first initial then poweredOff;
      transition poweredOff_to_booting first poweredOff accept missionInterface.missionPlan then booting;
      transition booting_to_ready first booting then ready;
      transition ready_to_task first ready then executingPrimaryTask;
      transition task_to_pause first executingPrimaryTask if perception.sensorOut.observation.obstacle == ObstacleClass::human then obstaclePause;
      transition pause_to_task first obstaclePause if perception.sensorOut.observation.obstacle == ObstacleClass::none then executingPrimaryTask;
      transition task_to_return first executingPrimaryTask if battery.state.stateOfCharge <= battery.minStateOfChargeForReturn then returningToDock;
      transition task_to_completed first executingPrimaryTask if missionInterface.missionReport.coverageAchieved >= missionInterface.missionPlan.requiredCoverage then completed;
      transition completed_to_return first completed then returningToDock;
      transition returning_to_docked first returningToDock then docked;
      transition task_to_emergency first executingPrimaryTask if safetyController.sensorSafetyIn.safetyEvent.emergencyStopRequired == true then emergencyStopped;
      transition emergency_to_maintenance first emergencyStopped then maintenanceRequired;
    }

    requirement bushRobotUseRequirement {
      id = "BR-001";
      doc "The robotic system shall perform its primary task using the Bush robot."
      subject robot : BushRobot;
      require constraint { robot.clearingTool.cuttingWidth >= 0.50 [SI::metre] }
      require constraint { robot.maximumPrimaryTaskAreaPerCharge >= 2000 [SI::squareMetre] }
    }

    requirement bushClearingPerformanceRequirement {
      id = "BR-002";
      doc "The Bush robot shall clear bush vegetation to the mission-specified cutting height over at least 98 percent of the assigned work area."
      subject robot : BushRobot;
      require constraint { robot.supervisor.minimumCoverage >= 98 }
      require constraint { robot.clearingTool.adjustableCutHeightMin <= 0.05 [SI::metre] }
      require constraint { robot.clearingTool.adjustableCutHeightMax >= 0.30 [SI::metre] }
    }

    requirement safetyRequirement {
      id = "BR-003";
      doc "The Bush robot shall stop automatically when a human is detected within the protective stop distance."
      subject robot : BushRobot;
      require constraint { robot.safetyController.protectiveStopDistance >= 1.2 [SI::metre] }
      require constraint { robot.safetyController.emergencyStopLatency <= 0.10 [SI::second] }
    }

    requirement mobilityRequirement {
      id = "BR-004";
      doc "The Bush robot shall traverse low brush, dense bush, mud, gravel, and slopes up to 25 degrees while performing the primary task."
      subject robot : BushRobot;
      require constraint { robot.mobilityBase.maxSlope >= 25 [SI::degree] }
      require constraint { robot.mobilityBase.groundClearance >= 0.15 [SI::metre] }
    }
  }

  part def RoboticBushClearingSystem {
    attribute systemName : String = "Autonomous Bush Clearing Robotic System";
    attribute supportedWorkArea : Area = 2500 [SI::squareMetre];
    attribute requiredCoverage : Percent = 98;
    attribute maximumHumanStopDistance : Length = 1.2 [SI::metre];

    port missionInterface : MissionPort;
    port diagnosticInterface : DiagnosticPort;

    part primaryRobot : BushRobot;
    part dock : DockingStation;

    connect missionInterface to primaryRobot.missionInterface;
    connect diagnosticInterface to primaryRobot.diagnostics;
    connect dock.powerOut to primaryRobot.battery.powerOut;
    connect dock.missionPort to primaryRobot.missionInterface;

    action def ExecuteAssignedBushClearingMission {
      in item assignedMission : MissionPlan;
      out item finalReport : MissionReport;

      first dispatch : primaryRobot.PerformPrimaryBushClearingTask;
      then dockAndReport : dock.RechargeBattery;

      constraint usesBushRobot {
        finalReport.success == true
      }

      constraint coverage {
        finalReport.coverageAchieved >= requiredCoverage
      }

      constraint supportedArea {
        assignedMission.workArea <= supportedWorkArea
      }
    }

    state def SystemMissionStateMachine {
      state initial;
      state standby;
      state missionLoaded;
      state bushRobotActive;
      state missionComplete;
      state robotDocked;
      state systemFault;

      transition first initial then standby;
      transition standby_to_loaded first standby accept missionInterface.missionPlan then missionLoaded;
      transition loaded_to_active first missionLoaded then bushRobotActive;
      transition active_to_complete first bushRobotActive if missionInterface.missionReport.success == true then missionComplete;
      transition active_to_fault first bushRobotActive if missionInterface.missionReport.finalHealth == HealthStatus::failed then systemFault;
      transition complete_to_docked first missionComplete then robotDocked;
    }

    requirement systemPrimaryTaskRequirement {
      id = "SYS-001";
      doc "The robotic system shall perform the primary bush clearing task by dispatching and controlling the Bush robot as the primary task performer."
      subject system : RoboticBushClearingSystem;
      require constraint { system.primaryRobot.maximumPrimaryTaskAreaPerCharge >= system.supportedWorkArea }
      require constraint { system.primaryRobot.supervisor.minimumCoverage >= system.requiredCoverage }
    }

    requirement systemSafetyRequirement {
      id = "SYS-002";
      doc "The robotic system shall maintain human safety during autonomous bush clearing operations."
      subject system : RoboticBushClearingSystem;
      require constraint { system.primaryRobot.safetyController.protectiveStopDistance >= system.maximumHumanStopDistance }
      require constraint { system.primaryRobot.safetyController.maximumSafeSpeedNearHuman == 0 [SI::metrePerSecond] }
    }

    requirement systemEnergyRequirement {
      id = "SYS-003";
      doc "The robotic system shall provide sufficient onboard energy and docking recharge capability for the assigned bush clearing mission."
      subject system : RoboticBushClearingSystem;
      require constraint { system.primaryRobot.battery.capacity >= 80 [SI::ampereHour] }
      require constraint { system.dock.chargerPower >= 1500 [SI::watt] }
    }

    satisfy systemPrimaryTaskRequirement by primaryRobot;
    satisfy systemSafetyRequirement by primaryRobot.safetyController;
    satisfy systemEnergyRequirement by primaryRobot.battery;
    satisfy systemEnergyRequirement by dock;
  }

  part roboticBushClearingSystem : RoboticBushClearingSystem {
    attribute nominalMission : MissionPlan {
      attribute workArea = 1800 [SI::squareMetre];
      attribute targetCutHeight = 0.10 [SI::metre];
      attribute maxAllowedSpeed = 0.9 [SI::metrePerSecond];
      attribute requiredCoverage = 98;
    }
  }
}
