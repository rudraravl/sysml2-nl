package PumpingSubsystemModel {

  import ScalarValues::*;
  import SI::*;
  import ISQ::*;

  attribute def Volume :> ISQ::volume {
    doc "Fluid volume."
  }

  attribute def Pressure :> ISQ::pressure {
    doc "Fluid pressure."
  }

  attribute def Temperature :> ISQ::thermodynamicTemperature {
    doc "Fluid temperature."
  }

  attribute def MassDensity :> ISQ::massDensity {
    doc "Fluid mass per unit volume."
  }

  attribute def DynamicViscosity :> ISQ::dynamicViscosity {
    doc "Fluid dynamic viscosity."
  }

  attribute def VolumetricFlowRate :> ISQ::volumeFlowRate {
    doc "Fluid volume transferred per unit time."
  }

  attribute def Frequency :> ISQ::frequency {
    doc "Pump stroke frequency."
  }

  attribute def ElectricPotential :> ISQ::electricPotential {
    doc "Electrical supply voltage."
  }

  attribute def ElectricCurrent :> ISQ::electricCurrent {
    doc "Electrical current."
  }

  attribute def Power :> ISQ::power {
    doc "Electrical or hydraulic power."
  }

  attribute def Time :> ISQ::time {
    doc "Elapsed time or duration."
  }

  attribute def Ratio :> ScalarValues::Real {
    doc "Dimensionless ratio."
  }

  attribute def BooleanStatus :> ScalarValues::Boolean {
    doc "Boolean status value."
  }

  attribute def StrokeCount :> ScalarValues::Integer {
    doc "Number of completed metering-pump strokes."
  }

  enum def PumpMode {
    enum idle;
    enum priming;
    enum metering;
    enum flushing;
    enum faulted;
    enum shutdown;
  }

  enum def ValvePosition {
    enum closed;
    enum open;
    enum throttled;
  }

  enum def FluidKind {
    enum water;
    enum additive;
    enum processChemical;
    enum cleaningFluid;
  }

  enum def AlarmSeverity {
    enum advisory;
    enum warning;
    enum trip;
  }

  item def Fluid {
    attribute kind : FluidKind;
    attribute density : MassDensity;
    attribute viscosity : DynamicViscosity;
    attribute temperature : Temperature;
    attribute suspendedGasRatio : Ratio;
  }

  item def MeteredFluid :> Fluid {
    attribute commandedBatchVolume : Volume;
    attribute deliveredBatchVolume : Volume;
    attribute additiveConcentration : Ratio;
  }

  item def ElectricalEnergy {
    attribute voltage : ElectricPotential;
    attribute current : ElectricCurrent;
    attribute availablePower : Power;
  }

  item def ControlCommand {
    attribute requestedMode : PumpMode;
    attribute commandedFlowRate : VolumetricFlowRate;
    attribute commandedBatchVolume : Volume;
    attribute enable : BooleanStatus;
    attribute resetFault : BooleanStatus;
  }

  item def PumpStatus {
    attribute actualMode : PumpMode;
    attribute measuredFlowRate : VolumetricFlowRate;
    attribute inletPressure : Pressure;
    attribute outletPressure : Pressure;
    attribute strokeFrequency : Frequency;
    attribute completedStrokes : StrokeCount;
    attribute faultActive : BooleanStatus;
  }

  item def Alarm {
    attribute severity : AlarmSeverity;
    attribute active : BooleanStatus;
    attribute messageCode : ScalarValues::String;
  }

  port def FluidPort {
    inout item fluid : Fluid;
    attribute pressure : Pressure;
    attribute flowRate : VolumetricFlowRate;
    attribute temperature : Temperature;
  }

  port def MeteredFluidPort :> FluidPort {
    inout item meteredFluid : MeteredFluid;
  }

  port def PowerPort {
    in item supply : ElectricalEnergy;
    attribute voltage : ElectricPotential;
    attribute current : ElectricCurrent;
  }

  port def ControlInputPort {
    in item command : ControlCommand;
  }

  port def StatusOutputPort {
    out item status : PumpStatus;
    out item alarm : Alarm;
  }

  port def SensorSignalPort {
    out attribute measuredPressure : Pressure;
    out attribute measuredFlowRate : VolumetricFlowRate;
    out attribute valid : BooleanStatus;
  }

  port def ActuatorCommandPort {
    in attribute requestedPosition : ValvePosition;
    in attribute requestedStrokeFrequency : Frequency;
    in attribute enabled : BooleanStatus;
  }

  interface def FluidTransfer {
    end source : FluidPort;
    end target : FluidPort;
    flow item transferredFluid : Fluid from source to target;
  }

  interface def MeteredFluidTransfer :> FluidTransfer {
    end meteringSource : MeteredFluidPort;
    end meteringTarget : MeteredFluidPort;
    flow item transferredMeteredFluid : MeteredFluid from meteringSource to meteringTarget;
  }

  interface def ElectricalSupplyInterface {
    end provider : PowerPort;
    end consumer : PowerPort;
    flow item suppliedEnergy : ElectricalEnergy from provider to consumer;
  }

  interface def CommandInterface {
    end controller : ControlInputPort;
    end controlled : ControlInputPort;
    flow item command : ControlCommand from controller to controlled;
  }

  interface def StatusInterface {
    end monitored : StatusOutputPort;
    end monitor : StatusOutputPort;
    flow item status : PumpStatus from monitored to monitor;
    flow item alarm : Alarm from monitored to monitor;
  }

  action def OpenValve {
    in portCommand : ActuatorCommandPort;
    out position : ValvePosition;
    do action setOpen;
  }

  action def CloseValve {
    in portCommand : ActuatorCommandPort;
    out position : ValvePosition;
    do action setClosed;
  }

  action def PrimeMeteringPump {
    in inletAvailable : BooleanStatus;
    in requestedPrimeTime : Time;
    out primed : BooleanStatus;
    out displacedVolume : Volume;
    do action openInletPath;
    then action runLowSpeedStrokes;
    then action verifyOutletWetted;
  }

  action def MeterFluidAction {
    in command : ControlCommand;
    in inletFluid : MeteredFluid;
    out outletFluid : MeteredFluid;
    out status : PumpStatus;
    do action computeStrokeFrequency;
    then action energizePumpMotor;
    then action displaceMeteredVolume;
    then action measureDeliveredFlow;
    then action publishStatus;
  }

  action def StopPumpAction {
    in reasonCode : ScalarValues::String;
    out stopped : BooleanStatus;
    do action disableMotorDrive;
    then action closeIsolationValves;
    then action reportStoppedStatus;
  }

  action def DetectPumpFaults {
    in status : PumpStatus;
    in minimumInletPressure : Pressure;
    in maximumOutletPressure : Pressure;
    in minimumMeasuredFlowRate : VolumetricFlowRate;
    out alarm : Alarm;
    out tripRequired : BooleanStatus;
    do action compareInletPressure;
    then action compareOutletPressure;
    then action compareFlowAgainstCommand;
    then action setAlarmIfRequired;
  }

  state def PumpingSubsystemStateMachine {
    attribute currentMode : PumpMode;

    state off;
    state standby;
    state priming;
    state metering;
    state flushing;
    state faulted;
    state shutdown;

    transition initial_to_off first start then off;

    transition off_to_standby
      first off
      accept ControlCommand
      if enable == true
      do action initializeElectronics
      then standby;

    transition standby_to_priming
      first standby
      accept ControlCommand
      if requestedMode == PumpMode::priming
      do PrimeMeteringPump
      then priming;

    transition priming_to_metering
      first priming
      accept ControlCommand
      if requestedMode == PumpMode::metering
      do MeterFluidAction
      then metering;

    transition standby_to_metering
      first standby
      accept ControlCommand
      if requestedMode == PumpMode::metering
      do MeterFluidAction
      then metering;

    transition metering_self_regulation
      first metering
      accept ControlCommand
      if requestedMode == PumpMode::metering
      do MeterFluidAction
      then metering;

    transition metering_to_flushing
      first metering
      accept ControlCommand
      if requestedMode == PumpMode::flushing
      do action replaceProcessFluidWithCleaningFluid
      then flushing;

    transition flushing_to_standby
      first flushing
      accept ControlCommand
      if requestedMode == PumpMode::idle
      do StopPumpAction
      then standby;

    transition any_to_faulted
      first standby
      accept Alarm
      if active == true and severity == AlarmSeverity::trip
      do StopPumpAction
      then faulted;

    transition metering_to_faulted
      first metering
      accept Alarm
      if active == true and severity == AlarmSeverity::trip
      do StopPumpAction
      then faulted;

    transition priming_to_faulted
      first priming
      accept Alarm
      if active == true and severity == AlarmSeverity::trip
      do StopPumpAction
      then faulted;

    transition faulted_to_standby
      first faulted
      accept ControlCommand
      if resetFault == true
      do action clearLatchedFaults
      then standby;

    transition standby_to_shutdown
      first standby
      accept ControlCommand
      if enable == false
      do StopPumpAction
      then shutdown;

    transition shutdown_to_off
      first shutdown
      do action removeInternalPower
      then off;
  }

  part def FluidReservoir {
    port outlet : FluidPort;
    attribute usableVolume : Volume;
    attribute staticHeadPressure : Pressure;
    attribute fluidInventory : MeteredFluid;
  }

  part def SuctionStrainer {
    port inlet : FluidPort;
    port outlet : FluidPort;
    attribute cleanPressureDrop : Pressure;
    attribute cloggedPressureDropLimit : Pressure;
    attribute clogged : BooleanStatus;
  }

  part def IsolationValve {
    port inlet : FluidPort;
    port outlet : FluidPort;
    port actuator : ActuatorCommandPort;
    attribute position : ValvePosition;
    attribute fullOpenPressureDrop : Pressure;
    action open : OpenValve;
    action close : CloseValve;
  }

  part def CheckValve {
    port inlet : FluidPort;
    port outlet : FluidPort;
    attribute crackingPressure : Pressure;
    attribute reverseLeakageRate : VolumetricFlowRate;
    attribute open : BooleanStatus;
  }

  part def PulsationDamper {
    port inlet : FluidPort;
    port outlet : FluidPort;
    attribute gasPrechargePressure : Pressure;
    attribute effectiveVolume : Volume;
    attribute rippleAttenuationRatio : Ratio;
  }

  part def PressureSensor {
    port process : FluidPort;
    port signal : SensorSignalPort;
    attribute rangeMinimum : Pressure;
    attribute rangeMaximum : Pressure;
    attribute accuracy : Ratio;
    attribute measuredPressure : Pressure;
  }

  part def FlowMeter {
    port inlet : FluidPort;
    port outlet : FluidPort;
    port signal : SensorSignalPort;
    attribute rangeMinimum : VolumetricFlowRate;
    attribute rangeMaximum : VolumetricFlowRate;
    attribute accuracy : Ratio;
    attribute measuredFlowRate : VolumetricFlowRate;
  }

  part def MotorDrive {
    port powerIn : PowerPort;
    port commandIn : ControlInputPort;
    port actuatorOut : ActuatorCommandPort;
    port statusOut : StatusOutputPort;
    attribute inputVoltage : ElectricPotential;
    attribute maximumCurrent : ElectricCurrent;
    attribute commandedStrokeFrequency : Frequency;
    attribute enabled : BooleanStatus;
  }

  part def PumpController {
    port operatorCommandIn : ControlInputPort;
    port pumpCommandOut : ControlInputPort;
    port valveCommandOut : ActuatorCommandPort;
    port statusIn : StatusOutputPort;
    port statusOut : StatusOutputPort;
    attribute commandedFlowRate : VolumetricFlowRate;
    attribute commandedBatchVolume : Volume;
    attribute minimumAllowedInletPressure : Pressure;
    attribute maximumAllowedOutletPressure : Pressure;
    attribute lowFlowTripDelay : Time;
    action faultDetection : DetectPumpFaults;
  }

  part def MeteringPump {
    port inlet : MeteredFluidPort;
    port outlet : MeteredFluidPort;
    port powerIn : PowerPort;
    port commandIn : ControlInputPort;
    port statusOut : StatusOutputPort;

    attribute displacementPerStroke : Volume;
    attribute minimumStrokeFrequency : Frequency;
    attribute maximumStrokeFrequency : Frequency;
    attribute commandedStrokeFrequency : Frequency;
    attribute actualStrokeFrequency : Frequency;
    attribute volumetricEfficiency : Ratio;
    attribute maximumOutletPressure : Pressure;
    attribute minimumRequiredInletPressure : Pressure;
    attribute deliveredFlowRate : VolumetricFlowRate;
    attribute completedStrokes : StrokeCount;
    attribute primed : BooleanStatus;
    attribute running : BooleanStatus;

    action prime : PrimeMeteringPump;
    action meter : MeterFluidAction;
    action stop : StopPumpAction;

    state machine behavior : PumpingSubsystemStateMachine;
  }

  part def DischargeLine {
    port inlet : FluidPort;
    port outlet : FluidPort;
    attribute lineVolume : Volume;
    attribute ratedPressure : Pressure;
    attribute nominalPressureDrop : Pressure;
  }

  part def ElectricalPowerSupply {
    port output : PowerPort;
    attribute nominalVoltage : ElectricPotential;
    attribute maximumCurrent : ElectricCurrent;
    attribute availablePower : Power;
  }

  part def PumpingSubsystem {
    port fluidIn : MeteredFluidPort;
    port fluidOut : MeteredFluidPort;
    port electricalIn : PowerPort;
    port commandIn : ControlInputPort;
    port statusOut : StatusOutputPort;

    attribute requiredFlowRate : VolumetricFlowRate;
    attribute actualFlowRate : VolumetricFlowRate;
    attribute requiredBatchVolume : Volume;
    attribute deliveredBatchVolume : Volume;
    attribute inletPressure : Pressure;
    attribute outletPressure : Pressure;
    attribute maximumPermittedOutletPressure : Pressure;
    attribute minimumPermittedInletPressure : Pressure;
    attribute flowAccuracy : Ratio;
    attribute availabilityStatus : BooleanStatus;

    part supplyReservoir : FluidReservoir {
      attribute usableVolume = 50 [SI::l];
      attribute staticHeadPressure = 18 [SI::kPa];
    }

    part suctionStrainer : SuctionStrainer {
      attribute cleanPressureDrop = 2 [SI::kPa];
      attribute cloggedPressureDropLimit = 15 [SI::kPa];
      attribute clogged = false;
    }

    part inletIsolationValve : IsolationValve {
      attribute position = ValvePosition::closed;
      attribute fullOpenPressureDrop = 1 [SI::kPa];
    }

    part inletCheckValve : CheckValve {
      attribute crackingPressure = 3 [SI::kPa];
      attribute reverseLeakageRate = 0.001 [SI::l / SI::min];
      attribute open = false;
    }

    part meteringPump : MeteringPump {
      attribute displacementPerStroke = 0.25 [SI::ml];
      attribute minimumStrokeFrequency = 5 [SI::Hz];
      attribute maximumStrokeFrequency = 40 [SI::Hz];
      attribute volumetricEfficiency = 0.96;
      attribute maximumOutletPressure = 700 [SI::kPa];
      attribute minimumRequiredInletPressure = 10 [SI::kPa];
      attribute primed = false;
      attribute running = false;
    }

    part dischargeCheckValve : CheckValve {
      attribute crackingPressure = 5 [SI::kPa];
      attribute reverseLeakageRate = 0.0005 [SI::l / SI::min];
      attribute open = false;
    }

    part pulsationDamper : PulsationDamper {
      attribute gasPrechargePressure = 250 [SI::kPa];
      attribute effectiveVolume = 0.2 [SI::l];
      attribute rippleAttenuationRatio = 0.85;
    }

    part outletIsolationValve : IsolationValve {
      attribute position = ValvePosition::closed;
      attribute fullOpenPressureDrop = 1 [SI::kPa];
    }

    part dischargeLine : DischargeLine {
      attribute lineVolume = 0.75 [SI::l];
      attribute ratedPressure = 1000 [SI::kPa];
      attribute nominalPressureDrop = 4 [SI::kPa];
    }

    part inletPressureSensor : PressureSensor {
      attribute rangeMinimum = 0 [SI::kPa];
      attribute rangeMaximum = 300 [SI::kPa];
      attribute accuracy = 0.01;
    }

    part outletPressureSensor : PressureSensor {
      attribute rangeMinimum = 0 [SI::kPa];
      attribute rangeMaximum = 1000 [SI::kPa];
      attribute accuracy = 0.01;
    }

    part dischargeFlowMeter : FlowMeter {
      attribute rangeMinimum = 0 [SI::l / SI::min];
      attribute rangeMaximum = 2.5 [SI::l / SI::min];
      attribute accuracy = 0.015;
    }

    part motorDrive : MotorDrive {
      attribute inputVoltage = 24 [SI::V];
      attribute maximumCurrent = 4 [SI::A];
      attribute enabled = false;
    }

    part controller : PumpController {
      attribute commandedFlowRate = 1.0 [SI::l / SI::min];
      attribute commandedBatchVolume = 10 [SI::l];
      attribute minimumAllowedInletPressure = 10 [SI::kPa];
      attribute maximumAllowedOutletPressure = 700 [SI::kPa];
      attribute lowFlowTripDelay = 3 [SI::s];
    }

    connect fluidIn to supplyReservoir.outlet;
    connect supplyReservoir.outlet to suctionStrainer.inlet;
    connect suctionStrainer.outlet to inletIsolationValve.inlet;
    connect inletIsolationValve.outlet to inletCheckValve.inlet;
    connect inletCheckValve.outlet to meteringPump.inlet;
    connect meteringPump.outlet to dischargeCheckValve.inlet;
    connect dischargeCheckValve.outlet to pulsationDamper.inlet;
    connect pulsationDamper.outlet to outletPressureSensor.process;
    connect outletPressureSensor.process to outletIsolationValve.inlet;
    connect outletIsolationValve.outlet to dischargeFlowMeter.inlet;
    connect dischargeFlowMeter.outlet to dischargeLine.inlet;
    connect dischargeLine.outlet to fluidOut;

    connect inletPressureSensor.process to meteringPump.inlet;
    connect dischargeFlowMeter.signal to controller.statusIn;
    connect inletPressureSensor.signal to controller.statusIn;
    connect outletPressureSensor.signal to controller.statusIn;

    connect electricalIn to motorDrive.powerIn;
    connect motorDrive.actuatorOut to meteringPump.commandIn;
    connect commandIn to controller.operatorCommandIn;
    connect controller.pumpCommandOut to meteringPump.commandIn;
    connect controller.valveCommandOut to inletIsolationValve.actuator;
    connect controller.valveCommandOut to outletIsolationValve.actuator;
    connect meteringPump.statusOut to controller.statusIn;
    connect controller.statusOut to statusOut;

    bind actualFlowRate = dischargeFlowMeter.measuredFlowRate;
    bind inletPressure = inletPressureSensor.measuredPressure;
    bind outletPressure = outletPressureSensor.measuredPressure;

    perform action startupSequence {
      first action verifyElectricalPower;
      then action openInletIsolationValve;
      then action openOutletIsolationValve;
      then action primeMeteringPump;
      then action enterStandby;
    }

    perform action meteredTransfer {
      first action receiveCommand;
      then action computeRequiredStrokeFrequency;
      then action runMeteringPump;
      then action monitorPressureAndFlow;
      then action accumulateDeliveredVolume;
      then action stopAtBatchVolume;
    }

    perform action safeShutdown {
      first action stopMeteringPump;
      then action closeOutletIsolationValve;
      then action closeInletIsolationValve;
      then action publishShutdownStatus;
    }
  }

  part def PumpingSubsystemInstallation {
    part powerSupply : ElectricalPowerSupply {
      attribute nominalVoltage = 24 [SI::V];
      attribute maximumCurrent = 5 [SI::A];
      attribute availablePower = 120 [SI::W];
    }

    part pumpingSubsystem : PumpingSubsystem {
      attribute requiredFlowRate = 1.0 [SI::l / SI::min];
      attribute requiredBatchVolume = 10 [SI::l];
      attribute maximumPermittedOutletPressure = 700 [SI::kPa];
      attribute minimumPermittedInletPressure = 10 [SI::kPa];
      attribute flowAccuracy = 0.02;
      attribute availabilityStatus = true;
    }

    port sourceFluid : MeteredFluidPort;
    port destinationFluid : MeteredFluidPort;
    port operatorCommand : ControlInputPort;
    port subsystemStatus : StatusOutputPort;

    connect sourceFluid to pumpingSubsystem.fluidIn;
    connect pumpingSubsystem.fluidOut to destinationFluid;
    connect powerSupply.output to pumpingSubsystem.electricalIn;
    connect operatorCommand to pumpingSubsystem.commandIn;
    connect pumpingSubsystem.statusOut to subsystemStatus;
  }

  requirement def PumpingSubsystemRequirement {
    subject subsystem : PumpingSubsystem;

    require constraint {
      subsystem.meteringPump isKindOf MeteringPump
    }

    doc "The pumping subsystem shall move fluid from its fluid inlet to its fluid outlet using a metering pump as the active displacement device."
  }

  requirement def MeteringPumpFlowRequirement {
    subject subsystem : PumpingSubsystem;

    require constraint {
      subsystem.actualFlowRate >= 0 [SI::l / SI::min] and
      subsystem.actualFlowRate <= 2.5 [SI::l / SI::min]
    }

    doc "The metering pump shall deliver a controlled nonnegative flow within the installed measurement range."
  }

  requirement def FlowAccuracyRequirement {
    subject subsystem : PumpingSubsystem;

    require constraint {
      abs(subsystem.actualFlowRate - subsystem.requiredFlowRate) <= subsystem.flowAccuracy * subsystem.requiredFlowRate
    }

    doc "During metering mode, the delivered flow rate shall remain within two percent of the commanded flow rate after priming and stabilization."
  }

  requirement def BatchVolumeRequirement {
    subject subsystem : PumpingSubsystem;

    require constraint {
      abs(subsystem.deliveredBatchVolume - subsystem.requiredBatchVolume) <= 0.02 * subsystem.requiredBatchVolume
    }

    doc "For a commanded batch transfer, the subsystem shall stop the metering pump when the delivered batch volume is within two percent of the requested batch volume."
  }

  requirement def InletPressureProtectionRequirement {
    subject subsystem : PumpingSubsystem;

    require constraint {
      subsystem.inletPressure >= subsystem.minimumPermittedInletPressure
    }

    doc "The subsystem shall prevent metering operation when measured inlet pressure is below the minimum pressure required to avoid cavitation and loss of prime."
  }

  requirement def OutletPressureProtectionRequirement {
    subject subsystem : PumpingSubsystem;

    require constraint {
      subsystem.outletPressure <= subsystem.maximumPermittedOutletPressure
    }

    doc "The subsystem shall trip the metering pump and close isolation valves if outlet pressure exceeds the maximum permitted discharge pressure."
  }

  requirement def CheckValveBackflowRequirement {
    subject subsystem : PumpingSubsystem;

    require constraint {
      subsystem.dischargeCheckValve.reverseLeakageRate <= 0.0005 [SI::l / SI::min]
    }

    doc "The discharge check valve shall limit reverse flow so the metered volume is not materially reduced after each pump stroke."
  }

  requirement def PrimingRequirement {
    subject subsystem : PumpingSubsystem;

    require constraint {
      subsystem.meteringPump.primed == true implies subsystem.meteringPump.running == true or subsystem.meteringPump.running == false
    }

    doc "The metering pump shall support a priming behavior that wets the pump chamber and discharge path before normal metering operation."
  }

  requirement def SafeShutdownRequirement {
    subject subsystem : PumpingSubsystem;

    require constraint {
      subsystem.inletIsolationValve.position == ValvePosition::closed and
      subsystem.outletIsolationValve.position == ValvePosition::closed
    }

    doc "When commanded to shut down or when a trip-level alarm is active, the subsystem shall stop the metering pump and close the inlet and outlet isolation valves."
  }

  satisfy PumpingSubsystemRequirement by PumpingSubsystem;
  satisfy MeteringPumpFlowRequirement by PumpingSubsystem::meteringPump;
  satisfy FlowAccuracyRequirement by PumpingSubsystem::controller;
  satisfy BatchVolumeRequirement by PumpingSubsystem::controller;
  satisfy InletPressureProtectionRequirement by PumpingSubsystem::inletPressureSensor;
  satisfy OutletPressureProtectionRequirement by PumpingSubsystem::outletPressureSensor;
  satisfy CheckValveBackflowRequirement by PumpingSubsystem::dischargeCheckValve;
  satisfy PrimingRequirement by PumpingSubsystem::meteringPump::prime;
  satisfy SafeShutdownRequirement by PumpingSubsystem::safeShutdown;

}
