package PopularScienceIndoorAirPurificationSystem {

  import ScalarValues::*;
  import SI::*;
  import ISQ::*;

  comment SystemPurpose
  /* Based on the popular science topic of aerosol physics and filtration, this model specifies an indoor smart air purifier whose primary high-level function is to draw contaminated room air through staged filtration and ultraviolet treatment, then return cleaner air while monitoring air quality and maintaining safe operation. */

  attribute def ElectricPower :> ISQ::power;
  attribute def ElectricPotential :> ISQ::electricPotential;
  attribute def ElectricCurrent :> ISQ::electricCurrent;
  attribute def Frequency :> ISQ::frequency;
  attribute def Temperature :> ISQ::thermodynamicTemperature;
  attribute def RelativeHumidity;
  attribute def PressureDrop :> ISQ::pressure;
  attribute def VolumetricFlowRate;
  attribute def SoundPressureLevel;
  attribute def ParticleConcentration;
  attribute def GasConcentration;
  attribute def Irradiance;
  attribute def ServiceLife;
  attribute def Efficiency;
  attribute def RotationalSpeed :> ISQ::frequency;
  attribute def Mass :> ISQ::mass;
  attribute def Length :> ISQ::length;
  attribute def TimeDuration :> ISQ::time;

  enum def OperatingMode {
    enum off;
    enum standby;
    enum automatic;
    enum manual;
    enum boost;
    enum sleep;
    enum maintenance;
    enum fault;
  }

  enum def FaultKind {
    enum none;
    enum fanStall;
    enum filterBlocked;
    enum uvDoorOpen;
    enum uvLampFailure;
    enum sensorFailure;
    enum powerFault;
    enum overTemperature;
  }

  enum def FilterCondition {
    enum new;
    enum nominal;
    enum degraded;
    enum replacementRequired;
    enum clogged;
  }

  item def AirMixture {
    attribute temperature: Temperature;
    attribute relativeHumidity: RelativeHumidity;
    attribute pm1_0: ParticleConcentration;
    attribute pm2_5: ParticleConcentration;
    attribute pm10: ParticleConcentration;
    attribute co2: GasConcentration;
    attribute voc: GasConcentration;
    attribute microbialLoad: ParticleConcentration;
    attribute odorIndex: Real;
  }

  item def ContaminatedRoomAir :> AirMixture;
  item def PurifiedSupplyAir :> AirMixture;

  item def ElectricalPower {
    attribute voltage: ElectricPotential;
    attribute current: ElectricCurrent;
    attribute frequency: Frequency;
    attribute power: ElectricPower;
  }

  item def LowVoltagePower :> ElectricalPower {
    attribute voltage: ElectricPotential = 24 [V];
  }

  item def ControlCommand {
    attribute requestedMode: OperatingMode;
    attribute requestedFanPercent: Real;
    attribute childLockEnabled: Boolean;
    attribute displayBrightnessPercent: Real;
  }

  item def SensorReading {
    attribute measuredPm2_5: ParticleConcentration;
    attribute measuredPm10: ParticleConcentration;
    attribute measuredCo2: GasConcentration;
    attribute measuredVoc: GasConcentration;
    attribute measuredTemperature: Temperature;
    attribute measuredHumidity: RelativeHumidity;
    attribute measuredDifferentialPressure: PressureDrop;
    attribute measuredDoorClosed: Boolean;
    attribute measuredFanSpeed: RotationalSpeed;
  }

  item def HealthStatus {
    attribute currentMode: OperatingMode;
    attribute activeFault: FaultKind;
    attribute filterCondition: FilterCondition;
    attribute remainingFilterLife: ServiceLife;
    attribute uvLampHealthy: Boolean;
    attribute cleanAirDeliveryRate: VolumetricFlowRate;
    attribute soundLevel: SoundPressureLevel;
  }

  item def UserNotification {
    attribute messageCode: String;
    attribute severity: Integer;
    attribute audible: Boolean;
    attribute visible: Boolean;
  }

  port def AirInletPort {
    in item airIn: AirMixture;
  }

  port def AirOutletPort {
    out item airOut: AirMixture;
  }

  port def InternalAirInputPort {
    in item airIn: AirMixture;
  }

  port def InternalAirOutputPort {
    out item airOut: AirMixture;
  }

  port def PowerInputPort {
    in item powerIn: ElectricalPower;
  }

  port def PowerOutputPort {
    out item powerOut: ElectricalPower;
  }

  port def LowVoltagePowerPort {
    inout item lowVoltage: LowVoltagePower;
  }

  port def CommandInputPort {
    in item command: ControlCommand;
  }

  port def StatusOutputPort {
    out item status: HealthStatus;
  }

  port def NotificationOutputPort {
    out item notification: UserNotification;
  }

  port def SensorDataOutputPort {
    out item reading: SensorReading;
  }

  port def SensorDataInputPort {
    in item reading: SensorReading;
  }

  port def ControlSignalOutputPort {
    out item command: ControlCommand;
  }

  port def ControlSignalInputPort {
    in item command: ControlCommand;
  }

  part def IntakeGrille {
    port roomAirIn: AirInletPort;
    port airToFan: InternalAirOutputPort;

    attribute openAreaRatio: Real = 0.72;
    attribute maximumFaceVelocity: VolumetricFlowRate = 480 ['m^3/h'];
    attribute washable: Boolean = true;
  }

  part def VariableSpeedBlower {
    port airIn: InternalAirInputPort;
    port airOut: InternalAirOutputPort;
    port power: LowVoltagePowerPort;
    port control: ControlSignalInputPort;
    port sensor: SensorDataOutputPort;

    attribute ratedFlow: VolumetricFlowRate = 520 ['m^3/h'];
    attribute minimumFlow: VolumetricFlowRate = 80 ['m^3/h'];
    attribute ratedPower: ElectricPower = 85 [W];
    attribute maximumSpeed: RotationalSpeed = 4200 ['1/min'];
    attribute acousticLevelAtNominal: SoundPressureLevel = 48 [dB];
  }

  part def PreFilter {
    port airIn: InternalAirInputPort;
    port airOut: InternalAirOutputPort;

    attribute capturesHairAndLint: Boolean = true;
    attribute nominalPressureDrop: PressureDrop = 18 [Pa];
    attribute serviceInterval: ServiceLife = 30 [d];
    attribute condition: FilterCondition = FilterCondition::nominal;
  }

  part def HepaFilter {
    port airIn: InternalAirInputPort;
    port airOut: InternalAirOutputPort;

    attribute particleRemovalEfficiencyAt03Micrometer: Efficiency = 0.9997;
    attribute nominalPressureDrop: PressureDrop = 95 [Pa];
    attribute maximumAllowedPressureDrop: PressureDrop = 220 [Pa];
    attribute ratedServiceLife: ServiceLife = 180 [d];
    attribute condition: FilterCondition = FilterCondition::nominal;
    attribute filterMediaArea: Length = 5.2 [m];
  }

  part def ActivatedCarbonFilter {
    port airIn: InternalAirInputPort;
    port airOut: InternalAirOutputPort;

    attribute vocReductionEfficiency: Efficiency = 0.85;
    attribute odorReductionEfficiency: Efficiency = 0.80;
    attribute carbonMass: Mass = 0.85 [kg];
    attribute nominalPressureDrop: PressureDrop = 45 [Pa];
    attribute ratedServiceLife: ServiceLife = 120 [d];
    attribute condition: FilterCondition = FilterCondition::nominal;
  }

  part def UltravioletTreatmentChamber {
    port airIn: InternalAirInputPort;
    port airOut: InternalAirOutputPort;
    port power: LowVoltagePowerPort;
    port control: ControlSignalInputPort;
    port status: SensorDataOutputPort;

    attribute wavelength: Length = 254 [nm];
    attribute lampPower: ElectricPower = 16 [W];
    attribute minimumChamberIrradiance: Irradiance = 1100 ['uW/cm^2'];
    attribute microbialInactivationTarget: Efficiency = 0.90;
    attribute accessDoorClosed: Boolean = true;
    attribute uvEnabled: Boolean = false;
  }

  part def ExhaustDiffuser {
    port cleanAirIn: InternalAirInputPort;
    port roomAirOut: AirOutletPort;

    attribute outletAreaRatio: Real = 0.81;
    attribute maximumDraftVelocity: VolumetricFlowRate = 520 ['m^3/h'];
    attribute directsFlowUpward: Boolean = true;
  }

  part def AirQualitySensorArray {
    port sampledAir: InternalAirInputPort;
    port dataOut: SensorDataOutputPort;
    port power: LowVoltagePowerPort;

    attribute pmSensorResolution: ParticleConcentration = 1 ['ug/m^3'];
    attribute co2Range: GasConcentration = 5000 [ppm];
    attribute vocRange: GasConcentration = 1000 [ppb];
    attribute samplingPeriod: TimeDuration = 5 [s];
    attribute selfTestSupported: Boolean = true;
  }

  part def DifferentialPressureSensor {
    port upstreamAir: InternalAirInputPort;
    port downstreamAir: InternalAirInputPort;
    port dataOut: SensorDataOutputPort;
    port power: LowVoltagePowerPort;

    attribute measurementRange: PressureDrop = 500 [Pa];
    attribute cloggedFilterThreshold: PressureDrop = 220 [Pa];
  }

  part def SafetyInterlock {
    port dataOut: SensorDataOutputPort;
    port power: LowVoltagePowerPort;

    attribute doorClosed: Boolean = true;
    attribute disablesUvWhenOpen: Boolean = true;
    attribute disablesFanWhenCoverRemoved: Boolean = true;
  }

  part def PowerSupply {
    port mainsInput: PowerInputPort;
    port lowVoltageOutput: LowVoltagePowerPort;
    port status: SensorDataOutputPort;

    attribute inputVoltage: ElectricPotential = 120 [V];
    attribute outputVoltage: ElectricPotential = 24 [V];
    attribute maximumOutputPower: ElectricPower = 140 [W];
    attribute efficiencyAtNominalLoad: Efficiency = 0.91;
    attribute overCurrentProtection: Boolean = true;
  }

  part def EmbeddedController {
    port sensorIn: SensorDataInputPort;
    port commandIn: CommandInputPort;
    port fanCommand: ControlSignalOutputPort;
    port uvCommand: ControlSignalOutputPort;
    port statusOut: StatusOutputPort;
    port notificationOut: NotificationOutputPort;
    port power: LowVoltagePowerPort;

    attribute processorClock: Frequency = 120 [MHz];
    attribute controlPeriod: TimeDuration = 1 [s];
    attribute targetPm2_5: ParticleConcentration = 12 ['ug/m^3'];
    attribute boostPm2_5Threshold: ParticleConcentration = 55 ['ug/m^3'];
    attribute quietModeMaximumSound: SoundPressureLevel = 35 [dB];
    attribute currentMode: OperatingMode = OperatingMode::standby;
    attribute activeFault: FaultKind = FaultKind::none;
  }

  part def UserInterface {
    port commandOut: CommandInputPort;
    port statusIn: StatusOutputPort;
    port notificationIn: NotificationOutputPort;
    port power: LowVoltagePowerPort;

    attribute hasTouchPanel: Boolean = true;
    attribute hasAirQualityIndicator: Boolean = true;
    attribute hasAudibleAlarm: Boolean = true;
    attribute supportsFilterReset: Boolean = true;
  }

  action def SenseAirQuality {
    in item sampledAir: AirMixture;
    out item reading: SensorReading;

    attribute samplingDuration: TimeDuration = 5 [s];
  }

  action def ComputePurificationCommand {
    in item reading: SensorReading;
    in item userCommand: ControlCommand;
    out item fanCommand: ControlCommand;
    out item uvCommand: ControlCommand;

    attribute pm2_5CleanTarget: ParticleConcentration = 12 ['ug/m^3'];
    attribute boostThreshold: ParticleConcentration = 55 ['ug/m^3'];
    attribute minimumFanPercent: Real = 18.0;
    attribute maximumFanPercent: Real = 100.0;
  }

  action def MoveAir {
    in item inletAir: AirMixture;
    in item fanCommand: ControlCommand;
    out item pressurizedAir: AirMixture;

    attribute commandedFlow: VolumetricFlowRate = 360 ['m^3/h'];
  }

  action def RemoveLargeParticles {
    in item unfilteredAir: AirMixture;
    out item preFilteredAir: AirMixture;

    attribute lintRemovalEfficiency: Efficiency = 0.95;
    attribute coarseParticleRemovalEfficiency: Efficiency = 0.70;
  }

  action def RemoveFineParticles {
    in item preFilteredAir: AirMixture;
    out item hepaFilteredAir: AirMixture;

    attribute pm03RemovalEfficiency: Efficiency = 0.9997;
    attribute pm25RemovalEfficiency: Efficiency = 0.999;
  }

  action def AdsorbGasesAndOdors {
    in item hepaFilteredAir: AirMixture;
    out item gasReducedAir: AirMixture;

    attribute vocReductionEfficiency: Efficiency = 0.85;
    attribute odorReductionEfficiency: Efficiency = 0.80;
  }

  action def InactivateMicrobes {
    in item gasReducedAir: AirMixture;
    in item uvCommand: ControlCommand;
    out item treatedAir: AirMixture;

    attribute requiredExposureTime: TimeDuration = 0.6 [s];
    attribute targetInactivationEfficiency: Efficiency = 0.90;
  }

  action def DeliverCleanAir {
    in item treatedAir: AirMixture;
    out item supplyAir: PurifiedSupplyAir;

    attribute nominalCleanAirDeliveryRate: VolumetricFlowRate = 450 ['m^3/h'];
  }

  action def MonitorHealth {
    in item reading: SensorReading;
    out item status: HealthStatus;
    out item notification: UserNotification;

    attribute filterPressureLimit: PressureDrop = 220 [Pa];
    attribute overTemperatureLimit: Temperature = 333.15 [K];
  }

  action def PurificationCycle {
    in item roomAir: ContaminatedRoomAir;
    in item userCommand: ControlCommand;
    out item cleanAir: PurifiedSupplyAir;
    out item status: HealthStatus;

    action sense: SenseAirQuality;
    action compute: ComputePurificationCommand;
    action move: MoveAir;
    action prefilter: RemoveLargeParticles;
    action hepa: RemoveFineParticles;
    action carbon: AdsorbGasesAndOdors;
    action uv: InactivateMicrobes;
    action deliver: DeliverCleanAir;
    action health: MonitorHealth;

    flow roomAir to sense.sampledAir;
    flow sense.reading to compute.reading;
    flow userCommand to compute.userCommand;
    flow roomAir to move.inletAir;
    flow compute.fanCommand to move.fanCommand;
    flow move.pressurizedAir to prefilter.unfilteredAir;
    flow prefilter.preFilteredAir to hepa.preFilteredAir;
    flow hepa.hepaFilteredAir to carbon.hepaFilteredAir;
    flow carbon.gasReducedAir to uv.gasReducedAir;
    flow compute.uvCommand to uv.uvCommand;
    flow uv.treatedAir to deliver.treatedAir;
    flow deliver.supplyAir to cleanAir;
    flow sense.reading to health.reading;
    flow health.status to status;
  }

  state def AirPurifierOperatingStateMachine {
    entry action initialize {
      out item status: HealthStatus;
    }

    state Off {
      entry action deenergizeActuators;
    }

    state Standby {
      entry action powerSensors;
      do action SenseAirQuality;
    }

    state AutomaticPurification {
      entry action enableClosedLoopControl;
      do action PurificationCycle;
    }

    state BoostPurification {
      entry action setMaximumFanSpeed;
      do action PurificationCycle;
    }

    state SleepPurification {
      entry action dimDisplayAndLimitFanNoise;
      do action PurificationCycle;
    }

    state MaintenanceRequired {
      entry action notifyFilterReplacement;
      do action MonitorHealth;
    }

    state Faulted {
      entry action disableFanAndUv;
      do action publishFaultNotification;
    }

    transition initial then Off;

    transition Off_to_Standby
      first Off
      accept ControlCommand
      if command.requestedMode != OperatingMode::off
      then Standby;

    transition Standby_to_Automatic
      first Standby
      accept ControlCommand
      if command.requestedMode == OperatingMode::automatic
      then AutomaticPurification;

    transition Standby_to_ManualBoost
      first Standby
      accept ControlCommand
      if command.requestedMode == OperatingMode::boost
      then BoostPurification;

    transition Automatic_to_Boost
      first AutomaticPurification
      accept SensorReading
      if reading.measuredPm2_5 >= 55 ['ug/m^3']
      then BoostPurification;

    transition Boost_to_Automatic
      first BoostPurification
      accept SensorReading
      if reading.measuredPm2_5 <= 12 ['ug/m^3']
      then AutomaticPurification;

    transition Automatic_to_Sleep
      first AutomaticPurification
      accept ControlCommand
      if command.requestedMode == OperatingMode::sleep
      then SleepPurification;

    transition Sleep_to_Automatic
      first SleepPurification
      accept ControlCommand
      if command.requestedMode == OperatingMode::automatic
      then AutomaticPurification;

    transition Any_to_Maintenance
      first AutomaticPurification
      accept SensorReading
      if reading.measuredDifferentialPressure >= 220 [Pa]
      then MaintenanceRequired;

    transition Maintenance_to_Standby
      first MaintenanceRequired
      accept ControlCommand
      if command.requestedMode == OperatingMode::standby
      then Standby;

    transition Any_to_Fault
      first AutomaticPurification
      accept SensorReading
      if reading.measuredDoorClosed == false
      then Faulted;

    transition Fault_to_Standby
      first Faulted
      accept ControlCommand
      if command.requestedMode == OperatingMode::standby
      then Standby;

    transition Any_to_Off
      first Standby
      accept ControlCommand
      if command.requestedMode == OperatingMode::off
      then Off;
  }

  part def SmartIndoorAirPurifier {
    port roomAirIntake: AirInletPort;
    port cleanAirOutlet: AirOutletPort;
    port mainsPower: PowerInputPort;
    port userCommand: CommandInputPort;
    port healthStatus: StatusOutputPort;
    port userAlert: NotificationOutputPort;

    part intake: IntakeGrille;
    part blower: VariableSpeedBlower;
    part preFilter: PreFilter;
    part hepaFilter: HepaFilter;
    part carbonFilter: ActivatedCarbonFilter;
    part uvChamber: UltravioletTreatmentChamber;
    part exhaust: ExhaustDiffuser;
    part airSensors: AirQualitySensorArray;
    part pressureSensor: DifferentialPressureSensor;
    part interlock: SafetyInterlock;
    part powerSupply: PowerSupply;
    part controller: EmbeddedController;
    part ui: UserInterface;

    attribute nominalCleanAirDeliveryRate: VolumetricFlowRate = 450 ['m^3/h'];
    attribute maximumRoomVolumeServed: VolumetricFlowRate = 135 ['m^3'];
    attribute maximumPowerConsumption: ElectricPower = 120 [W];
    attribute standbyPowerConsumption: ElectricPower = 1.5 [W];
    attribute maximumSoundLevel: SoundPressureLevel = 60 [dB];
    attribute enclosureHeight: Length = 0.62 [m];
    attribute enclosureWidth: Length = 0.34 [m];
    attribute enclosureDepth: Length = 0.34 [m];
    attribute mass: Mass = 8.7 [kg];

    perform action normalPurification: PurificationCycle;
    exhibit state operatingState: AirPurifierOperatingStateMachine;

    connect roomAirIntake to intake.roomAirIn;
    connect intake.airToFan to blower.airIn;
    connect blower.airOut to preFilter.airIn;
    connect preFilter.airOut to hepaFilter.airIn;
    connect hepaFilter.airOut to carbonFilter.airIn;
    connect carbonFilter.airOut to uvChamber.airIn;
    connect uvChamber.airOut to exhaust.cleanAirIn;
    connect exhaust.roomAirOut to cleanAirOutlet;

    connect mainsPower to powerSupply.mainsInput;
    connect powerSupply.lowVoltageOutput to blower.power;
    connect powerSupply.lowVoltageOutput to uvChamber.power;
    connect powerSupply.lowVoltageOutput to airSensors.power;
    connect powerSupply.lowVoltageOutput to pressureSensor.power;
    connect powerSupply.lowVoltageOutput to interlock.power;
    connect powerSupply.lowVoltageOutput to controller.power;
    connect powerSupply.lowVoltageOutput to ui.power;

    connect userCommand to controller.commandIn;
    connect controller.statusOut to healthStatus;
    connect controller.notificationOut to userAlert;
    connect controller.statusOut to ui.statusIn;
    connect controller.notificationOut to ui.notificationIn;
    connect ui.commandOut to controller.commandIn;

    connect controller.fanCommand to blower.control;
    connect controller.uvCommand to uvChamber.control;

    connect blower.sensor to controller.sensorIn;
    connect airSensors.dataOut to controller.sensorIn;
    connect pressureSensor.dataOut to controller.sensorIn;
    connect interlock.dataOut to controller.sensorIn;
    connect uvChamber.status to controller.sensorIn;

    connect preFilter.airOut to airSensors.sampledAir;
    connect hepaFilter.airIn to pressureSensor.upstreamAir;
    connect hepaFilter.airOut to pressureSensor.downstreamAir;
  }

  requirement def PrimaryFunctionRequirement {
    subject purifier: SmartIndoorAirPurifier;

    doc
    /* The system shall provide the high-level primary function of improving indoor air quality by accepting contaminated room air, removing fine particles, reducing gases and odors, inactivating airborne microbes when safe, and delivering purified air back to the room. */

    require constraint {
      purifier.nominalCleanAirDeliveryRate >= 400 ['m^3/h']
    }
  }

  requirement def FineParticleRemovalRequirement {
    subject purifier: SmartIndoorAirPurifier;

    require constraint {
      purifier.hepaFilter.particleRemovalEfficiencyAt03Micrometer >= 0.9997
    }
  }

  requirement def GasAndOdorReductionRequirement {
    subject purifier: SmartIndoorAirPurifier;

    require constraint {
      purifier.carbonFilter.vocReductionEfficiency >= 0.80 and
      purifier.carbonFilter.odorReductionEfficiency >= 0.75
    }
  }

  requirement def MicrobialTreatmentSafetyRequirement {
    subject purifier: SmartIndoorAirPurifier;

    require constraint {
      purifier.uvChamber.uvEnabled implies purifier.uvChamber.accessDoorClosed
    }
  }

  requirement def CleanAirDeliveryRequirement {
    subject purifier: SmartIndoorAirPurifier;

    require constraint {
      purifier.nominalCleanAirDeliveryRate >= 450 ['m^3/h']
    }
  }

  requirement def PowerConsumptionRequirement {
    subject purifier: SmartIndoorAirPurifier;

    require constraint {
      purifier.maximumPowerConsumption <= 120 [W] and
      purifier.standbyPowerConsumption <= 2 [W]
    }
  }

  requirement def AcousticRequirement {
    subject purifier: SmartIndoorAirPurifier;

    require constraint {
      purifier.maximumSoundLevel <= 60 [dB]
    }
  }

  requirement def FilterMaintenanceRequirement {
    subject purifier: SmartIndoorAirPurifier;

    require constraint {
      purifier.hepaFilter.maximumAllowedPressureDrop <= 220 [Pa]
    }
  }

  requirement def FaultDetectionRequirement {
    subject purifier: SmartIndoorAirPurifier;

    require constraint {
      purifier.controller.activeFault != FaultKind::none implies
      purifier.operatingState == AirPurifierOperatingStateMachine::Faulted
    }
  }

  requirement def UserNotificationRequirement {
    subject purifier: SmartIndoorAirPurifier;

    require constraint {
      purifier.ui.hasAirQualityIndicator == true and
      purifier.ui.hasAudibleAlarm == true
    }
  }

  satisfy PrimaryFunctionRequirement by SmartIndoorAirPurifier;
  satisfy FineParticleRemovalRequirement by SmartIndoorAirPurifier::hepaFilter;
  satisfy GasAndOdorReductionRequirement by SmartIndoorAirPurifier::carbonFilter;
  satisfy MicrobialTreatmentSafetyRequirement by SmartIndoorAirPurifier::uvChamber;
  satisfy CleanAirDeliveryRequirement by SmartIndoorAirPurifier;
  satisfy PowerConsumptionRequirement by SmartIndoorAirPurifier::powerSupply;
  satisfy AcousticRequirement by SmartIndoorAirPurifier::blower;
  satisfy FilterMaintenanceRequirement by SmartIndoorAirPurifier::pressureSensor;
  satisfy FaultDetectionRequirement by SmartIndoorAirPurifier::controller;
  satisfy UserNotificationRequirement by SmartIndoorAirPurifier::ui;

  part smartPurifierSystem: SmartIndoorAirPurifier {
    attribute nominalCleanAirDeliveryRate = 450 ['m^3/h'];
    attribute maximumPowerConsumption = 120 [W];
    attribute standbyPowerConsumption = 1.5 [W];
    attribute maximumSoundLevel = 60 [dB];
  }

}
