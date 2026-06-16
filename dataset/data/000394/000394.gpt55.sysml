package HybrotHighLevelModel {

  import ScalarValues::*;
  import SI::*;

  value def Millisecond {
    specializes Real;
    attribute unit : String = "ms";
  }

  value def Second {
    specializes Real;
    attribute unit : String = "s";
  }

  value def Hertz {
    specializes Real;
    attribute unit : String = "Hz";
  }

  value def Millivolt {
    specializes Real;
    attribute unit : String = "mV";
  }

  value def Microampere {
    specializes Real;
    attribute unit : String = "uA";
  }

  value def DegreeCelsius {
    specializes Real;
    attribute unit : String = "degC";
  }

  value def Percent {
    specializes Real;
    attribute unit : "%";
  }

  value def MillimeterPerSecond {
    specializes Real;
    attribute unit : "mm/s";
  }

  value def RadianPerSecond {
    specializes Real;
    attribute unit : "rad/s";
  }

  value def Lux {
    specializes Real;
    attribute unit : "lx";
  }

  value def Millimeter {
    specializes Real;
    attribute unit : "mm";
  }

  value def Volt {
    specializes Real;
    attribute unit : "V";
  }

  value def Joule {
    specializes Real;
    attribute unit : "J";
  }

  enum def CultureHealthState {
    enum viable;
    enum stressed;
    enum unstable;
    enum nonviable;
  }

  enum def RobotMobilityMode {
    enum stopped;
    enum exploratory;
    enum avoidance;
    enum goalSeeking;
    enum safeReturn;
  }

  enum def HybrotOperatingMode {
    enum dormant;
    enum stabilizingCulture;
    enum calibratingInterface;
    enum closedLoopEmbodiedOperation;
    enum protectiveShutdown;
  }

  item def NeuralSpike {
    attribute electrodeId : Integer;
    attribute amplitude : Millivolt;
    attribute timestamp : Millisecond;
  }

  item def NeuralSpikeTrain {
    attribute meanSpikeRate : Hertz;
    attribute burstRate : Hertz;
    attribute synchronyIndex : Percent;
    attribute windowDuration : Millisecond;
    part spikes : NeuralSpike[0..*];
  }

  item def StimulationPulse {
    attribute electrodeId : Integer;
    attribute pulseAmplitude : Microampere;
    attribute pulseWidth : Millisecond;
    attribute pulseFrequency : Hertz;
    attribute interPhaseDelay : Millisecond;
    attribute deliveredEnergy : Joule;
  }

  item def StimulationPattern {
    attribute patternId : String;
    attribute repetitionRate : Hertz;
    attribute duration : Millisecond;
    part pulses : StimulationPulse[1..*];
  }

  item def SensorFrame {
    attribute frameTime : Millisecond;
    attribute leftLightLevel : Lux;
    attribute rightLightLevel : Lux;
    attribute forwardObstacleDistance : Millimeter;
    attribute leftObstacleDistance : Millimeter;
    attribute rightObstacleDistance : Millimeter;
    attribute platformSpeed : MillimeterPerSecond;
    attribute yawRate : RadianPerSecond;
  }

  item def EncodedSensoryStimulus {
    attribute encodedIntensity : Percent;
    attribute encodedDirectionBias : Percent;
    attribute encodedThreatLevel : Percent;
    attribute encodingLatency : Millisecond;
    part stimulationPattern : StimulationPattern;
  }

  item def MotorCommand {
    attribute leftWheelVelocity : MillimeterPerSecond;
    attribute rightWheelVelocity : MillimeterPerSecond;
    attribute commandConfidence : Percent;
    attribute commandLatency : Millisecond;
    attribute mobilityMode : RobotMobilityMode;
  }

  item def MotionState {
    attribute forwardVelocity : MillimeterPerSecond;
    attribute yawRate : RadianPerSecond;
    attribute distanceToObstacle : Millimeter;
    attribute activeMode : RobotMobilityMode;
  }

  item def CultureHealthReport {
    attribute temperature : DegreeCelsius;
    attribute dissolvedOxygen : Percent;
    attribute nutrientLevel : Percent;
    attribute wasteLevel : Percent;
    attribute spontaneousSpikeRate : Hertz;
    attribute viability : Percent;
    attribute healthState : CultureHealthState;
  }

  item def NutrientMedium {
    attribute glucoseConcentration : Percent;
    attribute oxygenSaturation : Percent;
    attribute temperature : DegreeCelsius;
    attribute volume : Real;
  }

  item def WasteMedium {
    attribute metabolicWasteConcentration : Percent;
    attribute volume : Real;
  }

  item def ElectricalPower {
    attribute voltage : Volt;
    attribute availableEnergy : Joule;
  }

  port def NeuralRecordingPort {
    out item spikeTrain : NeuralSpikeTrain;
  }

  port def NeuralStimulationPort {
    in item stimulationPattern : StimulationPattern;
  }

  port def SensorDataPort {
    out item sensorFrame : SensorFrame;
  }

  port def EncodedStimulusPort {
    out item encodedStimulus : EncodedSensoryStimulus;
  }

  port def MotorCommandPort {
    in item motorCommand : MotorCommand;
  }

  port def MotionFeedbackPort {
    out item motionState : MotionState;
  }

  port def CultureHealthPort {
    out item healthReport : CultureHealthReport;
  }

  port def MediumSupplyPort {
    in item nutrientMedium : NutrientMedium;
    out item wasteMedium : WasteMedium;
  }

  port def PowerPort {
    in item electricalPower : ElectricalPower;
  }

  port def SafetyCommandPort {
    in item shutdownRequest : Boolean;
    out item safeStateConfirmed : Boolean;
  }

  part def LivingNeuronalCulture {
    attribute cultureId : String;
    attribute targetTemperature : DegreeCelsius = 37.0;
    attribute minimumViability : Percent = 70.0;
    attribute baselineSpikeRate : Hertz = 5.0;
    attribute maximumSafeStimulationAmplitude : Microampere = 20.0;

    port recording : NeuralRecordingPort;
    port stimulation : NeuralStimulationPort;
    port health : CultureHealthPort;
    port medium : MediumSupplyPort;

    item currentSpikeTrain : NeuralSpikeTrain;
    item currentHealthReport : CultureHealthReport;
  }

  part def MicroElectrodeArrayInterface {
    attribute electrodeCount : Integer = 60;
    attribute samplingRate : Hertz = 25000.0;
    attribute stimulationResolution : Microampere = 0.1;
    attribute recordingNoiseLimit : Millivolt = 0.05;

    port cultureRecording : NeuralRecordingPort;
    port cultureStimulation : NeuralStimulationPort;
    port encodedStimulusInput : NeuralStimulationPort;
    port decodedSpikeOutput : NeuralRecordingPort;
    port power : PowerPort;
  }

  part def SensorySubsystem {
    attribute obstacleDetectionRange : Millimeter = 800.0;
    attribute lightSensitivityFloor : Lux = 1.0;
    attribute framePeriod : Millisecond = 20.0;

    port sensorOutput : SensorDataPort;
    port power : PowerPort;
  }

  part def SensoryEncoder {
    attribute maximumEncodingLatency : Millisecond = 30.0;
    attribute obstacleThreatThreshold : Millimeter = 150.0;
    attribute highThreatStimulusAmplitude : Microampere = 12.0;
    attribute lowThreatStimulusAmplitude : Microampere = 3.0;

    port sensedWorld : SensorDataPort;
    port encodedOutput : EncodedStimulusPort;
    port stimulationOutput : NeuralStimulationPort;
  }

  part def NeuralDecoder {
    attribute decodingWindow : Millisecond = 100.0;
    attribute minimumCommandConfidence : Percent = 60.0;
    attribute maximumMotorCommandLatency : Millisecond = 150.0;

    port neuralInput : NeuralRecordingPort;
    port motorOutput : MotorCommandPort;
  }

  part def MobileRobotBody {
    attribute wheelBase : Millimeter = 120.0;
    attribute maximumForwardVelocity : MillimeterPerSecond = 250.0;
    attribute maximumYawRate : RadianPerSecond = 2.5;
    attribute safeObstacleStopDistance : Millimeter = 80.0;

    port commandInput : MotorCommandPort;
    port motionFeedback : MotionFeedbackPort;
    port power : PowerPort;
    port safety : SafetyCommandPort;
  }

  part def IncubationAndLifeSupportSubsystem {
    attribute nominalTemperature : DegreeCelsius = 37.0;
    attribute allowedTemperatureDeviation : DegreeCelsius = 1.0;
    attribute minimumOxygenSaturation : Percent = 80.0;
    attribute minimumNutrientLevel : Percent = 35.0;
    attribute maximumWasteLevel : Percent = 50.0;

    port cultureMedium : MediumSupplyPort;
    port cultureHealthInput : CultureHealthPort;
    port safety : SafetyCommandPort;
    port power : PowerPort;
  }

  part def SupervisorySafetyController {
    attribute minimumCultureViability : Percent = 70.0;
    attribute maximumCultureTemperature : DegreeCelsius = 38.0;
    attribute minimumCultureTemperature : DegreeCelsius = 36.0;
    attribute maximumObstacleRiskDistance : Millimeter = 50.0;
    attribute shutdownDecisionLatency : Millisecond = 50.0;

    port healthInput : CultureHealthPort;
    port motionInput : MotionFeedbackPort;
    port robotSafety : SafetyCommandPort;
    port lifeSupportSafety : SafetyCommandPort;
  }

  part def PowerSubsystem {
    attribute nominalLogicVoltage : Volt = 5.0;
    attribute nominalMotorVoltage : Volt = 12.0;
    attribute storedEnergy : Joule = 18000.0;

    port powerOutToSensors : PowerPort;
    port powerOutToMEA : PowerPort;
    port powerOutToRobot : PowerPort;
    port powerOutToLifeSupport : PowerPort;
  }

  action def AcquireSensorFrame {
    out item sensedFrame : SensorFrame;
  }

  action def EncodeSensorFrameAsStimulation {
    in item sensedFrame : SensorFrame;
    out item encodedStimulus : EncodedSensoryStimulus;
    out item stimulationPattern : StimulationPattern;
  }

  action def DeliverStimulationToCulture {
    in item stimulationPattern : StimulationPattern;
    out item evokedNeuralActivity : NeuralSpikeTrain;
  }

  action def RecordNeuralResponse {
    in item evokedNeuralActivity : NeuralSpikeTrain;
    out item spikeTrain : NeuralSpikeTrain;
  }

  action def DecodeSpikeTrainToMotorCommand {
    in item spikeTrain : NeuralSpikeTrain;
    out item motorCommand : MotorCommand;
  }

  action def ExecuteMotorCommand {
    in item motorCommand : MotorCommand;
    out item motionState : MotionState;
  }

  action def MonitorCultureHealth {
    out item healthReport : CultureHealthReport;
  }

  action def ApplyProtectiveShutdown {
    in item healthReport : CultureHealthReport;
    in item motionState : MotionState;
    out item safeStateConfirmed : Boolean;
  }

  action def ClosedLoopEmbodiedHybrotFunction {
    in item environmentalContext : SensorFrame;
    out item adaptiveMotion : MotionState;

    action acquire : AcquireSensorFrame;
    action encode : EncodeSensorFrameAsStimulation;
    action stimulate : DeliverStimulationToCulture;
    action record : RecordNeuralResponse;
    action decode : DecodeSpikeTrainToMotorCommand;
    action execute : ExecuteMotorCommand;
    action monitor : MonitorCultureHealth;

    flow acquire.sensedFrame to encode.sensedFrame;
    flow encode.stimulationPattern to stimulate.stimulationPattern;
    flow stimulate.evokedNeuralActivity to record.evokedNeuralActivity;
    flow record.spikeTrain to decode.spikeTrain;
    flow decode.motorCommand to execute.motorCommand;
    flow execute.motionState to adaptiveMotion;
  }

  state def HybrotOperationalStateMachine {
    attribute mode : HybrotOperatingMode;

    entry action initializeMode {
      mode = HybrotOperatingMode::dormant;
    }

    state Dormant {
      entry action setDormant {
        mode = HybrotOperatingMode::dormant;
      }
    }

    state CultureStabilization {
      entry action stabilizeWetware {
        mode = HybrotOperatingMode::stabilizingCulture;
      }
    }

    state InterfaceCalibration {
      entry action calibrateElectrodes {
        mode = HybrotOperatingMode::calibratingInterface;
      }
    }

    state ClosedLoopOperation {
      entry action enableEmbodiedNeuralControl {
        mode = HybrotOperatingMode::closedLoopEmbodiedOperation;
      }

      do action operate : ClosedLoopEmbodiedHybrotFunction;
    }

    state ProtectiveShutdown {
      entry action enforceSafeState {
        mode = HybrotOperatingMode::protectiveShutdown;
      }

      do action shutdown : ApplyProtectiveShutdown;
    }

    transition initial then Dormant;
    transition Dormant_to_CultureStabilization first Dormant then CultureStabilization accept startupCommand;
    transition CultureStabilization_to_InterfaceCalibration first CultureStabilization then InterfaceCalibration
      if cultureTemperatureStable and cultureViabilityAcceptable;
    transition InterfaceCalibration_to_ClosedLoopOperation first InterfaceCalibration then ClosedLoopOperation
      if electrodeImpedanceAcceptable and decoderConfidenceAcceptable;
    transition ClosedLoopOperation_to_ProtectiveShutdown first ClosedLoopOperation then ProtectiveShutdown
      if cultureHealthUnsafe or obstacleCollisionImminent or shutdownRequested;
    transition ProtectiveShutdown_to_Dormant first ProtectiveShutdown then Dormant
      if safeStateConfirmed;
  }

  constraint def CultureTemperatureWithinSafeRange {
    in temperature : DegreeCelsius;
    constraint temperature >= 36.0 and temperature <= 38.0;
  }

  constraint def CultureViabilityAcceptable {
    in viability : Percent;
    constraint viability >= 70.0;
  }

  constraint def StimulationAmplitudeSafe {
    in pulseAmplitude : Microampere;
    constraint pulseAmplitude <= 20.0;
  }

  constraint def ClosedLoopLatencyBound {
    in sensingLatency : Millisecond;
    in encodingLatency : Millisecond;
    in decodingLatency : Millisecond;
    in commandLatency : Millisecond;
    constraint sensingLatency + encodingLatency + decodingLatency + commandLatency <= 250.0;
  }

  constraint def ObstacleAvoidanceBound {
    in distanceToObstacle : Millimeter;
    constraint distanceToObstacle >= 50.0;
  }

  requirement def PrimaryFunctionRequirement {
    doc
    /*
     * The Hybrot shall use a living neuronal culture interfaced through a microelectrode array
     * to convert sensed environmental context into adaptive mobile robot motion while maintaining
     * the viability of the biological neural controller.
     */

    subject hybrot : HybrotSystem;

    require constraint {
      hybrot.primaryFunction ==
      "Biologically mediated closed-loop sensing, neural processing, and adaptive locomotion using a living neuronal culture coupled to a mobile robot body."
    }
  }

  requirement def CultureViabilityRequirement {
    subject culture : LivingNeuronalCulture;

    require constraint CultureViabilityAcceptable {
      viability = culture.currentHealthReport.viability;
    }
  }

  requirement def CultureTemperatureRequirement {
    subject culture : LivingNeuronalCulture;

    require constraint CultureTemperatureWithinSafeRange {
      temperature = culture.currentHealthReport.temperature;
    }
  }

  requirement def SafeStimulationRequirement {
    subject culture : LivingNeuronalCulture;

    require constraint StimulationAmplitudeSafe {
      pulseAmplitude = culture.maximumSafeStimulationAmplitude;
    }
  }

  requirement def ClosedLoopResponsivenessRequirement {
    subject decoder : NeuralDecoder;

    require constraint ClosedLoopLatencyBound {
      sensingLatency = 20.0;
      encodingLatency = 30.0;
      decodingLatency = decoder.decodingWindow;
      commandLatency = decoder.maximumMotorCommandLatency;
    }
  }

  requirement def CollisionAvoidanceRequirement {
    subject robot : MobileRobotBody;

    require constraint ObstacleAvoidanceBound {
      distanceToObstacle = robot.safeObstacleStopDistance;
    }
  }

  part def HybrotSystem {
    attribute systemName : String = "Hybrot";
    attribute primaryFunction : String =
      "Biologically mediated closed-loop sensing, neural processing, and adaptive locomotion using a living neuronal culture coupled to a mobile robot body.";

    attribute nominalClosedLoopPeriod : Millisecond = 100.0;
    attribute targetCultureTemperature : DegreeCelsius = 37.0;
    attribute operatingMode : HybrotOperatingMode = HybrotOperatingMode::dormant;

    part culture : LivingNeuronalCulture {
      cultureId = "cortical-neuron-culture-001";
      targetTemperature = 37.0;
      minimumViability = 70.0;
      baselineSpikeRate = 5.0;
      maximumSafeStimulationAmplitude = 20.0;
    }

    part mea : MicroElectrodeArrayInterface {
      electrodeCount = 60;
      samplingRate = 25000.0;
      stimulationResolution = 0.1;
      recordingNoiseLimit = 0.05;
    }

    part sensors : SensorySubsystem {
      obstacleDetectionRange = 800.0;
      lightSensitivityFloor = 1.0;
      framePeriod = 20.0;
    }

    part encoder : SensoryEncoder {
      maximumEncodingLatency = 30.0;
      obstacleThreatThreshold = 150.0;
      highThreatStimulusAmplitude = 12.0;
      lowThreatStimulusAmplitude = 3.0;
    }

    part decoder : NeuralDecoder {
      decodingWindow = 100.0;
      minimumCommandConfidence = 60.0;
      maximumMotorCommandLatency = 150.0;
    }

    part robotBody : MobileRobotBody {
      wheelBase = 120.0;
      maximumForwardVelocity = 250.0;
      maximumYawRate = 2.5;
      safeObstacleStopDistance = 80.0;
    }

    part lifeSupport : IncubationAndLifeSupportSubsystem {
      nominalTemperature = 37.0;
      allowedTemperatureDeviation = 1.0;
      minimumOxygenSaturation = 80.0;
      minimumNutrientLevel = 35.0;
      maximumWasteLevel = 50.0;
    }

    part safetyController : SupervisorySafetyController {
      minimumCultureViability = 70.0;
      maximumCultureTemperature = 38.0;
      minimumCultureTemperature = 36.0;
      maximumObstacleRiskDistance = 50.0;
      shutdownDecisionLatency = 50.0;
    }

    part power : PowerSubsystem {
      nominalLogicVoltage = 5.0;
      nominalMotorVoltage = 12.0;
      storedEnergy = 18000.0;
    }

    port externalPowerInput : PowerPort;

    connection cultureRecordingLink connect culture.recording to mea.cultureRecording;
    connection cultureStimulationLink connect mea.cultureStimulation to culture.stimulation;
    connection sensorToEncoderLink connect sensors.sensorOutput to encoder.sensedWorld;
    connection encoderToMEALink connect encoder.stimulationOutput to mea.encodedStimulusInput;
    connection meaToDecoderLink connect mea.decodedSpikeOutput to decoder.neuralInput;
    connection decoderToRobotLink connect decoder.motorOutput to robotBody.commandInput;
    connection robotMotionToSafetyLink connect robotBody.motionFeedback to safetyController.motionInput;
    connection cultureHealthToSafetyLink connect culture.health to safetyController.healthInput;
    connection cultureHealthToLifeSupportLink connect culture.health to lifeSupport.cultureHealthInput;
    connection mediumExchangeLink connect lifeSupport.cultureMedium to culture.medium;
    connection robotSafetyLink connect safetyController.robotSafety to robotBody.safety;
    connection lifeSupportSafetyLink connect safetyController.lifeSupportSafety to lifeSupport.safety;

    connection sensorPowerLink connect power.powerOutToSensors to sensors.power;
    connection meaPowerLink connect power.powerOutToMEA to mea.power;
    connection robotPowerLink connect power.powerOutToRobot to robotBody.power;
    connection lifeSupportPowerLink connect power.powerOutToLifeSupport to lifeSupport.power;

    perform behavior : ClosedLoopEmbodiedHybrotFunction;
    exhibit stateMachine : HybrotOperationalStateMachine;
  }

  part hybrot : HybrotSystem;

  satisfy PrimaryFunctionRequirement by hybrot;
  satisfy CultureViabilityRequirement by hybrot.culture;
  satisfy CultureTemperatureRequirement by hybrot.culture;
  satisfy SafeStimulationRequirement by hybrot.culture;
  satisfy ClosedLoopResponsivenessRequirement by hybrot.decoder;
  satisfy CollisionAvoidanceRequirement by hybrot.robotBody;
}
