package PolygraphSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def HeartRate :> Real;
    attribute def BloodPressure :> Real;
    attribute def RespirationRate :> Real;
    attribute def SkinConductance :> Real;
    attribute def StressLevel :> Real;
    attribute def ConfidenceScore :> Real;

    item def PhysiologicalData {
        attribute heartRate : HeartRate;
        attribute bloodPressure : BloodPressure;
        attribute respirationRate : RespirationRate;
        attribute skinConductance : SkinConductance;
    }

    item def ProcessedData :> PhysiologicalData;

    enum def QuestionType { control; relevant; irrelevant; }

    item def Question {
        attribute text : String;
        attribute type : QuestionType;
    }

    item def DeceptionIndicator {
        attribute stressLevel : StressLevel;
        attribute confidenceScore : ConfidenceScore;
        attribute question : Question;
    }

    item def ExaminationReport {
        attribute baseline : ProcessedData;
        attribute responses : ProcessedData[0..*];
        attribute indicators : DeceptionIndicator[0..*];
        attribute questions : Question[0..*];
        attribute overallAssessment : String;
    }

    attribute def CalibrationCompleteSignal;
    attribute def BaselineCompleteSignal;
    attribute def TestingCompleteSignal;
    attribute def ResetSystemSignal;

    action def CalibrateSensors;
    action def RecordBaseline { out baseline : ProcessedData; }
    action def ProcessSignals {
        in raw : PhysiologicalData;
        out processed : ProcessedData;
    }
    action def AnalyzeDeception {
        in processed : ProcessedData;
        in baseline : ProcessedData;
        in question : Question;
        out indicator : DeceptionIndicator;
    }
    action def GenerateExaminationReport {
        out report : ExaminationReport;
    }

    part def Subject;
    part def Examiner;

    part def CardiovascularSensor {
        out item data : PhysiologicalData;
    }

    part def RespirationSensor {
        out item data : PhysiologicalData;
    }

    part def GSRSensor {
        out item data : PhysiologicalData;
    }

    part def SignalProcessor {
        in item raw : PhysiologicalData;
        out item processed : ProcessedData;
        perform action process : ProcessSignals {
            in raw = raw;
            out processed = processed;
        }
    }

    part def QuestionController {
        out item question : Question;
    }

    part def DeceptionAnalyzer {
        in item processed : ProcessedData;
        in item question : Question;
        out item indicator : DeceptionIndicator;
        attribute baseline : ProcessedData;
        perform action analyze : AnalyzeDeception {
            in processed = processed;
            in baseline = baseline;
            in question = question;
            out indicator = indicator;
        }
    }

    part def DisplayConsole {
        in item processed : ProcessedData;
        in item question : Question;
        in item indicator : DeceptionIndicator;
        in item report : ExaminationReport;
    }

    part def DataRecorder {
        in item processed : ProcessedData;
        in item question : Question;
        in item indicator : DeceptionIndicator;
        out item report : ExaminationReport;
        perform action generateReport : GenerateExaminationReport {
            out report = report;
        }
    }

    state def PolygraphStates {
        entry; then Calibration;
        state Calibration {
            entry action calibrate : CalibrateSensors;
        }
        accept CalibrationCompleteSignal then BaselineEstablishment;
        state BaselineEstablishment {
            entry action recordBaseline : RecordBaseline;
        }
        accept BaselineCompleteSignal then ActiveTesting;
        state ActiveTesting {
            do action analyze : AnalyzeDeception;
        }
        accept TestingCompleteSignal then Reporting;
        state Reporting {
            entry action generateReport : GenerateExaminationReport;
        }
        accept ResetSystemSignal then Calibration;
    }

    requirement def MeasurePhysiologicalResponses {
        doc /* The system shall measure cardiovascular, respiration, and galvanic skin response signals from the subject. */
    }

    requirement def ProcessSignalsRequirement {
        doc /* The signal processor shall filter noise and amplify raw physiological signals for accurate analysis. */
    }

    requirement def EstablishBaselineRequirement {
        doc /* The system shall record the subject's resting physiological state as a baseline before primary questioning. */
    }

    requirement def DetectDeceptionRequirement {
        doc /* The deception analyzer shall compare live responses to the baseline and flag significant deviations as deception indicators with stress level and confidence score. */
    }

    requirement def DisplayResultsRequirement {
        doc /* The display console shall show physiological signals in real-time on graphs and display deception indicators as they are generated. */
    }

    requirement def LogDataRequirement {
        doc /* The data recorder shall log all sensor data, timestamps, and analysis results linked to specific questions asked. */
    }

    requirement def GenerateReportRequirement {
        doc /* The system shall compile a comprehensive examination report detailing baseline, responses, deception indicators, and overall assessment. */
    }

    part def PolygraphSystem {
        part examinedSubject : Subject;
        part examiner : Examiner;
        part cardioSensor : CardiovascularSensor;
        part respSensor : RespirationSensor;
        part gsrSensor : GSRSensor;
        part signalProcessor : SignalProcessor;
        part questionController : QuestionController;
        part deceptionAnalyzer : DeceptionAnalyzer;
        part displayConsole : DisplayConsole;
        part dataRecorder : DataRecorder;

        connect cardioSensor.data to signalProcessor.raw;
        connect respSensor.data to signalProcessor.raw;
        connect gsrSensor.data to signalProcessor.raw;

        connect signalProcessor.processed to deceptionAnalyzer.processed;
        connect signalProcessor.processed to displayConsole.processed;
        connect signalProcessor.processed to dataRecorder.processed;

        connect questionController.question to deceptionAnalyzer.question;
        connect questionController.question to displayConsole.question;
        connect questionController.question to dataRecorder.question;

        connect deceptionAnalyzer.indicator to displayConsole.indicator;
        connect deceptionAnalyzer.indicator to dataRecorder.indicator;

        connect dataRecorder.report to displayConsole.report;

        exhibit state polygraphStates : PolygraphStates;

        satisfy MeasurePhysiologicalResponses by cardioSensor;
        satisfy MeasurePhysiologicalResponses by respSensor;
        satisfy MeasurePhysiologicalResponses by gsrSensor;
        satisfy ProcessSignalsRequirement by signalProcessor;
        satisfy EstablishBaselineRequirement by deceptionAnalyzer;
        satisfy DetectDeceptionRequirement by deceptionAnalyzer;
        satisfy DisplayResultsRequirement by displayConsole;
        satisfy LogDataRequirement by dataRecorder;
        satisfy GenerateReportRequirement by dataRecorder;
    }
}
