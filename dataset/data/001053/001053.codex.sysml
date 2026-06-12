package FlameDetectorSystemModel {

  import ScalarValues::*;
  import ISQ::*;
  import SI::*;

  attribute def Irradiance :> ISQ::radiantIntensity {
    unit = W_per_m2;
  }

  attribute def Wavelength :> ISQ::length {
    unit = nm;
  }

  attribute def Temperature :> ISQ::thermodynamicTemperature {
    unit = K;
  }

  attribute def TimeDuration :> ISQ::duration {
    unit = s;
  }

  attribute def Voltage :> ISQ::electricPotential {
    unit = V;
  }

  attribute def ElectricCurrent :> ISQ::electricCurrent {
    unit = A;
  }

  attribute def ConfidenceRatio :> ScalarValues::Real {
    range = "0.0 .. 1.0";
  }

  attribute def Distance :> ISQ::length {
    unit = m;
  }

  attribute def Angle :> ISQ::planeAngle {
    unit = deg;
  }

  enum def DetectorOperatingMode {
    enum idle;
    enum monitoring;
    enum alarm;
    enum fault;
    enum maintenance;
  }

  enum def FlameAlarmSeverity {
    enum none;
    enum advisory;
    enum warning;
    enum critical;
  }

  enum def FaultCode {
    enum noFault;
    enum sensorObscured;
    enum sensorSaturated;
    enum lowSupplyVoltage;
    enum processorFailure;
    enum communicationsFailure;
    enum excessiveTemperature;
  }

  enum def AlarmCommand {
    enum noAlarm;
    enum raiseAlarm;
    enum silenceAudible;
    enum resetAlarm;
    enum testAlarm;
  }

  item def UltravioletRadiation {
    attribute wavelength : Wavelength;
    attribute irradiance : Irradiance;
  }

  item def InfraredRadiation {
    attribute wavelength : Wavelength;
    attribute irradiance : Irradiance;
  }

  item def FlameSignature {
    attribute uvIntensity : Irradiance;
    attribute irIntensity : Irradiance;
    attribute flickerFrequency_Hz : Real;
    attribute confidence : ConfidenceRatio;
    attribute estimatedRange : Distance;
    attribute detectedAngle : Angle;
  }

  item def FlameAlarmMessage {
    attribute severity : FlameAlarmSeverity;
    attribute confidence : ConfidenceRatio;
    attribute sourceId : String;
    attribute eventTime_s : Real;
    attribute estimatedRange : Distance;
  }

  item def HealthStatusMessage {
    attribute mode : DetectorOperatingMode;
    attribute fault : FaultCode;
    attribute internalTemperature : Temperature;
    attribute supplyVoltage : Voltage;
  }

  item def ElectricalPower {
    attribute voltage : Voltage;
    attribute current : ElectricCurrent;
  }

  item def ConfigurationData {
    attribute alarmConfidenceThreshold : ConfidenceRatio;
    attribute warningConfidenceThreshold : ConfidenceRatio;
    attribute alarmPersistenceTime : TimeDuration;
    attribute selfTestInterval : TimeDuration;
    attribute detectorIdentifier : String;
  }

  port def OpticalInputPort {
    in item uvRadiation : UltravioletRadiation;
    in item irRadiation : InfraredRadiation;
  }

  port def PowerInputPort {
    in item power : ElectricalPower;
  }

  port def AlarmOutputPort {
    out item alarmMessage : FlameAlarmMessage;
  }

  port def HealthOutputPort {
    out item healthMessage : HealthStatusMessage;
  }

  port def ConfigurationPort {
    in item configuration : ConfigurationData;
    in item command : AlarmCommand;
  }

  port def InternalSignalPort {
    out item flameSignature : FlameSignature;
  }

  port def ProcessedSignalPort {
    in item flameSignature : FlameSignature;
  }

  action def SenseRadiation {
    in item uvRadiation : UltravioletRadiation;
    in item irRadiation : InfraredRadiation;
    out item uvLevel : Irradiance;
    out item irLevel : Irradiance;
  }

  action def FilterOpticalNoise {
    in item rawUvLevel : Irradiance;
    in item rawIrLevel : Irradiance;
    out item filteredUvLevel : Irradiance;
    out item filteredIrLevel : Irradiance;
  }

  action def DetectFlameSignature {
    in item filteredUvLevel : Irradiance;
    in item filteredIrLevel : Irradiance;
    in attribute flickerFrequency_Hz : Real;
    out item signature : FlameSignature;
  }

  action def EvaluateAlarmCondition {
    in item signature : FlameSignature;
    in item configuration : ConfigurationData;
    out attribute alarmRequired : Boolean;
    out attribute severity : FlameAlarmSeverity;
  }

  action def PublishAlarm {
    in item signature : FlameSignature;
    in attribute severity : FlameAlarmSeverity;
    out item alarmMessage : FlameAlarmMessage;
  }

  action def PerformSelfTest {
    in item power : ElectricalPower;
    out item healthMessage : HealthStatusMessage;
    out attribute passed : Boolean;
  }

  state def FlameDetectorLifecycle {
    entry action initialize;
    
    state powerOff;
    state idle;
    state monitoring;
    state flameSuspected;
    state alarmActive;
    state faulted;
    state maintenance;

    transition first powerOff;
    transition powerOff_to_idle
      first powerOff
      then idle;

    transition idle_to_monitoring
      first idle
      accept configurationReceived
      then monitoring;

    transition monitoring_to_flameSuspected
      first monitoring
      accept flameConfidenceAboveWarning
      then flameSuspected;

    transition flameSuspected_to_monitoring
      first flameSuspected
      accept flameConfidenceBelowWarning
      then monitoring;

    transition flameSuspected_to_alarmActive
      first flameSuspected
      accept flameConfidenceAboveAlarmForPersistenceTime
      then alarmActive;

    transition alarmActive_to_monitoring
      first alarmActive
      accept resetCommandReceived
      then monitoring;

    transition monitoring_to_faulted
      first monitoring
      accept selfTestFailed
      then faulted;

    transition alarmActive_to_faulted
      first alarmActive
      accept selfTestFailed
      then faulted;

    transition faulted_to_monitoring
      first faulted
      accept faultCleared
      then monitoring;

    transition monitoring_to_maintenance
      first monitoring
      accept maintenanceCommandReceived
      then maintenance;

    transition maintenance_to_idle
      first maintenance
      accept maintenanceComplete
      then idle;
  }

  part def UVSensor {
    port opticalIn : OpticalInputPort;
    port signalOut : InternalSignalPort;

    attribute spectralMin : Wavelength = 185 [nm];
    attribute spectralMax : Wavelength = 260 [nm];
    attribute minimumDetectableIrradiance : Irradiance = 0.05 [W_per_m2];
    attribute saturationIrradiance : Irradiance = 50.0 [W_per_m2];
    attribute responseTime : TimeDuration = 0.050 [s];

    perform action senseUV : SenseRadiation;
  }

  part def IRSensor {
    port opticalIn : OpticalInputPort;
    port signalOut : InternalSignalPort;

    attribute spectralMin : Wavelength = 4300 [nm];
    attribute spectralMax : Wavelength = 4500 [nm];
    attribute minimumDetectableIrradiance : Irradiance = 0.10 [W_per_m2];
    attribute saturationIrradiance : Irradiance = 100.0 [W_per_m2];
    attribute responseTime : TimeDuration = 0.075 [s];

    perform action senseIR : SenseRadiation;
  }

  part def OpticalWindow {
    port externalOpticalIn : OpticalInputPort;
    port conditionedOpticalOut : OpticalInputPort;

    attribute fieldOfView : Angle = 90 [deg];
    attribute uvTransmissionRatio : Real = 0.82;
    attribute irTransmissionRatio : Real = 0.88;
    attribute contaminationWarningRatio : Real = 0.65;
  }

  part def SignalProcessor {
    port uvIn : ProcessedSignalPort;
    port irIn : ProcessedSignalPort;
    port configIn : ConfigurationPort;
    port signatureOut : InternalSignalPort;

    attribute samplingRate_Hz : Real = 100.0;
    attribute flameFlickerMin_Hz : Real = 3.0;
    attribute flameFlickerMax_Hz : Real = 30.0;
    attribute warningConfidenceThreshold : ConfidenceRatio = 0.60;
    attribute alarmConfidenceThreshold : ConfidenceRatio = 0.85;
    attribute alarmPersistenceTime : TimeDuration = 2.0 [s];

    perform action filterNoise : FilterOpticalNoise;
    perform action detectSignature : DetectFlameSignature;
    perform action evaluateAlarm : EvaluateAlarmCondition;
  }

  part def AlarmController {
    port signatureIn : ProcessedSignalPort;
    port configIn : ConfigurationPort;
    port alarmOut : AlarmOutputPort;
    port healthOut : HealthOutputPort;

    attribute latchedAlarm : Boolean = false;
    attribute audibleSilenced : Boolean = false;
    attribute defaultSeverity : FlameAlarmSeverity = FlameAlarmSeverity::critical;

    perform action publishAlarm : PublishAlarm;
  }

  part def SelfTestMonitor {
    port powerIn : PowerInputPort;
    port healthOut : HealthOutputPort;

    attribute selfTestInterval : TimeDuration = 60.0 [s];
    attribute minimumSupplyVoltage : Voltage = 18.0 [V];
    attribute maximumSupplyVoltage : Voltage = 32.0 [V];
    attribute maximumInternalTemperature : Temperature = 358.15 [K];

    perform action selfTest : PerformSelfTest;
  }

  part def PowerConditioner {
    port externalPowerIn : PowerInputPort;
    port conditionedPowerOut : PowerInputPort;

    attribute nominalInputVoltage : Voltage = 24.0 [V];
    attribute minimumInputVoltage : Voltage = 18.0 [V];
    attribute maximumInputVoltage : Voltage = 32.0 [V];
    attribute maximumCurrent : ElectricCurrent = 0.250 [A];
    attribute regulatedLogicVoltage : Voltage = 5.0 [V];
  }

  part def FlameDetectorSystem {
    port opticalInput : OpticalInputPort;
    port powerInput : PowerInputPort;
    port configurationInput : ConfigurationPort;
    port alarmOutput : AlarmOutputPort;
    port healthOutput : HealthOutputPort;

    attribute primaryFunction : String =
      "Continuously monitor the protected volume for ultraviolet and infrared radiation patterns characteristic of open flame, distinguish flame signatures from environmental noise, and issue a timely alarm and health status output.";

    attribute detectorId : String = "FD-001";
    attribute nominalDetectionRange : Distance = 30.0 [m];
    attribute horizontalFieldOfView : Angle = 90 [deg];
    attribute alarmResponseTime : TimeDuration = 3.0 [s];
    attribute operatingMode : DetectorOperatingMode = DetectorOperatingMode::idle;

    part window : OpticalWindow;
    part uvSensor : UVSensor;
    part irSensor : IRSensor;
    part processor : SignalProcessor;
    part alarmController : AlarmController;
    part selfTestMonitor : SelfTestMonitor;
    part powerConditioner : PowerConditioner;

    connection opticalPathToWindow connect opticalInput to window.externalOpticalIn;
    connection opticalPathToUVSensor connect window.conditionedOpticalOut to uvSensor.opticalIn;
    connection opticalPathToIRSensor connect window.conditionedOpticalOut to irSensor.opticalIn;

    connection powerPathToConditioner connect powerInput to powerConditioner.externalPowerIn;
    connection conditionedPowerToSelfTest connect powerConditioner.conditionedPowerOut to selfTestMonitor.powerIn;

    connection uvSignalPath connect uvSensor.signalOut to processor.uvIn;
    connection irSignalPath connect irSensor.signalOut to processor.irIn;
    connection signaturePath connect processor.signatureOut to alarmController.signatureIn;

    connection configurationToProcessor connect configurationInput to processor.configIn;
    connection configurationToAlarmController connect configurationInput to alarmController.configIn;

    connection alarmMessagePath connect alarmController.alarmOut to alarmOutput;
    connection alarmHealthPath connect alarmController.healthOut to healthOutput;
    connection selfTestHealthPath connect selfTestMonitor.healthOut to healthOutput;

    exhibit state lifecycle : FlameDetectorLifecycle;
  }

  requirement def DetectOpenFlameRequirement {
    subject detector : FlameDetectorSystem;

    doc
    /*
     The flame detector shall identify an open flame within its protected field of view by evaluating ultraviolet intensity, infrared intensity, and flicker behavior consistent with combustion.
     */

    require constraint {
      detector.nominalDetectionRange >= 30.0 [m]
    }
  }

  requirement def AlarmResponseRequirement {
    subject detector : FlameDetectorSystem;

    doc
    /*
     The flame detector shall issue a critical flame alarm when the calculated flame confidence is at or above the configured alarm threshold for the configured persistence time.
     */

    require constraint {
      detector.alarmResponseTime <= 3.0 [s]
    }
  }

  requirement def FalseAlarmRejectionRequirement {
    subject detector : FlameDetectorSystem;

    doc
    /*
     The flame detector shall reject transient optical noise sources by requiring correlated ultraviolet and infrared flame signatures before issuing a critical alarm.
     */
  }

  requirement def HealthMonitoringRequirement {
    subject detector : FlameDetectorSystem;

    doc
    /*
     The flame detector shall continuously report detector operating mode, supply voltage condition, internal temperature condition, and active fault code.
     */
  }

  requirement def FieldOfViewRequirement {
    subject detector : FlameDetectorSystem;

    doc
    /*
     The flame detector shall monitor a horizontal field of view of at least ninety degrees.
     */

    require constraint {
      detector.horizontalFieldOfView >= 90 [deg]
    }
  }

  requirement def PowerRequirement {
    subject detector : FlameDetectorSystem;

    doc
    /*
     The flame detector shall operate from a nominal twenty-four volt direct-current supply and tolerate an input range from eighteen to thirty-two volts.
     */
  }

  part flameDetector : FlameDetectorSystem;

  satisfy DetectOpenFlameRequirement by flameDetector;
  satisfy AlarmResponseRequirement by flameDetector;
  satisfy FalseAlarmRejectionRequirement by flameDetector;
  satisfy HealthMonitoringRequirement by flameDetector;
  satisfy FieldOfViewRequirement by flameDetector;
  satisfy PowerRequirement by flameDetector;
}