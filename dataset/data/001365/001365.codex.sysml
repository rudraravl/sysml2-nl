package BabyMonitorSystemModel {

  enum def TemperatureUnit { degC; }
  enum def RelativeHumidityUnit { percentRH; }
  enum def SoundPressureUnit { dBA; }
  enum def EnergyUnit { Wh; }
  enum def PowerUnit { W; }
  enum def DurationUnit { s; min; h; }
  enum def DistanceUnit { m; }
  enum def BitRateUnit { Mbps; }
  enum def IlluminanceUnit { lx; }

  attribute def TemperatureValue {
    attribute value : Real;
    attribute unit : TemperatureUnit = TemperatureUnit::degC;
  }

  attribute def RelativeHumidityValue {
    attribute value : Real;
    attribute unit : RelativeHumidityUnit = RelativeHumidityUnit::percentRH;
  }

  attribute def SoundLevelValue {
    attribute value : Real;
    attribute unit : SoundPressureUnit = SoundPressureUnit::dBA;
  }

  attribute def EnergyValue {
    attribute value : Real;
    attribute unit : EnergyUnit = EnergyUnit::Wh;
  }

  attribute def PowerValue {
    attribute value : Real;
    attribute unit : PowerUnit = PowerUnit::W;
  }

  attribute def DurationValue {
    attribute value : Real;
    attribute unit : DurationUnit = DurationUnit::s;
  }

  attribute def DistanceValue {
    attribute value : Real;
    attribute unit : DistanceUnit = DistanceUnit::m;
  }

  attribute def BitRateValue {
    attribute value : Real;
    attribute unit : BitRateUnit = BitRateUnit::Mbps;
  }

  attribute def IlluminanceValue {
    attribute value : Real;
    attribute unit : IlluminanceUnit = IlluminanceUnit::lx;
  }

  attribute def PercentageValue {
    attribute value : Real;
  }

  item def AudioSample {
    attribute soundLevel : SoundLevelValue;
    attribute duration : DurationValue;
    attribute sampleRateHz : Real;
  }

  item def VideoFrame {
    attribute widthPixels : Integer;
    attribute heightPixels : Integer;
    attribute frameRateHz : Real;
    attribute infraredEnabled : Boolean;
  }

  item def AmbientReading {
    attribute temperature : TemperatureValue;
    attribute humidity : RelativeHumidityValue;
    attribute lightLevel : IlluminanceValue;
  }

  item def BatteryStatus {
    attribute remainingCharge : PercentageValue;
    attribute remainingEnergy : EnergyValue;
    attribute externalPowerPresent : Boolean;
  }

  item def BabyStatus {
    attribute motionDetected : Boolean;
    attribute cryingDetected : Boolean;
    attribute faceVisible : Boolean;
    attribute roomTemperature : TemperatureValue;
    attribute roomHumidity : RelativeHumidityValue;
    attribute confidence : PercentageValue;
  }

  item def AlertMessage {
    attribute alertKind : String;
    attribute severity : Integer;
    attribute timestampSeconds : Real;
    attribute acknowledged : Boolean;
  }

  item def ControlCommand {
    attribute commandKind : String;
    attribute commandValue : String;
  }

  port def AudioOutPort {
    out item audio : AudioSample;
  }

  port def AudioInPort {
    in item audio : AudioSample;
  }

  port def VideoOutPort {
    out item frame : VideoFrame;
  }

  port def VideoInPort {
    in item frame : VideoFrame;
  }

  port def AmbientOutPort {
    out item reading : AmbientReading;
  }

  port def AmbientInPort {
    in item reading : AmbientReading;
  }

  port def StatusOutPort {
    out item status : BabyStatus;
  }

  port def StatusInPort {
    in item status : BabyStatus;
  }

  port def AlertOutPort {
    out item alert : AlertMessage;
  }

  port def AlertInPort {
    in item alert : AlertMessage;
  }

  port def CommandOutPort {
    out item command : ControlCommand;
  }

  port def CommandInPort {
    in item command : ControlCommand;
  }

  port def PowerOutPort {
    out item battery : BatteryStatus;
  }

  port def PowerInPort {
    in item battery : BatteryStatus;
  }

  part def CameraModule {
    attribute resolutionWidth : Integer = 1920;
    attribute resolutionHeight : Integer = 1080;
    attribute frameRateHz : Real = 30.0;
    attribute nightVisionRange : DistanceValue = (value = 5.0, unit = DistanceUnit::m);

    port videoOut : VideoOutPort;
    port commandIn : CommandInPort;

    action captureVideo {
      out item frame : VideoFrame;
    }
  }

  part def MicrophoneArray {
    attribute microphoneCount : Integer = 2;
    attribute minimumDetectableLevel : SoundLevelValue = (value = 30.0, unit = SoundPressureUnit::dBA);
    attribute cryingThreshold : SoundLevelValue = (value = 65.0, unit = SoundPressureUnit::dBA);

    port audioOut : AudioOutPort;

    action captureAudio {
      out item sample : AudioSample;
    }
  }

  part def TemperatureHumiditySensor {
    attribute temperatureAccuracy : TemperatureValue = (value = 0.5, unit = TemperatureUnit::degC);
    attribute humidityAccuracy : RelativeHumidityValue = (value = 3.0, unit = RelativeHumidityUnit::percentRH);

    port ambientOut : AmbientOutPort;

    action measureEnvironment {
      out item reading : AmbientReading;
    }
  }

  part def NightLight {
    attribute maximumIlluminance : IlluminanceValue = (value = 20.0, unit = IlluminanceUnit::lx);
    attribute enabled : Boolean = false;
    attribute brightness : PercentageValue = (value = 0.0);

    port commandIn : CommandInPort;
  }

  part def Speaker {
    attribute maximumOutputLevel : SoundLevelValue = (value = 70.0, unit = SoundPressureUnit::dBA);

    port audioIn : AudioInPort;
    port commandIn : CommandInPort;
  }

  part def BatterySubsystem {
    attribute capacity : EnergyValue = (value = 20.0, unit = EnergyUnit::Wh);
    attribute normalLoad : PowerValue = (value = 4.0, unit = PowerUnit::W);
    attribute minimumRuntime : DurationValue = (value = 5.0, unit = DurationUnit::h);

    port powerOut : PowerOutPort;

    action monitorBattery {
      out item battery : BatteryStatus;
    }
  }

  part def EdgeProcessor {
    attribute audioAlertLatencyLimit : DurationValue = (value = 2.0, unit = DurationUnit::s);
    attribute videoProcessingRateHz : Real = 15.0;
    attribute lowTemperatureLimit : TemperatureValue = (value = 18.0, unit = TemperatureUnit::degC);
    attribute highTemperatureLimit : TemperatureValue = (value = 26.0, unit = TemperatureUnit::degC);

    port audioIn : AudioInPort;
    port videoIn : VideoInPort;
    port ambientIn : AmbientInPort;
    port batteryIn : PowerInPort;
    port statusOut : StatusOutPort;
    port alertOut : AlertOutPort;
    port commandIn : CommandInPort;

    action evaluateBabyStatus {
      in item audio : AudioSample;
      in item frame : VideoFrame;
      in item reading : AmbientReading;
      out item status : BabyStatus;
      out item alert : AlertMessage;
    }
  }

  part def WirelessTransceiver {
    attribute rangeIndoor : DistanceValue = (value = 30.0, unit = DistanceUnit::m);
    attribute rangeOpenAir : DistanceValue = (value = 250.0, unit = DistanceUnit::m);
    attribute minimumEncryptedBitRate : BitRateValue = (value = 2.0, unit = BitRateUnit::Mbps);
    attribute encryptionEnabled : Boolean = true;

    port statusIn : StatusInPort;
    port alertIn : AlertInPort;
    port commandOut : CommandOutPort;
    port statusOut : StatusOutPort;
    port alertOut : AlertOutPort;
    port commandIn : CommandInPort;
  }

  part def ParentDisplayUnit {
    attribute displayWidthPixels : Integer = 1280;
    attribute displayHeightPixels : Integer = 720;
    attribute audibleAlarmLevel : SoundLevelValue = (value = 75.0, unit = SoundPressureUnit::dBA);

    port statusIn : StatusInPort;
    port alertIn : AlertInPort;
    port commandOut : CommandOutPort;

    action presentStatus {
      in item status : BabyStatus;
    }

    action alarmCaregiver {
      in item alert : AlertMessage;
    }
  }

  part def MobileAppGateway {
    attribute pushNotificationLatencyLimit : DurationValue = (value = 5.0, unit = DurationUnit::s);
    attribute pairedCaregiverDevices : Integer = 2;

    port statusIn : StatusInPort;
    port alertIn : AlertInPort;
    port commandOut : CommandOutPort;
  }

  part def BabyMonitor {
    attribute primaryFunction : String =
      "Continuously observe a baby and the nursery environment, transmit audio/video/status information to a caregiver, and issue timely alerts for crying, unsafe room conditions, loss of visibility, or low battery.";

    part camera : CameraModule;
    part microphone : MicrophoneArray;
    part environmentSensor : TemperatureHumiditySensor;
    part processor : EdgeProcessor;
    part radio : WirelessTransceiver;
    part battery : BatterySubsystem;
    part nightLight : NightLight;
    part speaker : Speaker;
    part parentUnit : ParentDisplayUnit;
    part mobileGateway : MobileAppGateway;

    connection cameraVideoToProcessor connect camera.videoOut to processor.videoIn;
    connection microphoneAudioToProcessor connect microphone.audioOut to processor.audioIn;
    connection ambientToProcessor connect environmentSensor.ambientOut to processor.ambientIn;
    connection batteryToProcessor connect battery.powerOut to processor.batteryIn;

    connection processorStatusToRadio connect processor.statusOut to radio.statusIn;
    connection processorAlertToRadio connect processor.alertOut to radio.alertIn;

    connection radioStatusToParent connect radio.statusOut to parentUnit.statusIn;
    connection radioAlertToParent connect radio.alertOut to parentUnit.alertIn;
    connection parentCommandsToRadio connect parentUnit.commandOut to radio.commandIn;
    connection radioCommandsToProcessor connect radio.commandOut to processor.commandIn;

    connection radioStatusToMobile connect radio.statusOut to mobileGateway.statusIn;
    connection radioAlertToMobile connect radio.alertOut to mobileGateway.alertIn;
    connection mobileCommandsToRadio connect mobileGateway.commandOut to radio.commandIn;

    connection processorCommandToNightLight connect processor.commandIn to nightLight.commandIn;
    connection processorCommandToSpeaker connect processor.commandIn to speaker.commandIn;

    state operationalBehavior {
      entry action initializePairing;

      state Off;
      state Booting;
      state Pairing;
      state Monitoring;
      state Alerting;
      state LowPower;
      state Faulted;

      transition initial then Off;
      transition powerApplied first Off then Booting;
      transition bootComplete first Booting then Pairing;
      transition caregiverPaired first Pairing then Monitoring;
      transition anomalyDetected first Monitoring then Alerting;
      transition alertAcknowledged first Alerting then Monitoring;
      transition batteryLow first Monitoring then LowPower;
      transition externalPowerRestored first LowPower then Monitoring;
      transition sensorFailure first Monitoring then Faulted;
      transition resetCommanded first Faulted then Booting;
      transition powerRemoved first Monitoring then Off;
    }

    action monitorBaby {
      action captureVideo : camera.captureVideo;
      action captureAudio : microphone.captureAudio;
      action measureEnvironment : environmentSensor.measureEnvironment;
      action assess : processor.evaluateBabyStatus;
      action present : parentUnit.presentStatus;
    }
  }

  requirement def ContinuousMonitoringRequirement {
    subject monitor : BabyMonitor;
    require constraint {
      monitor.processor.videoProcessingRateHz >= 10.0
    }
  }

  requirement def AudioAlertLatencyRequirement {
    subject monitor : BabyMonitor;
    require constraint {
      monitor.processor.audioAlertLatencyLimit.value <= 2.0
    }
  }

  requirement def TemperatureSafetyRequirement {
    subject monitor : BabyMonitor;
    require constraint {
      monitor.processor.lowTemperatureLimit.value == 18.0 and
      monitor.processor.highTemperatureLimit.value == 26.0
    }
  }

  requirement def WirelessRangeRequirement {
    subject monitor : BabyMonitor;
    require constraint {
      monitor.radio.rangeIndoor.value >= 30.0
    }
  }

  requirement def BatteryRuntimeRequirement {
    subject monitor : BabyMonitor;
    require constraint {
      monitor.battery.minimumRuntime.value >= 5.0
    }
  }

  requirement def EncryptedTransmissionRequirement {
    subject monitor : BabyMonitor;
    require constraint {
      monitor.radio.encryptionEnabled == true
    }
  }

  requirement def CaregiverNotificationRequirement {
    subject monitor : BabyMonitor;
    require constraint {
      monitor.mobileGateway.pushNotificationLatencyLimit.value <= 5.0
    }
  }

  part babyMonitorSystem : BabyMonitor;

}