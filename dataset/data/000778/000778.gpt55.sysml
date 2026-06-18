package StethoscopeSystemModel {

  import ScalarValues::*;
  import ISQ::*;
  import SI::*;

  attribute def LengthValue :> ISQ::length {
    unit = "m";
  }

  attribute def TubeLengthValue :> LengthValue {
    unit = "cm";
  }

  attribute def DiameterValue :> ISQ::length {
    unit = "mm";
  }

  attribute def MassValue :> ISQ::mass {
    unit = "g";
  }

  attribute def FrequencyValue :> ISQ::frequency {
    unit = "Hz";
  }

  attribute def PressureValue :> ISQ::pressure {
    unit = "Pa";
  }

  attribute def AcousticLevelValue :> ScalarValues::Real {
    unit = "dB SPL";
  }

  attribute def AttenuationValue :> ScalarValues::Real {
    unit = "dB";
  }

  attribute def GainValue :> ScalarValues::Real {
    unit = "dB";
  }

  attribute def ForceValue :> ISQ::force {
    unit = "N";
  }

  attribute def TemperatureValue :> ISQ::temperature {
    unit = "degC";
  }

  attribute def TimeValue :> ISQ::time {
    unit = "s";
  }

  attribute def PercentageValue :> ScalarValues::Real {
    unit = "%";
  }

  enum def AuscultationMode {
    enum bellMode;
    enum diaphragmMode;
  }

  enum def ContactQuality {
    enum noContact;
    enum poorSeal;
    enum acceptableSeal;
    enum optimalSeal;
  }

  enum def BodySoundSourceKind {
    enum cardiac;
    enum pulmonary;
    enum vascular;
    enum gastrointestinal;
  }

  item def BodySurfaceVibration {
    attribute sourceKind: BodySoundSourceKind;
    attribute dominantFrequency: FrequencyValue;
    attribute surfacePressureAmplitude: PressureValue;
    attribute acousticLevel: AcousticLevelValue;
  }

  item def AcousticPressureWave {
    attribute frequency: FrequencyValue;
    attribute pressureAmplitude: PressureValue;
    attribute soundPressureLevel: AcousticLevelValue;
  }

  item def MechanicalMembraneMotion {
    attribute displacement: LengthValue;
    attribute frequency: FrequencyValue;
    attribute contactForce: ForceValue;
  }

  item def BinauralAcousticSignal {
    attribute leftLevel: AcousticLevelValue;
    attribute rightLevel: AcousticLevelValue;
    attribute leftFrequency: FrequencyValue;
    attribute rightFrequency: FrequencyValue;
    attribute channelBalance: AttenuationValue;
  }

  item def ClinicianAuditoryPerception {
    attribute perceivedLevel: AcousticLevelValue;
    attribute perceivedFrequency: FrequencyValue;
    attribute intelligibility: PercentageValue;
  }

  item def AmbientNoise {
    attribute noiseLevel: AcousticLevelValue;
    attribute dominantFrequency: FrequencyValue;
  }

  item def ManualAdjustmentCommand {
    attribute requestedMode: AuscultationMode;
    attribute targetContactForce: ForceValue;
  }

  port def BodyContactPort {
    in item vibration: BodySurfaceVibration;
    out item appliedForce: ForceValue;
  }

  port def AcousticInputPort {
    in item wave: AcousticPressureWave;
  }

  port def AcousticOutputPort {
    out item wave: AcousticPressureWave;
  }

  port def BinauralOutputPort {
    out item signal: BinauralAcousticSignal;
  }

  port def EarInputPort {
    in item signal: BinauralAcousticSignal;
  }

  port def NoiseExposurePort {
    in item noise: AmbientNoise;
  }

  port def ManualControlPort {
    in item command: ManualAdjustmentCommand;
  }

  interface def MechanicalContactInterface {
    end patientSide: BodyContactPort;
    end chestpieceSide: BodyContactPort;
    flow patientSide.vibration to chestpieceSide.vibration;
    flow chestpieceSide.appliedForce to patientSide.appliedForce;
  }

  interface def AcousticTransmissionInterface {
    end source: AcousticOutputPort;
    end receiver: AcousticInputPort;
    flow source.wave to receiver.wave;
  }

  interface def BinauralListeningInterface {
    end source: BinauralOutputPort;
    end receiver: EarInputPort;
    flow source.signal to receiver.signal;
  }

  action def CaptureBodySound {
    in item bodyVibration: BodySurfaceVibration;
    in item contactForce: ForceValue;
    out item membraneMotion: MechanicalMembraneMotion;
    attribute minimumEffectiveForce: ForceValue = 1.0;
    attribute maximumComfortForce: ForceValue = 8.0;
  }

  action def ConvertMembraneMotionToAcousticWave {
    in item membraneMotion: MechanicalMembraneMotion;
    out item chestpieceWave: AcousticPressureWave;
    attribute diaphragmSensitivity: GainValue = 8.0;
    attribute bellSensitivity: GainValue = 5.0;
  }

  action def SelectAuscultationMode {
    in item command: ManualAdjustmentCommand;
    out mode: AuscultationMode;
  }

  action def TransmitAcousticWaveThroughTubing {
    in item chestpieceWave: AcousticPressureWave;
    out item binauralWave: AcousticPressureWave;
    attribute tubeTransmissionLoss: AttenuationValue = 3.0;
    attribute lowFrequencyCutoff: FrequencyValue = 20.0;
    attribute highFrequencyCutoff: FrequencyValue = 1000.0;
  }

  action def SplitSignalToEarpieces {
    in item binauralWave: AcousticPressureWave;
    out item binauralSignal: BinauralAcousticSignal;
    attribute maximumChannelImbalance: AttenuationValue = 2.0;
  }

  action def DeliverSoundToClinician {
    in item binauralSignal: BinauralAcousticSignal;
    out item perception: ClinicianAuditoryPerception;
    attribute minimumUsefulLevel: AcousticLevelValue = 20.0;
    attribute maximumSafeLevel: AcousticLevelValue = 85.0;
  }

  action def SuppressAmbientNoise {
    in item incomingNoise: AmbientNoise;
    out item attenuatedNoise: AmbientNoise;
    attribute passiveNoiseAttenuation: AttenuationValue = 12.0;
  }

  action def PerformAuscultation {
    in item bodyVibration: BodySurfaceVibration;
    in item clinicianCommand: ManualAdjustmentCommand;
    in item ambientNoise: AmbientNoise;
    out item perception: ClinicianAuditoryPerception;

    action selectMode: SelectAuscultationMode {
      in command = clinicianCommand;
    }

    action capture: CaptureBodySound {
      in bodyVibration = bodyVibration;
      in contactForce = clinicianCommand.targetContactForce;
    }

    action convert: ConvertMembraneMotionToAcousticWave {
      in membraneMotion = capture.membraneMotion;
    }

    action transmit: TransmitAcousticWaveThroughTubing {
      in chestpieceWave = convert.chestpieceWave;
    }

    action split: SplitSignalToEarpieces {
      in binauralWave = transmit.binauralWave;
    }

    action noiseControl: SuppressAmbientNoise {
      in incomingNoise = ambientNoise;
    }

    action deliver: DeliverSoundToClinician {
      in binauralSignal = split.binauralSignal;
      out perception = perception;
    }
  }

  state def StethoscopeOperationalStateMachine {
    in contactQuality: ContactQuality;
    in selectedMode: AuscultationMode;

    state Stored;
    state ReadyForUse;
    state PositionedOnPatient;
    state BellAuscultation;
    state DiaphragmAuscultation;
    state SoundTransmission;
    state ListeningComplete;

    transition initial then Stored;

    transition Stored_to_Ready
      first Stored
      then ReadyForUse;

    transition Ready_to_Positioned
      first ReadyForUse
      then PositionedOnPatient
      if contactQuality == ContactQuality::acceptableSeal or contactQuality == ContactQuality::optimalSeal;

    transition Positioned_to_Bell
      first PositionedOnPatient
      then BellAuscultation
      if selectedMode == AuscultationMode::bellMode;

    transition Positioned_to_Diaphragm
      first PositionedOnPatient
      then DiaphragmAuscultation
      if selectedMode == AuscultationMode::diaphragmMode;

    transition Bell_to_Transmission
      first BellAuscultation
      then SoundTransmission;

    transition Diaphragm_to_Transmission
      first DiaphragmAuscultation
      then SoundTransmission;

    transition Transmission_to_Complete
      first SoundTransmission
      then ListeningComplete;

    transition Reposition
      first ListeningComplete
      then PositionedOnPatient
      if contactQuality == ContactQuality::acceptableSeal or contactQuality == ContactQuality::optimalSeal;

    transition RemoveFromPatient
      first ListeningComplete
      then ReadyForUse;
  }

  part def PatientBodySurface {
    attribute localSkinTemperature: TemperatureValue = 34.0;
    attribute nominalHeartSoundFrequency: FrequencyValue = 80.0;
    attribute nominalLungSoundFrequency: FrequencyValue = 250.0;
    attribute nominalBodySoundLevel: AcousticLevelValue = 45.0;
    port contact: BodyContactPort;
  }

  part def Chestpiece {
    attribute outerDiameter: DiameterValue = 45.0;
    attribute mass: MassValue = 80.0;
    attribute effectiveFrequencyRangeLow: FrequencyValue = 20.0;
    attribute effectiveFrequencyRangeHigh: FrequencyValue = 1000.0;
    attribute contactForce: ForceValue = 3.5;
    attribute currentMode: AuscultationMode = AuscultationMode::diaphragmMode;
    attribute contactQuality: ContactQuality = ContactQuality::optimalSeal;

    port patientContact: BodyContactPort;
    port acousticOut: AcousticOutputPort;
    port controlIn: ManualControlPort;

    part diaphragm: Diaphragm;
    part bell: Bell;
    part stem: RotatableAcousticStem;

    action captureSound: CaptureBodySound;
    action convertSound: ConvertMembraneMotionToAcousticWave;
  }

  part def Diaphragm {
    attribute diameter: DiameterValue = 38.0;
    attribute thickness: DiameterValue = 0.25;
    attribute resonanceFrequency: FrequencyValue = 250.0;
    attribute sensitivity: GainValue = 8.0;
    attribute preferredFrequencyLow: FrequencyValue = 100.0;
    attribute preferredFrequencyHigh: FrequencyValue = 1000.0;
  }

  part def Bell {
    attribute diameter: DiameterValue = 30.0;
    attribute cupDepth: DiameterValue = 8.0;
    attribute sensitivity: GainValue = 5.0;
    attribute preferredFrequencyLow: FrequencyValue = 20.0;
    attribute preferredFrequencyHigh: FrequencyValue = 200.0;
  }

  part def RotatableAcousticStem {
    attribute rotationAngle: ScalarValues::Real = 0.0;
    attribute selectedMode: AuscultationMode = AuscultationMode::diaphragmMode;
    port acousticIn: AcousticInputPort;
    port acousticOut: AcousticOutputPort;
  }

  part def FlexibleAcousticTube {
    attribute totalLength: TubeLengthValue = 56.0;
    attribute internalDiameter: DiameterValue = 4.2;
    attribute wallThickness: DiameterValue = 2.0;
    attribute transmissionLoss: AttenuationValue = 3.0;
    attribute kinkRadiusMinimum: DiameterValue = 25.0;
    attribute frequencyRangeLow: FrequencyValue = 20.0;
    attribute frequencyRangeHigh: FrequencyValue = 1000.0;

    port acousticIn: AcousticInputPort;
    port acousticOut: AcousticOutputPort;

    action transmitWave: TransmitAcousticWaveThroughTubing;
  }

  part def BinauralYoke {
    attribute splitLoss: AttenuationValue = 1.0;
    attribute channelBalance: AttenuationValue = 0.5;
    port acousticIn: AcousticInputPort;
    port binauralOut: BinauralOutputPort;

    part leftBranch: EarTube;
    part rightBranch: EarTube;

    action splitSignal: SplitSignalToEarpieces;
  }

  part def EarTube {
    attribute length: TubeLengthValue = 18.0;
    attribute internalDiameter: DiameterValue = 3.6;
    attribute stiffness: ScalarValues::Real = 0.7;
    port acousticIn: AcousticInputPort;
    port acousticOut: AcousticOutputPort;
  }

  part def EarTip {
    attribute diameter: DiameterValue = 12.0;
    attribute materialCompliance: ScalarValues::Real = 0.85;
    attribute passiveNoiseAttenuation: AttenuationValue = 12.0;
    attribute comfortContactForce: ForceValue = 1.2;

    port binauralIn: EarInputPort;
    port ambientNoiseIn: NoiseExposurePort;
  }

  part def ClinicianEars {
    attribute auditoryThreshold: AcousticLevelValue = 10.0;
    attribute safeListeningLimit: AcousticLevelValue = 85.0;
    attribute perceivedIntelligibility: PercentageValue = 90.0;
    port earInput: EarInputPort;
    port ambientNoiseExposure: NoiseExposurePort;
  }

  part def AmbientClinicalEnvironment {
    attribute typicalNoiseLevel: AcousticLevelValue = 55.0;
    attribute dominantNoiseFrequency: FrequencyValue = 500.0;
    port noiseOut: NoiseExposurePort;
  }

  part def AcousticStethoscope {
    attribute overallMass: MassValue = 180.0;
    attribute overallLength: TubeLengthValue = 78.0;
    attribute usableFrequencyLow: FrequencyValue = 20.0;
    attribute usableFrequencyHigh: FrequencyValue = 1000.0;
    attribute nominalAcousticGain: GainValue = 6.0;
    attribute maximumTransmissionLoss: AttenuationValue = 8.0;
    attribute setupTime: TimeValue = 5.0;

    port bodyInterface: BodyContactPort;
    port userControl: ManualControlPort;
    port binauralOutput: BinauralOutputPort;
    port noiseExposure: NoiseExposurePort;

    part chestpiece: Chestpiece;
    part tube: FlexibleAcousticTube;
    part yoke: BinauralYoke;
    part leftEarTip: EarTip;
    part rightEarTip: EarTip;

    connect bodyInterface to chestpiece.patientContact;
    connect chestpiece.acousticOut to tube.acousticIn;
    connect tube.acousticOut to yoke.acousticIn;
    connect yoke.binauralOut to binauralOutput;
    connect userControl to chestpiece.controlIn;
    connect noiseExposure to leftEarTip.ambientNoiseIn;
    connect noiseExposure to rightEarTip.ambientNoiseIn;

    action auscultate: PerformAuscultation;

    state operatingStates: StethoscopeOperationalStateMachine;
  }

  part def AuscultationUseContext {
    part patient: PatientBodySurface;
    part stethoscope: AcousticStethoscope;
    part clinicianEars: ClinicianEars;
    part room: AmbientClinicalEnvironment;

    connect patient.contact to stethoscope.bodyInterface;
    connect stethoscope.binauralOutput to clinicianEars.earInput;
    connect room.noiseOut to stethoscope.noiseExposure;
    connect room.noiseOut to clinicianEars.ambientNoiseExposure;
  }

  requirement def PrimaryFunctionRequirement {
    subject stethoscope: AcousticStethoscope;

    doc /* The stethoscope shall capture low-level acoustic vibrations from a patient's body surface and transmit them as audible binaural sound to the clinician's ears for high-level assessment of cardiac, pulmonary, vascular, or gastrointestinal activity. */

    require constraint {
      stethoscope.usableFrequencyLow <= 20.0 and
      stethoscope.usableFrequencyHigh >= 1000.0 and
      stethoscope.maximumTransmissionLoss <= 8.0
    }
  }

  requirement def BodySoundCaptureRequirement {
    subject chestpiece: Chestpiece;

    doc /* The chestpiece shall provide a sealed contact interface and convert body surface vibration into an acoustic pressure wave. */

    require constraint {
      chestpiece.effectiveFrequencyRangeLow <= 20.0 and
      chestpiece.effectiveFrequencyRangeHigh >= 1000.0 and
      chestpiece.contactForce >= 1.0 and
      chestpiece.contactForce <= 8.0
    }
  }

  requirement def BinauralDeliveryRequirement {
    subject yoke: BinauralYoke;

    doc /* The binaural yoke shall split the transmitted acoustic signal into left and right channels with limited imbalance. */

    require constraint {
      yoke.channelBalance <= 2.0 and
      yoke.splitLoss <= 3.0
    }
  }

  requirement def AmbientNoiseIsolationRequirement {
    subject earTip: EarTip;

    doc /* Each ear tip shall reduce ambient clinical noise sufficiently to support recognition of body sounds. */

    require constraint {
      earTip.passiveNoiseAttenuation >= 10.0
    }
  }

  requirement def ComfortRequirement {
    subject stethoscope: AcousticStethoscope;

    doc /* The stethoscope shall remain light enough for routine clinical use. */

    require constraint {
      stethoscope.overallMass <= 250.0
    }
  }

  requirement def FrequencyCoverageRequirement {
    subject stethoscope: AcousticStethoscope;

    doc /* The stethoscope shall support auscultation over the typical frequency range of clinically relevant body sounds. */

    require constraint {
      stethoscope.usableFrequencyLow <= 20.0 and
      stethoscope.usableFrequencyHigh >= 1000.0
    }
  }

  part useContext: AuscultationUseContext;

  requirement primaryFunction: PrimaryFunctionRequirement {
    subject stethoscope = useContext.stethoscope;
  }

  requirement captureRequirement: BodySoundCaptureRequirement {
    subject chestpiece = useContext.stethoscope.chestpiece;
  }

  requirement deliveryRequirement: BinauralDeliveryRequirement {
    subject yoke = useContext.stethoscope.yoke;
  }

  requirement leftNoiseIsolationRequirement: AmbientNoiseIsolationRequirement {
    subject earTip = useContext.stethoscope.leftEarTip;
  }

  requirement rightNoiseIsolationRequirement: AmbientNoiseIsolationRequirement {
    subject earTip = useContext.stethoscope.rightEarTip;
  }

  requirement comfortRequirement: ComfortRequirement {
    subject stethoscope = useContext.stethoscope;
  }

  requirement frequencyCoverageRequirement: FrequencyCoverageRequirement {
    subject stethoscope = useContext.stethoscope;
  }

  satisfy primaryFunction by useContext.stethoscope;
  satisfy captureRequirement by useContext.stethoscope.chestpiece;
  satisfy deliveryRequirement by useContext.stethoscope.yoke;
  satisfy leftNoiseIsolationRequirement by useContext.stethoscope.leftEarTip;
  satisfy rightNoiseIsolationRequirement by useContext.stethoscope.rightEarTip;
  satisfy comfortRequirement by useContext.stethoscope;
  satisfy frequencyCoverageRequirement by useContext.stethoscope;

}
