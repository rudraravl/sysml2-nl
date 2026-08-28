package PolygraphSystem {

    import ScalarValues::*;

    // ===== Units =====

    unit def beats_per_min;
    unit def mmHg;
    unit def breaths_per_min;
    unit def microsiemens;
    unit def percent;
    unit def seconds;
    unit def millivolts;

    // ===== Value Types =====

    value type HeartRate = Real { unit beats_per_min; }
    value type SystolicPressure = Real { unit mmHg; }
    value type DiastolicPressure = Real { unit mmHg; }
    value type BreathingRate = Real { unit breaths_per_min; }
    value type SkinConductance = Real { unit microsiemens; }
    value type StressLevel = Real { unit percent; }
    value type ConfidenceScore = Real { unit percent; }
    value type Timestamp = Real { unit seconds; }
    value type SignalAmplitude = Real { unit millivolts; }
    value type SignalQuality = Real { unit percent; }

    // ===== Enumerations =====

    enumeration def QuestionType {
        control;
        relevant;
        irrelevant;
    }

    enumeration def OperationalState {
        idle;
        calibration;
        baselineEstablishment;
        activeTesting;
        reporting;
    }

    enumeration def ExaminerCommandKind {
        startCalibration;
        startBaseline;
        startTesting;
        nextQuestion;
        finishTesting;
        generateReport;
    }

    // ===== Item Definitions =====

    item def RawCardiovascularData {
        attribute heartRate : HeartRate;
        attribute systolic : SystolicPressure;
        attribute diastolic : DiastolicPressure;
        attribute timestamp : Timestamp;
    }

    item def RawRespirationData {
        attribute breathingRate : BreathingRate;
        attribute amplitude : SignalAmplitude;
        attribute timestamp : Timestamp;
    }

    item def RawGSRData {
        attribute conductance : SkinConductance;
        attribute timestamp : Timestamp;
    }

    item def ProcessedCardiovascularData {
        attribute heartRate : HeartRate;
        attribute systolic : SystolicPressure;
        attribute diastolic : DiastolicPressure;
        attribute timestamp : Timestamp;
        attribute quality : SignalQuality;
    }

    item def ProcessedRespirationData {
        attribute breathingRate : BreathingRate;
        attribute timestamp : Timestamp;
        attribute quality : SignalQuality;
    }

    item def ProcessedGSRData {
        attribute conductance : SkinConductance;
        attribute timestamp : Timestamp;
        attribute quality : SignalQuality;
    }

    item def PhysiologicalBaseline {
        attribute restingHeartRate : HeartRate;
        attribute restingSystolic : SystolicPressure;
        attribute restingDiastolic : DiastolicPressure;
        attribute restingBreathingRate : BreathingRate;
        attribute restingSkinConductance : SkinConductance;
        attribute establishedAt : Timestamp;
    }

    item def Question {
        attribute id : String;
        attribute text : String;
        attribute type : QuestionType;
        attribute sequenceNumber : Integer;
    }

    item def QuestionResponse {
        attribute questionId : String;
        attribute timestamp : Timestamp;
        attribute heartRate : HeartRate;
        attribute systolic : SystolicPressure;
        attribute diastolic : DiastolicPressure;
        attribute breathingRate : BreathingRate;
        attribute skinConductance : SkinConductance;
    }

    item def DeceptionIndicator {
        attribute questionId : String;
        attribute stressLevel : StressLevel;
        attribute confidenceScore : ConfidenceScore;
        attribute timestamp : Timestamp;
        attribute flagged : Boolean;
        attribute heartRateDeviation : HeartRate;
        attribute breathingRateDeviation : BreathingRate;
        attribute conductanceDeviation : SkinConductance;
    }

    item def DisplayUpdate {
        attribute heartRate : HeartRate;
        attribute systolic : SystolicPressure;
        attribute diastolic : DiastolicPressure;
        attribute breathingRate : BreathingRate;
        attribute skinConductance : SkinConductance;
        attribute timestamp : Timestamp;
    }

    item def ExaminationReport {
        attribute subjectId : String;
        attribute examinerId : String;
        attribute baseline : PhysiologicalBaseline;
        attribute responses : QuestionResponse[0..*];
        attribute indicators : DeceptionIndicator[0..*];
        attribute overallStressLevel : StressLevel;
        attribute overallAssessment : String;
        attribute generatedAt : Timestamp;
    }

    item def ExaminerCommand {
        attribute kind : ExaminerCommandKind;
        attribute timestamp : Timestamp;
        attribute questionText : String[0..1];
    }

    // ===== Port Definitions =====

    port def RawCardioPort {
        out data : RawCardiovascularData;
    }

    port def RawRespPort {
        out data : RawRespirationData;
    }

    port def RawGSRPort {
        out data : RawGSRData;
    }

    port def ProcCardioPort {
        out data : ProcessedCardiovascularData;
    }

    port def ProcRespPort {
        out data : ProcessedRespirationData;
    }

    port def ProcGSRPort {
        out data : ProcessedGSRData;
    }

    port def QuestionPort {
        out question : Question;
    }

    port def BaselinePort {
        out baseline : PhysiologicalBaseline;
    }

    port def ResponsePort {
        out response : QuestionResponse;
    }

    port def IndicatorPort {
        out indicator : DeceptionIndicator;
    }

    port def DisplayPort {
        out update : DisplayUpdate;
    }

    port def ReportPort {
        out report : ExaminationReport;
    }

    port def CommandPort {
        in command : ExaminerCommand;
    }

    // ===== Part Definitions: Sensors =====

    part def CardiovascularSensor {
        port rawOut : RawCardioPort;
        attribute samplingRate : Real = 100.0;
        attribute isAttached : Boolean = false;

        action def senseCardiovascular {
            out data : RawCardiovascularData;
            doc { Continuously samples heart rate and blood pressure from the subject. }
        }
    }

    part def RespirationSensor {
        port rawOut : RawRespPort;
        attribute samplingRate : Real = 50.0;
        attribute isAttached : Boolean = false;

        action def senseRespiration {
            out data : RawRespirationData;
            doc { Continuously monitors chest expansion to derive breathing rate. }
        }
    }

    part def GSRSensor {
        port rawOut : RawGSRPort;
        attribute samplingRate : Real = 20.0;
        attribute isAttached : Boolean = false;

        action def senseGSR {
            out data : RawGSRData;
            doc { Measures skin conductance via electrodes attached to the subject. }
        }
    }

    // ===== Part Definition: Signal Processor =====

    part def SignalProcessor {
        port cardioIn : ~RawCardioPort;
        port respIn : ~RawRespPort;
        port gsrIn : ~RawGSRPort;
        port cardioOut : ProcCardioPort;
        port respOut : ProcRespPort;
        port gsrOut : ProcGSRPort;
        port displayOut : DisplayPort;

        attribute filterCutoff : Real = 0.5;
        attribute amplificationFactor : Real = 10.0;
        attribute noiseThreshold : Real = 0.05;

        action def filterCardio {
            in raw : RawCardiovascularData;
            out processed : ProcessedCardiovascularData;
            doc { Removes noise from cardiovascular signal and amplifies for analysis. }
        }

        action def filterResp {
            in raw : RawRespirationData;
            out processed : ProcessedRespirationData;
            doc { Removes noise from respiration signal and amplifies for analysis. }
        }

        action def filterGSR {
            in raw : RawGSRData;
            out processed : ProcessedGSRData;
            doc { Removes noise from GSR signal and amplifies for analysis. }
        }

        action def generateDisplayUpdate {
            in cardio : ProcessedCardiovascularData;
            in resp : ProcessedRespirationData;
            in gsr : ProcessedGSRData;
            out update : DisplayUpdate;
            doc { Combines processed signals into a display update for real-time visualization. }
        }
    }

    // ===== Part Definition: Question Controller =====

    part def QuestionController {
        port commandIn : CommandPort;
        port questionOut : QuestionPort;

        attribute questionSet : Question[0..*];
        attribute currentIndex : Integer = 0;
        attribute totalQuestions : Integer = 0;

        action def loadQuestionSet {
            in questions : Question[0..*];
            doc { Loads the structured series of control, relevant, and irrelevant questions. }
        }

        action def presentNextQuestion {
            out question : Question;
            doc { Presents the next question in the sequence to the subject. }
        }

        action def receiveCommand {
            in command : ExaminerCommand;
            doc { Processes examiner commands to advance or modify the question sequence. }
        }
    }

    // ===== Part Definition: Deception Analyzer =====

    part def DeceptionAnalyzer {
        port cardioIn : ~ProcCardioPort;
        port respIn : ~ProcRespPort;
        port gsrIn : ~ProcGSRPort;
        port questionIn : ~QuestionPort;
        port baselineOut : BaselinePort;
        port responseOut : ResponsePort;
        port indicatorOut : IndicatorPort;

        attribute baseline : PhysiologicalBaseline;
        attribute deviationThreshold : Real = 15.0;
        attribute baselineSampleCount : Integer = 0;
        attribute minBaselineSamples : Integer = 100;
        attribute baselineEstablished : Boolean = false;

        action def collectBaselineSamples {
            in cardio : ProcessedCardiovascularData;
            in resp : ProcessedRespirationData;
            in gsr : ProcessedGSRData;
            doc { Accumulates resting-state samples to compute the physiological baseline. }
        }

        action def computeBaseline {
            in cardioSamples : ProcessedCardiovascularData[0..*];
            in respSamples : ProcessedRespirationData[0..*];
            in gsrSamples : ProcessedGSRData[0..*];
            out baseline : PhysiologicalBaseline;
            doc { Averages collected resting samples to establish the subject baseline. }
        }

        action def analyzeResponse {
            in question : Question;
            in cardio : ProcessedCardiovascularData;
            in resp : ProcessedRespirationData;
            in gsr : ProcessedGSRData;
            in baseline : PhysiologicalBaseline;
            out response : QuestionResponse;
            out indicator : DeceptionIndicator;
            doc {
                Compares live physiological responses to the established baseline.
                Calculates stress level and confidence score based on deviation magnitudes.
                Flags significant deviations as potential deception indicators.
            }
        }

        action def calculateStressLevel {
            in heartRateDeviation : HeartRate;
            in breathingRateDeviation : BreathingRate;
            in conductanceDeviation : SkinConductance;
            out stressLevel : StressLevel;
            doc { Computes an aggregate stress level from weighted physiological deviations. }
        }

        action def calculateConfidenceScore {
            in stressLevel : StressLevel;
            in baselineStability : SignalQuality;
            out confidence : ConfidenceScore;
            doc { Derives a confidence score reflecting reliability of the deception assessment. }
        }
    }

    // ===== Part Definition: Display Console =====

    part def DisplayConsole {
        port displayIn : ~DisplayPort;
        port indicatorIn : ~IndicatorPort;
        port reportIn : ~ReportPort;

        attribute refreshRate : Real = 60.0;
        attribute graphTimeWindow : Real = 30.0;

        action def renderRealTimeGraphs {
            in update : DisplayUpdate;
            doc { Renders physiological signals as real-time graphs for the examiner. }
        }

        action def renderDeceptionIndicator {
            in indicator : DeceptionIndicator;
            doc { Displays deception indicators including stress level and confidence score. }
        }

        action def renderReport {
            in report : ExaminationReport;
            doc { Displays the comprehensive examination report for examiner review. }
        }
    }

    // ===== Part Definition: Data Recorder =====

    part def DataRecorder {
        port cardioIn : ~ProcCardioPort;
        port respIn : ~ProcRespPort;
        port gsrIn : ~ProcGSRPort;
        port questionIn : ~QuestionPort;
        port responseIn : ~ResponsePort;
        port indicatorIn : ~IndicatorPort;
        port baselineIn : ~BaselinePort;
        port reportOut : ReportPort;

        attribute recordedResponses : QuestionResponse[0..*];
        attribute recordedIndicators : DeceptionIndicator[0..*];
        attribute recordedBaseline : PhysiologicalBaseline[0..1];
        attribute subjectId : String;
        attribute examinerId : String;

        action def logSensorData {
            in cardio : ProcessedCardiovascularData;
            in resp : ProcessedRespirationData;
            in gsr : ProcessedGSRData;
            doc { Logs all processed sensor data with timestamps. }
        }

        action def logQuestion {
            in question : Question;
            doc { Records each question presented with its type and sequence number. }
        }

        action def logResponse {
            in response : QuestionResponse;
            doc { Links physiological responses to specific questions. }
        }

        action def logIndicator {
            in indicator : DeceptionIndicator;
            doc { Records deception indicators linked to specific questions. }
        }

        action def logBaseline {
            in baseline : PhysiologicalBaseline;
            doc { Stores the established physiological baseline. }
        }

        action def compileExaminationReport {
            in baseline : PhysiologicalBaseline;
            in responses : QuestionResponse[0..*];
            in indicators : DeceptionIndicator[0..*];
            out report : ExaminationReport;
            doc {
                Compiles all collected data into a comprehensive examination report
                including baseline, responses, deception indicators, and overall assessment.
            }
        }

        action def computeOverallAssessment {
            in indicators : DeceptionIndicator[0..*];
            out overallStress : StressLevel;
            out assessmentText : String;
            doc { Aggregates individual deception indicators into an overall assessment. }
        }
    }

    // ===== State Machine Definition =====

    state def PolygraphOperation {
        attribute currentState : OperationalState = OperationalState::idle;

        entry; then idle;

        state idle {
            entry { currentState := OperationalState::idle; }
            doc { System is powered on but not actively examining. }
        }

        transition from idle to calibration
            when examinerCommand.kind == ExaminerCommandKind::startCalibration;

        state calibration {
            entry { currentState := OperationalState::calibration; }
            doc { Verifies sensor connectivity, attachment, and signal quality. }
            do { verifySensorAttachments(); }
        }

        transition from calibration to baselineEstablishment
            when calibrationComplete;

        state baselineEstablishment {
            entry { currentState := OperationalState::baselineEstablishment; }
            doc { Records the subject resting physiological state to establish baseline. }
            do { deceptionAnalyzer.collectBaselineSamples(); }
        }

        transition from baselineEstablishment to activeTesting
            when baselineComplete and deceptionAnalyzer.baselineEstablished;

        state activeTesting {
            entry { currentState := OperationalState::activeTesting; }
            doc { Examiner presents questions while system analyzes responses in real time. }
            do { questionController.presentNextQuestion(); }
        }

        transition from activeTesting to reporting
            when examinerCommand.kind == ExaminerCommandKind::finishTesting;

        state reporting {
            entry { currentState := OperationalState::reporting; }
            doc { Compiles all collected data into a comprehensive examination report. }
            do { dataRecorder.compileExaminationReport(); }
        }

        transition from reporting to idle
            when reportComplete;
    }

    // ===== Top-Level System =====

    part def PolygraphSystem {
        port commandIn : CommandPort;
        port reportOut : ReportPort;

        attribute subjectId : String;
        attribute examinerId : String;
        attribute systemState : OperationalState = OperationalState::idle;

        part cardiovascularSensor : CardiovascularSensor {
            port rawOut : RawCardioPort;
        }

        part respirationSensor : RespirationSensor {
            port rawOut : RawRespPort;
        }

        part gsrSensor : GSRSensor {
            port rawOut : RawGSRPort;
        }

        part signalProcessor : SignalProcessor {
            port cardioIn : ~RawCardioPort;
            port respIn : ~RawRespPort;
            port gsrIn : ~RawGSRPort;
            port cardioOut : ProcCardioPort;
            port respOut : ProcRespPort;
            port gsrOut : ProcGSRPort;
            port displayOut : DisplayPort;
        }

        part questionController : QuestionController {
            port commandIn : CommandPort;
            port questionOut : QuestionPort;
        }

        part deceptionAnalyzer : DeceptionAnalyzer {
            port cardioIn : ~ProcCardioPort;
            port respIn : ~ProcRespPort;
            port gsrIn : ~ProcGSRPort;
            port questionIn : ~QuestionPort;
            port baselineOut : BaselinePort;
            port responseOut : ResponsePort;
            port indicatorOut : IndicatorPort;
        }

        part displayConsole : DisplayConsole {
            port displayIn : ~DisplayPort;
            port indicatorIn : ~IndicatorPort;
            port reportIn : ~ReportPort;
        }

        part dataRecorder : DataRecorder {
            port cardioIn : ~ProcCardioPort;
            port respIn : ~ProcRespPort;
            port gsrIn : ~ProcGSRPort;
            port questionIn : ~QuestionPort;
            port responseIn : ~ResponsePort;
            port indicatorIn : ~IndicatorPort;
            port baselineIn : ~BaselinePort;
            port reportOut : ReportPort;
        }

        // Sensor to signal processor connections
        connect cardiovascularSensor.rawOut to signalProcessor.cardioIn;
        connect respirationSensor.rawOut to signalProcessor.respIn;
        connect gsrSensor.rawOut to signalProcessor.gsrIn;

        // Signal processor to deception analyzer connections
        connect signalProcessor.cardioOut to deceptionAnalyzer.cardioIn;
        connect signalProcessor.respOut to deceptionAnalyzer.respIn;
        connect signalProcessor.gsrOut to deceptionAnalyzer.gsrIn;

        // Signal processor to data recorder connections
        connect signalProcessor.cardioOut to dataRecorder.cardioIn;
        connect signalProcessor.respOut to dataRecorder.respIn;
        connect signalProcessor.gsrOut to dataRecorder.gsrIn;

        // Signal processor to display console connection
        connect signalProcessor.displayOut to displayConsole.displayIn;

        // Question controller to deception analyzer and data recorder
        connect questionController.questionOut to deceptionAnalyzer.questionIn;
        connect questionController.questionOut to dataRecorder.questionIn;

        // Deception analyzer outputs
        connect deceptionAnalyzer.baselineOut to dataRecorder.baselineIn;
        connect deceptionAnalyzer.responseOut to dataRecorder.responseIn;
        connect deceptionAnalyzer.indicatorOut to dataRecorder.indicatorIn;
        connect deceptionAnalyzer.indicatorOut to displayConsole.indicatorIn;

        // Data recorder report output
        connect dataRecorder.reportOut to displayConsole.reportIn;
        connect dataRecorder.reportOut to reportOut;

        // Examiner command input
        connect commandIn to questionController.commandIn;

        // State machine behavior
        exhibit PolygraphOperation;
    }

    // ===== Requirements =====

    requirement def PolygraphRequirement {
        doc { Base requirement for the polygraph system. }
        subject polygraph : PolygraphSystem;
    }

    requirement def SensorMeasurementRequirement :> PolygraphRequirement {
        doc {
            The system shall measure cardiovascular, respiratory, and galvanic skin
            response data from the subject using attached physical sensors.
        }
        attribute requiredSensors : Integer = 3;
    }

    requirement def SignalProcessingRequirement :> PolygraphRequirement {
        doc {
            The system shall filter noise and amplify raw sensor signals through an
            internal signal processor before analysis.
        }
        attribute minSignalQuality : SignalQuality = 80.0;
    }

    requirement def BaselineEstablishmentRequirement :> PolygraphRequirement {
        doc {
            The system shall establish a physiological baseline by recording the
            subject resting state before primary questioning begins.
        }
        attribute minBaselineDuration : Timestamp = 60.0;
    }

    requirement def QuestionManagementRequirement :> PolygraphRequirement {
        doc {
            The system shall manage a structured sequence of control, relevant, and
            irrelevant questions during the examination.
        }
    }

    requirement def DeceptionAnalysisRequirement :> PolygraphRequirement {
        doc {
            The system shall continuously compare live physiological responses to the
            established baseline and flag significant deviations as deception indicators
            with a calculated stress level and confidence score.
        }
        attribute deviationThreshold : Real = 15.0;
    }

    requirement def RealTimeDisplayRequirement :> PolygraphRequirement {
        doc {
            The system shall display physiological signals in real time on graphs and
            show analytical results and deception indicators as they are generated.
        }
        attribute maxDisplayLatency : Timestamp = 0.5;
    }

    requirement def DataRecordingRequirement :> PolygraphRequirement {
        doc {
            The system shall log all sensor data, timestamps, and analysis results,
            linking them to the specific questions asked.
        }
    }

    requirement def StateOperationRequirement :> PolygraphRequirement {
        doc {
            The system shall operate through the formal states of calibration, baseline
            establishment, active testing, and reporting.
        }
    }

    requirement def ReportGenerationRequirement :> PolygraphRequirement {
        doc {
            The system shall compile a comprehensive examination report detailing the
            subject baseline, responses, deception indicators, and an overall assessment.
        }
    }

    // ===== Requirement Satisfactions =====

    satisfaction satisfy SensorMeasurementRequirement by cardiovascularSensor;
    satisfaction satisfy SensorMeasurementRequirement by respirationSensor;
    satisfaction satisfy SensorMeasurementRequirement by gsrSensor;
    satisfaction satisfy SignalProcessingRequirement by signalProcessor;
    satisfaction satisfy BaselineEstablishmentRequirement by deceptionAnalyzer;
    satisfaction satisfy QuestionManagementRequirement by questionController;
    satisfaction satisfy DeceptionAnalysisRequirement by deceptionAnalyzer;
    satisfaction satisfy RealTimeDisplayRequirement by displayConsole;
    satisfaction satisfy DataRecordingRequirement by dataRecorder;
    satisfaction satisfy StateOperationRequirement by PolygraphSystem;
    satisfaction satisfy ReportGenerationRequirement by dataRecorder;

}
