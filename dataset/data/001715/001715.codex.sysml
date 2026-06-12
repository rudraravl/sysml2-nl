package LutronLightingControlSystemModel {

  import ScalarValues::*;
  import SI::*;
  import ISQ::*;

  attribute def Percent {
    :> ScalarValues::Real;
    unit = "%";
  }

  attribute def LuminousFlux {
    :> ScalarValues::Real;
    unit = "lm";
  }

  attribute def Illuminance {
    :> ScalarValues::Real;
    unit = "lx";
  }

  attribute def Power {
    :> ScalarValues::Real;
    unit = "W";
  }

  attribute def Voltage {
    :> ScalarValues::Real;
    unit = "V";
  }

  attribute def Current {
    :> ScalarValues::Real;
    unit = "A";
  }

  attribute def TimeDuration {
    :> ScalarValues::Real;
    unit = "s";
  }

  attribute def Temperature {
    :> ScalarValues::Real;
    unit = "degC";
  }

  enum def OccupancyState {
    enum occupied;
    enum vacant;
    enum unknown;
  }

  enum def LightingScene {
    enum off;
    enum evening;
    enum reading;
    enum entertaining;
    enum cleaning;
    enum away;
    enum night;
  }

  enum def ControlMode {
    enum localManual;
    enum scheduled;
    enum daylightHarvesting;
    enum occupancyBased;
    enum remoteApp;
    enum emergencyOverride;
  }

  enum def LinkHealth {
    enum online;
    enum degraded;
    enum offline;
  }

  item def ACLinePower {
    attribute rmsVoltage : Voltage;
    attribute rmsCurrent : Current;
    attribute frequencyHz : Real;
    attribute availablePower : Power;
  }

  item def DCPower {
    attribute voltage : Voltage;
    attribute current : Current;
    attribute availablePower : Power;
  }

  item def WirelessCommand {
    attribute sourceId : String;
    attribute targetId : String;
    attribute requestedScene : LightingScene;
    attribute requestedLevel : Percent;
    attribute fadeTime : TimeDuration;
    attribute priority : Integer;
  }

  item def LightingStatus {
    attribute zoneId : String;
    attribute activeScene : LightingScene;
    attribute measuredLevel : Percent;
    attribute loadPower : Power;
    attribute occupancy : OccupancyState;
    attribute linkHealth : LinkHealth;
  }

  item def OccupancyEvent {
    attribute roomId : String;
    attribute detectedState : OccupancyState;
    attribute confidence : Percent;
    attribute eventAge : TimeDuration;
  }

  item def DaylightMeasurement {
    attribute sensorId : String;
    attribute measuredIlluminance : Illuminance;
    attribute targetIlluminance : Illuminance;
  }

  item def DimmedLoadOutput {
    attribute outputVoltage : Voltage;
    attribute outputCurrent : Current;
    attribute dimmingLevel : Percent;
    attribute deliveredPower : Power;
  }

  port def ACPowerInPort {
    in item power : ACLinePower;
  }

  port def ACPowerOutPort {
    out item power : ACLinePower;
  }

  port def DCPowerOutPort {
    out item power : DCPower;
  }

  port def WirelessReceivePort {
    in item command : WirelessCommand;
  }

  port def WirelessTransmitPort {
    out item status : LightingStatus;
  }

  port def WirelessBidirectionalPort {
    in item command : WirelessCommand;
    out item status : LightingStatus;
  }

  port def SensorEventPort {
    out item occupancy : OccupancyEvent;
    out item daylight : DaylightMeasurement;
  }

  port def SensorInputPort {
    in item occupancy : OccupancyEvent;
    in item daylight : DaylightMeasurement;
  }

  port def LoadControlPort {
    out item loadOutput : DimmedLoadOutput;
  }

  port def LoadInputPort {
    in item loadInput : DimmedLoadOutput;
  }

  part def SmartBridge {
    attribute deviceId : String;
    attribute nominalPowerConsumption : Power = 3.0 [W];
    attribute communicationRange : LengthValue = 18.0 [m];
    attribute cloudConnected : Boolean;
    attribute linkHealth : LinkHealth;

    port acPower : ACPowerInPort;
    port radio : WirelessBidirectionalPort;

    action sendSceneCommand {
      in scene : LightingScene;
      in level : Percent;
      in fade : TimeDuration;
      out command : WirelessCommand;
    }

    action publishStatus {
      in status : LightingStatus;
    }

    state def BridgeOperation {
      state initializing;
      state connected;
      state localOnly;
      state faulted;

      transition first initializing;
      transition initializing_to_connected
        first initializing then connected
        accept after 5.0 [s];

      transition connected_to_localOnly
        first connected then localOnly
        accept when cloudConnected == false;

      transition localOnly_to_connected
        first localOnly then connected
        accept when cloudConnected == true;

      transition any_to_faulted
        first connected then faulted
        accept when linkHealth == LinkHealth::offline;
    }
  }

  part def InWallDimmer {
    attribute deviceId : String;
    attribute maxLoadPower : Power = 150.0 [W];
    attribute minStableLevel : Percent = 5.0 [%];
    attribute commandedLevel : Percent;
    attribute actualLevel : Percent;
    attribute localButtonPressed : Boolean;
    attribute internalTemperature : Temperature;
    attribute linkHealth : LinkHealth;

    port acPower : ACPowerInPort;
    port radio : WirelessBidirectionalPort;
    port loadControl : LoadControlPort;

    action computeDimmedOutput {
      in requestedLevel : Percent;
      in fadeTime : TimeDuration;
      out output : DimmedLoadOutput;
    }

    action reportZoneStatus {
      out status : LightingStatus;
    }

    state def DimmerBehavior {
      state off;
      state fadingUp;
      state on;
      state fadingDown;
      state overheated;
      state communicationLost;

      transition first off;

      transition off_to_fadingUp
        first off then fadingUp
        accept WirelessCommand
        if commandedLevel > 0.0 [%];

      transition fadingUp_to_on
        first fadingUp then on
        accept after 2.0 [s];

      transition on_to_fadingDown
        first on then fadingDown
        accept WirelessCommand
        if commandedLevel == 0.0 [%];

      transition fadingDown_to_off
        first fadingDown then off
        accept after 2.0 [s];

      transition on_to_overheated
        first on then overheated
        accept when internalTemperature > 85.0 [degC];

      transition overheated_to_off
        first overheated then off
        accept after 1.0 [s];

      transition on_to_communicationLost
        first on then communicationLost
        accept when linkHealth == LinkHealth::offline;
    }
  }

  part def PicoRemote {
    attribute deviceId : String;
    attribute batteryLevel : Percent;
    attribute selectedScene : LightingScene;
    attribute requestedLevel : Percent;
    attribute fadeTime : TimeDuration = 1.5 [s];

    port radio : WirelessTransmitPort;

    action pressOn {
      out command : WirelessCommand;
    }

    action pressOff {
      out command : WirelessCommand;
    }

    action pressFavorite {
      out command : WirelessCommand;
    }

    action raiseLevel {
      out command : WirelessCommand;
    }

    action lowerLevel {
      out command : WirelessCommand;
    }
  }

  part def OccupancyDaylightSensor {
    attribute deviceId : String;
    attribute roomId : String;
    attribute batteryLevel : Percent;
    attribute occupancy : OccupancyState;
    attribute measuredIlluminance : Illuminance;
    attribute targetIlluminance : Illuminance = 350.0 [lx];

    port sensorEvents : SensorEventPort;

    action detectMotion {
      out event : OccupancyEvent;
    }

    action measureDaylight {
      out measurement : DaylightMeasurement;
    }

    state def SensorBehavior {
      state monitoring;
      state occupiedDetected;
      state vacancyTimerRunning;
      state vacantReported;

      transition first monitoring;

      transition monitoring_to_occupiedDetected
        first monitoring then occupiedDetected
        accept when occupancy == OccupancyState::occupied;

      transition occupiedDetected_to_vacancyTimerRunning
        first occupiedDetected then vacancyTimerRunning
        accept when occupancy == OccupancyState::vacant;

      transition vacancyTimerRunning_to_vacantReported
        first vacancyTimerRunning then vacantReported
        accept after 600.0 [s];

      transition vacantReported_to_occupiedDetected
        first vacantReported then occupiedDetected
        accept when occupancy == OccupancyState::occupied;
    }
  }

  part def LEDLightingLoad {
    attribute loadId : String;
    attribute ratedPower : Power = 90.0 [W];
    attribute luminousFluxAtFull : LuminousFlux = 7200.0 [lm];
    attribute currentLevel : Percent;
    attribute deliveredPower : Power;
    attribute emittedFlux : LuminousFlux;

    port loadInput : LoadInputPort;

    action emitLight {
      in input : DimmedLoadOutput;
      out flux : LuminousFlux;
    }

    constraint powerWithinRating {
      deliveredPower <= ratedPower;
    }

    constraint fluxTracksLevel {
      emittedFlux == luminousFluxAtFull * currentLevel / 100.0;
    }
  }

  part def RoomLightingController {
    attribute roomId : String;
    attribute activeScene : LightingScene;
    attribute controlMode : ControlMode;
    attribute targetIlluminance : Illuminance = 350.0 [lx];
    attribute vacancyTimeout : TimeDuration = 600.0 [s];
    attribute occupiedLevel : Percent = 75.0 [%];
    attribute vacancyLevel : Percent = 0.0 [%];
    attribute nightLevel : Percent = 15.0 [%];

    port radio : WirelessBidirectionalPort;
    port sensors : SensorInputPort;

    action selectScene {
      in requestedScene : LightingScene;
      in occupancy : OccupancyState;
      in daylight : Illuminance;
      out requestedLevel : Percent;
      out fadeTime : TimeDuration;
    }

    action daylightHarvest {
      in daylight : Illuminance;
      in target : Illuminance;
      out adjustedLevel : Percent;
    }

    action applyVacancyPolicy {
      in occupancy : OccupancyState;
      out requestedScene : LightingScene;
      out requestedLevel : Percent;
    }

    state def ControlBehavior {
      state standby;
      state occupiedControl;
      state daylightAdjusting;
      state vacantHold;
      state lightsOff;
      state emergencyOn;

      transition first standby;

      transition standby_to_occupiedControl
        first standby then occupiedControl
        accept OccupancyEvent
        if occupancy == OccupancyState::occupied;

      transition occupiedControl_to_daylightAdjusting
        first occupiedControl then daylightAdjusting
        accept DaylightMeasurement;

      transition daylightAdjusting_to_occupiedControl
        first daylightAdjusting then occupiedControl
        accept after 0.5 [s];

      transition occupiedControl_to_vacantHold
        first occupiedControl then vacantHold
        accept OccupancyEvent
        if occupancy == OccupancyState::vacant;

      transition vacantHold_to_lightsOff
        first vacantHold then lightsOff
        accept after vacancyTimeout;

      transition lightsOff_to_occupiedControl
        first lightsOff then occupiedControl
        accept OccupancyEvent
        if occupancy == OccupancyState::occupied;

      transition occupiedControl_to_emergencyOn
        first occupiedControl then emergencyOn
        accept when controlMode == ControlMode::emergencyOverride;
    }
  }

  part def LutronBasedResidentialLightingSystem {
    doc /* Primary function: provide coordinated, high-level residential lighting control by receiving local, sensor, schedule, and app commands, then automatically setting dimmable lighting zones to comfortable, energy-efficient scenes while reporting system status. */

    attribute systemName : String = "Lutron-Based Residential Lighting Control System";
    attribute primaryFunction : String = "Coordinate smart dimmers, wireless remotes, occupancy sensing, daylight harvesting, and bridge connectivity to deliver reliable scene-based lighting control.";
    attribute nominalInputVoltage : Voltage = 120.0 [V];
    attribute branchCircuitLimit : Current = 15.0 [A];
    attribute maximumInstalledLoad : Power = 540.0 [W];
    attribute standbyPowerBudget : Power = 12.0 [W];

    port utilityPower : ACPowerInPort;

    part bridge : SmartBridge {
      attribute deviceId = "BRIDGE-01";
      attribute cloudConnected = true;
      attribute linkHealth = LinkHealth::online;
    }

    part livingRoomController : RoomLightingController {
      attribute roomId = "LivingRoom";
      attribute activeScene = LightingScene::evening;
      attribute controlMode = ControlMode::occupancyBased;
    }

    part kitchenController : RoomLightingController {
      attribute roomId = "Kitchen";
      attribute activeScene = LightingScene::cleaning;
      attribute controlMode = ControlMode::daylightHarvesting;
      attribute targetIlluminance = 500.0 [lx];
    }

    part livingRoomDimmer : InWallDimmer {
      attribute deviceId = "DIM-LR-01";
      attribute maxLoadPower = 150.0 [W];
      attribute commandedLevel = 60.0 [%];
      attribute actualLevel = 60.0 [%];
      attribute linkHealth = LinkHealth::online;
    }

    part kitchenDimmer : InWallDimmer {
      attribute deviceId = "DIM-KT-01";
      attribute maxLoadPower = 150.0 [W];
      attribute commandedLevel = 85.0 [%];
      attribute actualLevel = 85.0 [%];
      attribute linkHealth = LinkHealth::online;
    }

    part hallDimmer : InWallDimmer {
      attribute deviceId = "DIM-HL-01";
      attribute maxLoadPower = 100.0 [W];
      attribute commandedLevel = 25.0 [%];
      attribute actualLevel = 25.0 [%];
      attribute linkHealth = LinkHealth::online;
    }

    part livingRoomRemote : PicoRemote {
      attribute deviceId = "PICO-LR-01";
      attribute batteryLevel = 92.0 [%];
      attribute selectedScene = LightingScene::reading;
      attribute requestedLevel = 70.0 [%];
    }

    part entryRemote : PicoRemote {
      attribute deviceId = "PICO-ENTRY-01";
      attribute batteryLevel = 81.0 [%];
      attribute selectedScene = LightingScene::away;
      attribute requestedLevel = 0.0 [%];
    }

    part livingRoomSensor : OccupancyDaylightSensor {
      attribute deviceId = "SENS-LR-01";
      attribute roomId = "LivingRoom";
      attribute batteryLevel = 88.0 [%];
      attribute occupancy = OccupancyState::occupied;
      attribute measuredIlluminance = 180.0 [lx];
    }

    part kitchenSensor : OccupancyDaylightSensor {
      attribute deviceId = "SENS-KT-01";
      attribute roomId = "Kitchen";
      attribute batteryLevel = 76.0 [%];
      attribute occupancy = OccupancyState::occupied;
      attribute measuredIlluminance = 420.0 [lx];
      attribute targetIlluminance = 500.0 [lx];
    }

    part livingRoomLoad : LEDLightingLoad {
      attribute loadId = "LOAD-LR-CEILING";
      attribute ratedPower = 90.0 [W];
      attribute luminousFluxAtFull = 7200.0 [lm];
      attribute currentLevel = 60.0 [%];
    }

    part kitchenLoad : LEDLightingLoad {
      attribute loadId = "LOAD-KT-DOWNLIGHTS";
      attribute ratedPower = 120.0 [W];
      attribute luminousFluxAtFull = 9600.0 [lm];
      attribute currentLevel = 85.0 [%];
    }

    part hallLoad : LEDLightingLoad {
      attribute loadId = "LOAD-HL-SCONCES";
      attribute ratedPower = 45.0 [W];
      attribute luminousFluxAtFull = 3200.0 [lm];
      attribute currentLevel = 25.0 [%];
    }

    connect utilityPower.power to bridge.acPower.power;
    connect utilityPower.power to livingRoomDimmer.acPower.power;
    connect utilityPower.power to kitchenDimmer.acPower.power;
    connect utilityPower.power to hallDimmer.acPower.power;

    connect bridge.radio.command to livingRoomController.radio.command;
    connect bridge.radio.command to kitchenController.radio.command;
    connect livingRoomController.radio.status to bridge.radio.status;
    connect kitchenController.radio.status to bridge.radio.status;

    connect livingRoomRemote.radio.status to bridge.radio.status;
    connect entryRemote.radio.status to bridge.radio.status;

    connect bridge.radio.command to livingRoomDimmer.radio.command;
    connect bridge.radio.command to kitchenDimmer.radio.command;
    connect bridge.radio.command to hallDimmer.radio.command;

    connect livingRoomDimmer.radio.status to bridge.radio.status;
    connect kitchenDimmer.radio.status to bridge.radio.status;
    connect hallDimmer.radio.status to bridge.radio.status;

    connect livingRoomSensor.sensorEvents.occupancy to livingRoomController.sensors.occupancy;
    connect livingRoomSensor.sensorEvents.daylight to livingRoomController.sensors.daylight;
    connect kitchenSensor.sensorEvents.occupancy to kitchenController.sensors.occupancy;
    connect kitchenSensor.sensorEvents.daylight to kitchenController.sensors.daylight;

    connect livingRoomDimmer.loadControl.loadOutput to livingRoomLoad.loadInput.loadInput;
    connect kitchenDimmer.loadControl.loadOutput to kitchenLoad.loadInput.loadInput;
    connect hallDimmer.loadControl.loadOutput to hallLoad.loadInput.loadInput;

    constraint installedLoadWithinCircuit {
      livingRoomLoad.ratedPower + kitchenLoad.ratedPower + hallLoad.ratedPower <= maximumInstalledLoad;
    }

    constraint dimmersWithinLoadRatings {
      livingRoomLoad.ratedPower <= livingRoomDimmer.maxLoadPower and
      kitchenLoad.ratedPower <= kitchenDimmer.maxLoadPower and
      hallLoad.ratedPower <= hallDimmer.maxLoadPower;
    }

    constraint standbyPowerWithinBudget {
      bridge.nominalPowerConsumption <= standbyPowerBudget;
    }

    constraint commandedLevelsBounded {
      livingRoomDimmer.commandedLevel >= 0.0 [%] and livingRoomDimmer.commandedLevel <= 100.0 [%] and
      kitchenDimmer.commandedLevel >= 0.0 [%] and kitchenDimmer.commandedLevel <= 100.0 [%] and
      hallDimmer.commandedLevel >= 0.0 [%] and hallDimmer.commandedLevel <= 100.0 [%];
    }
  }

  requirement def PrimaryLightingControlRequirement {
    doc /* The system shall coordinate lighting zones from local controls, sensors, schedules, and app commands to provide scene-based dimming and automatic shutoff. */
    subject system : LutronBasedResidentialLightingSystem;
    require constraint {
      system.primaryFunction == "Coordinate smart dimmers, wireless remotes, occupancy sensing, daylight harvesting, and bridge connectivity to deliver reliable scene-based lighting control."
    }
  }

  requirement def VacancyEnergySavingRequirement {
    doc /* The system shall turn a vacant room lighting zone off after the configured vacancy timeout to reduce energy use. */
    subject controller : RoomLightingController;
    require constraint {
      controller.vacancyTimeout <= 900.0 [s]
    }
  }

  requirement def DaylightHarvestingRequirement {
    doc /* The system shall reduce electric lighting output when measured daylight is sufficient to maintain target illuminance. */
    subject controller : RoomLightingController;
    require constraint {
      controller.targetIlluminance >= 300.0 [lx]
    }
  }

  requirement def WirelessStatusRequirement {
    doc /* Each controlled dimmer shall report lighting level, active scene, load power, occupancy context, and wireless link health. */
    subject dimmer : InWallDimmer;
    require constraint {
      dimmer.linkHealth != LinkHealth::offline
    }
  }

  requirement def LoadSafetyRequirement {
    doc /* Each dimmer shall control only lighting loads at or below its rated maximum load power. */
    subject system : LutronBasedResidentialLightingSystem;
    require constraint {
      system.livingRoomLoad.ratedPower <= system.livingRoomDimmer.maxLoadPower and
      system.kitchenLoad.ratedPower <= system.kitchenDimmer.maxLoadPower and
      system.hallLoad.ratedPower <= system.hallDimmer.maxLoadPower
    }
  }

  requirement def ManualOverrideRequirement {
    doc /* A local button or wireless remote command shall override automatic scene selection for the targeted zone. */
    subject dimmer : InWallDimmer;
    require constraint {
      dimmer.localButtonPressed implies dimmer.commandedLevel == dimmer.actualLevel
    }
  }

  satisfy PrimaryLightingControlRequirement by LutronBasedResidentialLightingSystemModel::LutronBasedResidentialLightingSystem;
  satisfy VacancyEnergySavingRequirement by LutronBasedResidentialLightingSystemModel::RoomLightingController;
  satisfy DaylightHarvestingRequirement by LutronBasedResidentialLightingSystemModel::RoomLightingController;
  satisfy WirelessStatusRequirement by LutronBasedResidentialLightingSystemModel::InWallDimmer;
  satisfy LoadSafetyRequirement by LutronBasedResidentialLightingSystemModel::LutronBasedResidentialLightingSystem;
  satisfy ManualOverrideRequirement by LutronBasedResidentialLightingSystemModel::InWallDimmer;
}