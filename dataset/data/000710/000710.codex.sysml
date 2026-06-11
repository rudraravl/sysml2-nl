package EchocardiographyNumericalModeling {

  import ScalarValues::*;
  import SI::*;
  import ISQ::*;

  attribute def MillimeterHg {
    :> ISQ::pressure;
    unit = "mmHg";
  }

  attribute def Decibel {
    :> ISQ::dimensionless;
    unit = "dB";
  }

  attribute def BeatsPerMinute {
    :> ISQ::frequency;
    unit = "beat/min";
  }

  attribute def FramesPerSecond {
    :> ISQ::frequency;
    unit = "frame/s";
  }

  attribute def Percent {
    :> ISQ::dimensionless;
    unit = "%";
  }

  attribute def Milliliter {
    :> ISQ::volume;
    unit = "mL";
  }

  attribute def Millimeter {
    :> ISQ::length;
    unit = "mm";
  }

  attribute def MeterPerSecond {
    :> ISQ::speed;
    unit = "m/s";
  }

  attribute def PascalSecond {
    :> ISQ::dynamicViscosity;
    unit = "Pa*s";
  }

  item def UltrasoundFrame {
    attribute frameIndex : Integer;
    attribute acquisitionTime : Time;
    attribute samplingFrequency : Frequency;
    attribute transmitFrequency : Frequency;
    attribute axialResolution : Millimeter;
    attribute lateralResolution : Millimeter;
    attribute dynamicRange : Decibel;
  }

  item def DopplerPacket {
    attribute packetIndex : Integer;
    attribute sampleVolumeDepth : Millimeter;
    attribute pulseRepetitionFrequency : Frequency;
    attribute meanVelocity : MeterPerSecond;
    attribute aliasingDetected : Boolean;
  }

  item def ECGSample {
    attribute sampleTime : Time;
    attribute heartRate : BeatsPerMinute;
    attribute rWaveDetected : Boolean;
  }

  item def SegmentedGeometry {
    attribute endocardialSurfaceArea : Area;
    attribute epicardialSurfaceArea : Area;
    attribute leftVentricleVolume : Milliliter;
    attribute leftAtriumVolume : Milliliter;
    attribute wallThicknessSeptal : Millimeter;
    attribute wallThicknessPosterior : Millimeter;
    attribute confidence : Percent;
  }

  item def HemodynamicField {
    attribute pressureMean : MillimeterHg;
    attribute pressureGradientPeak : MillimeterHg;
    attribute velocityPeak : MeterPerSecond;
    attribute vorticityMagnitude : Frequency;
    attribute wallShearStressMean : Pressure;
  }

  item def ClinicalMetrics {
    attribute ejectionFraction : Percent;
    attribute strokeVolume : Milliliter;
    attribute cardiacOutput : VolumeFlowRate;
    attribute globalLongitudinalStrain : Percent;
    attribute diastolicEOverEPrime : Real;
    attribute peakTransmitralVelocity : MeterPerSecond;
    attribute estimatedFillingPressure : MillimeterHg;
    attribute modelUncertainty : Percent;
  }

  item def NumericalModelConfiguration {
    attribute meshElementCount : Integer;
    attribute timeStep : Time;
    attribute simulatedCardiacCycles : Integer;
    attribute bloodDensity : Density;
    attribute bloodViscosity : PascalSecond;
    attribute myocardialElasticModulus : Pressure;
    attribute convergenceTolerance : Real;
    attribute maximumIterations : Integer;
  }

  port def FrameInputPort {
    in frame : UltrasoundFrame;
  }

  port def DopplerInputPort {
    in packet : DopplerPacket;
  }

  port def ECGInputPort {
    in sample : ECGSample;
  }

  port def GeometryPort {
    out geometry : SegmentedGeometry;
  }

  port def ModelConfigurationPort {
    in configuration : NumericalModelConfiguration;
  }

  port def HemodynamicPort {
    out field : HemodynamicField;
  }

  port def MetricsPort {
    out metrics : ClinicalMetrics;
  }

  port def AlertPort {
    out alertText : String;
    out severity : Integer;
  }

  action def AcquireEchocardiographicData {
    in patientIdentifier : String;
    in acquisitionDuration : Time;
    out frames : UltrasoundFrame;
    out dopplerPackets : DopplerPacket;
    out ecgSamples : ECGSample;
  }

  action def PreprocessEchoData {
    in rawFrame : UltrasoundFrame;
    in rawDoppler : DopplerPacket;
    out normalizedFrame : UltrasoundFrame;
    out filteredDoppler : DopplerPacket;
  }

  action def SegmentCardiacStructures {
    in normalizedFrame : UltrasoundFrame;
    out geometry : SegmentedGeometry;
  }

  action def BuildPatientSpecificMesh {
    in geometry : SegmentedGeometry;
    in configuration : NumericalModelConfiguration;
    out meshQuality : Percent;
    out accepted : Boolean;
  }

  action def SolveCardiacNumericalModel {
    in geometry : SegmentedGeometry;
    in doppler : DopplerPacket;
    in ecg : ECGSample;
    in configuration : NumericalModelConfiguration;
    out field : HemodynamicField;
    out solverConverged : Boolean;
    out residualNorm : Real;
  }

  action def EstimateClinicalMetrics {
    in geometry : SegmentedGeometry;
    in field : HemodynamicField;
    out metrics : ClinicalMetrics;
  }

  action def ValidateModelResult {
    in metrics : ClinicalMetrics;
    in field : HemodynamicField;
    out valid : Boolean;
    out uncertainty : Percent;
  }

  state def ModelingRunStateMachine {
    entry action initializeRun;
    state idle;
    state acquiringData;
    state preprocessing;
    state segmenting;
    state meshing;
    state solving;
    state estimatingMetrics;
    state validating;
    state reporting;
    state failed;

    transition first idle;

    transition idle_to_acquiring
      first idle
      then acquiringData;

    transition acquiring_to_preprocessing
      first acquiringData
      then preprocessing;

    transition preprocessing_to_segmenting
      first preprocessing
      then segmenting;

    transition segmenting_to_meshing
      first segmenting
      then meshing
      if segmentConfidenceAcceptable;

    transition segmenting_to_failed
      first segmenting
      then failed
      if segmentConfidenceLow;

    transition meshing_to_solving
      first meshing
      then solving
      if meshAccepted;

    transition meshing_to_failed
      first meshing
      then failed
      if meshRejected;

    transition solving_to_estimating
      first solving
      then estimatingMetrics
      if solverConverged;

    transition solving_to_failed
      first solving
      then failed
      if solverDiverged;

    transition estimating_to_validating
      first estimatingMetrics
      then validating;

    transition validating_to_reporting
      first validating
      then reporting
      if modelValid;

    transition validating_to_failed
      first validating
      then failed
      if modelInvalid;
  }

  part def UltrasoundProbe {
    attribute centerFrequency : Frequency = 3.5 [SI::hertz];
    attribute bandwidth : Frequency = 2.0 [SI::hertz];
    attribute elementCount : Integer = 128;
    attribute maxImagingDepth : Millimeter = 180 [Millimeter];
    port frameOut : FrameInputPort;
    port dopplerOut : DopplerInputPort;
  }

  part def ECGSynchronizer {
    attribute samplingRate : Frequency = 500 [SI::hertz];
    attribute rWaveTimingTolerance : Time = 0.010 [SI::second];
    port ecgOut : ECGInputPort;
  }

  part def DataPreprocessor {
    attribute speckleReductionStrength : Percent = 35 [Percent];
    attribute temporalSmoothingWindow : Time = 0.040 [SI::second];
    port frameIn : FrameInputPort;
    port dopplerIn : DopplerInputPort;
    port frameOut : FrameInputPort;
    port dopplerOut : DopplerInputPort;
  }

  part def CardiacSegmentationEngine {
    attribute minimumSegmentationConfidence : Percent = 90 [Percent];
    attribute endocardialTrackingErrorLimit : Millimeter = 1.5 [Millimeter];
    port frameIn : FrameInputPort;
    port geometryOut : GeometryPort;
  }

  part def PatientSpecificNumericalSolver {
    attribute defaultBloodDensity : Density = 1060 [SI::kilogramPerCubicMetre];
    attribute defaultBloodViscosity : PascalSecond = 0.0035 [PascalSecond];
    attribute defaultTimeStep : Time = 0.002 [SI::second];
    attribute residualTolerance : Real = 1.0e-5;
    port geometryIn : GeometryPort;
    port dopplerIn : DopplerInputPort;
    port ecgIn : ECGInputPort;
    port configurationIn : ModelConfigurationPort;
    port fieldOut : HemodynamicPort;
  }

  part def ClinicalMetricEstimator {
    attribute ejectionFractionNormalLowerBound : Percent = 52 [Percent];
    attribute fillingPressureAlertThreshold : MillimeterHg = 15 [MillimeterHg];
    port geometryIn : GeometryPort;
    port fieldIn : HemodynamicPort;
    port metricsOut : MetricsPort;
  }

  part def ModelValidator {
    attribute maximumAllowedUncertainty : Percent = 10 [Percent];
    attribute maximumAllowedPressureResidual : MillimeterHg = 2 [MillimeterHg];
    port metricsIn : MetricsPort;
    port fieldIn : HemodynamicPort;
    port alertOut : AlertPort;
  }

  part def ClinicalReportInterface {
    attribute reportLatencyTarget : Time = 5 [SI::second];
    port metricsIn : MetricsPort;
    port fieldIn : HemodynamicPort;
    port alertIn : AlertPort;
  }

  part def EchocardiographyNumericalModelingSystem {
    attribute primaryFunction : String =
      "Convert patient-specific echocardiographic image, Doppler, and ECG data into a numerical cardiovascular model that estimates cardiac geometry, blood-flow behavior, pressure gradients, ventricular function, and uncertainty for clinical interpretation.";

    attribute targetFrameRate : FramesPerSecond = 60 [FramesPerSecond];
    attribute maximumEndToEndProcessingTime : Time = 120 [SI::second];
    attribute minimumUsableImageConfidence : Percent = 85 [Percent];

    part probe : UltrasoundProbe;
    part ecgSynchronizer : ECGSynchronizer;
    part preprocessor : DataPreprocessor;
    part segmentationEngine : CardiacSegmentationEngine;
    part numericalSolver : PatientSpecificNumericalSolver;
    part metricEstimator : ClinicalMetricEstimator;
    part validator : ModelValidator;
    part reportInterface : ClinicalReportInterface;

    port configurationIn : ModelConfigurationPort;
    port metricsOut : MetricsPort;
    port hemodynamicFieldOut : HemodynamicPort;
    port alertOut : AlertPort;

    connection frameAcquisitionFlow
      connect probe.frameOut to preprocessor.frameIn;

    connection dopplerAcquisitionFlow
      connect probe.dopplerOut to preprocessor.dopplerIn;

    connection ecgTimingFlow
      connect ecgSynchronizer.ecgOut to numericalSolver.ecgIn;

    connection normalizedFrameFlow
      connect preprocessor.frameOut to segmentationEngine.frameIn;

    connection filteredDopplerFlow
      connect preprocessor.dopplerOut to numericalSolver.dopplerIn;

    connection geometryToSolverFlow
      connect segmentationEngine.geometryOut to numericalSolver.geometryIn;

    connection geometryToMetricFlow
      connect segmentationEngine.geometryOut to metricEstimator.geometryIn;

    connection configurationFlow
      connect configurationIn to numericalSolver.configurationIn;

    connection hemodynamicToMetricFlow
      connect numericalSolver.fieldOut to metricEstimator.fieldIn;

    connection hemodynamicToValidatorFlow
      connect numericalSolver.fieldOut to validator.fieldIn;

    connection metricsToValidatorFlow
      connect metricEstimator.metricsOut to validator.metricsIn;

    connection metricsToReportFlow
      connect metricEstimator.metricsOut to reportInterface.metricsIn;

    connection fieldToReportFlow
      connect numericalSolver.fieldOut to reportInterface.fieldIn;

    connection alertToReportFlow
      connect validator.alertOut to reportInterface.alertIn;

    connection externalMetricsFlow
      connect metricEstimator.metricsOut to metricsOut;

    connection externalFieldFlow
      connect numericalSolver.fieldOut to hemodynamicFieldOut;

    connection externalAlertFlow
      connect validator.alertOut to alertOut;

    perform action acquire : AcquireEchocardiographicData;
    perform action preprocess : PreprocessEchoData;
    perform action segment : SegmentCardiacStructures;
    perform action mesh : BuildPatientSpecificMesh;
    perform action solve : SolveCardiacNumericalModel;
    perform action estimate : EstimateClinicalMetrics;
    perform action validate : ValidateModelResult;

    exhibit state runState : ModelingRunStateMachine;
  }

  requirement def PrimaryFunctionRequirement {
    doc /* The system shall numerically model cardiac structure and hemodynamics from echocardiographic images, Doppler measurements, and ECG timing to provide clinically interpretable ventricular function and flow estimates. */
    subject system : EchocardiographyNumericalModelingSystem;
    require constraint {
      system.maximumEndToEndProcessingTime <= 120 [SI::second]
    }
  }

  requirement def ImageDataQualityRequirement {
    doc /* The system shall accept only echocardiographic image sequences with sufficient segmentation confidence for patient-specific geometry construction. */
    subject geometry : SegmentedGeometry;
    require constraint {
      geometry.confidence >= 85 [Percent]
    }
  }

  requirement def SolverConvergenceRequirement {
    doc /* The numerical solver shall converge to a residual norm small enough to support reporting of pressure, velocity, and ventricular function metrics. */
    subject configuration : NumericalModelConfiguration;
    require constraint {
      configuration.convergenceTolerance <= 1.0e-4
    }
  }

  requirement def ClinicalMetricRequirement {
    doc /* The system shall report ejection fraction, stroke volume, cardiac output, strain, peak velocity, estimated filling pressure, and model uncertainty for each completed modeling run. */
    subject metrics : ClinicalMetrics;
    require constraint {
      metrics.modelUncertainty <= 10 [Percent]
    }
  }

  requirement def HemodynamicResultRequirement {
    doc /* The system shall compute hemodynamic fields containing pressure gradient, peak velocity, vorticity magnitude, and wall shear stress derived from patient-specific geometry and Doppler constraints. */
    subject field : HemodynamicField;
    require constraint {
      field.velocityPeak >= 0 [MeterPerSecond]
    }
  }

  requirement def ReportingLatencyRequirement {
    doc /* The system shall make validated model outputs available to the clinical reporting interface within the processing time target after acquisition is complete. */
    subject system : EchocardiographyNumericalModelingSystem;
    require constraint {
      system.maximumEndToEndProcessingTime <= 120 [SI::second]
    }
  }

  satisfy PrimaryFunctionRequirement by EchocardiographyNumericalModelingSystem;
  satisfy ImageDataQualityRequirement by CardiacSegmentationEngine;
  satisfy SolverConvergenceRequirement by PatientSpecificNumericalSolver;
  satisfy ClinicalMetricRequirement by ClinicalMetricEstimator;
  satisfy HemodynamicResultRequirement by PatientSpecificNumericalSolver;
  satisfy ReportingLatencyRequirement by ClinicalReportInterface;

  view def HighLevelSystemContext {
    expose EchocardiographyNumericalModelingSystem;
    expose UltrasoundProbe;
    expose ECGSynchronizer;
    expose ClinicalReportInterface;
    expose PrimaryFunctionRequirement;
  }

}