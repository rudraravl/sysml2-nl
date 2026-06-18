package CeilometerPrimaryFunctionModel {

  import ScalarValues::*;

  attribute def Length {
    attribute magnitude : Real;
    attribute unit : String = "m";
  }

  attribute def TimeDuration {
    attribute magnitude : Real;
    attribute unit : String = "s";
  }

  attribute def Frequency {
    attribute magnitude : Real;
    attribute unit : String = "Hz";
  }

  attribute def Wavelength {
    attribute magnitude : Real;
    attribute unit : String = "nm";
  }

  attribute def Energy {
    attribute magnitude : Real;
    attribute unit : String = "uJ";
  }

  attribute def Power {
    attribute magnitude : Real;
    attribute unit : String = "W";
  }

  attribute def Voltage {
    attribute magnitude : Real;
    attribute unit : String = "V";
  }

  attribute def Temperature {
    attribute magnitude : Real;
    attribute unit : String = "degC";
  }

  attribute def Humidity {
    attribute magnitude : Real;
    attribute unit : String = "%RH";
  }

  attribute def Pressure {
    attribute magnitude : Real;
    attribute unit : String = "hPa";
  }

  attribute def Probability {
    attribute magnitude : Real;
    attribute unit : String = "1";
  }

  attribute def DataRate {
    attribute magnitude : Real;
    attribute unit : String = "bit/s";
  }

  attribute def Angle {
    attribute magnitude : Real;
    attribute unit : String = "deg";
  }

  attribute def OpticalSignalStrength {
    attribute magnitude : Real;
    attribute unit : String = "count";
  }

  enum def OperatingMode {
    enum idle;
    enum selfTest;
    enum measurement;
    enum reporting;
    enum maintenance;
    enum faultSafe;
  }

  enum def CloudDetectionQuality {
    enum noCloudDetected;
    enum lowConfidence;
    enum nominalConfidence;
    enum highConfidence;
    enum obscured;
  }

  enum def FaultCode {
    enum none;
    enum powerInputFault;
    enum laserFault;
    enum receiverFault;
    enum opticalWindowObstructed;
    enum temperatureOutOfRange;
    enum processorFault;
    enum communicationFault;
  }

  enum def CommandKind {
    enum startMeasurement;
    enum stopMeasurement;
    enum runSelfTest;
    enum resetFault;
    enum requestStatus;
    enum requestLatestReport;
  }

  item def ElectricalSupply {
    attribute voltage : Voltage;
    attribute availablePower : Power;
  }

  item def RegulatedPower {
    attribute voltage : Voltage;
    attribute powerLimit : Power;
    attribute rippleVoltage : Voltage;
  }

  item def LaserDriveCommand {
    attribute pulseRepetitionFrequency : Frequency;
    attribute pulseEnergy : Energy;
    attribute pulseWidth : TimeDuration;
  }

  item def LaserPulse {
    attribute wavelength : Wavelength;
    attribute energy : Energy;
    attribute pulseWidth : TimeDuration;
    attribute divergence : Angle;
  }

  item def AtmosphericBackscatter {
    attribute elapsedTimeFromPulse : TimeDuration;
    attribute receivedStrength : OpticalSignalStrength;
    attribute estimatedRange : Length;
  }

  item def BackscatterProfile {
    attribute samplePeriod : TimeDuration;
    attribute maximumRange : Length;
    attribute sampleCount : Integer;
    attribute backgroundNoise : OpticalSignalStrength;
  }

  item def EnvironmentalObservation {
    attribute ambientTemperature : Temperature;
    attribute relativeHumidity : Humidity;
    attribute barometricPressure : Pressure;
    attribute windowTemperature : Temperature;
  }

  item def CloudBaseEstimate {
    attribute cloudBaseHeight : Length;
    attribute confidence : Probability;
    attribute quality : CloudDetectionQuality;
  }

  item def CloudBaseReport {
    attribute reportSequenceNumber : Integer;
    attribute measurementTimeFromStartup : TimeDuration;
    attribute cloudBaseHeight : Length;
    attribute confidence : Probability;
    attribute quality : CloudDetectionQuality;
    attribute operatingMode : OperatingMode;
    attribute activeFault : FaultCode;
  }

  item def MaintenanceCommand {
    attribute command : CommandKind;
    attribute commandSequenceNumber : Integer;
  }

  item def HealthStatus {
    attribute operatingMode : OperatingMode;
    attribute activeFault : FaultCode;
    attribute transmitterReady : Boolean;
    attribute receiverReady : Boolean;
    attribute processorReady : Boolean;
    attribute opticalWindowClear : Boolean;
    attribute internalTemperature : Temperature;
  }

  port def PowerInputPort {
    in item supply : ElectricalSupply;
  }

  port def RegulatedPowerPort {
    out item regulatedPower : RegulatedPower;
  }

  port def PowerLoadPort {
    in item regulatedPower : RegulatedPower;
  }

  port def LaserCommandPort {
    in item command : LaserDriveCommand;
  }

  port def OpticalTransmitPort {
    out item pulse : LaserPulse;
  }

  port def OpticalReceivePort {
    in item backscatter : AtmosphericBackscatter;
  }

  port def BackscatterDataPort {
    out item profile : BackscatterProfile;
  }

  port def ProfileInputPort {
    in item profile : BackscatterProfile;
  }

  port def EnvironmentDataPort {
    out item observation : EnvironmentalObservation;
  }

  port def EnvironmentInputPort {
    in item observation : EnvironmentalObservation;
  }

  port def EstimatePort {
    out item estimate : CloudBaseEstimate;
  }

  port def EstimateInputPort {
    in item estimate : CloudBaseEstimate;
  }

  port def ReportPort {
    out item report : CloudBaseReport;
  }

  port def CommandPort {
    in item command : MaintenanceCommand;
  }

  port def HealthPort {
    out item health : HealthStatus;
  }

  port def HealthInputPort {
    in item health : HealthStatus;
  }

  port def AtmosphericOpticalPort {
    in item transmittedPulse : LaserPulse;
    out item returnBackscatter : AtmosphericBackscatter;
  }

  action def ConditionInputPower {
    in item rawSupply : ElectricalSupply;
    out item regulatedPower : RegulatedPower;
  }

  action def GenerateLaserDrive {
    in item mode : OperatingMode;
    out item command : LaserDriveCommand;
  }

  action def EmitLaserPulse {
    in item command : LaserDriveCommand;
    out item pulse : LaserPulse;
  }

  action def ReceiveAtmosphericBackscatter {
    in item backscatter : AtmosphericBackscatter;
    out item profile : BackscatterProfile;
  }

  action def SenseEnvironment {
    out item observation : EnvironmentalObservation;
  }

  action def EstimateCloudBaseHeight {
    in item profile : BackscatterProfile;
    in item observation : EnvironmentalObservation;
    out item estimate : CloudBaseEstimate;
  }

  action def BuildCloudBaseReport {
    in item estimate : CloudBaseEstimate;
    in item health : HealthStatus;
    out item report : CloudBaseReport;
  }

  action def PerformSelfTest {
    out item health : HealthStatus;
  }

  action def PublishReport {
    in item report : CloudBaseReport;
  }

  action def CeilometerMeasurementCycle {
    in item command : MaintenanceCommand;
    out item report : CloudBaseReport;

    action conditionPower : ConditionInputPower;
    action createLaserCommand : GenerateLaserDrive;
    action emitPulse : EmitLaserPulse;
    action acquireBackscatter : ReceiveAtmosphericBackscatter;
    action senseEnvironment : SenseEnvironment;
    action estimateCloudBase : EstimateCloudBaseHeight;
    action buildReport : BuildCloudBaseReport;
    action publish : PublishReport;

    flow createLaserCommand.command to emitPulse.command;
    flow acquireBackscatter.profile to estimateCloudBase.profile;
    flow senseEnvironment.observation to estimateCloudBase.observation;
    flow estimateCloudBase.estimate to buildReport.estimate;
    flow buildReport.report to publish.report;
    flow buildReport.report to report;
  }

  state def CeilometerOperatingStates {
    state off;
    state initializing;
    state standby;
    state selfTesting;
    state measuring;
    state reporting;
    state maintenance;
    state faultSafe;

    transition powerApplied first off then initializing;
    transition initializationComplete first initializing then standby;
    transition selfTestRequested first standby accept MaintenanceCommand then selfTesting;
    transition selfTestPassed first selfTesting then standby;
    transition measurementRequested first standby accept MaintenanceCommand then measuring;
    transition measurementComplete first measuring then reporting;
    transition reportPublished first reporting then standby;
    transition maintenanceRequested first standby accept MaintenanceCommand then maintenance;
    transition maintenanceComplete first maintenance then standby;
    transition faultDetectedFromInitializing first initializing then faultSafe;
    transition faultDetectedFromStandby first standby then faultSafe;
    transition faultDetectedFromSelfTest first selfTesting then faultSafe;
    transition faultDetectedFromMeasuring first measuring then faultSafe;
    transition faultReset first faultSafe accept MaintenanceCommand then initializing;
  }

  part def PowerConditioner {
    port input : PowerInputPort;
    port regulatedOutput : RegulatedPowerPort;

    attribute nominalInputVoltage : Voltage {
      :>> magnitude = 24.0;
      :>> unit = "V";
    }

    attribute nominalOutputVoltage : Voltage {
      :>> magnitude = 12.0;
      :>> unit = "V";
    }

    attribute maximumOutputPower : Power {
      :>> magnitude = 60.0;
      :>> unit = "W";
    }

    perform action condition : ConditionInputPower;
  }

  part def LaserTransmitter {
    port powerInput : PowerLoadPort;
    port commandInput : LaserCommandPort;
    port opticalOutput : OpticalTransmitPort;
    port healthOutput : HealthPort;

    attribute emittedWavelength : Wavelength {
      :>> magnitude = 905.0;
      :>> unit = "nm";
    }

    attribute nominalPulseEnergy : Energy {
      :>> magnitude = 1.6;
      :>> unit = "uJ";
    }

    attribute nominalPulseWidth : TimeDuration {
      :>> magnitude = 100.0;
      :>> unit = "ns";
    }

    attribute pulseRepetitionFrequency : Frequency {
      :>> magnitude = 6500.0;
      :>> unit = "Hz";
    }

    perform action emit : EmitLaserPulse;
  }

  part def OpticalReceiver {
    port powerInput : PowerLoadPort;
    port opticalInput : OpticalReceivePort;
    port profileOutput : BackscatterDataPort;
    port healthOutput : HealthPort;

    attribute receiverFieldOfView : Angle {
      :>> magnitude = 1.2;
      :>> unit = "deg";
    }

    attribute samplePeriod : TimeDuration {
      :>> magnitude = 50.0;
      :>> unit = "ns";
    }

    attribute maximumSampledRange : Length {
      :>> magnitude = 7600.0;
      :>> unit = "m";
    }

    perform action acquire : ReceiveAtmosphericBackscatter;
  }

  part def EnvironmentalSensorAssembly {
    port powerInput : PowerLoadPort;
    port environmentOutput : EnvironmentDataPort;
    port healthOutput : HealthPort;

    attribute minimumOperatingTemperature : Temperature {
      :>> magnitude = -40.0;
      :>> unit = "degC";
    }

    attribute maximumOperatingTemperature : Temperature {
      :>> magnitude = 50.0;
      :>> unit = "degC";
    }

    perform action sense : SenseEnvironment;
  }

  part def SignalProcessor {
    port powerInput : PowerLoadPort;
    port profileInput : ProfileInputPort;
    port environmentInput : EnvironmentInputPort;
    port estimateOutput : EstimatePort;
    port commandOutput : LaserCommandPort;
    port healthOutput : HealthPort;

    attribute minimumDetectableHeight : Length {
      :>> magnitude = 10.0;
      :>> unit = "m";
    }

    attribute maximumDetectableHeight : Length {
      :>> magnitude = 7600.0;
      :>> unit = "m";
    }

    attribute nominalHeightResolution : Length {
      :>> magnitude = 5.0;
      :>> unit = "m";
    }

    perform action estimate : EstimateCloudBaseHeight;
    perform action generateDrive : GenerateLaserDrive;
  }

  part def CommunicationInterface {
    port powerInput : PowerLoadPort;
    port reportInput : EstimateInputPort;
    port reportOutput : ReportPort;
    port commandInput : CommandPort;
    port healthOutput : HealthPort;

    attribute nominalDataRate : DataRate {
      :>> magnitude = 115200.0;
      :>> unit = "bit/s";
    }

    perform action publishReport : PublishReport;
  }

  part def HealthManager {
    port transmitterHealthInput : HealthInputPort;
    port receiverHealthInput : HealthInputPort;
    port environmentHealthInput : HealthInputPort;
    port processorHealthInput : HealthInputPort;
    port communicationHealthInput : HealthInputPort;
    port healthOutput : HealthPort;

    attribute faultLatchActive : Boolean;
    perform action selfTest : PerformSelfTest;
  }

  part def OpticalWindow {
    port outwardOpticalPort : AtmosphericOpticalPort;

    attribute windowTilt : Angle {
      :>> magnitude = 15.0;
      :>> unit = "deg";
    }

    attribute heaterPower : Power {
      :>> magnitude = 12.0;
      :>> unit = "W";
    }

    attribute clearApertureDiameter : Length {
      :>> magnitude = 0.12;
      :>> unit = "m";
    }
  }

  part def Atmosphere {
    port opticalInterface : AtmosphericOpticalPort;

    attribute modeledCloudBaseHeight : Length {
      :>> magnitude = 1200.0;
      :>> unit = "m";
    }

    attribute verticalExtentModeled : Length {
      :>> magnitude = 7600.0;
      :>> unit = "m";
    }
  }

  requirement def PrimaryFunctionRequirement {
    subject ceilometer : CeilometerSystem;

    doc
    /* The ceilometer system shall determine and report the height above the instrument of the lowest detected cloud base by transmitting eye-safe optical pulses upward, receiving atmospheric backscatter, processing the return profile, and producing a cloud base height report with confidence and health status. */

    require constraint {
      ceilometer.latestReport.cloudBaseHeight.magnitude >= 0.0 and
      ceilometer.latestReport.cloudBaseHeight.magnitude <= 7600.0
    }
  }

  requirement def MeasurementRangeRequirement {
    subject ceilometer : CeilometerSystem;

    doc
    /* The system shall support cloud base detection from 10 m through 7600 m above the sensor. */

    require constraint {
      ceilometer.minimumReportedHeight.magnitude == 10.0 and
      ceilometer.maximumReportedHeight.magnitude == 7600.0
    }
  }

  requirement def ReportingRequirement {
    subject ceilometer : CeilometerSystem;

    doc
    /* The system shall publish a cloud base report at least once every 30 seconds while in measurement mode. */

    require constraint {
      ceilometer.maximumReportInterval.magnitude <= 30.0
    }
  }

  requirement def EnvironmentalOperatingRequirement {
    subject ceilometer : CeilometerSystem;

    doc
    /* The system shall remain operational over outdoor environmental conditions from -40 degC to 50 degC. */

    require constraint {
      ceilometer.minimumOperatingTemperature.magnitude <= -40.0 and
      ceilometer.maximumOperatingTemperature.magnitude >= 50.0
    }
  }

  requirement def FaultReportingRequirement {
    subject ceilometer : CeilometerSystem;

    doc
    /* The system shall include the active fault code in each report and enter a fault-safe state when measurement integrity cannot be assured. */

    require constraint {
      ceilometer.latestReport.activeFault != FaultCode::processorFault or
      ceilometer.currentMode == OperatingMode::faultSafe
    }
  }

  part def CeilometerSystem {
    port externalPowerInput : PowerInputPort;
    port externalCommandInput : CommandPort;
    port externalReportOutput : ReportPort;
    port atmosphericOpticalInterface : AtmosphericOpticalPort;

    part powerConditioner : PowerConditioner;
    part transmitter : LaserTransmitter;
    part receiver : OpticalReceiver;
    part environmentalSensors : EnvironmentalSensorAssembly;
    part processor : SignalProcessor;
    part communication : CommunicationInterface;
    part healthManager : HealthManager;
    part opticalWindow : OpticalWindow;

    attribute currentMode : OperatingMode;
    attribute activeFault : FaultCode;
    attribute latestReport : CloudBaseReport;

    attribute minimumReportedHeight : Length {
      :>> magnitude = 10.0;
      :>> unit = "m";
    }

    attribute maximumReportedHeight : Length {
      :>> magnitude = 7600.0;
      :>> unit = "m";
    }

    attribute maximumReportInterval : TimeDuration {
      :>> magnitude = 30.0;
      :>> unit = "s";
    }

    attribute minimumOperatingTemperature : Temperature {
      :>> magnitude = -40.0;
      :>> unit = "degC";
    }

    attribute maximumOperatingTemperature : Temperature {
      :>> magnitude = 50.0;
      :>> unit = "degC";
    }

    connect externalPowerInput to powerConditioner.input;
    connect powerConditioner.regulatedOutput to transmitter.powerInput;
    connect powerConditioner.regulatedOutput to receiver.powerInput;
    connect powerConditioner.regulatedOutput to environmentalSensors.powerInput;
    connect powerConditioner.regulatedOutput to processor.powerInput;
    connect powerConditioner.regulatedOutput to communication.powerInput;

    connect processor.commandOutput to transmitter.commandInput;
    connect transmitter.opticalOutput to opticalWindow.outwardOpticalPort;
    connect opticalWindow.outwardOpticalPort to atmosphericOpticalInterface;
    connect atmosphericOpticalInterface to receiver.opticalInput;

    connect receiver.profileOutput to processor.profileInput;
    connect environmentalSensors.environmentOutput to processor.environmentInput;
    connect processor.estimateOutput to communication.reportInput;
    connect externalCommandInput to communication.commandInput;
    connect communication.reportOutput to externalReportOutput;

    connect transmitter.healthOutput to healthManager.transmitterHealthInput;
    connect receiver.healthOutput to healthManager.receiverHealthInput;
    connect environmentalSensors.healthOutput to healthManager.environmentHealthInput;
    connect processor.healthOutput to healthManager.processorHealthInput;
    connect communication.healthOutput to healthManager.communicationHealthInput;

    exhibit state operatingStates : CeilometerOperatingStates;

    perform action measurementCycle : CeilometerMeasurementCycle;
    perform action selfTest : PerformSelfTest;

    satisfy PrimaryFunctionRequirement by measurementCycle;
    satisfy MeasurementRangeRequirement by processor;
    satisfy ReportingRequirement by communication;
    satisfy EnvironmentalOperatingRequirement by environmentalSensors;
    satisfy FaultReportingRequirement by healthManager;
  }

  part ceilometerInstallation {
    part ceilometer : CeilometerSystem;
    part atmosphere : Atmosphere;

    connect ceilometer.atmosphericOpticalInterface to atmosphere.opticalInterface;
  }

}
