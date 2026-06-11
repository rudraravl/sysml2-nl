package FractureSonography {

  import ScalarValues::*;

  attribute def FrequencyMHz :> Real { :>> unit = "MHz"; }
  attribute def AcousticPowerMilliWattPerCm2 :> Real { :>> unit = "mW/cm^2"; }
  attribute def DepthMillimeter :> Real { :>> unit = "mm"; }
  attribute def DistanceMillimeter :> Real { :>> unit = "mm"; }
  attribute def TimeSecond :> Real { :>> unit = "s"; }
  attribute def TemperatureCelsius :> Real { :>> unit = "degC"; }
  attribute def VoltageVolt :> Real { :>> unit = "V"; }
  attribute def DataRateMbps :> Real { :>> unit = "Mb/s"; }
  attribute def ConfidencePercent :> Real { :>> unit = "%"; }

  enum def ScanMode {
    enum linearBMode;
    enum compoundBMode;
    enum powerDoppler;
    enum boneSurfaceEnhancement;
  }

  enum def FractureLikelihood {
    enum unlikely;
    enum indeterminate;
    enum likely;
    enum urgentReferral;
  }

  item def UltrasoundPulse {
    attribute centerFrequency : FrequencyMHz;
    attribute acousticPower : AcousticPowerMilliWattPerCm2;
    attribute pulseDuration : TimeSecond;
    attribute scanMode : ScanMode;
  }

  item def EchoFrame {
    attribute imagingDepth : DepthMillimeter;
    attribute frameTimestamp : TimeSecond;
    attribute lineCount : Integer;
    attribute averageSignalToNoiseRatio : Real;
  }

  item def BoneSurfaceFeature {
    attribute corticalStepOff : DistanceMillimeter;
    attribute corticalGap : DistanceMillimeter;
    attribute periostealElevation : DistanceMillimeter;
    attribute posteriorShadowDetected : Boolean;
    attribute confidence : ConfidencePercent;
  }

  item def FractureAssessment {
    attribute likelihood : FractureLikelihood;
    attribute suspectedFracturePresent : Boolean;
    attribute maximumCorticalDiscontinuity : DistanceMillimeter;
    attribute confidence : ConfidencePercent;
    attribute recommendedAction : String;
  }

  item def PatientScanContext {
    attribute patientIdentifier : String;
    attribute anatomicalRegion : String;
    attribute painPointMarked : Boolean;
    attribute operatorIdentifier : String;
  }

  item def SonographyReport {
    attribute studyIdentifier : String;
    attribute regionScanned : String;
    attribute primaryFinding : String;
    attribute assessment : FractureAssessment;
    attribute savedFrameCount : Integer;
    attribute generatedAt : TimeSecond;
  }

  port def AcousticTransmitPort {
    out item pulse : UltrasoundPulse;
  }

  port def AcousticReceivePort {
    in item echo : EchoFrame;
  }

  port def ProbeDataPort {
    out item echoFrame : EchoFrame;
    in item transmitCommand : UltrasoundPulse;
  }

  port def ProcessingPort {
    in item frameIn : EchoFrame;
    out item featureOut : BoneSurfaceFeature;
    out item assessmentOut : FractureAssessment;
  }

  port def DisplayPort {
    in item frameDisplay : EchoFrame;
    in item assessmentDisplay : FractureAssessment;
  }

  port def ReportPort {
    in item reportIn : SonographyReport;
    out item reportOut : SonographyReport;
  }

  part def UltrasoundTransducerArray {
    attribute elementCount : Integer = 128;
    attribute nominalFrequency : FrequencyMHz = 12.0;
    attribute minimumFrequency : FrequencyMHz = 7.5;
    attribute maximumFrequency : FrequencyMHz = 18.0;
    attribute maximumSurfaceTemperature : TemperatureCelsius = 41.0;

    port tx : AcousticTransmitPort;
    port rx : AcousticReceivePort;
  }

  part def HandheldLinearProbe {
    attribute probeWidth : DistanceMillimeter = 38.0;
    attribute sterileCoverApplied : Boolean;
    attribute couplingGelPresent : Boolean;
    attribute contactPressureNominal : Boolean;

    part array : UltrasoundTransducerArray;

    port data : ProbeDataPort;
    port acousticOut : AcousticTransmitPort;
    port acousticIn : AcousticReceivePort;

    connect array.tx to acousticOut;
    connect acousticIn to array.rx;
  }

  part def Beamformer {
    attribute channelCount : Integer = 128;
    attribute maxFrameRate : Real = 60.0;
    attribute transmitVoltage : VoltageVolt = 70.0;

    port probeInterface : ProbeDataPort;
    port processingInterface : ProcessingPort;
  }

  part def BoneImageProcessor {
    attribute minimumDetectableStepOff : DistanceMillimeter = 0.5;
    attribute minimumConfidenceForLikelyFracture : ConfidencePercent = 80.0;
    attribute modelVersion : String = "cortical-surface-v4.2";

    port processing : ProcessingPort;
  }

  part def OperatorDisplay {
    attribute diagonalSize : DistanceMillimeter = 180.0;
    attribute brightnessLevel : Integer = 85;
    attribute overlayEnabled : Boolean = true;

    port displayInput : DisplayPort;
  }

  part def ReportManager {
    attribute localStorageEncrypted : Boolean = true;
    attribute retainedStudyLimit : Integer = 5000;

    port report : ReportPort;
  }

  part def PowerAndSafetyController {
    attribute batteryVoltage : VoltageVolt;
    attribute thermalLimit : TemperatureCelsius = 41.0;
    attribute acousticOutputLimit : AcousticPowerMilliWattPerCm2 = 720.0;
    attribute emergencyStopActive : Boolean = false;
  }

  action def AcquireBoneSurfaceImages {
    in context : PatientScanContext;
    out frame : EchoFrame;

    first start;
    then configureProbe;
    then emitPulse;
    then receiveEcho;
    then reconstructFrame;
    then done;

    action configureProbe;
    action emitPulse;
    action receiveEcho;
    action reconstructFrame;
  }

  action def DetectCorticalDiscontinuity {
    in frame : EchoFrame;
    out feature : BoneSurfaceFeature;

    first start;
    then enhanceBoneLine;
    then locateCorticalSurface;
    then measureStepOffAndGap;
    then classifyFeature;
    then done;

    action enhanceBoneLine;
    action locateCorticalSurface;
    action measureStepOffAndGap;
    action classifyFeature;
  }

  action def ProduceFractureAssessment {
    in feature : BoneSurfaceFeature;
    out assessment : FractureAssessment;

    first start;
    then compareAgainstClinicalThresholds;
    then assignLikelihood;
    then generateRecommendation;
    then done;

    action compareAgainstClinicalThresholds;
    action assignLikelihood;
    action generateRecommendation;
  }

  action def PerformFractureSonographyStudy {
    in scanContext : PatientScanContext;
    out report : SonographyReport;

    action acquire : AcquireBoneSurfaceImages {
      in context = scanContext;
    }

    action detect : DetectCorticalDiscontinuity {
      in frame = acquire.frame;
    }

    action assess : ProduceFractureAssessment {
      in feature = detect.feature;
    }

    action composeReport {
      in assessment = assess.assessment;
      out report = report;
    }

    first acquire then detect then assess then composeReport;
  }

  state def ImagingSessionStateMachine {
    entry;
    state Off;
    state Ready;
    state PatientContextLoaded;
    state Scanning;
    state Processing;
    state Reviewing;
    state ReportStored;
    state Fault;

    transition first Off;
    transition Off_to_Ready
      first Off
      then Ready;

    transition Ready_to_ContextLoaded
      first Ready
      then PatientContextLoaded;

    transition ContextLoaded_to_Scanning
      first PatientContextLoaded
      then Scanning;

    transition Scanning_to_Processing
      first Scanning
      then Processing;

    transition Processing_to_Reviewing
      first Processing
      then Reviewing;

    transition Reviewing_to_ReportStored
      first Reviewing
      then ReportStored;

    transition Any_to_Fault
      first Ready
      then Fault;
  }

  part def FractureSonographySystem {
    doc /* Primary function: acquire high-frequency ultrasound images over a painful or injured anatomical region, identify cortical bone surface discontinuities, estimate fracture likelihood, and present a structured assessment to support clinical triage without ionizing radiation. */

    attribute systemIdentifier : String = "FS-US-001";
    attribute operatingFrequency : FrequencyMHz = 12.0;
    attribute maximumImagingDepth : DepthMillimeter = 45.0;
    attribute maximumAcousticPower : AcousticPowerMilliWattPerCm2 = 720.0;
    attribute bootTime : TimeSecond = 18.0;
    attribute wirelessDataRate : DataRateMbps = 150.0;

    part probe : HandheldLinearProbe;
    part beamformer : Beamformer;
    part processor : BoneImageProcessor;
    part display : OperatorDisplay;
    part reportManager : ReportManager;
    part safetyController : PowerAndSafetyController;

    port reportPort : ReportPort;

    connect probe.data to beamformer.probeInterface;
    connect beamformer.processingInterface to processor.processing;
    connect processor.processing to display.displayInput;
    connect reportManager.report to reportPort;

    perform action studyWorkflow : PerformFractureSonographyStudy;

    exhibit state sessionStates : ImagingSessionStateMachine;
  }

  requirement def PrimaryFunctionRequirement {
    doc /* The system shall provide non-ionizing fracture sonography by acquiring ultrasound images of cortical bone, detecting surface discontinuities, and producing a fracture assessment for the scanned anatomical region. */
    subject system : FractureSonographySystem;

    require constraint {
      system.maximumImagingDepth >= 30.0
    }
  }

  requirement def AcousticSafetyRequirement {
    doc /* The system shall limit acoustic output and probe surface temperature during scanning. */
    subject system : FractureSonographySystem;

    require constraint {
      system.maximumAcousticPower <= 720.0
    }
  }

  requirement def DetectionPerformanceRequirement {
    doc /* The system shall detect cortical step-off features of at least 1.0 mm under valid coupling and scan conditions. */
    subject processor : BoneImageProcessor;

    require constraint {
      processor.minimumDetectableStepOff <= 1.0
    }
  }

  requirement def ReportRequirement {
    doc /* The system shall generate a structured sonography report containing region scanned, primary finding, fracture likelihood, confidence, and recommended action. */
    subject report : SonographyReport;

    require constraint {
      report.savedFrameCount >= 1
    }
  }

  requirement def WorkflowRequirement {
    doc /* The system shall complete image acquisition, feature detection, assessment generation, review, and report storage within one imaging session. */
    subject system : FractureSonographySystem;
  }

  satisfy PrimaryFunctionRequirement by FractureSonographySystem;
  satisfy AcousticSafetyRequirement by PowerAndSafetyController;
  satisfy DetectionPerformanceRequirement by BoneImageProcessor;
  satisfy ReportRequirement by ReportManager;
  satisfy WorkflowRequirement by PerformFractureSonographyStudy;
}