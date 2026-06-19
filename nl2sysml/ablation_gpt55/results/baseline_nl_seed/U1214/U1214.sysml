package SmartMeterPrimaryFunctionModel {
  import ScalarValues::*;

  attribute def Volt {
    attribute value : Real;
    attribute unit : String = "V";
  }

  attribute def Ampere {
    attribute value : Real;
    attribute unit : String = "A";
  }

  attribute def Hertz {
    attribute value : Real;
    attribute unit : String = "Hz";
  }

  attribute def Watt {
    attribute value : Real;
    attribute unit : String = "W";
  }

  attribute def KilowattHour {
    attribute value : Real;
    attribute unit : String = "kWh";
  }

  attribute def Second {
    attribute value : Real;
    attribute unit : String = "s";
  }

  attribute def Minute {
    attribute value : Real;
    attribute unit : String = "min";
  }

  attribute def Percent {
    attribute value : Real;
    attribute unit : String = "%";
  }

  attribute def DegreeCelsius {
    attribute value : Real;
    attribute unit : String = "degC";
  }

  attribute def Timestamp {
    attribute value : String;
    attribute unit : String = "ISO-8601";
  }

  attribute def MoneyPerKilowattHour {
    attribute value : Real;
    attribute unit : String = "currency/kWh";
  }

  enum def ServiceDisconnectState {
    enum connected;
    enum disconnected;
  }

  enum def MeasurementQuality {
    enum valid;
    enum estimated;
    enum missing;
    enum suspect;
  }

  enum def CommunicationSecurityState {
    enum unauthenticated;
    enum authenticated;
    enum encrypted;
    enum failed;
  }

  enum def TariffPeriod {
    enum offPeak;
    enum shoulder;
    enum peak;
    enum criticalPeak;
  }

  item def VoltageSample {
    attribute rmsVoltage : Volt;
    attribute frequency : Hertz;
    attribute sampledAt : Timestamp;
    attribute quality : MeasurementQuality;
  }

  item def CurrentSample {
    attribute rmsCurrent : Ampere;
    attribute sampledAt : Timestamp;
    attribute quality : MeasurementQuality;
  }

  item def MeterSampleSet {
    item phaseAVoltage : VoltageSample;
    item phaseBVoltage : VoltageSample;
    item phaseCVoltage : VoltageSample;
    item phaseACurrent : CurrentSample;
    item phaseBCurrent : CurrentSample;
    item phaseCCurrent : CurrentSample;
    attribute samplePeriod : Second;
  }

  item def ElectricalService {
    attribute nominalVoltage : Volt;
    attribute nominalFrequency : Hertz;
    attribute maximumCurrent : Ampere;
    attribute phaseCount : Integer;
  }

  item def InstantaneousPower {
    attribute activePower : Watt;
    attribute reactivePower : Watt;
    attribute apparentPower : Watt;
    attribute calculatedAt : Timestamp;
  }

  item def EnergyIntervalUsage {
    attribute deliveredEnergy : KilowattHour;
    attribute receivedEnergy : KilowattHour;
    attribute intervalDuration : Minute;
    attribute startedAt : Timestamp;
    attribute endedAt : Timestamp;
    attribute quality : MeasurementQuality;
  }

  item def TariffSchedule {
    attribute activePeriod : TariffPeriod;
    attribute offPeakRate : MoneyPerKilowattHour;
    attribute shoulderRate : MoneyPerKilowattHour;
    attribute peakRate : MoneyPerKilowattHour;
    attribute criticalPeakRate : MoneyPerKilowattHour;
    attribute effectiveFrom : Timestamp;
  }

  item def UsageReport {
    attribute meterIdentifier : String;
    attribute reportCreatedAt : Timestamp;
    attribute totalDeliveredEnergy : KilowattHour;
    attribute totalReceivedEnergy : KilowattHour;
    attribute intervalDeliveredEnergy : KilowattHour;
    attribute intervalReceivedEnergy : KilowattHour;
    attribute activePower : Watt;
    attribute serviceState : ServiceDisconnectState;
    attribute tariffPeriod : TariffPeriod;
    attribute quality : MeasurementQuality;
  }

  item def DisconnectCommand {
    attribute requestedState : ServiceDisconnectState;
    attribute commandIssuedAt : Timestamp;
    attribute authenticated : Boolean;
  }

  item def DisplayMessage {
    attribute displayedEnergy : KilowattHour;
    attribute displayedPower : Watt;
    attribute displayedTariffPeriod : TariffPeriod;
    attribute displayedAt : Timestamp;
  }

  item def DiagnosticEvent {
    attribute eventCode : String;
    attribute eventTime : Timestamp;
    attribute eventDescription : String;
  }

  item def DcPower {
    attribute voltage : Volt;
    attribute maximumPower : Watt;
  }

  port def ElectricalServicePort {
    inout item service : ElectricalService;
  }

  port def MeterSamplePort {
    inout item samples : MeterSampleSet;
  }

  port def PowerCalculationPort {
    inout item power : InstantaneousPower;
  }

  port def EnergyUsagePort {
    inout item intervalUsage : EnergyIntervalUsage;
  }

  port def UsageReportPort {
    inout item report : UsageReport;
  }

  port def TariffPort {
    inout item tariffSchedule : TariffSchedule;
  }

  port def DisconnectCommandPort {
    inout item command : DisconnectCommand;
  }

  port def DisplayPort {
    inout item displayMessage : DisplayMessage;
  }

  port def DiagnosticPort {
    inout item event : DiagnosticEvent;
  }

  port def DcPowerPort {
    inout item supply : DcPower;
  }

  part def ServiceEntryModule {
    attribute ratedVoltage : Volt;
    attribute ratedCurrent : Ampere;
    attribute ratedFrequency : Hertz;

    port grid : ElectricalServicePort;
    port sampledOutput : MeterSamplePort;
    port switchedService : ElectricalServicePort;
    port diagnosticOutput : DiagnosticPort;
  }

  part def PowerSupplyModule {
    attribute conversionEfficiency : Percent;
    attribute operatingTemperature : DegreeCelsius;

    port serviceInput : ElectricalServicePort;
    port dcOutput : DcPowerPort;
    port diagnosticOutput : DiagnosticPort;
  }

  part def MetrologyProcessor {
    attribute samplingPeriod : Second;
    attribute energyAccuracyPercent : Percent;
    attribute calculationLatency : Second;

    port sampleInput : MeterSamplePort;
    port instantaneousPowerOutput : PowerCalculationPort;
    port intervalUsageOutput : EnergyUsagePort;
    port diagnosticOutput : DiagnosticPort;
    port dcPowerInput : DcPowerPort;
  }

  part def MeterRegister {
    attribute totalDeliveredEnergy : KilowattHour;
    attribute totalReceivedEnergy : KilowattHour;
    attribute lastRegisterUpdate : Timestamp;
    attribute retainedMemoryYears : Real;

    port intervalUsageInput : EnergyUsagePort;
    port reportOutput : UsageReportPort;
    port diagnosticOutput : DiagnosticPort;
    port dcPowerInput : DcPowerPort;
  }

  part def TariffManager {
    attribute activeTariffPeriod : TariffPeriod;

    port tariffInput : TariffPort;
    port usageInput : EnergyUsagePort;
    port reportContributionOutput : UsageReportPort;
    port dcPowerInput : DcPowerPort;
  }

  part def CommunicationModule {
    attribute reportInterval : Minute;
    attribute securityState : CommunicationSecurityState;
    attribute minimumUptimePercent : Percent;

    port registerReportInput : UsageReportPort;
    port tariffOutput : TariffPort;
    port utilityNetwork : UsageReportPort;
    port disconnectCommandOutput : DisconnectCommandPort;
    port diagnosticOutput : DiagnosticPort;
    port dcPowerInput : DcPowerPort;
  }

  part def UserDisplay {
    attribute refreshPeriod : Second;
    attribute visibleDigitCount : Integer;

    port reportInput : UsageReportPort;
    port visibleReadout : DisplayPort;
    port dcPowerInput : DcPowerPort;
  }

  part def RemoteDisconnectSwitch {
    attribute presentState : ServiceDisconnectState;
    attribute maximumSwitchCurrent : Ampere;
    attribute actuationTime : Second;

    port serviceInput : ElectricalServicePort;
    port serviceOutput : ElectricalServicePort;
    port commandInput : DisconnectCommandPort;
    port diagnosticOutput : DiagnosticPort;
    port dcPowerInput : DcPowerPort;
  }

  part def RealTimeClock {
    attribute currentTime : Timestamp;
    attribute driftPerDay : Second;

    port diagnosticOutput : DiagnosticPort;
    port dcPowerInput : DcPowerPort;
  }

  part def EventLogger {
    attribute retainedEventCount : Integer;

    port serviceEntryEvents : DiagnosticPort;
    port metrologyEvents : DiagnosticPort;
    port communicationEvents : DiagnosticPort;
    port switchEvents : DiagnosticPort;
    port clockEvents : DiagnosticPort;
    port dcPowerInput : DcPowerPort;
  }

  action def AcquireVoltageCurrentSamples {
    in item service : ElectricalService;
    out item samples : MeterSampleSet;
  }

  action def CalculateInstantaneousPower {
    in item samples : MeterSampleSet;
    out item power : InstantaneousPower;
  }

  action def IntegrateEnergyOverInterval {
    in item power : InstantaneousPower;
    in intervalDuration : Minute;
    out item intervalUsage : EnergyIntervalUsage;
  }

  action def UpdateCumulativeRegister {
    in item intervalUsage : EnergyIntervalUsage;
    in previousDeliveredEnergy : KilowattHour;
    in previousReceivedEnergy : KilowattHour;
    out updatedDeliveredEnergy : KilowattHour;
    out updatedReceivedEnergy : KilowattHour;
  }

  action def PublishUsageReport {
    in updatedDeliveredEnergy : KilowattHour;
    in updatedReceivedEnergy : KilowattHour;
    in item intervalUsage : EnergyIntervalUsage;
    in item tariffSchedule : TariffSchedule;
    out item report : UsageReport;
  }

  action def MeasureComputeStoreAndReportUsage {
    in item service : ElectricalService;
    in item tariffSchedule : TariffSchedule;
    out item report : UsageReport;

    action acquireSamples : AcquireVoltageCurrentSamples;
    action calculatePower : CalculateInstantaneousPower;
    action integrateEnergy : IntegrateEnergyOverInterval;
    action updateRegister : UpdateCumulativeRegister;
    action publishReport : PublishUsageReport;

    first acquireSamples then calculatePower;
    then integrateEnergy;
    then updateRegister;
    then publishReport;
  }

  state def SmartMeterOperationalStateMachine {
    state Unpowered;
    state Initializing;
    state Measuring;
    state Reporting;
    state AwaitingNetwork;
    state ServiceDisconnected;
    state Faulted;

    transition powerApplied first Unpowered then Initializing;
    transition initializationComplete first Initializing then Measuring;
    transition reportIntervalElapsed first Measuring then Reporting;
    transition reportAccepted first Reporting then Measuring;
    transition networkUnavailable first Reporting then AwaitingNetwork;
    transition networkRestored first AwaitingNetwork then Reporting;
    transition authenticatedDisconnectCommand first Measuring then ServiceDisconnected;
    transition authenticatedReconnectCommand first ServiceDisconnected then Measuring;
    transition criticalFaultDetected first Measuring then Faulted;
    transition faultCleared first Faulted then Initializing;
    transition powerLostFromAnyState first Initializing then Unpowered;
  }

  part def SmartMeterSystem {
    attribute meterIdentifier : String;
    attribute firmwareVersion : String;
    attribute ratedServiceVoltage : Volt;
    attribute ratedServiceCurrent : Ampere;

    port gridService : ElectricalServicePort;
    port customerService : ElectricalServicePort;
    port utilityNetwork : UsageReportPort;
    port customerReadout : DisplayPort;

    part serviceEntry : ServiceEntryModule;
    part powerSupply : PowerSupplyModule;
    part metrology : MetrologyProcessor;
    part register : MeterRegister;
    part tariffManager : TariffManager;
    part communication : CommunicationModule;
    part display : UserDisplay;
    part disconnectSwitch : RemoteDisconnectSwitch;
    part clock : RealTimeClock;
    part eventLogger : EventLogger;

    connect gridService to serviceEntry.grid;
    connect serviceEntry.switchedService to disconnectSwitch.serviceInput;
    connect disconnectSwitch.serviceOutput to customerService;
    connect serviceEntry.sampledOutput to metrology.sampleInput;
    connect serviceEntry.grid to powerSupply.serviceInput;

    connect powerSupply.dcOutput to metrology.dcPowerInput;
    connect powerSupply.dcOutput to register.dcPowerInput;
    connect powerSupply.dcOutput to tariffManager.dcPowerInput;
    connect powerSupply.dcOutput to communication.dcPowerInput;
    connect powerSupply.dcOutput to display.dcPowerInput;
    connect powerSupply.dcOutput to disconnectSwitch.dcPowerInput;
    connect powerSupply.dcOutput to clock.dcPowerInput;
    connect powerSupply.dcOutput to eventLogger.dcPowerInput;

    connect metrology.instantaneousPowerOutput to register.intervalUsageInput;
    connect metrology.intervalUsageOutput to register.intervalUsageInput;
    connect metrology.intervalUsageOutput to tariffManager.usageInput;
    connect register.reportOutput to communication.registerReportInput;
    connect register.reportOutput to display.reportInput;
    connect communication.utilityNetwork to utilityNetwork;
    connect communication.tariffOutput to tariffManager.tariffInput;
    connect communication.disconnectCommandOutput to disconnectSwitch.commandInput;
    connect display.visibleReadout to customerReadout;

    connect serviceEntry.diagnosticOutput to eventLogger.serviceEntryEvents;
    connect metrology.diagnosticOutput to eventLogger.metrologyEvents;
    connect communication.diagnosticOutput to eventLogger.communicationEvents;
    connect disconnectSwitch.diagnosticOutput to eventLogger.switchEvents;
    connect clock.diagnosticOutput to eventLogger.clockEvents;

    perform action primaryFunction : MeasureComputeStoreAndReportUsage;
    exhibit state operatingStates : SmartMeterOperationalStateMachine;
  }

  requirement def SmartMeterPrimaryFunctionRequirement {
    doc /* The smart meter shall measure electrical energy delivered to and received from the customer service, calculate cumulative and interval usage, store time-stamped usage values, report usage securely to the utility, and present current consumption information to the customer. */
    subject meter : SmartMeterSystem;
    require constraint { meter.register.totalDeliveredEnergy.value >= 0.0 }
    require constraint { meter.register.totalReceivedEnergy.value >= 0.0 }
  }

  requirement def MeasurementAccuracyRequirement {
    doc /* The smart meter shall compute delivered and received energy within the required accuracy band for billing use. */
    subject meter : SmartMeterSystem;
    require constraint { meter.metrology.energyAccuracyPercent.value <= 0.5 }
  }

  requirement def ReportingIntervalRequirement {
    doc /* The smart meter shall create and transmit a usage report at least once every configured reporting interval. */
    subject meter : SmartMeterSystem;
    require constraint { meter.communication.reportInterval.value <= 15.0 }
  }

  requirement def CustomerDisplayRequirement {
    doc /* The smart meter shall refresh the customer-visible readout frequently enough to show recent consumption status. */
    subject meter : SmartMeterSystem;
    require constraint { meter.display.refreshPeriod.value <= 5.0 }
  }

  requirement def RemoteDisconnectSafetyRequirement {
    doc /* The smart meter shall actuate the service disconnect only when an authenticated command is received and shall represent the resulting service state in subsequent reports. */
    subject meter : SmartMeterSystem;
    require constraint { meter.disconnectSwitch.actuationTime.value <= 2.0 }
  }

  part smartMeter : SmartMeterSystem {
    attribute meterIdentifier = "SM-PRIMARY-0001";
    attribute firmwareVersion = "4.2.1";
  }
}
