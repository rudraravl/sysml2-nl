package ClothesDryerPrimaryFunctionModel {

  import ScalarValues::*;

  attribute def Mass_kg :> Real {
    doc "Mass measured in kilograms.";
  }

  attribute def Time_s :> Real {
    doc "Time measured in seconds.";
  }

  attribute def Temperature_degC :> Real {
    doc "Temperature measured in degrees Celsius.";
  }

  attribute def Power_W :> Real {
    doc "Power measured in watts.";
  }

  attribute def Voltage_V :> Real {
    doc "Voltage measured in volts.";
  }

  attribute def Current_A :> Real {
    doc "Current measured in amperes.";
  }

  attribute def Frequency_Hz :> Real {
    doc "Frequency measured in hertz.";
  }

  attribute def FlowRate_m3_per_s :> Real {
    doc "Volumetric flow rate measured in cubic meters per second.";
  }

  attribute def MoistureRatio_kg_per_kg :> Real {
    doc "Water mass divided by dry textile mass, measured in kg water per kg dry textile.";
  }

  attribute def RelativeHumidity_percent :> Real {
    doc "Relative humidity measured as a percentage.";
  }

  attribute def RotationalSpeed_rpm :> Real {
    doc "Rotational speed measured in revolutions per minute.";
  }

  attribute def Energy_kWh :> Real {
    doc "Energy measured in kilowatt-hours.";
  }

  attribute def Force_N :> Real {
    doc "Force measured in newtons.";
  }

  enum def DryerOperatingMode {
    enum off;
    enum standby;
    enum programSelection;
    enum doorLocked;
    enum drying;
    enum cooldown;
    enum complete;
    enum fault;
  }

  enum def DryingProgramKind {
    enum normalCotton;
    enum delicate;
    enum synthetic;
    enum towelHeavy;
    enum timedWarm;
    enum airFluff;
    enum ecoSensorDry;
  }

  enum def UserCommandKind {
    enum powerOn;
    enum powerOff;
    enum selectProgram;
    enum start;
    enum pause;
    enum resume;
    enum cancel;
    enum openDoor;
    enum closeDoor;
  }

  enum def FaultKind {
    enum none;
    enum doorOpenDuringRun;
    enum overTemperature;
    enum blockedAirflow;
    enum motorStall;
    enum heaterRelayStuck;
    enum moistureSensorFailure;
    enum powerInputOutOfRange;
    enum condensateTankFull;
  }

  item def ElectricalPower {
    attribute voltage: Voltage_V;
    attribute current: Current_A;
    attribute frequency: Frequency_Hz;
    attribute availablePower: Power_W;
  }

  item def ControlPower {
    attribute voltage: Voltage_V;
    attribute current: Current_A;
    attribute availablePower: Power_W;
  }

  item def LaundryLoad {
    attribute dryTextileMass: Mass_kg;
    attribute waterMass: Mass_kg;
    attribute moistureRatio: MoistureRatio_kg_per_kg;
    attribute averageTemperature: Temperature_degC;
    attribute maximumSafeTemperature: Temperature_degC;
  }

  item def AirStream {
    attribute temperature: Temperature_degC;
    attribute relativeHumidity: RelativeHumidity_percent;
    attribute volumetricFlowRate: FlowRate_m3_per_s;
    attribute entrainedWaterMassRate: Mass_kg;
  }

  item def Condensate {
    attribute waterMass: Mass_kg;
    attribute temperature: Temperature_degC;
  }

  item def Lint {
    attribute collectedMass: Mass_kg;
  }

  item def UserCommand {
    attribute commandKind: UserCommandKind;
    attribute selectedProgram: DryingProgramKind;
    attribute requestedDryTime: Time_s;
  }

  item def StatusIndication {
    attribute operatingMode: DryerOperatingMode;
    attribute remainingTime: Time_s;
    attribute currentFault: FaultKind;
    attribute finalMoistureEstimate: MoistureRatio_kg_per_kg;
  }

  item def SensorData {
    attribute drumAirTemperature: Temperature_degC;
    attribute exhaustAirTemperature: Temperature_degC;
    attribute exhaustHumidity: RelativeHumidity_percent;
    attribute estimatedLoadMoisture: MoistureRatio_kg_per_kg;
    attribute drumSpeed: RotationalSpeed_rpm;
    attribute doorClosed: Boolean;
    attribute airflowRate: FlowRate_m3_per_s;
    attribute condensateTankFull: Boolean;
    attribute detectedFault: FaultKind;
  }

  item def ActuatorCommand {
    attribute heaterPowerRequest: Power_W;
    attribute blowerSpeedRequest: RotationalSpeed_rpm;
    attribute drumSpeedRequest: RotationalSpeed_rpm;
    attribute doorLockRequest: Boolean;
    attribute drainPumpRequest: Boolean;
  }

  port def ElectricalPowerInPort {
    in item power: ElectricalPower;
  }

  port def ElectricalPowerOutPort {
    out item power: ElectricalPower;
  }

  port def ControlPowerPort {
    in item power: ControlPower;
  }

  port def LaundryAccessPort {
    inout item load: LaundryLoad;
  }

  port def AirInletPort {
    in item air: AirStream;
  }

  port def AirOutletPort {
    out item air: AirStream;
  }

  port def AirTransferInPort {
    in item air: AirStream;
  }

  port def AirTransferOutPort {
    out item air: AirStream;
  }

  port def CondensateOutletPort {
    out item water: Condensate;
  }

  port def LintServicePort {
    out item lint: Lint;
  }

  port def UserCommandInPort {
    in item command: UserCommand;
  }

  port def StatusOutPort {
    out item status: StatusIndication;
  }

  port def SensorDataOutPort {
    out item data: SensorData;
  }

  port def SensorDataInPort {
    in item data: SensorData;
  }

  port def ActuatorCommandOutPort {
    out item command: ActuatorCommand;
  }

  port def ActuatorCommandInPort {
    in item command: ActuatorCommand;
  }

  constraint def FinalMoistureIsAcceptable {
    in finalMoisture: MoistureRatio_kg_per_kg;
    in maximumAllowedMoisture: MoistureRatio_kg_per_kg;
    constraint { finalMoisture <= maximumAllowedMoisture }
  }

  constraint def TextileTemperatureIsSafe {
    in measuredTemperature: Temperature_degC;
    in maximumSafeTemperature: Temperature_degC;
    constraint { measuredTemperature <= maximumSafeTemperature }
  }

  constraint def DryerCapacityIsNotExceeded {
    in dryMass: Mass_kg;
    in ratedCapacity: Mass_kg;
    constraint { dryMass <= ratedCapacity }
  }

  constraint def AirflowIsSufficient {
    in measuredAirflow: FlowRate_m3_per_s;
    in minimumRequiredAirflow: FlowRate_m3_per_s;
    constraint { measuredAirflow >= minimumRequiredAirflow }
  }

  action def AcceptWetLaundry {
    inout item load: LaundryLoad;
    attribute acceptedCapacity: Mass_kg;
    constraint capacityLimit: DryerCapacityIsNotExceeded {
      in dryMass = load.dryTextileMass;
      in ratedCapacity = acceptedCapacity;
    }
  }

  action def HeatProcessAir {
    in item inletAir: AirStream;
    out item heatedAir: AirStream;
    in item command: ActuatorCommand;
    attribute maximumHeaterPower: Power_W;
    constraint safeHeaterPower {
      command.heaterPowerRequest <= maximumHeaterPower
    }
  }

  action def TumbleLaundry {
    inout item load: LaundryLoad;
    in item command: ActuatorCommand;
    attribute nominalTumbleSpeed: RotationalSpeed_rpm;
  }

  action def EvaporateMoisture {
    inout item load: LaundryLoad;
    in item heatedAir: AirStream;
    out item humidAir: AirStream;
    attribute evaporationEnergyUsed: Energy_kWh;
  }

  action def RemoveMoistureFromAir {
    in item humidAir: AirStream;
    out item processedAir: AirStream;
    out item condensate: Condensate;
  }

  action def SenseDryness {
    in item load: LaundryLoad;
    in item exhaustAir: AirStream;
    out item sensorData: SensorData;
  }

  action def CoolLaundry {
    inout item load: LaundryLoad;
    in item ambientAir: AirStream;
    out item exhaustAir: AirStream;
    attribute cooldownDuration: Time_s;
  }

  action def PresentDryLaundry {
    in item dryLoad: LaundryLoad;
    out item status: StatusIndication;
    constraint finalDryness: FinalMoistureIsAcceptable {
      in finalMoisture = dryLoad.moistureRatio;
      in maximumAllowedMoisture = 0.05;
    }
  }

  action def DryLaundryCycle {
    doc "Primary high-level behavior: accept a wet laundry load, circulate heated air through tumbling textiles, remove evaporated moisture, cool the load, and present dry laundry to the user.";
    in item wetLaundry: LaundryLoad;
    in item ambientAir: AirStream;
    in item userCommand: UserCommand;
    out item dryLaundry: LaundryLoad;
    out item exhaustAir: AirStream;
    out item removedCondensate: Condensate;
    out item finalStatus: StatusIndication;

    attribute selectedProgram: DryingProgramKind;
    attribute targetFinalMoisture: MoistureRatio_kg_per_kg = 0.05;
    attribute maximumTextileTemperature: Temperature_degC = 75.0;
    attribute maximumCycleTime: Time_s = 7200.0;

    action acceptLoad: AcceptWetLaundry {
      inout load = wetLaundry;
      acceptedCapacity = 8.0;
    }

    action heatAir: HeatProcessAir {
      in inletAir = ambientAir;
      maximumHeaterPower = 5200.0;
    }

    action tumble: TumbleLaundry {
      inout load = wetLaundry;
      nominalTumbleSpeed = 52.0;
    }

    action evaporate: EvaporateMoisture {
      inout load = wetLaundry;
    }

    action removeMoisture: RemoveMoistureFromAir;

    action sense: SenseDryness;

    action cool: CoolLaundry {
      inout load = wetLaundry;
      cooldownDuration = 300.0;
    }

    action present: PresentDryLaundry {
      in dryLoad = dryLaundry;
    }

    succession acceptLoad then heatAir;
    succession heatAir then tumble;
    succession tumble then evaporate;
    succession evaporate then removeMoisture;
    succession removeMoisture then sense;
    succession sense then cool;
    succession cool then present;
  }

  state def ClothesDryerOperatingStateMachine {
    attribute mode: DryerOperatingMode;
    attribute activeFault: FaultKind;

    entry action initialize {
      mode = DryerOperatingMode::off;
      activeFault = FaultKind::none;
    }

    state off;
    state standby;
    state selectingProgram;
    state doorSecured;
    state running {
      state warmUp;
      state moistureExtraction;
      state sensorDryEvaluation;
      state cooldown;

      transition first warmUp;
      transition warmUp_to_moistureExtraction
        first warmUp
        then moistureExtraction;

      transition moistureExtraction_to_sensorDryEvaluation
        first moistureExtraction
        then sensorDryEvaluation;

      transition sensorDryEvaluation_to_moistureExtraction
        first sensorDryEvaluation
        then moistureExtraction
        if estimatedMoistureAboveTarget;

      transition sensorDryEvaluation_to_cooldown
        first sensorDryEvaluation
        then cooldown
        if estimatedMoistureAtOrBelowTarget;
    }
    state complete;
    state paused;
    state faulted;

    attribute estimatedMoistureAboveTarget: Boolean;
    attribute estimatedMoistureAtOrBelowTarget: Boolean;
    attribute doorClosed: Boolean;
    attribute startRequested: Boolean;
    attribute pauseRequested: Boolean;
    attribute cancelRequested: Boolean;
    attribute faultDetected: Boolean;

    transition initial_to_off first off;

    transition off_to_standby
      first off
      then standby
      accept UserCommandKind::powerOn;

    transition standby_to_selectingProgram
      first standby
      then selectingProgram
      accept UserCommandKind::selectProgram;

    transition selectingProgram_to_doorSecured
      first selectingProgram
      then doorSecured
      if doorClosed;

    transition doorSecured_to_running
      first doorSecured
      then running
      accept UserCommandKind::start;

    transition running_to_paused
      first running
      then paused
      accept UserCommandKind::pause;

    transition paused_to_running
      first paused
      then running
      accept UserCommandKind::resume;

    transition running_to_complete
      first running
      then complete
      if estimatedMoistureAtOrBelowTarget;

    transition complete_to_standby
      first complete
      then standby
      accept UserCommandKind::openDoor;

    transition any_to_faulted_from_running
      first running
      then faulted
      if faultDetected;

    transition faulted_to_standby
      first faulted
      then standby
      accept UserCommandKind::cancel;

    transition standby_to_off
      first standby
      then off
      accept UserCommandKind::powerOff;
  }

  part def PowerSubsystem {
    port supplyIn: ElectricalPowerInPort;
    port heaterPowerOut: ElectricalPowerOutPort;
    port motorPowerOut: ElectricalPowerOutPort;
    port controllerPowerOut: ElectricalPowerOutPort;

    attribute nominalInputVoltage: Voltage_V = 240.0;
    attribute nominalFrequency: Frequency_Hz = 60.0;
    attribute maximumInputPower: Power_W = 5600.0;
  }

  part def HeatingSubsystem {
    port powerIn: ElectricalPowerInPort;
    port commandIn: ActuatorCommandInPort;
    port airIn: AirTransferInPort;
    port heatedAirOut: AirTransferOutPort;

    attribute maximumHeatingPower: Power_W = 5200.0;
    attribute normalHeatingPower: Power_W = 4200.0;
    attribute maximumOutletTemperature: Temperature_degC = 85.0;
  }

  part def AirMovingSubsystem {
    port powerIn: ElectricalPowerInPort;
    port commandIn: ActuatorCommandInPort;
    port ambientAirIn: AirInletPort;
    port recirculationAirIn: AirTransferInPort;
    port processAirOut: AirTransferOutPort;

    attribute nominalBlowerSpeed: RotationalSpeed_rpm = 1800.0;
    attribute minimumDryingAirflow: FlowRate_m3_per_s = 0.08;
    attribute nominalDryingAirflow: FlowRate_m3_per_s = 0.14;
  }

  part def DrumAssembly {
    port laundryAccess: LaundryAccessPort;
    port powerIn: ElectricalPowerInPort;
    port commandIn: ActuatorCommandInPort;
    port heatedAirIn: AirTransferInPort;
    port humidAirOut: AirTransferOutPort;
    port lintOut: LintServicePort;

    attribute internalVolume: Real = 0.12;
    attribute nominalTumbleSpeed: RotationalSpeed_rpm = 52.0;
    attribute reverseTumbleInterval: Time_s = 90.0;
    attribute ratedDryTextileCapacity: Mass_kg = 8.0;
  }

  part def MoistureRemovalSubsystem {
    port humidAirIn: AirTransferInPort;
    port driedAirOut: AirTransferOutPort;
    port exhaustAirOut: AirOutletPort;
    port condensateOut: CondensateOutletPort;
    port commandIn: ActuatorCommandInPort;

    attribute condensationEfficiency: Real = 0.82;
    attribute maximumCondensateCapacity: Mass_kg = 4.0;
    attribute nominalRemovedWaterPerCycle: Mass_kg = 2.5;
  }

  part def DoorAssembly {
    port commandIn: ActuatorCommandInPort;
    port statusOut: SensorDataOutPort;
    port laundryAccess: LaundryAccessPort;

    attribute sealCompressionForce: Force_N = 120.0;
    attribute lockEngaged: Boolean;
    attribute closed: Boolean;
  }

  part def SensorSuite {
    port drumAirSampleIn: AirTransferInPort;
    port exhaustAirSampleIn: AirTransferInPort;
    port loadInterface: LaundryAccessPort;
    port dataOut: SensorDataOutPort;

    attribute moistureMeasurementResolution: MoistureRatio_kg_per_kg = 0.005;
    attribute temperatureMeasurementResolution: Temperature_degC = 0.5;
    attribute airflowMeasurementResolution: FlowRate_m3_per_s = 0.005;
  }

  part def ControlUnit {
    port powerIn: ElectricalPowerInPort;
    port userCommandIn: UserCommandInPort;
    port sensorDataIn: SensorDataInPort;
    port actuatorCommandOut: ActuatorCommandOutPort;
    port statusOut: StatusOutPort;

    attribute controlLoopPeriod: Time_s = 1.0;
    attribute targetNormalMoisture: MoistureRatio_kg_per_kg = 0.05;
    attribute targetDelicateMoisture: MoistureRatio_kg_per_kg = 0.08;
    attribute maximumAllowedTemperature: Temperature_degC = 75.0;

    exhibit state operatingState: ClothesDryerOperatingStateMachine;
  }

  part def UserInterface {
    port commandOut: UserCommandInPort;
    port statusIn: StatusOutPort;

    attribute displayRemainingTime: Time_s;
    attribute selectedProgram: DryingProgramKind;
    attribute indicatedFault: FaultKind;
  }

  part def SafetySubsystem {
    port sensorDataIn: SensorDataInPort;
    port commandOut: ActuatorCommandOutPort;

    attribute highLimitCutoffTemperature: Temperature_degC = 95.0;
    attribute minimumSafeAirflow: FlowRate_m3_per_s = 0.05;
    attribute doorMustBeLockedDuringRun: Boolean = true;
  }

  part def ClothesDryer {
    doc "A clothes dryer is an appliance whose primary function is to transform a wet laundry load into a dry laundry load by tumbling the textiles while moving heated air through them and removing evaporated moisture.";

    port electricalSupply: ElectricalPowerInPort;
    port laundryDoor: LaundryAccessPort;
    port ambientAirIn: AirInletPort;
    port exhaustAirOut: AirOutletPort;
    port condensateDrain: CondensateOutletPort;
    port userCommandIn: UserCommandInPort;
    port userStatusOut: StatusOutPort;
    port lintService: LintServicePort;

    attribute ratedDryTextileCapacity: Mass_kg = 8.0;
    attribute nominalInputVoltage: Voltage_V = 240.0;
    attribute nominalElectricalFrequency: Frequency_Hz = 60.0;
    attribute maximumElectricalPower: Power_W = 5600.0;
    attribute nominalCycleEnergy: Energy_kWh = 3.2;
    attribute targetFinalMoisture: MoistureRatio_kg_per_kg = 0.05;
    attribute nominalFinalMoisture: MoistureRatio_kg_per_kg = 0.04;
    attribute maximumTextileTemperature: Temperature_degC = 75.0;
    attribute nominalCycleTime: Time_s = 3600.0;

    part powerSubsystem: PowerSubsystem;
    part heater: HeatingSubsystem;
    part blower: AirMovingSubsystem;
    part drum: DrumAssembly;
    part moistureRemoval: MoistureRemovalSubsystem;
    part door: DoorAssembly;
    part sensors: SensorSuite;
    part controller: ControlUnit;
    part userInterface: UserInterface;
    part safety: SafetySubsystem;

    perform action primaryDryingFunction: DryLaundryCycle;

    exhibit state lifecycle: ClothesDryerOperatingStateMachine;

    connect electricalSupply to powerSubsystem.supplyIn;
    connect powerSubsystem.heaterPowerOut to heater.powerIn;
    connect powerSubsystem.motorPowerOut to blower.powerIn;
    connect powerSubsystem.motorPowerOut to drum.powerIn;
    connect powerSubsystem.controllerPowerOut to controller.powerIn;

    connect userCommandIn to controller.userCommandIn;
    connect userInterface.commandOut to controller.userCommandIn;
    connect controller.statusOut to userStatusOut;
    connect controller.statusOut to userInterface.statusIn;

    connect controller.actuatorCommandOut to heater.commandIn;
    connect controller.actuatorCommandOut to blower.commandIn;
    connect controller.actuatorCommandOut to drum.commandIn;
    connect controller.actuatorCommandOut to door.commandIn;
    connect controller.actuatorCommandOut to moistureRemoval.commandIn;

    connect safety.commandOut to heater.commandIn;
    connect safety.commandOut to blower.commandIn;
    connect safety.commandOut to drum.commandIn;

    connect ambientAirIn to blower.ambientAirIn;
    connect blower.processAirOut to heater.airIn;
    connect heater.heatedAirOut to drum.heatedAirIn;
    connect drum.humidAirOut to moistureRemoval.humidAirIn;
    connect moistureRemoval.driedAirOut to blower.recirculationAirIn;
    connect moistureRemoval.exhaustAirOut to exhaustAirOut;
    connect moistureRemoval.condensateOut to condensateDrain;

    connect laundryDoor to door.laundryAccess;
    connect door.laundryAccess to drum.laundryAccess;
    connect drum.lintOut to lintService;

    connect drum.humidAirOut to sensors.drumAirSampleIn;
    connect moistureRemoval.exhaustAirOut to sensors.exhaustAirSampleIn;
    connect drum.laundryAccess to sensors.loadInterface;
    connect sensors.dataOut to controller.sensorDataIn;
    connect sensors.dataOut to safety.sensorDataIn;

    constraint capacity: DryerCapacityIsNotExceeded {
      in dryMass = 8.0;
      in ratedCapacity = ratedDryTextileCapacity;
    }

    constraint finalMoisture: FinalMoistureIsAcceptable {
      in finalMoisture = nominalFinalMoisture;
      in maximumAllowedMoisture = targetFinalMoisture;
    }

    constraint textileTemperatureSafety: TextileTemperatureIsSafe {
      in measuredTemperature = maximumTextileTemperature;
      in maximumSafeTemperature = 75.0;
    }
  }

  requirement def PrimaryFunctionRequirement {
    doc "The system shall dry clothes by converting a wet laundry load into a dry laundry load at a high level through controlled tumbling, heated airflow, moisture removal, cooling, and user notification.";
    subject dryer: ClothesDryer;
    require constraint {
      dryer.nominalFinalMoisture <= dryer.targetFinalMoisture
    }
  }

  requirement def LoadCapacityRequirement {
    doc "The dryer shall accept and dry a laundry load with dry textile mass up to its rated capacity.";
    subject dryer: ClothesDryer;
    require constraint {
      dryer.ratedDryTextileCapacity >= 8.0
    }
  }

  requirement def TextileProtectionRequirement {
    doc "The dryer shall limit normal cycle textile temperature to protect common fabrics.";
    subject dryer: ClothesDryer;
    require constraint {
      dryer.maximumTextileTemperature <= 75.0
    }
  }

  requirement def PowerCompatibilityRequirement {
    doc "The dryer shall operate from a nominal residential electric supply.";
    subject dryer: ClothesDryer;
    require constraint {
      dryer.nominalInputVoltage == 240.0 and dryer.nominalElectricalFrequency == 60.0
    }
  }

  requirement def MoistureRemovalRequirement {
    doc "The dryer shall remove water from the laundry load by evaporation into process air and discharge the removed moisture as exhaust air and/or condensate.";
    subject dryer: ClothesDryer;
    require constraint {
      dryer.targetFinalMoisture <= 0.05
    }
  }

  requirement def UserNotificationRequirement {
    doc "The dryer shall indicate cycle status, remaining time, completion, and detected fault conditions to the user.";
    subject dryer: ClothesDryer;
    require constraint {
      dryer.nominalCycleTime <= 7200.0
    }
  }

  requirement def SafetyInterlockRequirement {
    doc "The dryer shall inhibit heater and drum operation when the door is not closed and locked during a drying cycle.";
    subject dryer: ClothesDryer;
    require constraint {
      dryer.safety.doorMustBeLockedDuringRun == true
    }
  }

  requirement def AirflowSafetyRequirement {
    doc "The dryer shall detect inadequate airflow and command a safe shutdown to reduce overheating risk.";
    subject dryer: ClothesDryer;
    require constraint {
      dryer.safety.minimumSafeAirflow >= 0.05
    }
  }

  part domesticClothesDryer: ClothesDryer;

  requirement primaryFunction: PrimaryFunctionRequirement {
    subject dryer = domesticClothesDryer;
  }

  requirement capacity: LoadCapacityRequirement {
    subject dryer = domesticClothesDryer;
  }

  requirement textileProtection: TextileProtectionRequirement {
    subject dryer = domesticClothesDryer;
  }

  requirement powerCompatibility: PowerCompatibilityRequirement {
    subject dryer = domesticClothesDryer;
  }

  requirement moistureRemoval: MoistureRemovalRequirement {
    subject dryer = domesticClothesDryer;
  }

  requirement userNotification: UserNotificationRequirement {
    subject dryer = domesticClothesDryer;
  }

  requirement safetyInterlock: SafetyInterlockRequirement {
    subject dryer = domesticClothesDryer;
  }

  requirement airflowSafety: AirflowSafetyRequirement {
    subject dryer = domesticClothesDryer;
  }
}
