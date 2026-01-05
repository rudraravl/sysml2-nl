package PolygraphSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def HeartRateValue :> Real;
    attribute def BloodPressureValue :> Real;
    attribute def RespirationRateValue :> Real;
    attribute def SkinConductanceValue :> Real;
    
    item def PhysiologicalSignal {
        attribute heartRate : HeartRateValue;
        attribute systolicPressure : BloodPressureValue;
        attribute diastolicPressure : BloodPressureValue;
        attribute respirationRate : RespirationRateValue;
        attribute skinConductance : SkinConductanceValue;
        attribute timestamp : Real;
    }
    
    item def Question {
        attribute text : String;
        attribute questionType : QuestionType;
        attribute sequenceNumber : Integer;
    }
    
    enum def QuestionType {
        enum control;
        enum relevant;
        enum irrelevant;
    }
    
    item def DeceptionIndicator {
        attribute stressLevel : Real;
        attribute deviationFromBaseline : Real;
        attribute confidence : Real;
        attribute questionReference : Integer;
    }
    
    item def ExaminationReport {
        attribute subjectID : String;
        attribute examinerID : String;
        attribute baselineSignals : PhysiologicalSignal;
        attribute responseSignals : PhysiologicalSignal[*];
        attribute indicators : DeceptionIndicator[*];
        attribute overallAssessment : String;
        attribute examinationDate : String;
    }
    
    port def SensorPort {
        out signal : PhysiologicalSignal;
    }
    
    port def AnalysisPort {
        in rawSignal : PhysiologicalSignal;
        out processedSignal : PhysiologicalSignal;
    }
    
    port def DisplayPort {
        in displayData : PhysiologicalSignal;
        in indicator : DeceptionIndicator;
    }
    
    part def CardiovascularSensor {
        port output : SensorPort;
        attribute samplingRate : Real;
        attribute calibrated : Boolean;
        
        action def MeasureCardiovascular {
            out heartRate : HeartRateValue;
            out systolic : BloodPressureValue;
            out diastolic : BloodPressureValue;
        }
    }
    
    part def RespirationSensor {
        port output : SensorPort;
        attribute sensitivity : Real;
        attribute calibrated : Boolean;
        
        action def MeasureRespiration {
            out rate : RespirationRateValue;
        }
    }
    
    part def GalvanicSkinResponseSensor {
        port output : SensorPort;
        attribute baselineResistance : Real;
        attribute calibrated : Boolean;
        
        action def MeasureSkinConductance {
            out conductance : SkinConductanceValue;
        }
    }
    
    part def SignalProcessor {
        port input : ~SensorPort;
        port output : AnalysisPort;
        
        attribute filterCutoffFrequency : Real;
        attribute noiseThreshold : Real;
        
        action def FilterSignal {
            in rawSignal : PhysiologicalSignal;
            out filteredSignal : PhysiologicalSignal;
        }
        
        action def AmplifySignal {
            in signal : PhysiologicalSignal;
            in gainFactor : Real;
            out amplifiedSignal : PhysiologicalSignal;
        }
    }
    
    part def BaselineEstablisher {
        attribute baselineData : PhysiologicalSignal;
        attribute baselineDuration : Real;
        attribute baselineEstablished : Boolean;
        
        action def EstablishBaseline {
            in signals : PhysiologicalSignal[*];
            out baseline : PhysiologicalSignal;
        }
    }
    
    part def DeceptionAnalyzer {
        attribute analysisAlgorithm : String;
        attribute sensitivityThreshold : Real;
        attribute baselineReference : PhysiologicalSignal;
        
        action def AnalyzeResponse {
            in currentSignal : PhysiologicalSignal;
            in baseline : PhysiologicalSignal;
            in question : Question;
            out indicator : DeceptionIndicator;
        }
        
        action def CompareToBaseline {
            in signal : PhysiologicalSignal;
            in baseline : PhysiologicalSignal;
            out deviation : Real;
        }
        
        action def CalculateStressIndex {
            in heartRateChange : Real;
            in pressureChange : Real;
            in respirationChange : Real;
            in conductanceChange : Real;
            out stressIndex : Real;
        }
    }
    
    part def QuestionController {
        attribute questionQueue : Question[*];
        attribute currentQuestionIndex : Integer;
        attribute timingInterval : Real;
        
        action def PresentQuestion {
            in question : Question;
            out presentedQuestion : Question;
        }
        
        action def AdvanceToNextQuestion {
            inout currentIndex : Integer;
        }
    }
    
    part def DataRecorder {
        attribute recordingActive : Boolean;
        attribute storageCapacity : Integer;
        attribute recordedData : PhysiologicalSignal[*];
        
        action def RecordSignal {
            in signal : PhysiologicalSignal;
            in timestamp : Real;
        }
        
        action def GenerateReport {
            in baseline : PhysiologicalSignal;
            in responses : PhysiologicalSignal[*];
            in indicators : DeceptionIndicator[*];
            out report : ExaminationReport;
        }
    }
    
    part def DisplayConsole {
        port display : DisplayPort;
        attribute displayMode : String;
        attribute realTimeUpdate : Boolean;
        
        action def ShowRealTimeSignals {
            in signals : PhysiologicalSignal;
        }
        
        action def ShowAnalysisResults {
            in indicator : DeceptionIndicator;
        }
    }
    
    part def Polygraph {
        part cardiovascularSensor : CardiovascularSensor;
        part respirationSensor : RespirationSensor;
        part gsrSensor : GalvanicSkinResponseSensor;
        part signalProcessor : SignalProcessor;
        part baselineEstablisher : BaselineEstablisher;
        part analyzer : DeceptionAnalyzer;
        part questionController : QuestionController;
        part recorder : DataRecorder;
        part console : DisplayConsole;
        
        connect cardiovascularSensor.output to signalProcessor.input;
        connect respirationSensor.output to signalProcessor.input;
        connect gsrSensor.output to signalProcessor.input;
        
        perform action conductExamination;
    }
    
    action def ConductPolygraphExamination {
        in subject : String;
        in examiner : String;
        in attribute questions : Question[*];
        out report : ExaminationReport;
        
        private attribute baselineSignal : PhysiologicalSignal;
        private attribute responseSignals : PhysiologicalSignal[*] := ();
        private attribute deceptionIndicators : DeceptionIndicator[*] := ();
        private attribute currentTime : Real := 0.0;
        private attribute moreQuestions : Boolean;
        private attribute allQuestionsComplete : Boolean;
        
        first start;
        
        then action calibrateSensors {
            doc /* Calibrate all sensors before examination */
        }
        
        then action establishBaseline {
            doc /* Collect baseline physiological data */
            out baseline : PhysiologicalSignal;
        }
        then assign baselineSignal := establishBaseline.baseline;
        
        then action briefSubject {
            doc /* Explain procedure to subject */
        }
        
        then merge questionLoop;
        
        then action presentNextQuestion {
            out currentQuestion : Question;
        }
        
        then action waitForStabilization {
            doc /* Allow physiological response to stabilize */
        }
        
        then action acquireSignals {
            out signals : PhysiologicalSignal;
        }
        then assign currentTime := currentTime + 5.0;
        
        then action processSignals {
            in rawSignals : PhysiologicalSignal = acquireSignals.signals;
            out processedSignals : PhysiologicalSignal;
        }
        
        then action analyzeForDeception {
            in currentSignals : PhysiologicalSignal = processSignals.processedSignals;
            in baseline : PhysiologicalSignal = baselineSignal;
            in question : Question = presentNextQuestion.currentQuestion;
            out indicator : DeceptionIndicator;
        }
        
        then assign responseSignals := responseSignals->including(processSignals.processedSignals);
        then assign deceptionIndicators := deceptionIndicators->including(analyzeForDeception.indicator);
        
        then action recordData {
            in signal : PhysiologicalSignal = processSignals.processedSignals;
            in indicator : DeceptionIndicator = analyzeForDeception.indicator;
        }
        
        then decide;
            if moreQuestions then questionLoop;
            if allQuestionsComplete then generateFinalReport;
        
        action generateFinalReport {
            in baseline : PhysiologicalSignal = baselineSignal;
            in responses : PhysiologicalSignal[*] = responseSignals;
            in indicators : DeceptionIndicator[*] = deceptionIndicators;
            out finalReport : ExaminationReport;
        }
        then assign report := generateFinalReport.finalReport;
        
        then done;
    }
    
    state def PolygraphOperatingStates {
        entry; then idle;
        
        state idle {
            entry assign systemStatus := "Ready";
        }
        accept StartExaminationEvent then calibration;
        
        state calibration {
            entry assign systemStatus := "Calibrating";
            do action calibrateAllSensors;
        }
        then baseline;
        
        state baseline {
            entry assign systemStatus := "Establishing Baseline";
            do action collectBaselineData;
        }
        then testing;
        
        state testing {
            entry assign systemStatus := "Testing in Progress";
            
            state questionPresentation {
                entry assign questionStatus := "Presenting";
            }
            then signalAcquisition;
            
            state signalAcquisition {
                entry assign questionStatus := "Acquiring Signals";
            }
            then analysis;
            
            state analysis {
                entry assign questionStatus := "Analyzing";
            }
            then decide;
                if moreQuestions then questionPresentation;
                if testComplete then exit;
        }
        then reporting;
        
        state reporting {
            entry assign systemStatus := "Generating Report";
            do action compileExaminationReport;
        }
        then idle;
        
        accept EmergencyStopEvent then idle;
        
        private attribute systemStatus : String;
        private attribute questionStatus : String;
        private attribute moreQuestions : Boolean;
        private attribute testComplete : Boolean;
    }
    
    part polygraphSystem : Polygraph {
        perform action conductExamination : ConductPolygraphExamination;
        exhibit state operatingStates : PolygraphOperatingStates;
    }
    
    requirement def <'REQ-001'> PrimaryFunctionRequirement {
        doc /* The polygraph system shall detect and assess physiological responses to questioning 
             for the purpose of deception detection by monitoring cardiovascular activity, 
             respiration, and galvanic skin response. */
        
        subject polygraphSystem;
        
        require constraint functionalCapability {
            doc /* System must measure all required physiological parameters */
        }
    }
    
    requirement def <'REQ-002'> SensorAccuracyRequirement {
        doc /* All physiological sensors shall maintain measurement accuracy within specified tolerances:
             Heart rate: ±2 bpm, Blood pressure: ±3 mmHg, Respiration: ±1 breath/min, 
             Skin conductance: ±0.1 microsiemens */
        
        subject polygraphSystem.cardiovascularSensor;
        subject polygraphSystem.respirationSensor;
        subject polygraphSystem.gsrSensor;
    }
    
    requirement def <'REQ-003'> BaselineEstablishmentRequirement {
        doc /* The system shall establish a stable physiological baseline for each subject 
             prior to questioning, with a minimum baseline period of 3 minutes. */
        
        subject polygraphSystem.baselineEstablisher;
        
        require constraint baselineDuration {
            polygraphSystem.baselineEstablisher.baselineDuration >= 180.0
        }
    }
    
    requirement def <'REQ-004'> DataRecordingRequirement {
        doc /* The system shall continuously record all physiological signals with timestamps 
             synchronized to question presentation events. */
        
        subject polygraphSystem.recorder;
    }
    
    requirement def <'REQ-005'> AnalysisRequirement {
        doc /* The system shall analyze physiological responses by comparing current signals 
             to established baseline and generate deception indicators with confidence levels. */
        
        subject polygraphSystem.analyzer;
    }
    
    requirement <'SYS-001'> polygraphSystemRequirement {
        doc /* The polygraph system shall conduct deception detection examinations by monitoring 
             and analyzing physiological responses to structured questioning. */
        
        assume constraint qualifiedOperator {
            doc /* Assumes trained and certified polygraph examiner */
        }
        
        assume constraint controlledEnvironment {
            doc /* Assumes quiet, temperature-controlled examination room */
        }
        
        assume constraint subjectCooperation {
            doc /* Assumes voluntary subject participation and cooperation */
        }
        
        require PrimaryFunctionRequirement;
        require SensorAccuracyRequirement;
        require BaselineEstablishmentRequirement;
        require DataRecordingRequirement;
        require AnalysisRequirement;
    }
}
