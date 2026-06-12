package FlameDetectionSystemModel {

  import ScalarValues::*;
  import SI::*;

  attribute def Wavelength {
    :>> unit = "nm";
  }

  attribute def Irradiance {
    :>> unit = "W/m^2";
  }

  attribute def Temperature {
    :>> unit = "degC";
  }

  attribute def TimeDuration {
    :>> unit = "s";
  }

  attribute def Probability {
    :>> unit = "1";
  }

  attribute def Voltage {
    :>> unit = "V";
  }

  attribute def Current {
    :>> unit = "A";
  }

  attribute def Distance {
    :>> unit = "m";
  }

  enum def AlarmSeverity {
    enum normal;
    enum warning;
    enum confirmedFire;
    enum detectorFault;
  }

  enum def DetectorMode {
    enum off;
    enum selfTest;
    enum monitoring;
    enum alarmLatched;
    enum degraded;
    enum maintenance;
  }

  item def OpticalRadiation {
    attribute uvIrradiance : Irradiance;
    attribute irIrradiance : Irradiance;
    attribute visibleIrradiance : Irradiance;
    attribute dominantWavelength : Wavelength;
    attribute modulationFrequency : Real;
  }

  item def ThermalCondition {
    attribute ambientTemperature : Temperature;
    attribute detectorHousingTemperature : Temperature;
  }

  item def FlameEvidence {
    attribute uvScore : Probability;
    attribute irScore : Probability;
    attribute flickerScore : Probability;
    attribute combinedConfidence : Probability;
    attribute observationTime : TimeDuration;
  }

  item def AlarmCommand {
    attribute severity : AlarmSeverity;
    attribute confidence : Probability;
    attribute latchRequested : Boolean;
    attribute message : String;
  }

  item def FaultReport {
    attribute sensorFault : Boolean;
    attribute obscurationFault : Boolean;
    attribute powerFault : Boolean;
    attribute processorFault : Boolean;
    attribute description : String;
  }

  item def ElectricalPower {
    attribute supplyVoltage : Voltage;
    attribute supplyCurrent : Current;
  }

  item def MaintenanceCommand {
    attribute resetAlarm : Boolean;
    attribute startSelfTest : Boolean;
    attribute placeInMaintenance : Boolean;
  }

  port def OpticalInputPort {
    in radiation : OpticalRadiation;
  }

  port def ThermalInputPort {
    in thermal : ThermalCondition;
  }

  port def PowerInputPort {
    in power : ElectricalPower;
  }

  port def EvidencePort {
    out evidence : FlameEvidence;
  }

  port def AlarmOutputPort {
    out alarm : AlarmCommand;
  }

  port def FaultOutputPort {
    out fault : FaultReport;
  }

  port def MaintenancePort {
    in command : MaintenanceCommand;
  }

  port def InternalEvidenceInputPort {
    in evidence : FlameEvidence;
  }

  part def UltravioletSensor {
    attribute spectralRangeMin : Wavelength = 185;
    attribute spectralRangeMax : Wavelength = 260;
    attribute minimumDetectableIrradiance : Irradiance = 0.002;
    attribute saturationIrradiance : Irradiance = 2.0;
    attribute responseTime : TimeDuration = 0.05;

    port opticalIn : OpticalInputPort;
    port evidenceOut : EvidencePort;

    action detectUltravioletEnergy {
      in radiation : OpticalRadiation;
      out uvScore : Probability;
    }
  }

  part def InfraredSensor {
    attribute spectralRangeMin : Wavelength = 4300;
    attribute spectralRangeMax : Wavelength = 4500;
    attribute minimumDetectableIrradiance : Irradiance = 0.01;
    attribute responseTime : TimeDuration = 0.08;

    port opticalIn : OpticalInputPort;
    port evidenceOut : EvidencePort;

    action detectCarbonDioxideEmissionBand {
      in radiation : OpticalRadiation;
      out irScore : Probability;
    }
  }

  part def FlickerAnalyzer {
    attribute minimumFlickerFrequency : Real = 1.0;
    attribute maximumFlickerFrequency : Real = 20.0;
    attribute analysisWindow : TimeDuration = 2.0;

    port evidenceIn : InternalEvidenceInputPort;
    port evidenceOut : EvidencePort;

    action estimateFlameFlicker {
      in evidence : FlameEvidence;
      out flickerScore : Probability;
    }
  }

  part def SignalProcessor {
    attribute confirmationThreshold : Probability = 0.85;
    attribute warningThreshold : Probability = 0.55;
    attribute falseAlarmRejectionEnabled : Boolean = true;
    attribute confirmationTime : TimeDuration = 3.0;

    port uvEvidenceIn : InternalEvidenceInputPort;
    port irEvidenceIn : InternalEvidenceInputPort;
    port flickerEvidenceIn : InternalEvidenceInputPort;
    port alarmOut : AlarmOutputPort;
    port faultOut : FaultOutputPort;

    action fuseSensorEvidence {
      in uvEvidence : FlameEvidence;
      in irEvidence : FlameEvidence;
      in flickerEvidence : FlameEvidence;
      out fusedEvidence : FlameEvidence;
    }

    action classifyFireCondition {
      in fusedEvidence : FlameEvidence;
      out command : AlarmCommand;
    }
  }

  part def HealthMonitor {
    attribute selfTestInterval : TimeDuration = 60.0;
    attribute obscurationLimit : Probability = 0.40;
    attribute maximumHousingTemperature : Temperature = 85.0;
    attribute minimumSupplyVoltage : Voltage = 18.0;
    attribute maximumSupplyVoltage : Voltage = 32.0;

    port thermalIn : ThermalInputPort;
    port powerIn : PowerInputPort;
    port faultOut : FaultOutputPort;

    action performSelfTest {
      out report : FaultReport;
    }

    action checkOperatingLimits {
      in thermal : ThermalCondition;
      in power : ElectricalPower;
      out report : FaultReport;
    }
  }

  part def AlarmInterface {
    attribute relayContactRatingCurrent : Current = 2.0;
    attribute outputVoltageNominal : Voltage = 24.0;
    attribute alarmLatchEnabled : Boolean = true;

    port alarmIn : InternalEvidenceInputPort;
    port alarmOut : AlarmOutputPort;
    port faultOut : FaultOutputPort;

    action energizeAlarmRelay {
      in command : AlarmCommand;
    }

    action publishAlarmMessage {
      in command : AlarmCommand;
    }
  }

  part def FlameDetector {
    doc /* Primary function: continuously observe ultraviolet, infrared, and flicker characteristics in the protected area, determine whether the observed radiation is consistent with an open flame, and issue a confirmed fire alarm while rejecting non-flame sources. */

    attribute protectedRange : Distance = 30.0;
    attribute fieldOfView : Real = 90.0;
    attribute detectionConfirmationTime : TimeDuration = 3.0;
    attribute falseAlarmProbabilityTarget : Probability = 0.001;
    attribute currentMode : DetectorMode = DetectorMode::off;

    port opticalIn : OpticalInputPort;
    port thermalIn : ThermalInputPort;
    port powerIn : PowerInputPort;
    port maintenanceIn : MaintenancePort;
    port alarmOut : AlarmOutputPort;
    port faultOut : FaultOutputPort;

    part uvSensor : UltravioletSensor;
    part irSensor : InfraredSensor;
    part flickerAnalyzer : FlickerAnalyzer;
    part processor : SignalProcessor;
    part healthMonitor : HealthMonitor;
    part alarmInterface : AlarmInterface;

    connect opticalIn to uvSensor.opticalIn;
    connect opticalIn to irSensor.opticalIn;
    connect thermalIn to healthMonitor.thermalIn;
    connect powerIn to healthMonitor.powerIn;

    connect uvSensor.evidenceOut to processor.uvEvidenceIn;
    connect irSensor.evidenceOut to processor.irEvidenceIn;
    connect uvSensor.evidenceOut to flickerAnalyzer.evidenceIn;
    connect flickerAnalyzer.evidenceOut to processor.flickerEvidenceIn;

    connect processor.alarmOut to alarmOut;
    connect processor.faultOut to faultOut;
    connect healthMonitor.faultOut to faultOut;
    connect alarmInterface.alarmOut to alarmOut;
    connect alarmInterface.faultOut to faultOut;

    action detectFlame {
      in radiation : OpticalRadiation;
      in thermal : ThermalCondition;
      out alarm : AlarmCommand;

      first start;
      then collectOpticalEnergy;
      then evaluateUvAndIrSignatures;
      then analyzeTemporalFlicker;
      then rejectKnownFalseSources;
      then confirmAlarmCondition;
      then issueAlarm;
    }

    state def OperationalStateMachine {
      state Off;
      state SelfTest;
      state Monitoring;
      state Warning;
      state ConfirmedAlarm;
      state Fault;
      state Maintenance;

      transition initial then Off;

      transition PowerApplied
        first Off
        then SelfTest;

      transition SelfTestPassed
        first SelfTest
        then Monitoring;

      transition SelfTestFailed
        first SelfTest
        then Fault;

      transition FlameEvidenceAboveWarningThreshold
        first Monitoring
        then Warning;

      transition EvidenceFallsBelowWarningThreshold
        first Warning
        then Monitoring;

      transition EvidenceConfirmedForRequiredTime
        first Warning
        then ConfirmedAlarm;

      transition FaultDetected
        first Monitoring
        then Fault;

      transition AlarmResetCommanded
        first ConfirmedAlarm
        then SelfTest;

      transition MaintenanceCommanded
        first Monitoring
        then Maintenance;

      transition MaintenanceReleased
        first Maintenance
        then SelfTest;
    }
  }

  part def ProtectedArea {
    attribute areaName : String = "Process equipment bay";
    attribute maximumDetectionDistance : Distance = 30.0;

    port emittedRadiation : OpticalInputPort;
    port ambientThermalCondition : ThermalInputPort;
  }

  part flameDetectionInstallation {
    part protectedArea : ProtectedArea;
    part detector : FlameDetector;

    port plantPower : PowerInputPort;
    port operatorMaintenance : MaintenancePort;
    port plantFireAlarm : AlarmOutputPort;
    port plantFaultAnnunciation : FaultOutputPort;

    connect protectedArea.emittedRadiation to detector.opticalIn;
    connect protectedArea.ambientThermalCondition to detector.thermalIn;
    connect plantPower to detector.powerIn;
    connect operatorMaintenance to detector.maintenanceIn;
    connect detector.alarmOut to plantFireAlarm;
    connect detector.faultOut to plantFaultAnnunciation;
  }

  requirement def DetectOpenFlame {
    subject detector : FlameDetector;

    doc /* The detector shall identify an open flame in the protected area by evaluating ultraviolet radiation, infrared carbon dioxide emission energy, and flame flicker behavior. */

    require constraint {
      detector.detectionConfirmationTime <= 3.0
    }
  }

  requirement def RejectFalseAlarmSources {
    subject detector : FlameDetector;

    doc /* The detector shall suppress alarms caused by steady sunlight, hot surfaces, welding arcs outside the configured flame signature, and transient optical noise. */

    require constraint {
      detector.falseAlarmProbabilityTarget <= 0.001
    }
  }

  requirement def AnnunciateConfirmedFire {
    subject detector : FlameDetector;

    doc /* The detector shall output a latched confirmed fire alarm when fused flame confidence is at or above the confirmation threshold for the configured confirmation time. */

    require constraint {
      detector.processor.confirmationThreshold >= 0.85
    }
  }

  requirement def MonitorDetectorHealth {
    subject detector : FlameDetector;

    doc /* The detector shall monitor sensor integrity, optical obscuration, processor operation, supply power, and housing temperature and shall report a fault when limits are exceeded. */

    require constraint {
      detector.healthMonitor.selfTestInterval <= 60.0
    }
  }

  requirement def OperateAcrossSpecifiedPowerRange {
    subject detector : FlameDetector;

    doc /* The detector shall operate from a nominal 24 VDC fire-system power supply. */

    require constraint {
      detector.healthMonitor.minimumSupplyVoltage >= 18.0 and
      detector.healthMonitor.maximumSupplyVoltage <= 32.0
    }
  }

  satisfy DetectOpenFlame by flameDetectionInstallation.detector;
  satisfy RejectFalseAlarmSources by flameDetectionInstallation.detector;
  satisfy AnnunciateConfirmedFire by flameDetectionInstallation.detector;
  satisfy MonitorDetectorHealth by flameDetectionInstallation.detector;
  satisfy OperateAcrossSpecifiedPowerRange by flameDetectionInstallation.detector;
}