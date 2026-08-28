package 'Defect Detector System' {
    private import ScalarValues::Real;
    private import ScalarValues::Integer;
    private import ScalarValues::String;
    private import ScalarValues::Boolean;
    private import SI::s;
    private import SI::Hz;

    enum def DefectType {
        scratch;
        dent;
        discoloration;
        missingComponent;
        crack;
        deformation;
    }

    enum def SeverityLevel {
        low;
        medium;
        high;
        critical;
    }

    enum def PassFailStatus {
        pass;
        fail;
    }

    item def Product {
        attribute serialNumber : String;
        attribute productName : String;
    }

    item def Image {
        attribute imageId : String;
        attribute resolutionX : Integer;
        attribute resolutionY : Integer;
        attribute brightness : Real;
        attribute contrast : Real;
        attribute captureTimestamp : Real;
    }

    item def Defect {
        attribute defectType : DefectType;
        attribute positionX : Real;
        attribute positionY : Real;
        attribute severity : SeverityLevel;
        attribute confidence : Real;
    }

    item def InspectionReport {
        attribute reportId : String;
        item detectedDefects[0..*] : Defect;
        attribute defectCount : Integer;
        attribute status : PassFailStatus;
        attribute productSerialNumber : String;
    }

    item def Alert {
        attribute alertId : String;
        attribute alertType : String;
        attribute alertMessage : String;
        attribute severity : SeverityLevel;
    }

    action def CaptureImage {
        in product : Product;
        out image : Image;
    }

    action def PreprocessImage {
        in image : Image;
        out enhancedImage : Image;
    }

    action def DetectDefects {
        in image : Image;
        out defects[0..*] : Defect;
    }

    action def ProcessImage {
        in image : Image;
        out defects[0..*] : Defect;
        action preprocess : PreprocessImage;
        then action detect : DetectDefects;
    }

    action def GenerateReport {
        in defects[0..*] : Defect;
        in productSerialNumber : String;
        out report : InspectionReport;
    }

    action def EvaluateAlert {
        in report : InspectionReport;
        out alert : Alert;
    }

    action def InspectProductFlow {
        action capture : CaptureImage;
        then action process : ProcessImage;
        then action generate : GenerateReport;
        then action evaluate : EvaluateAlert;
    }

    part def ImagingSubsystem {
        attribute lightingLevel : Real = 0.85;
        attribute frameRate : Real = 30 [Hz];
        in port productIn : Product;
        out port imageOut : Image;
    }

    part def ProcessingSubsystem {
        attribute algorithmVersion : String = "defectnet-2.1";
        in port imageIn : Image;
        out port defectsOut : Defect[0..*];
    }

    part def ReportingSubsystem {
        attribute acceptableDefectLimit : Integer = 3;
        in port defectsIn : Defect[0..*];
        out port reportOut : InspectionReport;
    }

    part def AlertSubsystem {
        attribute criticalSeverityThreshold : SeverityLevel = SeverityLevel::critical;
        in port reportIn : InspectionReport;
        out port alertOut : Alert;
    }

    state machine def OperationStates {
        state Idle;
        state Capturing;
        state ProcessingImage;
        state GeneratingReport;
        state EvaluatingAlert;
        transition from Idle to Capturing;
        transition from Capturing to ProcessingImage;
        transition from ProcessingImage to GeneratingReport;
        transition from GeneratingReport to EvaluatingAlert;
        transition from EvaluatingAlert to Idle;
    }

    part def DefectDetectorSystem {
        attribute detectionAccuracy : Real = 0.98;
        attribute inspectionTime : Real = 1.2 [s];
        attribute falseAlarmRate : Real = 0.005;
        attribute uptime : Real = 0.995;

        in port productIn : Product;
        out port reportOut : InspectionReport;
        out port alertOut : Alert;

        perform action inspectProduct[*] ordered references InspectProductFlow;

        part imaging : ImagingSubsystem {
            perform inspectProduct.capture;
        }
        part processing : ProcessingSubsystem {
            perform inspectProduct.process;
        }
        part reporting : ReportingSubsystem {
            perform inspectProduct.generate;
        }
        part alerting : AlertSubsystem {
            perform inspectProduct.evaluate;
        }

        connect productIn to imaging.productIn;
        connect imaging.imageOut to processing.imageIn;
        connect processing.defectsOut to reporting.defectsIn;
        connect reporting.reportOut to alerting.reportIn;
        connect reporting.reportOut to reportOut;
        connect alerting.alertOut to alertOut;

        state machine operationStates : OperationStates;
    }

    requirement def HighDetectionAccuracy {
        attribute requiredAccuracy : Real = 0.98;
        subject detector : DefectDetectorSystem;
        constraint { detector.detectionAccuracy >= requiredAccuracy }
    }

    requirement def FastInspection {
        attribute maxInspectionTime : Real = 1.5 [s];
        subject detector : DefectDetectorSystem;
        constraint { detector.inspectionTime <= maxInspectionTime }
    }

    requirement def LowFalseAlarmRate {
        attribute maxFalseAlarmRate : Real = 0.01;
        subject detector : DefectDetectorSystem;
        constraint { detector.falseAlarmRate <= maxFalseAlarmRate }
    }

    requirement def HighReliability {
        attribute requiredUptime : Real = 0.995;
        subject detector : DefectDetectorSystem;
        constraint { detector.uptime >= requiredUptime }
    }

    part defectDetectorStation : DefectDetectorSystem {
        satisfy HighDetectionAccuracy;
        satisfy FastInspection;
        satisfy LowFalseAlarmRate;
        satisfy HighReliability;
    }
}
