package TissueImageAnalysisSystem {
    private import ScalarValues::*;
    private import SI::*;

    item def TissueSlide {
        attribute patientId : String;
        attribute sampleType : String;
    }

    item def RawImage {
        attribute pixelData : String;
        attribute resolution : Real = 0 [m];
    }

    item def QualityStatus {
        attribute isAcceptable : Boolean;
        attribute focusScore : Real;
        attribute clarityScore : Real;
    }

    item def RefinedImage {
        attribute enhancedPixelData : String;
        attribute contrastLevel : Real;
        attribute noiseLevel : Real;
    }

    item def SegmentationMap {
        attribute cellBoundaries : String;
        attribute nucleusBoundaries : String;
        attribute cellCount : Integer;
    }

    item def CellMetrics {
        attribute cellSize : Real = 0 [m**2];
        attribute cellShapeIndex : Real;
        attribute nuclearToPlasmaRatio : Real;
        attribute mitoticCount : Integer;
    }

    item def TissueClassification {
        attribute tissueType : String;
        attribute isCancerous : Boolean;
        attribute anomalyDescription : String;
        attribute tumorGrade : Integer;
    }

    item def DiagnosticReport {
        attribute reportId : String;
        attribute findings : String;
        attribute annotatedImage : RawImage;
        attribute classification : TissueClassification;
        attribute metrics : CellMetrics;
    }

    port def SlideInputPort { in item slide : TissueSlide; }
    port def RawImageOutputPort { out item rawImage : RawImage; }
    port def RawImageInputPort { in item rawImage : RawImage; }
    port def QualityStatusOutputPort { out item status : QualityStatus; }
    port def RefinedImageOutputPort { out item refinedImage : RefinedImage; }
    port def RefinedImageInputPort { in item refinedImage : RefinedImage; }
    port def SegmentationOutputPort { out item segmentationMap : SegmentationMap; }
    port def SegmentationInputPort { in item segmentationMap : SegmentationMap; }
    port def CellMetricsOutputPort { out item cellMetrics : CellMetrics; }
    port def CellMetricsInputPort { in item cellMetrics : CellMetrics; }
    port def ClassificationOutputPort { out item classification : TissueClassification; }
    port def ClassificationInputPort { in item classification : TissueClassification; }
    port def ReportOutputPort { out item report : DiagnosticReport; }
    port def ReportInputPort { in item report : DiagnosticReport; }

    action def ScanSlide {
        in item slide : TissueSlide;
        out item rawImage : RawImage;
    }

    action def AssessQuality {
        in item rawImage : RawImage;
        out item status : QualityStatus;
        out item passedImage : RawImage;
    }

    action def Preprocess {
        in item rawImage : RawImage;
        out item refinedImage : RefinedImage;
    }

    action def SegmentCells {
        in item refinedImage : RefinedImage;
        out item segmentationMap : SegmentationMap;
    }

    action def ExtractFeatures {
        in item segmentationMap : SegmentationMap;
        out item cellMetrics : CellMetrics;
    }

    action def ClassifyTissue {
        in item cellMetrics : CellMetrics;
        out item classification : TissueClassification;
    }

    action def GenerateReport {
        in item classification : TissueClassification;
        in item cellMetrics : CellMetrics;
        out item report : DiagnosticReport;
    }

    action def ReviewReport {
        in item report : DiagnosticReport;
    }

    part def DigitalScanningMicroscope {
        port slideInPort : SlideInputPort;
        port rawImageOutPort : RawImageOutputPort;
    }

    part def QualityControlModule {
        port rawImageInPort : RawImageInputPort;
        port statusOutPort : QualityStatusOutputPort;
        port imagePassPort : RawImageOutputPort;
    }

    part def ImagePreprocessingUnit {
        port imageInPort : RawImageInputPort;
        port refinedImageOutPort : RefinedImageOutputPort;
    }

    part def CellSegmentationEngine {
        port refinedImageInPort : RefinedImageInputPort;
        port segmentationOutPort : SegmentationOutputPort;
    }

    part def FeatureExtractionModule {
        port segmentationInPort : SegmentationInputPort;
        port metricsOutPort : CellMetricsOutputPort;
    }

    part def ClassificationEngine {
        port metricsInPort : CellMetricsInputPort;
        port classificationOutPort : ClassificationOutputPort;
    }

    part def DiagnosticReportGenerator {
        port classificationInPort : ClassificationInputPort;
        port metricsInPort : CellMetricsInputPort;
        port reportOutPort : ReportOutputPort;
    }

    part def Pathologist {
        port reportInPort : ReportInputPort;
    }

    state machine def AnalysisStates {
        state Idle;
        state Scanning;
        state QualityChecking;
        state Preprocessing;
        state Segmenting;
        state Extracting;
        state Classifying;
        state GeneratingReport;
        state AwaitingReview;
        state Complete;

        transition from Idle to Scanning;
        transition from Scanning to QualityChecking;
        transition from QualityChecking to Preprocessing;
        transition from Preprocessing to Segmenting;
        transition from Segmenting to Extracting;
        transition from Extracting to Classifying;
        transition from Classifying to GeneratingReport;
        transition from GeneratingReport to AwaitingReview;
        transition from AwaitingReview to Complete;
        transition from Complete to Idle;
    }

    part def TissueImageAnalysisSystem {
        port slideInputPort : SlideInputPort;
        port reportOutputPort : ReportOutputPort;

        part microscope : DigitalScanningMicroscope;
        part qcModule : QualityControlModule;
        part preprocessingUnit : ImagePreprocessingUnit;
        part segmentationEngine : CellSegmentationEngine;
        part featureExtraction : FeatureExtractionModule;
        part classificationEngine : ClassificationEngine;
        part reportGenerator : DiagnosticReportGenerator;
        part pathologist : Pathologist;

        flow slideFlow of TissueSlide
            from slideInputPort.slide to microscope.slideInPort.slide;
        flow rawImageFlow of RawImage
            from microscope.rawImageOutPort.rawImage to qcModule.rawImageInPort.rawImage;
        flow qcPassFlow of RawImage
            from qcModule.imagePassPort.rawImage to preprocessingUnit.imageInPort.rawImage;
        flow refinedImageFlow of RefinedImage
            from preprocessingUnit.refinedImageOutPort.refinedImage to segmentationEngine.refinedImageInPort.refinedImage;
        flow segmentationFlow of SegmentationMap
            from segmentationEngine.segmentationOutPort.segmentationMap to featureExtraction.segmentationInPort.segmentationMap;
        flow metricsFlow of CellMetrics
            from featureExtraction.metricsOutPort.cellMetrics to classificationEngine.metricsInPort.cellMetrics;
        flow metricsToReportFlow of CellMetrics
            from featureExtraction.metricsOutPort.cellMetrics to reportGenerator.metricsInPort.cellMetrics;
        flow classificationFlow of TissueClassification
            from classificationEngine.classificationOutPort.classification to reportGenerator.classificationInPort.classification;
        flow reportToPathologistFlow of DiagnosticReport
            from reportGenerator.reportOutPort.report to pathologist.reportInPort.report;
        flow reportOutputFlow of DiagnosticReport
            from reportGenerator.reportOutPort.report to reportOutputPort.report;

        state machine analysisStateMachine : AnalysisStates;
    }

    action def AnalyzeTissueWorkflow {
        in item slide : TissueSlide;
        out item report : DiagnosticReport;

        action trigger accept slide : TissueSlide;
        then action scan : ScanSlide {
            in item slide = trigger.slide;
            out item rawImage;
        }
        flow from scan.rawImage to qualityCheck.rawImage;
        then action qualityCheck : AssessQuality {
            in item rawImage;
            out item status;
            out item passedImage;
        }
        flow from qualityCheck.passedImage to preprocess.rawImage;
        then action preprocess : Preprocess {
            in item rawImage;
            out item refinedImage;
        }
        flow from preprocess.refinedImage to segment.refinedImage;
        then action segment : SegmentCells {
            in item refinedImage;
            out item segmentationMap;
        }
        flow from segment.segmentationMap to extract.segmentationMap;
        then action extract : ExtractFeatures {
            in item segmentationMap;
            out item cellMetrics;
        }
        flow from extract.cellMetrics to classify.cellMetrics;
        then action classify : ClassifyTissue {
            in item cellMetrics;
            out item classification;
        }
        flow from classify.classification to generate.classification;
        flow from extract.cellMetrics to generate.cellMetrics;
        then action generate : GenerateReport {
            in item classification;
            in item cellMetrics;
            out item report;
        }
    }

    requirement def DiagnosticAccuracyRequirement {
        doc /* The system shall classify cancerous tissue with at least 95 percent accuracy. */
        attribute requiredAccuracy : Real = 0.95;
    }

    requirement def WorkflowEfficiencyRequirement {
        doc /* The system shall process a slide from scanning to report in under 30 minutes. */
        attribute maxProcessingTime : Real = 1800 [s];
    }

    requirement def ImageQualityRequirement {
        doc /* The Quality Control Module shall reject images with focus score below 0.8. */
        attribute minFocusScore : Real = 0.8;
    }

    requirement def ReportCompletenessRequirement {
        doc /* The Diagnostic Report Generator shall produce reports containing annotated images, cell metrics, and classification results. */
    }

    part analysisSystem : TissueImageAnalysisSystem {
        satisfy DiagnosticAccuracyRequirement;
        satisfy WorkflowEfficiencyRequirement;
        satisfy ImageQualityRequirement;
        satisfy ReportCompletenessRequirement;
    }
}
