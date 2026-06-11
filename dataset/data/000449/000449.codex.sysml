package BreakthroughStrokeTriageDeviceModel {

  import ScalarValues::*;
  import SI::*;

  attribute def Probability {
    :>> range = "0..1";
  }

  attribute def TimeSecond {
    :>> unit = "s";
  }

  attribute def FrequencyHz {
    :>> unit = "Hz";
  }

  attribute def Acceleration {
    :>> unit = "m/s^2";
  }

  attribute def AngleDegree {
    :>> unit = "deg";
  }

  attribute def TemperatureCelsius {
    :>> unit = "degC";
  }

  attribute def Voltage {
    :>> unit = "V";
  }

  attribute def Current {
    :>> unit = "mA";
  }

  attribute def Energy {
    :>> unit = "Wh";
  }

  attribute def DataRate {
    :>> unit = "kb/s";
  }

  attribute def SignalQuality {
    :>> range = "0..100";
  }

  enum def AlertPriority {
    low;
    medium;
    high;
    critical;
  }

  enum def DeviceMode {
    off;
    standby;
    monitoring;
    analyzing;
    alerting;
    maintenance;
    fault;
  }

  enum def StrokeIndicatorKind {
    armDrift;
    facialAsymmetry;
    speechImpairment;
    gaitInstability;
    abnormalHeartRhythm;
    suddenMotionChange;
  }

  item def MotionSample {
    attribute timestamp : TimeSecond;
    attribute ax : Acceleration;
    attribute ay : Acceleration;
    attribute az : Acceleration;
    attribute roll : AngleDegree;
    attribute pitch : AngleDegree;
    attribute yaw : AngleDegree;
    attribute quality : SignalQuality;
  }

  item def FacialMetricSample {
    attribute timestamp : TimeSecond;
    attribute mouthDroopScore : Probability;
    attribute eyeClosureAsymmetry : Probability;
    attribute faceTrackingQuality : SignalQuality;
  }

  item def SpeechMetricSample {
    attribute timestamp : TimeSecond;
    attribute slurScore : Probability;
    attribute phraseCompletionScore : Probability;
    attribute audioQuality : SignalQuality;
  }

  item def PhysiologicSample {
    attribute timestamp : TimeSecond;
    attribute heartRateBpm : Real;
    attribute rhythmIrregularityScore : Probability;
    attribute skinTemperature : TemperatureCelsius;
    attribute quality : SignalQuality;
  }

  item def StrokeRiskAssessment {
    attribute timestamp : TimeSecond;
    attribute probabilityOfAcuteStroke : Probability;
    attribute confidence : Probability;
    attribute dominantIndicator : StrokeIndicatorKind;
    attribute recommendedPriority : AlertPriority;
  }

  item def EmergencyAlert {
    attribute timestamp : TimeSecond;
    attribute priority : AlertPriority;
    attribute probabilityOfAcuteStroke : Probability;
    attribute patientLocationLatitude : Real;
    attribute patientLocationLongitude : Real;
    attribute messageText : String;
  }

  item def ClinicianAcknowledgement {
    attribute timestamp : TimeSecond;
    attribute responderId : String;
    attribute accepted : Boolean;
  }

  item def BatteryPower {
    attribute voltage : Voltage;
    attribute current : Current;
    attribute remainingEnergy : Energy;
  }

  port def MotionSensorPort {
    out item sample : MotionSample;
  }

  port def CameraMetricPort {
    out item sample : FacialMetricSample;
  }

  port def MicrophoneMetricPort {
    out item sample : SpeechMetricSample;
  }

  port def PhysiologicSensorPort {
    out item sample : PhysiologicSample;
  }

  port def AssessmentPort {
    in item motion : MotionSample;
    in item face : FacialMetricSample;
    in item speech : SpeechMetricSample;
    in item physiology : PhysiologicSample;
    out item assessment : StrokeRiskAssessment;
  }

  port def AlertPort {
    in item assessment : StrokeRiskAssessment;
    out item alert : EmergencyAlert;
    in item acknowledgement : ClinicianAcknowledgement;
  }

  port def PowerPort {
    inout item power : BatteryPower;
  }

  port def WirelessPort {
    out item alert : EmergencyAlert;
    in item acknowledgement : ClinicianAcknowledgement;
  }

  part def InertialMeasurementUnit {
    attribute sampleRate : FrequencyHz = 100;
    attribute accelerationNoise : Acceleration = 0.03;
    attribute angularResolution : AngleDegree = 0.2;
    port motionOut : MotionSensorPort;
  }

  part def FaceMetricSensor {
    attribute frameRate : FrequencyHz = 15;
    attribute minimumFaceQuality : SignalQuality = 70;
    port faceOut : CameraMetricPort;
  }

  part def SpeechMetricSensor {
    attribute sampleRate : FrequencyHz = 16000;
    attribute minimumAudioQuality : SignalQuality = 65;
    port speechOut : MicrophoneMetricPort;
  }

  part def PhysiologicSensor {
    attribute sampleRate : FrequencyHz = 1;
    attribute rhythmWindow : TimeSecond = 30;
    port physiologyOut : PhysiologicSensorPort;
  }

  part def EdgeInferenceProcessor {
    attribute modelName : String = "acute-neurologic-deficit-triage-model";
    attribute inferencePeriod : TimeSecond = 5;
    attribute alertThreshold : Probability = 0.82;
    attribute minimumConfidence : Probability = 0.75;
    port assessmentIo : AssessmentPort;
  }

  part def AlertManager {
    attribute repeatEscalationInterval : TimeSecond = 60;
    attribute maximumUnacknowledgedAlerts : Integer = 3;
    port alertIo : AlertPort;
  }

  part def WirelessCommunicator {
    attribute uplinkDataRate : DataRate = 256;
    attribute encryptionEnabled : Boolean = true;
    port wirelessIo : WirelessPort;
  }

  part def BatterySubsystem {
    attribute nominalVoltage : Voltage = 3.8;
    attribute capacity : Energy = 12;
    attribute minimumOperatingVoltage : Voltage = 3.3;
    port powerOut : PowerPort;
  }

  part def PatientInterface {
    attribute hapticEnabled : Boolean = true;
    attribute audiblePromptEnabled : Boolean = true;
    attribute promptText : String = "Possible stroke symptoms detected. Emergency contacts are being notified.";
  }

  action def AcquireSensorData {
    in item motionIn : MotionSample;
    in item faceIn : FacialMetricSample;
    in item speechIn : SpeechMetricSample;
    in item physiologyIn : PhysiologicSample;
    out item motionOut : MotionSample;
    out item faceOut : FacialMetricSample;
    out item speechOut : SpeechMetricSample;
    out item physiologyOut : PhysiologicSample;
  }

  action def EstimateStrokeRisk {
    in item motion : MotionSample;
    in item face : FacialMetricSample;
    in item speech : SpeechMetricSample;
    in item physiology : PhysiologicSample;
    out item assessment : StrokeRiskAssessment;
  }

  action def GenerateEmergencyAlert {
    in item assessment : StrokeRiskAssessment;
    out item alert : EmergencyAlert;
  }

  action def TransmitAlert {
    in item alert : EmergencyAlert;
    out item acknowledgement : ClinicianAcknowledgement;
  }

  action def RunSelfTest {
    out attribute passed : Boolean;
  }

  state def DeviceOperationalStateMachine {
    state initial Off;
    state Standby;
    state Monitoring;
    state Analyzing;
    state Alerting;
    state Maintenance;
    state Fault;

    transition powerOn first Off then Standby;
    transition beginMonitoring first Standby then Monitoring;
    transition sufficientData first Monitoring then Analyzing;
    transition lowRisk first Analyzing then Monitoring;
    transition highRisk first Analyzing then Alerting;
    transition alertAcknowledged first Alerting then Monitoring;
    transition serviceRequested first Standby then Maintenance;
    transition serviceComplete first Maintenance then Standby;
    transition faultDetected first Monitoring then Fault;
    transition faultDuringAnalysis first Analyzing then Fault;
    transition resetAfterFault first Fault then Standby;
    transition powerOff first Standby then Off;
  }

  part def BreakthroughStrokeTriageWearable {
    attribute deviceBasis : String = "FDA Breakthrough Device-style AI-enabled acute stroke triage wearable";
    attribute primaryFunction : String = "Continuously monitor neurologic, motion, speech, facial, and physiologic signals to identify probable acute stroke and automatically notify emergency responders at a high level.";
    attribute operatingMode : DeviceMode = DeviceMode::standby;
    attribute maximumAlertLatency : TimeSecond = 30;
    attribute minimumBatteryLife : TimeSecond = 86400;

    part imu : InertialMeasurementUnit;
    part faceSensor : FaceMetricSensor;
    part speechSensor : SpeechMetricSensor;
    part physiologicSensor : PhysiologicSensor;
    part processor : EdgeInferenceProcessor;
    part alertManager : AlertManager;
    part communicator : WirelessCommunicator;
    part battery : BatterySubsystem;
    part userInterface : PatientInterface;

    port motionPort : MotionSensorPort;
    port facePort : CameraMetricPort;
    port speechPort : MicrophoneMetricPort;
    port physiologyPort : PhysiologicSensorPort;
    port assessmentPort : AssessmentPort;
    port alertPort : AlertPort;
    port wirelessPort : WirelessPort;
    port powerPort : PowerPort;

    connection motionData connect imu.motionOut to processor.assessmentIo;
    connection faceData connect faceSensor.faceOut to processor.assessmentIo;
    connection speechData connect speechSensor.speechOut to processor.assessmentIo;
    connection physiologyData connect physiologicSensor.physiologyOut to processor.assessmentIo;
    connection assessmentData connect processor.assessmentIo to alertManager.alertIo;
    connection alertData connect alertManager.alertIo to communicator.wirelessIo;
    connection batteryPower connect battery.powerOut to powerPort;

    perform action acquire : AcquireSensorData;
    perform action infer : EstimateStrokeRisk;
    perform action alert : GenerateEmergencyAlert;
    perform action transmit : TransmitAlert;
    perform action selfTest : RunSelfTest;

    exhibit state behavior : DeviceOperationalStateMachine;
  }

  requirement def PrimaryFunctionRequirement {
    subject device : BreakthroughStrokeTriageWearable;
    require constraint {
      device.maximumAlertLatency <= 30
    }
  }

  requirement def StrokeRiskDetectionRequirement {
    subject processor : EdgeInferenceProcessor;
    require constraint {
      processor.alertThreshold >= 0.80 and processor.minimumConfidence >= 0.70
    }
  }

  requirement def ContinuousMonitoringRequirement {
    subject device : BreakthroughStrokeTriageWearable;
    require constraint {
      device.imu.sampleRate >= 50 and
      device.faceSensor.frameRate >= 10 and
      device.physiologicSensor.sampleRate >= 1
    }
  }

  requirement def EmergencyNotificationRequirement {
    subject communicator : WirelessCommunicator;
    require constraint {
      communicator.encryptionEnabled == true and communicator.uplinkDataRate >= 128
    }
  }

  requirement def BatteryLifeRequirement {
    subject device : BreakthroughStrokeTriageWearable;
    require constraint {
      device.minimumBatteryLife >= 86400
    }
  }

  requirement def FalseAlarmControlRequirement {
    subject processor : EdgeInferenceProcessor;
    require constraint {
      processor.minimumConfidence >= 0.75
    }
  }

  requirement def SelfTestRequirement {
    subject device : BreakthroughStrokeTriageWearable;
    require constraint {
      device.operatingMode != DeviceMode::monitoring or device.battery.nominalVoltage >= device.battery.minimumOperatingVoltage
    }
  }

  part breakthroughStrokeTriageSystem : BreakthroughStrokeTriageWearable;

  requirement primaryFunctionReq : PrimaryFunctionRequirement {
    subject device = breakthroughStrokeTriageSystem;
  }

  requirement strokeRiskReq : StrokeRiskDetectionRequirement {
    subject processor = breakthroughStrokeTriageSystem.processor;
  }

  requirement continuousMonitoringReq : ContinuousMonitoringRequirement {
    subject device = breakthroughStrokeTriageSystem;
  }

  requirement emergencyNotificationReq : EmergencyNotificationRequirement {
    subject communicator = breakthroughStrokeTriageSystem.communicator;
  }

  requirement batteryLifeReq : BatteryLifeRequirement {
    subject device = breakthroughStrokeTriageSystem;
  }

  requirement falseAlarmReq : FalseAlarmControlRequirement {
    subject processor = breakthroughStrokeTriageSystem.processor;
  }

  requirement selfTestReq : SelfTestRequirement {
    subject device = breakthroughStrokeTriageSystem;
  }

  satisfy primaryFunctionReq by breakthroughStrokeTriageSystem;
  satisfy strokeRiskReq by breakthroughStrokeTriageSystem.processor;
  satisfy continuousMonitoringReq by breakthroughStrokeTriageSystem.imu;
  satisfy continuousMonitoringReq by breakthroughStrokeTriageSystem.faceSensor;
  satisfy continuousMonitoringReq by breakthroughStrokeTriageSystem.physiologicSensor;
  satisfy emergencyNotificationReq by breakthroughStrokeTriageSystem.communicator;
  satisfy batteryLifeReq by breakthroughStrokeTriageSystem.battery;
  satisfy falseAlarmReq by breakthroughStrokeTriageSystem.processor;
  satisfy selfTestReq by breakthroughStrokeTriageSystem;

}