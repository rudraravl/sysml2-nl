package DefectDetectorSystem {
    import ScalarValues::*;

    // ===== Value Types =====
    value def FrequencyValue :> Real { doc "Unit: Hz"; }
    value def PercentValue :> Real { doc "Unit: percent"; }
    value def TimeValue :> Real { doc "Unit: s"; }
    value def LengthValue :> Real { doc "Unit: mm"; }
    value def PixelCount :> Integer;
    value def ConfidenceScore :> Real { doc "Range 0 to 100"; }
    value def SeverityLevel :> Integer { doc "Range 1 to 10"; }
    value def DefectCount :> Integer;

    // ===== Enumerations =====
    enum def DefectType {
        scratch;
        dent;
        crack;
        discoloration;
        deformation;
        contamination;
    }

    enum def PassFailStatus {
        pass;
        fail;
    }

    enum def AlertLevel {
        info;
        warning;
        critical;
    }

    // ===== Item Definitions =====
    item def RawImage {
        attribute resolution : PixelCount;
        attribute frameRate : FrequencyValue;
        attribute lightingLevel : PercentValue;
        attribute timestamp : TimeValue;
    }

    item def ProcessedImage {
        attribute contrastEnhanced : Boolean;
        attribute noiseReduced : Boolean;
        attribute sourceImage : RawImage;
    }

    item def Defect {
        attribute type : DefectType;
        attribute positionX : LengthValue;
        attribute positionY : LengthValue;
        attribute severity : SeverityLevel;
        attribute confidence : ConfidenceScore;
    }

    item def InspectionReport {
        attribute reportId : String;
        attribute defects : Defect[0..*];
        attribute totalDefectCount : DefectCount;
        attribute status : PassFailStatus;
        attribute timestamp : TimeValue;
    }

    item def AlertMessage {
        attribute level : AlertLevel;
        attribute reportRef : InspectionReport;
        attribute message : String;
        attribute timestamp : TimeValue;
    }

    // ===== Port Definitions =====
    port def ImagePort {
        out item : RawImage;
    }

    port def DefectListPort {
        out item : Defect[0..*];
    }

    port def ReportPort {
        out item : InspectionReport;
    }

    port def AlertPort {
        out item : AlertMessage;
    }

    // ===== Imaging Subsystem =====
    part def ImagingSubsystem {
        attribute frameRate : FrequencyValue = 60;
        attribute resolution : PixelCount = 4096;
        attribute lightingAdjustable : Boolean = true;
        attribute currentLightingLevel : PercentValue = 50;

        port imageOut : ImagePort;

        action captureImage {
            in productPresent : Boolean;
            out image : RawImage;
        }

        action adjustLighting {
            in ambientLight : PercentValue;
            out lightingLevel : PercentValue;
        }

        state imagingBehavior {
            entry; then idle;

            state idle;
            state adjusting;
            state capturing;

            transition idle -> adjusting
                when productArrives;
            transition adjusting -> capturing
                when lightingOptimal;
            transition capturing -> idle
                when imageCaptured;
        }
    }

    // ===== Processing Subsystem =====
    part def ProcessingSubsystem {
        attribute detectionAccuracy : PercentValue = 98;
        attribute maxProcessingTime : TimeValue = 1.0;

        port imageIn : ~ImagePort;
        port defectListOut : DefectListPort;

        action preprocessImage {
            in rawImage : RawImage;
            out processedImage : ProcessedImage;
        }

        action detectDefects {
            in processedImage : ProcessedImage;
            out defects : Defect[0..*];
        }

        action analyzeDefect {
            in region;
            out defect : Defect;
        }

        state processingBehavior {
            entry; then waiting;

            state waiting;
            state preprocessing;
            state detecting;
            state done;

            transition waiting -> preprocessing
                when imageReceived;
            transition preprocessing -> detecting
                when preprocessingComplete;
            transition detecting -> done
                when detectionComplete;
            transition done -> waiting
                when resultsSent;
        }
    }

    // ===== Reporting Subsystem =====
    part def ReportingSubsystem {
        attribute acceptableDefectLimit : DefectCount = 3;

        port defectListIn : ~DefectListPort;
        port reportOut : ReportPort;

        action compileReport {
            in defects : Defect[0..*];
            out report : InspectionReport;
        }

        action evaluateStatus {
            in defectCount : DefectCount;
            out status : PassFailStatus;
        }

        state reportingBehavior {
            entry; then idle;

            state idle;
            state compiling;
            state evaluating;
            state published;

            transition idle -> compiling
                when defectsReceived;
            transition compiling -> evaluating
                when reportCompiled;
            transition evaluating -> published
                when statusDetermined;
            transition published -> idle
                when reportSent;
        }
    }

    // ===== Alert Subsystem =====
    part def AlertSubsystem {
        attribute criticalSeverityThreshold : SeverityLevel = 8;
        attribute falseAlarmRate : PercentValue = 1;

        port reportIn : ~ReportPort;
        port alertOut : AlertPort;

        action monitorReports {
            in report : InspectionReport;
        }

        action issueAlert {
            in report : InspectionReport;
            out alert : AlertMessage;
        }

        state alertBehavior {
            entry; then monitoring;

            state monitoring;
            state alerting;

            transition monitoring -> alerting
                when failureOrCriticalDefect;
            transition alerting -> monitoring
                when alertIssued;
        }
    }

    // ===== Top-Level System =====
    part def DefectDetectorSystem {
        attribute systemUptimeTarget : PercentValue = 99.5;
        attribute maxInspectionTime : TimeValue = 1.5;

        part imagingSubsystem : ImagingSubsystem;
        part processingSubsystem : ProcessingSubsystem;
        part reportingSubsystem : ReportingSubsystem;
        part alertSubsystem : AlertSubsystem;

        connection imagingToProcessing
            connect imagingSubsystem.imageOut to processingSubsystem.imageIn;

        connection processingToReporting
            connect processingSubsystem.defectListOut to reportingSubsystem.defectListIn;

        connection reportingToAlert
            connect reportingSubsystem.reportOut to alertSubsystem.reportIn;

        action performInspection {
            in product;
            out report : InspectionReport;
            out alert : AlertMessage [0..1];

            action captureImage {
                out image : RawImage;
            }

            action preprocessAndDetect {
                in image : RawImage;
                out defects : Defect[0..*];
            }

            action generateReport {
                in defects : Defect[0..*];
                out report : InspectionReport;
            }

            action checkAlert {
                in report : InspectionReport;
                out alert : AlertMessage [0..1];
            }

            succession captureImage then preprocessAndDetect;
            succession preprocessAndDetect then generateReport;
            succession generateReport then checkAlert;

            flow captureImage.image to preprocessAndDetect.image;
            flow preprocessAndDetect.defects to generateReport.defects;
            flow generateReport.report to checkAlert.report;
        }

        state systemOperation {
            entry; then standby;

            state standby;
            state inspecting;
            state reporting;
            state alerting;
            state complete;

            transition standby -> inspecting
                when productDetected;
            transition inspecting -> reporting
                when defectsIdentified;
            transition reporting -> alerting
                when reportGeneratedAndFailed;
            transition reporting -> complete
                when reportGeneratedAndPassed;
            transition alerting -> complete
                when alertIssued;
            transition complete -> standby
                when reset;
        }
    }

    // ===== Requirement Definitions =====
    requirement def DetectionAccuracyRequirement {
        doc "The system shall achieve a defect detection accuracy of at least 98%.";
        subject theProcessor : ProcessingSubsystem;
        attribute minAccuracy : PercentValue = 98;
        constraint { theProcessor.detectionAccuracy >= minAccuracy }
    }

    requirement def InspectionSpeedRequirement {
        doc "The system shall complete a full inspection cycle in under 1.5 seconds.";
        subject theSystem : DefectDetectorSystem;
        attribute maxTime : TimeValue = 1.5;
        constraint { theSystem.maxInspectionTime < maxTime }
    }

    requirement def FalseAlarmRateRequirement {
        doc "The system shall maintain a false alarm rate below 1%.";
        subject theAlertSubsystem : AlertSubsystem;
        attribute maxFalseAlarmRate : PercentValue = 1;
        constraint { theAlertSubsystem.falseAlarmRate < maxFalseAlarmRate }
    }

    requirement def ReliabilityRequirement {
        doc "The system shall maintain 99.5% operational uptime.";
        subject theSystem : DefectDetectorSystem;
        attribute minUptime : PercentValue = 99.5;
        constraint { theSystem.systemUptimeTarget >= minUptime }
    }

    requirement def ImagingResolutionRequirement {
        doc "The imaging subsystem shall capture images at high resolution.";
        subject theImager : ImagingSubsystem;
        attribute minResolution : PixelCount = 2048;
        constraint { theImager.resolution >= minResolution }
    }

    requirement def LightingAdjustmentRequirement {
        doc "The imaging subsystem shall actively adjust lighting for optimal image quality.";
        subject theImager : ImagingSubsystem;
        constraint { theImager.lightingAdjustable == true }
    }

    requirement def DefectClassificationRequirement {
        doc "The processing subsystem shall classify each defect by type, position, and severity.";
        subject theDefect : Defect;
        constraint { theDefect.type != null }
        constraint { theDefect.positionX != null }
        constraint { theDefect.positionY != null }
        constraint { theDefect.severity != null }
    }

    requirement def ConfidenceScoreRequirement {
        doc "The processing subsystem shall assign a confidence score to each detected defect.";
        subject theDefect : Defect;
        constraint { theDefect.confidence >= 0 }
        constraint { theDefect.confidence <= 100 }
    }

    requirement def ReportCompletenessRequirement {
        doc "The reporting subsystem shall include a unique ID, defect list, total count, and pass/fail status.";
        subject theReport : InspectionReport;
        constraint { theReport.reportId != null }
        constraint { theReport.defects != null }
        constraint { theReport.totalDefectCount != null }
        constraint { theReport.status != null }
    }

    requirement def AlertTriggerRequirement {
        doc "The alert subsystem shall issue an alert when a product fails or a critical defect is detected.";
        subject theReport : InspectionReport;
        attribute criticalThreshold : SeverityLevel = 8;
        constraint { theReport.status == PassFailStatus::fail }
    }

    // ===== Requirement Usages =====
    requirement detectionAccuracyReq : DetectionAccuracyRequirement {
        subject theProcessor = DefectDetectorSystem::processingSubsystem;
    }

    requirement inspectionSpeedReq : InspectionSpeedRequirement {
        subject theSystem = DefectDetectorSystem::self;
    }

    requirement falseAlarmReq : FalseAlarmRateRequirement {
        subject theAlertSubsystem = DefectDetectorSystem::alertSubsystem;
    }

    requirement reliabilityReq : ReliabilityRequirement {
        subject theSystem = DefectDetectorSystem::self;
    }

    requirement imagingResolutionReq : ImagingResolutionRequirement {
        subject theImager = DefectDetectorSystem::imagingSubsystem;
    }

    requirement lightingAdjustmentReq : LightingAdjustmentRequirement {
        subject theImager = DefectDetectorSystem::imagingSubsystem;
    }

    requirement defectClassificationReq : DefectClassificationRequirement {
        subject theDefect = Defect;
    }

    requirement confidenceScoreReq : ConfidenceScoreRequirement {
        subject theDefect = Defect;
    }

    requirement reportCompletenessReq : ReportCompletenessRequirement {
        subject theReport = InspectionReport;
    }

    requirement alertTriggerReq : AlertTriggerRequirement {
        subject theReport = InspectionReport;
    }
}
