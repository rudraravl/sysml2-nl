package FotoFinderSystemModel {

    import ScalarValues::*;
    import SI::*;

    attribute def Percent :> Real {
        unit = "%";
    }

    attribute def PixelCount :> Integer;
    attribute def ConfidenceScore :> Real;
    attribute def RiskScore :> Real;
    attribute def LesionIdentifier :> String;
    attribute def PatientIdentifier :> String;

    item def PatientIdentity {
        attribute patientId : PatientIdentifier;
        attribute dateOfBirth : String;
        attribute consentGranted : Boolean;
    }

    item def ImagingCommand {
        attribute requestedMode : ImagingMode;
        attribute targetRegion : BodyRegion;
        attribute operatorId : String;
    }

    item def OpticalImage {
        attribute imageId : String;
        attribute width : PixelCount;
        attribute height : PixelCount;
        attribute resolution : Real [1] { unit = "pixel/mm"; }
        attribute captureWavelength : Real [1] { unit = "nm"; }
        attribute captureTime : String;
    }

    item def DermoscopicImage :> OpticalImage {
        attribute polarized : Boolean;
        attribute magnification : Real;
    }

    item def BodyMapImage :> OpticalImage {
        attribute poseName : String;
    }

    item def LesionMeasurement {
        attribute lesionId : LesionIdentifier;
        attribute diameter : Real [1] { unit = "mm"; }
        attribute area : Real [1] { unit = "mm^2"; }
        attribute borderIrregularity : Real;
        attribute colorVariegation : Percent;
        attribute asymmetryIndex : Real;
    }

    item def RiskAssessment {
        attribute lesionId : LesionIdentifier;
        attribute malignancyRisk : RiskScore;
        attribute confidence : ConfidenceScore;
        attribute recommendedAction : ClinicalRecommendation;
    }

    item def PatientReport {
        attribute reportId : String;
        attribute patientId : PatientIdentifier;
        attribute generatedTime : String;
        attribute lesionCount : Integer;
        attribute highRiskLesionCount : Integer;
        attribute summaryText : String;
    }

    enum def ImagingMode {
        fullBodyMapping;
        dermoscopy;
        followUpComparison;
        reportGeneration;
    }

    enum def BodyRegion {
        head;
        neck;
        torsoAnterior;
        torsoPosterior;
        leftArm;
        rightArm;
        leftLeg;
        rightLeg;
        hand;
        foot;
    }

    enum def ClinicalRecommendation {
        routineMonitoring;
        shortTermFollowUp;
        clinicianReview;
        biopsyRecommended;
    }

    port def PatientDataPort {
        in item identity : PatientIdentity;
        out item report : PatientReport;
    }

    port def CommandPort {
        in item command : ImagingCommand;
    }

    port def ImagePort {
        out item image : OpticalImage;
    }

    port def DermoscopyImagePort {
        out item dermoscopicImage : DermoscopicImage;
    }

    port def BodyMapImagePort {
        out item bodyMapImage : BodyMapImage;
    }

    port def MeasurementPort {
        out item measurement : LesionMeasurement;
    }

    port def RiskPort {
        out item assessment : RiskAssessment;
    }

    port def StoragePort {
        in item image : OpticalImage;
        in item measurement : LesionMeasurement;
        in item assessment : RiskAssessment;
        in item report : PatientReport;
        out item historicalImage : OpticalImage;
        out item historicalMeasurement : LesionMeasurement;
    }

    part def FotoFinder {
        attribute primaryFunction : String = "Acquire standardized full-body and dermoscopic skin images, identify and measure skin lesions, compare findings over time, and support clinical risk assessment for early detection and monitoring of suspicious lesions.";

        port patientInterface : PatientDataPort;
        port operatorCommands : CommandPort;

        part imagingSubsystem : ImagingSubsystem;
        part positioningSubsystem : PatientPositioningSubsystem;
        part illuminationSubsystem : IlluminationSubsystem;
        part lesionAnalytics : LesionAnalyticsSubsystem;
        part comparisonEngine : FollowUpComparisonEngine;
        part clinicalReporting : ClinicalReportingSubsystem;
        part secureArchive : SecureArchiveSubsystem;
        part userConsole : OperatorConsole;
        part powerSubsystem : PowerSubsystem;

        connect operatorCommands to userConsole.commandInput;
        connect userConsole.positioningCommand to positioningSubsystem.commandInput;
        connect userConsole.imagingCommand to imagingSubsystem.commandInput;

        connect illuminationSubsystem.lightOutput to imagingSubsystem.lightInput;
        connect positioningSubsystem.poseOutput to imagingSubsystem.poseInput;

        connect imagingSubsystem.bodyMapOutput to lesionAnalytics.bodyMapInput;
        connect imagingSubsystem.dermoscopyOutput to lesionAnalytics.dermoscopyInput;

        connect lesionAnalytics.measurementOutput to comparisonEngine.currentMeasurementInput;
        connect lesionAnalytics.riskOutput to clinicalReporting.riskInput;

        connect secureArchive.historicalMeasurementOutput to comparisonEngine.historicalMeasurementInput;
        connect comparisonEngine.trendOutput to clinicalReporting.trendInput;

        connect imagingSubsystem.imageStorageOutput to secureArchive.imageInput;
        connect lesionAnalytics.measurementStorageOutput to secureArchive.measurementInput;
        connect lesionAnalytics.riskStorageOutput to secureArchive.riskInput;
        connect clinicalReporting.reportStorageOutput to secureArchive.reportInput;

        connect patientInterface to clinicalReporting.patientDataInput;
        connect clinicalReporting.reportOutput to patientInterface;

        connect powerSubsystem.powerOutput to imagingSubsystem.powerInput;
        connect powerSubsystem.powerOutput to illuminationSubsystem.powerInput;
        connect powerSubsystem.powerOutput to userConsole.powerInput;
        connect powerSubsystem.powerOutput to secureArchive.powerInput;
    }

    part def ImagingSubsystem {
        port commandInput : CommandPort;
        port lightInput : LightPort;
        port poseInput : PosePort;
        port bodyMapOutput : BodyMapImagePort;
        port dermoscopyOutput : DermoscopyImagePort;
        port imageStorageOutput : ImagePort;
        port powerInput : ElectricalPowerPort;

        part fullBodyCamera : FullBodyCamera;
        part dermoscopeCamera : DigitalDermoscopyCamera;
        part imageController : ImageAcquisitionController;

        connect commandInput to imageController.commandInput;
        connect lightInput to fullBodyCamera.lightInput;
        connect lightInput to dermoscopeCamera.lightInput;
        connect poseInput to fullBodyCamera.poseInput;
        connect imageController.fullBodyTrigger to fullBodyCamera.triggerInput;
        connect imageController.dermoscopyTrigger to dermoscopeCamera.triggerInput;
        connect fullBodyCamera.imageOutput to bodyMapOutput;
        connect dermoscopeCamera.imageOutput to dermoscopyOutput;
        connect fullBodyCamera.archiveOutput to imageStorageOutput;
        connect dermoscopeCamera.archiveOutput to imageStorageOutput;
        connect powerInput to fullBodyCamera.powerInput;
        connect powerInput to dermoscopeCamera.powerInput;
        connect powerInput to imageController.powerInput;
    }

    part def FullBodyCamera {
        attribute focalLength : Real [1] { unit = "mm"; } = 35.0;
        attribute sensorWidth : PixelCount = 8192;
        attribute sensorHeight : PixelCount = 5464;
        attribute minimumWorkingDistance : Real [1] { unit = "m"; } = 1.2;

        port triggerInput : TriggerPort;
        port lightInput : LightPort;
        port poseInput : PosePort;
        port imageOutput : BodyMapImagePort;
        port archiveOutput : ImagePort;
        port powerInput : ElectricalPowerPort;
    }

    part def DigitalDermoscopyCamera {
        attribute magnification : Real = 20.0;
        attribute contactPlateDiameter : Real [1] { unit = "mm"; } = 22.0;
        attribute polarizedModeAvailable : Boolean = true;

        port triggerInput : TriggerPort;
        port lightInput : LightPort;
        port imageOutput : DermoscopyImagePort;
        port archiveOutput : ImagePort;
        port powerInput : ElectricalPowerPort;
    }

    part def ImageAcquisitionController {
        port commandInput : CommandPort;
        port fullBodyTrigger : TriggerPort;
        port dermoscopyTrigger : TriggerPort;
        port powerInput : ElectricalPowerPort;

        action acquireImages {
            first start;
            then chooseMode;
            if commandInput.command.requestedMode == ImagingMode::fullBodyMapping then triggerFullBody;
            if commandInput.command.requestedMode == ImagingMode::dermoscopy then triggerDermoscopy;
            then verifyImageQuality;
            then complete;
        }

        state acquisitionState {
            entry; then idle;

            state idle;
            state configuring;
            state capturing;
            state validating;
            state completed;
            state fault;

            transition idle_to_configuring
                first idle
                accept ImagingCommand
                then configuring;

            transition configuring_to_capturing
                first configuring
                then capturing;

            transition capturing_to_validating
                first capturing
                then validating;

            transition validating_to_completed
                first validating
                if imageQualityAcceptable
                then completed;

            transition validating_to_fault
                first validating
                if not imageQualityAcceptable
                then fault;

            transition completed_to_idle
                first completed
                then idle;

            transition fault_to_idle
                first fault
                accept ImagingCommand
                then idle;
        }

        attribute imageQualityAcceptable : Boolean;
    }

    part def PatientPositioningSubsystem {
        attribute poseTolerance : Real [1] { unit = "deg"; } = 3.0;

        port commandInput : CommandPort;
        port poseOutput : PosePort;

        part poseGuide : PoseGuidanceDisplay;
        part referenceMarkers : BodyReferenceMarkerSet;

        connect commandInput to poseGuide.commandInput;
        connect poseGuide.poseOutput to poseOutput;
    }

    part def PoseGuidanceDisplay {
        port commandInput : CommandPort;
        port poseOutput : PosePort;
    }

    part def BodyReferenceMarkerSet {
        attribute markerCount : Integer = 32;
        attribute markerDiameter : Real [1] { unit = "mm"; } = 8.0;
    }

    part def IlluminationSubsystem {
        attribute visibleLightIntensity : Real [1] { unit = "lux"; } = 1200.0;
        attribute dermoscopyLedWavelength : Real [1] { unit = "nm"; } = 550.0;

        port lightOutput : LightPort;
        port powerInput : ElectricalPowerPort;

        part fullBodyLightArray : LightArray;
        part dermoscopyLedRing : LightArray;
        part lightController : LightController;

        connect powerInput to lightController.powerInput;
        connect powerInput to fullBodyLightArray.powerInput;
        connect powerInput to dermoscopyLedRing.powerInput;
        connect lightController.lightCommandOutput to fullBodyLightArray.commandInput;
        connect lightController.lightCommandOutput to dermoscopyLedRing.commandInput;
        connect fullBodyLightArray.lightOutput to lightOutput;
        connect dermoscopyLedRing.lightOutput to lightOutput;
    }

    part def LightArray {
        attribute ledCount : Integer;
        attribute colorTemperature : Real [1] { unit = "K"; }

        port commandInput : LightControlPort;
        port lightOutput : LightPort;
        port powerInput : ElectricalPowerPort;
    }

    part def LightController {
        port lightCommandOutput : LightControlPort;
        port powerInput : ElectricalPowerPort;
    }

    part def LesionAnalyticsSubsystem {
        port bodyMapInput : BodyMapImagePort;
        port dermoscopyInput : DermoscopyImagePort;
        port measurementOutput : MeasurementPort;
        port riskOutput : RiskPort;
        port measurementStorageOutput : MeasurementPort;
        port riskStorageOutput : RiskPort;

        part lesionDetector : LesionDetectionProcessor;
        part measurementProcessor : LesionMeasurementProcessor;
        part riskClassifier : RiskClassificationProcessor;

        connect bodyMapInput to lesionDetector.bodyMapInput;
        connect dermoscopyInput to lesionDetector.dermoscopyInput;
        connect lesionDetector.detectedLesionOutput to measurementProcessor.detectedLesionInput;
        connect measurementProcessor.measurementOutput to riskClassifier.measurementInput;
        connect measurementProcessor.measurementOutput to measurementOutput;
        connect measurementProcessor.measurementOutput to measurementStorageOutput;
        connect riskClassifier.riskOutput to riskOutput;
        connect riskClassifier.riskOutput to riskStorageOutput;
    }

    part def LesionDetectionProcessor {
        attribute minimumLesionDiameter : Real [1] { unit = "mm"; } = 1.0;
        attribute detectionSensitivity : Percent = 92.0;

        port bodyMapInput : BodyMapImagePort;
        port dermoscopyInput : DermoscopyImagePort;
        port detectedLesionOutput : DetectedLesionPort;

        action detectLesions {
            first normalizeColor;
            then segmentSkinSurface;
            then identifyCandidateLesions;
            then assignBodyMapCoordinates;
            then publishDetectedLesions;
        }
    }

    part def LesionMeasurementProcessor {
        port detectedLesionInput : DetectedLesionPort;
        port measurementOutput : MeasurementPort;

        action measureLesion {
            first computeDiameter;
            then computeArea;
            then evaluateAsymmetry;
            then evaluateBorder;
            then evaluateColorVariegation;
            then emitMeasurement;
        }
    }

    part def RiskClassificationProcessor {
        attribute highRiskThreshold : RiskScore = 0.70;
        attribute mediumRiskThreshold : RiskScore = 0.40;

        port measurementInput : MeasurementPort;
        port riskOutput : RiskPort;

        action classifyRisk {
            first evaluateABCDFeatures;
            then compareAgainstClassifierThresholds;
            then assignRecommendation;
            then emitRiskAssessment;
        }
    }

    part def FollowUpComparisonEngine {
        port currentMeasurementInput : MeasurementPort;
        port historicalMeasurementInput : MeasurementPort;
        port trendOutput : TrendPort;

        action compareOverTime {
            first matchLesionsByIdentifierAndLocation;
            then computeDiameterChange;
            then computeAreaChange;
            then computeRiskTrend;
            then publishTrend;
        }
    }

    part def ClinicalReportingSubsystem {
        port patientDataInput : PatientDataPort;
        port riskInput : RiskPort;
        port trendInput : TrendPort;
        port reportOutput : PatientDataPort;
        port reportStorageOutput : ReportPort;

        part reportComposer : ReportComposer;
        part clinicianReviewQueue : ClinicianReviewQueue;

        connect patientDataInput to reportComposer.patientDataInput;
        connect riskInput to reportComposer.riskInput;
        connect trendInput to reportComposer.trendInput;
        connect reportComposer.reportOutput to reportOutput;
        connect reportComposer.reportStorageOutput to reportStorageOutput;
        connect reportComposer.reviewOutput to clinicianReviewQueue.reviewInput;
    }

    part def ReportComposer {
        port patientDataInput : PatientDataPort;
        port riskInput : RiskPort;
        port trendInput : TrendPort;
        port reportOutput : PatientDataPort;
        port reportStorageOutput : ReportPort;
        port reviewOutput : ReviewPort;

        action generateReport {
            first collectPatientContext;
            then summarizeDetectedLesions;
            then highlightChangedLesions;
            then highlightHighRiskLesions;
            then createClinicalReport;
            then publishReport;
        }
    }

    part def ClinicianReviewQueue {
        port reviewInput : ReviewPort;
        attribute pendingReviewCount : Integer;
    }

    part def SecureArchiveSubsystem {
        attribute retentionPeriod : Real [1] { unit = "yr"; } = 10.0;
        attribute encryptionEnabled : Boolean = true;

        port imageInput : ImagePort;
        port measurementInput : MeasurementPort;
        port riskInput : RiskPort;
        port reportInput : ReportPort;
        port historicalImageOutput : ImagePort;
        port historicalMeasurementOutput : MeasurementPort;
        port powerInput : ElectricalPowerPort;

        part encryptedImageStore : EncryptedDataStore;
        part patientRecordIndex : PatientRecordIndex;

        connect imageInput to encryptedImageStore.imageInput;
        connect measurementInput to encryptedImageStore.measurementInput;
        connect riskInput to encryptedImageStore.riskInput;
        connect reportInput to encryptedImageStore.reportInput;
        connect encryptedImageStore.historicalImageOutput to historicalImageOutput;
        connect encryptedImageStore.historicalMeasurementOutput to historicalMeasurementOutput;
    }

    part def EncryptedDataStore {
        port imageInput : ImagePort;
        port measurementInput : MeasurementPort;
        port riskInput : RiskPort;
        port reportInput : ReportPort;
        port historicalImageOutput : ImagePort;
        port historicalMeasurementOutput : MeasurementPort;
    }

    part def PatientRecordIndex {
        attribute indexedPatientCount : Integer;
    }

    part def OperatorConsole {
        port commandInput : CommandPort;
        port imagingCommand : CommandPort;
        port positioningCommand : CommandPort;
        port powerInput : ElectricalPowerPort;

        action conductExam {
            first verifyPatientIdentity;
            then obtainConsent;
            then selectImagingMode;
            then guidePatientPose;
            then initiateCapture;
            then reviewCapturedImages;
            then submitForAnalysis;
        }
    }

    part def PowerSubsystem {
        attribute inputVoltage : Real [1] { unit = "V"; } = 120.0;
        attribute maximumPower : Real [1] { unit = "W"; } = 650.0;

        port powerOutput : ElectricalPowerPort;
    }

    port def ElectricalPowerPort {
        out attribute voltage : Real [1] { unit = "V"; }
        out attribute current : Real [1] { unit = "A"; }
    }

    port def TriggerPort {
        in attribute triggerRequested : Boolean;
    }

    port def LightPort {
        out attribute illuminance : Real [1] { unit = "lux"; }
        out attribute wavelength : Real [1] { unit = "nm"; }
    }

    port def LightControlPort {
        in attribute intensitySetpoint : Percent;
        in attribute polarizationEnabled : Boolean;
    }

    port def PosePort {
        out attribute poseName : String;
        out attribute angularDeviation : Real [1] { unit = "deg"; }
    }

    port def DetectedLesionPort {
        out item lesionId : LesionIdentifier;
        out attribute bodyRegion : BodyRegion;
        out attribute xCoordinate : Real [1] { unit = "mm"; }
        out attribute yCoordinate : Real [1] { unit = "mm"; }
    }

    port def TrendPort {
        out attribute lesionId : LesionIdentifier;
        out attribute diameterChange : Real [1] { unit = "mm"; }
        out attribute areaChange : Real [1] { unit = "mm^2"; }
        out attribute riskChange : RiskScore;
    }

    port def ReportPort {
        in item report : PatientReport;
    }

    port def ReviewPort {
        in attribute lesionId : LesionIdentifier;
        in attribute priority : Integer;
        in attribute reason : String;
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The FotoFinder system shall provide high-level support for dermatologic skin monitoring by acquiring standardized images, detecting and measuring skin lesions, comparing them with prior examinations, and producing clinically usable risk and follow-up information. */
        subject system : FotoFinder;

        require constraint {
            system.imagingSubsystem.fullBodyCamera.sensorWidth >= 6000 and
            system.lesionAnalytics.riskClassifier.highRiskThreshold <= 0.80 and
            system.secureArchive.encryptionEnabled == true
        }
    }

    requirement def ImageCaptureRequirement {
        doc /* The system shall acquire full-body map images and dermoscopic images using controlled illumination and guided patient positioning. */
        subject system : FotoFinder;

        require constraint {
            system.positioningSubsystem.poseTolerance <= 5.0 and
            system.illuminationSubsystem.visibleLightIntensity >= 800.0
        }
    }

    requirement def LesionAnalysisRequirement {
        doc /* The system shall identify candidate lesions, measure relevant visual features, and generate a risk assessment with a recommendation. */
        subject analytics : LesionAnalyticsSubsystem;

        require constraint {
            analytics.lesionDetector.minimumLesionDiameter <= 2.0 and
            analytics.lesionDetector.detectionSensitivity >= 85.0
        }
    }

    requirement def SecureRecordRequirement {
        doc /* The system shall retain examination images, measurements, risk assessments, and reports in an encrypted archive for longitudinal comparison. */
        subject archive : SecureArchiveSubsystem;

        require constraint {
            archive.encryptionEnabled == true and
            archive.retentionPeriod >= 7.0
        }
    }

    requirement def ClinicalReportRequirement {
        doc /* The system shall produce a patient-specific report summarizing lesion count, high-risk findings, trend changes, and recommended clinical follow-up. */
        subject reporting : ClinicalReportingSubsystem;
    }

    satisfy PrimaryFunctionRequirement by FotoFinder;
    satisfy ImageCaptureRequirement by FotoFinder;
    satisfy LesionAnalysisRequirement by LesionAnalyticsSubsystem;
    satisfy SecureRecordRequirement by SecureArchiveSubsystem;
    satisfy ClinicalReportRequirement by ClinicalReportingSubsystem;

    part fotoFinderSystem : FotoFinder;
}