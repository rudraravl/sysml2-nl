package HumphreyVisualFieldAnalyzer {
    import ScalarValues::*;
    import ISQ::*;
    import ISQDate::*;

    // ===== Value Types =====
    value def Luminance :> Real { unit 'cd/m²'; }
    value def StimulusDuration :> Real { unit 'ms'; }
    value def ReactionTime :> Real { unit 'ms'; }
    value def VisualFieldAngle :> Real { unit 'deg'; }
    value def Probability :> Real { unit '%'; }
    value def PatientAge :> Real { unit 'a'; }
    value def SamplingRate :> Real { unit 'Hz'; }

    // ===== Item Types =====
    item def TestProtocol {
        attribute name : String;
        attribute strategy : String;
        attribute testPointCount : Integer;
        attribute maxStimulusIntensity : Luminance := 10000.0;
        attribute minStimulusIntensity : Luminance := 0.1;
    }

    item def StimulusLocation {
        attribute x : VisualFieldAngle;
        attribute y : VisualFieldAngle;
    }

    item def LightStimulus {
        attribute intensity : Luminance;
        attribute duration : StimulusDuration;
        attribute location : StimulusLocation;
        attribute presented : Boolean;
        attribute catchTrial : Boolean;
        attribute catchType : String; // "none", "falsePositive", "falseNegative"
    }

    item def PatientResponse {
        attribute detected : Boolean;
        attribute reactionTime : ReactionTime;
        attribute stimulusId : String;
    }

    item def FixationStatus {
        attribute fixating : Boolean;
        attribute deviationX : VisualFieldAngle;
        attribute deviationY : VisualFieldAngle;
        attribute lossRecorded : Boolean;
    }

    item def ThresholdResult {
        attribute location : StimulusLocation;
        attribute threshold : Luminance;
        attribute reliable : Boolean;
    }

    item def VisualFieldMap {
        attribute grayscaleData : String;
        attribute meanDeviation : Probability;
        attribute patternStandardDeviation : Probability;
        attribute shortTermFluctuation : Probability;
        attribute correctedPatternStandardDeviation : Probability;
        attribute falsePositiveRate : Probability;
        attribute falseNegativeRate : Probability;
        attribute fixationLossRate : Probability;
        attribute thresholdResults : ThresholdResult[0..*];
    }

    item def ClinicalReport {
        attribute patientId : String;
        attribute patientAge : PatientAge;
        attribute testDate : DateTime;
        attribute protocolName : String;
        attribute visualFieldMap : VisualFieldMap;
        attribute interpretation : String;
        attribute reliabilityFlag : Boolean;
    }

    // ===== Port Definitions =====
    port def StimulusCommandPort {
        out stimulusCommand : LightStimulus;
    }

    port def StimulusReceivePort {
        in stimulusCommand : LightStimulus;
    }

    port def ResponseOutPort {
        out patientResponse : PatientResponse;
    }

    port def ResponseInPort {
        in patientResponse : PatientResponse;
    }

    port def FixationOutPort {
        out fixationStatus : FixationStatus;
    }

    port def FixationInPort {
        in fixationStatus : FixationStatus;
    }

    port def ReportOutPort {
        out report : ClinicalReport;
    }

    port def ReportInPort {
        in report : ClinicalReport;
    }

    // ===== Parts =====
    part def OpticalProjectionSystem {
        attribute calibrationFactor : Real = 1.0;
        attribute backgroundIllumination : Luminance = 10.0;
        port stimulusReceive : StimulusReceivePort;

        action def PresentStimulus {
            in stimulus : LightStimulus;
            attribute projectedIntensity : Luminance := stimulus.intensity * calibrationFactor;
        }

        action def CalibrateOptics {
            out calibrated : Boolean;
        }

        perform action calibrateOptics : CalibrateOptics;
        perform action presentStimulus : PresentStimulus {
            in stimulus = stimulusReceive.stimulusCommand;
        }
    }

    part def PatientResponseInterface {
        attribute buttonEnabled : Boolean = true;
        port responseOut : ResponseOutPort;

        action def CaptureButtonPress {
            out response : PatientResponse;
        }

        state def ButtonState;
        state machine ButtonStateMachine {
            state Released;
            state Pressed;
            transition releasedToPressed from Released to Pressed when true;
            transition pressedToReleased from Pressed to Released when true;
        }

        perform action captureButtonPress : CaptureButtonPress {
            out response = responseOut.patientResponse;
        }
    }

    part def FixationMonitoringSystem {
        attribute samplingRate : SamplingRate = 60.0;
        attribute maxDeviationTolerance : VisualFieldAngle = 2.0;
        port fixationOut : FixationOutPort;

        action def TrackEye {
            in imageFrame : String;
            out status : FixationStatus;
        }

        action def RecordFixationLoss {
            in status : FixationStatus;
            out recorded : Boolean;
        }

        perform action trackEye : TrackEye {
            out status = fixationOut.fixationStatus;
        }

        perform action recordFixationLoss : RecordFixationLoss;
    }

    part def TestControlProcessor {
        attribute selectedProtocol : TestProtocol;
        attribute testPointsMeasured : Integer = 0;
        attribute totalTestPoints : Integer;
        attribute falsePositiveCount : Integer = 0;
        attribute falseNegativeCount : Integer = 0;
        attribute fixationLossCount : Integer = 0;
        attribute currentThresholdResults : ThresholdResult[0..*];

        port stimulusCommand : StimulusCommandPort;
        port responseIn : ResponseInPort;
        port fixationIn : FixationInPort;
        port reportOut : ReportOutPort;

        action def SelectProtocol {
            in protocol : TestProtocol;
        }

        action def GenerateStimulus {
            out stimulus : LightStimulus;
        }

        action def EvaluateResponse {
            in response : PatientResponse;
            in fixation : FixationStatus;
            out valid : Boolean;
        }

        action def ThresholdAlgorithm {
            in response : PatientResponse;
            in location : StimulusLocation;
            out threshold : Luminance;
        }

        action def ReliabilityCheck {
            in response : PatientResponse;
            in stimulus : LightStimulus;
            out falsePositive : Boolean;
            out falseNegative : Boolean;
        }

        action def AnalyzeResults {
            in thresholdResults : ThresholdResult[0..*];
            out visualFieldMap : VisualFieldMap;
        }

        action def CompileReport {
            in visualFieldMap : VisualFieldMap;
            out report : ClinicalReport;
        }

        state def ProcessorState;
        state machine ExaminationStateMachine {
            state Idle;
            state Initializing;
            state Testing;
            state Analyzing;
            state Reporting;
            state Complete;

            transition init from Idle to Initializing when true;
            transition startTest from Initializing to Testing when true;
            transition finishTest from Testing to Analyzing when testPointsMeasured == totalTestPoints;
            transition analyze from Analyzing to Reporting when true;
            transition report from Reporting to Complete when true;
        }

        perform action selectProtocol : SelectProtocol;
        perform action generateStimulus : GenerateStimulus {
            out stimulus = stimulusCommand.stimulusCommand;
        }
        perform action evaluateResponse : EvaluateResponse;
        perform action thresholdAlgorithm : ThresholdAlgorithm;
        perform action reliabilityCheck : ReliabilityCheck;
        perform action analyzeResults : AnalyzeResults;
        perform action compileReport : CompileReport {
            out report = reportOut.report;
        }
    }

    part def ResultsDisplaySystem {
        attribute displayResolution : String = "1920x1080";
        attribute ageMatchedNormDatabase : String = "HumphreyNorms_v5";
        port reportIn : ReportInPort;

        action def GenerateGrayscale {
            in visualFieldMap : VisualFieldMap;
            out grayscaleImage : String;
        }

        action def ComputeStatisticalIndices {
            in visualFieldMap : VisualFieldMap;
            in patientAge : PatientAge;
            out indices : String;
        }

        action def RenderReport {
            in report : ClinicalReport;
            out renderedDisplay : String;
        }

        perform action generateGrayscale : GenerateGrayscale;
        perform action computeStatisticalIndices : ComputeStatisticalIndices;
        perform action renderReport : RenderReport {
            in report = reportIn.report;
        }
    }

    // ===== Top-Level System =====
    part def HumphreyVisualFieldAnalyzer {
        attribute deviceSerialNumber : String;
        attribute firmwareVersion : String;

        part opticalSystem : OpticalProjectionSystem;
        part controlProcessor : TestControlProcessor;
        part fixationMonitor : FixationMonitoringSystem;
        part responseInterface : PatientResponseInterface;
        part displaySystem : ResultsDisplaySystem;

        connection stimulusFlow from controlProcessor.stimulusCommand to opticalSystem.stimulusReceive;
        connection responseFlow from responseInterface.responseOut to controlProcessor.responseIn;
        connection fixationFlow from fixationMonitor.fixationOut to controlProcessor.fixationIn;
        connection reportFlow from controlProcessor.reportOut to displaySystem.reportIn;
    }

    // ===== Requirements =====
    requirement def DetectVisionLoss {
        subject analyzer : HumphreyVisualFieldAnalyzer;
        objective {
            doc "The system shall detect and monitor vision loss in patients, including symptoms of glaucoma, stroke, or other neurological conditions.";
        }
    }

    requirement def ProjectCalibratedStimuli {
        subject opticalSystem : OpticalProjectionSystem;
        objective {
            doc "The optical projection system shall project calibrated light stimuli of varying intensities at specific predetermined locations within the patient's peripheral vision.";
        }
    }

    requirement def OrchestrateTestProtocol {
        subject controlProcessor : TestControlProcessor;
        objective {
            doc "The test control processor shall orchestrate the entire examination based on a selected test protocol.";
        }
    }

    requirement def MonitorFixation {
        subject fixationMonitor : FixationMonitoringSystem;
        objective {
            doc "The fixation monitoring system shall continuously watch the patient's eye to confirm steady gaze on a central target and record any deviation or loss of fixation.";
        }
    }

    requirement def RecordPatientResponse {
        subject responseInterface : PatientResponseInterface;
        objective {
            doc "The patient response interface shall record patient responses and reaction times whenever a light stimulus is perceived.";
        }
    }

    requirement def PerformReliabilityChecks {
        subject controlProcessor : TestControlProcessor;
        objective {
            doc "The control processor shall perform reliability checks by occasionally not presenting a stimulus to catch false positive clicks and by presenting a very bright stimulus to check for false negatives.";
        }
    }

    requirement def DetermineThreshold {
        subject controlProcessor : TestControlProcessor;
        objective {
            doc "The control processor shall employ a thresholding algorithm to determine the dimmest light a patient can see at each point in the visual field.";
        }
    }

    requirement def ComputeVisualFieldMap {
        subject controlProcessor : TestControlProcessor;
        objective {
            doc "The control processor shall analyze the complete dataset to compute a visual field map once all test points are measured.";
        }
    }

    requirement def GenerateClinicalReport {
        subject displaySystem : ResultsDisplaySystem;
        objective {
            doc "The results display system shall generate a report including a grayscale map and statistical indices comparing patient results to age-matched norms.";
        }
    }

    requirement def SystemRequirements {
        subject analyzer : HumphreyVisualFieldAnalyzer;
        satisfy DetectVisionLoss by analyzer;
        satisfy ProjectCalibratedStimuli by analyzer.opticalSystem;
        satisfy OrchestrateTestProtocol by analyzer.controlProcessor;
        satisfy MonitorFixation by analyzer.fixationMonitor;
        satisfy RecordPatientResponse by analyzer.responseInterface;
        satisfy PerformReliabilityChecks by analyzer.controlProcessor;
        satisfy DetermineThreshold by analyzer.controlProcessor;
        satisfy ComputeVisualFieldMap by analyzer.controlProcessor;
        satisfy GenerateClinicalReport by analyzer.displaySystem;
    }
}
