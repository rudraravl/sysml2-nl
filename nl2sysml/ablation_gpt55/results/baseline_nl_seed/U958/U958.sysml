package ABBBasedResilientFacilityPowerSystem {
  import ScalarValues::*;
  import ISQ::*;
  import SI::*;

  attribute def Voltage :> ISQ::electricPotential;
  attribute def Current :> ISQ::electricCurrent;
  attribute def Power :> ISQ::power;
  attribute def Energy :> ISQ::energy;
  attribute def Frequency :> ISQ::frequency;
  attribute def Duration :> ISQ::duration;
  attribute def Temperature :> ISQ::thermodynamicTemperature;
  attribute def AvailabilityRatio :> Real;

  enum def PowerSourceKind {
    enum grid;
    enum battery;
    enum generator;
    enum none;
  }

  enum def CommandKind {
    enum closeGridContactor;
    enum openGridContactor;
    enum closeBatteryInverterContactor;
    enum openBatteryInverterContactor;
    enum startGenerator;
    enum stopGenerator;
    enum shedNonCriticalLoad;
    enum restoreLoad;
    enum enterSafeShutdown;
  }

  enum def SourceHealthKind {
    enum healthy;
    enum degraded;
    enum unavailable;
  }

  item def AcElectricalPower {
    attribute rmsVoltage : Voltage = 480 [SI::V];
    attribute rmsCurrent : Current;
    attribute realPower : Power;
    attribute frequency : Frequency = 60 [SI::Hz];
  }

  item def DcElectricalPower {
    attribute dcVoltage : Voltage = 700 [SI::V];
    attribute dcCurrent : Current;
    attribute realPower : Power;
  }

  item def StoredElectricalEnergy {
    attribute remainingEnergy : Energy;
    attribute stateOfCharge : Real;
    attribute packTemperature : Temperature;
  }

  item def MeasurementFrame {
    attribute measuredVoltage : Voltage;
    attribute measuredCurrent : Current;
    attribute measuredPower : Power;
    attribute measuredFrequency : Frequency;
    attribute sampleAge : Duration;
    attribute sourceKind : PowerSourceKind;
    attribute sourceHealth : SourceHealthKind;
  }

  item def SourceHealthReport {
    attribute gridHealth : SourceHealthKind;
    attribute batteryHealth : SourceHealthKind;
    attribute generatorHealth : SourceHealthKind;
    attribute preferredSource : PowerSourceKind;
    attribute estimatedAutonomy : Duration;
  }

  item def ControlCommand {
    attribute commandKind : CommandKind;
    attribute selectedSource : PowerSourceKind;
    attribute requestedPower : Power;
    attribute executeWithin : Duration;
  }

  item def OperatorMessage {
    attribute activeSource : PowerSourceKind;
    attribute availableAutonomy : Duration;
    attribute deliveredPower : Power;
    attribute alarmPresent : Boolean;
  }

  item def LoadRequest {
    attribute requestedPower : Power;
    attribute criticalityLevel : Integer;
    attribute maximumInterruption : Duration;
  }

  port def AcPowerPort {
    inout item acPower : AcElectricalPower;
  }

  port def DcPowerPort {
    inout item dcPower : DcElectricalPower;
  }

  port def EnergyStoragePort {
    inout item storedEnergy : StoredElectricalEnergy;
  }

  port def MeasurementPort {
    inout item measurement : MeasurementFrame;
  }

  port def HealthReportPort {
    inout item report : SourceHealthReport;
  }

  port def CommandPort {
    inout item command : ControlCommand;
  }

  port def OperatorPort {
    inout item message : OperatorMessage;
  }

  port def LoadRequestPort {
    inout item request : LoadRequest;
  }

  action def MonitorSources {
    in item gridMeasurement : MeasurementFrame;
    in item batteryMeasurement : MeasurementFrame;
    in item generatorMeasurement : MeasurementFrame;
    out item healthReport : SourceHealthReport;
  }

  action def SelectPreferredSource {
    in item healthReport : SourceHealthReport;
    in item loadRequest : LoadRequest;
    out item sourceCommand : ControlCommand;
  }

  action def DispatchPowerPath {
    in item sourceCommand : ControlCommand;
    out item transferSwitchCommand : ControlCommand;
    out item generatorCommand : ControlCommand;
    out item inverterCommand : ControlCommand;
  }

  action def RegulateOutputPower {
    in item rawPower : AcElectricalPower;
    out item conditionedPower : AcElectricalPower;
  }

  action def AnnunciateStatus {
    in item healthReport : SourceHealthReport;
    in item deliveredPower : AcElectricalPower;
    out item operatorMessage : OperatorMessage;
  }

  action def MaintainReliableCriticalPower {
    /*
     * Primary high-level function:
     * maintain continuous, regulated electrical power to critical facility loads by
     * monitoring available sources, selecting the healthiest source, commanding the
     * power path, conditioning output power, and reporting operational status.
     */
    in item sourceMeasurements : MeasurementFrame;
    in item loadRequest : LoadRequest;
    out item deliveredPower : AcElectricalPower;
    out item operatorStatus : OperatorMessage;

    action monitorSources : MonitorSources;
    action selectPreferredSource : SelectPreferredSource;
    action dispatchPowerPath : DispatchPowerPath;
    action regulateOutputPower : RegulateOutputPower;
    action annunciateStatus : AnnunciateStatus;
  }

  event def GridOutage;
  event def GridRestored;
  event def BatteryLow;
  event def GeneratorReady;
  event def GeneratorFault;
  event def CriticalFault;
  event def OperatorReset;

  state def PowerSourceControlStateMachine {
    entry; then gridSupplying;

    state gridSupplying;
    state batteryRideThrough;
    state generatorStarting;
    state generatorSupplying;
    state sourceRecovery;
    state safeShutdown;

    transition gridLoss
      first gridSupplying
      accept GridOutage
      then batteryRideThrough;

    transition batteryReserveLow
      first batteryRideThrough
      accept BatteryLow
      then generatorStarting;

    transition generatorAvailable
      first generatorStarting
      accept GeneratorReady
      then generatorSupplying;

    transition gridReturnsFromBattery
      first batteryRideThrough
      accept GridRestored
      then sourceRecovery;

    transition gridReturnsFromGenerator
      first generatorSupplying
      accept GridRestored
      then sourceRecovery;

    transition recoveryComplete
      first sourceRecovery
      accept OperatorReset
      then gridSupplying;

    transition generatorFails
      first generatorStarting
      accept GeneratorFault
      then batteryRideThrough;

    transition unrecoverableFaultFromGrid
      first gridSupplying
      accept CriticalFault
      then safeShutdown;

    transition unrecoverableFaultFromBattery
      first batteryRideThrough
      accept CriticalFault
      then safeShutdown;

    transition unrecoverableFaultFromGenerator
      first generatorSupplying
      accept CriticalFault
      then safeShutdown;
  }

  abstract part def ArchitectureBuildingBlock {
    attribute abbMaturityLevel : Integer = 3;
    attribute designReuseApproved : Boolean = true;
  }

  part def EnergyContinuityABB :> ArchitectureBuildingBlock {
    /*
     * ABB role:
     * reusable architecture building block for resilient electric-power continuity.
     */
    port utilityInput : AcPowerPort;
    port generatorInput : AcPowerPort;
    port storageInterface : EnergyStoragePort;
    port criticalLoadOutput : AcPowerPort;
    port operatorInterface : OperatorPort;

    attribute nominalFacilityVoltage : Voltage = 480 [SI::V];
    attribute nominalFacilityFrequency : Frequency = 60 [SI::Hz];
    attribute targetTransferDuration : Duration = 2 [SI::s];
    attribute targetAvailability : AvailabilityRatio = 0.9999;

    perform action primaryFunction : MaintainReliableCriticalPower;
  }

  part def GridInterface {
    port acIn : AcPowerPort;
    port acOut : AcPowerPort;
    port measurements : MeasurementPort;

    attribute nominalVoltage : Voltage = 480 [SI::V];
    attribute maximumImportPower : Power = 250000 [SI::W];
    attribute nominalFrequency : Frequency = 60 [SI::Hz];
  }

  part def BatteryEnergyStorageSystem {
    port dcOut : DcPowerPort;
    port energyStatus : EnergyStoragePort;
    port measurements : MeasurementPort;
    port command : CommandPort;

    attribute nominalDcVoltage : Voltage = 700 [SI::V];
    attribute usableEnergyCapacity : Energy = 1800000000 [SI::J];
    attribute maximumDischargePower : Power = 150000 [SI::W];
    attribute minimumStateOfCharge : Real = 0.20;
  }

  part def BidirectionalInverter {
    port dcIn : DcPowerPort;
    port acOut : AcPowerPort;
    port command : CommandPort;
    port measurements : MeasurementPort;

    attribute ratedAcPower : Power = 150000 [SI::W];
    attribute dcInputVoltage : Voltage = 700 [SI::V];
    attribute acOutputVoltage : Voltage = 480 [SI::V];
    attribute outputFrequency : Frequency = 60 [SI::Hz];
  }

  part def StandbyGenerator {
    port fuelCommand : CommandPort;
    port acOut : AcPowerPort;
    port measurements : MeasurementPort;

    attribute ratedPower : Power = 200000 [SI::W];
    attribute outputVoltage : Voltage = 480 [SI::V];
    attribute outputFrequency : Frequency = 60 [SI::Hz];
    attribute startTime : Duration = 15 [SI::s];
  }

  part def StaticTransferSwitch {
    port gridIn : AcPowerPort;
    port generatorIn : AcPowerPort;
    port inverterIn : AcPowerPort;
    port selectedAcOut : AcPowerPort;
    port command : CommandPort;
    port measurements : MeasurementPort;

    attribute maximumTransferDuration : Duration = 2 [SI::s];
    attribute ratedCurrent : Current = 400 [SI::A];
    attribute selectedSource : PowerSourceKind = PowerSourceKind::grid;
  }

  part def PowerConditioner {
    port acIn : AcPowerPort;
    port acOut : AcPowerPort;
    port measurements : MeasurementPort;

    attribute ratedPower : Power = 150000 [SI::W];
    attribute regulatedVoltage : Voltage = 480 [SI::V];
    attribute regulatedFrequency : Frequency = 60 [SI::Hz];
  }

  part def CriticalLoadPanel {
    port acIn : AcPowerPort;
    port loadRequest : LoadRequestPort;
    port measurements : MeasurementPort;

    attribute connectedCriticalLoad : Power = 120000 [SI::W];
    attribute allowableInterruption : Duration = 2 [SI::s];
  }

  part def SensorNetwork {
    port gridSense : MeasurementPort;
    port batterySense : MeasurementPort;
    port generatorSense : MeasurementPort;
    port transferSense : MeasurementPort;
    port conditionerSense : MeasurementPort;
    port loadSense : MeasurementPort;
    port aggregateReport : HealthReportPort;

    attribute maximumSampleAge : Duration = 1 [SI::s];
  }

  part def ResilienceController {
    port healthIn : HealthReportPort;
    port loadRequestIn : LoadRequestPort;
    port transferCommandOut : CommandPort;
    port inverterCommandOut : CommandPort;
    port generatorCommandOut : CommandPort;
    port operatorOut : OperatorPort;

    attribute controlCycle : Duration = 1 [SI::s];
    attribute sourceTransferBudget : Duration = 2 [SI::s];

    perform action maintainPower : MaintainReliableCriticalPower;
    exhibit state sourceControl : PowerSourceControlStateMachine;
  }

  part def OperatorGateway {
    port controllerStatus : OperatorPort;
    port operatorInterface : OperatorPort;

    attribute statusRefreshPeriod : Duration = 5 [SI::s];
  }

  part def ResilientFacilityPowerSystem :> EnergyContinuityABB {
    port gridService : AcPowerPort;
    port generatorService : AcPowerPort;
    port criticalLoadService : AcPowerPort;
    port operatorConsole : OperatorPort;

    attribute ratedCriticalLoadPower : Power = 120000 [SI::W];
    attribute maximumSourceTransferTime : Duration = 2 [SI::s];
    attribute minimumBatteryAutonomy : Duration = 14400 [SI::s];
    attribute deliveredPowerAvailability : AvailabilityRatio = 0.9999;
    attribute nominalOutputVoltage : Voltage = 480 [SI::V];
    attribute nominalOutputFrequency : Frequency = 60 [SI::Hz];

    part gridInterface : GridInterface;
    part battery : BatteryEnergyStorageSystem;
    part inverter : BidirectionalInverter;
    part generator : StandbyGenerator;
    part transferSwitch : StaticTransferSwitch;
    part conditioner : PowerConditioner;
    part loadPanel : CriticalLoadPanel;
    part sensors : SensorNetwork;
    part controller : ResilienceController;
    part operatorGateway : OperatorGateway;

    connection externalGridFeed connect gridService to gridInterface.acIn;
    connection gridToTransfer connect gridInterface.acOut to transferSwitch.gridIn;
    connection externalGeneratorFeed connect generatorService to generator.acOut;
    connection generatorToTransfer connect generator.acOut to transferSwitch.generatorIn;
    connection batteryToInverter connect battery.dcOut to inverter.dcIn;
    connection inverterToTransfer connect inverter.acOut to transferSwitch.inverterIn;
    connection transferToConditioner connect transferSwitch.selectedAcOut to conditioner.acIn;
    connection conditionerToPanel connect conditioner.acOut to loadPanel.acIn;
    connection panelToExternalCriticalLoad connect loadPanel.acIn to criticalLoadService;

    connection gridMeasurement connect gridInterface.measurements to sensors.gridSense;
    connection batteryMeasurement connect battery.measurements to sensors.batterySense;
    connection generatorMeasurement connect generator.measurements to sensors.generatorSense;
    connection transferMeasurement connect transferSwitch.measurements to sensors.transferSense;
    connection conditionerMeasurement connect conditioner.measurements to sensors.conditionerSense;
    connection loadMeasurement connect loadPanel.measurements to sensors.loadSense;

    connection healthReportToController connect sensors.aggregateReport to controller.healthIn;
    connection loadRequestToController connect loadPanel.loadRequest to controller.loadRequestIn;
    connection controllerToTransfer connect controller.transferCommandOut to transferSwitch.command;
    connection controllerToInverter connect controller.inverterCommandOut to inverter.command;
    connection controllerToGenerator connect controller.generatorCommandOut to generator.fuelCommand;
    connection controllerToOperatorGateway connect controller.operatorOut to operatorGateway.controllerStatus;
    connection operatorGatewayToConsole connect operatorGateway.operatorInterface to operatorConsole;
  }

  requirement def PrimaryFunctionRequirement {
    /*
     * The system shall provide the Energy Continuity ABB primary function:
     * continuous regulated power delivery to critical loads through source monitoring,
     * source selection, transfer control, output conditioning, and operator reporting.
     */
    subject system : ResilientFacilityPowerSystem;

    require constraint {
      system.ratedCriticalLoadPower >= 120000 [SI::W]
    }

    require constraint {
      system.nominalOutputVoltage == 480 [SI::V]
    }

    require constraint {
      system.nominalOutputFrequency == 60 [SI::Hz]
    }
  }

  requirement def TransferContinuityRequirement {
    subject system : ResilientFacilityPowerSystem;

    require constraint {
      system.maximumSourceTransferTime <= 2 [SI::s]
    }
  }

  requirement def BatteryAutonomyRequirement {
    subject system : ResilientFacilityPowerSystem;

    require constraint {
      system.minimumBatteryAutonomy >= 14400 [SI::s]
    }
  }

  requirement def AvailabilityRequirement {
    subject system : ResilientFacilityPowerSystem;

    require constraint {
      system.deliveredPowerAvailability >= 0.9999
    }
  }

  requirement primaryFunction : PrimaryFunctionRequirement;
  requirement transferContinuity : TransferContinuityRequirement;
  requirement batteryAutonomy : BatteryAutonomyRequirement;
  requirement availability : AvailabilityRequirement;

  part resilientFacilityPowerSystem : ResilientFacilityPowerSystem;
}
