package HumphreyVisualFieldAnalyzer {
    private import ScalarValues::*;
    
    unit cd_per_m2;
    unit deg;
    unit ms;
    unit dB;
    
    attribute def Luminance :> Real {
        unit cd_per_m2;
    }
    attribute def Angle :> Real {
        unit deg;
    }
    attribute def TimeDuration :> Real {
        unit ms;
    }
    attribute def Decibel :> Real {
        unit dB;
    }
    
    attribute def Point2D {
        attribute x : Real;
        attribute y : Real;
    }
    
    item def TestProtocol {
        attribute name : String;
        attribute testGrid : Point2D[*];
        attribute initialLuminance : Luminance;
    }
    
    item def StimulusCommand {
        attribute location : Point2D;
        attribute intensity : Luminance;
        attribute isCatchTrial : Boolean;
    }
    
    item def PatientResponse {
        attribute buttonPressed : Boolean;
        attribute reactionTime : TimeDuration;
        attribute isFalsePositive : Boolean;
    }
    
    item def FixationData {
        attribute gazeStable : Boolean;
        attribute deviation : Angle;
    }
    
    item def ThresholdPoint {
        attribute location : Point2D;
        attribute threshold : Luminance;
    }
    
    item def ReliabilityIndices {
        attribute falsePositiveRate : Real;
        attribute falseNegativeRate : Real;
        attribute fixationLossRate : Real;
    }
    
    item def TestStatistics {
        attribute meanDeviation : Decibel;
        attribute patternStandardDeviation : Decibel;
    }
    
    item def VisualFieldMap {
        attribute thresholds : ThresholdPoint[*];
        attribute grayscale : String;
    }
    
    item def ClinicalReport {
        attribute fieldMap : VisualFieldMap;
        attribute statistics : TestStatistics;
        attribute reliability : ReliabilityIndices;
    }
    
    port def StimulusCommandPort {
        out item stimulus : StimulusCommand;
    }
    
    port def ResponsePort {
        in item response : PatientResponse;
    }
    
    port def FixationPort {
        in item fixation : FixationData;
    }
    
    port def ReportPort {
        out item report : ClinicalReport;
    }
    
    port def ProtocolPort {
        in item protocol : TestProtocol;
    }
    
    part def OpticalProjectionSystem {
        port commandPort : ~StimulusCommandPort;
        action projectStimulus {
            in cmd : StimulusCommand;
            action emitLight;
        }
    }
    
    part def FixationMonitoringSystem {
        port gazePort : ~FixationPort;
        action monitorGaze {
            action trackEye;
            then action computeDeviation;
            then action emitFixationData;
        }
    }
    
    part def PatientResponseInterface {
        port clickPort : ~ResponsePort;
        action recordResponse {
            action waitForButton;
            then action measureReactionTime;
            then action emitResponse;
        }
    }
    
    part def ResultsDisplaySystem {
        port reportInPort : ~ReportPort;
        action generateReport {
            in rpt : ClinicalReport;
            action renderGrayscale;
            then action computeStatistics;
            then action displayResults;
        }
    }
    
    part def TestControlProcessor {
        port stimulusOut : StimulusCommandPort;
        port responseIn : ResponsePort;
        port fixationIn : FixationPort;
        port reportOut : ReportPort;
        port protocolIn : ProtocolPort;
        
        attribute currentProtocol : TestProtocol;
        attribute reliability : ReliabilityIndices;
        attribute fieldMap : VisualFieldMap;
        
        stateMachine TestLifecycle {
            state Idle;
            state AwaitingProtocol;
            state RunningTest;
            state Analyzing;
            state Reporting;
            
            transition from Idle to AwaitingProtocol;
            transition from AwaitingProtocol to RunningTest;
            transition from RunningTest to Analyzing;
            transition from Analyzing to Reporting;
            transition from Reporting to Idle;
        }
        
        function thresholdAlgorithm {
            in presented : Luminance[*];
            in responses : Boolean[*];
            return threshold : Luminance;
        }
        
        function computeReliability {
            in responses : PatientResponse[*];
            return indices : ReliabilityIndices;
        }
    }
    
    part def HumphreyVisualFieldAnalyzerSystem {
        part optical : OpticalProjectionSystem;
        part fixation : FixationMonitoringSystem;
        part response : PatientResponseInterface;
        part processor : TestControlProcessor;
        part display : ResultsDisplaySystem;
        
        interface stimulusInterface connect processor.stimulusOut to optical.commandPort {
            flow stimulusFlow of StimulusCommand from processor.stimulusOut.stimulus to optical.commandPort.stimulus;
        }
        interface responseInterface connect response.clickPort to processor.responseIn {
            flow responseFlow of PatientResponse from response.clickPort.response to processor.responseIn.response;
        }
        interface fixationInterface connect fixation.gazePort to processor.fixationIn {
            flow fixationFlow of FixationData from fixation.gazePort.fixation to processor.fixationIn.fixation;
        }
        interface reportInterface connect processor.reportOut to display.reportInPort {
            flow reportFlow of ClinicalReport from processor.reportOut.report to display.reportInPort.report;
        }
    }
    
    part analyzerInstance : HumphreyVisualFieldAnalyzerSystem;
    
    actor Clinician;
    actor Patient;
    
    usecase PerformVisualFieldTest;
    usecase GenerateClinicalReport;
    usecase MonitorPatientFixation;
    usecase ProvidePatientResponse;
    
    association PerformTestAssoc {
        memberEnd clinician : Clinician;
        memberEnd performTest : PerformVisualFieldTest;
    }
    association SystemTestAssoc {
        memberEnd system : HumphreyVisualFieldAnalyzerSystem;
        memberEnd performTest : PerformVisualFieldTest;
    }
    association PatientResponseAssoc {
        memberEnd patient : Patient;
        memberEnd provideResponse : ProvidePatientResponse;
    }
    association ReportGenAssoc {
        memberEnd system : HumphreyVisualFieldAnalyzerSystem;
        memberEnd genReport : GenerateClinicalReport;
    }
    association FixationAssoc {
        memberEnd system : HumphreyVisualFieldAnalyzerSystem;
        memberEnd monitorFix : MonitorPatientFixation;
    }
    
    requirement DetectVisionLoss {
        text: "The Humphrey Visual Field Analyzer shall systematically map a patient's complete field of vision to detect and monitor vision loss associated with glaucoma, stroke, or neurological conditions.";
    }
    
    requirement ProjectCalibratedStimuli {
        text: "The Optical Projection System shall project calibrated light stimuli of varying intensities at specific predetermined locations within the patient's peripheral vision.";
    }
    
    requirement MonitorFixationDeviation {
        text: "The Fixation Monitoring System shall continuously monitor the patient's gaze and record deviations greater than 2 degrees from the central fixation target.";
    }
    
    requirement RecordPatientResponses {
        text: "The Patient Response Interface shall record patient button presses and reaction times when the patient perceives a light stimulus.";
    }
    
    requirement ReliabilityChecks {
        text: "The Test Control Processor shall perform reliability checks by occasionally not presenting a stimulus to detect false positive responses and by presenting a very bright stimulus to detect false negative responses.";
    }
    
    requirement ThresholdAlgorithm {
        text: "The Test Control Processor shall employ a thresholding algorithm to determine the dimmest light stimulus a patient can perceive at each point in their visual field with an accuracy of plus or minus 1 dB.";
    }
    
    requirement GenerateReport {
        text: "The Results Display System shall generate a clinical report including a grayscale map of the patient's field of vision and statistical indices compared to age-matched norms.";
    }
    
    satisfy DetectVisionLoss by analyzerInstance;
    satisfy ProjectCalibratedStimuli by analyzerInstance.optical;
    satisfy MonitorFixationDeviation by analyzerInstance.fixation;
    satisfy RecordPatientResponses by analyzerInstance.response;
    satisfy ReliabilityChecks by analyzerInstance.processor;
    satisfy ThresholdAlgorithm by analyzerInstance.processor;
    satisfy GenerateReport by analyzerInstance.display;
    
    occurrence def VisualFieldTestSession {
        ref part clinician : Clinician;
        ref part patient : Patient;
        ref part system : HumphreyVisualFieldAnalyzerSystem {
            part :>> processor :>> TestControlProcessor {
                event protocolMsg.targetEvent;
                then event stimulusMsg.sourceEvent;
                then event responseMsg.targetEvent;
                then event fixationMsg.targetEvent;
                then event reportMsg.sourceEvent;
            }
            part :>> optical :>> OpticalProjectionSystem {
                event stimulusMsg.targetEvent;
            }
            part :>> response :>> PatientResponseInterface {
                event responseMsg.sourceEvent;
            }
            part :>> fixation :>> FixationMonitoringSystem {
                event fixationMsg.sourceEvent;
            }
            part :>> display :>> ResultsDisplaySystem {
                event reportMsg.targetEvent;
            }
        }
        message protocolMsg of TestProtocol;
        then message stimulusMsg of StimulusCommand;
        then message responseMsg of PatientResponse;
        then message fixationMsg of FixationData;
        then message reportMsg of ClinicalReport;
    }
}
